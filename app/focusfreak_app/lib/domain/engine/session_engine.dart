import '../../core/ff_constants.dart';
import '../model/session_state.dart';
import '../model/verification.dart';

/// What the engine is currently running.
class ActiveBlock {
  const ActiveBlock({
    required this.id,
    required this.name,
    required this.category,
    required this.duration,
    required this.trackEnabled,
    this.description = '',
    this.routineId,
    this.taskId,
    this.startOffset = Duration.zero,
  });

  final String id;
  final String name;
  final String description;

  /// 0..5. The index is the wire value and the colour index.
  final int category;

  final Duration duration;
  final bool trackEnabled;
  final String? routineId;
  final String? taskId;

  /// How much of the block had already gone when it was started. Non-zero
  /// only when a routine follows the clock and joins a block part-way: the
  /// countdown and ring pick up where the clock is, while verified and
  /// claimed still count only the time that was actually run.
  final Duration startOffset;

  /// What is left to run from the moment the block starts.
  Duration get planned {
    final left = duration - startOffset;
    return left.isNegative ? Duration.zero : left;
  }
}

/// Something the engine did that the rest of the app may want to react to —
/// persist, notify, animate, or push to the device.
sealed class SessionEvent {
  const SessionEvent(this.at);
  final DateTime at;
}

class SessionStarted extends SessionEvent {
  const SessionStarted(super.at, this.block);
  final ActiveBlock block;
}

class SessionTransition extends SessionEvent {
  const SessionTransition(super.at, this.from, this.to, {this.reason});
  final SessionState from;
  final SessionState to;
  final ViolationReason? reason;
}

class SessionViolation extends SessionEvent {
  const SessionViolation(super.at, this.reason, this.factors);
  final ViolationReason reason;
  final Set<VerificationFactor> factors;
}

class SessionCompleted extends SessionEvent {
  const SessionCompleted(super.at, this.verified, this.claimed);
  final Duration verified;
  final Duration claimed;
}

/// The session state machine.
///
/// Pure Dart, no Flutter, no I/O, no ambient clock — every method takes the
/// time explicitly. That is what makes the grace-period boundaries testable to
/// the second, and it is why this logic lives here rather than in a widget.
///
/// Mirrors the firmware machine in the firmware (`firmware/focusfreak/session.cpp`). If the two ever
/// disagree, the virtual bot and the physical bot behave differently and the
/// demo contradicts itself.
class SessionEngine {
  SessionEngine({
    Duration graceRunning = FfFirmware.graceRunning,
    Duration gracePaused = FfFirmware.gracePaused,
    Duration armTimeout = FfFirmware.armTimeout,
    this.autoPause = true,
  }) : _graceRunning = graceRunning,
       _gracePaused = gracePaused,
       _armTimeout = armTimeout;

  final Duration _graceRunning;
  final Duration _gracePaused;
  final Duration _armTimeout;

  /// Whether losing verification pauses the countdown.
  ///
  /// The firmware's machine does, and so does this one by default. The app
  /// turns it off unless the user asks for it: on a phone the screen is on
  /// every time you look at the timer, so a countdown that froze on it stopped
  /// the moment anyone checked how long was left. With it off the block keeps
  /// counting and only the verified minutes stop, which is the honest part.
  bool autoPause;

  SessionState _state = SessionState.idle;
  ActiveBlock? _block;

  DateTime? _armedAt;
  DateTime? _startedAt;
  DateTime? _lastTick;

  /// When the current run of unverified time began. Null while verified.
  DateTime? _unverifiedSince;

  /// True when the *user* pressed pause, rather than verification dropping.
  ///
  /// Without this the two are indistinguishable, and the next tick — one
  /// second later — sees a paused session with verification holding and
  /// helpfully resumes it. The pause button then appears to do nothing.
  /// A pause the user asked for is only ended by the user.
  bool _pausedByUser = false;

  Duration _verified = Duration.zero;
  Duration _claimed = Duration.zero;

  int _violations = 0;
  final Set<VerificationFactor> _lastViolatingFactors = <VerificationFactor>{};

  SessionState get state => _state;
  ActiveBlock? get block => _block;
  Duration get verified => _verified;
  Duration get claimed => _claimed;
  int get violations => _violations;
  DateTime? get startedAt => _startedAt;

  /// Time left in the block. Counts down against [claimed], so it freezes
  /// while paused — the countdown a user watches must agree with the timer
  /// that is actually running.
  Duration get remaining {
    final b = _block;
    if (b == null) return Duration.zero;
    final left = b.planned - _claimed;
    return left.isNegative ? Duration.zero : left;
  }

  double get progress {
    final b = _block;
    if (b == null || b.duration.inSeconds == 0) return 0;
    final done = b.startOffset + _claimed;
    return (done.inSeconds / b.duration.inSeconds).clamp(0.0, 1.0);
  }

  /// How long the current violation has been running, or null if none.
  Duration? unverifiedFor(DateTime now) {
    final since = _unverifiedSince;
    return since == null ? null : now.difference(since);
  }

  /// Arm a block. It does not start counting until verification is satisfied —
  /// this is the dock-the-phone ritual.
  List<SessionEvent> start(ActiveBlock block, DateTime now) {
    _block = block;
    _verified = Duration.zero;
    _claimed = Duration.zero;
    _violations = 0;
    _unverifiedSince = null;
    _pausedByUser = false;
    _lastViolatingFactors.clear();
    _armedAt = now;
    _startedAt = null;
    _lastTick = now;

    final from = _state;
    _state = SessionState.armed;
    return <SessionEvent>[
      SessionStarted(now, block),
      SessionTransition(now, from, SessionState.armed),
    ];
  }

  /// Advance the machine to [now] given the latest verification reading.
  ///
  /// Safe to call at any cadence. Time is taken from the difference between
  /// ticks rather than assumed, so a dropped frame or a backgrounded app does
  /// not silently lose or invent focus minutes.
  List<SessionEvent> tick(DateTime now, VerificationSnapshot snapshot) {
    final events = <SessionEvent>[];
    final last = _lastTick ?? now;
    var delta = now.difference(last);
    _lastTick = now;

    if (delta.isNegative) delta = Duration.zero;

    // A jump this large means the process was suspended, not that the user
    // focused for an hour. Credit the elapsed time to claimed only if the
    // machine was running, and never credit it as verified.
    final trustedDelta = delta > const Duration(minutes: 2)
        ? const Duration(minutes: 2)
        : delta;

    switch (_state) {
      case SessionState.armed:
        // No source at all (a browser, a phone with every permission denied)
        // means there is nothing to wait for. The block runs and its minutes
        // are claimed, never verified: `isVerified` stays false, so the
        // numbers stay honest while the timer stays usable.
        if (snapshot.isVerified || _noEvidence(snapshot)) {
          _startedAt = now;
          events.add(_transition(now, SessionState.running));
        } else if (now.difference(_armedAt ?? now) >= _armTimeout) {
          events.add(_transition(now, SessionState.idle));
        }

      case SessionState.running:
        _claimed += trustedDelta;

        if (snapshot.isVerified) {
          _verified += trustedDelta;
          _unverifiedSince = null;
          _lastViolatingFactors.clear();
        } else if (_noEvidence(snapshot)) {
          // Nothing is being violated; there is just nothing to check. That
          // is not a reason to pause anyone.
          _unverifiedSince = null;
        } else {
          _unverifiedSince ??= now;
          final violating = snapshot.violating.toSet();
          if (violating.isNotEmpty &&
              !_setEquals(violating, _lastViolatingFactors)) {
            _lastViolatingFactors
              ..clear()
              ..addAll(violating);
            _violations++;
            events.add(SessionViolation(now, _reasonFor(violating), violating));
          }
          if (autoPause && now.difference(_unverifiedSince!) >= _graceRunning) {
            events.add(
              _transition(
                now,
                SessionState.paused,
                reason: _reasonFor(violating),
              ),
            );
          }
        }

        // Completion is checked after the tick so the final second counts.
        final b = _block;
        if (b != null && _claimed >= b.planned) {
          _claimed = b.planned;
          events.add(_transition(now, SessionState.complete));
          events.add(SessionCompleted(now, _verified, _claimed));
        }

      case SessionState.paused:
        // Both timers are frozen here. That freeze is the feedback.
        //
        // A pause the user chose waits for the user. Only a pause caused by
        // verification dropping resumes on its own.
        if (_pausedByUser) break;
        if (snapshot.isVerified || !autoPause) {
          _unverifiedSince = null;
          _lastViolatingFactors.clear();
          events.add(_transition(now, SessionState.running));
        } else if (now.difference(_unverifiedSince ?? now) >= _gracePaused) {
          events.add(
            _transition(
              now,
              SessionState.broken,
              reason: _reasonFor(snapshot.violating.toSet()),
            ),
          );
          events.add(SessionCompleted(now, _verified, _claimed));
        }

      case SessionState.idle:
      case SessionState.complete:
      case SessionState.broken:
        break;
    }

    return events;
  }

  /// Manual pause. Distinct from a verification pause: there is no violation
  /// and no escalation to broken, because the user chose it.
  List<SessionEvent> pauseManually(DateTime now) {
    if (_state != SessionState.running) return const <SessionEvent>[];
    _unverifiedSince = null;
    _pausedByUser = true;
    return <SessionEvent>[_transition(now, SessionState.paused)];
  }

  List<SessionEvent> resume(DateTime now) {
    if (_state != SessionState.paused) return const <SessionEvent>[];
    _unverifiedSince = null;
    _pausedByUser = false;
    _lastTick = now;
    return <SessionEvent>[_transition(now, SessionState.running)];
  }

  /// True while the session is paused because the user asked for it.
  ///
  /// The UI needs the distinction: "Paused" is a choice, "Waiting for you" is
  /// the bot having lost sight of you, and telling a user the second when the
  /// first is true reads as an accusation.
  bool get isPausedByUser => _state == SessionState.paused && _pausedByUser;

  /// Stop early. Logged as abandoned rather than completed — the log tells the
  /// truth about what happened.
  List<SessionEvent> stop(DateTime now) {
    if (!_state.isActive) return const <SessionEvent>[];
    return <SessionEvent>[
      _transition(now, SessionState.broken, reason: ViolationReason.cancelled),
      SessionCompleted(now, _verified, _claimed),
    ];
  }

  /// Mark the block finished now, keeping whatever was earned.
  List<SessionEvent> skip(DateTime now) {
    if (!_state.isActive) return const <SessionEvent>[];
    return <SessionEvent>[
      _transition(now, SessionState.complete),
      SessionCompleted(now, _verified, _claimed),
    ];
  }

  void reset() {
    _state = SessionState.idle;
    _block = null;
    _armedAt = null;
    _startedAt = null;
    _lastTick = null;
    _unverifiedSince = null;
    _verified = Duration.zero;
    _claimed = Duration.zero;
    _violations = 0;
    _lastViolatingFactors.clear();
  }

  SessionTransition _transition(
    DateTime now,
    SessionState to, {
    ViolationReason? reason,
  }) {
    final from = _state;
    _state = to;
    return SessionTransition(now, from, to, reason: reason);
  }

  /// The most explanatory reason available. Presence loss is the most
  /// informative thing to tell a user, so it wins when several factors drop
  /// together.
  static ViolationReason _reasonFor(Set<VerificationFactor> factors) {
    if (factors.contains(VerificationFactor.presence)) {
      return ViolationReason.absent;
    }
    if (factors.contains(VerificationFactor.dock)) {
      return ViolationReason.undocked;
    }
    if (factors.contains(VerificationFactor.screenLock)) {
      return ViolationReason.screenOn;
    }
    if (factors.contains(VerificationFactor.appUsage)) {
      return ViolationReason.distractingApp;
    }
    return ViolationReason.heartbeatLost;
  }

  /// A tracked block with no available factor: nothing can verify it and
  /// nothing can catch it out either.
  static bool _noEvidence(VerificationSnapshot s) =>
      s.trackEnabled && s.available.isEmpty;

  static bool _setEquals(Set<Object?> a, Set<Object?> b) =>
      a.length == b.length && a.containsAll(b);
}
