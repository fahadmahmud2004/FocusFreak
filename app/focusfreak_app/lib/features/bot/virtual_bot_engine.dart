import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ff_constants.dart';
import '../../domain/model/bot_state.dart';
import '../../domain/model/session_state.dart';
import '../timer/session_controller.dart';
import 'face_animator.dart';

/// Runs the device's screen behaviour locally.
///
/// One of the two producers of [BotState]; the other decodes `0xB0 STATUS`
/// frames from real hardware. Both feed the same `BotCanvas`, so connecting a
/// bot swaps the source of truth and changes nothing about how it is drawn.
///
/// Animates at the device's own 25 fps rather than the phone's 60. Matching the
/// hardware's frame budget means what looks smooth here looks smooth there, and
/// it keeps the phone from doing four times the work for no visible gain.
class VirtualBotEngine extends StateNotifier<BotState> {
  VirtualBotEngine({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(BotState.initial((clock ?? DateTime.now)())) {
    _ticker = Timer.periodic(
      const Duration(milliseconds: 1000 ~/ FfFirmware.faceFps),
      (_) => _tick(),
    );
  }

  final DateTime Function() _clock;

  /// Blink, gaze and the mood blend — shared with the mirror of a real bot, so
  /// both faces are alive in the same way.
  late final FaceAnimator _face = FaceAnimator(clock: _clock);

  Timer? _ticker;

  /// Mode overrides with an expiry — Attention and Pet both time out back to
  /// whatever the session says the mode should be.
  BotMode? _override;
  DateTime? _overrideUntil;

  DateTime _lastInteraction = DateTime.now();

  // What the session last told us.
  SessionSnapshot? _session;
  String? _nextBlockName;
  DateTime? _nextBlockAt;

  /// Feed the current session in. Called whenever the session controller emits.
  void applySession(SessionSnapshot session) {
    _session = session;
    if (session.isActive) _lastInteraction = _clock();
    _face.setMood(session.mood);
    _tick();
  }

  void setUpcoming({String? name, DateTime? at}) {
    _nextBlockName = name;
    _nextBlockAt = at;
  }

  // --- interactions -------------------------------------------------------------

  /// Someone came close — the proximity sensor, or a tap on the canvas.
  void approach() {
    _lastInteraction = _clock();
    _override = BotMode.attention;
    _overrideUntil = _clock().add(FfFirmware.attentionHold);
    // Look straight at whoever just arrived.
    _face.lookAt(y: -0.25);
    _tick();
  }

  /// Follow something with the eyes — a finger dragged across the phone-as-bot
  /// screen, in −1..1 on each axis.
  ///
  /// Deliberately does not change the mode: a bot that abandoned its countdown
  /// because you brushed the screen would be a worse bot. It looks, and keeps
  /// doing what it was doing.
  void lookAt(double x, double y) {
    _lastInteraction = _clock();
    _face.lookAt(x: x.clamp(-1, 1), y: y.clamp(-1, 1));
    _tick();
  }

  /// The head was petted.
  void pet() {
    _lastInteraction = _clock();
    _override = BotMode.pet;
    _overrideUntil = _clock().add(FfFirmware.petDisplay);
    _face.setMood(Mood.happy);
    _tick();
  }

  void showPairing() {
    _lastInteraction = _clock();
    _override = BotMode.pair;
    _overrideUntil = _clock().add(const Duration(seconds: 30));
    _tick();
  }

  /// Force a mode, for the mode switcher on the bot screen.
  void preview(BotMode mode, {Duration hold = const Duration(seconds: 20)}) {
    _lastInteraction = _clock();
    _override = mode;
    _overrideUntil = _clock().add(hold);

    // Two modes are inseparable from a mood on the real device: Pet is always
    // the happy squint, and Dim is always the sleepy droop. Previewing them
    // with whatever mood happened to be current would misrepresent the
    // hardware.
    switch (mode) {
      case BotMode.pet:
        _face.setMood(Mood.happy);
      case BotMode.dim:
        _face.setMood(Mood.sleepy);
      default:
        break;
    }

    _tick();
  }

  void clearOverride() {
    _override = null;
    _overrideUntil = null;
    _tick();
  }

  // --- the loop -------------------------------------------------------------------

  void _tick() {
    if (!mounted) return;
    final now = _clock();

    _face.advance(now);

    final session = _session;
    final mode = _resolveMode(now, session);

    state = BotState(
      mode: mode,
      mood: _face.mood,
      now: now,
      blockName: session?.block?.name ?? '',
      blockDescription: session?.block?.description ?? '',
      category: session?.block?.category ?? 0,
      remaining: session?.remaining ?? Duration.zero,
      progress: session?.progress ?? 0,
      sessionState: session?.state ?? SessionState.idle,
      trackEnabled: session?.block?.trackEnabled ?? false,
      verification: session?.verification ?? BotState.initial(now).verification,
      nextBlockName: _nextBlockName,
      nextBlockAt: _nextBlockAt,
      gazeX: _face.gazeX,
      gazeY: _face.gazeY,
      blink: _face.blink,
      eyeShape: _face.eyes,
    );
  }

  BotMode _resolveMode(DateTime now, SessionSnapshot? session) {
    final until = _overrideUntil;
    if (_override != null && until != null && now.isBefore(until)) {
      return _override!;
    }
    _override = null;
    _overrideUntil = null;

    // A running block always wins: the countdown is the reason the device is
    // on the desk.
    if (session != null && session.isActive) return BotMode.task;

    if (now.difference(_lastInteraction) >= FfFirmware.dimAfter) {
      return BotMode.dim;
    }
    return BotMode.ambient;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final virtualBotProvider = StateNotifierProvider<VirtualBotEngine, BotState>((
  ref,
) {
  final engine = VirtualBotEngine();

  // The bot is a view of the session, so it follows rather than polls.
  ref.listen<SessionSnapshot>(
    sessionControllerProvider,
    (_, next) => engine.applySession(next),
    fireImmediately: true,
  );

  return engine;
});
