/// The verification factors, and what the app is allowed to conclude from them.
library;

/// One channel of evidence.
enum VerificationFactor {
  /// You are at the desk. Bot only — a phone cannot know this.
  presence,

  /// The phone is physically parked.
  dock,

  /// The phone's screen is off.
  screenLock,

  /// No distracting app was opened. App only.
  appUsage;

  String get label => switch (this) {
    VerificationFactor.presence => 'HERE',
    VerificationFactor.dock => 'DOCK',
    VerificationFactor.screenLock => 'LOCK',
    VerificationFactor.appUsage => 'APPS',
  };

  String get description => switch (this) {
    VerificationFactor.presence => 'You are at the desk',
    VerificationFactor.dock => 'The phone is docked',
    VerificationFactor.screenLock => 'The screen is off',
    VerificationFactor.appUsage => 'No distracting app is open',
  };

  int get bit => 1 << index;
}

/// A factor's reading.
///
/// Three states, not two. [unavailable] is the whole point: when there is no
/// sensor for a factor, the app says so rather than guessing. An absent
/// ultrasonic sensor must never read as "you left the desk", and must never
/// quietly read as "present" either.
enum FactorState { holding, violated, unavailable }

/// A complete verification reading at one instant.
class VerificationSnapshot {
  const VerificationSnapshot({
    required this.factors,
    required this.trackEnabled,
  });

  /// Every factor the system knows about, with its current state.
  final Map<VerificationFactor, FactorState> factors;

  /// Whether this block asked to be tracked at all.
  final bool trackEnabled;

  /// A snapshot with nothing available — the honest default before any source
  /// has reported.
  static const VerificationSnapshot none = VerificationSnapshot(
    factors: <VerificationFactor, FactorState>{},
    trackEnabled: false,
  );

  FactorState stateOf(VerificationFactor f) =>
      factors[f] ?? FactorState.unavailable;

  Iterable<VerificationFactor> get available => factors.entries
      .where((e) => e.value != FactorState.unavailable)
      .map((e) => e.key);

  Iterable<VerificationFactor> get violating => factors.entries
      .where((e) => e.value == FactorState.violated)
      .map((e) => e.key);

  /// Bitmask of which factors had a source. Persisted per session so a report
  /// never compares a 3-factor day against a 1-factor day without saying so.
  int get availabilityMask => available.fold(0, (mask, f) => mask | f.bit);

  /// The verdict.
  ///
  /// Rules, in order:
  ///
  /// * Tracking off → verified. A plain timer is not a failed verification, it
  ///   is a different thing, and [Provenance.untracked] records which.
  /// * No factor available at all → **not** verified. Claiming verification
  ///   with zero evidence is exactly the dishonesty this product exists to
  ///   replace.
  /// * Otherwise → every *available* factor must hold. Unavailable factors are
  ///   excluded, never assumed.
  bool get isVerified {
    if (!trackEnabled) return true;
    if (available.isEmpty) return false;
    return violating.isEmpty;
  }

  VerificationSnapshot copyWith({
    Map<VerificationFactor, FactorState>? factors,
    bool? trackEnabled,
  }) => VerificationSnapshot(
    factors: factors ?? this.factors,
    trackEnabled: trackEnabled ?? this.trackEnabled,
  );

  VerificationSnapshot withFactor(VerificationFactor f, FactorState s) =>
      copyWith(factors: <VerificationFactor, FactorState>{...factors, f: s});

  @override
  String toString() {
    final parts = VerificationFactor.values
        .map((f) => '${f.label}=${stateOf(f).name}')
        .join(' ');
    return 'VerificationSnapshot(track=$trackEnabled $parts '
        '=> ${isVerified ? 'verified' : 'unverified'})';
  }
}

// What a connected bot declares it has used to be modelled here as a second
// `DeviceCapabilities`, written before the device layer existed. It now lives
// in `lib/device/protocol.dart`, decoded from `0x81 HELLO_ACK` against
// `docs/PROTOCOL.md` §4, with one class rather than two that could drift
// apart. The capability → factor mapping is in
// `lib/device/device_verification_source.dart`, because which sensor counts as
// which evidence is verification policy, not wire format.
