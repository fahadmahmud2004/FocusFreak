import 'package:flutter/material.dart';

/// FocusFreak colour system.
///
/// Two independent palettes live here:
///
///  * The **brand palette** — gold on near-black, taken from the logo. Used for
///    chrome, accents and the bot's eyes.
///  * The **category palette** — the six block categories. These are NOT chosen
///    here. They are derived from the RGB565 constants the firmware writes to
///    the TFT and the WS2812B ring (the firmware), so the app, the
///    device screen and the LED ring can never drift apart.
class FfColors {
  const FfColors._();

  // ---------------------------------------------------------------------------
  // Brand — from assets/logo/focusfreak_logo.png
  //
  // The logo was redrawn on 3 August and these did not move. Its gold reads
  // #FDD365, which sits between [gold] and [goldBright] — inside the family
  // already here. They are also pinned to the firmware's RGB565 words by
  // `firmware_parity_test.dart`, so a nudge to match artwork exactly would
  // desynchronise the app from the device screen for a difference nobody can
  // see.
  // ---------------------------------------------------------------------------

  /// Primary brand gold. The logo's stroke colour.
  static const gold = Color(0xFFF0C44A);

  /// Lifted gold, used for the glowing eyes and focused states.
  static const goldBright = Color(0xFFFFDE7A);

  /// Recessed gold, used for borders and disabled accents.
  static const goldDeep = Color(0xFFB8862A);

  /// The logo's background. The darkest surface in the app.
  static const ink = Color(0xFF0B0B0D);
  static const inkElevated = Color(0xFF141417);
  static const inkRaised = Color(0xFF1C1C21);
  static const inkBorder = Color(0xFF2A2A31);

  /// True black, for the AMOLED theme.
  static const black = Color(0xFF000000);

  static const paper = Color(0xFFFAF8F4);
  static const paperElevated = Color(0xFFFFFFFF);
  static const paperRaised = Color(0xFFF1EEE7);
  static const paperBorder = Color(0xFFE0DCD2);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------

  /// Verified — the session is counting real, sensor-backed seconds.
  static const verified = Color(0xFF21CE73);

  /// Paused — a verification factor dropped out, timer is frozen.
  static const paused = Color(0xFFF5A623);

  /// Broken — the violation ran past the grace window.
  static const broken = Color(0xFFE5484D);

  /// Claimed-but-unverified time, in charts.
  static const claimed = Color(0xFF6E6E7A);

  static const info = Color(0xFF4A9EFF);

  // ---------------------------------------------------------------------------
  // Category palette — derived, never hand-picked
  // ---------------------------------------------------------------------------

  /// The exact RGB565 words the firmware uses. Indexed by category id 0..5.
  ///
  /// Changing a value here changes the app, the PDF reports and the virtual
  /// bot together — and it must be changed in the firmware in the same commit.
  static const List<int> categoryRgb565 = <int>[
    0x1A5F, // 0 Deep Work        — deep blue
    0x0651, // 1 Active Work      — teal
    0xFC00, // 2 Output/Practice  — orange
    0x2664, // 3 Routine          — green
    0x8817, // 4 Nap + Buffer     — purple
    0x4208, // 5 Sleep            — dark grey
  ];

  /// Expand a 16-bit RGB565 word into a 24-bit [Color].
  ///
  /// Each channel is scaled rather than shifted, so full-scale stays full-scale
  /// (`0x1F -> 0xFF`, not `0xF8`). This matches how the TFT actually renders.
  static Color fromRgb565(int v) {
    final r5 = (v >> 11) & 0x1F;
    final g6 = (v >> 5) & 0x3F;
    final b5 = v & 0x1F;
    return Color.fromARGB(
      0xFF,
      (r5 * 255 + 15) ~/ 31,
      (g6 * 255 + 31) ~/ 63,
      (b5 * 255 + 15) ~/ 31,
    );
  }

  /// Collapse a [Color] back to RGB565, for pushing to the device.
  static int toRgb565(Color c) {
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
  }

  /// The screen colour for a block category (0..5).
  static Color category(int id) =>
      fromRgb565(categoryRgb565[id.clamp(0, categoryRgb565.length - 1)]);

  /// A muted fill of the category colour, for chips and timeline bars.
  static Color categorySoft(int id, {double opacity = 0.16}) =>
      category(id).withValues(alpha: opacity);

  static const Color _onDark = Color(0xFF101014);

  /// Text colour for a label sitting on a category swatch.
  ///
  /// Picks whichever of near-black and white actually wins the WCAG contrast
  /// comparison rather than testing luminance against a fixed threshold. The
  /// six category colours are firmware constants, not design choices — a
  /// threshold that happens to work today silently breaks the moment one of
  /// them changes. The teal Active Work colour is exactly that case: it sits
  /// close enough to mid-luminance that the naive rule picks white and lands
  /// at 2.1:1.
  static Color onCategory(int id) {
    final bg = category(id);
    return _contrast(_onDark, bg) >= _contrast(Colors.white, bg)
        ? _onDark
        : Colors.white;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}

/// The six block categories, in firmware order. The index *is* the wire value.
enum FfCategory {
  deepWork('Deep Work', 'Focused, phone away'),
  activeWork('Active Work', 'Problem solving, labs'),
  output('Output', 'Practice, writing, delivery'),
  routine('Routine', 'Salat, meals, hygiene'),
  nap('Nap + Buffer', 'Recovery and slack'),
  sleep('Sleep', 'Core sleep block');

  const FfCategory(this.label, this.hint);

  final String label;
  final String hint;

  int get id => index;
  Color get color => FfColors.category(index);
  Color get onColor => FfColors.onCategory(index);
  Color get soft => FfColors.categorySoft(index);
  int get rgb565 => FfColors.categoryRgb565[index];

  static FfCategory fromId(int id) =>
      FfCategory.values[id.clamp(0, FfCategory.values.length - 1)];
}
