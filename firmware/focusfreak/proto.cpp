#include "proto.h"

#include "os.h"
#include "pins.h"
#include "sensors.h"
#include "session.h"
#include "store.h"

#define FW_MAJOR 1
#define FW_MINOR 0
#define PROTO_VERSION 1
#define DEVICE_ID 1

namespace Proto {

enum Cmd : uint8_t {
  C_HELLO = 0x01, C_HELLO_ACK = 0x81,
  C_SET_TIME = 0x10,
  C_ROUTINE_BEGIN = 0x20, C_ROUTINE_BLOCK = 0x21, C_ROUTINE_COMMIT = 0x22, C_ROUTINE_GET = 0x23,
  C_ROUTINE_BLOCK_REPLY = 0xA3,
  C_STATUS_REQ = 0x30, C_STATUS = 0xB0,
  C_SENSOR_REQ = 0x31, C_SENSORS = 0xB1,
  C_LOG_REQ = 0x40, C_LOG_ENTRY = 0xC0,
  C_PHONE_HEARTBEAT = 0x50,
  C_CONFIG_SET = 0x60,
  C_CONTROL = 0x70, C_INPUT = 0x71, C_LAUNCH = 0x72,
  C_NACK = 0xE0,
};

enum Nack : uint8_t {
  N_CRC_FAIL = 1, N_BAD_LENGTH, N_UNKNOWN_CMD, N_ROUTINE_SEQUENCE, N_ROUTINE_CRC,
  N_EEPROM_WRITE_FAIL, N_BUSY, N_OUT_OF_RANGE,
};

// --- CRCs (section 13) -------------------------------------------------------

uint8_t crc8(const uint8_t *d, uint16_t n) {
  uint8_t c = 0;
  while (n--) {
    c ^= *d++;
    for (uint8_t i = 0; i < 8; i++) c = (c & 0x80) ? (c << 1) ^ 0x07 : (c << 1);
  }
  return c;
}

// CRC-16/XMODEM: poly 0x1021, init 0.
uint16_t crc16(const uint8_t *d, uint16_t n) {
  uint16_t c = 0;
  while (n--) {
    c ^= (uint16_t)(*d++) << 8;
    for (uint8_t i = 0; i < 8; i++) c = (c & 0x8000) ? (c << 1) ^ 0x1021 : (c << 1);
  }
  return c;
}

// --- links --------------------------------------------------------------------

enum RxState : uint8_t { WAIT_AA, WAIT_55, READ_CMD, READ_LEN, READ_PAYLOAD, READ_CRC };

struct Link {
  Stream *port;
  RxState state;
  uint8_t cmd;
  uint8_t len;
  uint8_t idx;
  uint8_t buf[64];
  uint32_t lastByte;
  uint32_t lastFrame;
};

static Link s_usb = {&Serial, WAIT_AA, 0, 0, 0, {}, 0, 0};
static Link s_bt = {&BT_SERIAL, WAIT_AA, 0, 0, 0, {}, 0, 0};

// The routine being pushed, held in RAM until COMMIT verifies: a half-written
// routine would be a corrupt device.
static uint8_t s_staging[MAX_BLOCKS * BLOCK_SIZE];
static uint8_t s_stagingCount = 0;
static uint16_t s_stagingMask = 0;
static bool s_stagingOpen = false;

static void send(Link &l, uint8_t cmd, const uint8_t *payload, uint8_t len) {
  uint8_t head[4] = {0xAA, 0x55, cmd, len};
  uint8_t crc = crc8(head + 2, 2);
  // CRC over CMD + LEN + PAYLOAD, continued.
  uint8_t c = crc;
  for (uint8_t i = 0; i < len; i++) {
    c ^= payload[i];
    for (uint8_t b = 0; b < 8; b++) c = (c & 0x80) ? (c << 1) ^ 0x07 : (c << 1);
  }
  l.port->write(head, 4);
  if (len) l.port->write(payload, len);
  l.port->write(c);
}

static void nack(Link &l, uint8_t reason) { send(l, C_NACK, &reason, 1); }

static void sendStatus(Link &l) {
  uint8_t p[12];
  Session_::statusPayload(p);
  send(l, C_STATUS, p, 12);
}

static void put16(uint8_t *p, uint16_t v) {
  p[0] = v & 0xFF;
  p[1] = v >> 8;
}

static void sendSensors(Link &l) {
  Sensors s;
  Sensors_::read(s);
  uint8_t p[12];
  put16(p + 0, s.hasTemp ? (uint16_t)(int16_t)lround(s.tempC * 100) : 0x7FFF);
  put16(p + 2, s.hasHum ? (uint16_t)lround(s.humidity * 10) : 0xFFFF);
  put16(p + 4, s.hasLight ? (uint16_t)s.light : 0xFFFF);
  put16(p + 6, s.hasDistance ? (uint16_t)s.distanceCm : 0xFFFF);
  put16(p + 8, 0xFFFF);  // no IR phone spot in this build
  p[10] = s.dark ? 0x01 : 0;
  p[11] = s.hasRtcTemp ? (uint8_t)(int8_t)lround(s.rtcTempC) : 0x7F;
  send(l, C_SENSORS, p, 12);
}

// Capability bits mean "fitted and answered at boot" (section 4).
static void sendHelloAck(Link &l) {
  uint8_t capsLo = 0;
  if (Sensors_::sonarOk()) capsLo |= 1 << 0;  // presence
  capsLo |= 1 << 2;                            // light
  if (Sensors_::shtOk()) capsLo |= 1 << 3;     // temperature and humidity
  capsLo |= 1 << 4;                            // touch
  capsLo |= 1 << 6;                            // servo (the ear)
  capsLo |= 1 << 7;                            // buzzer
  uint8_t capsHi = 0;
  if (Sensors_::rtcOk()) capsHi |= 1 << 0;  // RTC
  capsHi |= 1 << 4;                         // encoder
  capsHi |= 1 << 5;                         // button
  capsHi |= 1 << 6;                         // sensor frame
  capsHi |= 1 << 7;                         // BotOS
  uint8_t p[8] = {PROTO_VERSION, FW_MAJOR, FW_MINOR, DEVICE_ID, capsLo, capsHi, LOG_DAYS, MAX_BLOCKS};
  send(l, C_HELLO_ACK, p, 8);
}

static void configSet(const uint8_t *p, uint8_t n) {
  BotSettings &s = os.settings;
  uint8_t i = 0;
  while (i + 2 <= n) {
    uint8_t key = p[i], len = p[i + 1];
    const uint8_t *v = p + i + 2;
    if (i + 2 + len > n) break;
    switch (key) {
      case 0x01: if (len >= 1) s.brightness = v[0] < 86 ? 0 : (v[0] < 171 ? 1 : 2); break;
      case 0x02: if (len >= 1) s.sound = v[0] != 0; break;
      case 0x03: if (len >= 1 && v[0] > 0) s.presenceMin = v[0]; break;
      case 0x04: if (len >= 1 && v[0] > 0) s.presenceMax = v[0]; break;
      case 0x05: if (len >= 1) s.graceRunningS = v[0]; break;
      case 0x06: if (len >= 2) s.gracePausedS = v[0] | (v[1] << 8); break;
      case 0x09: if (len >= 1) s.autoPause = v[0] != 0; break;
      default: break;  // unknown keys are skipped by their own length
    }
    i += 2 + len;
  }
  if (s.presenceMax <= s.presenceMin) s.presenceMax = s.presenceMin + 1;
  os.saveSettings();
}

static void dispatch(Link &l) {
  const uint8_t *p = l.buf;
  uint8_t n = l.len;
  switch (l.cmd) {
    case C_HELLO:
      sendHelloAck(l);
      break;

    case C_SET_TIME:
      if (n != 7) return nack(l, N_BAD_LENGTH);
      if (p[1] < 1 || p[1] > 12 || p[2] < 1 || p[2] > 31 || p[3] > 23 || p[4] > 59 || p[5] > 59) {
        return nack(l, N_OUT_OF_RANGE);
      }
      Sensors_::setTime(2000 + p[0], p[1], p[2], p[3], p[4], p[5]);
      break;

    case C_ROUTINE_BEGIN:
      if (n != 1) return nack(l, N_BAD_LENGTH);
      if (p[0] > MAX_BLOCKS) return nack(l, N_OUT_OF_RANGE);
      if (Store::routineWriting()) return nack(l, N_BUSY);
      s_stagingCount = p[0];
      s_stagingMask = 0;
      s_stagingOpen = true;
      break;

    case C_ROUTINE_BLOCK:
      if (!s_stagingOpen) return nack(l, N_ROUTINE_SEQUENCE);
      if (n != 1 + BLOCK_SIZE) return nack(l, N_BAD_LENGTH);
      if (p[0] >= s_stagingCount) return nack(l, N_OUT_OF_RANGE);
      memcpy(s_staging + (uint16_t)p[0] * BLOCK_SIZE, p + 1, BLOCK_SIZE);
      s_stagingMask |= 1 << p[0];
      break;

    case C_ROUTINE_COMMIT: {
      if (!s_stagingOpen) return nack(l, N_ROUTINE_SEQUENCE);
      if (n != 2) return nack(l, N_BAD_LENGTH);
      uint16_t want = p[0] | (p[1] << 8);
      uint16_t all = s_stagingCount >= 16 ? 0xFFFF : (1 << s_stagingCount) - 1;
      // A block that never arrived cannot be checksummed: a gap fails here.
      if ((s_stagingMask & all) != all) return nack(l, N_ROUTINE_CRC);
      if (crc16(s_staging, (uint16_t)s_stagingCount * BLOCK_SIZE) != want) return nack(l, N_ROUTINE_CRC);
      s_stagingOpen = false;
      Store::commitRoutine(s_staging, s_stagingCount);
      Session_::routinePushed();
      sendStatus(l);
      break;
    }

    case C_ROUTINE_GET: {
      uint8_t count = Session_::activeCount();
      uint8_t out[1 + BLOCK_SIZE];
      for (uint8_t i = 0; i < count; i++) {
        out[0] = i;
        Session_::activeBlockBytes(i, out + 1);
        send(l, C_ROUTINE_BLOCK_REPLY, out, sizeof(out));
      }
      break;
    }

    case C_STATUS_REQ:
      sendStatus(l);
      break;

    case C_SENSOR_REQ:
      sendSensors(l);
      break;

    case C_LOG_REQ: {
      if (n != 1) return nack(l, N_BAD_LENGTH);
      uint8_t days = p[0] < 1 ? 1 : (p[0] > LOG_DAYS ? LOG_DAYS : p[0]);
      uint16_t today = Session_::today();
      for (int16_t back = days - 1; back >= 0; back--) {
        if (back > today) continue;
        DayLog d;
        if (!Session_::logFor(today - back, d)) continue;
        uint8_t out[12];
        put16(out + 0, d.date);
        put16(out + 2, d.verifiedMin);
        put16(out + 4, d.claimedMin);
        out[6] = d.blocksDone;
        out[7] = d.blocksTotal;
        out[8] = d.violations;
        out[9] = out[10] = out[11] = 0;
        send(l, C_LOG_ENTRY, out, 12);
      }
      break;
    }

    case C_PHONE_HEARTBEAT:
      if (n != 2) return nack(l, N_BAD_LENGTH);
      Session_::heartbeat(p[0] != 0);
      break;

    case C_CONFIG_SET:
      configSet(p, n);
      break;

    case C_CONTROL:
      if (n != 2) return nack(l, N_BAD_LENGTH);
      switch (p[0]) {
        case 0: Session_::pause(); break;
        case 1: Session_::resume(); break;
        case 2: Session_::skip(); break;
        case 3: Session_::stop(); break;
        case 4: Session_::startBlock(p[1]); break;
        default: break;  // unknown action: ignored
      }
      sendStatus(l);
      break;

    case C_INPUT:
      if (n != 1) return nack(l, N_BAD_LENGTH);
      if (p[0] < K_COUNT) os.key((BotKey)p[0], millis());
      break;

    case C_LAUNCH:
      if (n != 2) return nack(l, N_BAD_LENGTH);
      if (p[0] < APP_COUNT) os.launch((BotApp)p[0], p[1]);
      break;

    default:
      // Forward compatible: an unknown command is ignored, never an error.
      // The C_NACK is informational.
      nack(l, N_UNKNOWN_CMD);
      break;
  }
}

static void feed(Link &l, uint8_t b, uint32_t now) {
  // 200 ms inter-byte timeout: one corrupt byte must not wedge the parser.
  if (l.state != WAIT_AA && now - l.lastByte > 200) l.state = WAIT_AA;
  l.lastByte = now;
  switch (l.state) {
    case WAIT_AA:
      if (b == 0xAA) l.state = WAIT_55;
      break;
    case WAIT_55:
      l.state = b == 0x55 ? READ_CMD : (b == 0xAA ? WAIT_55 : WAIT_AA);
      break;
    case READ_CMD:
      l.cmd = b;
      l.state = READ_LEN;
      break;
    case READ_LEN:
      if (b > 64) {  // corruption: drop and resync
        l.state = WAIT_AA;
        break;
      }
      l.len = b;
      l.idx = 0;
      l.state = b ? READ_PAYLOAD : READ_CRC;
      break;
    case READ_PAYLOAD:
      l.buf[l.idx++] = b;
      if (l.idx >= l.len) l.state = READ_CRC;
      break;
    case READ_CRC: {
      l.state = WAIT_AA;
      uint8_t hdr[2] = {l.cmd, l.len};
      uint8_t c = crc8(hdr, 2);
      for (uint8_t i = 0; i < l.len; i++) {
        c ^= l.buf[i];
        for (uint8_t k = 0; k < 8; k++) c = (c & 0x80) ? (c << 1) ^ 0x07 : (c << 1);
      }
      if (c != b) break;  // a bad frame is dropped; the app retries
      l.lastFrame = now;
      dispatch(l);
      break;
    }
  }
}

static void poll(Link &l) {
  uint32_t now = millis();
  // Bounded, so a flood of bytes cannot starve the face.
  for (uint8_t i = 0; i < 96 && l.port->available(); i++) feed(l, (uint8_t)l.port->read(), now);
}

void begin() {}

void update() {
  poll(s_bt);
  poll(s_usb);
}

bool btActive() { return s_bt.lastFrame && millis() - s_bt.lastFrame < 15000UL; }

}  // namespace Proto
