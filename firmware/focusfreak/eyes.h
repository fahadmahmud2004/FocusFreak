// The bot's face. Port of `lib/botos/eyes.dart` (RoboEyes-style).
#pragma once
#include "gfx.h"
#include "world.h"

class Eyes {
 public:
  static const int16_t baseW = 30;
  static const int16_t baseH = 38;
  static const int16_t radius = 11;
  static const int16_t space = 16;

  BotMood mood() const { return _mood; }
  void setMood(BotMood m) { _mood = m; }
  void setIdle(bool v) { _idle = v; }

  // Look towards a point, -1..1 on each axis, for [frames].
  void lookAt(float nx, float ny, int16_t frames = 60);
  void blink() { _blinkFrame = 0; }
  void pet();
  void poke();
  void laugh();
  void confused();

  void update();
  void draw();
  void drawMini(int16_t cx, int16_t cy);

 private:
  float _w = baseW, _h = baseH;
  float _x = 0, _y = 0, _targetX = 0, _targetY = 0;
  float _tired = 0, _happy = 0, _hop = 0, _hopVelocity = 0, _squish = 0, _wide = 0;

  int32_t _frame = 0;
  int32_t _nextBlink = 60;
  int16_t _blinkFrame = 99;
  int32_t _nextGlance = 40;
  int16_t _shake = 0;
  bool _shakeVertical = true;
  int32_t _happyUntil = -1;
  int32_t _surpriseUntil = -1;
  int32_t _recentPets[3] = {-999, -999, -999};

  BotMood _mood = M_CALM;
  bool _idle = true;
  bool _lookHeld = false;
  int32_t _lookHeldUntil = -1;

  struct Particle {
    int16_t x, y;
    uint8_t kind;  // 0 none, 1 heart, 2 z
    uint8_t age;
  };
  static const uint8_t MAX_PARTICLES = 8;
  Particle _particles[MAX_PARTICLES] = {};
  void addParticle(int16_t x, int16_t y, uint8_t kind);
};
