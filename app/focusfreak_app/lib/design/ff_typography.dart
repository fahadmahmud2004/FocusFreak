import 'package:flutter/material.dart';

/// Type scale.
///
/// The app deliberately uses the platform font (Roboto on Android, SF on
/// macOS) rather than a downloaded webfont: FocusFreak promises to work fully
/// offline, and `google_fonts` fetches over the network on first paint.
///
/// Every numeric style carries [FontFeature.tabularFigures] and
/// [FontFeature.slashedZero]. A countdown whose digits change width jitters,
/// and jitter is the one thing a focus timer cannot do.
class FfType {
  const FfType._();

  static const List<FontFeature> _numeric = <FontFeature>[
    FontFeature.tabularFigures(),
    FontFeature.slashedZero(),
  ];

  /// The big MM:SS on the timer and the bot's Task screen.
  static const TextStyle countdownXl = TextStyle(
    fontSize: 76,
    height: 1.0,
    fontWeight: FontWeight.w300,
    letterSpacing: -2,
    fontFeatures: _numeric,
  );

  static const TextStyle countdownLg = TextStyle(
    fontSize: 48,
    height: 1.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -1,
    fontFeatures: _numeric,
  );

  static const TextStyle countdownMd = TextStyle(
    fontSize: 30,
    height: 1.05,
    fontWeight: FontWeight.w500,
    fontFeatures: _numeric,
  );

  /// The small running countdown on the floating timer.
  static const TextStyle countdownSm = TextStyle(
    fontSize: 18,
    height: 1.0,
    fontWeight: FontWeight.w600,
    fontFeatures: _numeric,
  );

  /// Big single numbers on stat tiles.
  static const TextStyle statValue = TextStyle(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    fontFeatures: _numeric,
  );

  static const TextStyle statUnit = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
    fontFeatures: _numeric,
  );

  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  /// All-caps micro label used on badges (TRACK, DOCK, HERE, BT) — the same
  /// vocabulary the device screen uses, so the two read as one product.
  static const TextStyle overline = TextStyle(
    fontSize: 10.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  /// The hex wire log, and nothing else.
  ///
  /// Monospace so that a byte in one frame sits under the same byte in the
  /// next — which is the only way a hex dump is faster to read than the
  /// decoded frame it came from.
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Menlo', 'Courier New'],
    fontSize: 11,
    height: 1.45,
  );

  static TextTheme textTheme(Color onSurface, Color onSurfaceMuted) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: onSurface),
      displayMedium: displayMedium.copyWith(color: onSurface),
      headlineMedium: titleLarge.copyWith(color: onSurface),
      titleLarge: titleLarge.copyWith(color: onSurface),
      titleMedium: titleMedium.copyWith(color: onSurface),
      titleSmall: titleSmall.copyWith(color: onSurface),
      bodyLarge: body.copyWith(color: onSurface),
      bodyMedium: body.copyWith(color: onSurface),
      bodySmall: bodySmall.copyWith(color: onSurfaceMuted),
      labelLarge: titleSmall.copyWith(color: onSurface),
      labelMedium: caption.copyWith(color: onSurfaceMuted),
      labelSmall: overline.copyWith(color: onSurfaceMuted),
    );
  }
}
