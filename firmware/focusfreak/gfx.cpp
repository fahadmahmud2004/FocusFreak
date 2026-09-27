#include "gfx.h"

#include "pins.h"

U8G2_SSD1309_128X64_NONAME0_F_4W_HW_SPI oled(U8G2_R0, PIN_OLED_CS, PIN_OLED_DC, PIN_OLED_RES);
Gfx gfx;

static uint8_t *buf;

void Gfx::begin() {
  oled.begin();
  oled.setFontMode(1);    // transparent: text draws only its own pixels
  oled.setBitmapMode(1);
  oled.setFontPosBaseline();
  buf = oled.getBufferPtr();
}

void Gfx::clear() { oled.clearBuffer(); }
void Gfx::send() { oled.sendBuffer(); }
void Gfx::contrast(uint8_t v) { oled.setContrast(v); }

const uint8_t *Gfx::fontOf(Font f) {
  switch (f) {
    case F_PRIMARY: return u8g2_font_helvB08_tr;
    case F_SECONDARY: return u8g2_font_haxrcorp4089_tr;
    case F_MONO: return u8g2_font_profont11_tr;
    case F_TINY: return u8g2_font_4x6_tr;
    case F_BODY: return u8g2_font_6x10_tr;
    case F_BIG16: return u8g2_font_logisoso16_tn;
    case F_BIG24: return u8g2_font_logisoso24_tn;
    case F_BIG32: return u8g2_font_logisoso32_tn;
  }
  return u8g2_font_4x6_tr;
}

// --- pixels -------------------------------------------------------------------

// The SSD1309 buffer is page-major: one byte holds 8 vertical pixels.
void Gfx::pixel(int16_t x, int16_t y) {
  if (x < 0 || y < 0 || x >= W || y >= H) return;
  uint8_t *p = buf + (y >> 3) * W + x;
  uint8_t bit = 1 << (y & 7);
  if (color == 0) *p &= ~bit;
  else if (color == 2) *p ^= bit;
  else *p |= bit;
}

bool Gfx::get(int16_t x, int16_t y) {
  if (x < 0 || y < 0 || x >= W || y >= H) return false;
  return buf[(y >> 3) * W + x] & (1 << (y & 7));
}

void Gfx::hLine(int16_t x, int16_t y, int16_t w) {
  if (y < 0 || y >= H || w <= 0) return;
  int16_t x0 = x < 0 ? 0 : x;
  int16_t x1 = x + w > W ? W : x + w;
  for (int16_t i = x0; i < x1; i++) pixel(i, y);
}

void Gfx::vLine(int16_t x, int16_t y, int16_t h) {
  for (int16_t i = 0; i < h; i++) pixel(x, y + i);
}

void Gfx::box(int16_t x, int16_t y, int16_t w, int16_t h) {
  for (int16_t j = 0; j < h; j++) hLine(x, y + j, w);
}

void Gfx::frame(int16_t x, int16_t y, int16_t w, int16_t h) {
  if (w <= 0 || h <= 0) return;
  hLine(x, y, w);
  if (h > 1) hLine(x, y + h - 1, w);
  if (h > 2) {
    vLine(x, y + 1, h - 2);
    if (w > 1) vLine(x + w - 1, y + 1, h - 2);
  }
}

int16_t Gfx::cornerInset(int16_t j, int16_t h, int16_t r) {
  if (r <= 0) return 0;
  int16_t d = j < r ? r - j : (j >= h - r ? j - (h - r - 1) : 0);
  if (d <= 0) return 0;
  float dy = d - 0.5f;
  float v = (float)r * r - dy * dy;
  if (v < 0) v = 0;
  return (int16_t)lround(r - sqrt(v));
}

void Gfx::rBox(int16_t x, int16_t y, int16_t w, int16_t h, int16_t r) {
  if (w <= 0 || h <= 0) return;
  int16_t m = (w < h ? w : h) / 2;
  if (r > m) r = m;
  for (int16_t j = 0; j < h; j++) {
    int16_t inset = cornerInset(j, h, r);
    hLine(x + inset, y + j, w - 2 * inset);
  }
}

bool Gfx::insideRound(int16_t i, int16_t j, int16_t w, int16_t h, int16_t r) {
  if (i < 0 || j < 0 || i >= w || j >= h) return false;
  int16_t inset = cornerInset(j, h, r);
  return i >= inset && i < w - inset;
}

void Gfx::rFrame(int16_t x, int16_t y, int16_t w, int16_t h, int16_t r) {
  if (w <= 0 || h <= 0) return;
  int16_t m = (w < h ? w : h) / 2;
  if (r > m) r = m;
  for (int16_t j = 0; j < h; j++) {
    int16_t inset = cornerInset(j, h, r);
    for (int16_t i = inset; i < w - inset; i++) {
      if (!insideRound(i - 1, j, w, h, r) || !insideRound(i + 1, j, w, h, r) ||
          !insideRound(i, j - 1, w, h, r) || !insideRound(i, j + 1, w, h, r)) {
        pixel(x + i, y + j);
      }
    }
  }
}

void Gfx::disc(int16_t cx, int16_t cy, int16_t r) {
  for (int16_t dy = -r; dy <= r; dy++) {
    int16_t dx = (int16_t)lround(sqrt((float)r * r - (float)dy * dy));
    hLine(cx - dx, cy + dy, 2 * dx + 1);
  }
}

void Gfx::ellipse(int16_t cx, int16_t cy, int16_t rx, int16_t ry) {
  if (rx <= 0 || ry <= 0) return;
  for (int16_t dy = -ry; dy <= ry; dy++) {
    float t = 1.0f - ((float)dy * dy) / ((float)ry * ry);
    if (t < 0) t = 0;
    int16_t dx = (int16_t)lround(rx * sqrt(t));
    hLine(cx - dx, cy + dy, 2 * dx + 1);
  }
}

void Gfx::circle(int16_t cx, int16_t cy, int16_t r) {
  int16_t x = r, y = 0, err = 1 - r;
  while (x >= y) {
    pixel(cx + x, cy + y);
    pixel(cx + y, cy + x);
    pixel(cx - y, cy + x);
    pixel(cx - x, cy + y);
    pixel(cx - x, cy - y);
    pixel(cx - y, cy - x);
    pixel(cx + y, cy - x);
    pixel(cx + x, cy - y);
    y++;
    if (err < 0) {
      err += 2 * y + 1;
    } else {
      x--;
      err += 2 * (y - x) + 1;
    }
  }
}

void Gfx::line(int16_t x0, int16_t y0, int16_t x1, int16_t y1) {
  int16_t dx = abs(x1 - x0);
  int16_t dy = -abs(y1 - y0);
  int16_t sx = x0 < x1 ? 1 : -1;
  int16_t sy = y0 < y1 ? 1 : -1;
  int16_t err = dx + dy;
  while (true) {
    pixel(x0, y0);
    if (x0 == x1 && y0 == y1) break;
    int16_t e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x0 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y0 += sy;
    }
  }
}

void Gfx::triangle(int16_t x0, int16_t y0, int16_t x1, int16_t y1, int16_t x2, int16_t y2) {
  int16_t minY = min(y0, min(y1, y2));
  int16_t maxY = max(y0, max(y1, y2));
  if (minY < 0) minY = 0;
  if (maxY > H - 1) maxY = H - 1;
  const int16_t ax[3] = {x0, x1, x2};
  const int16_t ay[3] = {y0, y1, y2};
  for (int16_t y = minY; y <= maxY; y++) {
    bool any = false;
    float lo = 0, hi = 0;
    for (uint8_t e = 0; e < 3; e++) {
      int16_t xa = ax[e], ya = ay[e];
      int16_t xb = ax[(e + 1) % 3], yb = ay[(e + 1) % 3];
      if (ya == yb) continue;
      int16_t l = ya < yb ? ya : yb;
      int16_t h = ya < yb ? yb : ya;
      if (y < l || y > h) continue;
      float x = xa + (float)(xb - xa) * (y - ya) / (float)(yb - ya);
      if (!any) {
        lo = hi = x;
        any = true;
      } else {
        if (x < lo) lo = x;
        if (x > hi) hi = x;
      }
    }
    if (!any) continue;
    int16_t a = (int16_t)lround(lo);
    int16_t b = (int16_t)lround(hi);
    hLine(a, y, b - a + 1);
  }
}

void Gfx::dottedH(int16_t x, int16_t y, int16_t w) {
  for (int16_t i = 0; i < w; i += 2) pixel(x + i, y);
}

void Gfx::bitmap(int16_t x, int16_t y, const uint8_t *bmp, uint8_t maxRows) {
  uint8_t w = pgm_read_byte(bmp);
  uint8_t h = pgm_read_byte(bmp + 1);
  uint8_t per = (w + 7) / 8;
  if (h > maxRows) h = maxRows;
  const uint8_t *rows = bmp + 2;
  for (uint8_t r = 0; r < h; r++) {
    for (uint8_t c = 0; c < w; c++) {
      if (pgm_read_byte(rows + r * per + (c >> 3)) & (1 << (c & 7))) pixel(x + c, y + r);
    }
  }
}

// --- text ---------------------------------------------------------------------

int16_t Gfx::str(Font f, int16_t x, int16_t y, const char *s) {
  oled.setFont(fontOf(f));
  oled.setDrawColor(color);
  u8g2_t *u = oled.getU8g2();
  int16_t cx = x;
  for (; *s; s++) {
    uint8_t c = (uint8_t)*s;
    int8_t dx = u8g2_GetGlyphWidth(u, c);
    // U8g2 coordinates are unsigned: skip a glyph that starts off screen
    // rather than let it wrap round to the far side.
    if (cx >= 0 && cx < W && y >= 0) oled.drawGlyph(cx, y, c);
    cx += dx;
  }
  return cx - x;
}

int16_t Gfx::strWidth(Font f, const char *s) {
  oled.setFont(fontOf(f));
  u8g2_t *u = oled.getU8g2();
  int16_t w = 0;
  for (; *s; s++) w += u8g2_GetGlyphWidth(u, (uint8_t)*s);
  return w;
}

int16_t Gfx::strCenter(Font f, int16_t cx, int16_t y, const char *s) {
  return str(f, cx - strWidth(f, s) / 2, y, s);
}

int16_t Gfx::strRight(Font f, int16_t right, int16_t y, const char *s) {
  return str(f, right - strWidth(f, s), y, s);
}

static char pbuf[48];

static const char *fromP(const char *p) {
  strncpy_P(pbuf, p, sizeof(pbuf) - 1);
  pbuf[sizeof(pbuf) - 1] = 0;
  return pbuf;
}

int16_t Gfx::strP(Font f, int16_t x, int16_t y, const char *p) { return str(f, x, y, fromP(p)); }
int16_t Gfx::strCenterP(Font f, int16_t cx, int16_t y, const char *p) { return strCenter(f, cx, y, fromP(p)); }
int16_t Gfx::strRightP(Font f, int16_t right, int16_t y, const char *p) { return strRight(f, right, y, fromP(p)); }

const char *Gfx::fit(Font f, const char *s, int16_t maxW, char *out, uint8_t n) {
  strncpy(out, s, n - 1);
  out[n - 1] = 0;
  if (strWidth(f, out) <= maxW) return out;
  uint8_t len = strlen(out);
  // Room for the "..".
  if (len + 3 > n) len = n - 3;
  out[len] = 0;
  while (len > 0) {
    out[len] = '.';
    out[len + 1] = '.';
    out[len + 2] = 0;
    if (strWidth(f, out) <= maxW) break;
    len--;
    out[len] = 0;
  }
  // trimRight, then the dots.
  out[len] = 0;
  while (len > 0 && out[len - 1] == ' ') out[--len] = 0;
  out[len] = '.';
  out[len + 1] = '.';
  out[len + 2] = 0;
  return out;
}
