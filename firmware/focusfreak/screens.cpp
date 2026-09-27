#include "screens.h"

#include "assets.h"
#include "host.h"
#include "sound.h"
#include "ui.h"

// A PROGMEM string, copied into a RAM buffer.
static const char *P(char *out, const char *p, uint8_t n = 24) {
  strncpy_P(out, p, n - 1);
  out[n - 1] = 0;
  return out;
}

static char *fixed1(char *out, float v) {
  dtostrf(v, 0, 1, out);
  return out;
}

// --- shared -------------------------------------------------------------------

void comfort(const Sensors &s, const char **verdict, float *pos) {
  if (!s.hasTemp) {
    *verdict = PSTR("No temperature");
    *pos = 0.5f;
    return;
  }
  float t = s.tempC;
  // Apparent temperature: humid air feels hotter above ~26 C.
  float feels = t;
  if (s.hasHum && t > 26) {
    float extra = s.humidity - 40;
    if (extra < 0) extra = 0;
    if (extra > 60) extra = 60;
    feels = t + extra / 12;
  }
  float p = (feels - 16) / 20;
  *pos = p < 0 ? 0 : (p > 1 ? 1 : p);
  if (feels < 18) *verdict = PSTR("Too cold");
  else if (feels < 21) *verdict = PSTR("A bit cool");
  else if (feels <= 27) *verdict = s.hasHum && s.humidity > 70 ? PSTR("Comfy, but humid") : PSTR("Comfortable");
  else if (feels <= 31) *verdict = PSTR("Warm, get a fan on");
  else *verdict = PSTR("Too hot to focus");
}

const char *lightVerdict(int16_t light) {
  if (light < 150) return PSTR("Dark");
  if (light < 350) return PSTR("Too dim");
  if (light < 850) return PSTR("Good");
  return PSTR("Bright");
}

void sittingLabel(char *out, int32_t sat) {
  if (sat < 0) {
    strcpy_P(out, PSTR("Not now"));
    return;
  }
  long m = sat / 60;
  if (m < 60) snprintf_P(out, 24, PSTR("%ld min"), m);
  else snprintf_P(out, 24, PSTR("%ld h %ld min"), m / 60, m % 60);
  if ((uint32_t)sat >= BotOs::sitNudgeS) strcat_P(out, PSTR(", stretch"));
}

// --- home ---------------------------------------------------------------------

// While a block runs it is the first page, so turning the knob from anywhere
// on home always comes back round to it.
uint8_t HomeScreen::pages(HomePage *out) const {
  uint8_t n = 0;
  if (os.world().session.active) out[n++] = HP_FOCUS;
  if (os.settings.faceHome) {
    out[n++] = HP_FACE;
    out[n++] = HP_CLOCK;
  } else {
    out[n++] = HP_CLOCK;
    out[n++] = HP_FACE;
  }
  out[n++] = HP_ROOM;
  out[n++] = HP_DESK;
  out[n++] = HP_TODAY;
  return n;
}

HomePage HomeScreen::current() const {
  HomePage all[6];
  uint8_t n = pages(all);
  return all[page >= n ? n - 1 : page];
}

void HomeScreen::show(HomePage p) {
  HomePage all[6];
  uint8_t n = pages(all);
  page = 0;
  for (uint8_t i = 0; i < n; i++) {
    if (all[i] == p) page = i;
  }
}

bool HomeScreen::key(BotKey k) {
  switch (k) {
    case K_LEFT:
    case K_RIGHT: {
      HomePage all[6];
      uint8_t n = pages(all);
      int16_t p = page >= n ? n - 1 : page;
      p += k == K_RIGHT ? 1 : -1;
      page = (p + n) % n;
      _pageShownAt = os.frame;
      os.click();
      return true;
    }
    case K_TOUCH_LEFT:
    case K_TOUCH_RIGHT:
    case K_TOUCH_FRONT:
      // A touch always shows the face it is touching.
      show(HP_FACE);
      return false;
    case K_PRESS:
      if (current() == HP_FACE) {
        os.eyes.pet();
        return true;
      }
      if (current() == HP_FOCUS) {
        os.click(3000);
        os.push(newFocus());
        return true;
      }
      return false;
    default:
      return false;
  }
}

void HomeScreen::draw(const World &w) {
  switch (current()) {
    case HP_FOCUS: focusPage(w); break;
    case HP_FACE:
      os.eyes.draw();
      // Page dots fade in for a moment after turning the knob.
      if ((int32_t)os.frame - _pageShownAt < 40) dots(61);
      break;
    case HP_CLOCK: clockPage(w); break;
    case HP_ROOM: roomPage(w); break;
    case HP_DESK: deskPage(w); break;
    case HP_TODAY: todayPage(w); break;
  }
}

void HomeScreen::bar(const World &w, const char *title) {
  HomePage all[6];
  uint8_t n = pages(all);
  Ui::statusBar(w, title, n, page >= n ? n - 1 : page, os.playing);
}

void HomeScreen::focusPage(const World &w) {
  const Session &s = w.session;
  if (!s.active) return;
  char t[24];
  if (s.index && s.count) snprintf_P(t, sizeof(t), PSTR("Block %u/%u"), s.index, s.count);
  else strcpy_P(t, PSTR("Now"));
  bar(w, t);
  char fitted[24];
  gfx.strCenter(F_PRIMARY, 64, 21, Gfx::fit(F_PRIMARY, s.name, 120, fitted, sizeof(fitted)));
  char c[10];
  Ui::clock(c, s.remainingS);
  gfx.strCenter(strlen(c) > 5 ? F_BIG16 : F_BIG24, 64, 44, c);
  Ui::progress(6, 47, 116, 5, s.progress);
  if (s.paused) gfx.bitmap(2, 55, ICO_pause, 7);
  gfx.strCenterP(F_TINY, 64, 62, s.paused ? PSTR("PAUSED. PRESS TO OPEN") : PSTR("PRESS TO OPEN"));
}

void HomeScreen::dots(int16_t y) {
  HomePage all[6];
  uint8_t n = pages(all);
  int16_t x = 64 - (n * 5 - 2) / 2;
  uint8_t cur = page >= n ? n - 1 : page;
  for (uint8_t i = 0; i < n; i++) {
    if (i == cur) gfx.box(x, y - 1, 3, 3);
    else gfx.pixel(x + 1, y);
    x += 5;
  }
}

// The desk clock: the RTC's time and date, and the room at a glance.
void HomeScreen::clockPage(const World &w) {
  const Clock &t = w.now;
  char title[28];
  Ui::date(title, t);
  if (w.session.active) {
    strcat_P(title, PSTR("  "));
    Ui::clock(title + strlen(title), w.session.remainingS);
  }
  bar(w, title);

  char hh[3] = {(char)('0' + t.hour / 10), (char)('0' + t.hour % 10), 0};
  char mm[3] = {(char)('0' + t.minute / 10), (char)('0' + t.minute % 10), 0};
  char ss[3] = {(char)('0' + t.second / 10), (char)('0' + t.second % 10), 0};
  char hhmm[6] = {hh[0], hh[1], ':', mm[0], mm[1], 0};
  int16_t timeW = Gfx::strWidth(F_BIG32, hhmm) + 2 + Gfx::strWidth(F_SECONDARY, ss);
  int16_t x = 64 - timeW / 2;
  x += gfx.str(F_BIG32, x, 44, hh);
  // The colon breathes with the seconds.
  int16_t colonW = Gfx::strWidth(F_BIG32, ":");
  if ((t.second & 1) == 0) gfx.str(F_BIG32, x, 44, ":");
  x += colonW;
  x += gfx.str(F_BIG32, x, 44, mm);
  gfx.str(F_SECONDARY, x + 2, 44, ss);

  // The room along the bottom: temperature, humidity, light, you.
  gfx.dottedH(0, 50, 128);
  const Sensors &s = w.sensors;
  char v[12];
  int16_t cx = 0;
  gfx.bitmap(cx, 55, ICO_thermometer);
  gfx.str(F_SECONDARY, cx + 10, 63, s.hasTemp ? fixed1(v, s.tempC) : "--");
  if (s.hasTemp) Ui::degree(10 + Gfx::strWidth(F_SECONDARY, v) + 1, 56);
  cx += 36;
  gfx.bitmap(cx, 55, ICO_drop);
  if (s.hasHum) snprintf_P(v, sizeof(v), PSTR("%ld%%"), lround(s.humidity));
  gfx.str(F_SECONDARY, cx + 10, 63, s.hasHum ? v : "--");
  cx += 30;
  gfx.bitmap(cx, 55, s.dark ? ICO_moon : ICO_sun);
  if (s.hasLight) snprintf_P(v, sizeof(v), PSTR("%ld%%"), lround(s.light / 10.23f));
  gfx.str(F_SECONDARY, cx + 10, 63, s.hasLight ? v : "--");
  cx += 32;
  gfx.bitmap(cx, 55, ICO_person);
  if (s.present()) Ui::num(v, s.distanceCm);
  else strcpy_P(v, PSTR("away"));
  gfx.str(F_SECONDARY, cx + 10, 63, v);
}

void HomeScreen::roomPage(const World &w) {
  bar(w, "Room");
  const Sensors &s = w.sensors;
  if (!s.hasTemp && !s.hasHum) {
    gfx.strCenterP(F_SECONDARY, 64, 34, PSTR("No climate sensor"));
    return;
  }
  char v[12];
  gfx.bitmap(2, 16, ICO_thermometer);
  if (s.hasTemp) {
    int16_t vw = gfx.str(F_BIG16, 13, 30, fixed1(v, s.tempC));
    Ui::degree(15 + vw, 14);
    gfx.str(F_TINY, 19 + vw, 20, "C");
  }
  gfx.bitmap(70, 16, ICO_drop);
  if (s.hasHum) {
    int16_t vw = gfx.str(F_BIG16, 81, 30, Ui::num(v, lround(s.humidity)));
    gfx.str(F_SECONDARY, 83 + vw, 30, "%");
  }

  const char *verdict;
  float pos;
  comfort(s, &verdict, &pos);
  gfx.strCenterP(F_PRIMARY, 64, 45, verdict);

  // A comfort scale from cold to hot, with a marker where the room is.
  const int16_t x0 = 10, width = 108;
  for (int16_t x = x0; x <= x0 + width; x += 3) gfx.pixel(x, 55);
  gfx.str(F_TINY, 0, 58, "C");
  gfx.str(F_TINY, 124, 58, "H");
  int16_t p = x0 + (int16_t)lround(width * pos);
  gfx.triangle(p - 3, 50, p + 3, 50, p, 54);
  gfx.vLine(p, 54, 4);
  gfx.str(F_TINY, 50, 63, "COMFY");
  gfx.pixel(64 - 1, 58);
}

void HomeScreen::deskPage(const World &w) {
  bar(w, "Desk");
  const Sensors &s = w.sensors;
  char v[24];

  gfx.bitmap(2, 13, s.dark ? ICO_moon : ICO_sun);
  gfx.str(F_PRIMARY, 13, 20, "Light");
  if (s.hasLight) {
    long pct = lround(s.light / 1023.0f * 100);
    gfx.strRightP(F_SECONDARY, 126, 20, lightVerdict(s.light));
    Ui::progress(13, 23, 113, 6, pct / 100.0f);
  }

  gfx.bitmap(2, 33, ICO_person);
  gfx.str(F_PRIMARY, 13, 40, "You");
  if (!s.hasDistance) strcpy_P(v, PSTR("Away"));
  else if (s.distanceCm < 30) snprintf_P(v, sizeof(v), PSTR("%d cm, sit back"), s.distanceCm);
  else if (s.present()) snprintf_P(v, sizeof(v), PSTR("%d cm"), s.distanceCm);
  else strcpy_P(v, PSTR("Away"));
  gfx.strRight(F_SECONDARY, 126, 40, v);

  gfx.bitmap(2, 48, ICO_clock);
  gfx.str(F_PRIMARY, 13, 56, "Sitting");
  sittingLabel(v, os.sittingForS());
  gfx.strRight(F_SECONDARY, 126, 56, v);
}

void HomeScreen::todayPage(const World &w) {
  bar(w, "Today");
  uint16_t m = w.verifiedMinutesToday;
  char t[16];
  snprintf_P(t, sizeof(t), PSTR("%u:%02u"), m / 60, m % 60);
  int16_t tw = gfx.str(F_BIG24, 4, 40, t);
  gfx.str(F_SECONDARY, 8 + tw, 40, "verified");
  gfx.dottedH(4, 47, 120);
  gfx.bitmap(4, 51, ICO_bolt);
  if (w.streak == 0) strcpy_P(t, PSTR("Start a streak today"));
  else snprintf_P(t, sizeof(t), PSTR("%u day streak"), w.streak);
  gfx.str(F_SECONDARY, 15, 59, t);
}

// --- focus --------------------------------------------------------------------

class FocusScreen : public Screen {
 public:
  ScreenKind kind() const override { return SK_FOCUS; }

  bool key(BotKey k) override {
    const Session &s = os.world().session;
    switch (k) {
      case K_LEFT:
      case K_RIGHT:
        _faceView = !_faceView;
        os.click();
        return true;
      case K_PRESS:
        if (!s.active || s.armed) return true;
        os.click();
        if (s.paused) hostResumeFocus();
        else hostPauseFocus();
        return true;
      case K_HOLD:
        os.push(newFocusOptions());
        return true;
      case K_BUTTON:
        // Back from a running block is home, the face, with the block still
        // running one turn of the knob away.
        os.popToHome();
        os.home->show(HP_FACE);
        return true;
      default:
        return false;
    }
  }

  void draw(const World &w) override {
    const Session &s = w.session;
    if (!s.active) {
      gfx.strCenterP(F_SECONDARY, 64, 34, PSTR("Nothing running"));
      return;
    }
    char c[10];
    Ui::clock(c, s.remainingS);
    if (_faceView) {
      os.eyes.draw();
      char t[6];
      gfx.strRight(F_TINY, 127, 6, Ui::time(t, w.now));
      int16_t tw = Gfx::strWidth(F_PRIMARY, c) + 10;
      gfx.rBox(64 - tw / 2, 53, tw, 11, 4);
      gfx.color = 0;
      gfx.strCenter(F_PRIMARY, 64, 62, c);
      gfx.color = 1;
      return;
    }

    char title[16];
    if (s.index && s.count) snprintf_P(title, sizeof(title), PSTR("Block %u/%u"), s.index, s.count);
    else strcpy_P(title, PSTR("Focus"));
    Ui::statusBar(w, title, 0, 0, os.playing);

    char fitted[26];
    gfx.strCenter(F_PRIMARY, 64, 20, Gfx::fit(F_PRIMARY, s.name, 120, fitted, sizeof(fitted)));
    bool longText = strlen(c) > 5;
    gfx.strCenter(longText ? F_BIG16 : F_BIG24, 64, longText ? 40 : 46, c);
    Ui::progress(6, 49, 116, 6, s.progress);

    char status[26];
    const uint8_t *icon = nullptr;
    if (s.armed) {
      // The bot waits for whatever it can check: you at the desk, then the
      // phone locked.
      if (w.sensors.hasDistance && !w.sensors.present()) strcpy_P(status, PSTR("Sit down to start"));
      else strcpy_P(status, PSTR("Lock your phone to start"));
    } else if (s.paused) {
      strcpy_P(status, PSTR("Paused. Press to resume"));
      icon = ICO_pause;
    } else if (s.tracked && s.verified) {
      // What the block is for says more than what comes after it.
      if (s.description[0]) strcpy(status, s.description);
      else strcpy_P(status, PSTR("Verified"));
      icon = ICO_check;
    } else if (s.description[0]) {
      strcpy(status, s.description);
      icon = ICO_play;
    } else if (s.tracked) {
      strcpy_P(status, PSTR("Not verified right now"));
    } else {
      strcpy_P(status, PSTR("Running"));
      icon = ICO_play;
    }
    int16_t x = 64 - (Gfx::strWidth(F_SECONDARY, status) + (icon ? 10 : 0)) / 2;
    if (icon) {
      gfx.bitmap(x, 56, icon, 7);
      x += 10;
    }
    gfx.str(F_SECONDARY, x, 63, Gfx::fit(F_SECONDARY, status, 120, fitted, sizeof(fitted)));
  }

 private:
  bool _faceView = false;
};

Screen *newFocus() { return new FocusScreen(); }

class FocusOptionsScreen : public Screen {
 public:
  ScreenKind kind() const override { return SK_FOCUS_OPTIONS; }

  bool key(BotKey k) override {
    switch (k) {
      case K_LEFT:
      case K_RIGHT:
        _i = (_i + (k == K_RIGHT ? 1 : 2)) % 3;
        os.click();
        return true;
      case K_PRESS: {
        uint8_t i = _i;
        os.click();
        if (i == 0) hostSkipBlock();
        if (i == 1) hostStopFocus();
        os.pop();  // deletes this
        return true;
      }
      default:
        return false;
    }
  }

  void draw(const World &w) override {
    Ui::statusBar(w, "Block options");
    char label[16];
    for (uint8_t i = 0; i < 3; i++) {
      const char *item = i == 0 ? PSTR("Skip block") : (i == 1 ? PSTR("Stop") : PSTR("Back"));
      Ui::listRow(13 + i * 15, P(label, item, 16), nullptr, nullptr, i == _i);
    }
  }

 private:
  uint8_t _i = 0;
};

Screen *newFocusOptions() { return new FocusOptionsScreen(); }

// --- lists --------------------------------------------------------------------

bool ListScreen::key(BotKey k) {
  switch (k) {
    case K_LEFT:
    case K_RIGHT: {
      int16_t n = count();
      index += k == K_RIGHT ? 1 : -1;
      if (index < 0) index = 0;
      if (index > n - 1) index = n - 1;
      os.click();
      return true;
    }
    case K_PRESS:
      os.click(3000);
      select(index);  // may delete this
      return true;
    default:
      return false;
  }
}

void ListScreen::draw(const World &w) {
  char t[20];
  Ui::statusBar(w, P(t, title(), 20), 0, 0, os.playing);
  int16_t n = count();
  if (index > n - 1) index = n - 1;
  if (index < 0) index = 0;
  if (index < _first) _first = index;
  if (index >= _first + visible) _first = index - visible + 1;
  for (int16_t r = 0; r < visible && _first + r < n; r++) {
    drawRow(_first + r, 11 + r * 13, _first + r == index);
  }
  Ui::scrollbar(index, n);
}

// --- menu ---------------------------------------------------------------------

enum MenuItem : uint8_t { MI_FOCUS, MI_NOW, MI_ROUTINES, MI_MUSIC, MI_GAMES, MI_ALARMS, MI_ROOM, MI_SETTINGS };

class MenuScreen : public ListScreen {
 public:
  MenuItem item(int16_t i) {
    static const MenuItem rest[6] = {MI_ROUTINES, MI_MUSIC, MI_GAMES, MI_ALARMS, MI_ROOM, MI_SETTINGS};
    if (i == 0) return os.world().session.active ? MI_NOW : MI_FOCUS;
    return rest[i - 1];
  }
  int16_t count() override { return 7; }
  const char *title() override { return PSTR("Menu"); }

  void drawRow(int16_t i, int16_t y, bool selected) override {
    const char *label;
    const uint8_t *icon;
    switch (item(i)) {
      case MI_NOW: label = PSTR("Now running"); icon = ICO_play; break;
      case MI_FOCUS: label = PSTR("Focus timer"); icon = ICO_timer; break;
      case MI_ROUTINES: label = PSTR("Routines"); icon = ICO_clock; break;
      case MI_MUSIC: label = PSTR("Music"); icon = ICO_note; break;
      case MI_GAMES: label = PSTR("Games"); icon = ICO_game; break;
      case MI_ALARMS: label = PSTR("Alarms"); icon = ICO_bell; break;
      case MI_ROOM: label = PSTR("Room"); icon = ICO_gauge; break;
      default: label = PSTR("Settings"); icon = ICO_gear; break;
    }
    char t[16];
    Ui::listRow(y, P(t, label, 16), icon, nullptr, selected);
  }

  void select(int16_t i) override {
    switch (item(i)) {
      case MI_NOW: os.push(newFocus()); break;
      case MI_FOCUS: os.push(newTimerSetup()); break;
      case MI_ROUTINES: os.push(newRoutines()); break;
      case MI_MUSIC: os.push(newMusic()); break;
      case MI_GAMES: os.push(newGames()); break;
      case MI_ALARMS: os.push(newAlarms()); break;
      case MI_ROOM: os.push(newRoom()); break;
      default: os.push(newSettings()); break;
    }
  }
};

Screen *newMenu() { return new MenuScreen(); }

class TimerSetupScreen : public Screen {
 public:
  explicit TimerSetupScreen(uint16_t minutes) : _minutes(minutes) {}

  bool key(BotKey k) override {
    switch (k) {
      case K_LEFT:
      case K_RIGHT: {
        int16_t step = _minutes < 10 || (_minutes == 10 && k == K_LEFT) ? 1 : 5;
        int16_t m = _minutes + (k == K_RIGHT ? step : -step);
        _minutes = m < 1 ? 1 : (m > 180 ? 180 : m);
        os.click();
        return true;
      }
      case K_PRESS: {
        uint16_t minutes = _minutes;
        os.click(3000);
        os.popToHome();  // deletes this
        hostStartFocus(minutes);
        return true;
      }
      default:
        return false;
    }
  }

  void draw(const World &w) override {
    Ui::statusBar(w, "Focus timer");
    char t[6];
    Ui::num(t, _minutes);
    int16_t tw = Gfx::strWidth(F_BIG32, t);
    int16_t x = 64 - (tw + 22) / 2;
    gfx.str(F_BIG32, x, 46, t);
    gfx.str(F_PRIMARY, x + tw + 4, 46, "min");
    gfx.triangle(6, 30, 12, 24, 12, 36);
    gfx.triangle(121, 30, 115, 24, 115, 36);
    Ui::hintP(PSTR("Back"));
    Ui::hintP(PSTR("Start"), true);
  }

 private:
  uint16_t _minutes;
};

Screen *newTimerSetup(uint16_t minutes) { return new TimerSetupScreen(minutes); }

// --- routines -----------------------------------------------------------------

// The routines the bot carries in flash, so it runs a whole study day with no
// phone. Same list as `BotRoutines` in the Dart BotOS.
class RoutinesScreen : public ListScreen {
 public:
  int16_t count() override { return ROUTINE_TEMPLATE_COUNT; }
  const char *title() override { return PSTR("Routines"); }

  void drawRow(int16_t i, int16_t y, bool selected) override {
    const RoutineDef *r = &ROUTINE_TEMPLATES[i];
    char name[20];
    P(name, (const char *)pgm_read_ptr(&r->name), sizeof(name));
    const uint8_t *blocks = (const uint8_t *)pgm_read_ptr(&r->blocks);
    uint8_t n = pgm_read_byte(&r->count);
    uint16_t total = 0;
    for (uint8_t b = 0; b < n; b++) total += pgm_read_word(blocks + b * 48 + 40);
    char v[10];
    if (total % 60) snprintf_P(v, sizeof(v), PSTR("%uh %um"), total / 60, total % 60);
    else snprintf_P(v, sizeof(v), PSTR("%uh"), total / 60);
    Ui::listRow(y, name, ICO_clock, v, selected);
  }

  void select(int16_t i) override {
    uint8_t index = i;
    os.popToHome();  // deletes this
    hostStartRoutine(index);
  }
};

Screen *newRoutines() { return new RoutinesScreen(); }

// --- music --------------------------------------------------------------------

static const uint8_t *modeIcon(uint8_t m) {
  switch (m) {
    case PM_REPEAT: return ICO_repeat;
    case PM_ALL: return ICO_infinity;
    case PM_SHUFFLE: return ICO_shuffle;
    default: return ICO_play;
  }
}

static const char *modeLabel(uint8_t m) {
  switch (m) {
    case PM_REPEAT: return PSTR("Repeat");
    case PM_ALL: return PSTR("Play all");
    case PM_SHUFFLE: return PSTR("Shuffle");
    default: return PSTR("Once");
  }
}

static void nextPlayMode() {
  os.settings.playMode = (os.settings.playMode + 1) % PM_COUNT;
  os.saveSettings();
}

static const char *melodyTitle(char *out, int8_t i, uint8_t n = 24) {
  return P(out, (const char *)pgm_read_ptr(&MELODIES[i].title), n);
}

class NowPlayingScreen : public Screen {
 public:
  explicit NowPlayingScreen(int8_t index) : _index(index) { memset(_bars, 0, sizeof(_bars)); }

  bool key(BotKey k) override {
    switch (k) {
      case K_LEFT:
      case K_RIGHT:
        _index = (_index + (k == K_RIGHT ? 1 : MELODY_COUNT - 1)) % MELODY_COUNT;
        os.playMelody(_index);
        return true;
      case K_PRESS:
        if (os.playing) os.stopMelody();
        else os.playMelody(_index);
        return true;
      case K_HOLD:
        nextPlayMode();
        _modeShownAt = os.frame;
        return true;
      default:
        return false;
    }
  }

  void update(const World &) override {
    // Follow the player when it moves on by itself.
    if (os.playingIndex >= 0) _index = os.playingIndex;
    for (uint8_t i = 0; i < 16; i++) _bars[i] = _bars[i] > 2 ? _bars[i] - 2 : 0;
    uint16_t hz = os.playheadHz();
    if (hz > 0) {
      long band = lround(log(hz / 200.0f) / log(2.0f) * 4);
      if (band < 0) band = 0;
      if (band > 15) band = 15;
      for (uint8_t i = 0; i < 16; i++) {
        int16_t peak = 22 - abs((int16_t)i - (int16_t)band) * 5 + random(0, 4);
        if (peak < 0) peak = 0;
        if (peak > 22) peak = 22;
        if (peak > _bars[i]) _bars[i] = peak;
      }
    }
  }

  void draw(const World &w) override {
    uint8_t mode = os.settings.playMode;
    Ui::statusBar(w, "Now playing", 0, 0, os.playing);
    char t[26], fitted[26];
    gfx.str(F_PRIMARY, 2, 20, Gfx::fit(F_PRIMARY, melodyTitle(t, _index, sizeof(t)), 112, fitted, sizeof(fitted)));
    gfx.bitmap(118, 13, modeIcon(mode));
    gfx.strP(F_SECONDARY, 2, 29, (const char *)pgm_read_ptr(&MELODIES[_index].by));
    if ((int32_t)(os.frame - _modeShownAt) < 40) gfx.strRightP(F_SECONDARY, 126, 29, modeLabel(mode));
    for (uint8_t i = 0; i < 16; i++) {
      uint8_t h = _bars[i];
      if (h > 0) gfx.box(4 + i * 7 + 1, 52 - h, 5, h);
      gfx.pixel(4 + i * 7 + 3, 52);
    }
    Ui::progress(2, 55, 90, 6, os.playing ? os.playheadPos() : 0);
    gfx.bitmap(98, 55, os.playing ? ICO_pause : ICO_play);
    snprintf_P(t, sizeof(t), PSTR("%d/%d"), _index + 1, MELODY_COUNT);
    gfx.str(F_TINY, 108, 62, t);
  }

  // In any mode but Once the music carries on after you leave.
  void exit() override {
    if (os.settings.playMode == PM_ONCE) os.stopMelody();
  }

 private:
  int8_t _index;
  uint8_t _bars[16];
  uint32_t _modeShownAt = 0xFFFF0000UL;
};

Screen *newNowPlaying(int8_t index) { return new NowPlayingScreen(index); }

class MusicScreen : public ListScreen {
 public:
  explicit MusicScreen(int8_t autoplay) : _autoplay(autoplay) {}

  // Rows before the tunes: the play mode, then Stop while something plays.
  int16_t head() { return os.playing && os.playingIndex >= 0 ? 2 : 1; }

  void enter() override {
    if (_autoplay >= 0 && _autoplay < MELODY_COUNT) {
      index = _autoplay + head();
      play(_autoplay);
    }
  }

  int16_t count() override { return MELODY_COUNT + head(); }
  const char *title() override { return PSTR("Music"); }

  void drawRow(int16_t i, int16_t y, bool selected) override {
    char t[24], v[12];
    if (i == 0) {
      Ui::listRow(y, "Mode", modeIcon(os.settings.playMode), P(v, modeLabel(os.settings.playMode), 12), selected);
      return;
    }
    if (i == 1 && head() == 2) {
      Ui::listRow(y, "Stop music", ICO_pause, nullptr, selected);
      return;
    }
    int8_t m = i - head();
    Ui::listRow(y, melodyTitle(t, m), os.playingIndex == m ? ICO_play : ICO_note, nullptr, selected);
  }

  void select(int16_t i) override {
    if (i == 0) {
      nextPlayMode();
      return;
    }
    if (i == 1 && head() == 2) {
      os.stopMelody();
      index = 0;
      return;
    }
    play(i - head());
  }

 private:
  int8_t _autoplay;
  void play(int8_t m) {
    os.playMelody(m);
    os.push(newNowPlaying(m));
  }
};

Screen *newMusic(int8_t autoplay) { return new MusicScreen(autoplay); }

// --- games --------------------------------------------------------------------

static const char *gameTitle(uint8_t id) {
  switch (id) {
    case G_SNAKE: return PSTR("Snake");
    case G_BLOCKS: return PSTR("Blocks");
    case G_DINO: return PSTR("Dino Run");
    case G_FLAP: return PSTR("Flap");
    case G_RAID: return PSTR("Star Raid");
    case G_BREAKOUT: return PSTR("Breakout");
    case G_PADDLE: return PSTR("Paddle");
    case G_2048: return PSTR("2048");
    default: return PSTR("Reaction");
  }
}

class GamesScreen : public ListScreen {
 public:
  int16_t count() override { return G_COUNT; }
  const char *title() override { return PSTR("Games"); }

  void drawRow(int16_t i, int16_t y, bool selected) override {
    char label[12], v[14];
    const char *value = nullptr;
    if (os.hasBest((GameId)i)) {
      if (i == G_REACTION) snprintf_P(v, sizeof(v), PSTR("%ldms"), (long)os.settings.best[i]);
      else Ui::num(v, os.settings.best[i]);
      value = v;
    }
    Ui::listRow(y, P(label, gameTitle(i), 12), ICO_game, value, selected);
  }

  void select(int16_t i) override {
    // One buzzer: a game needs it for its own sounds.
    os.stopMelody();
    os.push(newGame((GameId)i));
  }
};

Screen *newGames() { return new GamesScreen(); }

// --- room ---------------------------------------------------------------------

class RoomScreen : public ListScreen {
 public:
  int16_t count() override { return 8; }
  const char *title() override { return PSTR("Room"); }

  void drawRow(int16_t i, int16_t y, bool selected) override {
    const World &w = os.world();
    const Sensors &s = w.sensors;
    char v[24], n[8];
    const char *label;
    const uint8_t *icon;
    strcpy_P(v, PSTR("--"));
    switch (i) {
      case 0:
        label = PSTR("Temperature");
        icon = ICO_thermometer;
        if (s.hasTemp) {
          fixed1(n, s.tempC);
          snprintf_P(v, sizeof(v), PSTR("%s C"), n);
        }
        break;
      case 1:
        label = PSTR("Humidity");
        icon = ICO_drop;
        if (s.hasHum) snprintf_P(v, sizeof(v), PSTR("%ld%%"), lround(s.humidity));
        break;
      case 2:
        label = PSTR("Light");
        icon = ICO_sun;
        if (s.hasLight) snprintf_P(v, sizeof(v), PSTR("%d / 1023"), s.light);
        break;
      case 3:
        label = PSTR("Dark room");
        icon = ICO_moon;
        strcpy_P(v, s.dark ? PSTR("Yes") : PSTR("No"));
        break;
      case 4:
        label = PSTR("Distance");
        icon = ICO_person;
        if (s.hasDistance) snprintf_P(v, sizeof(v), PSTR("%d cm"), s.distanceCm);
        break;
      case 5:
        label = PSTR("Sitting");
        icon = ICO_person;
        sittingLabel(v, os.sittingForS());
        break;
      case 6:
        label = PSTR("Clock temp");
        icon = ICO_clock;
        if (s.hasRtcTemp) {
          fixed1(n, s.rtcTempC);
          snprintf_P(v, sizeof(v), PSTR("%s C"), n);
        }
        break;
      default:
        label = PSTR("Bluetooth");
        icon = ICO_bluetooth;
        strcpy_P(v, w.linked ? PSTR("Linked") : PSTR("Waiting"));
        break;
    }
    char l[14];
    Ui::listRow(y, P(l, label, 14), icon, v, selected);
  }

  void select(int16_t) override {}
};

Screen *newRoom() { return new RoomScreen(); }

// --- settings -----------------------------------------------------------------

class SettingsScreen : public ListScreen {
 public:
  int16_t count() override { return 4; }
  const char *title() override { return PSTR("Settings"); }

  void drawRow(int16_t i, int16_t y, bool selected) override {
    const BotSettings &s = os.settings;
    const char *label;
    const char *value;
    switch (i) {
      case 0: label = PSTR("Sound"); value = s.sound ? PSTR("On") : PSTR("Off"); break;
      case 1:
        label = PSTR("Brightness");
        value = s.brightness == 0 ? PSTR("Low") : (s.brightness == 1 ? PSTR("Mid") : PSTR("High"));
        break;
      case 2: label = PSTR("Home shows"); value = s.faceHome ? PSTR("Face") : PSTR("Clock"); break;
      default: label = PSTR("BotOS"); value = PSTR("1.2"); break;
    }
    char l[14], v[8];
    Ui::listRow(y, P(l, label, 14), nullptr, P(v, value, 8), selected);
  }

  void select(int16_t i) override {
    BotSettings &s = os.settings;
    switch (i) {
      case 0: s.sound = !s.sound; os.saveSettings(); break;
      case 1: s.brightness = (s.brightness + 1) % 3; os.saveSettings(); break;
      case 2:
        s.faceHome = !s.faceHome;
        os.home->page = 0;
        os.saveSettings();
        break;
    }
  }
};

Screen *newSettings() { return new SettingsScreen(); }
