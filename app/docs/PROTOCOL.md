# FocusFreak Wire Protocol — v1

**This file is the contract.** The firmware's `proto.cpp` and the app's
`lib/device/protocol.dart` are both written from this document. Neither side may
change a byte layout without changing this file in the same commit.

Frozen for v1, with one documented extension (§4, `HELLO_ACK` capabilities).

---

## 1. Physical layer

| | |
|---|---|
| Link | HC-05, Bluetooth Classic SPP |
| SPP UUID | `00001101-0000-1000-8000-00805F9B34FB` |
| Baud | 9600, 8N1 |
| Device side | Arduino Mega `Serial2` — TX2 = D16, RX2 = D17 |
| Device name | `FocusFreak`, or `HC-05` before it is renamed |

9600 is deliberate. The whole payload is small — a full 16-block routine push is
16 × 49 = 784 B ≈ 0.8 s — and HC-05 clones throw framing errors at higher rates.

**The transport is not part of the contract.** These same frames run unchanged
over an HM-10 (BLE) module, over TCP to the desktop simulator, or over an
in-process loopback that drives the app's virtual bot. Both HC-05 and HM-10 are
transparent UART bridges; swapping them changes zero firmware lines and one line
in the app.

---

## 2. Frame format

```
┌──────┬──────┬─────┬─────┬─────────────┬──────┐
│ 0xAA │ 0x55 │ CMD │ LEN │ PAYLOAD     │ CRC8 │
│  1B  │  1B  │ 1B  │ 1B  │ 0..64 B     │  1B  │
└──────┴──────┴─────┴─────┴─────────────┴──────┘
```

* `LEN` is the payload length only, 0..64.
* `CRC8` is polynomial `0x07`, init `0x00`, computed over `CMD + LEN + PAYLOAD`
  (**not** over the `0xAA 0x55` preamble).
* Multi-byte integers are **little-endian**, matching AVR.
* Strings are fixed-width, NUL-padded, not NUL-terminated. A 16-byte name field
  holds exactly 16 bytes on the wire regardless of content.

### Receive state machine

```
WAIT_AA → WAIT_55 → READ_CMD → READ_LEN → READ_PAYLOAD → READ_CRC → dispatch
```

Two rules that are not optional on either side:

1. **200 ms inter-byte timeout.** In any state past `WAIT_AA`, if no byte
   arrives for 200 ms, reset to `WAIT_AA`. Without this, one corrupt byte wedges
   the parser permanently and the link appears dead until a power cycle.
2. **Unknown `CMD` is logged and ignored, never an error.** This is what makes
   the protocol forward-compatible: a newer app talking to older firmware, or the
   reverse, degrades instead of failing.

`LEN > 64` is treated as corruption — drop and resync.

---

## 3. Command table

Direction `A→D` is app to device, `D→A` is device to app. Reply codes have the
high bit set.

| CMD | Dir | Payload | Meaning |
|---|---|---|---|
| `0x01` | A→D | — | HELLO |
| `0x81` | D→A | 8 B | HELLO_ACK — see §4 |
| `0x10` | A→D | 7 B | SET_TIME: `yy mm dd hh mm ss dow` |
| `0x20` | A→D | 1 B | ROUTINE_BEGIN: block count, 0..16 |
| `0x21` | A→D | 49 B | ROUTINE_BLOCK: `idx` + Block struct — see §5 |
| `0x22` | A→D | 2 B | ROUTINE_COMMIT: crc16 over all blocks |
| `0x23` | A→D | — | ROUTINE_GET |
| `0xA3` | D→A | 49 B | ROUTINE_BLOCK, streamed reply |
| `0x30` | A→D | — | STATUS_REQ |
| `0xB0` | D→A | 12 B | STATUS — see §6 |
| `0x31` | A→D | — | SENSOR_REQ |
| `0xB1` | D→A | 12 B | SENSORS — see §6a |
| `0x40` | A→D | 1 B | LOG_REQ: how many days, 1..30 |
| `0xC0` | D→A | 12 B | LOG_ENTRY, streamed DayLog — see §7 |
| `0x50` | A→D | 2 B | PHONE_HEARTBEAT: `screen_locked`, `batt_pct` |
| `0x60` | A→D | n B | CONFIG_SET — see §8 |
| `0x70` | A→D | 2 B | CONTROL: `action`, `arg` — see §9 |
| `0x71` | A→D | 1 B | INPUT: press a control — see §9a |
| `0x72` | A→D | 2 B | LAUNCH: open a BotOS app — see §9a |
| `0xE0` | D→A | 1 B | NACK: reason code — see §10 |

---

## 4. `0x81` HELLO_ACK — 8 bytes

**Extended from the original 4-byte version.**

The reason: the app must not hard-code which sensors the bot has. If the
HC-SR04 is swapped for a VL53L0X, the servo is dropped for battery reasons, or a
sound sensor is added later, the app has to keep working without a rebuild. The
device declares what it has; the app renders only that.

```
[0] proto_version      currently 0x01
[1] fw_major
[2] fw_minor
[3] device_id          arbitrary per-unit id, for multi-unit demos
[4] caps_lo            bit0 PRESENCE    bit1 DOCK
                       bit2 LIGHT       bit3 TEMP_HUM
                       bit4 TOUCH       bit5 LED_RING
                       bit6 SERVO       bit7 BUZZER
[5] caps_hi            bit0 RTC         bit1 BATTERY
                       bit2 SOUND       bit3 TOUCHSCREEN
                       bit4 ENCODER     bit5 BUTTON
                       bit6 SENSOR_FRAME (answers 0x31)
                       bit7 BOTOS       (takes 0x71 INPUT, 0x72 LAUNCH)
[6] eeprom_log_days    how many DayLog entries the ring buffer holds (30)
[7] max_blocks         how many routine blocks fit in EEPROM (16)
```

Rules:

* A capability bit means **the sensor exists and its driver reported healthy at
  boot**, not merely that the firmware was compiled with support.
* The app must treat a cleared bit as "this factor is unavailable" and neither
  display it nor count it — never as "this factor failed".
* `max_blocks` and `eeprom_log_days` are read from the device rather than
  assumed, so a firmware build with a larger EEPROM map needs no app change.
* Reserved bits are zero. The app must mask rather than compare, so setting a
  reserved bit later does not break an older app.
* bits 4..7 of `caps_hi` were reserved in v1 and were assigned on 26 September
  2026 for BotOS. Both bytes are now full: the next capability needs a new
  byte appended to HELLO_ACK, which older apps ignore by length.

The final build (`FinalBuildPlan.md`, `firmware/focusfreak/proto.cpp`)
declares `caps_lo = 0xDD` (presence, light, temp/hum, touch, the SG90 servo
ear, buzzer) and `caps_hi = 0xF1` (RTC, encoder, button, sensor frame,
BotOS). It has no IR phone spot (so no dock), no LED ring and no
touchscreen. Presence, temp/hum and RTC are set only when that part answered
at boot: an HC-SR04 that never echoed is not declared.

`proto_version` mismatch is a warning, not a disconnect. The app shows a banner
and continues with the commands both sides share.

---

## 5. `Block` — 48 bytes on the wire

Matches the firmware struct (`firmware/focusfreak/store.h`) exactly.

```
offset size field
  0     16   char     name[16]        NUL-padded, not terminated
 16     24   char     desc[24]        NUL-padded, not terminated
 40      2   uint16   duration_min
 42      1   uint8    category        0..5, see §11
 43      1   uint8    flags           bit0 = track enabled; bits 1..7 reserved
 44      2   uint16   start_min       minutes since midnight; 0xFFFF = run
                                      sequentially after the previous block
 46      2   uint16   reserved        must be 0
                                      ------
                                      48 B
```

`0x21 ROUTINE_BLOCK` carries **49 bytes**: a 1-byte index followed by the 48-byte
struct.

Because `name` and `desc` are fixed-size, the app enforces 16/24 character limits
in its editor. Longer strings are rejected at input time, never silently
truncated on push.

---

## 6. `0xB0` STATUS — 12 bytes

```
offset size field
  0      1   uint8    state           0 IDLE 1 ARMED 2 RUNNING 3 PAUSED
                                      4 COMPLETE 5 BROKEN
  1      1   uint8    block_idx       0xFF when no block is active
  2      2   uint16   secs_left
  4      2   uint16   vfm_today       verified focus minutes
  6      2   uint16   claimed_today   minutes elapsed in tracked blocks
  8      1   uint8    streak
  9      1   uint8    mood            0 CALM 1 SEARCHING 2 SAD 3 HAPPY 4 SLEEPY
 10      1   uint8    flags           bit0 present    bit1 docked
                                      bit2 phone_locked  bit3 verified
                                      bit4 track_enabled bit5 charging
 11      1   uint8    batt_pct        0xFF when no battery monitoring
                                      ------
                                      12 B
```

`flags` bits 0..2 are the three verification channels; bit3 is the device's own
conclusion. The app displays all four rather than recomputing bit3 — if they ever
disagree, that is a firmware bug worth seeing rather than hiding.

A verification bit whose capability is absent in `HELLO_ACK` must be ignored.

---

## 6a. `0xB1` SENSORS — 12 bytes

What the sensors read now, sent in answer to `0x31 SENSOR_REQ`. Every field has
a "no reading" value: a bot without a sensor, or one whose sensor did not
answer, says so rather than sending a zero the app would believe.

```
offset size field
  0      2   int16    temp_centi_c    SHT21, °C × 100     0x7FFF = none
  2      2   uint16   humidity_permil SHT21, %RH × 10     0xFFFF = none
  4      2   uint16   light           LDR A8, 0..1023     0xFFFF = none
  6      2   uint16   distance_cm     HC-SR04             0xFFFF = no echo
  8      2   uint16   ir              TCRT5000, 0..1023, lower = closer
                                                          0xFFFF = none
                                      (always none: no IR in the build)
 10      1   uint8    flags           bit0 dark (LDR level below 150)
                                      bit1 phone_parked (IR below threshold)
 11      1   int8     rtc_temp_c      DS3231's own sensor 0x7F = none
                                      ------
                                      12 B
```

The app asks every 5 s while connected; the Home tab and the bot's Room and
Desk screens show these.

---

## 7. `0xC0` LOG_ENTRY — 12 bytes

```
offset size field
  0      2   uint16   date_code       days since 2026-01-01
  2      2   uint16   verified_min
  4      2   uint16   claimed_min
  6      1   uint8    blocks_done
  7      1   uint8    blocks_total
  8      1   uint8    violations
  9      3   uint8    reserved[3]     must be 0
                                      ------
                                      12 B
```

The device holds 30 days. The phone is the permanent archive, so the app pulls
logs on every connect and merges by `date_code`.

---

## 8. `0x60` CONFIG_SET

Type-length-value, so either side can add a key without breaking the other.
Unknown keys are skipped using their own length field.

```
repeated: [key:1][len:1][value:len]

key 0x01  brightness       1 B  0..255
key 0x02  sound_enabled    1 B  0 | 1
key 0x03  presence_min_cm  1 B
key 0x04  presence_max_cm  1 B
key 0x05  grace_running_s  1 B
key 0x06  grace_paused_s   2 B
key 0x07  led_brightness   1 B  0..255
key 0x08  theme            1 B
key 0x09  auto_pause       1 B  0 | 1   stepping away pauses the countdown
                                        (default 0, as the app's own engine)
```

---

## 9. `0x70` CONTROL — 2 bytes

```
[0] action   0 pause · 1 resume · 2 skip · 3 stop · 4 start
[1] arg      block index for action 4; 0 otherwise
```

**A pause the user asked for is only ended by the user.** Both sides run a
state machine that also pauses on its own when verification drops, and that one
*does* resume by itself when the conditions come back. The two must not be
confused: a device that resumes a `CONTROL(0)` pause on its next sensor read
makes its own pause button look broken. The app hit exactly this bug on
2 August 2026 — one tick after the manual pause, verification was holding, and
the session resumed itself.

Keep a flag for which kind of pause is in effect. `0xB0 STATUS` does not carry
it today; the app tracks its own, and the device must track its own.

---

## 9a. `0x71` INPUT and `0x72` LAUNCH

The phone as a remote for the bot's own controls, so the virtual bot's knob in
the app turns the real one.

```
0x71 INPUT   [0] key    0 LEFT (encoder anticlockwise)   1 RIGHT
                        2 PRESS (encoder switch)          3 HOLD (switch, 0.6 s)
                        4 BUTTON (push button)            5 TOUCH_LEFT
                        6 TOUCH_RIGHT                     7 TOUCH_FRONT

0x72 LAUNCH  [0] app    0 HOME  1 MENU  2 FOCUS_TIMER  3 MUSIC  4 GAMES
                        5 DINO  6 BREAKOUT  7 REACTION  8 ROOM  9 SETTINGS
                        10 SNAKE  11 BLOCKS  12 FLAP  13 PADDLE
                        14 STAR_RAID  15 G2048  16 ALARMS
             [1] arg    FOCUS_TIMER: minutes; MUSIC: 1-based melody index,
                        0 = just open the list; otherwise 0
```

10 and up were added on 27 September 2026, appended so older values keep
their meaning. A bot that does not have an app ignores the LAUNCH; the Mega
only needs the games and tunes it was flashed with.

Neither is answered. The next STATUS shows the effect. Both indices are the
BotOS enums (`lib/botos/world.dart` `BotKey`, `lib/botos/os.dart` `BotApp`);
the firmware port keeps the same order.

---

## 10. `0xE0` NACK reason codes

```
0x01 CRC_FAIL
0x02 BAD_LENGTH
0x03 UNKNOWN_CMD          informational; the device still ignores and continues
0x04 ROUTINE_SEQUENCE     a BLOCK or COMMIT arrived without a BEGIN
0x05 ROUTINE_CRC          the COMMIT crc16 did not match the blocks received
0x06 EEPROM_WRITE_FAIL
0x07 BUSY
0x08 OUT_OF_RANGE
```

---

## 11. Categories

The index is the wire value, the display order, and the colour index. It is the
same number in the firmware, the app, the LED ring and the PDF reports.

| id | Category | RGB565 |
|---|---|---|
| 0 | Deep Work | `0x1A5F` |
| 1 | Active Work | `0x0651` |
| 2 | Output / Practice | `0xFC00` |
| 3 | Routine (salat, meal, hygiene) | `0x2664` |
| 4 | Nap + Buffer | `0x8817` |
| 5 | Sleep | `0x4208` |

---

## 12. Key sequences

### Routine push — atomic

```
app → 0x20 ROUTINE_BEGIN (n)
app → 0x21 ROUTINE_BLOCK (0)
        …
app → 0x21 ROUTINE_BLOCK (n-1)
app → 0x22 ROUTINE_COMMIT (crc16 over all n blocks, in index order)

device: crc ok   → write EEPROM → reply 0xB0 STATUS
device: crc fail → reply 0xE0 NACK(0x05); the app retries the whole push once
```

**The device must not write EEPROM before COMMIT.** A half-written routine is a
corrupt device, and the user's only recovery would be a factory reset.

### Heartbeat

The app sends `0x50` every 10 s, and **only while a tracked block is running** —
there is nothing to verify otherwise and the radio should stay quiet. If the
device sees no heartbeat for 25 s it treats `phone_locked` as false.

### Connect handshake

```
app → 0x01 HELLO
dev → 0x81 HELLO_ACK           app records capabilities
app → 0x10 SET_TIME            phone clock is authoritative on connect
app → 0x40 LOG_REQ (30)        pull history before it rolls out of EEPROM
dev → 0xC0 LOG_ENTRY × n
app → 0x30 STATUS_REQ          then poll every 5 s
```

---

## 13. CRC8

Polynomial `0x07`, init `0x00`, no reflection, no final XOR.

```c
uint8_t crc8(const uint8_t *d, uint8_t n) {
    uint8_t c = 0x00;
    while (n--) {
        c ^= *d++;
        for (uint8_t i = 0; i < 8; i++)
            c = (c & 0x80) ? (c << 1) ^ 0x07 : (c << 1);
    }
    return c;
}
```

Test vectors, asserted on both sides:

| Input | CRC8 |
|---|---|
| `""` (empty) | `0x00` |
| `0x00` | `0x00` |
| `0x01` | `0x07` |
| `"123456789"` (ASCII) | `0xF4` |
| `0x01 0x00` | `0x15` |

The routine COMMIT uses **CRC-16/XMODEM** (poly `0x1021`, init `0x0000`) over the
concatenated 48-byte block structs, not CRC8.

---

## 14. Logging

Both sides log every frame as hex, in both directions, behind a filterable tag
(`FF-WIRE` in Logcat, `[wire]` in the Dart logs). When an integration bug appears
at 2 a.m. in week 4, these two logs side by side are the only thing that resolves
it quickly.
