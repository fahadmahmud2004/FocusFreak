/// The thin Dart side of `BtClassicPlugin.kt`.
///
/// Nothing here knows about frames or the protocol — it moves bytes and
/// reports link events. Everything above it is written once and runs the same
/// over Bluetooth, over the desktop simulator, and over the loopback.
library;

import 'dart:async';

import 'package:flutter/services.dart';

/// A phone-side view of a Bluetooth device, paired or merely seen.
class BondedDevice {
  const BondedDevice({
    required this.name,
    required this.address,
    this.type = 0,
    this.bonded = false,
    this.rssi,
  });

  final String name;
  final String address;
  final int type;

  /// Whether the phone has already paired with it. A returning user's bot is
  /// bonded and will never appear in a scan, which is why both go in one list.
  final bool bonded;

  /// Signal strength, when a scan reported one. Used only for ordering: the
  /// bot on your desk should be above the one on the desk behind you.
  final int? rssi;

  /// Bots advertise as `FocusFreak-XXXX` once provisioned
  /// (`docs/BOT_PROVISIONING.md`), or under the serial module's factory name
  /// if it was never renamed. HC-05 clones ship under several: `HC-05`,
  /// `HC05`, `HC-06`, `JDY-31-SPP`, `BT04-A`, `linvor`, `H-C-2010-06-01`.
  ///
  /// Spaces, dashes and underscores are ignored, so a module renamed
  /// `Focus Freak` or `Focus_Freak` is found as well as `FocusFreak-1234`.
  bool get looksLikeBot {
    final key = name.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
    return _botNames.any(key.contains);
  }

  static const List<String> _botNames = <String>[
    'focusfreak',
    'hc05',
    'hc06',
    'jdy',
    'bt04',
    'linvor',
    'hc2010',
    'zs040',
  ];

  /// What to show when the radio gave an address but no name yet.
  String get displayName => name.isEmpty ? 'Unknown device' : name;

  static BondedDevice fromMap(Map<Object?, Object?> raw) => BondedDevice(
    name: raw['name'] as String? ?? '',
    address: raw['address'] as String? ?? '',
    type: raw['type'] as int? ?? 0,
    bonded: raw['bonded'] == true,
    rssi: raw['rssi'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is BondedDevice && other.address == address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => '$displayName ($address)';
}

/// Something that happened during a scan.
sealed class DiscoveryEvent {
  const DiscoveryEvent();
}

/// A device came into view, or a bonded one was replayed at the start.
class DeviceFound extends DiscoveryEvent {
  const DeviceFound(this.device);
  final BondedDevice device;
}

/// The scan ended, whether it timed out or was stopped.
class DiscoveryFinished extends DiscoveryEvent {
  const DiscoveryFinished();
}

/// Why a Bluetooth call failed, in words a user can act on.
class BluetoothException implements Exception {
  const BluetoothException(this.code, this.message);

  final String code;
  final String message;

  /// Maps the plugin's error codes to something worth showing on screen.
  factory BluetoothException.from(PlatformException e) =>
      BluetoothException(e.code, switch (e.code) {
        'permission' =>
          'FocusFreak needs Bluetooth permission to reach the '
              'bot.',
        'disabled' => 'Bluetooth is off.',
        'unsupported' =>
          'This phone has no Bluetooth radio. Everything '
              'except the bot still works.',
        'io' => 'The bot did not answer. Check it is powered and paired.',
        'bond' => e.message ?? 'Pairing did not finish. Try again.',
        'busy' => 'Still pairing with another bot.',
        _ => e.message ?? 'Bluetooth failed.',
      });

  @override
  String toString() => message;
}

/// Bluetooth Classic, one socket at a time.
class BluetoothChannel {
  BluetoothChannel({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('focusfreak/bt'),
      _events = events ?? const EventChannel('focusfreak/bt/events');

  final MethodChannel _methods;
  final EventChannel _events;

  Stream<dynamic>? _raw;

  Stream<dynamic> get _stream => _raw ??= _events.receiveBroadcastStream();

  /// Bytes as the radio delivered them, in arbitrary chunks.
  Stream<Uint8List> get incoming =>
      _stream.where((e) => e is Uint8List).cast<Uint8List>();

  /// Link events the phone did not ask for — most importantly the bot going
  /// out of range mid-session.
  ///
  /// Filtered on `kind`: the same event channel now also carries scan results,
  /// and without the discriminator every discovered device would arrive here
  /// looking like a link state change.
  Stream<({String state, String? detail})> get linkEvents => _stream
      .where((e) => e is Map && e['kind'] == 'link')
      .map(
        (e) => (
          state: (e as Map)['state'] as String? ?? 'unknown',
          detail: e['detail'] as String?,
        ),
      );

  /// Devices as the scan finds them, plus a terminator when it ends.
  Stream<DiscoveryEvent> get discoveryEvents => _stream
      .where((e) => e is Map && e['kind'] == 'discovery')
      .map<DiscoveryEvent?>((e) {
        final map = e as Map<Object?, Object?>;
        return switch (map['event']) {
          'found' => DeviceFound(BondedDevice.fromMap(map)),
          'finished' => const DiscoveryFinished(),
          _ => null,
        };
      })
      .where((e) => e != null)
      .cast<DiscoveryEvent>();

  Future<T> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args) as T;
    } on PlatformException catch (e) {
      throw BluetoothException.from(e);
    } on MissingPluginException {
      // The web and macOS development surfaces have no plugin. Saying so
      // plainly beats a stack trace in a demo.
      throw const BluetoothException(
        'unsupported',
        'Bluetooth is only available in the Android build.',
      );
    }
  }

  Future<bool> get isSupported async {
    try {
      return await _call<bool>('isSupported');
    } on BluetoothException {
      return false;
    }
  }

  Future<bool> get isEnabled => _call<bool>('isEnabled');

  Future<bool> get hasPermissions => _call<bool>('hasPermissions');

  /// Asks for the runtime permissions. Returns whether they are already held —
  /// the grant itself lands asynchronously, so re-check [hasPermissions] after
  /// the dialog closes.
  Future<bool> requestPermissions() => _call<bool>('requestPermissions');

  /// Asks Android to turn the radio on.
  ///
  /// Returns whether it is already on — the user's answer to the system dialog
  /// arrives separately, so re-check [isEnabled] rather than trusting a false.
  Future<bool> requestEnable() => _call<bool>('requestEnable');

  Future<List<BondedDevice>> bondedDevices() async {
    final raw = await _call<List<Object?>>('bondedDevices');
    return <BondedDevice>[
      for (final entry in raw.whereType<Map<Object?, Object?>>())
        BondedDevice.fromMap(entry),
    ];
  }

  /// Starts a scan. Results arrive on [discoveryEvents], beginning with the
  /// already-bonded devices, which a scan by itself never reports.
  Future<bool> startDiscovery() => _call<bool>('startDiscovery');

  Future<void> stopDiscovery() => _call<void>('stopDiscovery');

  /// Pairs with a bot, supplying the PIN on the user's behalf.
  ///
  /// This is what makes the flow feel like a Bluetooth speaker: no trip to
  /// Android settings, no code to type. A bot that is already paired returns
  /// immediately. See `docs/BOT_PROVISIONING.md` for why one PIN works for
  /// every unit.
  Future<void> bond(String address) =>
      _call<void>('bond', <String, Object?>{'address': address});

  Future<BondedDevice> connect(String address) async {
    final raw = await _call<Map<Object?, Object?>>('connect', <String, Object?>{
      'address': address,
    });
    return BondedDevice(
      name: raw['name'] as String? ?? address,
      address: raw['address'] as String? ?? address,
    );
  }

  Future<void> write(Uint8List bytes) =>
      _call<void>('write', <String, Object?>{'bytes': bytes});

  Future<void> disconnect() => _call<void>('disconnect');
}
