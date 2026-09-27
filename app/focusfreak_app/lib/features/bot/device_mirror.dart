/// The second producer of [BotState]: a real bot, decoded.
///
/// `VirtualBotEngine` runs the device's behaviour locally; this runs nothing —
/// it reads `0xB0 STATUS` and reports what the bot on the desk already decided.
/// Both feed the same `BotCanvas`, so connecting hardware swaps the source of
/// truth and changes nothing about how it is drawn.
///
/// Like `DeviceVerificationSource`, it is built once and **re-pointed** by
/// [attach] on every connect rather than rebuilt, so nothing watching it is
/// torn down when a bot comes and goes.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ff_constants.dart';
import '../../device/device_link.dart';
import '../../device/protocol.dart';
import '../../device/transport/transport.dart';
import '../../domain/model/bot_state.dart';
import '../../domain/model/session_state.dart';
import '../../domain/model/verification.dart';
import '../device/device_controller.dart';
import 'face_animator.dart';
import 'virtual_bot_engine.dart';

class DeviceMirror extends StateNotifier<BotState?> {
  DeviceMirror({
    DateTime Function()? clock,
    Duration? staleAfter,
    math.Random? random,
  }) : _clock = clock ?? DateTime.now,
       staleAfter = staleAfter ?? FfFirmware.statusPollInterval * 3,
       _random = random,
       super(null);

  final DateTime Function() _clock;
  final math.Random? _random;

  /// How old a status may be and still describe *now*. Three poll intervals,
  /// the same window [DeviceVerificationSource] uses: one missed poll is a
  /// dropped frame, three in a row is a bot that stopped talking.
  final Duration staleAfter;

  DeviceLink? _link;
  StreamSubscription<DeviceStatus>? _statusSub;
  StreamSubscription<LinkState>? _stateSub;
  Timer? _ticker;
  late FaceAnimator _face;

  String _deviceName = FfApp.name;
  DeviceStatus? _status;
  DateTime? _statusAt;

  /// What the device says it is holding, so a block index can become a name.
  /// Empty until the pull lands, and re-pulled if an index arrives that it
  /// cannot explain.
  List<WireBlock> _routine = const <WireBlock>[];
  bool _pullingRoutine = false;
  DateTime? _pulledAt;

  DeviceLink? get link => _link;

  bool get isStale {
    final at = _statusAt;
    if (at == null) return true;
    return _clock().difference(at) > staleAfter;
  }

  // -- Attaching -----------------------------------------------------------------

  /// Points the mirror at a link — or at none, which puts the Bot tab back on
  /// the virtual engine.
  void attach(DeviceLink? link, {String? deviceName}) {
    unawaited(_statusSub?.cancel());
    unawaited(_stateSub?.cancel());
    _statusSub = null;
    _stateSub = null;
    _ticker?.cancel();
    _ticker = null;

    _link = link;
    _status = null;
    _statusAt = null;
    _routine = const <WireBlock>[];
    _deviceName = deviceName ?? FfApp.name;

    if (link == null) {
      if (mounted) state = null;
      return;
    }

    _face = FaceAnimator(clock: _clock, random: _random);
    _statusSub = link.statuses.listen(_onStatus);
    _stateSub = link.states.listen((linkState) {
      // A link that dropped is not a bot to mirror. Detaching here rather than
      // waiting for the controller means the face never freezes mid-countdown
      // pretending the block is still running.
      if (linkState != LinkState.connected) attach(null);
    });

    final seed = link.lastStatus;
    if (seed != null) _onStatus(seed);
    unawaited(_pullRoutine());

    // Ticks at the device's own 25 fps: STATUS arrives every 5 s, and a mirror
    // that only redraws on frames shows a countdown that jumps in five-second
    // steps.
    _ticker = Timer.periodic(
      const Duration(milliseconds: 1000 ~/ FfFirmware.faceFps),
      (_) => tick(),
    );
    tick();
  }

  void _onStatus(DeviceStatus status) {
    final previous = _status;
    _status = status;
    _statusAt = _clock();
    _face.setMood(_moodOf(status.mood));

    // An index the pulled routine cannot name means the device is running a
    // routine this app did not push — or pushed before the pull landed.
    //
    // A block starting is also a reason to re-read the names: the bot can
    // start its own focus timer or one of its routines from its menu, and
    // that replaces what it holds under the same indexes. So does time: a
    // switch from one to the other without an idle status in between shows
    // up at the next minute's pull.
    final now = _clock();
    final started =
        status.hasActiveBlock &&
        (previous == null ||
            !previous.hasActiveBlock ||
            previous.blockIdx != status.blockIdx);
    final due =
        status.hasActiveBlock &&
        (_pulledAt == null ||
            now.difference(_pulledAt!) > const Duration(minutes: 1));
    if (status.hasActiveBlock &&
        (_blockAt(status.blockIdx) == null || started || due)) {
      unawaited(_pullRoutine());
    }
    tick();
  }

  /// Re-read the block names after the app pushed a new routine, so the
  /// mirror does not name the new blocks after the old ones.
  Future<void> refreshRoutine() => _pullRoutine();

  Future<void> _pullRoutine() async {
    final link = _link;
    if (link == null || _pullingRoutine) return;
    _pullingRoutine = true;
    _pulledAt = _clock();
    try {
      final blocks = await link.fetchRoutine();
      if (identical(link, _link)) _routine = blocks;
    } on Object {
      // A routine we could not read costs block *names*, nothing else. The
      // countdown, the mood and the verification badges are all in STATUS.
    } finally {
      _pullingRoutine = false;
    }
  }

  WireBlock? _blockAt(int index) =>
      index >= 0 && index < _routine.length ? _routine[index] : null;

  // -- The loop --------------------------------------------------------------------

  /// Draws one frame. Called by the ticker; visible so tests can step it.
  void tick() {
    if (!mounted || _link == null) return;
    final now = _clock();
    _face.advance(now);
    state = _compose(now);
  }

  BotState _compose(DateTime now) {
    final status = _status;
    if (status == null) {
      // Connected, handshake done, first status not in yet.
      return BotState(
        mode: BotMode.ambient,
        mood: _face.mood,
        now: now,
        live: true,
        deviceName: _deviceName,
        gazeX: _face.gazeX,
        gazeY: _face.gazeY,
        blink: _face.blink,
        eyeShape: _face.eyes,
      );
    }

    final sessionState = _stateOf(status.state);
    final block = _blockAt(status.blockIdx);
    final remaining = _remaining(status, sessionState, now);
    final next = _blockAt(status.blockIdx + 1);

    return BotState(
      mode: _modeOf(status, sessionState),
      mood: _face.mood,
      now: now,
      blockName: block?.name ?? '',
      blockDescription: block?.description ?? '',
      category: block?.category ?? 0,
      remaining: remaining,
      progress: _progress(block, remaining),
      sessionState: sessionState,
      trackEnabled: status.trackEnabled,
      verification: _verification(status),
      nextBlockName: next?.name,
      nextBlockAt: next == null ? null : _startOf(next, now),
      // STATUS carries no temperature or humidity, so the comfort line stays
      // hidden rather than showing a plausible-looking guess.
      batteryPct: status.battPct,
      streak: status.streak,
      verifiedMinutesToday: status.verifiedToday,
      gazeX: _face.gazeX,
      gazeY: _face.gazeY,
      blink: _face.blink,
      live: true,
      deviceName: _deviceName,
      eyeShape: _face.eyes,
    );
  }

  /// The countdown between frames.
  ///
  /// STATUS arrives every 5 s. Counting down locally and correcting on each
  /// frame is what makes the mirror a clock rather than a slideshow — but a
  /// **stale** link freezes instead: a countdown that keeps running off a
  /// reading from four minutes ago is inventing progress nobody made.
  Duration _remaining(
    DeviceStatus status,
    SessionState sessionState,
    DateTime now,
  ) {
    final at = _statusAt;
    if (at == null || isStale || !sessionState.countsTime) {
      return status.remaining;
    }
    final left = status.remaining - now.difference(at);
    return left.isNegative ? Duration.zero : left;
  }

  double _progress(WireBlock? block, Duration remaining) {
    final total = (block?.durationMin ?? 0) * 60;
    if (total <= 0) return 0;
    return ((total - remaining.inSeconds) / total).clamp(0.0, 1.0);
  }

  /// Today's wall-clock start, for a block pinned to a time of day.
  DateTime? _startOf(WireBlock block, DateTime now) {
    if (block.isSequential) return null;
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: block.startMin));
  }

  /// Which screen the device is showing.
  ///
  /// Derived, because STATUS has no screen-mode byte: a running block is Task,
  /// and somebody at the desk is Attention. Pet, Pair and Dim are local events
  /// the app cannot see, and the presence bit opens at 90 cm where the device's
  /// own Attention wakes at 70, so the mirror can show the big face a step
  /// early. Closing that gap means a mode byte in `docs/PROTOCOL.md` §6.
  BotMode _modeOf(DeviceStatus status, SessionState sessionState) {
    if (sessionState.isActive) return BotMode.task;
    if (status.present) return BotMode.attention;
    return BotMode.ambient;
  }

  /// What the device's own sensors are reporting, in the app's terms.
  ///
  /// The capability rules are `DeviceVerificationSource`'s, for the same
  /// reason: a sensor the bot never declared is [FactorState.unavailable], not
  /// a violation. Screen-lock is only shown while a tracked block runs, which
  /// is the only time the phone's heartbeat is feeding that bit.
  VerificationSnapshot _verification(DeviceStatus status) {
    final caps = _link?.capabilities ?? const DeviceCapabilities.none();
    final provided = <VerificationFactor>{
      if (caps.has(DeviceCapability.presence)) VerificationFactor.presence,
      if (caps.has(DeviceCapability.dock)) VerificationFactor.dock,
      if (status.trackEnabled) VerificationFactor.screenLock,
    };

    if (isStale) {
      return VerificationSnapshot(
        trackEnabled: status.trackEnabled,
        factors: <VerificationFactor, FactorState>{
          for (final f in provided) f: FactorState.unavailable,
        },
      );
    }

    FactorState held(bool holding) =>
        holding ? FactorState.holding : FactorState.violated;

    return VerificationSnapshot(
      trackEnabled: status.trackEnabled,
      factors: <VerificationFactor, FactorState>{
        if (provided.contains(VerificationFactor.presence))
          VerificationFactor.presence: held(status.present),
        if (provided.contains(VerificationFactor.dock))
          VerificationFactor.dock: held(status.docked),
        if (provided.contains(VerificationFactor.screenLock))
          VerificationFactor.screenLock: held(status.phoneLocked),
      },
    );
  }

  // The two enums are deliberately the same shape as the firmware's, but they
  // are mapped by name rather than by index: a reordering on either side
  // should be a compile error, not a silently wrong face.
  static SessionState _stateOf(DeviceRunState state) => switch (state) {
    DeviceRunState.idle => SessionState.idle,
    DeviceRunState.armed => SessionState.armed,
    DeviceRunState.running => SessionState.running,
    DeviceRunState.paused => SessionState.paused,
    DeviceRunState.complete => SessionState.complete,
    DeviceRunState.broken => SessionState.broken,
  };

  static Mood _moodOf(DeviceMood mood) => switch (mood) {
    DeviceMood.calm => Mood.calm,
    DeviceMood.searching => Mood.searching,
    DeviceMood.sad => Mood.sad,
    DeviceMood.happy => Mood.happy,
    DeviceMood.sleepy => Mood.sleepy,
  };

  @override
  void dispose() {
    unawaited(_statusSub?.cancel());
    unawaited(_stateSub?.cancel());
    _ticker?.cancel();
    super.dispose();
  }
}

// -- Providers -----------------------------------------------------------------

/// Null whenever no bot is connected. `DeviceController` attaches and detaches
/// it alongside the verification source, in the same two places.
final deviceMirrorProvider = StateNotifierProvider<DeviceMirror, BotState?>(
  (ref) => DeviceMirror(),
);

/// The face, from whichever producer is authoritative right now.
///
/// This is the swap §5.3 promises: every consumer watches one provider, and
/// connecting a bot changes which producer answers and nothing else.
final botStateProvider = Provider<BotState>(
  (ref) => ref.watch(realBotConnectedProvider)
      ? ref.watch(deviceMirrorProvider) ?? ref.watch(virtualBotProvider)
      : ref.watch(virtualBotProvider),
);
