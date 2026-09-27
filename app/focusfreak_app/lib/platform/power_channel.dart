/// The Dart side of `PowerSettingsPlugin.kt`.
///
/// Two settings decide whether a 90-minute block survives being put in a
/// pocket: Android's battery-optimisation exemption, and — on Xiaomi, Oppo,
/// Vivo, Realme and Huawei — the vendor's own autostart whitelist, which sits
/// on top and kills foreground services regardless of what Android allows.
///
/// Neither can be granted programmatically, and neither should be: both open a
/// screen where the user decides. Everything here reports honestly when the
/// screen does not exist on this ROM, so the app can offer the button only when
/// it would do something.
library;

import 'package:flutter/services.dart';

class PowerChannel {
  const PowerChannel({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel('focusfreak/power');

  final MethodChannel _methods;

  Future<T?> _invoke<T>(String method) async {
    try {
      return await _methods.invokeMethod<T>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Whether Android has been told to leave this app alone. True on the
  /// development surfaces, where there is nothing to exempt.
  Future<bool> get isExempt async =>
      await _invoke<bool>('isIgnoringBatteryOptimizations') ?? true;

  /// Shows the system dialog. The answer arrives when the user gives it, so
  /// re-check [isExempt] rather than trusting the return.
  Future<void> requestExemption() =>
      _invoke<void>('requestIgnoreBatteryOptimizations');

  /// Whether this ROM has a vendor autostart screen at all. False on stock
  /// Android — and the card must not mention a screen that is not there.
  Future<bool> get hasAutostartSettings async =>
      await _invoke<bool>('hasAutostartSettings') ?? false;

  Future<void> openAutostartSettings() =>
      _invoke<void>('openAutostartSettings');

  Future<void> openAppSettings() => _invoke<void>('openAppSettings');
}
