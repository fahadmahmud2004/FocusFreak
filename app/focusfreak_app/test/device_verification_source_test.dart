import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/device/device_link.dart';
import 'package:focusfreak_app/device/device_verification_source.dart';
import 'package:focusfreak_app/device/protocol.dart';
import 'package:focusfreak_app/device/simulated_device.dart';
import 'package:focusfreak_app/device/transport/loopback_transport.dart';
import 'package:focusfreak_app/domain/engine/verification_source.dart';
import 'package:focusfreak_app/domain/model/verification.dart';

/// The claim this file defends: connecting a bot adds evidence, and losing one
/// removes it — but neither ever produces a *guess*.
void main() {
  late SimulatedDevice device;
  late DeviceLink link;
  late DeviceVerificationSource source;
  var now = DateTime(2026, 8, 2, 9);

  Future<void> connect({
    DeviceCapabilities caps = SimulatedDeviceConfig.defaultCapabilities,
  }) async {
    device = SimulatedDevice(config: SimulatedDeviceConfig(capabilities: caps));
    link = DeviceLink(
      LoopbackTransport(device: device, latency: Duration.zero),
      statusPoll: const Duration(seconds: 30),
    );
    await link.connect();
    source = DeviceVerificationSource(
      link: link,
      staleAfter: const Duration(seconds: 15),
      clock: () => now,
    );
    await link.requestStatus();
  }

  setUp(() => now = DateTime(2026, 8, 2, 9));
  tearDown(() async {
    await source.dispose();
    await link.dispose();
  });

  test('offers presence and dock when the bot declares both sensors', () async {
    await connect();
    expect(source.providedFactors, <VerificationFactor>{
      VerificationFactor.presence,
      VerificationFactor.dock,
    });

    final snapshot = source.read(trackEnabled: true);
    expect(snapshot.stateOf(VerificationFactor.presence), FactorState.holding);
    expect(snapshot.stateOf(VerificationFactor.dock), FactorState.holding);
    expect(snapshot.isVerified, isTrue);
  });

  test(
    'a sensor the bot does not have is unavailable, never violated',
    () async {
      // Presence only: no reed switch on this unit.
      await connect(caps: const DeviceCapabilities(0x01, 0x00));
      expect(source.providedFactors, <VerificationFactor>{
        VerificationFactor.presence,
      });

      final snapshot = source.read(trackEnabled: true);
      expect(
        snapshot.stateOf(VerificationFactor.dock),
        FactorState.unavailable,
      );
      expect(snapshot.violating, isEmpty);
      expect(snapshot.isVerified, isTrue, reason: 'one factor, and it holds');
    },
  );

  test('an empty chair is a violation, not an absence', () async {
    await connect();
    device.present = false;
    await link.requestStatus();

    final snapshot = source.read(trackEnabled: true);
    expect(snapshot.stateOf(VerificationFactor.presence), FactorState.violated);
    expect(snapshot.isVerified, isFalse);
  });

  test('a stale link stops vouching', () async {
    // The rule that matters most. A bot that went quiet four minutes ago knows
    // nothing about now, and saying otherwise would be the exact false claim
    // the product exists to replace.
    await connect();
    expect(source.read(trackEnabled: true).isVerified, isTrue);

    now = now.add(const Duration(seconds: 20));
    expect(source.isStale, isTrue);

    final snapshot = source.read(trackEnabled: true);
    expect(
      snapshot.stateOf(VerificationFactor.presence),
      FactorState.unavailable,
    );
    expect(snapshot.available, isEmpty);
    expect(
      snapshot.isVerified,
      isFalse,
      reason: 'no evidence is not the same as good evidence',
    );
    expect(source.deviceVerdict, isNull);
  });

  test('a fresh status makes it current again', () async {
    await connect();
    now = now.add(const Duration(seconds: 20));
    expect(source.isStale, isTrue);

    await link.requestStatus();
    expect(source.isStale, isFalse);
    expect(source.read(trackEnabled: true).isVerified, isTrue);
  });

  test('disconnecting withdraws the factors entirely', () async {
    await connect();
    await link.disconnect();

    expect(source.providedFactors, isEmpty);
    final snapshot = source.read(trackEnabled: true);
    expect(snapshot.available, isEmpty);
    expect(snapshot.isVerified, isFalse);
  });

  test('the device verdict is carried but not used to decide', () async {
    await connect();
    expect(source.deviceVerdict, isNotNull);

    device.present = false;
    await link.requestStatus();
    expect(source.deviceVerdict, isFalse);
    expect(source.read(trackEnabled: true).isVerified, isFalse);
  });

  test(
    'in the composite, the bot adds presence to the phone\'s screen-lock',
    () async {
      // §5.4: the bot supplies presence and dock, the phone keeps supplying
      // screen-lock, and neither knows about the other.
      await connect();
      final phone = ManualVerificationSource(
        provides: <VerificationFactor>{VerificationFactor.screenLock},
      )..set(VerificationFactor.screenLock, true);

      final composite = CompositeVerificationSource(<VerificationSource>[
        phone,
        source,
      ]);
      expect(composite.providedFactors, <VerificationFactor>{
        VerificationFactor.screenLock,
        VerificationFactor.presence,
        VerificationFactor.dock,
      });

      final snapshot = composite.read(trackEnabled: true);
      expect(snapshot.isVerified, isTrue);
      expect(
        snapshot.availabilityMask & VerificationFactor.presence.bit,
        isNot(0),
        reason: 'presence in the mask is what makes this sensor-verified',
      );

      // Losing the bot degrades to app-only rather than failing.
      await link.disconnect();
      final degraded = composite.read(trackEnabled: true);
      expect(degraded.isVerified, isTrue);
      expect(degraded.availabilityMask & VerificationFactor.presence.bit, 0);
    },
  );

  test('a violation from the bot outranks a phone that is happy', () async {
    await connect();
    device.present = false;
    await link.requestStatus();

    final phone = ManualVerificationSource(
      provides: <VerificationFactor>{VerificationFactor.screenLock},
    )..set(VerificationFactor.screenLock, true);
    final composite = CompositeVerificationSource(<VerificationSource>[
      phone,
      source,
    ]);

    expect(composite.read(trackEnabled: true).isVerified, isFalse);
  });

  test('an untracked block is not a failed verification', () async {
    await connect();
    device.present = false;
    await link.requestStatus();
    expect(source.read(trackEnabled: false).isVerified, isTrue);
  });
}
