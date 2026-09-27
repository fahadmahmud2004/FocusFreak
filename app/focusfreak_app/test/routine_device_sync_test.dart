import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/app/providers.dart';
import 'package:focusfreak_app/device/protocol.dart';
import 'package:focusfreak_app/device/simulated_device.dart';
import 'package:focusfreak_app/domain/engine/session_engine.dart';
import 'package:focusfreak_app/domain/engine/verification_source.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/domain/model/verification.dart';
import 'package:focusfreak_app/features/device/device_controller.dart';
import 'package:focusfreak_app/features/device/routine_device_sync.dart';
import 'package:focusfreak_app/features/timer/session_controller.dart';

/// A full day is up to 35 blocks and the bot holds 16. These check that the
/// bot is always holding — and running — the block the phone is on.
void main() {
  late ProviderContainer container;
  late RoutineDeviceSync sync;

  setUp(() async {
    container = ProviderContainer(
      overrides: <Override>[
        phoneVerificationSourceProvider.overrideWithValue(
          ManualVerificationSource(provides: <VerificationFactor>{}),
        ),
      ],
    );
    final device = container.read(deviceControllerProvider.notifier);
    await device.connectVirtual();
    sync = RoutineDeviceSync(device);
  });
  tearDown(() => container.dispose());

  SimulatedDevice bot() =>
      container.read(deviceControllerProvider.notifier).simulated!;

  final day = <ActiveBlock>[
    for (var i = 0; i < 30; i++)
      ActiveBlock(
        id: 'b$i',
        name: 'Block $i',
        category: i.isEven ? 0 : 4,
        duration: const Duration(minutes: 30),
        trackEnabled: i.isEven,
      ),
  ];

  SessionSnapshot at(
    int index, {
    List<ActiveBlock>? queue,
    Duration? remaining,
    SessionState state = SessionState.running,
    bool pausedByUser = false,
  }) {
    final q = queue ?? day;
    return SessionSnapshot(
      state: state,
      block: state.isActive ? q[index] : null,
      remaining: remaining ?? q[index].duration,
      progress: 0,
      verified: Duration.zero,
      claimed: Duration.zero,
      violations: 0,
      mood: Mood.calm,
      verification: VerificationSnapshot.none,
      queue: q,
      queueIndex: index,
      autoMode: true,
      pausedByUser: pausedByUser,
    );
  }

  test(
    'starting a routine sends the next sixteen blocks and starts the first',
    () async {
      await sync.update(at(5), connected: true);

      expect(bot().routine.map((b) => b.name), <String>[
        for (var i = 5; i < 21; i++) 'Block $i',
      ]);
      expect(bot().runState, DeviceRunState.running);
      expect(bot().blockIdx, 0);
    },
  );

  test(
    'a block joined part-way reaches the bot with only what is left',
    () async {
      await sync.update(
        at(2, remaining: const Duration(minutes: 12, seconds: 10)),
        connected: true,
      );
      expect(
        bot().routine.first.durationMin,
        13,
        reason: 'rounded up, so the bot never finishes first',
      );
      expect(bot().routine[1].durationMin, 30);
    },
  );

  test('advancing inside the window moves the bot, without a push', () async {
    await sync.update(at(0), connected: true);
    await sync.update(at(3), connected: true);

    expect(
      bot().routine.first.name,
      'Block 0',
      reason: 'still the window pushed at the start',
    );
    expect(bot().blockIdx, 3);
  });

  test('running off the end of the window sends the next one', () async {
    await sync.update(at(0), connected: true);
    await sync.update(at(16), connected: true);

    expect(bot().routine.first.name, 'Block 16');
    expect(bot().routine, hasLength(14), reason: 'only 14 blocks are left');
    expect(bot().blockIdx, 0);
  });

  test('the user\'s pause and resume reach the bot', () async {
    await sync.update(at(1), connected: true);
    await sync.update(
      at(1, state: SessionState.paused, pausedByUser: true),
      connected: true,
    );
    expect(bot().runState, DeviceRunState.paused);

    await sync.update(at(1), connected: true);
    expect(bot().runState, DeviceRunState.running);
  });

  test('stopping the routine stops the bot', () async {
    await sync.update(at(1), connected: true);
    await sync.update(at(1, state: SessionState.idle), connected: true);
    expect(bot().runState, DeviceRunState.idle);
  });

  test('a bot that reconnects mid-routine is caught up', () async {
    await sync.update(at(1), connected: true);
    await sync.update(at(4), connected: false);
    await sync.update(at(4), connected: true);

    expect(bot().routine.first.name, 'Block 4');
    expect(bot().blockIdx, 0);
  });

  test('a single timer runs on the bot too', () async {
    final single = SessionSnapshot(
      state: SessionState.running,
      block: day.first,
      remaining: day.first.duration,
      progress: 0,
      verified: Duration.zero,
      claimed: Duration.zero,
      violations: 0,
      mood: Mood.calm,
      verification: VerificationSnapshot.none,
      queue: <ActiveBlock>[day.first],
      queueIndex: 0,
    );
    await sync.update(single, connected: true);
    // A timer started in the app counts down on the desk as well.
    expect(bot().routine.map((b) => b.name), <String>['Block 0']);
    expect(bot().runState, DeviceRunState.running);
    expect(bot().blockIdx, 0);
  });
}
