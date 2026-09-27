#include "sound.h"

#include <math.h>

#include "pins.h"

namespace Sound {

// --- RTTTL --------------------------------------------------------------------
//
// `name:d=4,o=5,b=120:c,8e.,2g6,p`, read straight out of flash one note at a
// time, the way `Rtttl.parse` in music.dart reads it.

struct Note {
  uint16_t hz;  // 0 = rest
  uint16_t ms;
};

static const char *s_cursor;  // PROGMEM, the next note token
static uint8_t s_defDur = 4, s_defOct = 6;
static uint32_t s_whole = 0;

static bool s_active = false;   // notes left to play
static bool s_started = false;  // a melody has started (elapsed counts)
static bool s_audible = true;
static bool s_alarm = false;
static bool s_cue = false;
static uint32_t s_start = 0;
static uint32_t s_length = 0;
static uint32_t s_noteEnd = 0;
static uint32_t s_soundEnd = 0;
static uint16_t s_hz = 0;

static uint32_t s_activeNext = 0;  // active buzzer pulse under an alarm
static bool s_activeOn = false;

static char rd(const char *p) { return (char)pgm_read_byte(p); }

static void activeBuzzer(bool on) {
  s_activeOn = on;
  digitalWrite(PIN_BUZZER_ACTIVE, on == BUZZER_ACTIVE_HIGH ? HIGH : LOW);
}

// Parses the `d=4,o=5,b=120` section and leaves the cursor on the first note.
static bool header(const char *p) {
  s_defDur = 4;
  s_defOct = 6;
  uint16_t bpm = 63;
  while (rd(p) && rd(p) != ':') p++;
  if (!rd(p)) return false;
  p++;
  while (rd(p) && rd(p) != ':') {
    char key = rd(p);
    while (rd(p) && rd(p) != '=' && rd(p) != ':') p++;
    if (rd(p) != '=') break;
    p++;
    uint16_t v = 0;
    bool any = false;
    while (rd(p) >= '0' && rd(p) <= '9') {
      v = v * 10 + (rd(p) - '0');
      any = true;
      p++;
    }
    if (any) {
      if (key == 'd') s_defDur = v;
      else if (key == 'o') s_defOct = v;
      else if (key == 'b') bpm = v;
    }
    while (rd(p) == ',' || rd(p) == ' ') p++;
  }
  if (!rd(p)) return false;
  p++;
  if (bpm == 0) bpm = 63;
  s_whole = 60000UL * 4 / bpm;
  s_cursor = p;
  return true;
}

// Reads one note token at [p]; returns false at the end. Tokens that do not
// parse are skipped, as the Dart regex skips them.
static bool nextNote(const char *&p, Note &out) {
  while (true) {
    while (rd(p) == ',' || rd(p) == ' ') p++;
    if (!rd(p)) return false;
    const char *tok = p;
    while (rd(p) && rd(p) != ',') p++;
    const char *end = p;

    const char *q = tok;
    while (q < end && rd(q) == ' ') q++;
    uint16_t dur = 0;
    bool hasDur = false;
    while (q < end && rd(q) >= '0' && rd(q) <= '9') {
      dur = dur * 10 + (rd(q) - '0');
      hasDur = true;
      q++;
    }
    if (q >= end) continue;
    char n = tolower(rd(q++));
    if (!((n >= 'a' && n <= 'g') || n == 'p')) continue;
    bool sharp = q < end && rd(q) == '#';
    if (sharp) q++;
    bool dot = false;
    if (q < end && rd(q) == '.') {
      dot = true;
      q++;
    }
    int8_t octave = -1;
    if (q < end && rd(q) >= '0' && rd(q) <= '9') octave = rd(q++) - '0';
    if (q < end && rd(q) == '.') {
      dot = true;
      q++;
    }
    while (q < end && rd(q) == ' ') q++;
    if (q != end) continue;

    if (!hasDur || dur == 0) dur = s_defDur;
    uint32_t ms = s_whole / dur;
    if (dot) ms += ms / 2;
    out.ms = ms;
    if (n == 'p') {
      out.hz = 0;
      return true;
    }
    // c c# d d# e f f# g g# a a# b
    static const int8_t base[7] = {9, 11, 0, 2, 4, 5, 7};  // a b c d e f g
    int8_t semi = base[n - 'a'] + (sharp ? 1 : 0);
    if (octave < 0) octave = s_defOct;
    int16_t semis = octave * 12 + semi;
    // A4 = 440 Hz is semitone 57 counting from C0.
    out.hz = (uint16_t)lround(440.0 * pow(2.0, (semis - 57) / 12.0));
    return true;
  }
}

static void startNote(const Note &n, uint32_t at) {
  s_hz = n.hz;
  s_noteEnd = at + n.ms;
  // Cut to 90 % so repeated notes are heard as separate.
  uint32_t sounding = (uint32_t)n.ms * 9 / 10;
  s_soundEnd = at + sounding;
  if (n.hz > 0 && s_audible && sounding > 0) ::tone(PIN_BUZZER_PASSIVE, n.hz, sounding);
}

void begin() {
  pinMode(PIN_BUZZER_PASSIVE, OUTPUT);
  pinMode(PIN_BUZZER_ACTIVE, OUTPUT);
  activeBuzzer(false);
}

void play(const MelodyDef *def, bool audible, bool alarm) {
  const char *r = (const char *)pgm_read_ptr(&def->rtttl);
  ::noTone(PIN_BUZZER_PASSIVE);
  s_active = false;
  s_cue = false;
  if (!header(r)) return;
  // Length first, for the playhead.
  const char *p = s_cursor;
  Note n;
  s_length = 0;
  while (nextNote(p, n)) s_length += n.ms;

  s_audible = audible;
  s_alarm = alarm;
  s_start = millis();
  s_started = true;
  s_active = nextNote(s_cursor, n);
  if (s_active) startNote(n, s_start);
  if (!alarm && s_activeOn) activeBuzzer(false);
  s_activeNext = s_start;
}

void stopMelody() {
  s_active = false;
  s_started = false;
  s_hz = 0;
  s_alarm = false;
  s_cue = false;
  ::noTone(PIN_BUZZER_PASSIVE);
  activeBuzzer(false);
}

void update() {
  uint32_t now = millis();
  if (s_active && (int32_t)(now - s_noteEnd) >= 0) {
    Note n;
    if (nextNote(s_cursor, n)) {
      startNote(n, s_noteEnd);
    } else {
      s_active = false;
      s_hz = 0;
    }
  }
  // Under an alarm the active buzzer beeps too: loud enough to wake you.
  if (s_alarm && s_active && (int32_t)(now - s_activeNext) >= 0) {
    activeBuzzer(!s_activeOn);
    s_activeNext = now + (s_activeOn ? 180 : 420);
  } else if ((!s_alarm || !s_active) && s_activeOn) {
    activeBuzzer(false);
  }
}

uint32_t elapsedMs() { return s_started ? millis() - s_start : 0; }
uint32_t lengthMs() { return s_length; }

uint16_t currentHz() {
  if (!s_active) return 0;
  return (int32_t)(millis() - s_soundEnd) < 0 ? s_hz : 0;
}

void tone(uint16_t hz, uint16_t ms) { ::tone(PIN_BUZZER_PASSIVE, hz, ms); }

bool busy() { return s_active; }

bool cue(const MelodyDef *def) {
  if (s_active && !s_cue) return false;
  play(def, true);
  s_cue = true;
  return true;
}

void stopAll() { stopMelody(); }

}  // namespace Sound
