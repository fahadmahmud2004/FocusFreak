// Shared pieces of the bot's screens. Port of `lib/botos/ui.dart`.
#pragma once
#include "gfx.h"
#include "world.h"

namespace Ui {

const int16_t statusH = 10;

// Title (or the time) on the left, live icons on the right, page dots in the
// middle when there are pages. [title] is a RAM string or null.
void statusBar(const World &w, const char *title, uint8_t pages = 0, uint8_t page = 0,
               bool playing = false);

// A row of a list: icon, label, optional value on the right.
void listRow(int16_t y, const char *label, const uint8_t *icon = nullptr,
             const char *value = nullptr, bool selected = false, int16_t width = 122);

void scrollbar(int16_t index, int16_t count, int16_t top = 11);

// A labelled key hint in a bottom corner. [text] is PROGMEM.
void hintP(const char *text, bool right = false);

void progress(int16_t x, int16_t y, int16_t w, int16_t h, float value);

// A small degree sign, which the ASCII fonts do not have.
void degree(int16_t x, int16_t y);

// "HH:MM"
char *time(char *out, const Clock &t);
// "MM:SS" or "H:MM:SS"
char *clock(char *out, uint32_t seconds);
// "MON 27 SEP"
char *date(char *out, const Clock &t);

// "%d" helpers that do not drag in printf for every call.
char *num(char *out, long v);

}  // namespace Ui
