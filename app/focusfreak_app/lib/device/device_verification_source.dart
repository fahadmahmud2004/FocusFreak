/// The bot as a source of verification evidence.
///
/// This is the whole of Phase 5 on the verification side: one more
/// [VerificationSource] added to the composite. The session engine does not
/// change, the UI does not change, and unplugging the bot degrades to app-only
/// verification instead of failing.
library;

import 'dart:async';

import '../core/ff_constants.dart';
import '../domain/engine/verification_source.dart';
import '../domain/model/verification.dart';
import 'device_link.dart';
import 'protocol.dart';
import 'transport/transport.dart';

/// Reads presence and dock from a connected bot.
///
/// Two rules keep it honest, and both are tested:
///
/// 1. **A factor is only offered if the device declared the sensor.** No
///    HC-SR04 in `caps_lo` means presence is unavailable — never "you left".
/// 2. **A stale link offers nothing.** If status frames stop arriving, the
///    last one is not evidence about now. Continuing to vouch for a user from
///    a reading taken minutes ago is exactly the false claim the product
///    exists to avoid.
class DeviceVerificationSource implements VerificationSource {
  DeviceVerificationSource({
    DeviceLink? link,
    Duration? staleAfter,
    DateTime Function()? clock,
  }) : staleAfter = staleAfter ?? FfFirmware.statusPollInterval * 3,
       _clock = clock ?? DateTime.now {
    attach(link);
  }

  /// The live link, or null when no bot is connected.
  DeviceLink? get link => _link;
  DeviceLink? _link;

  /// Points this source at a different link — or at none.
  ///
  /// Connecting a bot mid-session must not rebuild the session's verification
  /// source: that would discard the running block. So the source outlives any
  /// one connection and is re-pointed instead.
  void attach(DeviceLink? link) {
    unawaited(_statusSub?.cancel());
    unawaited(_stateSub?.cancel());
    _statusSub = null;
    _stateSub = null;
    _link = link;
    _status = null;
    _statusAt = null;

    if (link != null) {
      _statusSub = link.statuses.listen((status) {
        _status = status;
        _statusAt = _clock();
        _ping();
      });
      _stateSub = link.states.listen((state) {
        if (state != LinkState.connected) {
          // Losing the link clears the reading rather than freezing it.
          _status = null;
          _statusAt = null;
        }
        _ping();
      });
    }
    _ping();
  }

  /// How old a status may be and still count as a reading about *now*.
  ///
  /// Three poll intervals: one missed poll is a dropped frame on a 9600-baud
  /// clone module, three in a row is a bot that is no longer talking.
  final Duration staleAfter;

  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  StreamSubscription<DeviceStatus>? _statusSub;
  StreamSubscription<LinkState>? _stateSub;

  DeviceStatus? _status;
  DateTime? _statusAt;

  /// Which factors this bot can speak to at all.
  ///
  /// Presence is the one a phone physically cannot supply, which is why its
  /// presence in the mask is what separates a sensor-verified session from an
  /// app-verified one.
  @override
  Set<VerificationFactor> get providedFactors {
    final link = _link;
    if (link == null || link.state != LinkState.connected) {
      return const <VerificationFactor>{};
    }
    final caps = link.capabilities;
    return <VerificationFactor>{
      if (caps.has(DeviceCapability.presence)) VerificationFactor.presence,
      if (caps.has(DeviceCapability.dock)) VerificationFactor.dock,
    };
  }

  bool get isStale {
    final at = _statusAt;
    if (at == null) return true;
    return _clock().difference(at) > staleAfter;
  }

  /// The device's own verdict, carried through for display beside the app's.
  ///
  /// Never used to decide verification — the app computes that from the
  /// factors. A disagreement between the two is a firmware bug worth seeing
  /// (`docs/PROTOCOL.md` §6).
  bool? get deviceVerdict => isStale ? null : _status?.deviceVerified;

  @override
  VerificationSnapshot read({required bool trackEnabled}) {
    final provided = providedFactors;
    final status = _status;
    if (provided.isEmpty || status == null || isStale) {
      return VerificationSnapshot(
        trackEnabled: trackEnabled,
        factors: <VerificationFactor, FactorState>{
          for (final f in provided) f: FactorState.unavailable,
        },
      );
    }
    return VerificationSnapshot(
      trackEnabled: trackEnabled,
      factors: <VerificationFactor, FactorState>{
        if (provided.contains(VerificationFactor.presence))
          VerificationFactor.presence: status.present
              ? FactorState.holding
              : FactorState.violated,
        if (provided.contains(VerificationFactor.dock))
          VerificationFactor.dock: status.docked
              ? FactorState.holding
              : FactorState.violated,
      },
    );
  }

  @override
  Stream<void> get changes => _changes.stream;

  void _ping() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> dispose() async {
    await _statusSub?.cancel();
    await _stateSub?.cancel();
    await _changes.close();
  }
}
