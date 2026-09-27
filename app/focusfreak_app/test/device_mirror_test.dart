import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/device/device_link.dart';
import 'package:focusfreak_app/device/protocol.dart';
import 'package:focusfreak_app/device/simulated_device.dart';
import 'package:focusfreak_app/device/transport/loopback_transport.dart';
import 'package:focusfreak_app/domain/model/bot_state.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/domain/model/verification.dart';
import 'package:focusfreak_app/features/bot/device_mirror.dart';
import 'package:focusfreak_app/features/device/device_controller.dart';
import 'package:focusfreak_app/features/bot/virtual_bot_engine.dart';

/// The claim this file defends: connecting a bot makes the Bot tab show *that
/// bot*, without inventing anything `0xB0 STATUS` does not carry.
void main() {
  late SimulatedDevice device;
  late DeviceLink link;
  late DeviceMirror mirror;
  var now = DateTime(2026, 8, 3, 9);

  final routine = <WireBlock>[
    WireBlock(
      name: 'Deep Work 1',
      description: 'Math + Physics',
      durationMin: 50,
      category: 1,
      trackEnabled: true,
      startMin: 9 * 60,
    ),
    WireBlock(
      name: 'Break',
      durationMin: 10,
      category: 3,
      startMin: 9 * 60 + 50,
    ),
  ];

  Future<void> connect({
    DeviceCapabilities caps = SimulatedDeviceConfig.defaultCapabilities,
    List<WireBlock>? blocks,
  }) async {
    device = SimulatedDevice(config: SimulatedDeviceConfig(capabilities: caps));
    device.seedRoutine(blocks ?? routine);
    link = DeviceLink(
      LoopbackTransport(device: device, latency: Duration.zero),
      statusPoll: const Duration(seconds: 30),
      streamQuietPeriod: const Duration(milliseconds: 20),
    );
    await link.connect();
    mirror = DeviceMirror(
      clock: () => now,
      staleAfter: const Duration(seconds: 15),
    )..attach(link, deviceName: 'Virtual bot');
    // The routine pull ends on a quiet gap, so it takes a beat to land.
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  /// Runs the block at [index] on the device and lets the mirror see it.
  Future<void> startBlock(int index) async {
    await link.control(ControlAction.start, arg: index);
  }

  BotState face() => mirror.state!;

  setUp(() => now = DateTime(2026, 8, 3, 9));
  tearDown(() async {
    mirror.dispose();
    await link.dispose();
  });

  test('a connected bot produces the face, not the simulation', () async {
    await connect();
    expect(
      face().live,
      isTrue,
      reason: 'the badge on this screen says where the numbers came from',
    );
    expect(face().deviceName, 'Virtual bot');
  });

  test(
    'a running block arrives with its name, category and countdown',
    () async {
      await connect();
      await startBlock(0);

      expect(face().sessionState, SessionState.running);
      expect(face().mode, BotMode.task);
      expect(face().blockName, 'Deep Work 1');
      expect(face().blockDescription, 'Math + Physics');
      expect(face().category, 1);
      expect(face().trackEnabled, isTrue);
      expect(face().remaining, const Duration(minutes: 50));
      expect(face().progress, 0);
      expect(face().nextBlockName, 'Break');
      expect(face().nextBlockAt, DateTime(2026, 8, 3, 9, 50));
    },
  );

  test('the countdown runs between status frames and corrects on one', () async {
    // STATUS arrives every 5 s. A mirror that only redrew on frames would show
    // a countdown that jumps in five-second steps.
    await connect();
    await startBlock(0);

    now = now.add(const Duration(seconds: 3));
    mirror.tick();
    expect(face().remaining, const Duration(minutes: 49, seconds: 57));

    // The device is the authority: its own count wins on the next frame.
    device.advance(const Duration(seconds: 30));
    now = now.add(const Duration(seconds: 2));
    await link.requestStatus();
    expect(face().remaining, const Duration(minutes: 49, seconds: 30));
    expect(face().progress, closeTo(30 / 3000, 0.0001));
  });

  test(
    'a stale link freezes the countdown instead of inventing progress',
    () async {
      await connect();
      await startBlock(0);

      now = now.add(const Duration(seconds: 20)); // past staleAfter
      mirror.tick();

      expect(mirror.isStale, isTrue);
      expect(
        face().remaining,
        const Duration(minutes: 50),
        reason: 'a reading from four minutes ago is not a countdown',
      );
    },
  );

  test('a stale link withdraws the evidence too', () async {
    await connect();
    await startBlock(0);
    expect(
      face().verification.stateOf(VerificationFactor.presence),
      FactorState.holding,
    );

    now = now.add(const Duration(seconds: 20));
    mirror.tick();

    final v = face().verification;
    expect(v.stateOf(VerificationFactor.presence), FactorState.unavailable);
    expect(v.stateOf(VerificationFactor.dock), FactorState.unavailable);
    expect(v.available, isEmpty);
    expect(
      v.isVerified,
      isFalse,
      reason: 'no evidence is not the same as good evidence',
    );
  });

  test('an empty chair shows as a violation', () async {
    await connect();
    await startBlock(0);
    device.present = false;
    await link.requestStatus();

    expect(
      face().verification.stateOf(VerificationFactor.presence),
      FactorState.violated,
    );
    expect(face().verification.isVerified, isFalse);
  });

  test(
    'a sensor the bot does not have is unavailable, never violated',
    () async {
      // Presence only: no reed switch on this unit.
      await connect(caps: const DeviceCapabilities(0x01, 0x00));
      await startBlock(0);

      final v = face().verification;
      expect(v.stateOf(VerificationFactor.presence), FactorState.holding);
      expect(v.stateOf(VerificationFactor.dock), FactorState.unavailable);
      expect(v.violating, isEmpty);
    },
  );

  test(
    'screen-lock is only claimed while the heartbeat is feeding it',
    () async {
      await connect();
      expect(
        face().verification.stateOf(VerificationFactor.screenLock),
        FactorState.unavailable,
        reason: 'nothing is being tracked, so nothing is reporting the screen',
      );

      await startBlock(0);
      expect(
        face().verification.stateOf(VerificationFactor.screenLock),
        FactorState.holding,
      );
    },
  );

  test('mood follows the device, and blends rather than snapping', () async {
    await connect();
    await startBlock(0);
    expect(face().mood, Mood.calm);

    // A verification drop-out is what turns the real bot searching.
    await link.control(ControlAction.pause);
    expect(face().mood, Mood.searching);
    expect(
      face().eyeShape!.height,
      isNot(closeTo(EyeParams.forMood(Mood.searching).height, 0.01)),
      reason: 'the 8-frame transition is the whole point of eyeShape',
    );

    for (var i = 0; i < 8; i++) {
      mirror.tick();
    }
    expect(
      face().eyeShape!.height,
      closeTo(EyeParams.forMood(Mood.searching).height, 0.01),
    );
  });

  test('the day\'s numbers are the device\'s own', () async {
    await connect();
    device
      ..streak = 4
      ..verifiedToday = 96;
    await link.requestStatus();

    expect(face().streak, 4);
    expect(face().verifiedMinutesToday, 96);
    expect(
      face().temperatureC,
      isNull,
      reason: 'STATUS carries no comfort reading, so none is shown',
    );
    expect(
      face().batteryPct,
      isNull,
      reason: 'this build has no battery gauge and must not invent one',
    );
  });

  test('an idle bot with someone at the desk is showing Attention', () async {
    await connect();
    expect(face().mode, BotMode.attention);

    device.present = false;
    await link.requestStatus();
    expect(face().mode, BotMode.ambient);
  });

  test('losing the link detaches the mirror', () async {
    await connect();
    await link.disconnect();
    expect(
      mirror.state,
      isNull,
      reason: 'a face frozen mid-countdown would outlive the bot',
    );
  });

  test('the Bot tab swaps producers and swaps back', () async {
    // §5.3: one BotState, one BotView, two producers. This is the swap.
    await connect();
    final real = StateProvider<bool>((_) => true);
    final container = ProviderContainer(
      overrides: <Override>[
        virtualBotProvider.overrideWith((ref) => VirtualBotEngine()),
        realBotConnectedProvider.overrideWith((ref) => ref.watch(real)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(botStateProvider).live, isFalse);

    container.read(deviceMirrorProvider.notifier).attach(link);
    expect(container.read(botStateProvider).live, isTrue);

    container.read(deviceMirrorProvider.notifier).attach(null);
    expect(container.read(botStateProvider).live, isFalse);
  });

  test('the virtual bot is the app itself, not a bot to mirror', () async {
    // Connected to the virtual bot, the Bot tab keeps running the app's own
    // BotOS: its sound, its timer. Mirroring it would silence both.
    await connect();
    final container = ProviderContainer(
      overrides: <Override>[
        virtualBotProvider.overrideWith((ref) => VirtualBotEngine()),
        realBotConnectedProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);

    container.read(deviceMirrorProvider.notifier).attach(link);
    expect(container.read(botStateProvider).live, isFalse);
    container.read(deviceMirrorProvider.notifier).attach(null);
  });
}
