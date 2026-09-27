/// The Dart side of `ScreenPlugin.kt`.
///
/// One job: keep the display awake while the phone is standing in as the bot.
library;

import 'package:flutter/services.dart';

class ScreenChannel {
  const ScreenChannel({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel('focusfreak/screen');

  final MethodChannel _methods;

  /// Asks Android to hold the screen on, or lets it sleep again.
  ///
  /// Silently does nothing where the plugin does not exist — the web and macOS
  /// development surfaces. A missing keep-awake is a screen that dims, not a
  /// crash, and the fullscreen face is still perfectly usable.
  Future<void> setKeepAwake({required bool keep}) async {
    try {
      await _methods.invokeMethod<void>('setKeepAwake', <String, Object?>{
        'keep': keep,
      });
    } on MissingPluginException {
      // Not Android. Nothing to do.
    } on PlatformException {
      // The window was already gone. Also nothing to do.
    }
  }
}
