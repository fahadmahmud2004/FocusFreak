/// The Dart side of `PhoneStatePlugin.kt` and `UsageStatsPlugin.kt`.
///
/// These are the phone's *own* verification factors — the half that has nothing
/// to do with a bot. Nothing here interprets them; it moves readings, and
/// `PhoneVerificationSource` turns them into evidence.
///
/// The one rule this file exists to keep: **a factor the platform did not
/// report is absent, not holding.** Both plugins emit a sparse map, and every
/// failure path here — no plugin, no permission, no sensor, not Android at all —
/// resolves to an empty map rather than to a comfortable default.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/model/verification.dart';

/// One reading from a platform plugin.
class PhoneReading {
  const PhoneReading({
    this.running = false,
    this.granted = true,
    this.factors = const <VerificationFactor, FactorState>{},
  });

  /// Whether the plugin is currently observing anything.
  final bool running;

  /// Whether the grant this feed needs is held. Always true for feeds that
  /// need no grant.
  final bool granted;

  /// Only the factors actually being observed. A factor missing from this map
  /// has no source, which is not the same as holding.
  final Map<VerificationFactor, FactorState> factors;

  /// Nothing observed, nothing claimed. The honest reading for web, macOS, a
  /// missing plugin, or a revoked permission.
  static const PhoneReading none = PhoneReading();

  static PhoneReading fromMap(Map<Object?, Object?> raw) {
    final factors = <VerificationFactor, FactorState>{};
    final reported = raw['factors'];
    if (reported is Map) {
      for (final entry in reported.entries) {
        final factor = _factorFor(entry.key);
        final state = _stateFor(entry.value);
        // An unrecognised key is dropped rather than guessed at. A newer
        // plugin talking to an older app must not be able to invent a factor.
        if (factor != null && state != null) factors[factor] = state;
      }
    }
    return PhoneReading(
      running: raw['running'] == true,
      granted: raw['granted'] != false,
      factors: factors,
    );
  }

  static VerificationFactor? _factorFor(Object? key) {
    for (final f in VerificationFactor.values) {
      if (f.name == key) return f;
    }
    return null;
  }

  /// Note there is no mapping for `unavailable`: the plugins express that by
  /// leaving the factor out entirely, and a plugin that sent it explicitly
  /// would mean the same thing.
  static FactorState? _stateFor(Object? value) => switch (value) {
    'holding' => FactorState.holding,
    'violated' => FactorState.violated,
    _ => null,
  };

  @override
  String toString() =>
      'PhoneReading(running: $running, granted: $granted, '
      '${factors.entries.map((e) => '${e.key.label}=${e.value.name}').join(' ')})';
}

/// Shared plumbing for the two phone plugins.
///
/// Both speak the same shape — a method channel of commands and an event
/// channel of readings — and both have to degrade to [PhoneReading.none] on any
/// surface where the plugin does not exist.
abstract class _PhonePlugin {
  _PhonePlugin(String methods, String events)
    : _methods = MethodChannel(methods),
      _events = EventChannel(events);

  final MethodChannel _methods;
  final EventChannel _events;

  Stream<PhoneReading>? _readings;

  /// Readings as the platform pushes them.
  ///
  /// Errors are mapped to [PhoneReading.none] rather than forwarded: a broken
  /// feed is a feed with no evidence in it, and that is a state the verification
  /// engine already understands. Letting it surface as a stream error would
  /// take down the session instead.
  Stream<PhoneReading> get readings => _readings ??= _events
      .receiveBroadcastStream()
      .map((e) => e is Map ? PhoneReading.fromMap(e) : PhoneReading.none)
      .handleError((Object _) {})
      .cast<PhoneReading>();

  Future<T?> invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on MissingPluginException {
      // Web and macOS are development surfaces with no plugin. Reporting
      // nothing is correct there — the app just runs with no phone factors.
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<PhoneReading> invokeReading(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    final raw = await invoke<Map<Object?, Object?>>(method, args);
    return raw == null ? PhoneReading.none : PhoneReading.fromMap(raw);
  }
}

/// Screen lock, and stillness standing in for the dock.
class PhoneStateChannel extends _PhonePlugin {
  PhoneStateChannel() : super('focusfreak/phone', 'focusfreak/phone/events');

  /// Whether this phone can answer the stillness question at all.
  Future<bool> hasAccelerometer() async =>
      await invoke<bool>('hasAccelerometer') ?? false;

  /// Begins observing, and raises the foreground service that keeps the
  /// observation alive once the screen goes off.
  ///
  /// [title] and [body] are what the user reads in the notification shade for
  /// as long as the block runs, so they name the block rather than the app.
  Future<PhoneReading> start({
    required bool useStillness,
    required String title,
    required String body,
  }) => invokeReading('start', <String, Object?>{
    'useStillness': useStillness,
    'title': title,
    'body': body,
  });

  /// Turns stillness on or off without disturbing a running observation.
  Future<PhoneReading> configure({required bool useStillness}) => invokeReading(
    'configure',
    <String, Object?>{'useStillness': useStillness},
  );

  Future<void> stop() => invoke<void>('stop');

  Future<PhoneReading> read() => invokeReading('read');
}

/// Whether another app was opened.
class UsageStatsChannel extends _PhonePlugin {
  UsageStatsChannel() : super('focusfreak/usage', 'focusfreak/usage/events');

  /// Whether the usage-access grant is held. It can be revoked at any time
  /// from system settings, so this is asked rather than remembered.
  Future<bool> hasAccess() async => await invoke<bool>('hasAccess') ?? false;

  /// Opens the system screen carrying the grant. False if this ROM has no such
  /// screen, in which case the feature is simply not offered.
  Future<bool> openSettings() async =>
      await invoke<bool>('openSettings') ?? false;

  Future<PhoneReading> start() => invokeReading('start');

  Future<void> stop() => invoke<void>('stop');

  Future<PhoneReading> read() => invokeReading('read');
}
