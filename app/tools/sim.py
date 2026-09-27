#!/usr/bin/env python3
"""FocusFreak wire-protocol simulator.

Written from ``docs/PROTOCOL.md``, which is the contract. Two modes:

* ``device`` — pretends to be the bot. Point the app (or a serial terminal) at
  it and the whole connect / push / status / log flow works with no hardware.
* ``app``    — pretends to be the phone. Point it at a real Arduino over USB
  and it runs the §12 handshake, pushes a routine, and polls status, so the
  firmware can be tested before the Bluetooth module is even wired.

That second mode is the reason this file exists in Python rather than reusing
the app's Dart ``SimulatedDevice``: it has to run on the firmware author's
machine, over their USB cable, with nothing installed but a Python 3.

    python3 sim.py device --tcp 5600        # app connects to 127.0.0.1:5600
    python3 sim.py device --serial /dev/tty.usbserial-1420
    python3 sim.py app --serial /dev/tty.usbmodem1101 --push
    python3 sim.py selftest

``--serial`` needs pyserial (``pip install pyserial``); ``--tcp`` needs nothing.

Stdlib only, one file, no build step. If it grows a dependency it stops being
the thing a teammate can run at 1 a.m. the night before the demo.
"""

from __future__ import annotations

import argparse
import datetime
import socket
import struct
import sys
import time
from dataclasses import dataclass, field

# --------------------------------------------------------------------------
# §2 framing, §13 checksums
# --------------------------------------------------------------------------

PREAMBLE = b"\xAA\x55"
MAX_PAYLOAD = 64
INTER_BYTE_TIMEOUT = 0.200  # §2: 200 ms, not optional on either side

# §3 command table
HELLO, HELLO_ACK = 0x01, 0x81
SET_TIME = 0x10
ROUTINE_BEGIN, ROUTINE_BLOCK, ROUTINE_COMMIT, ROUTINE_GET = 0x20, 0x21, 0x22, 0x23
ROUTINE_BLOCK_REPLY = 0xA3
STATUS_REQ, STATUS = 0x30, 0xB0
LOG_REQ, LOG_ENTRY = 0x40, 0xC0
PHONE_HEARTBEAT = 0x50
CONFIG_SET = 0x60
CONTROL = 0x70
NACK = 0xE0

CMD_NAMES = {
    HELLO: "HELLO", HELLO_ACK: "HELLO_ACK", SET_TIME: "SET_TIME",
    ROUTINE_BEGIN: "ROUTINE_BEGIN", ROUTINE_BLOCK: "ROUTINE_BLOCK",
    ROUTINE_COMMIT: "ROUTINE_COMMIT", ROUTINE_GET: "ROUTINE_GET",
    ROUTINE_BLOCK_REPLY: "ROUTINE_BLOCK(reply)", STATUS_REQ: "STATUS_REQ",
    STATUS: "STATUS", LOG_REQ: "LOG_REQ", LOG_ENTRY: "LOG_ENTRY",
    PHONE_HEARTBEAT: "PHONE_HEARTBEAT", CONFIG_SET: "CONFIG_SET",
    CONTROL: "CONTROL", NACK: "NACK",
}

# §10 NACK reasons
NACK_CRC_FAIL, NACK_BAD_LENGTH, NACK_UNKNOWN_CMD = 0x01, 0x02, 0x03
NACK_ROUTINE_SEQUENCE, NACK_ROUTINE_CRC = 0x04, 0x05
NACK_EEPROM_WRITE_FAIL, NACK_BUSY, NACK_OUT_OF_RANGE = 0x06, 0x07, 0x08


def crc8(data: bytes) -> int:
    """Poly 0x07, init 0x00, no reflection, no final XOR. §13."""
    c = 0x00
    for byte in data:
        c ^= byte
        for _ in range(8):
            c = ((c << 1) ^ 0x07) & 0xFF if c & 0x80 else (c << 1) & 0xFF
    return c


def crc16_xmodem(data: bytes) -> int:
    """Poly 0x1021, init 0x0000. Used only by ROUTINE_COMMIT."""
    crc = 0x0000
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def encode(cmd: int, payload: bytes = b"") -> bytes:
    if len(payload) > MAX_PAYLOAD:
        raise ValueError(f"payload {len(payload)} B exceeds {MAX_PAYLOAD}")
    body = bytes([cmd, len(payload)]) + payload
    return PREAMBLE + body + bytes([crc8(body)])


def hexdump(data: bytes) -> str:
    return " ".join(f"{b:02x}" for b in data)


class Parser:
    """The §2 receive state machine, including the 200 ms resync rule."""

    WAIT_AA, WAIT_55, CMD, LEN, PAYLOAD, CRC = range(6)

    def __init__(self, on_drop=None):
        self.state = self.WAIT_AA
        self.cmd = 0
        self.need = 0
        self.buf = bytearray()
        self.last_byte_at = None
        self.on_drop = on_drop or (lambda why: None)

    def feed(self, data: bytes):
        """Yields (cmd, payload) for every complete frame in *data*."""
        out = []
        for byte in data:
            now = time.monotonic()
            self._expire(now)
            self.last_byte_at = now

            if self.state == self.WAIT_AA:
                if byte == 0xAA:
                    self.state = self.WAIT_55
            elif self.state == self.WAIT_55:
                # AA AA 55 is a legitimate resync after a dropped byte.
                if byte == 0x55:
                    self.state = self.CMD
                elif byte != 0xAA:
                    self.state = self.WAIT_AA
            elif self.state == self.CMD:
                self.cmd = byte
                self.state = self.LEN
            elif self.state == self.LEN:
                if byte > MAX_PAYLOAD:
                    self._drop(f"LEN={byte}")
                    continue
                self.need = byte
                self.buf.clear()
                self.state = self.CRC if byte == 0 else self.PAYLOAD
            elif self.state == self.PAYLOAD:
                self.buf.append(byte)
                if len(self.buf) == self.need:
                    self.state = self.CRC
            elif self.state == self.CRC:
                want = crc8(bytes([self.cmd, self.need]) + bytes(self.buf))
                if byte == want:
                    out.append((self.cmd, bytes(self.buf)))
                    self._reset()
                else:
                    self._drop(f"crc got {byte:02x} want {want:02x}")
        return out

    def resync_if_stale(self):
        self._expire(time.monotonic())

    def _expire(self, now):
        if self.state == self.WAIT_AA or self.last_byte_at is None:
            return
        if now - self.last_byte_at >= INTER_BYTE_TIMEOUT:
            self._drop("inter-byte timeout")

    def _drop(self, why):
        self.on_drop(why)
        self._reset()

    def _reset(self):
        self.state = self.WAIT_AA
        self.cmd = 0
        self.need = 0
        self.buf.clear()
        self.last_byte_at = None


# --------------------------------------------------------------------------
# §5 Block, §6 STATUS, §7 LOG_ENTRY
# --------------------------------------------------------------------------

SEQUENTIAL = 0xFFFF


@dataclass
class Block:
    name: str
    desc: str = ""
    duration_min: int = 30
    category: int = 0
    track: bool = False
    start_min: int = SEQUENTIAL

    def pack(self) -> bytes:
        name = self.name.encode()[:16].ljust(16, b"\0")
        desc = self.desc.encode()[:24].ljust(24, b"\0")
        return name + desc + struct.pack(
            "<HBBHH", self.duration_min, self.category,
            1 if self.track else 0, self.start_min, 0,
        )

    @staticmethod
    def unpack(data: bytes) -> "Block":
        if len(data) != 48:
            raise ValueError(f"Block is 48 B, got {len(data)}")
        duration, category, flags, start, _ = struct.unpack("<HBBHH", data[40:])
        return Block(
            name=data[0:16].rstrip(b"\0").decode(errors="replace"),
            desc=data[16:40].rstrip(b"\0").decode(errors="replace"),
            duration_min=duration, category=category,
            track=bool(flags & 0x01), start_min=start,
        )


@dataclass
class DayLog:
    date_code: int
    verified_min: int = 0
    claimed_min: int = 0
    blocks_done: int = 0
    blocks_total: int = 0
    violations: int = 0

    def pack(self) -> bytes:
        return struct.pack(
            "<HHHBBB3x", self.date_code, self.verified_min, self.claimed_min,
            self.blocks_done, self.blocks_total, self.violations,
        )


# --------------------------------------------------------------------------
# Links: TCP or serial, same two methods either way
# --------------------------------------------------------------------------

class TcpLink:
    def __init__(self, conn, peer):
        self.conn = conn
        self.description = f"tcp {peer[0]}:{peer[1]}"
        conn.settimeout(0.05)

    def read(self) -> bytes:
        try:
            return self.conn.recv(512)
        except socket.timeout:
            return b""

    def write(self, data: bytes):
        self.conn.sendall(data)

    def close(self):
        self.conn.close()


class SerialLink:
    def __init__(self, port: str, baud: int):
        try:
            import serial  # type: ignore
        except ImportError:
            sys.exit("--serial needs pyserial:  pip install pyserial")
        self.port = serial.Serial(port, baud, timeout=0.05)
        self.description = f"serial {port} @ {baud}"

    def read(self) -> bytes:
        waiting = self.port.in_waiting
        return self.port.read(waiting if waiting else 1)

    def write(self, data: bytes):
        self.port.write(data)

    def close(self):
        self.port.close()


# --------------------------------------------------------------------------
# device mode — pretend to be the bot
# --------------------------------------------------------------------------

@dataclass
class Device:
    """The firmware's behaviour, close enough to test the app against.

    Mirrors ``lib/device/simulated_device.dart``. The sequence rules are the
    part that matters: BLOCK without BEGIN is a NACK, and **nothing is stored
    until COMMIT verifies** — a half-written routine is a corrupt device.
    """

    proto_version: int = 0x01
    fw_major: int = 1
    fw_minor: int = 0
    device_id: int = 1
    caps_lo: int = 0xFF
    caps_hi: int = 0x09
    log_days: int = 30
    max_blocks: int = 16

    routine: list = field(default_factory=list)
    logs: list = field(default_factory=list)
    config: dict = field(default_factory=dict)
    staging: list = field(default_factory=lambda: None)

    state: int = 0          # 0 IDLE 1 ARMED 2 RUNNING 3 PAUSED 4 COMPLETE 5 BROKEN
    block_idx: int = 0xFF
    secs_left: int = 0
    verified_today: int = 0
    claimed_today: int = 0
    streak: int = 3
    mood: int = 0
    present: bool = True
    docked: bool = True
    phone_locked: bool = True
    started_at: float = 0.0

    def status_payload(self) -> bytes:
        self._tick()
        tracked = (
            self.state == 2
            and self.block_idx != 0xFF
            and self.block_idx < len(self.routine)
            and self.routine[self.block_idx].track
        )
        verified = tracked and self.present and self.docked and self.phone_locked
        flags = (
            (0x01 if self.present else 0)
            | (0x02 if self.docked else 0)
            | (0x04 if self.phone_locked else 0)
            | (0x08 if verified else 0)
            | (0x10 if tracked else 0)
        )
        return struct.pack(
            "<BBHHHBBBB", self.state, self.block_idx, self.secs_left,
            self.verified_today, self.claimed_today, self.streak, self.mood,
            flags, 0xFF,  # no battery gauge: 0xFF means unknown, not 255%
        )

    def _tick(self):
        if self.state != 2 or not self.started_at:
            return
        now = time.monotonic()
        elapsed = int(now - self.started_at)
        if elapsed <= 0:
            return
        self.started_at = now
        self.secs_left = max(0, self.secs_left - elapsed)
        if self.secs_left == 0:
            self.state, self.block_idx = 4, 0xFF

    def handle(self, cmd: int, payload: bytes, send):
        if cmd == HELLO:
            send(HELLO_ACK, bytes([
                self.proto_version, self.fw_major, self.fw_minor,
                self.device_id, self.caps_lo, self.caps_hi,
                self.log_days, self.max_blocks,
            ]))
        elif cmd == SET_TIME:
            if len(payload) != 7:
                return send(NACK, bytes([NACK_BAD_LENGTH]))
            yy, mm, dd, hh, mi, ss, dow = payload
            print(f"    clock set to 20{yy:02d}-{mm:02d}-{dd:02d} "
                  f"{hh:02d}:{mi:02d}:{ss:02d} (dow {dow})")
        elif cmd == ROUTINE_BEGIN:
            if len(payload) != 1:
                return send(NACK, bytes([NACK_BAD_LENGTH]))
            if payload[0] > self.max_blocks:
                return send(NACK, bytes([NACK_OUT_OF_RANGE]))
            self.staging = [None] * payload[0]
        elif cmd == ROUTINE_BLOCK:
            if self.staging is None:
                return send(NACK, bytes([NACK_ROUTINE_SEQUENCE]))
            if len(payload) != 49:
                return send(NACK, bytes([NACK_BAD_LENGTH]))
            idx = payload[0]
            if idx >= len(self.staging):
                return send(NACK, bytes([NACK_OUT_OF_RANGE]))
            self.staging[idx] = Block.unpack(payload[1:])
        elif cmd == ROUTINE_COMMIT:
            if self.staging is None:
                return send(NACK, bytes([NACK_ROUTINE_SEQUENCE]))
            if len(payload) != 2:
                return send(NACK, bytes([NACK_BAD_LENGTH]))
            if any(b is None for b in self.staging):
                return send(NACK, bytes([NACK_ROUTINE_CRC]))
            want = payload[0] | (payload[1] << 8)
            got = crc16_xmodem(b"".join(b.pack() for b in self.staging))
            if got != want:
                print(f"    commit crc {got:04x} != {want:04x}, nothing written")
                return send(NACK, bytes([NACK_ROUTINE_CRC]))
            self.routine = self.staging
            self.staging = None
            print(f"    committed {len(self.routine)} blocks to EEPROM")
            send(STATUS, self.status_payload())
        elif cmd == ROUTINE_GET:
            for i, block in enumerate(self.routine):
                send(ROUTINE_BLOCK_REPLY, bytes([i]) + block.pack())
        elif cmd == STATUS_REQ:
            send(STATUS, self.status_payload())
        elif cmd == LOG_REQ:
            if len(payload) != 1:
                return send(NACK, bytes([NACK_BAD_LENGTH]))
            days = max(1, min(payload[0], self.log_days))
            for entry in self.logs[-days:]:
                send(LOG_ENTRY, entry.pack())
        elif cmd == PHONE_HEARTBEAT:
            if len(payload) != 2:
                return send(NACK, bytes([NACK_BAD_LENGTH]))
            self.phone_locked = bool(payload[0])
        elif cmd == CONFIG_SET:
            i = 0
            while i + 1 < len(payload):
                key, ln = payload[i], payload[i + 1]
                value = int.from_bytes(payload[i + 2:i + 2 + ln], "little")
                self.config[key] = value
                print(f"    config 0x{key:02x} = {value}")
                i += 2 + ln
        elif cmd == CONTROL:
            if len(payload) != 2:
                return send(NACK, bytes([NACK_BAD_LENGTH]))
            self._control(payload[0], payload[1])
            send(STATUS, self.status_payload())
        else:
            # §2: unknown CMD is logged and ignored, never an error.
            print(f"    unknown cmd 0x{cmd:02x}, ignored")
            send(NACK, bytes([NACK_UNKNOWN_CMD]))

    def _control(self, action: int, arg: int):
        if action == 0 and self.state == 2:
            self._tick()
            self.state, self.mood = 3, 1
        elif action == 1 and self.state == 3:
            self.state, self.mood, self.started_at = 2, 0, time.monotonic()
        elif action in (2, 4):
            self._start(arg if action == 4 else self.block_idx + 1)
        elif action == 3:
            self.state, self.block_idx, self.secs_left = 0, 0xFF, 0

    def _start(self, index: int):
        if not (0 <= index < len(self.routine)):
            self.state, self.block_idx, self.secs_left = 4, 0xFF, 0
            return
        self.block_idx = index
        self.secs_left = self.routine[index].duration_min * 60
        self.state, self.mood = 2, 0
        self.started_at = time.monotonic()


def run_device(link, device: Device, quiet: bool):
    def send(cmd, payload=b""):
        frame = encode(cmd, payload)
        if not quiet:
            print(f"D→A {CMD_NAMES.get(cmd, hex(cmd)):<20} {hexdump(frame)}")
        link.write(frame)

    parser = Parser(on_drop=lambda why: print(f"!!  dropped: {why}"))
    print(f"device mode on {link.description} — waiting for HELLO")
    try:
        while True:
            data = link.read()
            if data:
                for cmd, payload in parser.feed(data):
                    if not quiet:
                        print(f"A→D {CMD_NAMES.get(cmd, hex(cmd)):<20} "
                              f"{hexdump(payload)}")
                    device.handle(cmd, payload, send)
            else:
                parser.resync_if_stale()
                time.sleep(0.01)
    except (KeyboardInterrupt, ConnectionResetError, BrokenPipeError):
        print("\nlink closed")
    finally:
        link.close()


# --------------------------------------------------------------------------
# app mode — pretend to be the phone, against real firmware
# --------------------------------------------------------------------------

STATES = ["IDLE", "ARMED", "RUNNING", "PAUSED", "COMPLETE", "BROKEN"]
MOODS = ["CALM", "SEARCHING", "SAD", "HAPPY", "SLEEPY"]

DEMO_ROUTINE = [
    Block("Deep Work", "Phone in the drawer", 90, 0, True, 5 * 60 + 30),
    Block("Break", "Walk, water", 15, 4),
    Block("Output", "Write it up", 60, 2, True),
]


def run_app(link, push: bool, seconds: int):
    parser = Parser(on_drop=lambda why: print(f"!!  dropped: {why}"))
    pending = []

    def send(cmd, payload=b""):
        frame = encode(cmd, payload)
        print(f"→ {CMD_NAMES.get(cmd, hex(cmd)):<20} {hexdump(frame)}")
        link.write(frame)

    def pump(timeout=1.0):
        """Reads for *timeout* seconds, returning the frames that arrived."""
        got = []
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            data = link.read()
            if data:
                for frame in parser.feed(data):
                    print(f"← {CMD_NAMES.get(frame[0], hex(frame[0])):<20} "
                          f"{hexdump(frame[1])}")
                    got.append(frame)
            else:
                parser.resync_if_stale()
                time.sleep(0.01)
        return got + pending

    print(f"app mode on {link.description} — §12 handshake")
    send(HELLO)
    frames = pump(2.0)
    ack = next((p for c, p in frames if c == HELLO_ACK), None)
    if ack is None or len(ack) != 8:
        sys.exit("no HELLO_ACK — wrong baud, wrong port, or the device is mute")
    print(f"    proto {ack[0]}  fw {ack[1]}.{ack[2]}  id {ack[3]}  "
          f"caps {ack[4]:08b}/{ack[5]:08b}  logs {ack[6]}  blocks {ack[7]}")

    now = time.localtime()
    send(SET_TIME, bytes([
        now.tm_year % 100, now.tm_mon, now.tm_mday,
        now.tm_hour, now.tm_min, now.tm_sec, (now.tm_wday + 1) % 7,
    ]))

    send(LOG_REQ, bytes([30]))
    for cmd, payload in pump(1.5):
        if cmd == LOG_ENTRY and len(payload) == 12:
            date_code, verified, claimed, done, total, violations = struct.unpack(
                "<HHHBBB", payload[:9])
            print(f"    day {date_code}: {verified}/{claimed} min, "
                  f"{done}/{total} blocks, {violations} violations")

    if push:
        print(f"pushing {len(DEMO_ROUTINE)} blocks")
        send(ROUTINE_BEGIN, bytes([len(DEMO_ROUTINE)]))
        for i, block in enumerate(DEMO_ROUTINE):
            send(ROUTINE_BLOCK, bytes([i]) + block.pack())
        crc = crc16_xmodem(b"".join(b.pack() for b in DEMO_ROUTINE))
        send(ROUTINE_COMMIT, bytes([crc & 0xFF, crc >> 8]))
        for cmd, payload in pump(4.0):
            if cmd == NACK:
                print(f"!!  push refused, reason 0x{payload[0]:02x} — "
                      f"the device kept its previous routine")
            elif cmd == STATUS:
                print("    committed")

    print(f"polling status for {seconds} s")
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        send(STATUS_REQ)
        for cmd, payload in pump(1.0):
            if cmd == STATUS and len(payload) == 12:
                state, idx, secs, verified, claimed, streak, mood, flags, batt = \
                    struct.unpack("<BBHHHBBBB", payload)
                bits = "".join(
                    n for n, b in
                    (("P", 0x01), ("D", 0x02), ("L", 0x04),
                     ("V", 0x08), ("T", 0x10), ("C", 0x20))
                    if flags & b
                )
                print(f"    {STATES[state] if state < 6 else state:<9} "
                      f"block {idx if idx != 0xFF else '-'}  {secs // 60:>3}m left  "
                      f"{verified}/{claimed} min  streak {streak}  "
                      f"{MOODS[mood] if mood < 5 else mood}  [{bits}]")
        time.sleep(4.0)
    link.close()


# --------------------------------------------------------------------------
# selftest — the §13 vectors, asserted here as they are in Dart and C
# --------------------------------------------------------------------------

def selftest() -> int:
    checks = [
        ("crc8 empty", crc8(b""), 0x00),
        ("crc8 00", crc8(b"\x00"), 0x00),
        ("crc8 01", crc8(b"\x01"), 0x07),
        ("crc8 123456789", crc8(b"123456789"), 0xF4),
        ("crc8 01 00", crc8(b"\x01\x00"), 0x15),
        ("crc16 123456789", crc16_xmodem(b"123456789"), 0x31C3),
        ("HELLO frame", encode(HELLO), b"\xAA\x55\x01\x00\x15"),
        ("block size", len(Block("x").pack()), 48),
        ("daylog size", len(DayLog(1).pack()), 12),
    ]
    failures = 0
    for name, got, want in checks:
        ok = got == want
        failures += 0 if ok else 1
        shown = hexdump(got) if isinstance(got, bytes) else got
        print(f"{'ok  ' if ok else 'FAIL'} {name:<22} {shown}")

    # Round-trip a block through the wire form, including a 16-char name that
    # leaves no room for a NUL terminator.
    block = Block("ABCDEFGHIJKLMNOP", "desc", 90, 2, True, 330)
    back = Block.unpack(block.pack())
    if (back.name, back.duration_min, back.track, back.start_min) != (
            "ABCDEFGHIJKLMNOP", 90, True, 330):
        print(f"FAIL block round-trip     {back}")
        failures += 1
    else:
        print("ok   block round-trip")

    # And a frame through the parser, one byte at a time.
    parser = Parser()
    frames = []
    for byte in encode(STATUS, b"\x02\x01" + b"\x00" * 10):
        frames += parser.feed(bytes([byte]))
    if len(frames) != 1 or frames[0][0] != STATUS:
        print("FAIL parser round-trip")
        failures += 1
    else:
        print("ok   parser round-trip")

    print("\nall vectors match" if not failures else f"\n{failures} FAILED")
    return 1 if failures else 0


# --------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("mode", choices=["device", "app", "selftest"])
    ap.add_argument("--tcp", type=int, metavar="PORT",
                    help="listen (device) or connect (app) on 127.0.0.1:PORT")
    ap.add_argument("--serial", metavar="PORT", help="serial port path")
    ap.add_argument("--baud", type=int, default=9600, help="default 9600, §1")
    ap.add_argument("--push", action="store_true",
                    help="app mode: push the demo routine")
    ap.add_argument("--seconds", type=int, default=30,
                    help="app mode: how long to poll status")
    ap.add_argument("--quiet", action="store_true", help="hide the hex log")
    args = ap.parse_args()

    if args.mode == "selftest":
        return selftest()

    if not args.tcp and not args.serial:
        ap.error("give --tcp PORT or --serial PATH")

    if args.mode == "device":
        device = Device()
        device.routine = list(DEMO_ROUTINE)
        # §7: date_code is days since 2026-01-01, in local terms — computing it
        # from epoch seconds lands a day out on either side of UTC.
        today = (datetime.date.today() - datetime.date(2026, 1, 1)).days
        device.logs = [
            DayLog(today - i, 240 - i * 20, 300 - i * 15, 6, 8, i % 3)
            for i in range(9, -1, -1)
        ]
        if args.serial:
            run_device(SerialLink(args.serial, args.baud), device, args.quiet)
            return 0
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", args.tcp))
        server.listen(1)
        print(f"listening on 127.0.0.1:{args.tcp} — ctrl-C to stop")
        try:
            while True:
                conn, peer = server.accept()
                run_device(TcpLink(conn, peer), device, args.quiet)
        except KeyboardInterrupt:
            print("\nstopped")
        return 0

    if args.serial:
        link = SerialLink(args.serial, args.baud)
    else:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(("127.0.0.1", args.tcp))
        link = TcpLink(sock, ("127.0.0.1", args.tcp))
    run_app(link, args.push, args.seconds)
    return 0


if __name__ == "__main__":
    sys.exit(main())
