#include "sensors.h"

#include <RTClib.h>
#include <Wire.h>

#include "pins.h"

// Quadrature steps per click of the knob. Most EC11 / KY-040 encoders make a
// full 4-step cycle per detent; set 2 if yours moves two items per click.
#define ENC_STEPS_PER_DETENT 4

namespace Sensors_ {

static RTC_DS3231 rtc;
static bool s_rtcOk = false;
static Clock s_now = {2026, 1, 1, 0, 0, 0, 4, 0};
static uint32_t s_clockAt = 0;         // millis of the last RTC read
static uint32_t s_softUnix = 0;        // fallback clock when the RTC is missing
static uint32_t s_softAt = 0;
static float s_rtcTemp = 0;
static bool s_hasRtcTemp = false;
static uint32_t s_rtcTempAt = 0;

// --- clock --------------------------------------------------------------------

static void fromDateTime(const DateTime &d) {
  s_now.year = d.year();
  s_now.month = d.month();
  s_now.day = d.day();
  s_now.hour = d.hour();
  s_now.minute = d.minute();
  s_now.second = d.second();
  uint8_t dow = d.dayOfTheWeek();  // 0 = Sunday
  s_now.weekday = dow == 0 ? 7 : dow;
  s_now.unix = d.unixtime();
}

static void readClock() {
  if (s_rtcOk) {
    DateTime d = rtc.now();
    // A DS3231 that stopped answering reads back garbage, not an error.
    if (d.year() >= 2020 && d.year() < 2100 && d.month() >= 1 && d.month() <= 12) {
      fromDateTime(d);
      return;
    }
  }
  uint32_t now = millis();
  s_softUnix += (now - s_softAt) / 1000;
  s_softAt = now - (now - s_softAt) % 1000;
  fromDateTime(DateTime(s_softUnix));
}

void setTime(uint16_t year, uint8_t month, uint8_t day, uint8_t hour, uint8_t minute, uint8_t second) {
  DateTime d(year, month, day, hour, minute, second);
  if (s_rtcOk) rtc.adjust(d);
  s_softUnix = d.unixtime();
  s_softAt = millis();
  fromDateTime(d);
}

const Clock &now() { return s_now; }
bool rtcOk() { return s_rtcOk; }

// --- SHT21 --------------------------------------------------------------------
//
// No-hold master mode: send the command, go away, and read the three bytes
// once the conversion is done (85 ms for temperature, 29 ms for humidity).

enum ShtStep : uint8_t { SHT_IDLE, SHT_TEMP, SHT_HUM };
static ShtStep s_shtStep = SHT_IDLE;
static uint32_t s_shtAt = 0;
static bool s_shtPresent = false;
static uint8_t s_shtFails = 0;
static bool s_hasTemp = false, s_hasHum = false;
static float s_temp = 0, s_hum = 0;

static bool shtCommand(uint8_t cmd) {
  Wire.beginTransmission(I2C_ADDR_SHT21);
  Wire.write(cmd);
  return Wire.endTransmission() == 0;
}

static uint8_t shtCrc(const uint8_t *d, uint8_t n) {
  uint8_t crc = 0;
  for (uint8_t i = 0; i < n; i++) {
    crc ^= d[i];
    for (uint8_t b = 0; b < 8; b++) crc = (crc & 0x80) ? (crc << 1) ^ 0x31 : (crc << 1);
  }
  return crc;
}

static bool shtRead(uint16_t &raw) {
  if (Wire.requestFrom((uint8_t)I2C_ADDR_SHT21, (uint8_t)3) != 3) return false;
  uint8_t d[3] = {(uint8_t)Wire.read(), (uint8_t)Wire.read(), (uint8_t)Wire.read()};
  if (shtCrc(d, 2) != d[2]) return false;
  raw = ((uint16_t)d[0] << 8 | d[1]) & 0xFFFC;
  return true;
}

static void shtFail() {
  s_shtStep = SHT_IDLE;
  if (++s_shtFails >= 3) {
    s_hasTemp = false;
    s_hasHum = false;
  }
}

static void updateSht(uint32_t now) {
  if (!s_shtPresent) return;
  switch (s_shtStep) {
    case SHT_IDLE:
      if (now - s_shtAt >= 5000 || !s_hasTemp) {
        if (now - s_shtAt < 1000 && s_shtFails) return;  // back off after a failure
        s_shtAt = now;
        if (shtCommand(0xF3)) s_shtStep = SHT_TEMP;
        else shtFail();
      }
      break;
    case SHT_TEMP:
      if (now - s_shtAt >= 90) {
        uint16_t raw;
        if (!shtRead(raw)) return shtFail();
        s_temp = -46.85f + 175.72f * raw / 65536.0f;
        s_hasTemp = true;
        s_shtAt = now;
        if (shtCommand(0xF5)) s_shtStep = SHT_HUM;
        else shtFail();
      }
      break;
    case SHT_HUM:
      if (now - s_shtAt >= 35) {
        uint16_t raw;
        if (!shtRead(raw)) return shtFail();
        float h = -6.0f + 125.0f * raw / 65536.0f;
        s_hum = h < 0 ? 0 : (h > 100 ? 100 : h);
        s_hasHum = true;
        s_shtFails = 0;
        s_shtStep = SHT_IDLE;
        s_shtAt = now;
      }
      break;
  }
}

bool shtOk() { return s_shtPresent && s_hasTemp; }

// --- HC-SR04 ------------------------------------------------------------------

static int16_t s_dist[5];
static uint8_t s_distN = 0, s_distI = 0;
static uint8_t s_misses = 0;
static bool s_sonarEver = false;
static bool s_hasDistance = false;
static int16_t s_distance = 0;
static uint32_t s_pingAt = 0;

static void ping() {
  digitalWrite(PIN_US_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_US_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_US_TRIG, LOW);
  // 15 ms is about 2.5 m there and back: far past the desk.
  uint32_t us = pulseIn(PIN_US_ECHO, HIGH, 15000UL);
  if (us == 0) {
    // One missed echo is noise; five in a row is nobody there.
    if (++s_misses >= 5) {
      s_hasDistance = false;
      s_distN = 0;
    }
    return;
  }
  s_misses = 0;
  s_sonarEver = true;
  s_dist[s_distI] = us / 58;
  s_distI = (s_distI + 1) % 5;
  if (s_distN < 5) s_distN++;
  // The median of the last five: one stray echo off a chair back does not
  // make the bot think you left.
  int16_t sorted[5];
  memcpy(sorted, s_dist, sizeof(sorted));
  for (uint8_t i = 1; i < s_distN; i++) {
    int16_t v = sorted[i];
    int8_t j = i - 1;
    while (j >= 0 && sorted[j] > v) {
      sorted[j + 1] = sorted[j];
      j--;
    }
    sorted[j + 1] = v;
  }
  s_distance = sorted[s_distN / 2];
  s_hasDistance = true;
}

bool sonarOk() { return s_sonarEver; }

// --- LDR ----------------------------------------------------------------------

static float s_light = -1;
static uint32_t s_lightAt = 0;

// --- controls -----------------------------------------------------------------

static volatile int16_t s_encRaw = 0;
static volatile uint8_t s_encState = 0;
static int16_t s_encDetent = 0;

static void encoderIsr() {
  static const int8_t table[16] = {0, -1, 1, 0, 1, 0, 0, -1, -1, 0, 0, 1, 0, 1, -1, 0};
  s_encState = ((s_encState << 2) | (digitalRead(PIN_ENC_CLK) << 1) | digitalRead(PIN_ENC_DT)) & 0x0F;
  s_encRaw += table[s_encState];
}

struct Debounced {
  uint8_t pin;
  bool activeLow;
  bool stable;
  bool last;
  uint32_t changedAt;

  // Returns true once per press, after the pin has been steady 25 ms.
  bool pressedEdge(uint32_t now, bool *released = nullptr) {
    bool v = digitalRead(pin) == (activeLow ? LOW : HIGH);
    if (v != last) {
      last = v;
      changedAt = now;
    }
    if (v != stable && now - changedAt >= 25) {
      stable = v;
      if (!v && released) *released = true;
      return v;
    }
    return false;
  }
};

static Debounced s_touchL = {PIN_TOUCH_TOP_L, false, false, false, 0};
static Debounced s_touchR = {PIN_TOUCH_TOP_R, false, false, false, 0};
static Debounced s_touchF = {PIN_TOUCH_FRONT, false, false, false, 0};
static Debounced s_button = {PIN_BUTTON, true, false, false, 0};
static Debounced s_encSw = {PIN_ENC_SW, true, false, false, 0};
static uint32_t s_swDownAt = 0;
static bool s_holdFired = false;

struct KeyEvent {
  BotKey key;
  uint32_t at;
};
static KeyEvent s_keys[12];
static uint8_t s_keyHead = 0, s_keyTail = 0;

static void pushKey(BotKey k, uint32_t at) {
  uint8_t next = (s_keyHead + 1) % 12;
  if (next == s_keyTail) return;  // full: drop rather than overwrite
  s_keys[s_keyHead] = {k, at};
  s_keyHead = next;
}

bool nextKey(BotKey &k, uint32_t &atMs) {
  if (s_keyTail == s_keyHead) return false;
  k = s_keys[s_keyTail].key;
  atMs = s_keys[s_keyTail].at;
  s_keyTail = (s_keyTail + 1) % 12;
  return true;
}

static void updateControls(uint32_t now) {
  noInterrupts();
  int16_t raw = s_encRaw;
  interrupts();
  // Floor division, so the first click either way needs the same travel.
  int16_t detent = raw >= 0 ? raw / ENC_STEPS_PER_DETENT : -((-raw + ENC_STEPS_PER_DETENT - 1) / ENC_STEPS_PER_DETENT);
  while (detent > s_encDetent) {
    pushKey(K_RIGHT, now);
    s_encDetent++;
  }
  while (detent < s_encDetent) {
    pushKey(K_LEFT, now);
    s_encDetent--;
  }

  if (s_touchL.pressedEdge(now)) pushKey(K_TOUCH_LEFT, now);
  if (s_touchR.pressedEdge(now)) pushKey(K_TOUCH_RIGHT, now);
  if (s_touchF.pressedEdge(now)) pushKey(K_TOUCH_FRONT, now);
  if (s_button.pressedEdge(now)) pushKey(K_BUTTON, now);

  // The knob's switch: a tap is PRESS, 0.6 s held is HOLD (and no PRESS).
  bool released = false;
  if (s_encSw.pressedEdge(now, &released)) {
    s_swDownAt = now;
    s_holdFired = false;
  }
  if (s_encSw.stable && !s_holdFired && now - s_swDownAt >= 600) {
    s_holdFired = true;
    pushKey(K_HOLD, now);
  }
  if (released && !s_holdFired) pushKey(K_PRESS, now);
}

// --- public -------------------------------------------------------------------

void begin() {
  pinMode(PIN_US_TRIG, OUTPUT);
  pinMode(PIN_US_ECHO, INPUT);
  pinMode(PIN_BT_STATE, INPUT);
  pinMode(PIN_TOUCH_TOP_L, INPUT);
  pinMode(PIN_TOUCH_TOP_R, INPUT);
  pinMode(PIN_TOUCH_FRONT, INPUT);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_ENC_SW, INPUT_PULLUP);
  pinMode(PIN_ENC_CLK, INPUT_PULLUP);
  pinMode(PIN_ENC_DT, INPUT_PULLUP);
  pinMode(PIN_RTC_SQW, INPUT_PULLUP);

  s_encState = (digitalRead(PIN_ENC_CLK) << 1) | digitalRead(PIN_ENC_DT);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_CLK), encoderIsr, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_DT), encoderIsr, CHANGE);

  Wire.begin();
  Wire.setClock(100000);
  Wire.setWireTimeout(3000, true);  // a stuck bus must not freeze the bot

  s_rtcOk = rtc.begin();
  if (s_rtcOk && rtc.lostPower()) {
    // The coin cell ran out: start from the build time until the app sets it.
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }
  s_softUnix = DateTime(F(__DATE__), F(__TIME__)).unixtime();
  s_softAt = millis();
  readClock();

  Wire.beginTransmission(I2C_ADDR_SHT21);
  s_shtPresent = Wire.endTransmission() == 0;
  if (s_shtPresent) shtCommand(0xFE);  // soft reset
  s_shtAt = millis();

  // Ten pings to see whether anything echoes.
  for (uint8_t i = 0; i < 10 && !s_sonarEver; i++) {
    ping();
    delay(30);
  }
}

void update() {
  uint32_t now = millis();
  updateControls(now);

  if (now - s_clockAt >= 250) {
    s_clockAt = now;
    readClock();
  }
  if (s_rtcOk && now - s_rtcTempAt >= 10000) {
    s_rtcTempAt = now;
    s_rtcTemp = rtc.getTemperature();
    s_hasRtcTemp = s_rtcTemp > -40 && s_rtcTemp < 85;
  }

  updateSht(now);
  updateControls(now);

  if (now - s_pingAt >= 100) {
    s_pingAt = now;
    ping();
  }

  if (now - s_lightAt >= 100) {
    s_lightAt = now;
    int16_t v = analogRead(PIN_LDR);
    s_light = s_light < 0 ? v : s_light * 0.8f + v * 0.2f;
  }
}

void read(Sensors &out) {
  out.hasTemp = s_hasTemp;
  out.tempC = s_temp;
  out.hasHum = s_hasHum;
  out.humidity = s_hum;
  out.hasLight = s_light >= 0;
  out.light = s_light < 0 ? 0 : (int16_t)lround(s_light);
  out.dark = out.hasLight && out.light < 150;
  out.hasDistance = s_hasDistance;
  out.distanceCm = s_distance;
  out.hasRtcTemp = s_hasRtcTemp;
  out.rtcTempC = s_rtcTemp;
}

bool btLinked() { return digitalRead(PIN_BT_STATE) == HIGH; }

}  // namespace Sensors_
