// BotOS: the bot's screens and behaviour. Port of `lib/botos/os.dart`.
//
// The app's virtual bot runs the Dart original; this is the same program on
// the Mega. The loop calls BotOs::tick() 25 times a second with the world
// (sensors, session, time), feeds it key presses, and it draws the screen
// and asks for sound, focus blocks and saved settings through host.h.
#pragma once
#include "eyes.h"
#include "gfx.h"
#include "world.h"

class Screen;
class HomeScreen;

// Screen kinds the OS needs to recognise, as the Dart `is` checks do.
enum ScreenKind : uint8_t { SK_OTHER, SK_HOME, SK_FOCUS, SK_FOCUS_OPTIONS, SK_ALARM_RING };

class Screen {
 public:
  virtual ~Screen() {}
  // Return true when the screen used the key. Unused keys fall through to
  // the global rules in BotOs::key.
  virtual bool key(BotKey) { return false; }
  virtual void update(const World &) {}
  virtual void draw(const World &) = 0;
  virtual void enter() {}
  virtual void exit() {}
  virtual ScreenKind kind() const { return SK_OTHER; }
};

class BotOs {
 public:
  static const uint8_t fps = 25;
  static const uint32_t idleFrames = 5UL * 60 * fps;  // five minutes of nobody
  static const uint32_t sitNudgeS = 50UL * 60;        // a stretch after 50 min
  static const uint32_t breakAfterS = 2UL * 60;       // away this long is a break

  BotSettings settings;
  Eyes eyes;
  HomeScreen *home;

  uint32_t frame = 0;

  // What the buzzer plays: an index into MELODIES, or -1. playingAlarm while
  // an alarm tone sounds (the index is then into ALARM_TONES).
  int8_t playingIndex = -1;
  bool playing = false;
  bool playingAlarm = false;

  // When the last key arrived, in millis. The reaction game needs better
  // than a 40 ms frame.
  uint32_t lastKeyMs = 0;

  // A snoozed alarm rings again at this unix time (0 = none).
  uint32_t snoozeUntil = 0;

  void begin();
  const World &world() const { return _world; }
  Screen *top() const { return _stack[_depth - 1]; }
  uint8_t depth() const { return _depth; }

  bool idle() const { return frame - _lastActivity > idleFrames; }
  bool showingFace() const { return frame < _faceUntil; }
  // Panel brightness 0..1: the setting, lowered at night and when idle.
  float brightness() const;

  // How long you have been at the desk, or -1 when you are not.
  int32_t sittingForS() const;

  void click(uint16_t hz = 2600);
  void tone(uint16_t hz, uint16_t ms);  // a game sound, if sound is on

  void playMelody(int8_t index);
  void playAlarmTone(uint8_t tone);
  void stopMelody();
  int8_t nextTrack(int8_t from);
  bool alarmToneDone() const { return !playing || !playingAlarm; }
  // How far into the current melody, 0..1, and the note sounding now.
  float playheadPos() const;
  uint16_t playheadHz() const;

  void saveAlarm(uint8_t slot);
  void saveSettings();
  void saveBest(GameId g, int32_t score, bool lowerIsBetter = false);
  bool hasBest(GameId g) const { return settings.bestSet & (1 << g); }
  void snooze(uint8_t slot, uint32_t seconds = 300);

  void push(Screen *s);
  void pop();
  void popToHome();
  void replace(Screen *s);
  void launch(BotApp app, uint8_t arg = 0);

  void key(BotKey k, uint32_t atMs);
  void tick(const World &w);

 private:
  World _world = {};
  Screen *_stack[8];
  uint8_t _depth = 0;

  uint32_t _lastActivity = 0;
  uint32_t _faceUntil = 0;
  bool _wasPresent = false;
  uint32_t _sittingSince = 0;  // unix, 0 = not sitting
  uint32_t _lastSeen = 0;
  uint16_t _nudges = 0;
  bool _hasSessionKey = false;
  uint16_t _sessionKey = 0;
  int16_t _alarmMinute = -1;
  int8_t _snoozed = -1;

  void checkAlarms(const Clock &now);
  void ring(int8_t slot);
  void trackSitting(const World &w);
  void peek();
};

extern BotOs os;
