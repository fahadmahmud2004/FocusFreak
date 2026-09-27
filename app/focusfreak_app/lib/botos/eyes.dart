/// The bot's face.
///
/// Modelled on FluxGarage's RoboEyes, the most loved OLED face for Arduino:
/// two rounded eyes that glide rather than jump, lids cut in for tired, sad and
/// happy, idle glances around the room, curiosity (the eye on the side it is
/// looking grows), blinking at irregular intervals, and a laugh.
///
/// Everything is drawn with [Gfx] calls that exist in U8g2, and every value is
/// an integer pixel or a frame count, so the C port is a transliteration.
library;

import 'dart:math' as math;

import 'gfx.dart';
import 'icons.dart';
import 'world.dart';

class Eyes {
  Eyes({math.Random? random}) : _rng = random ?? math.Random();

  final math.Random _rng;

  // Base geometry, in pixels.
  // Taller than wide with soft corners: the shape that reads as a friendly
  // character (Cozmo, EMO) rather than two lit squares.
  static const int baseW = 30;
  static const int baseH = 38;
  static const int radius = 11;
  static const int space = 16;

  // Animated values. Doubles so easing is smooth; drawn rounded.
  double _w = baseW.toDouble();
  double _h = baseH.toDouble();
  double _x = 0;
  double _y = 0;
  double _targetX = 0;
  double _targetY = 0;

  double _tired = 0;
  double _happy = 0;
  double _hop = 0;
  double _hopVelocity = 0;
  double _squish = 0;
  double _wide = 0;

  int _frame = 0;
  int _nextBlink = 60;
  int _blinkFrame = 99;
  int _nextGlance = 40;
  int _shake = 0;
  bool _shakeVertical = true;
  int _happyUntil = -1;
  int _surpriseUntil = -1;
  final List<int> _recentPets = <int>[];

  BotMood _mood = BotMood.calm;
  bool _idle = true;
  bool _lookHeld = false;
  int _lookHeldUntil = -1;

  final List<_Particle> _particles = <_Particle>[];

  BotMood get mood => _mood;

  void setMood(BotMood mood) => _mood = mood;

  /// Wander on its own when true; hold still when false.
  set idle(bool value) => _idle = value;

  /// Look towards a point, −1..1 on each axis, for [frames].
  void lookAt(double nx, double ny, {int frames = 60}) {
    _targetX = nx.clamp(-1.0, 1.0) * 16;
    _targetY = ny.clamp(-1.0, 1.0) * 9;
    _lookHeld = true;
    _lookHeldUntil = _frame + frames;
  }

  void blink() => _blinkFrame = 0;

  /// A touch on the head. Answers every single tap, straight away: a squish,
  /// a little hop and a heart. Three quick taps and it laughs.
  void pet() {
    _squish = 1;
    _hopVelocity = -2.6;
    _happyUntil = _frame + 70;
    _recentPets.add(_frame);
    _recentPets.removeWhere((f) => _frame - f > 30);
    _particles.add(
      _Particle(
        x: 60 + _rng.nextInt(9) - 4 + _x.round(),
        y: 14 + _y.round(),
        kind: _ParticleKind.heart,
      ),
    );
    if (_recentPets.length >= 3) {
      laugh();
      _recentPets.clear();
    }
  }

  /// A poke on the front pad: eyes go wide, then a blink.
  void poke() {
    _wide = 1;
    _surpriseUntil = _frame + 18;
    _blinkFrame = -8;
  }

  void laugh() {
    _shake = 20;
    _shakeVertical = true;
  }

  void confused() {
    _shake = 20;
    _shakeVertical = false;
  }

  /// One frame at 25 fps.
  void update() {
    _frame++;

    // Moods ease their lids in and out.
    final happy = _frame < _happyUntil || _mood == BotMood.happy;
    final tired = switch (_mood) {
      BotMood.sleepy => 0.62,
      BotMood.sad => 0.4,
      _ => 0.0,
    };
    _happy += ((happy ? 1.0 : 0.0) - _happy) * 0.3;
    _tired += (tired - _tired) * 0.2;

    // Squish and surprise spring back.
    _squish *= 0.78;
    if (_frame > _surpriseUntil) _wide *= 0.8;

    // A small hop with gravity.
    _hopVelocity += 0.55;
    _hop += _hopVelocity;
    if (_hop > 0) {
      _hop = 0;
      _hopVelocity = 0;
    }

    // Glances: somewhere new every one to three seconds.
    if (_lookHeld && _frame > _lookHeldUntil) _lookHeld = false;
    if (!_lookHeld && _frame >= _nextGlance) {
      _nextGlance = _frame + 25 + _rng.nextInt(50);
      if (_idle && (_mood == BotMood.calm || _mood == BotMood.searching)) {
        final far = _rng.nextInt(4) == 0;
        _targetX = (_rng.nextDouble() * 2 - 1) * (far ? 16 : 8);
        _targetY = (_rng.nextDouble() * 2 - 1) * 6;
      } else if (_mood == BotMood.sad || _mood == BotMood.sleepy) {
        _targetX = 0;
        _targetY = 6;
      } else {
        _targetX = 0;
        _targetY = 0;
      }
    }
    _x += (_targetX - _x) * 0.25;
    _y += (_targetY - _y) * 0.25;

    // Blinks at irregular intervals; an even rhythm reads as a machine.
    if (_blinkFrame < 0) {
      _blinkFrame++;
    } else if (_blinkFrame >= 0 && _blinkFrame < 8) {
      _blinkFrame++;
      if (_blinkFrame == 8) _blinkFrame = 99;
    } else if (_frame >= _nextBlink) {
      _blinkFrame = 0;
      _nextBlink = _frame + 60 + _rng.nextInt(90);
      // Now and then, a double blink.
      if (_rng.nextInt(6) == 0) _nextBlink = _frame + 11;
    }

    var targetH = baseH.toDouble();
    var targetW = baseW.toDouble();
    if (_blinkFrame >= 0 && _blinkFrame < 8) {
      // Four frames down, four back up.
      final t = _blinkFrame < 4 ? _blinkFrame / 4 : (8 - _blinkFrame) / 4;
      targetH = baseH * (1 - t) + 2 * t;
    }
    // A slow breath, a pixel or so, so the face is never perfectly still.
    targetH += math.sin(_frame / 18) * 0.9;
    targetH = targetH * (1 - 0.38 * _squish) + 6 * _wide;
    targetW = targetW + 5 * _squish + 3 * _wide;
    _h += (targetH - _h) * 0.6;
    _w += (targetW - _w) * 0.6;

    if (_shake > 0) _shake--;

    for (final p in _particles) {
      p.age++;
      if (p.age.isEven) p.y--;
    }
    _particles.removeWhere((p) => p.age > 26 || p.y < -4);
    if (_mood == BotMood.sleepy && _frame % 40 == 0) {
      _particles.add(_Particle(x: 104, y: 18, kind: _ParticleKind.z));
    }
  }

  /// Draws the full face, centred on the screen.
  void draw(Gfx g) {
    final w = _w.round();
    final h = math.max(2, _h.round());
    final shake = _shake > 0 ? (_shake.isEven ? 2 : -2) : 0;
    final ox = _x.round() + (_shakeVertical ? 0 : shake);
    final oy = _y.round() + _hop.round() + (_shakeVertical ? shake : 0);

    final total = w * 2 + space;
    final lx = (Gfx.width - total) ~/ 2 + ox;
    final rx = lx + w + space;

    // Curiosity: looking far to one side, the eye on that side grows.
    final curious = _mood == BotMood.searching || _x.abs() > 11;
    final lh = h + (curious && _x < -11 ? 6 : 0);
    final rh = h + (curious && _x > 11 ? 6 : 0);
    final ly = (Gfx.height - lh) ~/ 2 + oy;
    final ry = (Gfx.height - rh) ~/ 2 + oy;
    final r = math.min(radius, h ~/ 2);

    g.color = 1;
    g.rBox(lx, ly, w, lh, r);
    g.rBox(rx, ry, w, rh, r);

    g.color = 0;
    // Tired and sad: lids slope down towards the outer corners.
    final lid = (_tired * lh).round();
    if (lid > 0) {
      g.triangle(lx - 1, ly - 1, lx + w, ly - 1, lx - 1, ly + lid);
      g.box(lx - 1, ly - 1, w + 2, lid ~/ 2);
      g.triangle(rx - 1, ry - 1, rx + w, ry - 1, rx + w, ry + lid);
      g.box(rx - 1, ry - 1, w + 2, lid ~/ 2);
    }
    // Happy: an arc cut from below leaves a crescent, the "^ ^" that reads
    // as a smile.
    final smile = (_happy * lh * 0.9).round();
    if (smile > 0) {
      g.ellipse(lx + w ~/ 2, ly + lh + smile ~/ 4, w * 9 ~/ 10, smile);
      g.ellipse(rx + w ~/ 2, ry + rh + smile ~/ 4, w * 9 ~/ 10, smile);
    }

    // The shine: a small dark glint high on each eye that shifts with the
    // gaze. It is what makes the eyes look wet rather than printed.
    if (h > 14 && _happy < 0.5 && _tired < 0.3) {
      final gx = (_x / 6).round();
      final gy = (_y / 6).round();
      g.rBox(lx + w - 11 + gx, ly + 6 + gy, 5, 5, 2);
      g.rBox(rx + w - 11 + gx, ry + 6 + gy, 5, 5, 2);
    }
    g.color = 1;

    for (final p in _particles) {
      switch (p.kind) {
        case _ParticleKind.heart:
          g.bitmap(p.x, p.y, BotIcons.heartSmall);
        case _ParticleKind.z:
          g.str(BotFonts.tiny, p.x + p.age ~/ 6, p.y, p.age < 13 ? 'z' : 'Z');
      }
    }
  }

  /// A small pair of eyes for the corner of the dashboard, sharing the blink
  /// and the gaze so it is the same face, just smaller.
  void drawMini(Gfx g, int cx, int cy) {
    final blinkT = _blinkFrame >= 0 && _blinkFrame < 8
        ? (_blinkFrame < 4 ? _blinkFrame / 4 : (8 - _blinkFrame) / 4)
        : 0.0;
    final h = math.max(1, (10 * (1 - blinkT)).round());
    final dx = (_x / 5).round();
    final dy = (_y / 4).round();
    g.color = 1;
    g.rBox(cx - 10 + dx, cy - h ~/ 2 + dy, 8, h, 2);
    g.rBox(cx + 2 + dx, cy - h ~/ 2 + dy, 8, h, 2);
    if (_happy > 0.5) {
      g.color = 0;
      g.box(cx - 11 + dx, cy + 1 + dy, 22, 5);
      g.color = 1;
    }
  }
}

enum _ParticleKind { heart, z }

class _Particle {
  _Particle({required this.x, required this.y, required this.kind});

  final int x;
  int y;
  final _ParticleKind kind;
  int age = 0;
}
