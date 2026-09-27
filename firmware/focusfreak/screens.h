// The bot's screens. Port of `lib/botos/screens.dart`, `alarms.dart`,
// `games.dart` and `arcade.dart`.
//
// Controls, everywhere:
//   turn the knob: move between pages or items
//   press the knob: select, or pause and resume a block
//   hold the knob: options, or back to home
//   push button: open the menu, or go back
//   top pads: pet the bot (left and right in games)
//   front pad: poke the bot (jump and tap in games)
#pragma once
#include "os.h"

enum HomePage : uint8_t { HP_FOCUS, HP_FACE, HP_CLOCK, HP_ROOM, HP_DESK, HP_TODAY };

class HomeScreen : public Screen {
 public:
  uint8_t page = 0;

  uint8_t pages(HomePage *out) const;
  HomePage current() const;
  void show(HomePage p);

  bool key(BotKey k) override;
  void draw(const World &w) override;
  ScreenKind kind() const override { return SK_HOME; }

 private:
  int32_t _pageShownAt = -999;
  void bar(const World &w, const char *title);
  void focusPage(const World &w);
  void dots(int16_t y);
  void clockPage(const World &w);
  void roomPage(const World &w);
  void deskPage(const World &w);
  void todayPage(const World &w);
};

// A scrolling list: the pattern every list on the bot uses.
class ListScreen : public Screen {
 public:
  int16_t index = 0;
  static const int16_t visible = 4;

  virtual int16_t count() = 0;
  virtual const char *title() = 0;  // PROGMEM
  virtual void drawRow(int16_t i, int16_t y, bool selected) = 0;
  virtual void select(int16_t i) = 0;

  bool key(BotKey k) override;
  void draw(const World &w) override;

 protected:
  int16_t _first = 0;
};

// Shared helpers.
void comfort(const Sensors &s, const char **verdict, float *pos);
const char *lightVerdict(int16_t light);          // PROGMEM
void sittingLabel(char *out, int32_t sittingS);   // at least 24 bytes

Screen *newFocus();
Screen *newFocusOptions();
Screen *newMenu();
Screen *newTimerSetup(uint16_t minutes = 25);
Screen *newRoutines();
Screen *newMusic(int8_t autoplay = -1);
Screen *newNowPlaying(int8_t index);
Screen *newGames();
Screen *newRoom();
Screen *newSettings();
Screen *newAlarms();
Screen *newAlarmEdit(uint8_t slot);
Screen *newAlarmRing(uint8_t slot);
Screen *newGame(GameId id);
