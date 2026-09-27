/// The parts of the face that no data source supplies.
///
/// Blinking, idle gaze drift and the 8-frame mood blend are things the device
/// does for itself: `0xB0 STATUS` carries a mood byte and nothing else about
/// the face, and the session engine carries less than that. Both producers of
/// `BotState` need them, so they live here once — the virtual bot and the
/// mirror of a real one come alive the same way, and a value tuned for one is
/// tuned for both.
library;

import 'dart:math' as math;

import '../../domain/model/bot_state.dart';
import '../../domain/model/session_state.dart';

class FaceAnimator {
  FaceAnimator({DateTime Function()? clock, math.Random? random})
    : _clock = clock ?? DateTime.now,
      _rng = random ?? math.Random() {
    _nextGazeAt = _clock();
    _scheduleBlink();
  }

  final DateTime Function() _clock;
  final math.Random _rng;

  /// A mood transition runs over this many frames, the same count the firmware
  /// uses.
  static const int _moodFrames = 8;

  Mood _moodFrom = Mood.calm;
  Mood _moodTo = Mood.calm;
  int _moodFrame = _moodFrames;

  late DateTime _nextBlinkAt;
  double _blink = 0;
  bool _blinkClosing = false;

  double _gazeX = 0;
  double _gazeY = 0;
  double _targetGazeX = 0;
  double _targetGazeY = 0;
  late DateTime _nextGazeAt;

  /// Where the face is heading. The shape it is drawn with right now comes
  /// from [eyes], which may still be partway there.
  Mood get mood => _moodTo;

  double get blink => _blink;
  double get gazeX => _gazeX;
  double get gazeY => _gazeY;

  /// The blended eye shape partway through a mood change.
  EyeParams get eyes {
    if (_moodFrame >= _moodFrames) return EyeParams.forMood(_moodTo);
    return EyeParams.lerp(
      EyeParams.forMood(_moodFrom),
      EyeParams.forMood(_moodTo),
      _moodFrame / _moodFrames,
    );
  }

  void setMood(Mood mood) {
    if (mood == _moodTo) return;
    _moodFrom = _moodTo;
    _moodTo = mood;
    _moodFrame = 0;
  }

  /// Point the eyes somewhere, until the next idle drift takes over. Used when
  /// someone approaches.
  void lookAt({double x = 0, double y = 0}) {
    _targetGazeX = x;
    _targetGazeY = y;
  }

  /// Advances one frame.
  void advance(DateTime now) {
    _advanceBlink(now);
    _advanceGaze(now);
    if (_moodFrame < _moodFrames) _moodFrame++;
  }

  // --- blink ------------------------------------------------------------------

  void _scheduleBlink() {
    // 3-6 s, random. A regular blink reads as a machine; an irregular one reads
    // as alive.
    _nextBlinkAt = _clock().add(
      Duration(milliseconds: 3000 + _rng.nextInt(3000)),
    );
  }

  void _advanceBlink(DateTime now) {
    if (_blinkClosing) {
      // A blink is five frames down and five back up — the firmware squashes
      // the height rather than sliding a lid, and so does this.
      _blink += 0.2;
      if (_blink >= 1) {
        _blink = 1;
        _blinkClosing = false;
      }
      return;
    }

    if (_blink > 0) {
      _blink = math.max(0, _blink - 0.2);
      if (_blink == 0) _scheduleBlink();
      return;
    }

    if (now.isAfter(_nextBlinkAt)) _blinkClosing = true;
  }

  // --- gaze -------------------------------------------------------------------

  void _advanceGaze(DateTime now) {
    if (now.isAfter(_nextGazeAt)) {
      // Sad and sleepy moods look down and stay there rather than wandering.
      final settled = _moodTo == Mood.sad || _moodTo == Mood.sleepy;
      _targetGazeX = settled ? 0 : (_rng.nextDouble() * 2 - 1) * 0.6;
      _targetGazeY = settled ? 0.5 : (_rng.nextDouble() * 2 - 1) * 0.35;
      _nextGazeAt = now.add(Duration(milliseconds: 1800 + _rng.nextInt(2600)));
    }

    // Ease towards the target so the eyes glide rather than snap.
    _gazeX += (_targetGazeX - _gazeX) * 0.08;
    _gazeY += (_targetGazeY - _gazeY) * 0.08;
  }
}
