/// The real link: Bluetooth Classic SPP to an HC-05.
///
/// The same [Transport] interface the loopback implements, so everything above
/// it — [DeviceLink], the verification source, the UI — is already written and
/// already tested by the time hardware arrives.
library;

import 'dart:async';
import 'dart:typed_data';

import '../../platform/bluetooth_channel.dart';
import 'transport.dart';

class BluetoothTransport extends BaseTransport {
  BluetoothTransport({
    required this.address,
    required this.name,
    BluetoothChannel? channel,
  }) : _channel = channel ?? BluetoothChannel();

  final String address;
  final String name;
  final BluetoothChannel _channel;

  StreamSubscription<Uint8List>? _bytesSub;
  StreamSubscription<({String state, String? detail})>? _eventSub;

  @override
  String get description => '$name · $address';

  @override
  Future<void> connect() async {
    setState(LinkState.connecting);
    try {
      await _channel.connect(address);
      _bytesSub ??= _channel.incoming.listen(emit);
      // The bot leaving the desk, the module losing power, the phone walking
      // out of range: all arrive here, and all mean the same thing to the app.
      _eventSub ??= _channel.linkEvents.listen((event) {
        if (event.state == 'disconnected') {
          setState(LinkState.disconnected, error: event.detail);
        }
      });
      setState(LinkState.connected);
    } on BluetoothException catch (e) {
      setState(LinkState.failed, error: e.message);
      rethrow;
    }
  }

  @override
  Future<void> send(List<int> data) async {
    if (state != LinkState.connected) {
      throw StateError('send on a ${state.name} Bluetooth link');
    }
    await _channel.write(Uint8List.fromList(data));
  }

  @override
  Future<void> disconnect() async {
    await _bytesSub?.cancel();
    _bytesSub = null;
    await _eventSub?.cancel();
    _eventSub = null;
    try {
      await _channel.disconnect();
    } on BluetoothException {
      // Disconnecting a link that is already gone is not an error worth
      // surfacing — the desired state is reached either way.
    }
    setState(LinkState.disconnected);
  }
}
