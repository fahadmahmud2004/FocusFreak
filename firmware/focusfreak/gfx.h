// The 128 x 64 screen, with the drawing calls BotOS uses.
//
// Port of `app/focusfreak_app/lib/botos/gfx.dart`. Shapes are drawn with
// the same integer algorithms as the Dart Gfx, straight into U8g2's frame
// buffer, so the bot shows the same pixels the app's virtual bot does. Text
// goes through U8g2 with the same fonts the Dart side decoded from U8g2.
#pragma once
#include <Arduino.h>
#include <U8g2lib.h>

extern U8G2_SSD1309_128X64_NONAME0_F_4W_HW_SPI oled;

// The fonts by role, as `BotFonts` in gfx.dart.
enum Font : uint8_t {
  F_PRIMARY,    // helvB08, bold titles
  F_SECONDARY,  // haxrcorp4089, small readable text
  F_MONO,       // profont11
  F_TINY,       // 4x6, status bar and captions
  F_BODY,       // 6x10
  F_BIG16,      // logisoso16, numerals
  F_BIG24,
  F_BIG32,
};

class Gfx {
 public:
  static const int16_t W = 128;
  static const int16_t H = 64;

  // U8g2's draw colour: 1 sets, 0 clears, 2 inverts.
  uint8_t color = 1;

  void begin();
  void clear();
  void send();
  void contrast(uint8_t v);

  void pixel(int16_t x, int16_t y);
  bool get(int16_t x, int16_t y);
  void hLine(int16_t x, int16_t y, int16_t w);
  void vLine(int16_t x, int16_t y, int16_t h);
  void box(int16_t x, int16_t y, int16_t w, int16_t h);
  void frame(int16_t x, int16_t y, int16_t w, int16_t h);
  void rBox(int16_t x, int16_t y, int16_t w, int16_t h, int16_t r);
  void rFrame(int16_t x, int16_t y, int16_t w, int16_t h, int16_t r);
  void disc(int16_t cx, int16_t cy, int16_t r);
  void ellipse(int16_t cx, int16_t cy, int16_t rx, int16_t ry);
  void circle(int16_t cx, int16_t cy, int16_t r);
  void line(int16_t x0, int16_t y0, int16_t x1, int16_t y1);
  void triangle(int16_t x0, int16_t y0, int16_t x1, int16_t y1, int16_t x2, int16_t y2);
  void dottedH(int16_t x, int16_t y, int16_t w);

  // A PROGMEM bitmap from assets.h. [maxRows] draws only the top rows, as
  // `rows.take(7)` does in the Dart screens.
  void bitmap(int16_t x, int16_t y, const uint8_t *bmp, uint8_t maxRows = 255);

  // Text with its baseline at y, as U8g2's drawStr. Returns the advance.
  int16_t str(Font f, int16_t x, int16_t y, const char *s);
  int16_t strCenter(Font f, int16_t cx, int16_t y, const char *s);
  int16_t strRight(Font f, int16_t right, int16_t y, const char *s);
  static int16_t strWidth(Font f, const char *s);

  // PROGMEM strings.
  int16_t strP(Font f, int16_t x, int16_t y, const char *p);
  int16_t strCenterP(Font f, int16_t cx, int16_t y, const char *p);
  int16_t strRightP(Font f, int16_t right, int16_t y, const char *p);

  // Cuts [s] with ".." so it fits in [maxW], into out (at least n bytes).
  static const char *fit(Font f, const char *s, int16_t maxW, char *out, uint8_t n);

 private:
  static const uint8_t *fontOf(Font f);
  static int16_t cornerInset(int16_t j, int16_t h, int16_t r);
  bool insideRound(int16_t i, int16_t j, int16_t w, int16_t h, int16_t r);
};

extern Gfx gfx;
