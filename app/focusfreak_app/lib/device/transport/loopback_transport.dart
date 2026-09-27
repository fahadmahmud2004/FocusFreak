/// An in-process link to a [SimulatedDevice].
///
/// The entire device UI is built against this: pairing screen, connect flow,
/// routine push, mirrored status, log merge, NACK handling. When the hardware
/// arrives, the Bluetooth transport replaces this one and nothing above it
/// changes — and if the bot dies on demo day, the app still demonstrates every
/// screen.
library;

import 'dart:async';
import 'dart:typed_data';

import '../simulated_device.dart';
import 'transport.dart';

class LoopbackTransport extends BaseTransport {
  LoopbackTransport({
    SimulatedDevice? device,
    this.latency = const Duration(milliseconds: 12),
    this.chunkSize = 0,
  }) : device = device ?? SimulatedDevice() {
    this.device.onSend = _fromDevice;
  }

  /// The bot on the other end. Exposed so a demo screen can flip its sensors.
  final SimulatedDevice device;

  /// Stands in for radio round-trip time. Not cosmetic: it is what makes the
  /// app's own timeout and retry paths actually execute during development
  /// instead of always resolving within the same microtask.
  final Duration latency;

  /// When > 0, replies are delivered in fragments of this size.
  ///
  /// Real HC-05 reads split frames at arbitrary offsets. Setting this to 1 in a
  /// test is the cheapest way to prove the parser does not assume one read
  /// equals one frame.
  final int chunkSize;

  final List<Timer> _pending = <Timer>[];

  @override
  String get description => 'Loopback (virtual bot)';

  @override
  Future<void> connect() async {
    setState(LinkState.connecting);
    await Future<void>.delayed(latency);
    setState(LinkState.connected);
  }

  @override
  Future<void> send(List<int> data) async {
    if (state != LinkState.connected) {
      throw StateError('send on a ${state.name} loopback');
    }
    _schedule(() => device.receive(data));
  }

  void _fromDevice(Uint8List bytes) {
    if (chunkSize <= 0) {
      _schedule(() => emit(bytes));
      return;
    }
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(i, end);
      _schedule(() => emit(chunk));
    }
  }

  void _schedule(void Function() action) {
    if (latency == Duration.zero) {
      scheduleMicrotask(action);
      return;
    }
    late Timer timer;
    timer = Timer(latency, () {
      _pending.remove(timer);
      action();
    });
    _pending.add(timer);
  }

  @override
  Future<void> disconnect() async {
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
    setState(LinkState.disconnected);
  }
}
