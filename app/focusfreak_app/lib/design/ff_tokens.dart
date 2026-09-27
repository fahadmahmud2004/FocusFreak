import 'package:flutter/widgets.dart';

/// Spacing, radius, elevation and motion tokens.
///
/// Everything in the app measures itself in these. If a widget hard-codes a
/// number, that is a bug, not a shortcut.
class FfSpace {
  const FfSpace._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard page gutter.
  static const double gutter = 16;
}

class FfRadius {
  const FfRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Motion. Nothing in this app animates for longer than [slow] — a focus tool
/// that makes you wait for its own transitions is working against itself.
class FfMotion {
  const FfMotion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;
  static const Curve standard = Curves.easeInOutCubic;
}

/// Breakpoints. The app is phone-first but must not fall apart on a tablet or
/// on the macOS/web build used during development.
class FfBreakpoint {
  const FfBreakpoint._();

  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;

  static bool isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < compact;
  static bool isExpanded(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= medium;

  /// Content never stretches past this, however wide the window gets.
  static const double maxContentWidth = 720;
}
