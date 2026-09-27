/// Turning the phone's sensors on for exactly as long as a tracked block runs.
///
/// The shape mirrors `AlarmScheduler`: one object that watches the session and
/// applies a side effect, so there is a single definition of "a tracked block is
/// running" and `SessionController` stays free of platform code.
///
/// Two rules decide everything here.
///
/// **Nothing observes outside a tracked block.** An untracked block asked not to
/// be watched, and watching it anyway would be both a battery cost and a promise
/// the user did not make.
///
/// **Stopping clears the readings.** `PhoneVerificationSource.stop` drops every
/// factor rather than freezing it, so the gap between one block and the next is
/// "no evidence", never a stale "holding" inherited from the last one.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repo/settings_repository.dart';
import '../../platform/phone_verification_source.dart';
import 'session_controller.dart';

/// Whether stillness may stand in for the bot's dock switch.
final useStillnessAsDockProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watchBool(SettingKey.useStillnessAsDock),
);

/// Opt-in. Off until the user turns it on and grants usage access.
final useAppUsageTrackingProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watchBool(SettingKey.useAppUsageTracking),
);

/// Starts and stops [PhoneVerificationSource] in step with the session.
class PhoneTracker {
  PhoneTracker(this._source);

  /// Null when the installed phone source is not the platform one — which is
  /// the case in every test, where the composite holds a
  /// `ManualVerificationSource` instead. There is nothing to start or stop
  /// then, and pretending otherwise would mean tests exercising a code path
  /// that never runs on a phone.
  final PhoneVerificationSource? _source;

  bool _useStillness = true;
  bool _useAppUsage = false;

  /// What is currently being observed, so a settings change mid-block can be
  /// applied without restarting the observation.
  bool _observing = false;

  /// Serialises the platform calls.
  ///
  /// The session publishes every second and settings arrive on their own
  /// streams; without this, a stop and a start could overlap and leave the
  /// plugin observing after the block that wanted it had ended.
  Future<void> _pending = Future<void>.value();

  Future<void> get settled => _pending;

  void apply(SessionSnapshot session) {
    final source = _source;
    if (source == null) return;

    final block = session.block;
    final wanted =
        session.state.isActive && block != null && block.trackEnabled;

    if (wanted && !_observing) {
      _observing = true;
      final name = block.name;
      _queue(
        () => source.start(
          useStillness: _useStillness,
          useAppUsage: _useAppUsage,
          title: '$name is running',
          body: 'FocusFreak is checking you are still with it.',
        ),
      );
    } else if (!wanted && _observing) {
      _observing = false;
      _queue(source.stop);
    }
  }

  void setStillness(bool value) {
    if (_useStillness == value) return;
    _useStillness = value;
    _reconfigure();
  }

  void setAppUsage(bool value) {
    if (_useAppUsage == value) return;
    _useAppUsage = value;
    _reconfigure();
  }

  /// Turning a factor off has to take back the one already being reported, not
  /// just stop the next block from reporting it.
  void _reconfigure() {
    final source = _source;
    if (source == null || !_observing) return;
    _queue(
      () => source.configure(
        useStillness: _useStillness,
        useAppUsage: _useAppUsage,
      ),
    );
  }

  void _queue(Future<void> Function() work) {
    _pending = _pending.then((_) => work()).catchError((Object _) {
      // A platform call that fails leaves the source reporting nothing, which
      // the verification engine already handles as "no evidence". Taking down
      // the session over it would be the worse outcome.
    });
  }

  /// Only the observation is stopped here. The source itself is owned by
  /// [phoneVerificationSourceProvider] and outlives this, because it is a
  /// member of the session's build-once composite.
  Future<void> dispose() async {
    if (!_observing) return;
    _observing = false;
    await _source?.stop();
  }
}

// -- Providers -----------------------------------------------------------------

/// The live wiring, watched by the app shell so it exists for the whole
/// session rather than only while a screen that cares is on top.
final phoneTrackerProvider = Provider<PhoneTracker>((ref) {
  final source = ref.watch(phoneVerificationSourceProvider);
  final tracker = PhoneTracker(
    source is PhoneVerificationSource ? source : null,
  );

  void follow<T>(
    ProviderListenable<AsyncValue<T>> provider,
    void Function(T value) apply,
  ) {
    final current = ref.read(provider);
    if (current.hasValue) apply(current.requireValue);
    ref.listen<AsyncValue<T>>(provider, (_, next) {
      if (next.hasValue) apply(next.requireValue);
    });
  }

  // Settings first, so a block starting in the same frame starts with the
  // user's choices rather than the defaults.
  follow<bool>(useStillnessAsDockProvider, tracker.setStillness);
  follow<bool>(useAppUsageTrackingProvider, tracker.setAppUsage);

  ref.listen<SessionSnapshot>(
    sessionControllerProvider,
    (_, next) => tracker.apply(next),
    fireImmediately: true,
  );

  ref.onDispose(tracker.dispose);
  return tracker;
});
