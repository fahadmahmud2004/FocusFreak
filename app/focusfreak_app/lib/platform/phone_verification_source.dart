/// The phone's own evidence, as a [VerificationSource].
///
/// This replaces a `ManualVerificationSource` that declared `screenLock` and
/// that nothing ever set — which meant every bot-less session reported LOCK as
/// holding with no sensor behind it, and verified itself. That is precisely the
/// dishonesty in `docs/ARCHITECTURE.md`'s "never fake a sensor reading", so the central
/// rule here is inverted from the one it replaces: **a factor appears only while
/// something is genuinely watching it.**
///
/// Concretely, `providedFactors` is derived from the last platform reading, not
/// declared up front. Before tracking starts, after it stops, on web and macOS,
/// and whenever a grant is missing, this source provides nothing at all — and a
/// tracked block with no other source is then *unverified*, which is the correct
/// and deliberate outcome.
library;

import 'dart:async';

import '../domain/engine/verification_source.dart';
import '../domain/model/verification.dart';
import 'phone_channel.dart';

class PhoneVerificationSource implements VerificationSource {
  PhoneVerificationSource({PhoneStateChannel? phone, UsageStatsChannel? usage})
    : _phone = phone ?? PhoneStateChannel(),
      _usage = usage ?? UsageStatsChannel();

  final PhoneStateChannel _phone;
  final UsageStatsChannel _usage;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  StreamSubscription<PhoneReading>? _phoneSub;
  StreamSubscription<PhoneReading>? _usageSub;

  PhoneReading _phoneReading = PhoneReading.none;
  PhoneReading _usageReading = PhoneReading.none;

  bool _tracking = false;

  /// Whether the phone is currently observing anything.
  bool get isTracking => _tracking;

  /// The usage-access grant, as of the last reading. Surfaced so the settings
  /// screen can offer the shortcut only when it would do something.
  bool get hasUsageAccess => _usageReading.granted;

  // -- VerificationSource ------------------------------------------------------

  /// Derived, never declared.
  ///
  /// A factor is provided only if the platform reported it in the most recent
  /// reading, which is what keeps it out of `availabilityMask` — and therefore
  /// out of the verdict — when nothing is watching.
  @override
  Set<VerificationFactor> get providedFactors => <VerificationFactor>{
    ..._phoneReading.factors.keys,
    ..._usageReading.factors.keys,
  };

  @override
  VerificationSnapshot read({required bool trackEnabled}) =>
      VerificationSnapshot(
        trackEnabled: trackEnabled,
        factors: <VerificationFactor, FactorState>{
          ..._phoneReading.factors,
          ..._usageReading.factors,
        },
      );

  @override
  Stream<void> get changes => _changes.stream;

  // -- Lifecycle ---------------------------------------------------------------

  /// Starts observing, for the duration of one tracked block.
  ///
  /// [useStillness] and [useAppUsage] are the user's two opt-ins. Both default
  /// off in the sense that matters: passing false does not mean "assume the
  /// factor holds", it means the factor is not reported at all.
  ///
  /// [title] and [body] name the block in the notification shade for as long as
  /// it runs.
  Future<void> start({
    required bool useStillness,
    required bool useAppUsage,
    required String title,
    required String body,
  }) async {
    _tracking = true;
    _phoneSub ??= _phone.readings.listen(_onPhone);
    _usageSub ??= _usage.readings.listen(_onUsage);

    _phoneReading = await _phone.start(
      useStillness: useStillness,
      title: title,
      body: body,
    );
    _usageReading = useAppUsage ? await _usage.start() : PhoneReading.none;
    _emit();
  }

  /// Applies a settings change without interrupting a running observation.
  Future<void> configure({
    required bool useStillness,
    required bool useAppUsage,
  }) async {
    if (!_tracking) return;
    _phoneReading = await _phone.configure(useStillness: useStillness);
    if (useAppUsage) {
      _usageReading = await _usage.start();
    } else {
      await _usage.stop();
      _usageReading = PhoneReading.none;
    }
    _emit();
  }

  /// Stops observing, and takes the factors down with it.
  ///
  /// The readings are cleared rather than left at their last value: a reading
  /// from before the block ended is not evidence about now, which is the same
  /// rule `DeviceVerificationSource` applies to a stale bot.
  Future<void> stop() async {
    if (!_tracking) return;
    _tracking = false;
    await _phone.stop();
    await _usage.stop();
    _phoneReading = PhoneReading.none;
    _usageReading = PhoneReading.none;
    _emit();
  }

  void _onPhone(PhoneReading reading) {
    _phoneReading = _tracking ? reading : PhoneReading.none;
    _emit();
  }

  void _onUsage(PhoneReading reading) {
    _usageReading = _tracking ? reading : PhoneReading.none;
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> dispose() async {
    await _phoneSub?.cancel();
    await _usageSub?.cancel();
    _phoneSub = null;
    _usageSub = null;
    if (_tracking) {
      _tracking = false;
      await _phone.stop();
      await _usage.stop();
    }
    await _changes.close();
  }
}
