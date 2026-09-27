/// The byte pipe under the protocol.
///
/// `docs/PROTOCOL.md` §1: *the transport is not part of the contract*. The same
/// frames run over HC-05 Bluetooth Classic, over an HM-10 (BLE), over TCP to
/// the desktop simulator, and over an in-process loopback. Everything above
/// this interface is written once and never learns which one it got.
library;

import 'dart:async';
import 'dart:typed_data';

/// Link lifecycle, kept deliberately small.
///
/// There is no `reconnecting` state: a reconnect is a [connecting] that the app
/// started rather than the user, and the UI has no reason to say it differently.
enum LinkState { disconnected, connecting, connected, failed }

/// A bidirectional byte stream to a bot.
abstract class Transport {
  /// Shown in the UI and written into the wire log — "HC-05 · 98:D3:31:…",
  /// "Loopback (virtual bot)", "Simulator 127.0.0.1:5600".
  String get description;

  /// Bytes as they arrive, in whatever chunk sizes the radio produced. Chunk
  /// boundaries are meaningless; the parser reassembles frames.
  Stream<Uint8List> get incoming;

  Stream<LinkState> get states;
  LinkState get state;

  /// The reason the last connection attempt failed, for the UI to show. Null
  /// unless [state] is [LinkState.failed].
  String? get lastError;

  Future<void> connect();
  Future<void> send(List<int> data);
  Future<void> disconnect();
  Future<void> dispose();
}

/// Shared plumbing: state broadcasting, and one place that guarantees the
/// state stream and [state] can never disagree.
abstract class BaseTransport implements Transport {
  final StreamController<Uint8List> incomingController =
      StreamController<Uint8List>.broadcast();
  final StreamController<LinkState> stateController =
      StreamController<LinkState>.broadcast();

  LinkState _state = LinkState.disconnected;
  String? _lastError;

  @override
  Stream<Uint8List> get incoming => incomingController.stream;

  @override
  Stream<LinkState> get states => stateController.stream;

  @override
  LinkState get state => _state;

  @override
  String? get lastError => _lastError;

  void setState(LinkState next, {String? error}) {
    _lastError = next == LinkState.failed ? error : null;
    if (_state == next) return;
    _state = next;
    if (!stateController.isClosed) stateController.add(next);
  }

  void emit(List<int> bytes) {
    if (!incomingController.isClosed) {
      incomingController.add(Uint8List.fromList(bytes));
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await incomingController.close();
    await stateController.close();
  }
}
