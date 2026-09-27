/// More games for breaks, each built around the bot's own controls.
///
/// * Snake: the knob steers, one detent a quarter turn.
/// * Blocks: the knob moves, press rotates, the front pad drops.
/// * Flap: any tap flaps.
/// * Paddle: the knob is your paddle, against the bot.
/// * Star Raid: the knob moves the ship, a tap fires.
/// * 2048: the knob slides left and right, the top pads up and down.
///
/// All one-bit, 128 x 64, and each keeps a best score.
library;

import 'dart:math' as math;

import 'icons.dart';
import 'os.dart';
import 'screens.dart';

enum _Phase { ready, playing, paused, over }

void _saveBest(BotOs os, String game, int score) {
  final best = os.settings.best[game];
  if (best != null && score <= best) return;
  os.settings.best[game] = score;
  os.emit(SaveSetting('best.$game', score));
}

void _tone(BotOs os, int hz, int ms) {
  if (os.settings.sound) os.emit(PlayTone(hz, ms));
}

/// The boxed message every game uses for "ready", "paused" and "game over".
void _panel(Gfx g, String title, String line, {int cx = 64, int w = 84}) {
  final x = cx - w ~/ 2;
  g.color = 0;
  g.box(x, 20, w, 24);
  g.color = 1;
  g.rFrame(x, 20, w, 24, 3);
  g.strCenter(BotFonts.primary, cx, 31, title);
  g.strCenter(BotFonts.secondary, cx, 40, line);
}

bool _isTap(BotKey k) =>
    k == BotKey.press ||
    k == BotKey.touchFront ||
    k == BotKey.touchLeft ||
    k == BotKey.touchRight;

// --- Snake --------------------------------------------------------------------

class SnakeGame extends BotScreen {
  SnakeGame(super.os) {
    _reset();
  }

  static const int _cell = 4;
  static const int _cols = 32;
  static const int _rows = 13;
  static const int _top = 11;

  // Right, down, left, up: a right turn of the knob is +1.
  static const List<(int, int)> _dirs = <(int, int)>[
    (1, 0),
    (0, 1),
    (-1, 0),
    (0, -1),
  ];

  _Phase _phase = _Phase.ready;
  final List<(int, int)> _body = <(int, int)>[];
  int _dir = 0;
  int _nextDir = 0;
  (int, int) _food = (20, 6);
  int _score = 0;
  int _wait = 0;

  void _reset() {
    _body
      ..clear()
      ..addAll(<(int, int)>[(8, 6), (7, 6), (6, 6)]);
    _dir = 0;
    _nextDir = 0;
    _score = 0;
    _placeFood();
  }

  void _placeFood() {
    while (true) {
      final f = (os.random.nextInt(_cols), os.random.nextInt(_rows));
      if (!_body.contains(f)) {
        _food = f;
        return;
      }
    }
  }

  @override
  bool key(BotKey k) {
    if (_phase != _Phase.playing) {
      if (_isTap(k) || k == BotKey.right || k == BotKey.left) {
        if (_phase == _Phase.over) _reset();
        _phase = _Phase.playing;
        return true;
      }
      return false;
    }
    switch (k) {
      case BotKey.right:
      case BotKey.touchRight:
        _nextDir = (_dir + 1) % 4;
        return true;
      case BotKey.left:
      case BotKey.touchLeft:
        _nextDir = (_dir + 3) % 4;
        return true;
      case BotKey.press:
      case BotKey.touchFront:
        _phase = _Phase.paused;
        return true;
      default:
        return false;
    }
  }

  @override
  void update(BotWorld w) {
    if (_phase != _Phase.playing) return;
    if (--_wait > 0) return;
    _wait = math.max(2, 6 - _score ~/ 5);

    _dir = _nextDir;
    final (dx, dy) = _dirs[_dir];
    final head = (_body.first.$1 + dx, _body.first.$2 + dy);
    final hitWall =
        head.$1 < 0 || head.$2 < 0 || head.$1 >= _cols || head.$2 >= _rows;
    final hitSelf = _body.sublist(0, _body.length - 1).contains(head);
    if (hitWall || hitSelf) {
      _phase = _Phase.over;
      _saveBest(os, 'snake', _score);
      _tone(os, 180, 200);
      os.eyes.confused();
      return;
    }
    _body.insert(0, head);
    if (head == _food) {
      _score++;
      _tone(os, 1400, 20);
      if (_body.length >= _cols * _rows) {
        _phase = _Phase.over;
        _saveBest(os, 'snake', _score);
        return;
      }
      _placeFood();
    } else {
      _body.removeLast();
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    g.str(BotFonts.tiny, 1, 6, 'SNAKE');
    g.strRight(BotFonts.tiny, 127, 6, '$_score');
    final best = os.settings.best['snake'];
    if (best != null) g.strCenter(BotFonts.tiny, 64, 6, 'HI $best');
    g.frame(0, _top - 2, 128, _rows * _cell + 3);

    for (var i = 0; i < _body.length; i++) {
      final (x, y) = _body[i];
      final px = x * _cell;
      final py = _top + y * _cell;
      if (i == 0) {
        g.box(px, py, _cell, _cell);
      } else {
        g.box(px, py, _cell - 1, _cell - 1);
      }
    }
    final (fx, fy) = _food;
    final fpx = fx * _cell;
    final fpy = _top + fy * _cell;
    if ((os.frame ~/ 6).isEven) {
      g.box(fpx + 1, fpy, 2, 4);
      g.box(fpx, fpy + 1, 4, 2);
    } else {
      g.frame(fpx, fpy, 4, 4);
    }

    switch (_phase) {
      case _Phase.ready:
        _panel(g, 'Snake', 'Turn the knob to steer');
      case _Phase.paused:
        _panel(g, 'Paused', 'Tap to carry on');
      case _Phase.over:
        _panel(g, 'Game over', 'Length ${_body.length}. Tap');
      case _Phase.playing:
        break;
    }
  }
}

// --- Blocks -------------------------------------------------------------------

class BlocksGame extends BotScreen {
  BlocksGame(super.os) {
    _next = os.random.nextInt(_shapes.length);
    _spawn();
  }

  static const int _w = 10;
  static const int _h = 20;
  static const int _cell = 3;
  static const int _x0 = 44;
  static const int _y0 = 2;

  /// The seven pieces, each as four cells in its spawn rotation.
  static const List<List<(int, int)>> _shapes = <List<(int, int)>>[
    <(int, int)>[(0, 1), (1, 1), (2, 1), (3, 1)], // I
    <(int, int)>[(1, 0), (2, 0), (1, 1), (2, 1)], // O
    <(int, int)>[(1, 0), (0, 1), (1, 1), (2, 1)], // T
    <(int, int)>[(1, 0), (2, 0), (0, 1), (1, 1)], // S
    <(int, int)>[(0, 0), (1, 0), (1, 1), (2, 1)], // Z
    <(int, int)>[(0, 0), (0, 1), (1, 1), (2, 1)], // J
    <(int, int)>[(2, 0), (0, 1), (1, 1), (2, 1)], // L
  ];

  _Phase _phase = _Phase.ready;
  final List<int> _board = List<int>.filled(_w * _h, 0);
  List<(int, int)> _piece = const <(int, int)>[];
  int _kind = 0;
  int _next = 0;
  int _px = 3;
  int _py = 0;
  int _score = 0;
  int _lines = 0;
  int _fall = 0;
  int _flash = 0;

  int get _level => _lines ~/ 10 + 1;

  void _reset() {
    _board.fillRange(0, _board.length, 0);
    _score = 0;
    _lines = 0;
    _spawn();
  }

  void _spawn() {
    _kind = _next;
    _next = os.random.nextInt(_shapes.length);
    _piece = List<(int, int)>.of(_shapes[_kind]);
    _px = 3;
    _py = 0;
    if (!_fits(_piece, _px, _py)) {
      _phase = _Phase.over;
      _saveBest(os, 'blocks', _score);
      _tone(os, 160, 250);
      os.eyes.confused();
    }
  }

  bool _fits(List<(int, int)> cells, int ox, int oy) {
    for (final (x, y) in cells) {
      final bx = ox + x;
      final by = oy + y;
      if (bx < 0 || bx >= _w || by >= _h) return false;
      if (by >= 0 && _board[by * _w + bx] != 0) return false;
    }
    return true;
  }

  void _move(int dx) {
    if (_fits(_piece, _px + dx, _py)) _px += dx;
  }

  void _rotate() {
    if (_kind == 1) return; // O
    // Clockwise about the centre of a 3 x 3 (4 x 4 for I) box.
    final size = _kind == 0 ? 3 : 2;
    final turned = <(int, int)>[for (final (x, y) in _piece) (size - y, x)];
    for (final kick in const <int>[0, -1, 1, -2, 2]) {
      if (_fits(turned, _px + kick, _py)) {
        _piece = turned;
        _px += kick;
        _tone(os, 900, 8);
        return;
      }
    }
  }

  bool _drop() {
    if (_fits(_piece, _px, _py + 1)) {
      _py++;
      return true;
    }
    _lock();
    return false;
  }

  void _lock() {
    for (final (x, y) in _piece) {
      final by = _py + y;
      if (by >= 0) _board[by * _w + _px + x] = 1;
    }
    var cleared = 0;
    for (var y = _h - 1; y >= 0; y--) {
      var full = true;
      for (var x = 0; x < _w; x++) {
        if (_board[y * _w + x] == 0) full = false;
      }
      if (!full) continue;
      cleared++;
      for (var yy = y; yy > 0; yy--) {
        for (var x = 0; x < _w; x++) {
          _board[yy * _w + x] = _board[(yy - 1) * _w + x];
        }
      }
      for (var x = 0; x < _w; x++) {
        _board[x] = 0;
      }
      y++;
    }
    if (cleared > 0) {
      _lines += cleared;
      _score += const <int>[0, 40, 100, 300, 1200][cleared] * _level;
      _flash = 6;
      _tone(os, cleared == 4 ? 1800 : 1300, 40);
      if (cleared == 4) os.eyes.laugh();
    } else {
      _tone(os, 500, 10);
    }
    _spawn();
  }

  @override
  bool key(BotKey k) {
    if (_phase != _Phase.playing) {
      if (_isTap(k)) {
        if (_phase == _Phase.over) _reset();
        _phase = _Phase.playing;
        return true;
      }
      return false;
    }
    switch (k) {
      case BotKey.left:
        _move(-1);
      case BotKey.right:
        _move(1);
      case BotKey.press:
      case BotKey.touchRight:
        _rotate();
      case BotKey.touchLeft:
        if (_drop()) _score++;
      case BotKey.touchFront:
      case BotKey.hold:
        var rows = 0;
        while (_drop()) {
          rows++;
        }
        _score += rows * 2;
      default:
        return false;
    }
    return true;
  }

  @override
  void update(BotWorld w) {
    if (_flash > 0) _flash--;
    if (_phase != _Phase.playing) return;
    final speed = math.max(2, 22 - _level * 2);
    if (++_fall >= speed) {
      _fall = 0;
      _drop();
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    // The well.
    g.frame(_x0 - 2, _y0 - 2, _w * _cell + 4, _h * _cell + 4);
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        if (_board[y * _w + x] != 0) {
          g.box(_x0 + x * _cell, _y0 + y * _cell, _cell - 1, _cell - 1);
        }
      }
    }
    // Where it will land, dotted.
    if (_phase == _Phase.playing) {
      var gy = _py;
      while (_fits(_piece, _px, gy + 1)) {
        gy++;
      }
      for (final (x, y) in _piece) {
        g.pixel(_x0 + (_px + x) * _cell + 1, _y0 + (gy + y) * _cell + 1);
      }
    }
    for (final (x, y) in _piece) {
      final by = _py + y;
      if (by < 0) continue;
      g.box(_x0 + (_px + x) * _cell, _y0 + by * _cell, _cell, _cell);
    }

    // Left: score and lines.
    g.str(BotFonts.tiny, 0, 6, 'SCORE');
    g.str(BotFonts.secondary, 0, 16, '$_score');
    g.str(BotFonts.tiny, 0, 26, 'LINES');
    g.str(BotFonts.secondary, 0, 36, '$_lines');
    g.str(BotFonts.tiny, 0, 46, 'LEVEL');
    g.str(BotFonts.secondary, 0, 56, '$_level');

    // Right: the next piece and the best.
    g.str(BotFonts.tiny, 84, 6, 'NEXT');
    for (final (x, y) in _shapes[_next]) {
      g.box(86 + x * 4, 12 + y * 4, 3, 3);
    }
    final best = os.settings.best['blocks'];
    if (best != null) {
      g.str(BotFonts.tiny, 84, 34, 'BEST');
      g.str(BotFonts.secondary, 84, 44, '$best');
    }

    if (_flash > 0 && _flash.isEven) {
      g.color = 2;
      g.box(_x0, _y0, _w * _cell, _h * _cell);
      g.color = 1;
    }

    switch (_phase) {
      case _Phase.ready:
        _panel(g, 'Blocks', 'Press to rotate', cx: 59, w: 76);
      case _Phase.over:
        _panel(g, 'Game over', 'Tap to retry', cx: 59, w: 76);
      case _Phase.paused:
      case _Phase.playing:
        break;
    }
  }
}

// --- Flap ---------------------------------------------------------------------

class FlapGame extends BotScreen {
  FlapGame(super.os);

  static const int _birdX = 26;
  static const int _gap = 24;

  static const List<String> _birdUp = <String>[
    '..####..',
    '.#...#.#',
    '###..###',
    '#..#####',
    '#....##.',
    '.####...',
  ];
  static const List<String> _birdDown = <String>[
    '..####..',
    '.#...#.#',
    '#....###',
    '###.####',
    '.##..##.',
    '..###...',
  ];

  _Phase _phase = _Phase.ready;
  double _y = 30;
  double _vy = 0;
  int _score = 0;
  double _scroll = 0;
  final List<_Pipe> _pipes = <_Pipe>[];

  void _reset() {
    _y = 30;
    _vy = 0;
    _score = 0;
    _pipes
      ..clear()
      ..add(_Pipe(140, 16 + os.random.nextInt(24)));
  }

  @override
  bool key(BotKey k) {
    if (!_isTap(k) && k != BotKey.right && k != BotKey.left) return false;
    switch (_phase) {
      case _Phase.ready:
      case _Phase.over:
        _reset();
        _phase = _Phase.playing;
        _vy = -2.6;
      case _Phase.playing:
        _vy = -2.6;
        _tone(os, 1100, 12);
      case _Phase.paused:
        _phase = _Phase.playing;
    }
    return true;
  }

  @override
  void update(BotWorld w) {
    if (_phase != _Phase.playing) {
      if (_phase == _Phase.ready) _y = 30 + math.sin(os.frame / 6) * 3;
      return;
    }
    _vy = math.min(3.2, _vy + 0.28);
    _y += _vy;
    _scroll = (_scroll + 1.4) % 8;
    for (final p in _pipes) {
      p.x -= 1.4;
      if (!p.passed && p.x + 10 < _birdX) {
        p.passed = true;
        _score++;
        _tone(os, 1600, 15);
      }
    }
    _pipes.removeWhere((p) => p.x < -12);
    if (_pipes.isEmpty || _pipes.last.x < 76) {
      _pipes.add(_Pipe(130, 14 + os.random.nextInt(28)));
    }

    final top = _y.round();
    var dead = top < 0 || top + 6 > 58;
    for (final p in _pipes) {
      final px = p.x.round();
      if (_birdX + 7 > px && _birdX < px + 10) {
        if (top + 1 < p.gapTop || top + 5 > p.gapTop + _gap) dead = true;
      }
    }
    if (dead) {
      _phase = _Phase.over;
      _saveBest(os, 'flap', _score);
      _tone(os, 200, 180);
      os.eyes.confused();
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    for (final p in _pipes) {
      final x = p.x.round();
      g.box(x + 1, 0, 8, p.gapTop - 3);
      g.box(x, p.gapTop - 4, 10, 4);
      final bottom = p.gapTop + _gap;
      g.box(x, bottom, 10, 4);
      g.box(x + 1, bottom + 4, 8, 58 - bottom - 4);
    }
    g.hLine(0, 58, 128);
    for (var x = -_scroll.round(); x < 128; x += 8) {
      g.line(x, 63, x + 4, 59);
    }
    g.bitmap(
      _birdX,
      _y.round(),
      _vy < 0 || (os.frame ~/ 4).isEven ? _birdUp : _birdDown,
    );
    g.color = 0;
    g.box(58, 0, 12, 9);
    g.color = 1;
    g.strCenter(BotFonts.secondary, 64, 8, '$_score');

    switch (_phase) {
      case _Phase.ready:
        _panel(g, 'Flap', 'Tap to fly');
      case _Phase.over:
        final best = os.settings.best['flap'] ?? _score;
        _panel(g, 'Game over', 'Score $_score  Best $best');
      case _Phase.paused:
      case _Phase.playing:
        break;
    }
  }
}

class _Pipe {
  _Pipe(this.x, this.gapTop);
  double x;
  final int gapTop;
  bool passed = false;
}

// --- Paddle -------------------------------------------------------------------

class PaddleGame extends BotScreen {
  PaddleGame(super.os);

  static const int _padH = 14;
  static const int _winAt = 7;

  _Phase _phase = _Phase.ready;
  double _you = 25;
  double _bot = 25;
  double _bx = 64;
  double _by = 32;
  double _vx = 1.6;
  double _vy = 0.8;
  int _youScore = 0;
  int _botScore = 0;
  int _serveWait = 0;
  bool _won = false;

  void _serve(int toward) {
    _bx = 64;
    _by = 20 + os.random.nextInt(24).toDouble();
    _vx = 1.6 * toward;
    _vy = (os.random.nextDouble() - 0.5) * 2;
    _serveWait = 25;
  }

  void _move(double dy) => _you = (_you + dy).clamp(10, 63 - _padH).toDouble();

  @override
  bool key(BotKey k) {
    if (_phase != _Phase.playing) {
      if (_isTap(k)) {
        _youScore = 0;
        _botScore = 0;
        _phase = _Phase.playing;
        _serve(1);
        return true;
      }
    }
    switch (k) {
      case BotKey.left:
      case BotKey.touchLeft:
        _move(-5);
        return true;
      case BotKey.right:
      case BotKey.touchRight:
        _move(5);
        return true;
      case BotKey.press:
      case BotKey.touchFront:
        return true;
      default:
        return false;
    }
  }

  @override
  void update(BotWorld w) {
    if (_phase != _Phase.playing) return;

    // The bot follows the ball, a little slowly: it can be beaten.
    final target = _by - _padH / 2;
    final reach = 1.0 + (_youScore - _botScore).clamp(0, 4) * 0.15;
    if (_vx > 0) _bot += (target - _bot).clamp(-reach, reach);
    _bot = _bot.clamp(10, 63 - _padH).toDouble();

    if (_serveWait > 0) {
      _serveWait--;
      return;
    }
    _bx += _vx;
    _by += _vy;
    if (_by <= 11 || _by >= 61) {
      _vy = -_vy;
      _by = _by.clamp(11, 61).toDouble();
    }

    void bounce(double paddle, int side) {
      final hit = ((_by + 1 - paddle) / _padH).clamp(0.0, 1.0);
      final speed = math.min(3.4, _vx.abs() + 0.12);
      _vx = speed * side;
      _vy = (hit - 0.5) * 3.2;
      _tone(os, side > 0 ? 700 : 520, 12);
    }

    if (_vx < 0 &&
        _bx <= 5 &&
        _bx >= 2 &&
        _by + 2 >= _you &&
        _by <= _you + _padH) {
      bounce(_you, 1);
    }
    if (_vx > 0 &&
        _bx >= 121 &&
        _bx <= 124 &&
        _by + 2 >= _bot &&
        _by <= _bot + _padH) {
      bounce(_bot, -1);
    }

    if (_bx < -2) {
      _botScore++;
      _tone(os, 220, 120);
      _point(-1);
    } else if (_bx > 128) {
      _youScore++;
      _tone(os, 1500, 60);
      _point(1);
    }
  }

  void _point(int scorer) {
    if (_youScore >= _winAt || _botScore >= _winAt) {
      _won = _youScore > _botScore;
      _phase = _Phase.over;
      _saveBest(os, 'paddle', _youScore);
      if (_won) os.eyes.laugh();
      return;
    }
    _serve(-scorer);
  }

  @override
  void draw(Gfx g, BotWorld w) {
    g.strCenter(BotFonts.secondary, 52, 8, '$_youScore');
    g.strCenter(BotFonts.secondary, 76, 8, '$_botScore');
    g.str(BotFonts.tiny, 1, 6, 'YOU');
    g.strRight(BotFonts.tiny, 127, 6, 'BOT');
    g.hLine(0, 9, 128);
    for (var y = 11; y < 64; y += 4) {
      g.vLine(64, y, 2);
    }
    g.rBox(1, _you.round(), 3, _padH, 1);
    g.rBox(124, _bot.round(), 3, _padH, 1);
    if (_phase == _Phase.playing && (_serveWait == 0 || _serveWait.isEven)) {
      g.box(_bx.round(), _by.round(), 2, 2);
    }
    switch (_phase) {
      case _Phase.ready:
        _panel(g, 'Paddle', 'First to $_winAt. Tap');
      case _Phase.over:
        _panel(
          g,
          _won ? 'You win' : 'Bot wins',
          '$_youScore to $_botScore. Tap',
        );
      case _Phase.paused:
      case _Phase.playing:
        break;
    }
  }
}

// --- Star Raid ----------------------------------------------------------------

class StarRaidGame extends BotScreen {
  StarRaidGame(super.os) {
    _wave();
  }

  static const int _cols = 7;
  static const int _rows = 3;

  static const List<String> _alienA = <String>[
    '..#...#..',
    '...#.#...',
    '..#####..',
    '.##.#.##.',
    '#########',
    '#.#####.#',
    '#.#...#.#',
    '...#.#...',
  ];
  static const List<String> _alienB = <String>[
    '..#...#..',
    '#..#.#..#',
    '#.#####.#',
    '###.#.###',
    '#########',
    '.#######.',
    '..#...#..',
    '.#.....#.',
  ];
  static const List<String> _ship = <String>[
    '....#....',
    '...###...',
    '...###...',
    '.#######.',
    '#########',
  ];

  _Phase _phase = _Phase.ready;
  final List<bool> _alive = List<bool>.filled(_cols * _rows, true);
  double _ox = 8;
  double _oy = 12;
  double _dx = 0.35;
  double _ship0 = 60;
  int? _shotX;
  double _shotY = 0;
  final List<(double, double)> _bombs = <(double, double)>[];
  int _score = 0;
  int _lives = 3;
  int _level = 1;
  int _hitFlash = 0;

  void _wave() {
    _alive.fillRange(0, _alive.length, true);
    _ox = 8;
    _oy = 12;
    _dx = 0.3 + _level * 0.08;
    _bombs.clear();
    _shotX = null;
  }

  void _fire() {
    if (_shotX != null) return;
    _shotX = _ship0.round() + 4;
    _shotY = 56;
    _tone(os, 1800, 10);
  }

  @override
  bool key(BotKey k) {
    if (_phase != _Phase.playing) {
      if (_isTap(k)) {
        if (_phase == _Phase.over) {
          _score = 0;
          _lives = 3;
          _level = 1;
          _wave();
        }
        _phase = _Phase.playing;
        return true;
      }
      return false;
    }
    switch (k) {
      case BotKey.left:
        _ship0 = (_ship0 - 7).clamp(0, 119).toDouble();
      case BotKey.right:
        _ship0 = (_ship0 + 7).clamp(0, 119).toDouble();
      case BotKey.touchLeft:
        _ship0 = (_ship0 - 10).clamp(0, 119).toDouble();
        _fire();
      case BotKey.touchRight:
        _ship0 = (_ship0 + 10).clamp(0, 119).toDouble();
        _fire();
      case BotKey.press:
      case BotKey.touchFront:
        _fire();
      default:
        return false;
    }
    return true;
  }

  @override
  void update(BotWorld w) {
    if (_hitFlash > 0) _hitFlash--;
    if (_phase != _Phase.playing) return;

    // The formation marches, and steps down at each edge.
    var minX = 999;
    var maxX = -999;
    var maxY = -999;
    for (var i = 0; i < _alive.length; i++) {
      if (!_alive[i]) continue;
      final x = (_ox + (i % _cols) * 13).round();
      final y = (_oy + (i ~/ _cols) * 10).round();
      minX = math.min(minX, x);
      maxX = math.max(maxX, x + 9);
      maxY = math.max(maxY, y + 8);
    }
    _ox += _dx;
    if ((maxX >= 127 && _dx > 0) || (minX <= 0 && _dx < 0)) {
      _dx = -_dx * 1.04;
      _oy += 3;
    }
    if (maxY >= 54) {
      _lives = 0;
      _over();
      return;
    }

    // The shot.
    final sx = _shotX;
    if (sx != null) {
      _shotY -= 3;
      if (_shotY < 9) {
        _shotX = null;
      } else {
        for (var i = 0; i < _alive.length; i++) {
          if (!_alive[i]) continue;
          final x = (_ox + (i % _cols) * 13).round();
          final y = (_oy + (i ~/ _cols) * 10).round();
          if (sx >= x && sx <= x + 8 && _shotY >= y && _shotY <= y + 8) {
            _alive[i] = false;
            _shotX = null;
            _score += (_rows - i ~/ _cols) * 10;
            _tone(os, 600, 25);
            // Fewer left, faster march.
            _dx *= 1.03;
            break;
          }
        }
      }
    }
    if (_alive.every((a) => !a)) {
      _level++;
      _wave();
      os.eyes.laugh();
      return;
    }

    // Bombs.
    if (_bombs.length < 1 + _level ~/ 2 && os.random.nextInt(40) == 0) {
      final shooters = <int>[
        for (var i = 0; i < _alive.length; i++)
          if (_alive[i]) i,
      ];
      final i = shooters[os.random.nextInt(shooters.length)];
      _bombs.add((_ox + (i % _cols) * 13 + 4, _oy + (i ~/ _cols) * 10 + 8));
    }
    for (var b = _bombs.length - 1; b >= 0; b--) {
      final (x, y) = _bombs[b];
      final ny = y + 1.3;
      if (ny > 63) {
        _bombs.removeAt(b);
        continue;
      }
      if (ny >= 57 && x >= _ship0 && x <= _ship0 + 9) {
        _bombs.removeAt(b);
        _lives--;
        _hitFlash = 12;
        _tone(os, 150, 160);
        if (_lives <= 0) {
          _over();
          return;
        }
        continue;
      }
      _bombs[b] = (x, ny);
    }
  }

  void _over() {
    _phase = _Phase.over;
    _saveBest(os, 'raid', _score);
    _tone(os, 120, 300);
    os.eyes.confused();
  }

  @override
  void draw(Gfx g, BotWorld w) {
    g.str(BotFonts.tiny, 1, 6, '$_score');
    g.strCenter(BotFonts.tiny, 64, 6, 'WAVE $_level');
    for (var i = 0; i < _lives; i++) {
      g.bitmap(122 - i * 5, 2, BotIcons.heartSmall);
    }
    final sprite = (os.frame ~/ 10).isEven ? _alienA : _alienB;
    for (var i = 0; i < _alive.length; i++) {
      if (!_alive[i]) continue;
      g.bitmap(
        (_ox + (i % _cols) * 13).round(),
        (_oy + (i ~/ _cols) * 10).round(),
        sprite,
      );
    }
    final sx = _shotX;
    if (sx != null) g.vLine(sx, _shotY.round(), 3);
    for (final (x, y) in _bombs) {
      final bx = x.round();
      final by = y.round();
      g.pixel(bx, by);
      g.pixel(bx + ((os.frame ~/ 3).isEven ? 1 : -1), by + 1);
      g.pixel(bx, by + 2);
    }
    if (_hitFlash == 0 || _hitFlash.isEven) {
      g.bitmap(_ship0.round(), 58, _ship);
    }
    switch (_phase) {
      case _Phase.ready:
        _panel(g, 'Star Raid', 'Turn to move, tap to fire');
      case _Phase.over:
        _panel(g, 'Game over', 'Score $_score. Tap');
      case _Phase.paused:
      case _Phase.playing:
        break;
    }
  }
}

// --- 2048 ---------------------------------------------------------------------

class Game2048 extends BotScreen {
  Game2048(super.os) {
    _reset();
  }

  static const int _n = 4;
  static const int _cw = 16;
  static const int _ch = 15;
  static const int _x0 = 1;
  static const int _y0 = 3;

  final List<int> _grid = List<int>.filled(_n * _n, 0);
  int _score = 0;
  bool _over = false;
  bool _won = false;
  int _bump = -1;
  int _bumpAt = -999;

  void _reset() {
    _grid.fillRange(0, _grid.length, 0);
    _score = 0;
    _over = false;
    _won = false;
    _add();
    _add();
  }

  void _add() {
    final empty = <int>[
      for (var i = 0; i < _grid.length; i++)
        if (_grid[i] == 0) i,
    ];
    if (empty.isEmpty) return;
    final i = empty[os.random.nextInt(empty.length)];
    _grid[i] = os.random.nextInt(10) == 0 ? 4 : 2;
    _bump = i;
    _bumpAt = os.frame;
  }

  /// Slides every line toward its start; [line] lists a line's cell indexes
  /// from the edge being slid to.
  bool _slide(List<List<int>> lines) {
    var moved = false;
    var best = 0;
    for (final line in lines) {
      final values = <int>[
        for (final i in line)
          if (_grid[i] != 0) _grid[i],
      ];
      final merged = <int>[];
      for (var k = 0; k < values.length; k++) {
        if (k + 1 < values.length && values[k] == values[k + 1]) {
          final v = values[k] * 2;
          merged.add(v);
          _score += v;
          best = math.max(best, v);
          k++;
        } else {
          merged.add(values[k]);
        }
      }
      for (var k = 0; k < line.length; k++) {
        final v = k < merged.length ? merged[k] : 0;
        if (_grid[line[k]] != v) moved = true;
        _grid[line[k]] = v;
      }
    }
    if (best >= 2048 && !_won) {
      _won = true;
      os.eyes.laugh();
    }
    if (best > 0) _tone(os, 600 + math.min(best, 2048) ~/ 2, 15);
    return moved;
  }

  void _go(int dir) {
    // 0 left, 1 right, 2 up, 3 down.
    final lines = <List<int>>[
      for (var a = 0; a < _n; a++)
        <int>[
          for (var b = 0; b < _n; b++)
            switch (dir) {
              0 => a * _n + b,
              1 => a * _n + (_n - 1 - b),
              2 => b * _n + a,
              _ => (_n - 1 - b) * _n + a,
            },
        ],
    ];
    if (!_slide(lines)) return;
    _add();
    if (!_canMove()) {
      _over = true;
      _saveBest(os, '2048', _score);
      os.eyes.confused();
    }
  }

  bool _canMove() {
    for (var i = 0; i < _grid.length; i++) {
      if (_grid[i] == 0) return true;
      final x = i % _n;
      if (x + 1 < _n && _grid[i] == _grid[i + 1]) return true;
      if (i + _n < _grid.length && _grid[i] == _grid[i + _n]) return true;
    }
    return false;
  }

  @override
  bool key(BotKey k) {
    if (_over) {
      if (_isTap(k)) _reset();
      return _isTap(k);
    }
    switch (k) {
      case BotKey.left:
        _go(0);
      case BotKey.right:
        _go(1);
      case BotKey.touchLeft:
      case BotKey.press:
        _go(2);
      case BotKey.touchRight:
      case BotKey.touchFront:
        _go(3);
      default:
        return false;
    }
    _saveBest(os, '2048', _score);
    return true;
  }

  @override
  void draw(Gfx g, BotWorld w) {
    for (var i = 0; i < _grid.length; i++) {
      final x = _x0 + (i % _n) * _cw;
      final y = _y0 + (i ~/ _n) * _ch;
      final v = _grid[i];
      final grow = i == _bump && os.frame - _bumpAt < 4 ? 0 : 1;
      if (v == 0) {
        g.pixel(x + _cw ~/ 2 - 1, y + _ch ~/ 2 - 1);
        continue;
      }
      final text = v >= 1024 ? '${v ~/ 1024}K' : '$v';
      if (v >= 8) {
        g.rBox(x + grow, y + grow, _cw - 1 - grow * 2, _ch - 1 - grow * 2, 2);
        g.color = 0;
      } else {
        g.rFrame(x + grow, y + grow, _cw - 1 - grow * 2, _ch - 1 - grow * 2, 2);
      }
      g.strCenter(
        text.length > 2 ? BotFonts.tiny : BotFonts.secondary,
        x + _cw ~/ 2 - 1,
        y + (text.length > 2 ? 10 : 11),
        text,
      );
      g.color = 1;
    }

    const rx = 70;
    g.str(BotFonts.primary, rx, 11, '2048');
    g.str(BotFonts.tiny, rx, 21, 'SCORE');
    g.str(BotFonts.secondary, rx, 31, '$_score');
    final best = os.settings.best['2048'];
    g.str(BotFonts.tiny, rx, 41, 'BEST');
    g.str(BotFonts.secondary, rx, 51, '${best ?? 0}');
    g.str(BotFonts.tiny, rx, 62, 'PADS: UP/DN');

    if (_over) _panel(g, 'No moves', 'Score $_score. Tap');
    if (_won && !_over && os.frame % 50 < 25) {
      g.str(BotFonts.tiny, rx + 30, 11, 'WIN');
    }
  }
}
