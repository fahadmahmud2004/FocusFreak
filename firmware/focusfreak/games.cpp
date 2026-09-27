// Games for breaks, built for the bot's own controls. Port of
// `lib/botos/games.dart`: Dino Run, Breakout, Reaction.
#include "assets.h"
#include "screens.h"
#include "ui.h"

Screen *newArcadeGame(GameId id);  // arcade.cpp

enum Phase : uint8_t { PH_READY, PH_PLAYING, PH_OVER };


static uint8_t sprH(const uint8_t *s) { return pgm_read_byte(s + 1); }

// --- Dino Run -----------------------------------------------------------------

class DinoGame : public Screen {
 public:
  static const int16_t ground = 58;
  static const int16_t dinoX = 8;

  bool key(BotKey k) override {
    switch (k) {
      case K_PRESS:
      case K_TOUCH_FRONT:
      case K_TOUCH_LEFT:
      case K_TOUCH_RIGHT:
      case K_RIGHT:
        if (_phase != PH_PLAYING) {
          reset();
          _phase = PH_PLAYING;
          return true;
        }
        if (onGround()) {
          _vy = -5.6f;
          os.tone(880, 25);
        }
        return true;
      default:
        return false;
    }
  }

  void update(const World &) override {
    if (_phase != PH_PLAYING) return;
    _vy += 0.52f;
    _y += _vy;
    if (_y > 0) {
      _y = 0;
      _vy = 0;
    }

    _speed = min(7.5f, _speed + 0.0025f);
    long before = (long)floor(_score);
    _score += _speed / 10;
    if ((long)floor(_score) / 100 > before / 100) os.tone(1500, 40);
    _groundScroll = fmod(_groundScroll + _speed, 128.0f);
    for (uint8_t i = 0; i < 2; i++) {
      _clouds[i] -= _speed / 5;
      if (_clouds[i] < -12) _clouds[i] = 130 + random(0, 40);
    }

    for (uint8_t i = 0; i < _count; i++) _obs[i].x -= _speed;
    uint8_t kept = 0;
    for (uint8_t i = 0; i < _count; i++) {
      if (_obs[i].x >= -16) _obs[kept++] = _obs[i];
    }
    _count = kept;
    float last = _count == 0 ? -999.0f : _obs[_count - 1].x;
    if (128 - last > _nextGap && _count < MAX_OBS) {
      bool bird = _score > 250 && random(0, 4) == 0;
      Obstacle &o = _obs[_count++];
      o.x = 130;
      o.kind = bird ? 2 : (random(0, 2) ? 0 : 1);
      o.high = random(0, 2);
      _nextGap = 50 + _speed * 10 + random(0, 60);
    }

    // Collision, with boxes a little smaller than the sprites: a hit the
    // player cannot see is a cheat.
    int16_t dinoTop = ground - 15 + (int16_t)lround(_y) + 2;
    const int16_t dinoLeft = dinoX + 2;
    const int16_t dinoRight = dinoX + 11;
    int16_t dinoBottom = ground + (int16_t)lround(_y) - 1;
    for (uint8_t i = 0; i < _count; i++) {
      int16_t w, h, top;
      box(_obs[i], &w, &h, &top);
      int16_t ox = (int16_t)lround(_obs[i].x);
      if (ox + 1 < dinoRight && ox + w - 1 > dinoLeft && top + 1 < dinoBottom && top + h - 1 > dinoTop) {
        _phase = PH_OVER;
        os.saveBest(G_DINO, (long)floor(_score));
        os.tone(180, 180);
        os.eyes.confused();
        break;
      }
    }
  }

  void draw(const World &) override {
    long score = (long)floor(_score);
    char t[16];
    snprintf_P(t, sizeof(t), PSTR("%05ld"), score);
    gfx.strRight(F_TINY, 127, 6, t);
    if (os.hasBest(G_DINO)) {
      snprintf_P(t, sizeof(t), PSTR("HI %05ld"), (long)os.settings.best[G_DINO]);
      gfx.strRight(F_TINY, 100, 6, t);
    }

    for (uint8_t i = 0; i < 2; i++) gfx.bitmap((int16_t)lround(_clouds[i]), 16, SPR_cloud);

    // Ground with scrolling grit.
    gfx.hLine(0, ground, 128);
    for (int16_t i = 0; i < 12; i++) {
      int16_t x = (int16_t)lround((i * 23 + 7) - _groundScroll);
      x = ((x % 128) + 128) % 128;
      gfx.pixel(x, ground + 2 + (i % 3));
      if ((i & 1) == 0) gfx.pixel(x + 3, ground + 4);
    }

    for (uint8_t i = 0; i < _count; i++) {
      int16_t w, h, top;
      box(_obs[i], &w, &h, &top);
      const uint8_t *s = _obs[i].kind == 0 ? SPR_cactusSmall
                         : _obs[i].kind == 1 ? SPR_cactusBig
                         : ((os.frame / 6) % 2 == 0 ? SPR_birdA : SPR_birdB);
      gfx.bitmap((int16_t)lround(_obs[i].x), top + h - sprH(s), s);
    }

    const uint8_t *sprite = _phase == PH_OVER ? SPR_dinoDead
                            : (!onGround() || _phase == PH_READY) ? SPR_dinoA
                            : ((os.frame / 3) % 2 == 0 ? SPR_dinoA : SPR_dinoB);
    gfx.bitmap(dinoX, ground - 15 + (int16_t)lround(_y), sprite);

    if (_phase == PH_READY) {
      gfx.strCenterP(F_PRIMARY, 72, 30, PSTR("Dino Run"));
      gfx.strCenterP(F_SECONDARY, 72, 41, PSTR("Tap to jump"));
    } else if (_phase == PH_OVER) {
      gfx.color = 0;
      gfx.box(30, 18, 70, 24);
      gfx.color = 1;
      gfx.rFrame(30, 18, 70, 24, 3);
      gfx.strCenterP(F_PRIMARY, 65, 29, PSTR("Game over"));
      gfx.strCenterP(F_SECONDARY, 65, 38, PSTR("Tap to retry"));
    }

    // Night falls now and then, the way the original does.
    if (score % 700 > 500) {
      gfx.color = 2;
      gfx.box(0, 0, 128, 64);
      gfx.color = 1;
    }
  }

 private:
  struct Obstacle {
    float x;
    uint8_t kind;  // 0 small cactus, 1 big cactus, 2 bird
    bool high;
  };
  static const uint8_t MAX_OBS = 8;

  Phase _phase = PH_READY;
  float _y = 0, _vy = 0, _speed = 3.2f, _score = 0, _groundScroll = 0, _nextGap = 60;
  Obstacle _obs[MAX_OBS];
  uint8_t _count = 0;
  float _clouds[2] = {30, 95};

  bool onGround() const { return _y >= 0; }

  void reset() {
    _y = 0;
    _vy = 0;
    _speed = 3.2f;
    _score = 0;
    _nextGap = 60;
    _count = 0;
  }

  static void box(const Obstacle &o, int16_t *w, int16_t *h, int16_t *top) {
    switch (o.kind) {
      case 0: *w = 6; *h = 12; *top = ground - 12; break;
      case 1: *w = 10; *h = 16; *top = ground - 16; break;
      default: *w = 12; *h = 7; *top = o.high ? ground - 30 : ground - 17; break;
    }
  }
};

// --- Breakout -----------------------------------------------------------------

class BreakoutGame : public Screen {
 public:
  static const uint8_t cols = 8, rows = 4;
  static const int16_t brickW = 14, brickH = 4, paddleW = 22, paddleY = 60;

  BreakoutGame() { build(); }

  bool key(BotKey k) override {
    switch (k) {
      case K_LEFT: move(-9); return true;
      case K_RIGHT: move(9); return true;
      case K_TOUCH_LEFT: move(-14); return true;
      case K_TOUCH_RIGHT: move(14); return true;
      case K_PRESS:
      case K_TOUCH_FRONT:
        if (_phase == PH_OVER) {
          build();
          _lives = 3;
          _score = 0;
          _level = 1;
          _stuck = true;
          _phase = PH_READY;
          return true;
        }
        _phase = PH_PLAYING;
        if (_stuck) {
          _stuck = false;
          float speed = 1.8f + _level * 0.25f;
          _vx = (random(0, 2) ? 1 : -1) * speed * 0.6f;
          _vy = -speed;
        }
        return true;
      default:
        return false;
    }
  }

  void update(const World &) override {
    if (_stuck) {
      _bx = _paddle + paddleW / 2.0f - 1;
      _by = paddleY - 3;
      return;
    }
    if (_phase != PH_PLAYING) return;

    _bx += _vx;
    _by += _vy;
    if (_bx <= 0 || _bx >= 126) {
      _vx = -_vx;
      _bx = constrain(_bx, 0, 126);
    }
    if (_by <= 11) _vy = fabs(_vy);

    // Paddle: where it lands on the paddle sets the angle.
    if (_vy > 0 && _by + 2 >= paddleY && _by + 2 <= paddleY + 3 && _bx + 2 >= _paddle &&
        _bx <= _paddle + paddleW) {
      float hit = constrain((_bx + 1 - _paddle) / paddleW, 0.0f, 1.0f);
      float speed = sqrt(_vx * _vx + _vy * _vy);
      float angle = (hit - 0.5f) * 2.2f;
      _vx = speed * sin(angle);
      _vy = -speed * cos(angle);
      os.tone(660, 15);
    }

    for (uint8_t i = 0; i < cols * rows; i++) {
      if (!_bricks[i]) continue;
      int16_t bx = 2 + (i % cols) * (brickW + 2);
      int16_t by = 12 + (i / cols) * (brickH + 2);
      if (_bx + 2 > bx && _bx < bx + brickW && _by + 2 > by && _by < by + brickH) {
        _bricks[i] = false;
        _score += 10 * (rows - i / cols);
        bool fromSide = _bx + 1 < bx || _bx + 1 > bx + brickW;
        if (fromSide) _vx = -_vx;
        else _vy = -_vy;
        os.tone(1320, 12);
        break;
      }
    }

    bool any = false;
    for (uint8_t i = 0; i < cols * rows; i++) any |= _bricks[i];
    if (!any) {
      _level++;
      build();
      _stuck = true;
      os.eyes.laugh();
    }

    if (_by > 64) {
      _lives--;
      _stuck = true;
      os.tone(200, 150);
      if (_lives <= 0) {
        _phase = PH_OVER;
        os.saveBest(G_BREAKOUT, _score);
      }
    }
  }

  void draw(const World &) override {
    char t[12];
    gfx.str(F_TINY, 1, 6, Ui::num(t, _score));
    snprintf_P(t, sizeof(t), PSTR("LV %u"), _level);
    gfx.strCenter(F_TINY, 64, 6, t);
    for (int8_t i = 0; i < _lives; i++) gfx.bitmap(122 - i * 5, 2, ICO_heartSmall);
    gfx.dottedH(0, 9, 128);

    for (uint8_t i = 0; i < cols * rows; i++) {
      if (!_bricks[i]) continue;
      int16_t x = 2 + (i % cols) * (brickW + 2);
      int16_t y = 12 + (i / cols) * (brickH + 2);
      if (i / cols == 0) {
        gfx.box(x, y, brickW, brickH);
      } else {
        gfx.rBox(x, y, brickW, brickH, 1);
        if ((i / cols) % 2 == 1) {
          gfx.color = 0;
          gfx.hLine(x + 2, y + 1, brickW - 4);
          gfx.color = 1;
        }
      }
    }

    gfx.rBox((int16_t)lround(_paddle), paddleY, paddleW, 3, 1);
    gfx.box((int16_t)lround(_bx), (int16_t)lround(_by), 2, 2);

    if (_phase == PH_READY && _stuck) {
      gfx.strCenterP(F_SECONDARY, 64, 47, PSTR("Turn the knob to move"));
      gfx.strCenterP(F_SECONDARY, 64, 55, PSTR("Press to launch"));
    } else if (_phase == PH_OVER) {
      gfx.color = 0;
      gfx.box(24, 24, 80, 24);
      gfx.color = 1;
      gfx.rFrame(24, 24, 80, 24, 3);
      gfx.strCenterP(F_PRIMARY, 64, 35, PSTR("Game over"));
      snprintf_P(t, sizeof(t), PSTR("Score %d"), _score);
      gfx.strCenter(F_SECONDARY, 64, 44, t);
    }
  }

 private:
  Phase _phase = PH_READY;
  bool _bricks[cols * rows];
  float _paddle = 53, _bx = 64, _by = 56, _vx = 1.2f, _vy = -1.8f;
  bool _stuck = true;
  int8_t _lives = 3;
  int16_t _score = 0;
  uint8_t _level = 1;

  void build() { memset(_bricks, 1, sizeof(_bricks)); }
  void move(float dx) { _paddle = constrain(_paddle + dx, 0, 128 - paddleW); }
};

// --- Reaction -----------------------------------------------------------------

enum RPhase : uint8_t { RP_INTRO, RP_WAITING, RP_GO, RP_EARLY, RP_RESULT };

class ReactionGame : public Screen {
 public:
  bool key(BotKey k) override {
    bool tap = k == K_TOUCH_FRONT || k == K_TOUCH_LEFT || k == K_TOUCH_RIGHT || k == K_PRESS;
    if (!tap) return false;
    switch (_phase) {
      case RP_INTRO:
      case RP_RESULT:
      case RP_EARLY:
        _phase = RP_WAITING;
        _flashAt = os.frame + 38 + random(0, 62);
        break;
      case RP_WAITING:
        _phase = RP_EARLY;
        os.tone(220, 120);
        break;
      case RP_GO: {
        uint32_t at = os.lastKeyMs ? os.lastKeyMs : millis();
        long ms = (long)(at - _goAtMs);
        if (ms < 0) ms = 0;
        _result = ms;
        _phase = RP_RESULT;
        os.saveBest(G_REACTION, ms, true);
        if (ms < 250) os.eyes.laugh();
        break;
      }
    }
    return true;
  }

  void update(const World &) override {
    if (_phase == RP_WAITING && os.frame >= _flashAt) {
      _phase = RP_GO;
      _goAtMs = millis();
      os.tone(2000, 90);
    }
  }

  void draw(const World &w) override {
    switch (_phase) {
      case RP_INTRO:
        Ui::statusBar(w, "Reaction");
        gfx.strCenterP(F_PRIMARY, 64, 26, PSTR("How fast are you?"));
        gfx.strCenterP(F_SECONDARY, 64, 38, PSTR("Tap the front pad"));
        gfx.strCenterP(F_SECONDARY, 64, 47, PSTR("the moment it flashes"));
        Ui::hintP(PSTR("Tap to start"), true);
        break;
      case RP_WAITING: {
        gfx.strCenterP(F_PRIMARY, 64, 30, PSTR("Wait for it..."));
        uint8_t dots = (os.frame / 8) % 4;
        char d[4] = {0, 0, 0, 0};
        for (uint8_t i = 0; i < dots; i++) d[i] = '.';
        gfx.strCenter(F_PRIMARY, 64, 42, d);
        break;
      }
      case RP_GO:
        gfx.box(0, 0, 128, 64);
        gfx.color = 0;
        gfx.strCenterP(F_PRIMARY, 64, 36, PSTR("TAP!"));
        gfx.color = 1;
        break;
      case RP_EARLY:
        Ui::statusBar(w, "Reaction");
        gfx.strCenterP(F_PRIMARY, 64, 30, PSTR("Too soon!"));
        gfx.strCenterP(F_SECONDARY, 64, 42, PSTR("Wait for the flash"));
        Ui::hintP(PSTR("Tap to retry"), true);
        break;
      case RP_RESULT: {
        Ui::statusBar(w, "Reaction");
        char t[16];
        int16_t tw = gfx.strCenter(F_BIG24, 56, 40, Ui::num(t, _result));
        gfx.str(F_PRIMARY, 58 + tw / 2, 40, "ms");
        gfx.strCenterP(F_SECONDARY, 64, 51,
                       _result < 200 ? PSTR("Lightning!") : (_result < 300 ? PSTR("Quick") : PSTR("Try again")));
        if (os.hasBest(G_REACTION)) {
          snprintf_P(t, sizeof(t), PSTR("BEST %ldMS"), (long)os.settings.best[G_REACTION]);
          gfx.str(F_TINY, 1, 62, t);
        }
        Ui::hintP(PSTR("Again"), true);
        break;
      }
    }
  }

 private:
  RPhase _phase = RP_INTRO;
  uint32_t _flashAt = 0;
  uint32_t _goAtMs = 0;
  long _result = 0;
};

Screen *newGame(GameId id) {
  switch (id) {
    case G_DINO: return new DinoGame();
    case G_BREAKOUT: return new BreakoutGame();
    case G_REACTION: return new ReactionGame();
    default: return newArcadeGame(id);
  }
}
