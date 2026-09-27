import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/app/providers.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/device/protocol.dart';
import 'package:focusfreak_app/device/transport/transport.dart';
import 'package:focusfreak_app/domain/engine/verification_source.dart';
import 'package:focusfreak_app/domain/model/verification.dart';
import 'package:focusfreak_app/features/device/device_controller.dart';
import 'package:focusfreak_app/features/timer/session_controller.dart';

/// The wiring test: connecting a bot has to change what the *session* can
/// verify, not just what the device screen shows. That handover is the point
/// of the whole phase.
void main() {
  late ProviderContainer container;
  late ManualVerificationSource phone;

  setUp(() {
    // The phone's half, stood in for.
    //
    // The real one is `PhoneVerificationSource`, which talks to two platform
    // channels that do not exist in a test binding — and, correctly, reports
    // *nothing* when they do not. These tests are about the bot's half of the
    // handover, so the phone's half is injected already reporting, and the
    // "reports nothing" case has its own test in
    // `phone_verification_source_test.dart`.
    phone = ManualVerificationSource(
      provides: <VerificationFactor>{VerificationFactor.screenLock},
    )..set(VerificationFactor.screenLock, true);

    container = ProviderContainer(
      overrides: <Override>[
        phoneVerificationSourceProvider.overrideWithValue(phone),
      ],
    );
  });
  tearDown(() => container.dispose());

  DeviceController controller() =>
      container.read(deviceControllerProvider.notifier);

  Block block(String name, {int minutes = 30, bool track = false}) => Block(
    id: name,
    routineId: 'r',
    position: 0,
    name: name,
    description: '',
    durationMin: minutes,
    category: 0,
    trackEnabled: track,
    startMin: 0xFFFF,
  );

  group('connecting', () {
    test('the virtual bot completes a real handshake', () async {
      await controller().connectVirtual();

      final state = container.read(deviceControllerProvider);
      expect(state.isConnected, isTrue);
      expect(state.kind, DeviceKind.virtual);
      expect(state.ack, isNotNull);
      expect(state.capabilities.has(DeviceCapability.presence), isTrue);
      expect(state.error, isNull);
    });

    test('the wire log records both directions', () async {
      // §14: this log beside Logcat's FF-WIRE is what resolves an integration
      // bug quickly.
      await controller().connectVirtual();
      final log = container.read(deviceControllerProvider).wireLog;

      expect(log.any((l) => l.contains('>> HELLO')), isTrue);
      expect(log.any((l) => l.contains('<< HELLO_ACK')), isTrue);
      expect(log.any((l) => l.contains('>> SET_TIME')), isTrue);
    });

    test('disconnecting clears the device, not the log', () async {
      await controller().connectVirtual();
      await controller().disconnect();

      final state = container.read(deviceControllerProvider);
      expect(state.isConnected, isFalse);
      expect(state.link, LinkState.disconnected);
      expect(state.ack, isNull);
      expect(state.status, isNull);
      expect(state.wireLog, isNotEmpty);
    });
  });

  group('verification handover', () {
    test('no bot means the session sees only screen lock', () {
      final source = container.read(verificationSourceProvider);
      expect(source.providedFactors, <VerificationFactor>{
        VerificationFactor.screenLock,
      });
    });

    test(
      'connecting adds presence and dock to the session\'s own source',
      () async {
        // Read the composite *before* connecting: it must be the same object
        // afterwards. Rebuilding it would rebuild the SessionController and
        // discard a block that was running.
        final before = container.read(verificationSourceProvider);
        await controller().connectVirtual();
        final after = container.read(verificationSourceProvider);

        expect(identical(before, after), isTrue);
        expect(after.providedFactors, <VerificationFactor>{
          VerificationFactor.screenLock,
          VerificationFactor.presence,
          VerificationFactor.dock,
        });
      },
    );

    test('the bot vouches only while its readings are current', () async {
      final source = container.read(verificationSourceProvider);
      expect(phone.providedFactors, isNotEmpty);

      await controller().connectVirtual();
      await controller().refreshStatus();

      final snapshot = source.read(trackEnabled: true);
      expect(
        snapshot.stateOf(VerificationFactor.presence),
        FactorState.holding,
      );
      expect(snapshot.isVerified, isTrue);
      expect(
        snapshot.availabilityMask & VerificationFactor.presence.bit,
        isNot(0),
        reason: 'presence is what separates sensor-verified from app-verified',
      );
    });

    test('an empty chair reaches the session as a violation', () async {
      await controller().connectVirtual();
      controller().simulated!.present = false;
      await controller().refreshStatus();

      final snapshot = container
          .read(verificationSourceProvider)
          .read(trackEnabled: true);
      expect(
        snapshot.stateOf(VerificationFactor.presence),
        FactorState.violated,
      );
      expect(snapshot.isVerified, isFalse);
    });

    test('disconnecting withdraws the bot\'s factors immediately', () async {
      await controller().connectVirtual();
      await controller().refreshStatus();
      await controller().disconnect();

      final source = container.read(verificationSourceProvider);
      expect(source.providedFactors, <VerificationFactor>{
        VerificationFactor.screenLock,
      });
      expect(
        source.read(trackEnabled: true).availabilityMask &
            VerificationFactor.presence.bit,
        0,
      );
    });
  });

  group('routine push', () {
    test('sends the blocks and reports what happened', () async {
      await controller().connectVirtual();
      final report = await controller().pushRoutine(<Block>[
        block('Deep Work', minutes: 90, track: true),
        block('Break', minutes: 15),
      ]);

      expect(report.ok, isTrue);
      expect(report.message, contains('2 blocks'));
    });

    test(
      'a routine past the device capacity is refused, not truncated',
      () async {
        // Silently dropping someone's last four blocks would be a lie the app
        // told itself.
        await controller().connectVirtual();
        final report = await controller().pushRoutine(<Block>[
          for (var i = 0; i < 20; i++) block('B$i'),
        ]);

        expect(report.ok, isFalse);
        expect(report.message, contains('16'));
      },
    );

    test(
      'a name too long for the wire field fails with a readable message',
      () async {
        await controller().connectVirtual();
        final report = await controller().pushRoutine(<Block>[
          block('A block name well past sixteen characters'),
        ]);

        expect(report.ok, isFalse);
        expect(report.message, contains('16'));
      },
    );

    test('pushing with no bot connected is refused politely', () async {
      final report = await controller().pushRoutine(<Block>[block('X')]);
      expect(report.ok, isFalse);
      expect(report.message, contains('No bot'));
    });
  });

  group('control', () {
    test('start runs a block and the mirrored status follows', () async {
      await controller().connectVirtual();
      await controller().pushRoutine(<Block>[
        block('Deep Work', minutes: 90, track: true),
      ]);
      await controller().control(ControlAction.start);

      final status = container.read(deviceControllerProvider).status;
      expect(status?.state, DeviceRunState.running);
      expect(status?.secsLeft, 90 * 60);
    });

    test('control on a dead link does nothing rather than throwing', () async {
      await expectLater(controller().control(ControlAction.pause), completes);
    });
  });
}
