#include "ui.h"

#include "assets.h"

namespace Ui {

static void two(char *out, uint8_t v) {
  out[0] = '0' + v / 10;
  out[1] = '0' + v % 10;
}

char *time(char *out, const Clock &t) {
  two(out, t.hour);
  out[2] = ':';
  two(out + 3, t.minute);
  out[5] = 0;
  return out;
}

char *clock(char *out, uint32_t s) {
  uint16_t h = s / 3600;
  uint8_t m = (s % 3600) / 60;
  uint8_t sec = s % 60;
  if (h > 0) {
    snprintf_P(out, 10, PSTR("%u:%02u:%02u"), h, m, sec);
  } else {
    two(out, m);
    out[2] = ':';
    two(out + 3, sec);
    out[5] = 0;
  }
  return out;
}

static const char DAYS[] PROGMEM = "MONTUEWEDTHUFRISATSUN";
static const char MONTHS[] PROGMEM = "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";

char *date(char *out, const Clock &t) {
  memcpy_P(out, DAYS + (t.weekday - 1) * 3, 3);
  out[3] = ' ';
  uint8_t i = 4;
  if (t.day >= 10) out[i++] = '0' + t.day / 10;
  out[i++] = '0' + t.day % 10;
  out[i++] = ' ';
  memcpy_P(out + i, MONTHS + (t.month - 1) * 3, 3);
  out[i + 3] = 0;
  return out;
}

char *num(char *out, long v) {
  ltoa(v, out, 10);
  return out;
}

void statusBar(const World &w, const char *title, uint8_t pages, uint8_t page, bool playing) {
  gfx.color = 1;
  char left[24];
  if (title) {
    uint8_t i = 0;
    for (; title[i] && i < sizeof(left) - 1; i++) left[i] = toupper(title[i]);
    left[i] = 0;
  } else {
    time(left, w.now);
  }
  gfx.str(F_TINY, 1, 6, left);

  int16_t x = 127;
  if (w.linked) {
    x -= 9;
    gfx.bitmap(x, 0, ICO_bluetooth, 7);
  }
  if (playing) {
    x -= 9;
    gfx.bitmap(x, 0, ICO_note, 7);
  }
  // The time, always: when the title takes the left, it sits on the right.
  if (title) {
    char t[6];
    gfx.strRight(F_TINY, x - 2, 6, time(t, w.now));
  }

  if (pages > 1) {
    int16_t width = pages * 4 - 1;
    int16_t dx = 64 - width / 2;
    for (uint8_t i = 0; i < pages; i++) {
      if (i == page) gfx.box(dx, 2, 3, 3);
      else gfx.pixel(dx + 1, 3);
      dx += 4;
    }
  }
  gfx.dottedH(0, 8, 128);
}

void listRow(int16_t y, const char *label, const uint8_t *icon, const char *value, bool selected,
             int16_t width) {
  const int16_t h = 13;
  gfx.color = 1;
  if (selected) gfx.rBox(0, y, width, h, 3);
  gfx.color = selected ? 0 : 1;
  int16_t x = 4;
  if (icon) {
    gfx.bitmap(x, y + 3, icon);
    x += 12;
  }
  int16_t valueW = value ? Gfx::strWidth(F_SECONDARY, value) : 0;
  char fitted[28];
  gfx.str(F_PRIMARY, x, y + 10,
          Gfx::fit(F_PRIMARY, label, width - x - valueW - 6, fitted, sizeof(fitted)));
  if (value) gfx.strRight(F_SECONDARY, width - 4, y + 10, value);
  gfx.color = 1;
}

void scrollbar(int16_t index, int16_t count, int16_t top) {
  if (count <= 1) return;
  int16_t h = Gfx::H - top;
  for (int16_t y = top; y < Gfx::H; y += 2) gfx.pixel(126, y);
  int16_t thumb = (int16_t)lround((float)h / count);
  if (thumb < 4) thumb = 4;
  if (thumb > h) thumb = h;
  int16_t y = top + (int16_t)lround((float)(h - thumb) * index / (count - 1));
  gfx.box(125, y, 3, thumb);
}

void hintP(const char *text, bool right) {
  char t[24];
  strncpy_P(t, text, sizeof(t) - 1);
  t[sizeof(t) - 1] = 0;
  int16_t w = Gfx::strWidth(F_TINY, t) + 6;
  int16_t x = right ? 128 - w : 0;
  gfx.color = 1;
  gfx.rBox(x, 56, w, 8, 2);
  gfx.color = 0;
  gfx.str(F_TINY, x + 3, 62, t);
  gfx.color = 1;
}

void progress(int16_t x, int16_t y, int16_t w, int16_t h, float value) {
  gfx.color = 1;
  gfx.rFrame(x, y, w, h, h / 2);
  if (value < 0) value = 0;
  if (value > 1) value = 1;
  int16_t fill = (int16_t)lround((w - 4) * value);
  if (fill > 0) gfx.rBox(x + 2, y + 2, fill, h - 4, (h - 4) / 2);
}

void degree(int16_t x, int16_t y) {
  gfx.pixel(x + 1, y);
  gfx.pixel(x, y + 1);
  gfx.pixel(x + 2, y + 1);
  gfx.pixel(x + 1, y + 2);
}

}  // namespace Ui
