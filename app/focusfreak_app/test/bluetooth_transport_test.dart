import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/device/device_link.dart';
import 'package:focusfreak_app/device/protocol.dart';
import 'package:focusfreak_app/device/simulated_device.dart';
import 'package:focusfreak_app/device/transport/bluetooth_transport.dart';
import 'package:focusfreak_app/device/transport/transport.dart';
import 'package:focusfreak_app/platform/bluetooth_channel.dart';

/// A stand-in for `BtClassicPlugin.kt`: same surface, no radio.
///
/// It lets the Bluetooth transport's own logic — state transitions, an
/// unsolicited drop, a refused permission — be tested on a laptop, which is
/// the only place they will be exercised before demo day.
class FakeBluetoothChannel extends BluetoothChannel {
  FakeBluetoothChannel({this.device, this.failWith});

  /// When set, bytes written are fed to it and its replies come back.
  final SimulatedDevice? device;

  /// When set, [connect] throws this instead of succeeding.
  final BluetoothException? failWith;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<({String state, String? detail})> _events =
      StreamController<({String state, String? detail})>.broadcast();

  bool connected = false;
  int disconnectCalls = 0;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<({String state, String? detail})> get linkEvents => _events.stream;

  @override
  Future<BondedDevice> connect(String address) async {
    final failure = failWith;
    if (failure != null) throw failure;
    connected = true;
    device?.onSend = _incoming.add;
    return BondedDevice(name: 'FocusFreak', address: address);
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (!connected) throw const BluetoothException('io', 'not connected');
    device?.receive(bytes);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    connected = false;
  }

  /// The bot walking out of range, or its battery dying mid-session.
  void dropLink(String why) {
    connected = false;
    _events.add((state: 'disconnected', detail: why));
  }

  Future<void> close() async {
    await _incoming.close();
    await _events.close();
  }
}

void main() {
  test('reports its device in a form the UI can show', () {
    final transport = BluetoothTransport(
      address: '98:D3:31:F5:12:0A',
      name: 'FocusFreak',
      channel: FakeBluetoothChannel(),
    );
    expect(transport.description, 'FocusFreak · 98:D3:31:F5:12:0A');
    expect(transport.state, LinkState.disconnected);
  });

  test('drives a full handshake over the channel', () async {
    // The point of the Transport seam: DeviceLink cannot tell this from the
    // loopback, and will not be able to tell the real radio from either.
    final device = SimulatedDevice();
    final channel = FakeBluetoothChannel(device: device);
    final transport = BluetoothTransport(
      address: '00:11:22:33:44:55',
      name: 'HC-05',
      channel: channel,
    );
    final link = DeviceLink(transport, statusPoll: const Duration(seconds: 30));

    final ack = await link.connect();
    expect(ack.versionMatches, isTrue);
    expect(transport.state, LinkState.connected);
    expect(link.capabilities.has(DeviceCapability.presence), isTrue);

    await link.dispose();
    await channel.close();
  });

  test(
    'a refused permission fails the connection with a readable message',
    () async {
      final channel = FakeBluetoothChannel(
        failWith: const BluetoothException('permission', 'no permission'),
      );
      final transport = BluetoothTransport(
        address: 'x',
        name: 'HC-05',
        channel: channel,
      );

      await expectLater(
        transport.connect(),
        throwsA(isA<BluetoothException>()),
      );
      expect(transport.state, LinkState.failed);
      expect(transport.lastError, 'no permission');
      await channel.close();
    },
  );

  test('an unsolicited drop moves the link to disconnected', () async {
    // The bot leaving the desk mid-session. The app has to notice by itself:
    // nothing asked for this event.
    final device = SimulatedDevice();
    final channel = FakeBluetoothChannel(device: device);
    final transport = BluetoothTransport(
      address: 'x',
      name: 'FocusFreak',
      channel: channel,
    );
    await transport.connect();
    expect(transport.state, LinkState.connected);

    channel.dropLink('stream closed by the device');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(transport.state, LinkState.disconnected);
    expect(
      transport.lastError,
      isNull,
      reason: 'a drop is not a failed connect',
    );
    expect(
      () => transport.send(<int>[1, 2, 3]),
      throwsStateError,
      reason: 'sending into a dead socket must fail loudly',
    );
    await channel.close();
  });

  test('disconnect is idempotent enough to call on a dead link', () async {
    final channel = FakeBluetoothChannel(device: SimulatedDevice());
    final transport = BluetoothTransport(
      address: 'x',
      name: 'FocusFreak',
      channel: channel,
    );
    await transport.connect();
    await transport.disconnect();
    await transport.disconnect();

    expect(channel.disconnectCalls, 2);
    expect(transport.state, LinkState.disconnected);
    await channel.close();
  });

  test('a bonded device is recognised by either name', () {
    // The module ships as HC-05 and is renamed to FocusFreak with an AT
    // command. Both have to be offered, or a half-set-up bot looks invisible.
    expect(
      const BondedDevice(name: 'HC-05', address: 'a').looksLikeBot,
      isTrue,
    );
    expect(
      const BondedDevice(name: 'FocusFreak', address: 'a').looksLikeBot,
      isTrue,
    );
    expect(
      const BondedDevice(name: 'Galaxy Buds', address: 'a').looksLikeBot,
      isFalse,
    );
    // HC-05 clones ship under other factory names too.
    for (final name in <String>[
      'Focus Freak',
      'Focus_Freak',
      'FocusFreak-1a2b',
      'HC-06',
      'HC05',
      'JDY-31-SPP',
      'BT04-A',
      'linvor',
    ]) {
      expect(
        BondedDevice(name: name, address: 'a').looksLikeBot,
        isTrue,
        reason: name,
      );
    }
  });
}
