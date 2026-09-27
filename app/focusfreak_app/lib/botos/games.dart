/// Games for breaks, built for the bot's own controls.
///
/// * Dino Run: jump with the front pad, a top pad or the knob.
/// * Breakout: the rotary encoder is the paddle.
/// * Reaction: tap the front pad the moment the screen flashes.
///
/// All three are one-bit pixel art on the 128 × 64 panel and keep a best score.
library;

import 'dart:math' as math;

import 'icons.dart';
import 'os.dart';
import 'screens.dart';
import 'ui.dart';

enum _Phase { ready, playing, over }

void _saveBest(BotOs os, String game, int score, {bool lowerIsBetter = false}) {
  final best = os.settings.best[game];
  final better = best == null || (lowerIsBetter ? score < best : score > best);
  if (!better) return;
  os.settings.best[game] = score;
  os.emit(SaveSetting('best.$game', score));
}

// --- Dino Run -----------------------------------------------------------------

class DinoGame extends BotScreen {
  DinoGame(super.os);

  static const int ground = 58;
  static const int dinoX = 8;

  static const List<String> _dinoA = <String>[
    '.......######.',
    '......##.#####',
    '......########',
    '......########',
    '......#####...',
    '......#######.',
    '#....#####....',
    '##..#######...',
    '###########...',
    '.##########...',
    '..#########...',
    '...#######....',
    '....##..##....',
    '....#....#....',
    '....##...##...',
  ];

  static const List<String> _dinoB = <String>[
    '.......######.',
    '......##.#####',
    '......########',
    '......########',
    '......#####...',
    '......#######.',
    '#....#####....',
    '##..#######...',
    '###########...',
    '.##########...',
    '..#########...',
    '...#######....',
    '....###.#.....',
    '....#...##....',
    '....##........',
  ];

  static const List<String> _dinoDead = <String>[
    '.......######.',
    '......#.#.####',
    '......##.#####',
    '......#.#.####',
    '......########',
    '......#######.',
    '#....#####....',
    '##..#######...',
    '###########...',
    '.##########...',
    '..#########...',
    '...#######....',
    '....##..##....',
    '....#....#....',
    '....##...##...',
  ];

  static const List<String> _cactusSmall = <String>[
    '..##..',
    '..##..',
    '#.##..',
    '#.##.#',
    '#.##.#',
    '####.#',
    '.#####',
    '..##..',
    '..##..',
    '..##..',
    '..##..',
    '..##..',
  ];

  static const List<String> _cactusBig = <String>[
    '....##....',
    '....##....',
    '....##..#.',
    '.#..##..#.',
    '.#..##..#.',
    '.#..##..#.',
    '.#..######',
    '.#..##....',
    '.######...',
    '....##....',
    '....##....',
    '....##....',
    '....##....',
    '....##....',
    '....##....',
    '....##....',
  ];

  static const List<String> _birdA = <String>[
    '.....#......',
    '.....##.....',
    '..#..###....',
    '.#####.#####',
    '..#########.',
    '.....###....',
  ];

  static const List<String> _birdB = <String>[
    '............',
    '............',
    '..#.........',
    '.###########',
    '..#########.',
    '.....###....',
    '.....##.....',
    '.....#......',
  ];

  static const List<String> _cloud = <String>[
    '....####...',
    '..##....##.',
    '.#........#',
    '###########',
  ];

  _Phase _phase = _Phase.ready;
  double _y = 0;
  double _vy = 0;
  double _speed = 3.2;
  double _score = 0;
  double _groundScroll = 0;
  double _nextGap = 60;
  final List<_Obstacle> _obstacles = <_Obstacle>[];
  final List<double> _clouds = <double>[30, 95];

  bool get _onGround => _y >= 0;

  void _reset() {
    _y = 0;
    _vy = 0;
    _speed = 3.2;
    _score = 0;
    _nextGap = 60;
    _obstacles.clear();
  }

  @override
  bool key(BotKey k) {
    switch (k) {
      case BotKey.press:
      case BotKey.touchFront:
      case BotKey.touchLeft:
      case BotKey.touchRight:
      case BotKey.right:
        if (_phase != _Phase.playing) {
          _reset();
          _phase = _Phase.playing;
          return true;
        }
        if (_onGround) {
          _vy = -5.6;
          if (os.settings.sound) os.emit(const PlayTone(880, 25));
        }
        return true;
      default:
        return false;
    }
  }

  @override
  void update(BotWorld w) {
    if (_phase != _Phase.playing) return;
    _vy += 0.52;
    _y += _vy;
    if (_y > 0) {
      _y = 0;
      _vy = 0;
    }

    _speed = math.min(7.5, _speed + 0.0025);
    final before = _score.floor();
    _score += _speed / 10;
    if (_score.floor() ~/ 100 > before ~/ 100 && os.settings.sound) {
      os.emit(const PlayTone(1500, 40));
    }
    _groundScroll = (_groundScroll + _speed) % 128;
    for (var i = 0; i < _clouds.length; i++) {
      _clouds[i] -= _speed / 5;
      if (_clouds[i] < -12) _clouds[i] = 130 + os.random.nextInt(40).toDouble();
    }

    for (final o in _obstacles) {
      o.x -= _speed;
    }
    _obstacles.removeWhere((o) => o.x < -16);
    final last = _obstacles.isEmpty ? -999.0 : _obstacles.last.x;
    if (128 - last > _nextGap) {
      final bird = _score > 250 && os.random.nextInt(4) == 0;
      _obstacles.add(
        _Obstacle(
          x: 130,
          kind: bird
              ? _Kind.bird
              : os.random.nextBool()
              ? _Kind.small
              : _Kind.big,
          high: os.random.nextBool(),
        ),
      );
      _nextGap = 50 + _speed * 10 + os.random.nextInt(60);
    }

    // Collision, with boxes a little smaller than the sprites: a hit the
    // player cannot see is a cheat.
    final dinoTop = ground - 15 + _y.round() + 2;
    const dinoLeft = dinoX + 2;
    const dinoRight = dinoX + 11;
    final dinoBottom = ground + _y.round() - 1;
    for (final o in _obstacles) {
      final (w, h, top) = o.box(ground);
      final ox = o.x.round();
      if (ox + 1 < dinoRight &&
          ox + w - 1 > dinoLeft &&
          top + 1 < dinoBottom &&
          top + h - 1 > dinoTop) {
        _phase = _Phase.over;
        _saveBest(os, 'dino', _score.floor());
        if (os.settings.sound) os.emit(const PlayTone(180, 180));
        os.eyes.confused();
        break;
      }
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    final score = _score.floor();
    g.strRight(BotFonts.tiny, 127, 6, score.toString().padLeft(5, '0'));
    final best = os.settings.best['dino'];
    if (best != null) {
      g.strRight(
        BotFonts.tiny,
        100,
        6,
        'HI ${best.toString().padLeft(5, '0')}',
      );
    }

    for (final c in _clouds) {
      g.bitmap(c.round(), 16, _cloud);
    }

    // Ground with scrolling grit.
    g.hLine(0, ground, 128);
    for (var i = 0; i < 12; i++) {
      final x = ((i * 23 + 7) - _groundScroll).round() % 128;
      g.pixel(x, ground + 2 + (i % 3));
      if (i.isEven) g.pixel(x + 3, ground + 4);
    }

    for (final o in _obstacles) {
      final (_, h, top) = o.box(ground);
      final sprite = switch (o.kind) {
        _Kind.small => _cactusSmall,
        _Kind.big => _cactusBig,
        _Kind.bird => (os.frame ~/ 6).isEven ? _birdA : _birdB,
      };
      g.bitmap(o.x.round(), top + h - sprite.length, sprite);
    }

    final sprite = _phase == _Phase.over
        ? _dinoDead
        : !_onGround || _phase == _Phase.ready
        ? _dinoA
        : (os.frame ~/ 3).isEven
        ? _dinoA
        : _dinoB;
    g.bitmap(dinoX, ground - 15 + _y.round(), sprite);

    if (_phase == _Phase.ready) {
      g.strCenter(BotFonts.primary, 72, 30, 'Dino Run');
      g.strCenter(BotFonts.secondary, 72, 41, 'Tap to jump');
    } else if (_phase == _Phase.over) {
      g.color = 0;
      g.box(30, 18, 70, 24);
      g.color = 1;
      g.rFrame(30, 18, 70, 24, 3);
      g.strCenter(BotFonts.primary, 65, 29, 'Game over');
      g.strCenter(BotFonts.secondary, 65, 38, 'Tap to retry');
    }

    // Night falls every 500 points, the way the original does.
    if (score % 700 > 500) {
      g.color = 2;
      g.box(0, 0, 128, 64);
      g.color = 1;
    }
  }
}

enum _Kind { small, big, bird }

class _Obstacle {
  _Obstacle({required this.x, required this.kind, required this.high});

  double x;
  final _Kind kind;
  final bool high;

  /// Width, height and top edge of the obstacle's box.
  (int, int, int) box(int ground) => switch (kind) {
    _Kind.small => (6, 12, ground - 12),
    _Kind.big => (10, 16, ground - 16),
    _Kind.bird => (12, 7, high ? ground - 30 : ground - 17),
  };
}

// --- Breakout -----------------------------------------------------------------

class BreakoutGame extends BotScreen {
  BreakoutGame(super.os) {
    _build();
  }

  static const int _cols = 8;
  static const int _rows = 4;
  static const int _brickW = 14;
  static const int _brickH = 4;
  static const int _paddleW = 22;
  static const int _paddleY = 60;

  _Phase _phase = _Phase.ready;
  final List<bool> _bricks = List<bool>.filled(_cols * _rows, true);
  double _paddle = 53;
  double _bx = 64;
  double _by = 56;
  double _vx = 1.2;
  double _vy = -1.8;
  bool _stuck = true;
  int _lives = 3;
  int _score = 0;
  int _level = 1;

  void _build() => _bricks.fillRange(0, _bricks.length, true);

  void _move(double dx) =>
      _paddle = (_paddle + dx).clamp(0, 128 - _paddleW).toDouble();

  @override
  bool key(BotKey k) {
    switch (k) {
      case BotKey.left:
        _move(-9);
        return true;
      case BotKey.right:
        _move(9);
        return true;
      case BotKey.touchLeft:
        _move(-14);
        return true;
      case BotKey.touchRight:
        _move(14);
        return true;
      case BotKey.press:
      case BotKey.touchFront:
        if (_phase == _Phase.over) {
          _build();
          _lives = 3;
          _score = 0;
          _level = 1;
          _stuck = true;
          _phase = _Phase.ready;
          return true;
        }
        _phase = _Phase.playing;
        if (_stuck) {
          _stuck = false;
          final speed = 1.8 + _level * 0.25;
          _vx = (os.random.nextBool() ? 1 : -1) * speed * 0.6;
          _vy = -speed;
        }
        return true;
      default:
        return false;
    }
  }

  @override
  void update(BotWorld w) {
    if (_stuck) {
      _bx = _paddle + _paddleW / 2 - 1;
      _by = _paddleY - 3;
      return;
    }
    if (_phase != _Phase.playing) return;

    _bx += _vx;
    _by += _vy;
    if (_bx <= 0 || _bx >= 126) {
      _vx = -_vx;
      _bx = _bx.clamp(0, 126).toDouble();
    }
    if (_by <= 11) {
      _vy = _vy.abs();
    }

    // Paddle: where it lands on the paddle sets the angle.
    if (_vy > 0 &&
        _by + 2 >= _paddleY &&
        _by + 2 <= _paddleY + 3 &&
        _bx + 2 >= _paddle &&
        _bx <= _paddle + _paddleW) {
      final hit = ((_bx + 1 - _paddle) / _paddleW).clamp(0.0, 1.0);
      final speed = math.sqrt(_vx * _vx + _vy * _vy);
      final angle = (hit - 0.5) * 2.2;
      _vx = speed * math.sin(angle);
      _vy = -speed * math.cos(angle);
      if (os.settings.sound) os.emit(const PlayTone(660, 15));
    }

    // Bricks.
    for (var i = 0; i < _bricks.length; i++) {
      if (!_bricks[i]) continue;
      final bx = 2 + (i % _cols) * (_brickW + 2);
      final by = 12 + (i ~/ _cols) * (_brickH + 2);
      if (_bx + 2 > bx &&
          _bx < bx + _brickW &&
          _by + 2 > by &&
          _by < by + _brickH) {
        _bricks[i] = false;
        _score += 10 * (_rows - i ~/ _cols);
        final fromSide = _bx + 1 < bx || _bx + 1 > bx + _brickW;
        if (fromSide) {
          _vx = -_vx;
        } else {
          _vy = -_vy;
        }
        if (os.settings.sound) os.emit(const PlayTone(1320, 12));
        break;
      }
    }

    if (_bricks.every((b) => !b)) {
      _level++;
      _build();
      _stuck = true;
      os.eyes.laugh();
    }

    if (_by > 64) {
      _lives--;
      _stuck = true;
      if (os.settings.sound) os.emit(const PlayTone(200, 150));
      if (_lives <= 0) {
        _phase = _Phase.over;
        _saveBest(os, 'breakout', _score);
      }
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    g.str(BotFonts.tiny, 1, 6, '$_score');
    g.strCenter(BotFonts.tiny, 64, 6, 'LV $_level');
    for (var i = 0; i < _lives; i++) {
      g.bitmap(122 - i * 5, 2, BotIcons.heartSmall);
    }
    g.dottedH(0, 9, 128);

    for (var i = 0; i < _bricks.length; i++) {
      if (!_bricks[i]) continue;
      final x = 2 + (i % _cols) * (_brickW + 2);
      final y = 12 + (i ~/ _cols) * (_brickH + 2);
      if (i ~/ _cols == 0) {
        g.box(x, y, _brickW, _brickH);
      } else {
        g.rBox(x, y, _brickW, _brickH, 1);
        if ((i ~/ _cols).isOdd) {
          g.color = 0;
          g.hLine(x + 2, y + 1, _brickW - 4);
          g.color = 1;
        }
      }
    }

    g.rBox(_paddle.round(), _paddleY, _paddleW, 3, 1);
    g.box(_bx.round(), _by.round(), 2, 2);

    if (_phase == _Phase.ready && _stuck) {
      g.strCenter(BotFonts.secondary, 64, 47, 'Turn the knob to move');
      g.strCenter(BotFonts.secondary, 64, 55, 'Press to launch');
    } else if (_phase == _Phase.over) {
      g.color = 0;
      g.box(24, 24, 80, 24);
      g.color = 1;
      g.rFrame(24, 24, 80, 24, 3);
      g.strCenter(BotFonts.primary, 64, 35, 'Game over');
      g.strCenter(BotFonts.secondary, 64, 44, 'Score $_score');
    }
  }
}

// --- Reaction -----------------------------------------------------------------

class ReactionGame extends BotScreen {
  ReactionGame(super.os);

  _RPhase _phase = _RPhase.intro;
  int _flashAt = 0;
  DateTime? _goAt;
  int? _result;

  @override
  bool key(BotKey k) {
    final tap =
        k == BotKey.touchFront ||
        k == BotKey.touchLeft ||
        k == BotKey.touchRight ||
        k == BotKey.press;
    if (!tap) return false;
    switch (_phase) {
      case _RPhase.intro:
      case _RPhase.result:
      case _RPhase.early:
        _phase = _RPhase.waiting;
        _flashAt = os.frame + 38 + os.random.nextInt(62);
        _goAt = null;
      case _RPhase.waiting:
        _phase = _RPhase.early;
        if (os.settings.sound) os.emit(const PlayTone(220, 120));
      case _RPhase.go:
        final at = os.lastKeyAt ?? os.world.now;
        final ms = at.difference(_goAt ?? at).inMilliseconds;
        _result = ms;
        _phase = _RPhase.result;
        _saveBest(os, 'reaction', ms, lowerIsBetter: true);
        if (ms < 250) os.eyes.laugh();
    }
    return true;
  }

  @override
  void update(BotWorld w) {
    if (_phase == _RPhase.waiting && os.frame >= _flashAt) {
      _phase = _RPhase.go;
      _goAt = w.now;
      if (os.settings.sound) os.emit(const PlayTone(2000, 90));
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    switch (_phase) {
      case _RPhase.intro:
        BotUi.statusBar(g, w, title: 'Reaction');
        g.strCenter(BotFonts.primary, 64, 26, 'How fast are you?');
        g.strCenter(BotFonts.secondary, 64, 38, 'Tap the front pad');
        g.strCenter(BotFonts.secondary, 64, 47, 'the moment it flashes');
        BotUi.hint(g, 'Tap to start', right: true);
      case _RPhase.waiting:
        g.strCenter(BotFonts.primary, 64, 30, 'Wait for it...');
        final dots = (os.frame ~/ 8) % 4;
        g.strCenter(BotFonts.primary, 64, 42, '.' * dots);
      case _RPhase.go:
        g.box(0, 0, 128, 64);
        g.color = 0;
        g.strCenter(BotFonts.primary, 64, 36, 'TAP!');
        g.color = 1;
      case _RPhase.early:
        BotUi.statusBar(g, w, title: 'Reaction');
        g.strCenter(BotFonts.primary, 64, 30, 'Too soon!');
        g.strCenter(BotFonts.secondary, 64, 42, 'Wait for the flash');
        BotUi.hint(g, 'Tap to retry', right: true);
      case _RPhase.result:
        BotUi.statusBar(g, w, title: 'Reaction');
        final ms = _result ?? 0;
        final tw = g.strCenter(BotFonts.big24, 56, 40, '$ms');
        g.str(BotFonts.primary, 58 + tw ~/ 2, 40, 'ms');
        final best = os.settings.best['reaction'];
        g.strCenter(
          BotFonts.secondary,
          64,
          51,
          ms < 200
              ? 'Lightning!'
              : ms < 300
              ? 'Quick'
              : 'Try again',
        );
        if (best != null) g.str(BotFonts.tiny, 1, 62, 'BEST ${best}MS');
        BotUi.hint(g, 'Again', right: true);
    }
  }
}

enum _RPhase { intro, waiting, go, early, result }
