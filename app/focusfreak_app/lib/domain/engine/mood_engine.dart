import '../model/session_state.dart';

/// Maps what is happening to what the bot's face does.
///
/// This is the product's entire feedback mechanism. There is no buzzer ladder,
/// no red alert, no shame copy — a device that punishes ends up in a drawer by
/// week three, which is the documented failure mode of accountability hardware
/// (`docs/ARCHITECTURE.md`). Disappointing a character works where
/// being scolded by a box does not.
class MoodEngine {
  MoodEngine({
    Duration happyHold = const Duration(seconds: 6),
    Duration sadHold = const Duration(seconds: 20),
    Duration sleepyAfter = const Duration(minutes: 10),
  }) : _happyHold = happyHold,
       _sadHold = sadHold,
       _sleepyAfter = sleepyAfter;

  final Duration _happyHold;

  /// Sadness lingers. It recovers on its own, and petting the bot clears it
  /// early — forgiveness is a designed feature, not an oversight.
  final Duration _sadHold;

  final Duration _sleepyAfter;

  Mood _mood = Mood.calm;

  /// When the current mood must stop overriding the session-derived one.
  DateTime? _holdUntil;

  DateTime? _lastActivity;

  Mood get mood => _mood;

  /// Recompute the mood for [now].
  Mood update({
    required DateTime now,
    required SessionState state,
    required bool verified,
    bool sleepBlock = false,
  }) {
    final hold = _holdUntil;
    if (hold != null && now.isBefore(hold)) return _mood;
    _holdUntil = null;

    if (state.isActive || state == SessionState.complete) {
      _lastActivity = now;
    }

    _mood = switch (state) {
      SessionState.running when verified => Mood.calm,
      SessionState.running => Mood.searching,
      SessionState.paused => Mood.searching,
      SessionState.broken => Mood.sad,
      SessionState.complete => Mood.happy,
      SessionState.armed => Mood.calm,
      SessionState.idle => _idleMood(now, sleepBlock),
    };

    return _mood;
  }

  Mood _idleMood(DateTime now, bool sleepBlock) {
    if (sleepBlock) return Mood.sleepy;
    final last = _lastActivity;
    if (last != null && now.difference(last) >= _sleepyAfter) {
      return Mood.sleepy;
    }
    return Mood.calm;
  }

  /// A block finished. Hold the happy face long enough to be felt.
  void celebrate(DateTime now) {
    _mood = Mood.happy;
    _holdUntil = now.add(_happyHold);
    _lastActivity = now;
  }

  /// A streak broke, or a session did.
  void disappoint(DateTime now) {
    _mood = Mood.sad;
    _holdUntil = now.add(_sadHold);
  }

  /// The head was petted.
  ///
  /// Clears a lingering sad mood immediately. The bot forgives you and gets
  /// back to work — that loop is the reason people keep the thing on the desk.
  void pet(DateTime now) {
    _mood = Mood.happy;
    _holdUntil = now.add(_happyHold);
    _lastActivity = now;
  }

  void reset() {
    _mood = Mood.calm;
    _holdUntil = null;
    _lastActivity = null;
  }
}
