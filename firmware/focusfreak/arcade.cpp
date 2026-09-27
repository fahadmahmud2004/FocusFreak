// More games for breaks. Port of `lib/botos/arcade.dart`: Snake, Blocks,
// Flap, Paddle, Star Raid, 2048.
#include "assets.h"
#include "screens.h"
#include "ui.h"

enum APhase : uint8_t { AP_READY, AP_PLAYING, AP_PAUSED, AP_OVER };

static float frand() { return random(0, 32768) / 32767.0f; }

// The boxed message every game uses for "ready", "paused" and "game over".
// [title] is PROGMEM, [line] RAM.
static void panel(const char *title, const char *line, int16_t cx = 64, int16_t w = 84) {
  int16_t x = cx - w / 2;
  gfx.color = 0;
  gfx.box(x, 20, w, 24);
  gfx.color = 1;
  gfx.rFrame(x, 20, w, 24, 3);
  gfx.strCenterP(F_PRIMARY, cx, 31, title);
  gfx.strCenter(F_SECONDARY, cx, 40, line);
}

static void panelP(const char *title, const char *lineP, int16_t cx = 64, int16_t w = 84) {
  char line[32];
  strncpy_P(line, lineP, sizeof(line) - 1);
  line[sizeof(line) - 1] = 0;
  panel(title, line, cx, w);
}

static bool isTap(BotKey k) {
  return k == K_PRESS || k == K_TOUCH_FRONT || k == K_TOUCH_LEFT || k == K_TOUCH_RIGHT;
}

// --- Snake --------------------------------------------------------------------

class SnakeGame : public Screen {
 public:
  static const int16_t cell = 4, cols = 32, rows = 13, top = 11;
  static const uint8_t MAX_LEN = 200;

  SnakeGame() { reset(); }

  bool key(BotKey k) override {
    if (_phase != AP_PLAYING) {
      if (isTap(k) || k == K_RIGHT || k == K_LEFT) {
        if (_phase == AP_OVER) reset();
        _phase = AP_PLAYING;
        return true;
      }
      return false;
    }
    switch (k) {
      case K_RIGHT:
      case K_TOUCH_RIGHT:
        _nextDir = (_dir + 1) % 4;
        return true;
      case K_LEFT:
      case K_TOUCH_LEFT:
        _nextDir = (_dir + 3) % 4;
        return true;
      case K_PRESS:
      case K_TOUCH_FRONT:
        _phase = AP_PAUSED;
        return true;
      default:
        return false;
    }
  }

  void update(const World &) override {
    if (_phase != AP_PLAYING) return;
    if (--_wait > 0) return;
    _wait = max(2, 6 - _score / 5);

    // Right, down, left, up: a right turn of the knob is +1.
    static const int8_t DX[4] = {1, 0, -1, 0};
    static const int8_t DY[4] = {0, 1, 0, -1};
    _dir = _nextDir;
    int16_t hx = _x[0] + DX[_dir];
    int16_t hy = _y[0] + DY[_dir];
    bool hitWall = hx < 0 || hy < 0 || hx >= cols || hy >= rows;
    bool hitSelf = false;
    for (uint8_t i = 0; i + 1 < _len; i++) {
      if (_x[i] == hx && _y[i] == hy) hitSelf = true;
    }
    if (hitWall || hitSelf) {
      _phase = AP_OVER;
      os.saveBest(G_SNAKE, _score);
      os.tone(180, 200);
      os.eyes.confused();
      return;
    }
    bool ate = hx == _fx && hy == _fy;
    // Insert the new head at the front.
    uint8_t keep = ate ? _len : _len - 1;
    if (keep >= MAX_LEN) keep = MAX_LEN - 1;
    memmove(_x + 1, _x, keep);
    memmove(_y + 1, _y, keep);
    _x[0] = hx;
    _y[0] = hy;
    _len = keep + 1;
    if (ate) {
      _score++;
      os.tone(1400, 20);
      if (_len >= MAX_LEN) {
        _phase = AP_OVER;
        os.saveBest(G_SNAKE, _score);
        return;
      }
      placeFood();
    }
  }

  void draw(const World &) override {
    char t[24];
    gfx.str(F_TINY, 1, 6, "SNAKE");
    gfx.strRight(F_TINY, 127, 6, Ui::num(t, _score));
    if (os.hasBest(G_SNAKE)) {
      snprintf_P(t, sizeof(t), PSTR("HI %ld"), (long)os.settings.best[G_SNAKE]);
      gfx.strCenter(F_TINY, 64, 6, t);
    }
    gfx.frame(0, top - 2, 128, rows * cell + 3);

    for (uint8_t i = 0; i < _len; i++) {
      int16_t px = _x[i] * cell;
      int16_t py = top + _y[i] * cell;
      if (i == 0) gfx.box(px, py, cell, cell);
      else gfx.box(px, py, cell - 1, cell - 1);
    }
    int16_t fpx = _fx * cell;
    int16_t fpy = top + _fy * cell;
    if ((os.frame / 6) % 2 == 0) {
      gfx.box(fpx + 1, fpy, 2, 4);
      gfx.box(fpx, fpy + 1, 4, 2);
    } else {
      gfx.frame(fpx, fpy, 4, 4);
    }

    switch (_phase) {
      case AP_READY: panelP(PSTR("Snake"), PSTR("Turn the knob to steer")); break;
      case AP_PAUSED: panelP(PSTR("Paused"), PSTR("Tap to carry on")); break;
      case AP_OVER:
        snprintf_P(t, sizeof(t), PSTR("Length %u. Tap"), _len);
        panel(PSTR("Game over"), t);
        break;
      default: break;
    }
  }

 private:
  APhase _phase = AP_READY;
  uint8_t _x[MAX_LEN], _y[MAX_LEN];
  uint8_t _len = 0;
  uint8_t _dir = 0, _nextDir = 0;
  uint8_t _fx = 20, _fy = 6;
  int16_t _score = 0;
  int8_t _wait = 0;

  void reset() {
    _len = 3;
    _x[0] = 8; _y[0] = 6;
    _x[1] = 7; _y[1] = 6;
    _x[2] = 6; _y[2] = 6;
    _dir = 0;
    _nextDir = 0;
    _score = 0;
    placeFood();
  }

  void placeFood() {
    for (uint16_t tries = 0; tries < 2000; tries++) {
      uint8_t fx = random(0, cols), fy = random(0, rows);
      bool onBody = false;
      for (uint8_t i = 0; i < _len; i++) {
        if (_x[i] == fx && _y[i] == fy) onBody = true;
      }
      if (!onBody) {
        _fx = fx;
        _fy = fy;
        return;
      }
    }
  }
};

// --- Blocks -------------------------------------------------------------------

class BlocksGame : public Screen {
 public:
  static const int8_t W = 10, H = 20, cell = 3, x0 = 44, y0 = 2;

  BlocksGame() {
    _next = random(0, 7);
    spawn();
  }

  bool key(BotKey k) override {
    if (_phase != AP_PLAYING) {
      if (isTap(k)) {
        if (_phase == AP_OVER) reset();
        _phase = AP_PLAYING;
        return true;
      }
      return false;
    }
    switch (k) {
      case K_LEFT: move(-1); break;
      case K_RIGHT: move(1); break;
      case K_PRESS:
      case K_TOUCH_RIGHT: rotate(); break;
      case K_TOUCH_LEFT:
        if (drop()) _score++;
        break;
      case K_TOUCH_FRONT:
      case K_HOLD: {
        int16_t n = 0;
        while (drop()) n++;
        _score += n * 2;
        break;
      }
      default:
        return false;
    }
    return true;
  }

  void update(const World &) override {
    if (_flash > 0) _flash--;
    if (_phase != AP_PLAYING) return;
    int16_t speed = max(2, 22 - level() * 2);
    if (++_fall >= speed) {
      _fall = 0;
      drop();
    }
  }

  void draw(const World &) override {
    gfx.frame(x0 - 2, y0 - 2, W * cell + 4, H * cell + 4);
    for (int8_t y = 0; y < H; y++) {
      for (int8_t x = 0; x < W; x++) {
        if (_board[y * W + x]) gfx.box(x0 + x * cell, y0 + y * cell, cell - 1, cell - 1);
      }
    }
    // Where it will land, dotted.
    if (_phase == AP_PLAYING) {
      int8_t gy = _py;
      while (fits(_px, _py, _px, gy + 1, _cells)) gy++;
      for (uint8_t i = 0; i < 4; i++) {
        gfx.pixel(x0 + (_px + _cells[i][0]) * cell + 1, y0 + (gy + _cells[i][1]) * cell + 1);
      }
    }
    for (uint8_t i = 0; i < 4; i++) {
      int8_t by = _py + _cells[i][1];
      if (by < 0) continue;
      gfx.box(x0 + (_px + _cells[i][0]) * cell, y0 + by * cell, cell, cell);
    }

    char t[12];
    gfx.str(F_TINY, 0, 6, "SCORE");
    gfx.str(F_SECONDARY, 0, 16, Ui::num(t, _score));
    gfx.str(F_TINY, 0, 26, "LINES");
    gfx.str(F_SECONDARY, 0, 36, Ui::num(t, _lines));
    gfx.str(F_TINY, 0, 46, "LEVEL");
    gfx.str(F_SECONDARY, 0, 56, Ui::num(t, level()));

    gfx.str(F_TINY, 84, 6, "NEXT");
    for (uint8_t i = 0; i < 4; i++) {
      gfx.box(86 + shape(_next, i, 0) * 4, 12 + shape(_next, i, 1) * 4, 3, 3);
    }
    if (os.hasBest(G_BLOCKS)) {
      gfx.str(F_TINY, 84, 34, "BEST");
      gfx.str(F_SECONDARY, 84, 44, Ui::num(t, os.settings.best[G_BLOCKS]));
    }

    if (_flash > 0 && (_flash & 1) == 0) {
      gfx.color = 2;
      gfx.box(x0, y0, W * cell, H * cell);
      gfx.color = 1;
    }

    if (_phase == AP_READY) panelP(PSTR("Blocks"), PSTR("Press to rotate"), 59, 76);
    else if (_phase == AP_OVER) panelP(PSTR("Game over"), PSTR("Tap to retry"), 59, 76);
  }

 private:
  APhase _phase = AP_READY;
  uint8_t _board[W * H] = {};
  int8_t _cells[4][2];
  uint8_t _kind = 0, _next = 0;
  int8_t _px = 3, _py = 0;
  long _score = 0;
  int16_t _lines = 0;
  int16_t _fall = 0;
  int8_t _flash = 0;

  int16_t level() const { return _lines / 10 + 1; }

  // The seven pieces, each as four cells in its spawn rotation.
  static int8_t shape(uint8_t kind, uint8_t i, uint8_t axis) {
    static const int8_t S[7][4][2] PROGMEM = {
        {{0, 1}, {1, 1}, {2, 1}, {3, 1}},  // I
        {{1, 0}, {2, 0}, {1, 1}, {2, 1}},  // O
        {{1, 0}, {0, 1}, {1, 1}, {2, 1}},  // T
        {{1, 0}, {2, 0}, {0, 1}, {1, 1}},  // S
        {{0, 0}, {1, 0}, {1, 1}, {2, 1}},  // Z
        {{0, 0}, {0, 1}, {1, 1}, {2, 1}},  // J
        {{2, 0}, {0, 1}, {1, 1}, {2, 1}},  // L
    };
    return (int8_t)pgm_read_byte(&S[kind][i][axis]);
  }

  void reset() {
    memset(_board, 0, sizeof(_board));
    _score = 0;
    _lines = 0;
    spawn();
  }

  void spawn() {
    _kind = _next;
    _next = random(0, 7);
    for (uint8_t i = 0; i < 4; i++) {
      _cells[i][0] = shape(_kind, i, 0);
      _cells[i][1] = shape(_kind, i, 1);
    }
    _px = 3;
    _py = 0;
    if (!fits(_px, _py, _px, _py, _cells)) {
      _phase = AP_OVER;
      os.saveBest(G_BLOCKS, _score);
      os.tone(160, 250);
      os.eyes.confused();
    }
  }

  bool fits(int8_t, int8_t, int8_t ox, int8_t oy, int8_t cells[4][2]) const {
    for (uint8_t i = 0; i < 4; i++) {
      int8_t bx = ox + cells[i][0];
      int8_t by = oy + cells[i][1];
      if (bx < 0 || bx >= W || by >= H) return false;
      if (by >= 0 && _board[by * W + bx]) return false;
    }
    return true;
  }

  void move(int8_t dx) {
    if (fits(_px, _py, _px + dx, _py, _cells)) _px += dx;
  }

  void rotate() {
    if (_kind == 1) return;  // O
    // Clockwise about the centre of a 3 x 3 (4 x 4 for I) box.
    int8_t size = _kind == 0 ? 3 : 2;
    int8_t turned[4][2];
    for (uint8_t i = 0; i < 4; i++) {
      turned[i][0] = size - _cells[i][1];
      turned[i][1] = _cells[i][0];
    }
    static const int8_t kicks[5] = {0, -1, 1, -2, 2};
    for (uint8_t k = 0; k < 5; k++) {
      if (fits(_px, _py, _px + kicks[k], _py, turned)) {
        memcpy(_cells, turned, sizeof(_cells));
        _px += kicks[k];
        os.tone(900, 8);
        return;
      }
    }
  }

  bool drop() {
    if (fits(_px, _py, _px, _py + 1, _cells)) {
      _py++;
      return true;
    }
    lock();
    return false;
  }

  void lock() {
    for (uint8_t i = 0; i < 4; i++) {
      int8_t by = _py + _cells[i][1];
      if (by >= 0) _board[by * W + _px + _cells[i][0]] = 1;
    }
    uint8_t cleared = 0;
    for (int8_t y = H - 1; y >= 0; y--) {
      bool full = true;
      for (int8_t x = 0; x < W; x++) {
        if (!_board[y * W + x]) full = false;
      }
      if (!full) continue;
      cleared++;
      for (int8_t yy = y; yy > 0; yy--) memcpy(_board + yy * W, _board + (yy - 1) * W, W);
      memset(_board, 0, W);
      y++;
    }
    if (cleared > 0) {
      static const int16_t points[5] = {0, 40, 100, 300, 1200};
      _lines += cleared;
      _score += (long)points[cleared > 4 ? 4 : cleared] * level();
      _flash = 6;
      os.tone(cleared == 4 ? 1800 : 1300, 40);
      if (cleared == 4) os.eyes.laugh();
    } else {
      os.tone(500, 10);
    }
    spawn();
  }
};

// --- Flap ---------------------------------------------------------------------

class FlapGame : public Screen {
 public:
  static const int16_t birdX = 26, gap = 24;

  bool key(BotKey k) override {
    if (!isTap(k) && k != K_RIGHT && k != K_LEFT) return false;
    switch (_phase) {
      case AP_READY:
      case AP_OVER:
        reset();
        _phase = AP_PLAYING;
        _vy = -2.6f;
        break;
      case AP_PLAYING:
        _vy = -2.6f;
        os.tone(1100, 12);
        break;
      case AP_PAUSED:
        _phase = AP_PLAYING;
        break;
    }
    return true;
  }

  void update(const World &) override {
    if (_phase != AP_PLAYING) {
      if (_phase == AP_READY) _y = 30 + sin(os.frame / 6.0f) * 3;
      return;
    }
    _vy = min(3.2f, _vy + 0.28f);
    _y += _vy;
    _scroll = fmod(_scroll + 1.4f, 8.0f);
    for (uint8_t i = 0; i < _count; i++) {
      Pipe &p = _pipes[i];
      p.x -= 1.4f;
      if (!p.passed && p.x + 10 < birdX) {
        p.passed = true;
        _score++;
        os.tone(1600, 15);
      }
    }
    uint8_t kept = 0;
    for (uint8_t i = 0; i < _count; i++) {
      if (_pipes[i].x >= -12) _pipes[kept++] = _pipes[i];
    }
    _count = kept;
    if ((_count == 0 || _pipes[_count - 1].x < 76) && _count < MAX_PIPES) {
      _pipes[_count++] = {130, (int8_t)(14 + random(0, 28)), false};
    }

    int16_t topY = (int16_t)lround(_y);
    bool dead = topY < 0 || topY + 6 > 58;
    for (uint8_t i = 0; i < _count; i++) {
      int16_t px = (int16_t)lround(_pipes[i].x);
      if (birdX + 7 > px && birdX < px + 10) {
        if (topY + 1 < _pipes[i].gapTop || topY + 5 > _pipes[i].gapTop + gap) dead = true;
      }
    }
    if (dead) {
      _phase = AP_OVER;
      os.saveBest(G_FLAP, _score);
      os.tone(200, 180);
      os.eyes.confused();
    }
  }

  void draw(const World &) override {
    for (uint8_t i = 0; i < _count; i++) {
      int16_t x = (int16_t)lround(_pipes[i].x);
      int16_t g = _pipes[i].gapTop;
      gfx.box(x + 1, 0, 8, g - 3);
      gfx.box(x, g - 4, 10, 4);
      int16_t bottom = g + gap;
      gfx.box(x, bottom, 10, 4);
      gfx.box(x + 1, bottom + 4, 8, 58 - bottom - 4);
    }
    gfx.hLine(0, 58, 128);
    for (int16_t x = -(int16_t)lround(_scroll); x < 128; x += 8) gfx.line(x, 63, x + 4, 59);
    gfx.bitmap(birdX, (int16_t)lround(_y), _vy < 0 || (os.frame / 4) % 2 == 0 ? SPR_birdUp : SPR_birdDown);
    gfx.color = 0;
    gfx.box(58, 0, 12, 9);
    gfx.color = 1;
    char t[28];
    gfx.strCenter(F_SECONDARY, 64, 8, Ui::num(t, _score));

    if (_phase == AP_READY) {
      panelP(PSTR("Flap"), PSTR("Tap to fly"));
    } else if (_phase == AP_OVER) {
      long best = os.hasBest(G_FLAP) ? os.settings.best[G_FLAP] : _score;
      snprintf_P(t, sizeof(t), PSTR("Score %d  Best %ld"), _score, best);
      panel(PSTR("Game over"), t);
    }
  }

 private:
  struct Pipe {
    float x;
    int8_t gapTop;
    bool passed;
  };
  static const uint8_t MAX_PIPES = 5;

  APhase _phase = AP_READY;
  float _y = 30, _vy = 0, _scroll = 0;
  int16_t _score = 0;
  Pipe _pipes[MAX_PIPES];
  uint8_t _count = 0;

  void reset() {
    _y = 30;
    _vy = 0;
    _score = 0;
    _count = 1;
    _pipes[0] = {140, (int8_t)(16 + random(0, 24)), false};
  }
};

// --- Paddle -------------------------------------------------------------------

class PaddleGame : public Screen {
 public:
  static const int16_t padH = 14;
  static const uint8_t winAt = 7;

  bool key(BotKey k) override {
    if (_phase != AP_PLAYING) {
      if (isTap(k)) {
        _you = 0;
        _bot = 0;
        _phase = AP_PLAYING;
        serve(1);
        return true;
      }
    }
    switch (k) {
      case K_LEFT:
      case K_TOUCH_LEFT: move(-5); return true;
      case K_RIGHT:
      case K_TOUCH_RIGHT: move(5); return true;
      case K_PRESS:
      case K_TOUCH_FRONT: return true;
      default: return false;
    }
  }

  void update(const World &) override {
    if (_phase != AP_PLAYING) return;

    // The bot follows the ball, a little slowly: it can be beaten.
    float target = _by - padH / 2.0f;
    int8_t lead = constrain(_you - _bot, 0, 4);
    float reach = 1.0f + lead * 0.15f;
    if (_vx > 0) _botY += constrain(target - _botY, -reach, reach);
    _botY = constrain(_botY, 10, 63 - padH);

    if (_serveWait > 0) {
      _serveWait--;
      return;
    }
    _bx += _vx;
    _by += _vy;
    if (_by <= 11 || _by >= 61) {
      _vy = -_vy;
      _by = constrain(_by, 11, 61);
    }

    if (_vx < 0 && _bx <= 5 && _bx >= 2 && _by + 2 >= _youY && _by <= _youY + padH) bounce(_youY, 1);
    if (_vx > 0 && _bx >= 121 && _bx <= 124 && _by + 2 >= _botY && _by <= _botY + padH) bounce(_botY, -1);

    if (_bx < -2) {
      _bot++;
      os.tone(220, 120);
      point(-1);
    } else if (_bx > 128) {
      _you++;
      os.tone(1500, 60);
      point(1);
    }
  }

  void draw(const World &) override {
    char t[28];
    gfx.strCenter(F_SECONDARY, 52, 8, Ui::num(t, _you));
    gfx.strCenter(F_SECONDARY, 76, 8, Ui::num(t, _bot));
    gfx.str(F_TINY, 1, 6, "YOU");
    gfx.strRight(F_TINY, 127, 6, "BOT");
    gfx.hLine(0, 9, 128);
    for (int16_t y = 11; y < 64; y += 4) gfx.vLine(64, y, 2);
    gfx.rBox(1, (int16_t)lround(_youY), 3, padH, 1);
    gfx.rBox(124, (int16_t)lround(_botY), 3, padH, 1);
    if (_phase == AP_PLAYING && (_serveWait == 0 || (_serveWait & 1) == 0)) {
      gfx.box((int16_t)lround(_bx), (int16_t)lround(_by), 2, 2);
    }
    if (_phase == AP_READY) {
      snprintf_P(t, sizeof(t), PSTR("First to %u. Tap"), winAt);
      panel(PSTR("Paddle"), t);
    } else if (_phase == AP_OVER) {
      snprintf_P(t, sizeof(t), PSTR("%u to %u. Tap"), _you, _bot);
      panel(_won ? PSTR("You win") : PSTR("Bot wins"), t);
    }
  }

 private:
  APhase _phase = AP_READY;
  float _youY = 25, _botY = 25, _bx = 64, _by = 32, _vx = 1.6f, _vy = 0.8f;
  uint8_t _you = 0, _bot = 0;
  uint8_t _serveWait = 0;
  bool _won = false;

  void serve(int8_t toward) {
    _bx = 64;
    _by = 20 + random(0, 24);
    _vx = 1.6f * toward;
    _vy = (frand() - 0.5f) * 2;
    _serveWait = 25;
  }

  void move(float dy) { _youY = constrain(_youY + dy, 10, 63 - padH); }

  void bounce(float paddle, int8_t side) {
    float hit = constrain((_by + 1 - paddle) / padH, 0.0f, 1.0f);
    float speed = min(3.4f, (float)fabs(_vx) + 0.12f);
    _vx = speed * side;
    _vy = (hit - 0.5f) * 3.2f;
    os.tone(side > 0 ? 700 : 520, 12);
  }

  void point(int8_t scorer) {
    if (_you >= winAt || _bot >= winAt) {
      _won = _you > _bot;
      _phase = AP_OVER;
      os.saveBest(G_PADDLE, _you);
      if (_won) os.eyes.laugh();
      return;
    }
    serve(-scorer);
  }
};

// --- Star Raid ----------------------------------------------------------------

class StarRaidGame : public Screen {
 public:
  static const uint8_t cols = 7, rows = 3;
  static const uint8_t MAX_BOMBS = 6;

  StarRaidGame() { wave(); }

  bool key(BotKey k) override {
    if (_phase != AP_PLAYING) {
      if (isTap(k)) {
        if (_phase == AP_OVER) {
          _score = 0;
          _lives = 3;
          _level = 1;
          wave();
        }
        _phase = AP_PLAYING;
        return true;
      }
      return false;
    }
    switch (k) {
      case K_LEFT: _ship = constrain(_ship - 7, 0, 119); break;
      case K_RIGHT: _ship = constrain(_ship + 7, 0, 119); break;
      case K_TOUCH_LEFT: _ship = constrain(_ship - 10, 0, 119); fire(); break;
      case K_TOUCH_RIGHT: _ship = constrain(_ship + 10, 0, 119); fire(); break;
      case K_PRESS:
      case K_TOUCH_FRONT: fire(); break;
      default: return false;
    }
    return true;
  }

  void update(const World &) override {
    if (_hitFlash > 0) _hitFlash--;
    if (_phase != AP_PLAYING) return;

    // The formation marches, and steps down at each edge.
    int16_t minX = 999, maxX = -999, maxY = -999;
    for (uint8_t i = 0; i < cols * rows; i++) {
      if (!_alive[i]) continue;
      int16_t x = (int16_t)lround(_ox + (i % cols) * 13);
      int16_t y = (int16_t)lround(_oy + (i / cols) * 10);
      minX = min(minX, x);
      maxX = max(maxX, (int16_t)(x + 9));
      maxY = max(maxY, (int16_t)(y + 8));
    }
    _ox += _dx;
    if ((maxX >= 127 && _dx > 0) || (minX <= 0 && _dx < 0)) {
      _dx = -_dx * 1.04f;
      _oy += 3;
    }
    if (maxY >= 54) {
      _lives = 0;
      over();
      return;
    }

    // The shot.
    if (_shotX >= 0) {
      _shotY -= 3;
      if (_shotY < 9) {
        _shotX = -1;
      } else {
        for (uint8_t i = 0; i < cols * rows; i++) {
          if (!_alive[i]) continue;
          int16_t x = (int16_t)lround(_ox + (i % cols) * 13);
          int16_t y = (int16_t)lround(_oy + (i / cols) * 10);
          if (_shotX >= x && _shotX <= x + 8 && _shotY >= y && _shotY <= y + 8) {
            _alive[i] = false;
            _shotX = -1;
            _score += (rows - i / cols) * 10;
            os.tone(600, 25);
            // Fewer left, faster march.
            _dx *= 1.03f;
            break;
          }
        }
      }
    }
    uint8_t left = 0;
    for (uint8_t i = 0; i < cols * rows; i++) left += _alive[i];
    if (left == 0) {
      _level++;
      wave();
      os.eyes.laugh();
      return;
    }

    // Bombs.
    if (_bombCount < 1 + _level / 2 && _bombCount < MAX_BOMBS && random(0, 40) == 0) {
      uint8_t pick = random(0, left);
      for (uint8_t i = 0; i < cols * rows; i++) {
        if (!_alive[i]) continue;
        if (pick-- == 0) {
          _bombs[_bombCount][0] = _ox + (i % cols) * 13 + 4;
          _bombs[_bombCount][1] = _oy + (i / cols) * 10 + 8;
          _bombCount++;
          break;
        }
      }
    }
    for (int8_t b = _bombCount - 1; b >= 0; b--) {
      float x = _bombs[b][0];
      float ny = _bombs[b][1] + 1.3f;
      if (ny > 63) {
        removeBomb(b);
        continue;
      }
      if (ny >= 57 && x >= _ship && x <= _ship + 9) {
        removeBomb(b);
        _lives--;
        _hitFlash = 12;
        os.tone(150, 160);
        if (_lives <= 0) {
          over();
          return;
        }
        continue;
      }
      _bombs[b][1] = ny;
    }
  }

  void draw(const World &) override {
    char t[24];
    gfx.str(F_TINY, 1, 6, Ui::num(t, _score));
    snprintf_P(t, sizeof(t), PSTR("WAVE %u"), _level);
    gfx.strCenter(F_TINY, 64, 6, t);
    for (int8_t i = 0; i < _lives; i++) gfx.bitmap(122 - i * 5, 2, ICO_heartSmall);
    const uint8_t *sprite = (os.frame / 10) % 2 == 0 ? SPR_alienA : SPR_alienB;
    for (uint8_t i = 0; i < cols * rows; i++) {
      if (!_alive[i]) continue;
      gfx.bitmap((int16_t)lround(_ox + (i % cols) * 13), (int16_t)lround(_oy + (i / cols) * 10), sprite);
    }
    if (_shotX >= 0) gfx.vLine(_shotX, (int16_t)lround(_shotY), 3);
    for (uint8_t b = 0; b < _bombCount; b++) {
      int16_t bx = (int16_t)lround(_bombs[b][0]);
      int16_t by = (int16_t)lround(_bombs[b][1]);
      gfx.pixel(bx, by);
      gfx.pixel(bx + ((os.frame / 3) % 2 == 0 ? 1 : -1), by + 1);
      gfx.pixel(bx, by + 2);
    }
    if (_hitFlash == 0 || (_hitFlash & 1) == 0) gfx.bitmap((int16_t)lround(_ship), 58, SPR_ship);
    if (_phase == AP_READY) {
      panelP(PSTR("Star Raid"), PSTR("Turn to move, tap to fire"));
    } else if (_phase == AP_OVER) {
      snprintf_P(t, sizeof(t), PSTR("Score %ld. Tap"), _score);
      panel(PSTR("Game over"), t);
    }
  }

 private:
  APhase _phase = AP_READY;
  bool _alive[cols * rows];
  float _ox = 8, _oy = 12, _dx = 0.35f, _ship = 60;
  int16_t _shotX = -1;
  float _shotY = 0;
  float _bombs[MAX_BOMBS][2];
  uint8_t _bombCount = 0;
  long _score = 0;
  int8_t _lives = 3;
  uint8_t _level = 1;
  uint8_t _hitFlash = 0;

  void wave() {
    memset(_alive, 1, sizeof(_alive));
    _ox = 8;
    _oy = 12;
    _dx = 0.3f + _level * 0.08f;
    _bombCount = 0;
    _shotX = -1;
  }

  void fire() {
    if (_shotX >= 0) return;
    _shotX = (int16_t)lround(_ship) + 4;
    _shotY = 56;
    os.tone(1800, 10);
  }

  void removeBomb(int8_t b) {
    for (uint8_t i = b; i + 1 < _bombCount; i++) {
      _bombs[i][0] = _bombs[i + 1][0];
      _bombs[i][1] = _bombs[i + 1][1];
    }
    _bombCount--;
  }

  void over() {
    _phase = AP_OVER;
    os.saveBest(G_RAID, _score);
    os.tone(120, 300);
    os.eyes.confused();
  }
};

// --- 2048 ---------------------------------------------------------------------

class Game2048 : public Screen {
 public:
  static const int8_t N = 4, cw = 16, ch = 15, x0 = 1, y0 = 3;

  Game2048() { reset(); }

  bool key(BotKey k) override {
    if (_over) {
      if (isTap(k)) reset();
      return isTap(k);
    }
    switch (k) {
      case K_LEFT: go(0); break;
      case K_RIGHT: go(1); break;
      case K_TOUCH_LEFT:
      case K_PRESS: go(2); break;
      case K_TOUCH_RIGHT:
      case K_TOUCH_FRONT: go(3); break;
      default: return false;
    }
    os.saveBest(G_2048, _score);
    return true;
  }

  void draw(const World &) override {
    char t[12];
    for (uint8_t i = 0; i < N * N; i++) {
      int16_t x = x0 + (i % N) * cw;
      int16_t y = y0 + (i / N) * ch;
      uint16_t v = _grid[i];
      int8_t grow = i == _bump && os.frame - _bumpAt < 4 ? 0 : 1;
      if (v == 0) {
        gfx.pixel(x + cw / 2 - 1, y + ch / 2 - 1);
        continue;
      }
      if (v >= 1024) snprintf_P(t, sizeof(t), PSTR("%uK"), v / 1024);
      else Ui::num(t, v);
      if (v >= 8) {
        gfx.rBox(x + grow, y + grow, cw - 1 - grow * 2, ch - 1 - grow * 2, 2);
        gfx.color = 0;
      } else {
        gfx.rFrame(x + grow, y + grow, cw - 1 - grow * 2, ch - 1 - grow * 2, 2);
      }
      bool small = strlen(t) > 2;
      gfx.strCenter(small ? F_TINY : F_SECONDARY, x + cw / 2 - 1, y + (small ? 10 : 11), t);
      gfx.color = 1;
    }

    const int16_t rx = 70;
    gfx.str(F_PRIMARY, rx, 11, "2048");
    gfx.str(F_TINY, rx, 21, "SCORE");
    gfx.str(F_SECONDARY, rx, 31, Ui::num(t, _score));
    gfx.str(F_TINY, rx, 41, "BEST");
    gfx.str(F_SECONDARY, rx, 51, Ui::num(t, os.hasBest(G_2048) ? os.settings.best[G_2048] : 0));
    gfx.str(F_TINY, rx, 62, "PADS: UP/DN");

    if (_over) {
      char line[24];
      snprintf_P(line, sizeof(line), PSTR("Score %ld. Tap"), _score);
      panel(PSTR("No moves"), line);
    }
    if (_won && !_over && os.frame % 50 < 25) gfx.str(F_TINY, rx + 30, 11, "WIN");
  }

 private:
  uint16_t _grid[N * N];
  long _score = 0;
  bool _over = false, _won = false;
  int8_t _bump = -1;
  uint32_t _bumpAt = 0;

  void reset() {
    memset(_grid, 0, sizeof(_grid));
    _score = 0;
    _over = false;
    _won = false;
    add();
    add();
  }

  void add() {
    uint8_t empty = 0;
    for (uint8_t i = 0; i < N * N; i++) empty += _grid[i] == 0;
    if (!empty) return;
    uint8_t pick = random(0, empty);
    for (uint8_t i = 0; i < N * N; i++) {
      if (_grid[i]) continue;
      if (pick-- == 0) {
        _grid[i] = random(0, 10) == 0 ? 4 : 2;
        _bump = i;
        _bumpAt = os.frame;
        return;
      }
    }
  }

  // Cell index of step b along line a, sliding toward the start of the line.
  static uint8_t cellOf(uint8_t dir, uint8_t a, uint8_t b) {
    switch (dir) {
      case 0: return a * N + b;
      case 1: return a * N + (N - 1 - b);
      case 2: return b * N + a;
      default: return (N - 1 - b) * N + a;
    }
  }

  void go(uint8_t dir) {
    bool moved = false;
    uint16_t best = 0;
    for (uint8_t a = 0; a < N; a++) {
      uint16_t values[N];
      uint8_t n = 0;
      for (uint8_t b = 0; b < N; b++) {
        uint16_t v = _grid[cellOf(dir, a, b)];
        if (v) values[n++] = v;
      }
      uint16_t merged[N];
      uint8_t m = 0;
      for (uint8_t k = 0; k < n; k++) {
        if (k + 1 < n && values[k] == values[k + 1]) {
          uint16_t v = values[k] * 2;
          merged[m++] = v;
          _score += v;
          if (v > best) best = v;
          k++;
        } else {
          merged[m++] = values[k];
        }
      }
      for (uint8_t b = 0; b < N; b++) {
        uint16_t v = b < m ? merged[b] : 0;
        uint8_t c = cellOf(dir, a, b);
        if (_grid[c] != v) moved = true;
        _grid[c] = v;
      }
    }
    if (best >= 2048 && !_won) {
      _won = true;
      os.eyes.laugh();
    }
    if (best > 0) os.tone(600 + min(best, (uint16_t)2048) / 2, 15);
    if (!moved) return;
    add();
    if (!canMove()) {
      _over = true;
      os.saveBest(G_2048, _score);
      os.eyes.confused();
    }
  }

  bool canMove() const {
    for (uint8_t i = 0; i < N * N; i++) {
      if (_grid[i] == 0) return true;
      uint8_t x = i % N;
      if (x + 1 < N && _grid[i] == _grid[i + 1]) return true;
      if (i + N < N * N && _grid[i] == _grid[i + N]) return true;
    }
    return false;
  }
};

Screen *newArcadeGame(GameId id) {
  switch (id) {
    case G_SNAKE: return new SnakeGame();
    case G_BLOCKS: return new BlocksGame();
    case G_FLAP: return new FlapGame();
    case G_PADDLE: return new PaddleGame();
    case G_RAID: return new StarRaidGame();
    case G_2048: return new Game2048();
    default: return nullptr;
  }
}
