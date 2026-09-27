import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../data/repo/session_repository.dart';
import '../../data/repo/settings_repository.dart';
import '../../domain/engine/mood_engine.dart';
import '../../domain/engine/session_engine.dart';
import '../../domain/engine/verification_source.dart';
import '../../domain/model/session_state.dart';
import '../../domain/model/template.dart';
import '../../domain/model/verification.dart';

/// A moment worth hearing.
///
/// Emitted rather than inferred from [SessionSnapshot]: in auto mode a
/// finished block is replaced by the next one before anything outside this
/// class sees a `complete`, so a listener watching states alone would miss
/// every transition in a routine. What is *not* here matters as much — there
/// is no cue for a violation. A sound when you leave your desk is the
/// punishment ladder rebuilt (`docs/ARCHITECTURE.md`).
enum SessionCue {
  /// A block just started, including each one a routine rolls into.
  blockStarted,

  /// A block finished and another is coming.
  blockEnded,

  /// The last block of the run finished. Nothing follows it.
  runCompleted,

  /// One of the last three seconds of a block.
  finalSecond,
}

/// Everything a screen needs to render the current session.
class SessionSnapshot {
  const SessionSnapshot({
    required this.state,
    required this.block,
    required this.remaining,
    required this.progress,
    required this.verified,
    required this.claimed,
    required this.violations,
    required this.mood,
    required this.verification,
    required this.queue,
    required this.queueIndex,
    this.autoMode = false,
    this.pausedByUser = false,
    this.lastReason,
  });

  final SessionState state;
  final ActiveBlock? block;
  final Duration remaining;
  final double progress;
  final Duration verified;
  final Duration claimed;
  final int violations;
  final Mood mood;
  final VerificationSnapshot verification;

  /// The remaining blocks of the routine being run, when in auto mode.
  final List<ActiveBlock> queue;
  final int queueIndex;

  final bool autoMode;

  /// Paused by the pause button, as opposed to verification dropping out.
  final bool pausedByUser;

  final ViolationReason? lastReason;

  static const SessionSnapshot idle = SessionSnapshot(
    state: SessionState.idle,
    block: null,
    remaining: Duration.zero,
    progress: 0,
    verified: Duration.zero,
    claimed: Duration.zero,
    violations: 0,
    mood: Mood.calm,
    verification: VerificationSnapshot.none,
    queue: <ActiveBlock>[],
    queueIndex: 0,
  );

  bool get isRunning => state == SessionState.running;
  bool get isActive => state.isActive;
  bool get isVerified => verification.isVerified;

  ActiveBlock? get nextBlock =>
      queueIndex + 1 < queue.length ? queue[queueIndex + 1] : null;
}

/// Drives a session from start to finish.
///
/// Owns the [SessionEngine] and the once-per-second tick, reads verification
/// from whatever [VerificationSource] is installed, and writes the result to
/// the database. The engine itself stays pure; everything impure lives here.
class SessionController extends StateNotifier<SessionSnapshot> {
  SessionController(this._sessions, this._source)
    : super(SessionSnapshot.idle) {
    _sourceSub = _source.changes.listen((_) => _tick());
  }

  final SessionRepository _sessions;
  final VerificationSource _source;

  final SessionEngine _engine = SessionEngine(autoPause: false);

  /// Whether stepping away pauses the countdown. Off by default: see
  /// [SessionEngine.autoPause].
  bool get autoPause => _engine.autoPause;
  set autoPause(bool value) {
    if (_engine.autoPause == value) return;
    _engine.autoPause = value;
    _tick();
  }

  final MoodEngine _mood = MoodEngine();

  Timer? _ticker;
  StreamSubscription<void>? _sourceSub;
  String? _sessionId;

  final StreamController<SessionCue> _cues =
      StreamController<SessionCue>.broadcast();

  /// The audible moments. Nothing is attached to this unless the user has
  /// sound on, and nothing in the session depends on anyone listening.
  Stream<SessionCue> get cues => _cues.stream;

  /// The last whole second announced, so one tick per second is emitted no
  /// matter how often the verification source pings the controller.
  int? _lastCountdownSecond;

  List<ActiveBlock> _queue = const <ActiveBlock>[];
  int _queueIndex = 0;
  bool _autoMode = false;
  ViolationReason? _lastReason;

  /// Persisting every second would be a write per second for ninety minutes.
  /// The engine holds the authoritative numbers in memory; the database only
  /// needs to be close enough to survive a crash.
  static const Duration _persistEvery = Duration(seconds: 15);
  DateTime? _lastPersist;

  // --- starting ---------------------------------------------------------------

  /// Run a single block.
  Future<void> startBlock(ActiveBlock block) async {
    await _startQueue(<ActiveBlock>[block], 0, auto: false);
  }

  /// Run a whole routine end to end, pausing and resuming as one unit.
  ///
  /// This is what turns a list of blocks into an operating system for the day:
  /// finishing one block arms the next automatically, and the user never has to
  /// remember what comes after what.
  ///
  /// [offset] is how much of block [from] has already gone — non-zero when the
  /// routine follows the clock and joins a block part-way (see
  /// `RoutineClock.plan`). Only that first block is shortened; the rest run
  /// their full length, which keeps them on the routine's times.
  /// Run a built-in template end to end, as the bot's Routines menu does.
  Future<void> startTemplate(RoutineTemplate t) async {
    if (t.blocks.isEmpty) return;
    final queue = <ActiveBlock>[
      for (var i = 0; i < t.blocks.length; i++)
        ActiveBlock(
          id: '${t.key}-$i',
          name: t.blocks[i].name,
          description: t.blocks[i].description,
          category: t.blocks[i].category,
          duration: Duration(minutes: t.blocks[i].durationMin),
          trackEnabled: t.blocks[i].track,
        ),
    ];
    await _startQueue(queue, 0, auto: true);
  }

  Future<void> startRoutine(
    List<Block> blocks, {
    String? routineId,
    int from = 0,
    Duration offset = Duration.zero,
  }) async {
    if (blocks.isEmpty) return;
    final first = from.clamp(0, blocks.length - 1);
    final queue = <ActiveBlock>[
      for (var i = 0; i < blocks.length; i++)
        ActiveBlock(
          id: blocks[i].id,
          name: blocks[i].name,
          description: blocks[i].description,
          category: blocks[i].category,
          duration: Duration(minutes: blocks[i].durationMin),
          trackEnabled: blocks[i].trackEnabled,
          routineId: routineId,
          startOffset: i == first ? offset : Duration.zero,
        ),
    ];
    await _startQueue(queue, first, auto: true);
  }

  Future<void> _startQueue(
    List<ActiveBlock> queue,
    int index, {
    required bool auto,
  }) async {
    await _closeCurrent(SessionState.broken, ViolationReason.cancelled);

    _queue = queue;
    _queueIndex = index;
    _autoMode = auto;
    _lastReason = null;

    final block = queue[index];
    final now = DateTime.now();

    _engine.start(block, now);
    _sessionId = await _sessions.begin(block: block, startedAt: now);
    _lastPersist = now;
    _cue(SessionCue.blockStarted);

    _startTicker();
    _tick();
  }

  // --- controls ---------------------------------------------------------------

  void pause() {
    _apply(_engine.pauseManually(DateTime.now()));
    _publish();
  }

  void resume() {
    _apply(_engine.resume(DateTime.now()));
    _publish();
  }

  Future<void> skip() async {
    _apply(_engine.skip(DateTime.now()));
    await _finishAndAdvance();
  }

  Future<void> stop() async {
    _apply(_engine.stop(DateTime.now()));
    await _closeCurrent(SessionState.broken, ViolationReason.cancelled);
    _reset();
  }

  /// The head was petted. Clears a lingering sad mood.
  void pet() {
    _mood.pet(DateTime.now());
    _publish();
  }

  // --- the loop ----------------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!_engine.state.isActive) return;

    final now = DateTime.now();
    final block = _engine.block;
    final snapshot = _source.read(trackEnabled: block?.trackEnabled ?? false);

    final wasArmed = _engine.state == SessionState.armed;
    final events = _engine.tick(now, snapshot);
    _apply(events);

    // The engine's arm timeout drops to idle, as the firmware does. Here that
    // would end the block, or a whole routine, fifteen seconds after Start
    // because the phone was not locked yet. The block keeps waiting instead,
    // on the same session row, until the conditions hold.
    if (wasArmed && _engine.state == SessionState.idle) {
      final block = _engine.block;
      if (block != null) _engine.start(block, now);
    }

    if (_engine.state.isFinished) {
      unawaited(_finishAndAdvance());
      return;
    }

    _announceFinalSeconds();

    final last = _lastPersist;
    if (last == null || now.difference(last) >= _persistEvery) {
      _lastPersist = now;
      unawaited(_persist(snapshot));
    }

    _publish(snapshot);
  }

  /// Ticks the last three seconds of a block, once each.
  ///
  /// Only while it is actually counting: a paused block sitting at 0:02 is
  /// waiting for you, and ticking at it would be nagging.
  void _announceFinalSeconds() {
    if (_engine.state != SessionState.running) {
      _lastCountdownSecond = null;
      return;
    }
    final left = _engine.remaining.inSeconds;
    if (left <= 0 || left > _finalSecondsCue) {
      _lastCountdownSecond = null;
      return;
    }
    if (left == _lastCountdownSecond) return;
    _lastCountdownSecond = left;
    _cue(SessionCue.finalSecond);
  }

  static const int _finalSecondsCue = 3;

  void _cue(SessionCue cue) {
    if (!_cues.isClosed) _cues.add(cue);
  }

  void _apply(List<SessionEvent> events) {
    final id = _sessionId;
    for (final e in events) {
      if (id != null) unawaited(_sessions.logEvent(id, e));

      switch (e) {
        case SessionViolation v:
          _lastReason = v.reason;
        case SessionTransition t:
          if (t.reason != null) _lastReason = t.reason;
          if (t.to == SessionState.complete) _mood.celebrate(t.at);
          if (t.to == SessionState.broken) _mood.disappoint(t.at);
        default:
          break;
      }
    }
  }

  Future<void> _persist(VerificationSnapshot snapshot) async {
    final id = _sessionId;
    if (id == null) return;
    await _sessions.progress(
      id,
      verified: _engine.verified,
      claimed: _engine.claimed,
      state: _engine.state,
      violations: _engine.violations,
      factorMask: snapshot.availabilityMask,
    );
  }

  /// Close the finished block and, in auto mode, arm the next one.
  Future<void> _finishAndAdvance() async {
    final finished = _engine.state;
    await _closeCurrent(finished, _lastReason);

    final hasNext = _autoMode && _queueIndex + 1 < _queue.length;

    // A block that ran out is worth hearing. One that broke is not: the app
    // says what happened on screen, without a noise that reads as a buzzer.
    if (finished == SessionState.complete) {
      _cue(hasNext ? SessionCue.blockEnded : SessionCue.runCompleted);
    }

    // A broken session stops the routine rather than rolling on. Auto-advancing
    // past a break would quietly hide the thing the user most needs to see.
    if (!hasNext || finished == SessionState.broken) {
      _reset(keepQueue: true);
      return;
    }

    _queueIndex++;
    final next = _queue[_queueIndex];
    final now = DateTime.now();

    _engine.start(next, now);
    _sessionId = await _sessions.begin(block: next, startedAt: now);
    _lastPersist = now;
    _cue(SessionCue.blockStarted);
    _publish();
  }

  Future<void> _closeCurrent(
    SessionState finalState,
    ViolationReason? reason,
  ) async {
    final id = _sessionId;
    if (id == null) return;
    _sessionId = null;

    final block = _engine.block;
    final snapshot = _source.read(trackEnabled: block?.trackEnabled ?? false);

    await _sessions.finish(
      id,
      endedAt: DateTime.now(),
      verified: _engine.verified,
      claimed: _engine.claimed,
      state: finalState,
      violations: _engine.violations,
      factorMask: snapshot.availabilityMask,
      trackEnabled: block?.trackEnabled ?? false,
    );
  }

  void _reset({bool keepQueue = false}) {
    _ticker?.cancel();
    _ticker = null;
    _engine.reset();
    if (!keepQueue) {
      _queue = const <ActiveBlock>[];
      _queueIndex = 0;
      _autoMode = false;
    }
    _publish();
  }

  void _publish([VerificationSnapshot? snapshot]) {
    if (!mounted) return;
    final block = _engine.block;
    final verification =
        snapshot ?? _source.read(trackEnabled: block?.trackEnabled ?? false);

    state = SessionSnapshot(
      state: _engine.state,
      block: block,
      remaining: _engine.remaining,
      progress: _engine.progress,
      verified: _engine.verified,
      claimed: _engine.claimed,
      violations: _engine.violations,
      mood: _mood.update(
        now: DateTime.now(),
        state: _engine.state,
        verified: verification.isVerified,
        sleepBlock: block?.category == 5,
      ),
      verification: verification,
      queue: _queue,
      queueIndex: _queueIndex,
      autoMode: _autoMode,
      pausedByUser: _engine.isPausedByUser,
      lastReason: _lastReason,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_sourceSub?.cancel());
    unawaited(_cues.close());
    super.dispose();
  }
}

/// The installed verification source: the phone, plus the bot when one is
/// connected.
///
/// Built **once**. Both members are long-lived, and the bot's member reports
/// no factors until a link is attached to it, so connecting or losing a bot
/// mid-session changes the evidence without disturbing the session.
final verificationSourceProvider = Provider<VerificationSource>((ref) {
  return CompositeVerificationSource(<VerificationSource>[
    ref.watch(phoneVerificationSourceProvider),
    ref.watch(deviceVerificationSourceProvider),
  ]);
});

/// Whether stepping away pauses the countdown.
final pauseWhenAwayProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(settingsRepositoryProvider).watchBool(SettingKey.pauseWhenAway),
);

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionSnapshot>((ref) {
      final controller = SessionController(
        ref.watch(sessionRepositoryProvider),
        ref.watch(verificationSourceProvider),
      );
      // Listened to, not watched: a settings change must not rebuild the
      // controller and throw away the block that is running.
      ref.listen<AsyncValue<bool>>(pauseWhenAwayProvider, (_, next) {
        if (next.hasValue) controller.autoPause = next.requireValue;
      }, fireImmediately: true);
      return controller;
    });
