// What BotOS reads and what it asks for. Port of `lib/botos/world.dart`.
#pragma once
#include <Arduino.h>

// Every physical control. The value is the wire value of `0x71 INPUT`.
enum BotKey : uint8_t {
  K_LEFT = 0,         // encoder one detent anticlockwise
  K_RIGHT = 1,        // one detent clockwise
  K_PRESS = 2,        // encoder switch: select
  K_HOLD = 3,         // encoder switch held 0.6 s: back / options
  K_BUTTON = 4,       // push button: menu and back
  K_TOUCH_LEFT = 5,   // top-left pad
  K_TOUCH_RIGHT = 6,  // top-right pad
  K_TOUCH_FRONT = 7,  // front pad
  K_COUNT = 8,
};

// BotOS's own order (`BotMood` in world.dart). Not the wire order: see
// moodToWire() in session.cpp.
enum BotMood : uint8_t { M_CALM, M_HAPPY, M_SAD, M_SLEEPY, M_SEARCHING };

// Wall-clock time from the DS3231.
struct Clock {
  uint16_t year;
  uint8_t month, day, hour, minute, second;
  uint8_t weekday;  // 1 = Monday .. 7 = Sunday, as Dart's DateTime.weekday
  uint32_t unix;    // seconds, for differences
};

// The room, as the sensors report it. A has* flag false means no reading, and
// screens show it as missing rather than guessing.
struct Sensors {
  bool hasTemp;
  float tempC;
  bool hasHum;
  float humidity;
  bool hasLight;
  int16_t light;  // 0 dark .. 1023 bright
  bool dark;
  bool hasDistance;
  int16_t distanceCm;
  bool hasRtcTemp;
  float rtcTempC;
  uint8_t presenceMin;  // cm
  uint8_t presenceMax;

  // Someone at the desk: the 20..90 cm window.
  bool present() const {
    return hasDistance && distanceCm >= presenceMin && distanceCm <= presenceMax;
  }
};

// The block running, as BotOS needs to draw it.
struct Session {
  bool active;
  uint16_t key;  // changes whenever a different block starts
  char name[17];
  char description[25];
  uint32_t remainingS;
  float progress;
  bool paused;
  bool armed;
  bool tracked;
  bool verified;
  uint8_t index;  // 1-based position in a routine, 0 when not a routine
  uint8_t count;
};

struct World {
  Clock now;
  Sensors sensors;
  Session session;
  BotMood mood;
  bool linked;  // a phone is connected over Bluetooth
  uint16_t verifiedMinutesToday;
  uint8_t streak;
};

// One alarm slot. days: bit 0 Monday .. bit 6 Sunday; 0 = ring once.
struct BotAlarm {
  bool on;
  uint8_t hour;
  uint8_t minute;
  uint8_t tone;
  uint8_t days;

  bool once() const { return days == 0; }
  bool ringsOn(uint8_t weekday) const { return days == 0 || (days >> (weekday - 1)) & 1; }
  bool ringsAt(const Clock &t) const {
    return on && t.hour == hour && t.minute == minute && ringsOn(t.weekday);
  }
};

#define ALARM_SLOTS 4

// Where each game keeps its best score, in the Games list's order.
enum GameId : uint8_t {
  G_SNAKE, G_BLOCKS, G_DINO, G_FLAP, G_RAID, G_BREAKOUT, G_PADDLE, G_2048, G_REACTION,
  G_COUNT,
};

enum PlayMode : uint8_t { PM_ONCE, PM_REPEAT, PM_ALL, PM_SHUFFLE, PM_COUNT };

// Saved preferences, kept in EEPROM as is (store.cpp).
struct BotSettings {
  uint8_t version;
  bool sound;
  uint8_t brightness;  // 0 low, 1 mid, 2 high
  bool faceHome;       // home opens on the face rather than the clock
  uint8_t playMode;
  uint16_t bestSet;    // bit per GameId: a best score exists
  int32_t best[G_COUNT];
  BotAlarm alarms[ALARM_SLOTS];
  // Session engine, from CONFIG_SET.
  uint8_t presenceMin;
  uint8_t presenceMax;
  bool autoPause;
  uint8_t graceRunningS;
  uint16_t gracePausedS;
};

// The things BotOS can open directly, from the app's `0x72 LAUNCH`. The value
// is the wire value.
enum BotApp : uint8_t {
  APP_HOME, APP_MENU, APP_FOCUS_TIMER, APP_MUSIC, APP_GAMES, APP_DINO, APP_BREAKOUT,
  APP_REACTION, APP_ROOM, APP_SETTINGS, APP_SNAKE, APP_BLOCKS, APP_FLAP, APP_PADDLE,
  APP_STAR_RAID, APP_2048, APP_ALARMS,
  APP_COUNT,
};
