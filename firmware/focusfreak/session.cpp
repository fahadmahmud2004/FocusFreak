#include "session.h"

#include "assets.h"
#include "os.h"
#include "sensors.h"
#include "sound.h"

namespace Session_ {

enum Source : uint8_t { SRC_PUSHED, SRC_TEMPLATE, SRC_QUICK };

static Source s_source = SRC_PUSHED;
static uint8_t s_template = 0;
static uint16_t s_quickMin = 25;

static RunState s_state = RS_IDLE;
static uint8_t s_blockIdx = 0xFF;
static Block s_block;
static uint32_t s_plannedS = 0;
static uint32_t s_claimedS = 0;
static uint16_t s_key = 0;
static bool s_pausedByUser = false;
static int32_t s_unverifiedS = -1;  // seconds of the current unverified run, -1 = verified
static bool s_verified = false;
static bool s_lastViolating = false;

static uint32_t s_tickAt = 0;
static uint8_t s_endedS = 0;  // seconds spent in COMPLETE or BROKEN

// Presence, debounced: the stable value moves only after the raw one has
// held for two seconds.
static bool s_presentRaw = false, s_presentStable = false;
static uint32_t s_presentChangedAt = 0;

// The phone's heartbeat: trusted for 25 s.
static uint32_t s_heartbeatAt = 0;
static bool s_hasHeartbeat = false;
static bool s_phoneLocked = false;

// Mood, as MoodEngine.
static BotMood s_mood = M_CALM;
static uint32_t s_moodHoldUntil = 0;
static uint32_t s_lastActivity = 0;

// Today.
static DayLog s_today;
static uint32_t s_todayVerifiedS = 0, s_todayClaimedS = 0;
static uint32_t s_logSavedAt = 0;
static bool s_logDirty = false;
static uint8_t s_streak = 0;

static const uint32_t HEARTBEAT_TIMEOUT_MS = 25000;
static const uint32_t HAPPY_HOLD_MS = 6000;
static const uint32_t SAD_HOLD_MS = 20000;
static const uint32_t SLEEPY_AFTER_MS = 10UL * 60 * 1000;

// --- blocks -------------------------------------------------------------------

static void decode(const uint8_t *b, Block &out) {
  memcpy(out.name, b, 16);
  out.name[16] = 0;
  memcpy(out.desc, b + 16, 24);
  out.desc[24] = 0;
  out.durationMin = b[40] | (b[41] << 8);
  out.category = b[42];
  out.tracked = b[43] & 1;
}

uint8_t activeCount() {
  switch (s_source) {
    case SRC_QUICK: return 1;
    case SRC_TEMPLATE: return pgm_read_byte(&ROUTINE_TEMPLATES[s_template].count);
    default: return Store::routineCount();
  }
}

void activeBlockBytes(uint8_t index, uint8_t out[48]) {
  memset(out, 0, 48);
  switch (s_source) {
    case SRC_QUICK:
      // A focus timer from the bot's menu, named the way the app names one.
      memcpy_P(out, PSTR("Focus"), 5);
      out[40] = s_quickMin & 0xFF;
      out[41] = s_quickMin >> 8;
      out[42] = 0;
      out[43] = 1;
      out[44] = 0xFF;
      out[45] = 0xFF;
      break;
    case SRC_TEMPLATE: {
      const uint8_t *blocks = (const uint8_t *)pgm_read_ptr(&ROUTINE_TEMPLATES[s_template].blocks);
      memcpy_P(out, blocks + (uint16_t)index * 48, 48);
      break;
    }
    default:
      Store::readBlock(index, out);
      break;
  }
}

// --- today --------------------------------------------------------------------

// Days since 2026-01-01, with the day rolling over at 04:00: a session that
// starts at 01:00 belongs to the day before (FfApp.dayRolloverHour).
static uint16_t dateCode(uint32_t unix) {
  const uint32_t epoch2026 = 1767225600UL;
  const uint32_t rollover = 4UL * 3600;
  if (unix < epoch2026 + rollover) return 0;
  return (unix - rollover - epoch2026) / 86400UL;
}

uint16_t today() { return s_today.date; }

bool logFor(uint16_t date, DayLog &out) {
  if (date == s_today.date) {
    out = s_today;
    return true;
  }
  return Store::readLog(date, out);
}

static void computeStreak() {
  uint8_t n = s_today.verifiedMin > 0 ? 1 : 0;
  DayLog d;
  for (uint16_t back = 1; back < LOG_DAYS && back <= s_today.date; back++) {
    if (!Store::readLog(s_today.date - back, d) || d.verifiedMin == 0) break;
    n++;
  }
  s_streak = n;
}

static void loadToday(uint16_t date) {
  if (!Store::readLog(date, s_today)) {
    memset(&s_today, 0, sizeof(s_today));
    s_today.date = date;
  }
  s_todayVerifiedS = (uint32_t)s_today.verifiedMin * 60;
  s_todayClaimedS = (uint32_t)s_today.claimedMin * 60;
  computeStreak();
}

static void saveToday(bool now) {
  s_logDirty = true;
  if (now || millis() - s_logSavedAt >= 60000UL) {
    Store::writeLog(&s_today);
    s_logSavedAt = millis();
    s_logDirty = false;
  }
}

static void countTime(bool verified) {
  s_todayClaimedS++;
  if (verified) s_todayVerifiedS++;
  uint16_t claimedMin = s_todayClaimedS / 60;
  uint16_t verifiedMin = s_todayVerifiedS / 60;
  if (claimedMin != s_today.claimedMin || verifiedMin != s_today.verifiedMin) {
    bool firstVerified = s_today.verifiedMin == 0 && verifiedMin > 0;
    s_today.claimedMin = claimedMin;
    s_today.verifiedMin = verifiedMin;
    if (firstVerified) computeStreak();
    saveToday(false);
  }
}

// --- mood ---------------------------------------------------------------------

static void holdMood(BotMood m, uint32_t ms) {
  s_mood = m;
  s_moodHoldUntil = millis() + ms;
  if (s_moodHoldUntil == 0) s_moodHoldUntil = 1;
}

static void updateMood() {
  uint32_t now = millis();
  if (s_moodHoldUntil && (int32_t)(now - s_moodHoldUntil) < 0) return;
  s_moodHoldUntil = 0;
  bool active = s_state == RS_ARMED || s_state == RS_RUNNING || s_state == RS_PAUSED;
  if (active || s_state == RS_COMPLETE) s_lastActivity = now;
  switch (s_state) {
    case RS_RUNNING: s_mood = s_verified || !s_block.tracked ? M_CALM : M_SEARCHING; break;
    case RS_PAUSED: s_mood = M_SEARCHING; break;
    case RS_BROKEN: s_mood = M_SAD; break;
    case RS_COMPLETE: s_mood = M_HAPPY; break;
    case RS_ARMED: s_mood = M_CALM; break;
    default:
      s_mood = s_lastActivity && now - s_lastActivity >= SLEEPY_AFTER_MS ? M_SLEEPY : M_CALM;
      break;
  }
}

BotMood mood() { return s_mood; }

// Clears a lingering sad mood: the bot forgives you and gets back to work.
void pet() {
  holdMood(M_HAPPY, HAPPY_HOLD_MS);
  s_lastActivity = millis();
}

uint8_t moodToWire(BotMood m) {
  switch (m) {
    case M_SEARCHING: return 1;
    case M_SAD: return 2;
    case M_HAPPY: return 3;
    case M_SLEEPY: return 4;
    default: return 0;
  }
}

// --- verification -------------------------------------------------------------

static bool heartbeatFresh() { return s_hasHeartbeat && millis() - s_heartbeatAt < HEARTBEAT_TIMEOUT_MS; }

// Available factors: presence when the ultrasonic sensor works, the phone
// lock while the app's heartbeat is fresh. A factor with no sensor behind it
// is left out, never counted as holding.
static bool anyEvidence() { return Sensors_::sonarOk() || heartbeatFresh(); }

static bool verifiedNow() {
  if (!s_block.tracked || (s_state != RS_RUNNING && s_state != RS_ARMED)) return false;
  bool any = false;
  if (Sensors_::sonarOk()) {
    any = true;
    if (!s_presentStable) return false;
  }
  if (heartbeatFresh()) {
    any = true;
    if (!s_phoneLocked) return false;
  }
  return any;
}

bool presentStable() { return s_presentStable; }

void heartbeat(bool screenLocked) {
  s_heartbeatAt = millis();
  s_hasHeartbeat = true;
  s_phoneLocked = screenLocked;
}

// --- the machine --------------------------------------------------------------

static void finishBlock(bool completed);

void startBlock(uint8_t index) {
  uint8_t n = activeCount();
  if (index >= n) {
    s_state = n ? RS_COMPLETE : RS_IDLE;
    s_blockIdx = 0xFF;
    return;
  }
  uint8_t raw[48];
  activeBlockBytes(index, raw);
  decode(raw, s_block);
  s_blockIdx = index;
  s_plannedS = (uint32_t)s_block.durationMin * 60;
  if (s_plannedS == 0) s_plannedS = 60;
  s_claimedS = 0;
  s_unverifiedS = -1;
  s_pausedByUser = false;
  s_lastViolating = false;
  s_key++;
  // An untracked block (a break, a meal) just runs. A tracked one waits for
  // its conditions: you at the desk, the phone locked.
  s_state = s_block.tracked ? RS_ARMED : RS_RUNNING;
  s_verified = verifiedNow();
  if (s_state == RS_ARMED && (s_verified || !anyEvidence())) s_state = RS_RUNNING;
  s_today.blocksTotal++;
  saveToday(true);
  s_tickAt = millis();
  if (os.settings.sound) Sound::cue(&MELODY_START);
}

static void finishBlock(bool completed) {
  if (completed) {
    s_today.blocksDone++;
    saveToday(true);
    holdMood(M_HAPPY, HAPPY_HOLD_MS);
    if (os.settings.sound) Sound::cue(&MELODY_DONE);
  }
  uint8_t next = s_blockIdx + 1;
  if (next < activeCount()) {
    startBlock(next);
  } else {
    s_state = RS_COMPLETE;
    s_blockIdx = 0xFF;
  }
}

void startQuick(uint16_t minutes) {
  s_source = SRC_QUICK;
  s_quickMin = minutes ? minutes : 25;
  startBlock(0);
}

void startTemplate(uint8_t index) {
  if (index >= ROUTINE_TEMPLATE_COUNT) return;
  s_source = SRC_TEMPLATE;
  s_template = index;
  startBlock(0);
}

void routinePushed() {
  s_source = SRC_PUSHED;
  s_state = RS_IDLE;
  s_blockIdx = 0xFF;
}

static bool active() { return s_state == RS_ARMED || s_state == RS_RUNNING || s_state == RS_PAUSED; }

// A pause the user asked for is only ended by the user.
void pause() {
  if (s_state != RS_RUNNING) return;
  s_state = RS_PAUSED;
  s_pausedByUser = true;
  s_unverifiedS = -1;
}

void resume() {
  if (s_state != RS_PAUSED) return;
  s_state = RS_RUNNING;
  s_pausedByUser = false;
  s_unverifiedS = -1;
  s_tickAt = millis();
}

void skip() {
  if (!active()) return;
  finishBlock(true);
}

// Stopped early: logged as what it was, and the bot goes back to idle.
void stop() {
  if (!active()) return;
  s_state = RS_IDLE;
  s_blockIdx = 0xFF;
  saveToday(true);
}

static void tickSecond() {
  s_verified = verifiedNow();
  const BotSettings &cfg = os.settings;
  switch (s_state) {
    case RS_ARMED:
      if (s_verified || !anyEvidence()) s_state = RS_RUNNING;
      break;

    case RS_RUNNING: {
      s_claimedS++;
      if (s_block.tracked) {
        countTime(s_verified);
        if (s_verified || !anyEvidence()) {
          s_unverifiedS = -1;
          s_lastViolating = false;
        } else {
          if (s_unverifiedS < 0) s_unverifiedS = 0;
          s_unverifiedS++;
          if (!s_lastViolating) {
            s_lastViolating = true;
            s_today.violations++;
            saveToday(false);
          }
          // With auto-pause on (off by default, as in the app), stepping
          // away freezes the countdown after the grace period.
          if (cfg.autoPause && s_unverifiedS >= cfg.graceRunningS) s_state = RS_PAUSED;
        }
      }
      // The last three seconds tick.
      uint32_t left = s_plannedS - s_claimedS;
      if (left > 0 && left <= 3 && cfg.sound && !Sound::busy()) Sound::tone(1000, 40);
      if (s_claimedS >= s_plannedS) {
        s_claimedS = s_plannedS;
        finishBlock(true);
      }
      break;
    }

    case RS_PAUSED:
      if (s_pausedByUser) break;
      if (s_verified || !cfg.autoPause) {
        s_unverifiedS = -1;
        s_lastViolating = false;
        s_state = RS_RUNNING;
      } else if (++s_unverifiedS >= (int32_t)cfg.graceRunningS + cfg.gracePausedS) {
        s_state = RS_BROKEN;
        s_blockIdx = 0xFF;
        holdMood(M_SAD, SAD_HOLD_MS);
        saveToday(true);
      }
      break;

    case RS_COMPLETE:
    case RS_BROKEN:
      // The happy (or sad) face has been seen: back to idle.
      if (++s_endedS >= (s_state == RS_COMPLETE ? 10 : 20)) s_state = RS_IDLE;
      break;

    default:
      break;
  }
  if (s_state != RS_COMPLETE && s_state != RS_BROKEN) s_endedS = 0;
}

void begin() {
  s_source = SRC_PUSHED;
  loadToday(dateCode(Sensors_::now().unix));
  s_tickAt = millis();
  s_lastActivity = 0;
}

void update(const Sensors &s) {
  uint32_t now = millis();
  bool raw = s.present();
  if (raw != s_presentRaw) {
    s_presentRaw = raw;
    s_presentChangedAt = now;
  }
  if (s_presentStable != s_presentRaw && now - s_presentChangedAt >= 2000) s_presentStable = s_presentRaw;

  uint16_t date = dateCode(Sensors_::now().unix);
  if (date != s_today.date) {
    if (s_logDirty) Store::writeLog(&s_today);
    loadToday(date);
  }

  while (now - s_tickAt >= 1000) {
    s_tickAt += 1000;
    tickSecond();
  }
  if (s_logDirty && now - s_logSavedAt >= 60000UL) saveToday(true);
  updateMood();
}

// --- reading --------------------------------------------------------------------

void fill(Session &out) {
  out.active = active();
  out.key = s_key;
  memcpy(out.name, s_block.name, sizeof(out.name));
  memcpy(out.description, s_block.desc, sizeof(out.description));
  out.remainingS = s_plannedS > s_claimedS ? s_plannedS - s_claimedS : 0;
  out.progress = s_plannedS ? (float)s_claimedS / s_plannedS : 0;
  out.paused = s_state == RS_PAUSED;
  out.armed = s_state == RS_ARMED;
  out.tracked = s_block.tracked;
  out.verified = s_verified;
  // Position only for the bot's own routines: a routine from the app is a
  // window of up to 16 blocks, and "3/16" of a 35-block day would mislead.
  if (s_source == SRC_TEMPLATE && out.active) {
    out.index = s_blockIdx + 1;
    out.count = activeCount();
  } else {
    out.index = 0;
    out.count = 0;
  }
}

uint16_t verifiedMinutesToday() { return s_today.verifiedMin; }
uint8_t streak() { return s_streak; }

void statusPayload(uint8_t p[12]) {
  uint32_t left = s_plannedS > s_claimedS ? s_plannedS - s_claimedS : 0;
  if (!active()) left = 0;
  if (left > 0xFFFF) left = 0xFFFF;
  bool tracking = s_state == RS_RUNNING && s_block.tracked;
  p[0] = s_state;
  p[1] = active() ? s_blockIdx : 0xFF;
  p[2] = left & 0xFF;
  p[3] = left >> 8;
  p[4] = s_today.verifiedMin & 0xFF;
  p[5] = s_today.verifiedMin >> 8;
  p[6] = s_today.claimedMin & 0xFF;
  p[7] = s_today.claimedMin >> 8;
  p[8] = s_streak;
  p[9] = moodToWire(s_mood);
  p[10] = (s_presentStable ? 0x01 : 0) | (s_phoneLocked && heartbeatFresh() ? 0x04 : 0) |
          (s_verified && tracking ? 0x08 : 0) | (tracking ? 0x10 : 0);
  p[11] = 0xFF;  // no battery gauge
}

}  // namespace Session_
