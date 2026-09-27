#include "eyes.h"

#include "assets.h"
#include "host.h"

static float frand() { return random(0, 32768) / 32767.0f; }
static float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

void Eyes::lookAt(float nx, float ny, int16_t frames) {
  _targetX = clampf(nx, -1, 1) * 16;
  _targetY = clampf(ny, -1, 1) * 9;
  _lookHeld = true;
  _lookHeldUntil = _frame + frames;
}

void Eyes::addParticle(int16_t x, int16_t y, uint8_t kind) {
  for (uint8_t i = 0; i < MAX_PARTICLES; i++) {
    if (_particles[i].kind == 0) {
      _particles[i] = {x, y, kind, 0};
      return;
    }
  }
}

// A touch on the head. Answers every single tap, straight away: a squish, a
// little hop and a heart. Three quick taps and it laughs.
void Eyes::pet() {
  _squish = 1;
  _hopVelocity = -2.6f;
  _happyUntil = _frame + 70;
  _recentPets[0] = _recentPets[1];
  _recentPets[1] = _recentPets[2];
  _recentPets[2] = _frame;
  addParticle(60 + random(0, 9) - 4 + (int16_t)lround(_x), 14 + (int16_t)lround(_y), 1);
  hostEarWiggle();
  if (_frame - _recentPets[0] <= 30) {
    laugh();
    _recentPets[0] = _recentPets[1] = _recentPets[2] = -999;
  }
}

void Eyes::poke() {
  _wide = 1;
  _surpriseUntil = _frame + 18;
  _blinkFrame = -8;
}

void Eyes::laugh() {
  _shake = 20;
  _shakeVertical = true;
  hostEarWiggle();
}

void Eyes::confused() {
  _shake = 20;
  _shakeVertical = false;
}

void Eyes::update() {
  _frame++;

  bool happy = _frame < _happyUntil || _mood == M_HAPPY;
  float tired = _mood == M_SLEEPY ? 0.62f : (_mood == M_SAD ? 0.4f : 0.0f);
  _happy += ((happy ? 1.0f : 0.0f) - _happy) * 0.3f;
  _tired += (tired - _tired) * 0.2f;

  _squish *= 0.78f;
  if (_frame > _surpriseUntil) _wide *= 0.8f;

  _hopVelocity += 0.55f;
  _hop += _hopVelocity;
  if (_hop > 0) {
    _hop = 0;
    _hopVelocity = 0;
  }

  if (_lookHeld && _frame > _lookHeldUntil) _lookHeld = false;
  if (!_lookHeld && _frame >= _nextGlance) {
    _nextGlance = _frame + 25 + random(0, 50);
    if (_idle && (_mood == M_CALM || _mood == M_SEARCHING)) {
      bool far = random(0, 4) == 0;
      _targetX = (frand() * 2 - 1) * (far ? 16 : 8);
      _targetY = (frand() * 2 - 1) * 6;
    } else if (_mood == M_SAD || _mood == M_SLEEPY) {
      _targetX = 0;
      _targetY = 6;
    } else {
      _targetX = 0;
      _targetY = 0;
    }
  }
  _x += (_targetX - _x) * 0.25f;
  _y += (_targetY - _y) * 0.25f;

  // Blinks at irregular intervals; an even rhythm reads as a machine.
  if (_blinkFrame < 0) {
    _blinkFrame++;
  } else if (_blinkFrame >= 0 && _blinkFrame < 8) {
    _blinkFrame++;
    if (_blinkFrame == 8) _blinkFrame = 99;
  } else if (_frame >= _nextBlink) {
    _blinkFrame = 0;
    _nextBlink = _frame + 60 + random(0, 90);
    if (random(0, 6) == 0) _nextBlink = _frame + 11;
  }

  float targetH = baseH;
  float targetW = baseW;
  if (_blinkFrame >= 0 && _blinkFrame < 8) {
    float t = _blinkFrame < 4 ? _blinkFrame / 4.0f : (8 - _blinkFrame) / 4.0f;
    targetH = baseH * (1 - t) + 2 * t;
  }
  targetH += sin(_frame / 18.0f) * 0.9f;
  targetH = targetH * (1 - 0.38f * _squish) + 6 * _wide;
  targetW = targetW + 5 * _squish + 3 * _wide;
  _h += (targetH - _h) * 0.6f;
  _w += (targetW - _w) * 0.6f;

  if (_shake > 0) _shake--;

  for (uint8_t i = 0; i < MAX_PARTICLES; i++) {
    Particle &p = _particles[i];
    if (!p.kind) continue;
    p.age++;
    if ((p.age & 1) == 0) p.y--;
    if (p.age > 26 || p.y < -4) p.kind = 0;
  }
  if (_mood == M_SLEEPY && _frame % 40 == 0) addParticle(104, 18, 2);
}

void Eyes::draw() {
  int16_t w = (int16_t)lround(_w);
  int16_t h = (int16_t)lround(_h);
  if (h < 2) h = 2;
  int16_t shake = _shake > 0 ? ((_shake & 1) == 0 ? 2 : -2) : 0;
  int16_t ox = (int16_t)lround(_x) + (_shakeVertical ? 0 : shake);
  int16_t oy = (int16_t)lround(_y) + (int16_t)lround(_hop) + (_shakeVertical ? shake : 0);

  int16_t total = w * 2 + space;
  int16_t lx = (Gfx::W - total) / 2 + ox;
  int16_t rx = lx + w + space;

  // Curiosity: looking far to one side, the eye on that side grows.
  bool curious = _mood == M_SEARCHING || fabs(_x) > 11;
  int16_t lh = h + (curious && _x < -11 ? 6 : 0);
  int16_t rh = h + (curious && _x > 11 ? 6 : 0);
  int16_t ly = (Gfx::H - lh) / 2 + oy;
  int16_t ry = (Gfx::H - rh) / 2 + oy;
  int16_t r = radius < h / 2 ? radius : h / 2;

  gfx.color = 1;
  gfx.rBox(lx, ly, w, lh, r);
  gfx.rBox(rx, ry, w, rh, r);

  gfx.color = 0;
  int16_t lid = (int16_t)lround(_tired * lh);
  if (lid > 0) {
    gfx.triangle(lx - 1, ly - 1, lx + w, ly - 1, lx - 1, ly + lid);
    gfx.box(lx - 1, ly - 1, w + 2, lid / 2);
    gfx.triangle(rx - 1, ry - 1, rx + w, ry - 1, rx + w, ry + lid);
    gfx.box(rx - 1, ry - 1, w + 2, lid / 2);
  }
  int16_t smile = (int16_t)lround(_happy * lh * 0.9f);
  if (smile > 0) {
    gfx.ellipse(lx + w / 2, ly + lh + smile / 4, w * 9 / 10, smile);
    gfx.ellipse(rx + w / 2, ry + rh + smile / 4, w * 9 / 10, smile);
  }

  if (h > 14 && _happy < 0.5f && _tired < 0.3f) {
    int16_t gx = (int16_t)lround(_x / 6);
    int16_t gy = (int16_t)lround(_y / 6);
    gfx.rBox(lx + w - 11 + gx, ly + 6 + gy, 5, 5, 2);
    gfx.rBox(rx + w - 11 + gx, ry + 6 + gy, 5, 5, 2);
  }
  gfx.color = 1;

  for (uint8_t i = 0; i < MAX_PARTICLES; i++) {
    const Particle &p = _particles[i];
    if (p.kind == 1) {
      gfx.bitmap(p.x, p.y, ICO_heartSmall);
    } else if (p.kind == 2) {
      gfx.str(F_TINY, p.x + p.age / 6, p.y, p.age < 13 ? "z" : "Z");
    }
  }
}

void Eyes::drawMini(int16_t cx, int16_t cy) {
  float blinkT = 0;
  if (_blinkFrame >= 0 && _blinkFrame < 8) {
    blinkT = _blinkFrame < 4 ? _blinkFrame / 4.0f : (8 - _blinkFrame) / 4.0f;
  }
  int16_t h = (int16_t)lround(10 * (1 - blinkT));
  if (h < 1) h = 1;
  int16_t dx = (int16_t)lround(_x / 5);
  int16_t dy = (int16_t)lround(_y / 4);
  gfx.color = 1;
  gfx.rBox(cx - 10 + dx, cy - h / 2 + dy, 8, h, 2);
  gfx.rBox(cx + 2 + dx, cy - h / 2 + dy, 8, h, 2);
  if (_happy > 0.5f) {
    gfx.color = 0;
    gfx.box(cx - 11 + dx, cy + 1 + dy, 22, 5);
    gfx.color = 1;
  }
}
