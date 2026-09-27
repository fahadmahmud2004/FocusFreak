#include "os.h"

#include "assets.h"
#include "host.h"
#include "screens.h"
#include "sound.h"

BotOs os;

static HomeScreen homeScreen;

void BotOs::begin() {
  home = &homeScreen;
  _stack[0] = home;
  _depth = 1;
}

float BotOs::brightness() const {
  static const float levels[3] = {0.45f, 0.72f, 1.0f};
  float b = levels[settings.brightness > 2 ? 2 : settings.brightness];
  if (_world.sensors.dark) b *= 0.6f;
  if (idle() && !_world.session.active) b *= 0.5f;
  return b;
}

int32_t BotOs::sittingForS() const {
  if (!_sittingSince) return -1;
  return (int32_t)(_world.now.unix - _sittingSince);
}

// --- sound --------------------------------------------------------------------

// A soft click for a control, if sound is on. Silent while music plays: there
// is one buzzer, and a click on every detent would chop the tune to pieces.
void BotOs::click(uint16_t hz) {
  if (settings.sound && !playing) Sound::tone(hz, 12);
}

void BotOs::tone(uint16_t hz, uint16_t ms) {
  if (settings.sound) Sound::tone(hz, ms);
}

void BotOs::playMelody(int8_t index) {
  if (index < 0 || index >= MELODY_COUNT) return;
  playing = true;
  playingIndex = index;
  playingAlarm = false;
  Sound::play(&MELODIES[index], settings.sound);
}

// Always audible: an alarm that obeys the mute switch is one you sleep through.
void BotOs::playAlarmTone(uint8_t t) {
  if (t >= ALARM_TONE_COUNT) t = 0;
  playing = true;
  playingIndex = -1;
  playingAlarm = true;
  Sound::play(&ALARM_TONES[t], true, true);
}

void BotOs::stopMelody() {
  if (!playing) return;
  playing = false;
  playingIndex = -1;
  playingAlarm = false;
  Sound::stopMelody();
}

int8_t BotOs::nextTrack(int8_t from) {
  const int8_t n = MELODY_COUNT;
  if (from < 0 || n == 0) return -1;
  switch (settings.playMode) {
    case PM_REPEAT: return from;
    case PM_ALL: return (from + 1) % n;
    case PM_SHUFFLE: return n == 1 ? 0 : (from + 1 + random(0, n - 1)) % n;
    default: return -1;
  }
}

float BotOs::playheadPos() const {
  if (!playing) return 0;
  uint32_t len = Sound::lengthMs();
  if (len == 0) return 0;
  uint32_t ms = Sound::elapsedMs();
  return ms >= len ? 1.0f : (float)ms / len;
}

uint16_t BotOs::playheadHz() const { return playing ? Sound::currentHz() : 0; }

// --- settings -----------------------------------------------------------------

void BotOs::saveAlarm(uint8_t) { hostSaveSettings(); }
void BotOs::saveSettings() { hostSaveSettings(); }

void BotOs::saveBest(GameId g, int32_t score, bool lowerIsBetter) {
  bool better = !hasBest(g) || (lowerIsBetter ? score < settings.best[g] : score > settings.best[g]);
  if (!better) return;
  settings.best[g] = score;
  settings.bestSet |= 1 << g;
  hostSaveSettings();
}

void BotOs::snooze(uint8_t slot, uint32_t seconds) {
  snoozeUntil = _world.now.unix + seconds;
  _snoozed = slot;
}

void BotOs::checkAlarms(const Clock &now) {
  if (snoozeUntil && now.unix >= snoozeUntil) {
    snoozeUntil = 0;
    ring(_snoozed);
    return;
  }
  int16_t minute = now.hour * 60 + now.minute;
  if (_alarmMinute == minute) return;
  bool first = _alarmMinute < 0;
  _alarmMinute = minute;
  // Switching on at 07:00:40 must not ring the 07:00 alarm a second time.
  if (first && now.second > 2) return;
  for (uint8_t i = 0; i < ALARM_SLOTS; i++) {
    BotAlarm &a = settings.alarms[i];
    if (!a.ringsAt(now)) continue;
    if (a.once()) {
      a.on = false;
      saveAlarm(i);
    }
    ring(i);
    return;
  }
}

void BotOs::ring(int8_t slot) {
  if (slot < 0 || slot >= ALARM_SLOTS) return;
  _lastActivity = frame;
  if (top()->kind() == SK_ALARM_RING) pop();
  push(newAlarmRing(slot));
}

// --- navigation ---------------------------------------------------------------

void BotOs::push(Screen *s) {
  if (!s) return;
  if (_depth >= sizeof(_stack) / sizeof(_stack[0])) {
    delete s;
    return;
  }
  _stack[_depth++] = s;
  s->enter();
}

// Note for screens: pop() deletes the screen on top. A screen that pops
// itself must not touch its own members afterwards.
void BotOs::pop() {
  if (_depth <= 1) return;
  Screen *s = _stack[--_depth];
  s->exit();
  delete s;
}

void BotOs::popToHome() {
  while (_depth > 1) pop();
}

void BotOs::replace(Screen *s) {
  if (_depth > 1) pop();
  push(s);
}

void BotOs::launch(BotApp app, uint8_t arg) {
  _lastActivity = frame;
  popToHome();
  switch (app) {
    case APP_HOME: break;
    case APP_MENU: push(newMenu()); break;
    case APP_FOCUS_TIMER:
      push(newMenu());
      push(newTimerSetup(arg > 0 ? arg : 25));
      break;
    case APP_MUSIC:
      push(newMenu());
      push(newMusic(arg > 0 ? arg - 1 : -1));
      break;
    case APP_GAMES:
      push(newMenu());
      push(newGames());
      break;
    case APP_DINO: push(newGames()); push(newGame(G_DINO)); break;
    case APP_BREAKOUT: push(newGames()); push(newGame(G_BREAKOUT)); break;
    case APP_REACTION: push(newGames()); push(newGame(G_REACTION)); break;
    case APP_ROOM: push(newMenu()); push(newRoom()); break;
    case APP_SETTINGS: push(newMenu()); push(newSettings()); break;
    case APP_SNAKE: push(newGames()); push(newGame(G_SNAKE)); break;
    case APP_BLOCKS: push(newGames()); push(newGame(G_BLOCKS)); break;
    case APP_FLAP: push(newGames()); push(newGame(G_FLAP)); break;
    case APP_PADDLE: push(newGames()); push(newGame(G_PADDLE)); break;
    case APP_STAR_RAID: push(newGames()); push(newGame(G_RAID)); break;
    case APP_2048: push(newGames()); push(newGame(G_2048)); break;
    case APP_ALARMS: push(newMenu()); push(newAlarms()); break;
    default: break;
  }
}

// --- input --------------------------------------------------------------------

void BotOs::key(BotKey k, uint32_t atMs) {
  lastKeyMs = atMs;
  _lastActivity = frame;
  if (top()->key(k)) return;
  switch (k) {
    case K_BUTTON:
      click(1900);
      if (_depth == 1) push(newMenu());
      else pop();
      break;
    case K_HOLD:
      click(1500);
      popToHome();
      break;
    case K_TOUCH_LEFT:
    case K_TOUCH_RIGHT:
      eyes.pet();
      peek();
      if (settings.sound && !playing) Sound::tone(3200, 18);
      break;
    case K_TOUCH_FRONT:
      eyes.poke();
      peek();
      if (settings.sound && !playing) Sound::tone(1800, 22);
      break;
    default:
      break;
  }
}

void BotOs::trackSitting(const World &w) {
  uint32_t now = w.now.unix;
  if (_sittingSince && now < _sittingSince) _sittingSince = now;  // the clock was set back
  if (w.sensors.present()) {
    if (!_sittingSince) _sittingSince = now;
    _lastSeen = now;
  } else if (_lastSeen && now - _lastSeen > breakAfterS) {
    _sittingSince = 0;
    _lastSeen = 0;
    _nudges = 0;
  }
  // A gentle nudge, never during a block you chose to sit through.
  int32_t sat = sittingForS();
  if (sat < 0 || w.session.active) return;
  uint16_t due = sat / sitNudgeS;
  if (due > _nudges) {
    _nudges = due;
    eyes.lookAt(0, -0.6f, 60);
    eyes.blink();
    _faceUntil = frame + fps * 3;
    if (settings.sound && !playing) Sound::tone(1320, 60);
  }
}

void BotOs::peek() {
  bool onFace = top()->kind() == SK_HOME && home->current() == HP_FACE;
  if (!onFace) _faceUntil = frame + fps * 2 + fps / 2;
}

// --- the frame ----------------------------------------------------------------

void BotOs::tick(const World &w) {
  frame++;
  _world = w;

  // Someone sat down: wake up and look at them.
  bool present = w.sensors.present();
  if (present && !_wasPresent) {
    _lastActivity = frame;
    eyes.lookAt(0, -0.5f, 50);
    eyes.blink();
  }
  if (present && frame > fps && _lastActivity < frame - fps) _lastActivity = frame - fps;
  _wasPresent = present;
  trackSitting(w);

  // A block starting takes over the screen; one ending hands it back. Any
  // change of block counts: the next one in a routine, or a new one.
  bool hasSession = w.session.active;
  if (hasSession && (!_hasSessionKey || w.session.key != _sessionKey) &&
      top()->kind() != SK_ALARM_RING) {
    _lastActivity = frame;
    popToHome();
    push(newFocus());
  } else if (!hasSession && _hasSessionKey) {
    ScreenKind k = top()->kind();
    if (k == SK_FOCUS || k == SK_FOCUS_OPTIONS) popToHome();
  }
  _hasSessionKey = hasSession;
  _sessionKey = w.session.key;

  checkAlarms(w.now);

  bool sleepy = (idle() && !hasSession) || (w.sensors.dark && idle());
  eyes.setMood(sleepy ? M_SLEEPY : w.mood);
  eyes.setIdle(!hasSession);
  eyes.update();

  if (playing && Sound::elapsedMs() > Sound::lengthMs() + 300) {
    int8_t next = playingAlarm ? -1 : nextTrack(playingIndex);
    if (next >= 0) {
      playMelody(next);
    } else {
      playing = false;
      playingIndex = -1;
      playingAlarm = false;
    }
  }

  top()->update(w);
  gfx.clear();
  gfx.color = 1;
  if (showingFace()) eyes.draw();
  else top()->draw(w);
}
