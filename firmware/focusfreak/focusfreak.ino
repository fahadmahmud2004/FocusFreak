// FocusFreak firmware 1.0 — Arduino Mega 2560.
//
// BotOS (the same screens, games, music and alarms as the app's virtual bot)
// on the 2.42" OLED, the focus session engine with verification, routines in
// EEPROM, 30 days of logs, and the app link over the HC-05.
//
// Wiring: docs/WIRING.md. Pins: pins.h. Protocol:
// app/docs/PROTOCOL.md. Assets (icons, tunes, routines) are generated from
// the Dart BotOS by app/tools/make_firmware_assets.py.
//
// Libraries: U8g2, RTClib (Adafruit), Servo.
// Board: Tools > Board > Arduino Mega or Mega 2560.

#include <Wire.h>

#include "ear.h"
#include "gfx.h"
#include "host.h"
#include "os.h"
#include "pins.h"
#include "proto.h"
#include "sensors.h"
#include "session.h"
#include "sound.h"
#include "store.h"

static World g_world;
static Sensors g_sensors;
static uint32_t g_frameAt = 0;
static uint8_t g_contrast = 0;

// --- what BotOS asks for ------------------------------------------------------

void hostStartFocus(uint16_t minutes) { Session_::startQuick(minutes); }
void hostStartRoutine(uint8_t index) { Session_::startTemplate(index); }
void hostPauseFocus() { Session_::pause(); }
void hostResumeFocus() { Session_::resume(); }
void hostSkipBlock() { Session_::skip(); }
void hostStopFocus() { Session_::stop(); }
void hostSaveSettings() { Store::saveSettings(os.settings); }

void hostEarWiggle() {
  Ear::wiggle();
  Session_::pet();
}

// --- the world, each frame ----------------------------------------------------

static void buildWorld() {
  g_world.now = Sensors_::now();
  g_world.sensors = g_sensors;
  Session_::fill(g_world.session);
  g_world.mood = Session_::mood();
  g_world.linked = Sensors_::btLinked() || Proto::btActive();
  g_world.verifiedMinutesToday = Session_::verifiedMinutesToday();
  g_world.streak = Session_::streak();
}

static void readSensors() {
  Sensors_::read(g_sensors);
  g_sensors.presenceMin = os.settings.presenceMin;
  g_sensors.presenceMax = os.settings.presenceMax;
}

void setup() {
  Serial.begin(115200);
  BT_SERIAL.begin(BT_BAUD);

  // SS must be an output for the Mega to stay SPI master.
  pinMode(PIN_MEGA_SS, OUTPUT);
  digitalWrite(PIN_MEGA_SS, HIGH);

  gfx.begin();
  gfx.clear();
  gfx.strCenter(F_PRIMARY, 64, 36, "FocusFreak");
  gfx.send();

  Sound::begin();
  Store::begin(os.settings);
  Sensors_::begin();
  randomSeed(analogRead(A0) ^ micros());
  Session_::begin();
  Ear::begin();
  Proto::begin();
  os.begin();
  readSensors();

  Serial.println(F("FocusFreak firmware 1.0"));
}

void loop() {
  Proto::update();
  Sensors_::update();
  readSensors();

  BotKey k;
  uint32_t at;
  while (Sensors_::nextKey(k, at)) os.key(k, at);

  Session_::update(g_sensors);
  Ear::update();
  Sound::update();
  Store::update();

  // 25 frames a second, the rate BotOS is tuned for.
  uint32_t now = millis();
  if (now - g_frameAt >= 1000 / BotOs::fps) {
    g_frameAt = now;
    buildWorld();
    os.tick(g_world);
    uint8_t c = (uint8_t)lround(os.brightness() * 255);
    if (c < 8) c = 8;
    if (abs((int16_t)c - g_contrast) > 2) {
      g_contrast = c;
      gfx.contrast(c);
    }
    gfx.send();
  }
}
