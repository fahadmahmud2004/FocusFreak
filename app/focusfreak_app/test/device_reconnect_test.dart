import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/device/simulated_device.dart';
import 'package:focusfreak_app/device/transport/transport.dart';
import 'package:focusfreak_app/features/bot/device_mirror.dart';
import 'package:focusfreak_app/device/device_verification_source.dart';
import 'package:focusfreak_app/features/device/device_controller.dart';
import 'package:focusfreak_app/platform/bluetooth_channel.dart';

/// Connecting the way a Bluetooth speaker connects.
///
/// The promise this file protects: **turn the bot on, tap it once, and never
/// think about it again.** That means three things have to hold — pairing is
/// part of the tap and not a separate trip to Android settings, a bot that
/// drops out comes back on its own, and a bot the user deliberately disconnects
/// stays disconnected.
///
/// The last one is the easiest to get wrong and the worst to live with: an app
/// that reconnects after you told it not to is one you cannot put down.
class ScanningBluetoothChannel extends BluetoothChannel {
  ScanningBluetoothChannel({this.device});

  final SimulatedDevice? device;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<({String state, String? detail})> _events =
      StreamController<({String state, String? detail})>.broadcast();
  final StreamController<DiscoveryEvent> _discovery =
      StreamController<DiscoveryEvent>.broadcast();

  bool connected = false;
  bool enabled = true;
  bool permitted = true;

  /// Addresses passed to [bond], in order. A bot that is already bonded must
  /// not be bonded again.
  final List<String> bonds = <String>[];
  final List<String> connects = <String>[];

  /// What [bondedDevices] reports — the phone's pairing list.
  List<BondedDevice> paired = <BondedDevice>[];

  /// Set to make every [connect] fail, standing in for a bot that is switched
  /// off while the app keeps trying.
  bool refuseConnections = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<({String state, String? detail})> get linkEvents => _events.stream;

  @override
  Stream<DiscoveryEvent> get discoveryEvents => _discovery.stream;

  @override
  Future<bool> get isSupported async => true;

  @override
  Future<bool> get isEnabled async => enabled;

  @override
  Future<bool> get hasPermissions async => permitted;

  @override
  Future<bool> requestEnable() async => enabled;

  @override
  Future<bool> requestPermissions() async => permitted;

  @override
  Future<List<BondedDevice>> bondedDevices() async => paired;

  @override
  Future<bool> startDiscovery() async => true;

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<void> bond(String address) async => bonds.add(address);

  @override
  Future<BondedDevice> connect(String address) async {
    connects.add(address);
    if (refuseConnections) {
      throw const BluetoothException('io', 'The bot did not answer.');
    }
    connected = true;
    device?.onSend = _incoming.add;
    return BondedDevice(name: 'FocusFreak-A3F2', address: address);
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (!connected) throw const BluetoothException('io', 'not connected');
    device?.receive(bytes);
  }

  @override
  Future<void> disconnect() async => connected = false;

  void found(BondedDevice device) => _discovery.add(DeviceFound(device));

  void finishScan() => _discovery.add(const DiscoveryFinished());

  /// The bot walking out of range, or its battery dying mid-block.
  void dropLink() {
    connected = false;
    _events.add((state: 'disconnected', detail: 'out of range'));
  }

  Future<void> close() async {
    await _incoming.close();
    await _events.close();
    await _discovery.close();
  }
}

void main() {
  late ScanningBluetoothChannel channel;
  late DeviceVerificationSource verification;
  late DeviceMirror mirror;
  late List<String?> remembered;
  late List<Duration> waits;

  /// Builds a controller whose backoff does not actually wait.
  ///
  /// The delays are recorded instead, so the schedule can be asserted without
  /// a test that takes 52 seconds to run.
  DeviceController build() {
    remembered = <String?>[];
    waits = <Duration>[];
    return DeviceController(
      verification,
      mirror,
      channel,
      delay: (d) async => waits.add(d),
      onRemember: remembered.add,
    );
  }

  setUp(() {
    channel = ScanningBluetoothChannel(device: SimulatedDevice());
    verification = DeviceVerificationSource();
    mirror = DeviceMirror();
  });

  tearDown(() async {
    await channel.close();
    await verification.dispose();
  });

  const bot = BondedDevice(
    name: 'FocusFreak-A3F2',
    address: '00:11:22:33:44:55',
  );
  const bondedBot = BondedDevice(
    name: 'FocusFreak-A3F2',
    address: '00:11:22:33:44:55',
    bonded: true,
  );

  group('finding a bot', () {
    test('a scan lists bots and ignores everything else', () async {
      final controller = build();
      await controller.scan();

      channel.found(bot);
      // A scan in a café turns up thirty earbuds, and every one of them is a
      // way for someone to pick the wrong thing.
      channel.found(
        const BondedDevice(name: 'JBL GO 3', address: 'AA:BB:CC:DD:EE:FF'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.found, <BondedDevice>[bot]);
      controller.dispose();
    });

    test('an already-paired bot sorts above one merely in range', () async {
      final controller = build();
      await controller.scan();

      channel.found(
        const BondedDevice(
          name: 'FocusFreak-0001',
          address: '11:11:11:11:11:11',
        ),
      );
      channel.found(bondedBot);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.found.first.address, bondedBot.address);
      controller.dispose();
    });

    test('the scan ending clears the spinner', () async {
      final controller = build();
      await controller.scan();
      expect(controller.state.scanning, isTrue);

      channel.finishScan();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.scanning, isFalse);
      controller.dispose();
    });
  });

  group('one tap', () {
    test('pairs and connects in a single action', () async {
      final controller = build();
      await controller.connectBluetooth(bot);

      // The whole point: no trip to Android settings, no PIN typed. The bond
      // happens inside the tap that asked to use the bot.
      expect(channel.bonds, <String>[bot.address]);
      expect(controller.state.isConnected, isTrue);
      await controller.disconnect();
      controller.dispose();
    });

    test('does not re-pair a bot the phone already knows', () async {
      final controller = build();
      await controller.connectBluetooth(bondedBot);

      expect(channel.bonds, isEmpty);
      expect(controller.state.isConnected, isTrue);
      await controller.disconnect();
      controller.dispose();
    });

    test('remembers the bot it connected to', () async {
      final controller = build();
      await controller.connectBluetooth(bot);

      expect(remembered, <String?>[bot.address]);
      await controller.disconnect();
      controller.dispose();
    });
  });

  group('coming back on its own', () {
    test('a bot that drops out is reconnected without being asked', () async {
      final controller = build();
      channel.paired = <BondedDevice>[bondedBot];
      await controller.connectBluetooth(bot);
      expect(controller.state.isConnected, isTrue);

      channel.dropLink();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        channel.connects.length,
        greaterThan(1),
        reason: 'the app should try to get the bot back by itself',
      );
      controller.dispose();
    });

    test('the backoff rises and is capped', () async {
      final controller = build();
      channel.paired = <BondedDevice>[bondedBot];
      channel.refuseConnections = true;

      await controller.reconnectLast(bot.address);

      // Rising rather than fixed, and capped rather than unbounded: a bot
      // switched off should cost a retry every half minute, not one every two
      // seconds until the battery is flat.
      expect(waits, <Duration>[
        const Duration(seconds: 2),
        const Duration(seconds: 5),
        const Duration(seconds: 15),
        const Duration(seconds: 30),
      ]);
      expect(
        controller.state.reconnecting,
        isFalse,
        reason: 'giving up has to clear the indicator',
      );
      controller.dispose();
    });

    test('a silent failure never raises an error banner', () async {
      final controller = build();
      channel.paired = <BondedDevice>[bondedBot];
      channel.refuseConnections = true;

      await controller.reconnectLast(bot.address);

      // Nobody asked for this attempt, so nobody should be told it failed. A
      // phone carried away from its desk is the ordinary case.
      expect(controller.state.error, isNull);
      controller.dispose();
    });

    test('nothing is attempted when no bot was ever remembered', () async {
      final controller = build();
      await controller.reconnectLast(null);
      await controller.reconnectLast('');

      expect(channel.connects, isEmpty);
      controller.dispose();
    });

    test(
      'nothing is attempted when the phone is no longer paired with it',
      () async {
        final controller = build();
        channel.paired = <BondedDevice>[];

        await controller.reconnectLast(bot.address);

        // The user unpaired it in system settings. Silently re-pairing would be
        // undoing a decision they made.
        expect(channel.connects, isEmpty);
        controller.dispose();
      },
    );
  });

  group('disconnecting is sticky', () {
    test('a deliberate disconnect is not undone by the reconnect', () async {
      final controller = build();
      channel.paired = <BondedDevice>[bondedBot];
      await controller.connectBluetooth(bot);
      final connectsBefore = channel.connects.length;

      await controller.disconnect();
      channel.dropLink();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        channel.connects.length,
        connectsBefore,
        reason:
            'an app that reconnects after you said stop is one you '
            'cannot put down',
      );
      expect(controller.state.link, LinkState.disconnected);
      controller.dispose();
    });

    test(
      'and it forgets the bot, so the next launch does not reconnect',
      () async {
        final controller = build();
        await controller.connectBluetooth(bot);
        await controller.disconnect();

        expect(remembered, <String?>[bot.address, null]);
        controller.dispose();
      },
    );

    test('disconnecting the virtual bot does not forget the real one', () async {
      final controller = build();
      await controller.connectVirtual(latency: Duration.zero);
      await controller.disconnect();

      // The virtual bot has no address, and erasing the real bot on the desk
      // because someone tried the demo would be a bug you only notice the next
      // morning.
      expect(remembered, isEmpty);
      controller.dispose();
    });
  });
}
