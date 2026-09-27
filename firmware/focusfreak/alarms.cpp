// Alarms: the bot as a desk clock that wakes you. Port of `lib/botos/alarms.dart`.
#include "assets.h"
#include "screens.h"
#include "ui.h"

// The day patterns the knob steps through.
static const uint8_t PRESETS[6] = {0, 0x7F, 0x4F, 0x1F, 0x30, 0x60};

static void repeatLabel(char *out, uint8_t days) {
  switch (days) {
    case 0: strcpy_P(out, PSTR("Once")); return;
    case 0x7F: strcpy_P(out, PSTR("Every day")); return;
    case 0x4F: strcpy_P(out, PSTR("Sun to Thu")); return;
    case 0x1F: strcpy_P(out, PSTR("Mon to Fri")); return;
    case 0x30: strcpy_P(out, PSTR("Fri and Sat")); return;
    case 0x60: strcpy_P(out, PSTR("Sat and Sun")); return;
  }
  static const char NAMES[] PROGMEM = "MonTueWedThuFriSatSun";
  out[0] = 0;
  for (uint8_t i = 0; i < 7; i++) {
    if (!((days >> i) & 1)) continue;
    if (out[0]) strcat(out, " ");
    uint8_t n = strlen(out);
    memcpy_P(out + n, NAMES + i * 3, 3);
    out[n + 3] = 0;
  }
}

static void alarmTime(char *out, const BotAlarm &a) {
  snprintf_P(out, 6, PSTR("%02u:%02u"), a.hour, a.minute);
}

static const char *toneTitle(char *out, uint8_t t, uint8_t n) {
  strncpy_P(out, (const char *)pgm_read_ptr(&ALARM_TONES[t].title), n - 1);
  out[n - 1] = 0;
  return out;
}

// --- the list -----------------------------------------------------------------

class AlarmsScreen : public ListScreen {
 public:
  int16_t count() override { return ALARM_SLOTS; }
  const char *title() override { return PSTR("Alarms"); }

  void drawRow(int16_t i, int16_t y, bool selected) override {
    const BotAlarm &a = os.settings.alarms[i];
    char t[6], v[32];
    alarmTime(t, a);
    if (a.on) repeatLabel(v, a.days);
    else strcpy_P(v, PSTR("Off"));
    Ui::listRow(y, t, a.on ? ICO_bell : ICO_bellOff, v, selected);
  }

  void select(int16_t i) override { os.push(newAlarmEdit(i)); }
};

Screen *newAlarms() { return new AlarmsScreen(); }

// --- editing ------------------------------------------------------------------

enum Field : uint8_t { FD_HOUR, FD_MINUTE, FD_ON, FD_REPEAT, FD_TONE, FD_COUNT };

// Turn to pick a field, press to change it, turn to set, press again to keep
// it. Back saves.
class AlarmEditScreen : public Screen {
 public:
  explicit AlarmEditScreen(uint8_t slot) : _slot(slot) {}

  bool key(BotKey k) override {
    switch (k) {
      case K_LEFT:
      case K_RIGHT: {
        int8_t d = k == K_RIGHT ? 1 : -1;
        if (_editing) change(d);
        else _field = (_field + (d > 0 ? 1 : FD_COUNT - 1)) % FD_COUNT;
        os.click();
        return true;
      }
      case K_PRESS:
        os.click(3000);
        if (_field == FD_ON) {
          a().on = !a().on;
          os.saveAlarm(_slot);
        } else {
          _editing = !_editing;
          if (!_editing) {
            os.saveAlarm(_slot);
            os.stopMelody();
          }
        }
        return true;
      default:
        return false;
    }
  }

  void exit() override {
    os.saveAlarm(_slot);
    os.stopMelody();
  }

  void draw(const World &w) override {
    const BotAlarm &al = a();
    char t[16];
    snprintf_P(t, sizeof(t), PSTR("Alarm %u"), _slot + 1);
    Ui::statusBar(w, t);

    char hh[3], mm[3];
    snprintf_P(hh, 3, PSTR("%02u"), al.hour);
    snprintf_P(mm, 3, PSTR("%02u"), al.minute);
    int16_t hw = Gfx::strWidth(F_BIG24, hh);
    int16_t cw = Gfx::strWidth(F_BIG24, ":");
    int16_t mw = Gfx::strWidth(F_BIG24, mm);
    int16_t x = 64 - (hw + cw + mw) / 2;
    const int16_t base = 36;
    timePart(x, base, hh, hw, FD_HOUR);
    x += hw;
    gfx.str(F_BIG24, x, base, ":");
    x += cw;
    timePart(x, base, mm, mw, FD_MINUTE);

    // On, repeat and tone along the bottom.
    static const uint8_t widths[3] = {24, 52, 48};
    const int16_t y = 44;
    int16_t cx = 1;
    for (uint8_t i = 0; i < 3; i++) {
      char text[32], fitted[20];
      uint8_t field = i == 0 ? FD_ON : (i == 1 ? FD_REPEAT : FD_TONE);
      if (i == 0) strcpy_P(text, al.on ? PSTR("ON") : PSTR("OFF"));
      else if (i == 1) repeatLabel(text, al.days);
      else toneTitle(text, al.tone, sizeof(text));
      int16_t wv = widths[i];
      bool selected = _field == field;
      if (selected && _editing) {
        gfx.rBox(cx, y, wv - 2, 11, 3);
        gfx.color = 0;
      } else if (selected) {
        gfx.rFrame(cx, y, wv - 2, 11, 3);
      }
      gfx.strCenter(F_SECONDARY, cx + (wv - 2) / 2, y + 8, Gfx::fit(F_SECONDARY, text, wv - 6, fitted, sizeof(fitted)));
      gfx.color = 1;
      cx += wv;
    }

    gfx.strP(F_TINY, 1, 63, _editing ? PSTR("TURN TO SET, PRESS TO KEEP") : PSTR("TURN TO PICK, PRESS TO EDIT"));
  }

 private:
  uint8_t _slot;
  uint8_t _field = 0;
  bool _editing = false;

  BotAlarm &a() { return os.settings.alarms[_slot]; }
  const BotAlarm &a() const { return os.settings.alarms[_slot]; }

  void change(int8_t d) {
    BotAlarm &al = a();
    switch (_field) {
      case FD_HOUR: al.hour = (al.hour + (d > 0 ? 1 : 23)) % 24; break;
      case FD_MINUTE: al.minute = (al.minute + (d > 0 ? 1 : 59)) % 60; break;
      case FD_ON: al.on = !al.on; break;
      case FD_REPEAT: {
        int8_t at = 0;
        for (uint8_t i = 0; i < 6; i++) {
          if (PRESETS[i] == al.days) at = i;
        }
        al.days = PRESETS[(at + (d > 0 ? 1 : 5)) % 6];
        break;
      }
      case FD_TONE:
        al.tone = (al.tone + (d > 0 ? 1 : ALARM_TONE_COUNT - 1)) % ALARM_TONE_COUNT;
        os.playAlarmTone(al.tone);
        break;
    }
    // Setting a time is a sign you want it to ring.
    if (_field != FD_ON) al.on = true;
  }

  void timePart(int16_t x, int16_t base, const char *text, int16_t w, uint8_t field) {
    bool selected = _field == field;
    if (selected && _editing) {
      gfx.rBox(x - 2, base - 19, w + 3, 22, 3);
      gfx.color = 0;
      gfx.str(F_BIG24, x, base, text);
      gfx.color = 1;
      return;
    }
    gfx.str(F_BIG24, x, base, text);
    if (selected) gfx.box(x, base + 3, w - 1, 2);
  }
};

Screen *newAlarmEdit(uint8_t slot) { return new AlarmEditScreen(slot); }

// --- ringing ------------------------------------------------------------------

// The tone repeats until the knob is pressed (stop) or a pad is touched
// (snooze five minutes). Ten minutes of ringing and it snoozes on its own.
class AlarmRingScreen : public Screen {
 public:
  explicit AlarmRingScreen(uint8_t slot) : _slot(slot), _start(os.frame) {}
  ScreenKind kind() const override { return SK_ALARM_RING; }

  void enter() override {
    os.eyes.lookAt(0, -0.4f, 60);
    os.playAlarmTone(os.settings.alarms[_slot].tone);
  }

  bool key(BotKey k) override {
    switch (k) {
      case K_TOUCH_LEFT:
      case K_TOUCH_RIGHT:
      case K_TOUCH_FRONT:
        os.snooze(_slot);
        close();
        break;
      case K_LEFT:
      case K_RIGHT:
        break;
      default:
        os.snoozeUntil = 0;
        close();
        break;
    }
    return true;
  }

  void update(const World &) override {
    if (os.frame - _start > 10UL * 60 * BotOs::fps) {
      os.snooze(_slot);
      close();
      return;
    }
    // Round again once the tone has played through.
    if (os.alarmToneDone()) os.playAlarmTone(os.settings.alarms[_slot].tone);
  }

  void draw(const World &w) override {
    uint32_t f = os.frame - _start;
    // The bell rocks, and the whole screen flashes once a second.
    static const int8_t rock[4] = {0, -2, 0, 2};
    gfx.bitmap(8 + rock[(f / 3) % 4], 14, ICO_bellBig);
    if (f % 25 < 3) {
      gfx.frame(0, 0, 128, 64);
      gfx.frame(1, 1, 126, 62);
    }
    char t[12];
    gfx.strCenter(F_BIG24, 76, 34, Ui::time(t, w.now));
    snprintf_P(t, sizeof(t), PSTR("Alarm %u"), _slot + 1);
    gfx.strCenter(F_PRIMARY, 76, 46, t);
    Ui::hintP(PSTR("Touch: snooze"));
    Ui::hintP(PSTR("Press: stop"), true);
  }

 private:
  uint8_t _slot;
  uint32_t _start;

  void close() {
    os.stopMelody();
    os.pop();  // deletes this
  }
};

Screen *newAlarmRing(uint8_t slot) { return new AlarmRingScreen(slot); }
