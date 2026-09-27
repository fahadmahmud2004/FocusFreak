import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/device/device_link.dart';
import 'package:focusfreak_app/device/frame_codec.dart';
import 'package:focusfreak_app/device/protocol.dart';
import 'package:focusfreak_app/device/simulated_device.dart';
import 'package:focusfreak_app/device/transport/loopback_transport.dart';
import 'package:focusfreak_app/device/transport/transport.dart';

/// The whole device layer, end to end, over a loopback: real frames, real
/// CRCs, real sequence rules. Everything here also has to hold against the
/// firmware — these are the tests that say whether the two agree.
void main() {
  late SimulatedDevice device;
  late LoopbackTransport transport;
  late DeviceLink link;

  /// Zero latency and a short quiet period keep the suite fast; the timing
  /// rules themselves are covered in `frame_codec_test.dart`.
  DeviceLink build({
    SimulatedDeviceConfig config = const SimulatedDeviceConfig(),
    int chunkSize = 0,
  }) {
    device = SimulatedDevice(config: config);
    transport = LoopbackTransport(
      device: device,
      latency: Duration.zero,
      chunkSize: chunkSize,
    );
    return DeviceLink(
      transport,
      statusPoll: const Duration(seconds: 30),
      heartbeat: const Duration(milliseconds: 20),
      streamQuietPeriod: const Duration(milliseconds: 30),
    );
  }

  List<WireBlock> sampleRoutine() => <WireBlock>[
    WireBlock(
      name: 'Deep Work',
      description: 'Phone away',
      durationMin: 90,
      category: 0,
      trackEnabled: true,
      startMin: 330,
    ),
    WireBlock(name: 'Break', durationMin: 15, category: 4),
    WireBlock(name: 'Output', durationMin: 60, category: 2, trackEnabled: true),
  ];

  tearDown(() async => link.dispose());

  group('handshake', () {
    test('HELLO gets HELLO_ACK and the declared capabilities', () async {
      link = build();
      final ack = await link.connect();

      expect(ack.versionMatches, isTrue);
      expect(link.capabilities.has(DeviceCapability.presence), isTrue);
      expect(link.capabilities.has(DeviceCapability.dock), isTrue);
      expect(link.maxBlocks, 16);
      expect(transport.state, LinkState.connected);
    });

    test('capabilities are none before any device has spoken', () {
      link = build();
      expect(link.capabilities.present, isEmpty);
      expect(link.helloAck, isNull);
    });

    test('a device without a sensor never has that capability set', () async {
      // No battery gauge in the build. The app must render nothing rather
      // than a made-up percentage.
      link = build();
      await link.connect();
      expect(link.capabilities.has(DeviceCapability.battery), isFalse);
      expect((await link.requestStatus()).battPct, isNull);
    });

    test(
      'SET_TIME lands, so the device dates its logs from the phone',
      () async {
        link = build();
        await link.connect();
        expect(device.deviceTime, isNotNull);
      },
    );

    test('a silent device times out instead of hanging forever', () async {
      // A paired-but-silent HC-05 — wrong baud, or still in AT mode — is
      // common enough that it needs a real error, not an endless spinner.
      device = SimulatedDevice();
      device.onSend = (_) {}; // swallow every reply
      transport = LoopbackTransport(device: device, latency: Duration.zero);
      transport.device.onSend = (_) {};
      link = DeviceLink(
        transport,
        statusPoll: const Duration(seconds: 30),
        replyTimeout: const Duration(milliseconds: 60),
      );

      await expectLater(link.connect(), throwsA(isA<DeviceTimeoutException>()));
    });

    test('survives replies fragmented one byte per read', () async {
      link = build(chunkSize: 1);
      final ack = await link.connect();
      expect(ack.maxBlocks, 16);
    });
  });

  group('routine push', () {
    test('BEGIN → BLOCKs → COMMIT commits and returns the status', () async {
      link = build();
      await link.connect();

      final result = await link.pushRoutine(sampleRoutine());
      expect(result.ok, isTrue);
      expect(result.status, isNotNull);
      expect(device.routine, hasLength(3));
      expect(device.routine.first.name, 'Deep Work');
      expect(device.routine.first.trackEnabled, isTrue);
      expect(device.routine[1].isSequential, isTrue);
    });

    test('reads back byte-identical to what was pushed', () async {
      link = build();
      await link.connect();
      final pushed = sampleRoutine();
      await link.pushRoutine(pushed);

      final read = await link.fetchRoutine();
      expect(read, hasLength(pushed.length));
      for (var i = 0; i < pushed.length; i++) {
        expect(read[i].encode(), pushed[i].encode());
      }
    });

    test(
      'a bad commit checksum writes nothing and keeps the old routine',
      () async {
        // The failure that matters: a half-written routine is a corrupt device
        // whose only recovery is a factory reset.
        link = build();
        await link.connect();
        await link.pushRoutine(sampleRoutine());
        expect(device.routine, hasLength(3));

        await link.send(routineBeginFrame(1));
        await link.send(
          WireBlock(name: 'Ghost', durationMin: 10, category: 0).toFrame(0),
        );
        final nack = link.nacks.first;
        await link.send(Frame(FfCmd.routineCommit, <int>[0x00, 0x00]));
        expect((await nack).reason, NackReason.routineCrc);

        expect(device.routine, hasLength(3));
        expect(device.routine.first.name, 'Deep Work');
      },
    );

    test(
      'a missing block fails the commit rather than leaving a hole',
      () async {
        link = build();
        await link.connect();

        await link.send(routineBeginFrame(3));
        final blocks = sampleRoutine();
        await link.send(blocks[0].toFrame(0));
        await link.send(blocks[2].toFrame(2)); // index 1 never arrives
        final nack = link.nacks.first;
        await link.send(routineCommitFrame(blocks));

        expect((await nack).reason, NackReason.routineCrc);
        expect(device.routine, isEmpty);
      },
    );

    test('BLOCK without BEGIN is a sequence NACK', () async {
      link = build();
      await link.connect();
      final nack = link.nacks.first;
      await link.send(
        WireBlock(name: 'Orphan', durationMin: 5, category: 0).toFrame(0),
      );
      expect((await nack).reason, NackReason.routineSequence);
      expect(device.routine, isEmpty);
    });

    test(
      'a routine longer than the device holds is refused before sending',
      () async {
        link = build();
        await link.connect();
        final tooMany = <WireBlock>[
          for (var i = 0; i < 20; i++)
            WireBlock(name: 'B$i', durationMin: 10, category: 0),
        ];
        final result = await link.pushRoutine(tooMany);
        expect(result.ok, isFalse);
        expect(result.detail, contains('16'));
        expect(device.routine, isEmpty);
      },
    );

    test('a device that declares a smaller EEPROM is respected', () async {
      // max_blocks is read from the device, never assumed.
      link = build(config: const SimulatedDeviceConfig(maxBlocks: 2));
      await link.connect();
      expect(link.maxBlocks, 2);
      expect((await link.pushRoutine(sampleRoutine())).ok, isFalse);
    });
  });

  group('logs', () {
    test('pulls the ring buffer and stops on the quiet gap', () async {
      // The stream has no terminator: the device sends what it has, which may
      // be fewer days than asked for.
      link = build();
      device.seedLogs(<DeviceLogEntry>[
        for (var i = 0; i < 5; i++)
          DeviceLogEntry(
            dateCode: 200 + i,
            verifiedMin: 60 * i,
            claimedMin: 70 * i,
            blocksDone: i,
            blocksTotal: 8,
            violations: 0,
          ),
      ]);
      await link.connect();

      final logs = await link.fetchLogs(30);
      expect(logs, hasLength(5));
      expect(
        logs.first.day,
        DeviceLogEntry.epoch.add(const Duration(days: 200)),
      );
      expect(logs.last.verifiedMin, 240);
    });

    test('an empty device returns an empty history, not an error', () async {
      link = build();
      await link.connect();
      expect(await link.fetchLogs(30), isEmpty);
    });

    test(
      'asking for more days than the device holds returns what it has',
      () async {
        link = build();
        device.seedLogs(<DeviceLogEntry>[
          for (var i = 0; i < 3; i++)
            DeviceLogEntry(
              dateCode: i,
              verifiedMin: 10,
              claimedMin: 10,
              blocksDone: 1,
              blocksTotal: 1,
              violations: 0,
            ),
        ]);
        await link.connect();
        expect(await link.fetchLogs(30), hasLength(3));
      },
    );
  });

  group('status mirror', () {
    test('CONTROL start runs a block and the status reflects it', () async {
      link = build();
      await link.connect();
      await link.pushRoutine(sampleRoutine());

      await link.control(ControlAction.start, arg: 0);
      final status = await link.requestStatus();
      expect(status.state, DeviceRunState.running);
      expect(status.blockIdx, 0);
      expect(status.secsLeft, 90 * 60);
      expect(status.trackEnabled, isTrue);
    });

    test('pause freezes the timer and moves the mood to searching', () async {
      link = build();
      await link.connect();
      await link.pushRoutine(sampleRoutine());
      await link.control(ControlAction.start, arg: 0);

      device.advance(const Duration(minutes: 10));
      await link.control(ControlAction.pause);
      final paused = await link.requestStatus();
      expect(paused.state, DeviceRunState.paused);
      expect(paused.mood, DeviceMood.searching);

      final secs = paused.secsLeft;
      device.advance(const Duration(minutes: 5));
      expect((await link.requestStatus()).secsLeft, secs);
    });

    test('verified minutes only accrue while the factors hold', () async {
      link = build();
      await link.connect();
      await link.pushRoutine(sampleRoutine());
      await link.control(ControlAction.start, arg: 0);
      link.setTracking(tracking: true, phoneLocked: true);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      device.advance(const Duration(minutes: 10));
      var status = await link.requestStatus();
      expect(status.claimedToday, 10);
      expect(status.verifiedToday, 10);

      device.present = false; // the chair is empty
      device.advance(const Duration(minutes: 10));
      status = await link.requestStatus();
      expect(status.claimedToday, 20, reason: 'claimed keeps counting');
      expect(status.verifiedToday, 10, reason: 'verified does not');
      expect(status.deviceVerified, isFalse);
    });

    test('an untracked block claims nothing at all', () async {
      link = build();
      await link.connect();
      await link.pushRoutine(sampleRoutine());
      await link.control(ControlAction.start, arg: 1); // Break, untracked

      device.advance(const Duration(minutes: 10));
      final status = await link.requestStatus();
      expect(status.trackEnabled, isFalse);
      expect(status.claimedToday, 0);
      expect(status.verifiedToday, 0);
    });

    test('statuses reach the stream, not only the awaited reply', () async {
      link = build();
      await link.connect();
      link.stopPolling();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final seen = <DeviceStatus>[];
      final sub = link.statuses.listen(seen.add);

      await link.requestStatus();
      await link.requestStatus();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(seen, hasLength(2));
      expect(link.lastStatus, isNotNull);
    });
  });

  group('heartbeat', () {
    test('runs only while a tracked block is running', () async {
      link = build();
      await link.connect();
      expect(device.lastHeartbeatAt, isNull);

      link.setTracking(tracking: true, phoneLocked: true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(device.lastHeartbeatAt, isNotNull);
      expect(device.phoneLocked, isTrue);

      link.setTracking(tracking: false, phoneLocked: false);
      final at = device.lastHeartbeatAt;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(device.lastHeartbeatAt, at, reason: 'the radio goes quiet');
    });

    test(
      'carries the screen-lock state the device cannot see itself',
      () async {
        link = build();
        await link.connect();
        link.setTracking(tracking: true, phoneLocked: false);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(device.phoneLocked, isFalse);
      },
    );
  });

  group('robustness', () {
    test('an unknown command is ignored, and the link keeps working', () async {
      // Forward compatibility: a newer app talking to older firmware degrades
      // rather than failing.
      link = build();
      await link.connect();
      await link.send(Frame(0x9E, <int>[1, 2, 3]));
      expect((await link.requestStatus()).state, DeviceRunState.idle);
    });

    test('a malformed reply is logged, not thrown', () async {
      final lines = <String>[];
      device = SimulatedDevice();
      transport = LoopbackTransport(device: device, latency: Duration.zero);
      link = DeviceLink(
        transport,
        statusPoll: const Duration(seconds: 30),
        onWireLog: lines.add,
      );
      await transport.connect();
      await link.connect();

      // A STATUS frame that is well-framed but the wrong length.
      device.onSend?.call(Frame(FfCmd.status, <int>[1, 2, 3]).encode());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(lines.any((l) => l.contains('STATUS is 12 B')), isTrue);
      expect((await link.requestStatus()).state, DeviceRunState.idle);
    });

    test(
      'a NACK fails the outstanding request instead of timing out',
      () async {
        link = build();
        await link.connect();
        // CONTROL with a malformed payload: the device answers BAD_LENGTH.
        final nack = link.nacks.first;
        await link.send(Frame(FfCmd.control, <int>[9]));
        expect((await nack).reason, NackReason.badLength);
      },
    );

    test('disconnect stops the timers and the link goes quiet', () async {
      link = build();
      await link.connect();
      link.setTracking(tracking: true, phoneLocked: true);
      await link.disconnect();

      final at = device.lastHeartbeatAt;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(device.lastHeartbeatAt, at);
      expect(transport.state, LinkState.disconnected);
    });
  });

  group('config', () {
    test(
      'CONFIG_SET reaches the device and unknown keys do not break it',
      () async {
        link = build();
        await link.connect();
        await link.setConfig(<ConfigKey, int>{
          ConfigKey.presenceMinCm: 20,
          ConfigKey.presenceMaxCm: 90,
          ConfigKey.gracePausedS: 300,
        });
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(device.config[ConfigKey.presenceMinCm], 20);
        expect(device.config[ConfigKey.presenceMaxCm], 90);
        expect(device.config[ConfigKey.gracePausedS], 300);
      },
    );
  });
}
