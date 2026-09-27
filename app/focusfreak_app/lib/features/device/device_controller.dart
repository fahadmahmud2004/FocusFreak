/// Connecting to a bot, and everything the connection screen needs to know.
///
/// One controller owns the live [DeviceLink]; the rest of the app reads its
/// state. Which transport is underneath — a real HC-05 or the in-process
/// virtual bot — changes nothing above this file, which is what lets the whole
/// device UI be built and demonstrated with no hardware.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../data/repo/settings_repository.dart';
import '../../device/device_link.dart';
import '../../device/device_verification_source.dart';
import '../../device/protocol.dart';
import '../../device/simulated_device.dart';
import '../../device/transport/bluetooth_transport.dart';
import '../../device/transport/loopback_transport.dart';
import '../../device/transport/transport.dart';
import '../../platform/bluetooth_channel.dart';
import '../bot/device_mirror.dart';

/// Which kind of bot is on the other end.
enum DeviceKind {
  /// The in-process virtual bot. Real frames, real sequence rules, no radio.
  virtual,

  /// A paired HC-05.
  bluetooth,
}

/// Everything the connection screen renders.
class DeviceConnectionState {
  const DeviceConnectionState({
    this.link = LinkState.disconnected,
    this.kind,
    this.label,
    this.ack,
    this.status,
    this.error,
    this.busy = false,
    this.wireLog = const <String>[],
    this.found = const <BondedDevice>[],
    this.scanning = false,
    this.pairingAddress,
    this.reconnecting = false,
  });

  final LinkState link;
  final DeviceKind? kind;

  /// What to call this bot on screen.
  final String? label;

  /// What the device declared at HELLO_ACK. Null until the handshake lands.
  final HelloAck? ack;

  /// The most recent `0xB0 STATUS`.
  final DeviceStatus? status;

  final String? error;

  /// True while a connect, push or pull is in flight.
  final bool busy;

  /// The last frames in both directions, newest last. Kept in memory only.
  final List<String> wireLog;

  /// Bots the scan has turned up, already-paired ones included. One list on
  /// purpose: a customer should not have to know what "bonded" means.
  final List<BondedDevice> found;

  final bool scanning;

  /// The bot currently being paired with, so its row alone shows a spinner.
  final String? pairingAddress;

  /// A silent reconnect is in flight after the bot dropped out. Distinct from
  /// [busy], which means the user is waiting on something they asked for.
  final bool reconnecting;

  bool get isConnected => link == LinkState.connected;

  DeviceCapabilities get capabilities =>
      ack?.capabilities ?? const DeviceCapabilities.none();

  DeviceConnectionState copyWith({
    LinkState? link,
    DeviceKind? kind,
    String? label,
    HelloAck? ack,
    DeviceStatus? status,
    String? error,
    bool? busy,
    List<String>? wireLog,
    List<BondedDevice>? found,
    bool? scanning,
    String? pairingAddress,
    bool? reconnecting,
    bool clearError = false,
    bool clearDevice = false,
    bool clearPairing = false,
  }) => DeviceConnectionState(
    link: link ?? this.link,
    kind: clearDevice ? null : (kind ?? this.kind),
    label: clearDevice ? null : (label ?? this.label),
    ack: clearDevice ? null : (ack ?? this.ack),
    status: clearDevice ? null : (status ?? this.status),
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
    wireLog: wireLog ?? this.wireLog,
    found: found ?? this.found,
    scanning: scanning ?? this.scanning,
    pairingAddress: clearPairing
        ? null
        : (pairingAddress ?? this.pairingAddress),
    reconnecting: reconnecting ?? this.reconnecting,
  );
}

/// How a routine push ended, in words for the UI.
class PushReport {
  const PushReport(this.ok, this.message);
  final bool ok;
  final String message;
}

class DeviceController extends StateNotifier<DeviceConnectionState> {
  DeviceController(
    this._verification,
    this._mirror,
    this._bluetooth, {
    Future<void> Function(Duration) delay = _wait,
    this.onRemember,
  }) : _delay = delay,
       super(const DeviceConnectionState());

  static Future<void> _wait(Duration d) => Future<void>.delayed(d);

  /// Injected so reconnect tests do not have to wait real seconds.
  final Future<void> Function(Duration) _delay;

  /// Called with the address of a bot that connected, or null when the user
  /// deliberately disconnects. Persists to `SettingKey.lastDeviceAddress`.
  final void Function(String? address)? onRemember;

  /// The source that the session's composite already holds. Connecting
  /// re-points it rather than rebuilding it — rebuilding would discard a
  /// running session.
  final DeviceVerificationSource _verification;

  /// The Bot tab's other producer. Attaching it is what makes the tab show the
  /// bot on the desk instead of the simulated one.
  final DeviceMirror _mirror;

  final BluetoothChannel _bluetooth;

  static const int _wireLogLimit = 200;

  DeviceLink? _link;
  StreamSubscription<DeviceStatus>? _statusSub;
  StreamSubscription<LinkState>? _stateSub;
  StreamSubscription<DeviceNackException>? _nackSub;
  StreamSubscription<DiscoveryEvent>? _discoverySub;

  /// The bot to come back to. Null for the virtual bot, which has nothing to
  /// reconnect to, and cleared when the user disconnects on purpose.
  String? _reconnectAddress;

  /// Set by [disconnect] and cleared only when the user asks for a bot again.
  /// This is what stops a deliberate disconnect from being undone two seconds
  /// later by the drop handler.
  bool _userDisconnected = false;

  bool _reconnecting = false;

  DeviceLink? get link => _link;

  /// The virtual bot behind a [DeviceKind.virtual] connection, so the demo
  /// screen can flip its sensors and watch the app react.
  SimulatedDevice? get simulated => _simulated;
  SimulatedDevice? _simulated;

  // -- Connecting --------------------------------------------------------------

  /// Connects to the in-process virtual bot.
  ///
  /// Not a toy: it is the same protocol over a loopback, so a demo still works
  /// if the hardware dies on the day, and every device screen is developed
  /// against it.
  /// [latency] stands in for radio round-trip time. It is deliberate in the
  /// app — it makes the timeout and retry paths actually execute during
  /// development — and set to zero by widget tests, whose fake clock does not
  /// advance while a `Future` is awaited.
  Future<void> connectVirtual({Duration? latency}) async {
    final device = SimulatedDevice();
    _simulated = device;
    // There is nothing to reconnect to: the virtual bot is in this process,
    // and if it went away so did everything else.
    _reconnectAddress = null;
    _userDisconnected = false;
    await _connect(
      DeviceLink(
        LoopbackTransport(
          device: device,
          latency: latency ?? const Duration(milliseconds: 12),
        ),
        onWireLog: _log,
      ),
      DeviceKind.virtual,
      'Virtual bot',
    );
  }

  // -- Finding a bot -----------------------------------------------------------

  /// Looks for bots, and reports paired ones too.
  ///
  /// One list, deliberately. The distinction between "paired" and "in range"
  /// is Bluetooth's, not the user's, and a screen that made them choose which
  /// list to look in would be the settings trip this flow exists to remove.
  Future<void> scan() async {
    if (state.scanning) return;
    await _discoverySub?.cancel();

    if (!await _bluetooth.isEnabled) {
      // One tap to turn the radio on, rather than a dead end that says the
      // app cannot help.
      await _bluetooth.requestEnable();
      if (!await _bluetooth.isEnabled) return;
    }
    if (!await _bluetooth.hasPermissions) {
      await _bluetooth.requestPermissions();
      if (!await _bluetooth.hasPermissions) return;
    }

    state = state.copyWith(
      scanning: true,
      found: const <BondedDevice>[],
      clearError: true,
    );

    _discoverySub = _bluetooth.discoveryEvents.listen((event) {
      switch (event) {
        case DeviceFound(:final device):
          // Only bots from the scan: a café turns up thirty earbuds, and every
          // one is a way to pick the wrong thing. Devices already paired to
          // this phone stay, under the bots: someone who paired a module
          // renamed to anything at all can still pick it.
          if (!device.looksLikeBot && !device.bonded) return;
          final next = <BondedDevice>[
            for (final d in state.found)
              if (d.address != device.address) d,
            device,
          ]..sort(_byStrength);
          state = state.copyWith(found: next);
        case DiscoveryFinished():
          state = state.copyWith(scanning: false);
      }
    });

    try {
      await _bluetooth.startDiscovery();
    } on BluetoothException catch (e) {
      state = state.copyWith(scanning: false, error: e.message);
    }
  }

  /// Bots first, then paired, then strongest signal. The bot on your desk
  /// should be the one at the top of the list.
  static int _byStrength(BondedDevice a, BondedDevice b) {
    if (a.looksLikeBot != b.looksLikeBot) return a.looksLikeBot ? -1 : 1;
    if (a.bonded != b.bonded) return a.bonded ? -1 : 1;
    final ar = a.rssi, br = b.rssi;
    if (ar != null && br != null && ar != br) return br.compareTo(ar);
    return a.displayName.compareTo(b.displayName);
  }

  Future<void> stopScan() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _bluetooth.stopDiscovery();
    state = state.copyWith(scanning: false);
  }

  /// Pair if needed, then connect. One tap, one outcome.
  ///
  /// The two steps are not separate on screen because they are not separate to
  /// the user: they asked to use their bot. Pairing is answered on their behalf
  /// (`BtClassicPlugin.BOT_PIN`), so nothing in here shows a code.
  Future<void> connectBluetooth(BondedDevice device) async {
    _simulated = null;
    _userDisconnected = false;
    state = state.copyWith(pairingAddress: device.address, clearError: true);

    try {
      if (state.scanning) await stopScan();
      if (!device.bonded) await _bluetooth.bond(device.address);
    } on BluetoothException catch (e) {
      state = state.copyWith(error: e.message, busy: false, clearPairing: true);
      return;
    } finally {
      state = state.copyWith(clearPairing: true);
    }

    await _connect(
      DeviceLink(
        BluetoothTransport(
          address: device.address,
          name: device.displayName,
          channel: _bluetooth,
        ),
        onWireLog: _log,
      ),
      DeviceKind.bluetooth,
      device.displayName,
      address: device.address,
    );
  }

  // -- Coming back on its own --------------------------------------------------

  /// Reconnects to the bot this phone used last, without being asked.
  ///
  /// Called at launch. Silent by design: a failure here is not an error the
  /// user made, and a phone that has simply been carried away from its desk
  /// must not greet them with a warning about it.
  Future<void> reconnectLast(String? address) async {
    if (address == null || address.isEmpty) return;
    if (_link != null || _userDisconnected) return;
    if (!await _bluetooth.isSupported) return;
    if (!await _bluetooth.isEnabled) return;
    if (!await _bluetooth.hasPermissions) return;

    final bonded = await _bluetooth.bondedDevices();
    final match = bonded.where((d) => d.address == address).firstOrNull;
    if (match == null) return;

    _reconnectAddress = address;
    await _attemptReconnect(match, announce: false);
  }

  /// The backoff.
  ///
  /// Rising rather than fixed, and capped rather than unbounded: a bot that is
  /// switched off should cost a retry every half minute, not a retry every two
  /// seconds until the battery is flat.
  static const List<Duration> _backoff = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  Future<void> _attemptReconnect(
    BondedDevice device, {
    required bool announce,
  }) async {
    if (_reconnecting) return;
    _reconnecting = true;
    state = state.copyWith(reconnecting: true);

    try {
      for (var attempt = 0; attempt < _backoff.length; attempt++) {
        if (_userDisconnected || _link != null) return;
        await _delay(_backoff[attempt]);
        if (_userDisconnected || _link != null) return;

        await _connect(
          DeviceLink(
            BluetoothTransport(
              address: device.address,
              name: device.displayName,
              channel: _bluetooth,
            ),
            onWireLog: _log,
          ),
          DeviceKind.bluetooth,
          device.displayName,
          address: device.address,
          silent: !announce,
        );
        if (state.isConnected) return;
      }
    } finally {
      _reconnecting = false;
      state = state.copyWith(reconnecting: false);
    }
  }

  Future<void> _connect(
    DeviceLink link,
    DeviceKind kind,
    String label, {
    String? address,
    bool silent = false,
  }) async {
    await _closeLink();
    state = state.copyWith(
      link: LinkState.connecting,
      kind: kind,
      label: label,
      busy: !silent,
      clearError: true,
    );

    _link = link;
    _statusSub = link.statuses.listen(
      (status) => state = state.copyWith(status: status),
    );
    _stateSub = link.states.listen((linkState) {
      state = state.copyWith(link: linkState);
      if (linkState == LinkState.disconnected ||
          linkState == LinkState.failed) {
        // The bot walking out of range. Nothing asked for this, so the UI has
        // to hear about it from here — and then the app quietly tries to get
        // it back rather than leaving the user to notice and retap.
        state = state.copyWith(status: null, busy: false);
        _onUnexpectedDrop();
      }
    });
    _nackSub = link.nacks.listen(
      (nack) => state = state.copyWith(error: nack.message),
    );

    try {
      final ack = await link.connect();
      _verification.attach(link);
      _mirror.attach(link, deviceName: label);
      if (address != null) {
        _reconnectAddress = address;
        onRemember?.call(address);
      }
      state = state.copyWith(
        link: LinkState.connected,
        ack: ack,
        busy: false,
        clearError: true,
      );
    } on Object catch (e) {
      await _teardown();
      state = state.copyWith(
        link: LinkState.failed,
        busy: false,
        // A silent attempt is one nobody asked for. Reporting its failure
        // would mean an error banner appearing on its own, for something the
        // user never did.
        error: silent ? null : _describe(e),
        clearError: silent,
        clearDevice: true,
      );
    }
  }

  /// The bot dropped out without being asked to. Try to get it back.
  void _onUnexpectedDrop() {
    if (_userDisconnected || _reconnecting) return;
    final address = _reconnectAddress;
    if (address == null || state.kind != DeviceKind.bluetooth) return;

    unawaited(() async {
      await _teardown();
      final bonded = await _bluetooth.bondedDevices();
      final match = bonded.where((d) => d.address == address).firstOrNull;
      if (match == null) return;
      await _attemptReconnect(match, announce: false);
    }());
  }

  /// The user asked to stop, and that is sticky.
  ///
  /// Nothing here may reconnect afterwards: someone who taps Disconnect has
  /// not asked to be reconnected two seconds later, and an app that came back
  /// on its own would be one they could not put down.
  Future<void> disconnect() async {
    _userDisconnected = true;
    // Only forget a bot that was actually remembered. Disconnecting the
    // virtual one must not erase the real bot on the desk, and a disconnect
    // with nothing paired has nothing to forget.
    if (_reconnectAddress != null) {
      _reconnectAddress = null;
      onRemember?.call(null);
    }
    if (_link == null) return;
    await _teardown();
    state = state.copyWith(
      link: LinkState.disconnected,
      busy: false,
      reconnecting: false,
      clearDevice: true,
      clearError: true,
    );
  }

  Future<void> _teardown() async {
    // The verification source is detached *first*: for the moments between the
    // link dying and this finishing, the bot must not still be vouching.
    _verification.attach(null);
    // And the Bot tab goes back to the virtual engine rather than holding the
    // last frame of a bot that is no longer there.
    _mirror.attach(null);
    await _closeLink();
  }

  /// Drops the link without touching the reconnect intent.
  ///
  /// Split out from [_teardown] so that starting a fresh connection does not
  /// look like the user giving up on the old one.
  ///
  /// Returns early when there is no link, which is not just an optimisation:
  /// [connectVirtual] sets `_simulated` before calling `_connect`, and clearing
  /// it here on a first connection would leave the virtual bot's own controls
  /// with nothing to drive.
  Future<void> _closeLink() async {
    if (_link == null) return;
    await _statusSub?.cancel();
    await _stateSub?.cancel();
    await _nackSub?.cancel();
    _statusSub = null;
    _stateSub = null;
    _nackSub = null;
    final link = _link;
    _link = null;
    _simulated = null;
    await link?.dispose();
  }

  // -- Operations ---------------------------------------------------------------

  /// Pushes a routine's blocks to the device.
  ///
  /// Blocks past the device's capacity are **refused, not truncated**: silently
  /// dropping the last four blocks of someone's day would be a lie the app told
  /// itself.
  Future<PushReport> pushRoutine(List<Block> blocks) => pushWire(<WireBlock>[
    for (final b in blocks)
      WireBlock(
        name: b.name,
        description: b.description,
        durationMin: b.durationMin,
        category: b.category,
        trackEnabled: b.trackEnabled,
        startMin: b.startMin,
      ),
  ]);

  /// Pushes blocks already in wire form — what `RoutineDeviceSync` sends while
  /// a routine runs.
  Future<PushReport> pushWire(List<WireBlock> wire) async {
    final link = _link;
    if (link == null) return const PushReport(false, 'No bot is connected.');

    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await link.pushRoutine(wire);
      if (result.outcome == PushOutcome.committed) {
        unawaited(_mirror.refreshRoutine());
      }
      return switch (result.outcome) {
        PushOutcome.committed => PushReport(
          true,
          '${wire.length} blocks are on the bot.',
        ),
        PushOutcome.checksumFailed => PushReport(
          false,
          result.detail ??
              'The bot did not accept the routine. It kept the one it had.',
        ),
        PushOutcome.interrupted => PushReport(
          false,
          'The push did not finish. Nothing was changed on the bot.',
        ),
      };
    } on ProtocolException catch (e) {
      // Almost always a name or description longer than the fixed wire field.
      return PushReport(false, e.message);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> control(ControlAction action, {int arg = 0}) async {
    final link = _link;
    if (link == null) return;
    try {
      await link.control(action, arg: arg);
    } on Object catch (e) {
      state = state.copyWith(error: _describe(e));
    }
  }

  /// The bot's sensor readings, or null when no bot answers.
  Future<DeviceSensors?> readSensors() async {
    final link = _link;
    if (link == null || !link.capabilities.has(DeviceCapability.sensorFrame)) {
      return null;
    }
    try {
      return await link.requestSensors();
    } on Object {
      return null;
    }
  }

  /// Press a control on the bot. Fire and forget: the next frame shows it.
  Future<void> sendInput(int key) async {
    try {
      await _link?.sendInput(key);
    } on Object catch (e) {
      state = state.copyWith(error: _describe(e));
    }
  }

  Future<void> launch(int app, {int arg = 0}) async {
    try {
      await _link?.launch(app, arg: arg);
    } on Object catch (e) {
      state = state.copyWith(error: _describe(e));
    }
  }

  Future<void> refreshStatus() async {
    final link = _link;
    if (link == null) return;
    try {
      await link.requestStatus();
    } on Object catch (e) {
      state = state.copyWith(error: _describe(e));
    }
  }

  /// Pulls the device's day logs. The phone is the permanent archive, so this
  /// is worth doing before old days roll out of the 30-entry ring buffer.
  Future<List<DeviceLogEntry>> pullLogs() async {
    final link = _link;
    if (link == null) return const <DeviceLogEntry>[];
    state = state.copyWith(busy: true);
    try {
      return await link.fetchLogs();
    } on Object catch (e) {
      state = state.copyWith(error: _describe(e));
      return const <DeviceLogEntry>[];
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void clearWireLog() => state = state.copyWith(wireLog: const <String>[]);

  void _log(String line) {
    // Frames can still be arriving from the radio while the link is being torn
    // down, and a wire log is not worth a crash on the way out.
    if (!mounted) return;
    final next = <String>[...state.wireLog, line];
    state = state.copyWith(
      wireLog: next.length > _wireLogLimit
          ? next.sublist(next.length - _wireLogLimit)
          : next,
    );
  }

  String _describe(Object error) => switch (error) {
    BluetoothException e => e.message,
    DeviceNackException e => e.message,
    DeviceTimeoutException _ =>
      'The bot did not answer. Check it is powered and in range.',
    ProtocolException e => e.message,
    StateError e => e.message,
    _ => error.toString(),
  };

  @override
  void dispose() {
    _userDisconnected = true;
    unawaited(_discoverySub?.cancel());
    unawaited(_teardown());
    super.dispose();
  }
}

// -- Providers ---------------------------------------------------------------

final bluetoothChannelProvider = Provider<BluetoothChannel>(
  (ref) => BluetoothChannel(),
);

final deviceControllerProvider =
    StateNotifierProvider<DeviceController, DeviceConnectionState>((ref) {
      return DeviceController(
        ref.watch(deviceVerificationSourceProvider),
        ref.watch(deviceMirrorProvider.notifier),
        ref.watch(bluetoothChannelProvider),
        // Read inside the callback, not watched here: watching would build the
        // database the moment anything looked at this provider, including in the
        // pure-Dart tests that have no binding to build it with.
        onRemember: (address) => unawaited(
          ref
              .read(settingsRepositoryProvider)
              .setString(SettingKey.lastDeviceAddress, address ?? ''),
        ),
      );
    });

/// Reconnects to the last bot at launch, without being asked.
///
/// Watched by the app shell, so it runs once for the life of the app rather
/// than every time the device screen is opened. Everything it does is silent:
/// a bot that is switched off or out of range is the ordinary case, not a
/// failure worth telling anyone about.
final deviceAutoConnectProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);

  // The virtual bot is remembered the same way a real one is: connecting it
  // keeps it for next time, disconnecting it on purpose forgets it.
  ref.listen<DeviceConnectionState>(deviceControllerProvider, (prev, next) {
    final wasVirtual =
        prev != null && prev.isConnected && prev.kind == DeviceKind.virtual;
    final isVirtual = next.isConnected && next.kind == DeviceKind.virtual;
    if (isVirtual && !wasVirtual) {
      unawaited(settings.setBool(SettingKey.useVirtualBot, true));
    } else if (next.isConnected && next.kind == DeviceKind.bluetooth) {
      unawaited(settings.setBool(SettingKey.useVirtualBot, false));
    } else if (wasVirtual && next.link == LinkState.disconnected) {
      unawaited(settings.setBool(SettingKey.useVirtualBot, false));
    }
  });

  final controller = ref.read(deviceControllerProvider.notifier);
  final address = await settings.getString(SettingKey.lastDeviceAddress);
  if (address.isNotEmpty) await controller.reconnectLast(address);
  if (ref.read(deviceControllerProvider).isConnected) return;
  if (await settings.getBool(SettingKey.useVirtualBot)) {
    await controller.connectVirtual();
  }
});

/// A real bot, over Bluetooth. The virtual bot does not count: it is the
/// app's own BotOS, so with it connected the phone still plays the sound and
/// runs the timer.
final realBotConnectedProvider = Provider<bool>(
  (ref) => ref.watch(
    deviceControllerProvider.select(
      (s) => s.isConnected && s.kind == DeviceKind.bluetooth,
    ),
  ),
);

/// Any bot, real or virtual. The Bot tab asks for one until this is true.
final botConnectedProvider = Provider<bool>(
  (ref) => ref.watch(deviceControllerProvider.select((s) => s.isConnected)),
);

/// Whether this build can talk Bluetooth at all — false on web and macOS,
/// where the plugin does not exist.
final bluetoothAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(bluetoothChannelProvider).isSupported,
);

/// Routines, for the push screen.
final pushableRoutinesProvider = Provider<AsyncValue<List<Routine>>>(
  (ref) => ref.watch(routinesProvider),
);
