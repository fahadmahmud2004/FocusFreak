import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ff_colors.dart';
import 'ff_tokens.dart';
import 'ff_typography.dart';

/// Which of the three looks the app is wearing.
enum FfThemeMode { light, dark, amoled }

/// The colours Material's [ColorScheme] has no slot for.
///
/// Exposed as a [ThemeExtension] so widgets read them from the tree
/// (`context.ff`) rather than importing a palette and guessing the mode.
@immutable
class FfPalette extends ThemeExtension<FfPalette> {
  const FfPalette({
    required this.surfaceBase,
    required this.surfaceElevated,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.verified,
    required this.paused,
    required this.broken,
    required this.claimed,
    required this.accent,
    required this.accentBright,
    required this.accentDeep,
    required this.isDark,
  });

  final Color surfaceBase;
  final Color surfaceElevated;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color verified;
  final Color paused;
  final Color broken;
  final Color claimed;

  final Color accent;
  final Color accentBright;
  final Color accentDeep;

  final bool isDark;

  static const FfPalette darkPalette = FfPalette(
    surfaceBase: FfColors.ink,
    surfaceElevated: FfColors.inkElevated,
    surfaceRaised: FfColors.inkRaised,
    border: FfColors.inkBorder,
    borderStrong: Color(0xFF3A3A44),
    textPrimary: Color(0xFFF2F1EE),
    textSecondary: Color(0xFFA8A8B3),
    textMuted: Color(0xFF6E6E7A),
    verified: FfColors.verified,
    paused: FfColors.paused,
    broken: FfColors.broken,
    claimed: FfColors.claimed,
    accent: FfColors.gold,
    accentBright: FfColors.goldBright,
    accentDeep: FfColors.goldDeep,
    isDark: true,
  );

  static const FfPalette amoledPalette = FfPalette(
    surfaceBase: FfColors.black,
    surfaceElevated: Color(0xFF0C0C0F),
    surfaceRaised: Color(0xFF16161A),
    border: Color(0xFF232329),
    borderStrong: Color(0xFF34343C),
    textPrimary: Color(0xFFF2F1EE),
    textSecondary: Color(0xFFA8A8B3),
    textMuted: Color(0xFF6E6E7A),
    verified: FfColors.verified,
    paused: FfColors.paused,
    broken: FfColors.broken,
    claimed: FfColors.claimed,
    accent: FfColors.gold,
    accentBright: FfColors.goldBright,
    accentDeep: FfColors.goldDeep,
    isDark: true,
  );

  static const FfPalette lightPalette = FfPalette(
    surfaceBase: FfColors.paper,
    surfaceElevated: FfColors.paperElevated,
    surfaceRaised: FfColors.paperRaised,
    border: FfColors.paperBorder,
    borderStrong: Color(0xFFCBC6B9),
    textPrimary: Color(0xFF16161A),
    textSecondary: Color(0xFF55555F),
    textMuted: Color(0xFF86868F),
    verified: Color(0xFF12A05C),
    paused: Color(0xFFC97C0A),
    broken: Color(0xFFCC2E33),
    claimed: Color(0xFF9A9AA4),
    // The logo gold is a light-on-dark colour; on paper it needs to go deeper
    // to stay legible as text and as a 3:1 non-text contrast.
    accent: Color(0xFF9A6E12),
    accentBright: Color(0xFFC28E1E),
    accentDeep: Color(0xFF6E4E0A),
    isDark: false,
  );

  @override
  FfPalette copyWith({
    Color? surfaceBase,
    Color? surfaceElevated,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? verified,
    Color? paused,
    Color? broken,
    Color? claimed,
    Color? accent,
    Color? accentBright,
    Color? accentDeep,
    bool? isDark,
  }) {
    return FfPalette(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      verified: verified ?? this.verified,
      paused: paused ?? this.paused,
      broken: broken ?? this.broken,
      claimed: claimed ?? this.claimed,
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      accentDeep: accentDeep ?? this.accentDeep,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  FfPalette lerp(ThemeExtension<FfPalette>? other, double t) {
    if (other is! FfPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return FfPalette(
      surfaceBase: c(surfaceBase, other.surfaceBase),
      surfaceElevated: c(surfaceElevated, other.surfaceElevated),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      verified: c(verified, other.verified),
      paused: c(paused, other.paused),
      broken: c(broken, other.broken),
      claimed: c(claimed, other.claimed),
      accent: c(accent, other.accent),
      accentBright: c(accentBright, other.accentBright),
      accentDeep: c(accentDeep, other.accentDeep),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension FfPaletteContext on BuildContext {
  /// The FocusFreak palette for the current theme.
  FfPalette get ff =>
      Theme.of(this).extension<FfPalette>() ?? FfPalette.darkPalette;
}

class FfTheme {
  const FfTheme._();

  static ThemeData of(FfThemeMode mode) => switch (mode) {
    FfThemeMode.light => _build(FfPalette.lightPalette, Brightness.light),
    FfThemeMode.dark => _build(FfPalette.darkPalette, Brightness.dark),
    FfThemeMode.amoled => _build(FfPalette.amoledPalette, Brightness.dark),
  };

  static ThemeData _build(FfPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.isDark ? const Color(0xFF10100C) : Colors.white,
      primaryContainer: p.accent.withValues(alpha: p.isDark ? 0.18 : 0.14),
      onPrimaryContainer: p.isDark ? p.accentBright : p.accentDeep,
      secondary: p.verified,
      onSecondary: Colors.white,
      error: p.broken,
      onError: Colors.white,
      surface: p.surfaceBase,
      onSurface: p.textPrimary,
      surfaceContainerLowest: p.surfaceBase,
      surfaceContainerLow: p.surfaceElevated,
      surfaceContainer: p.surfaceElevated,
      surfaceContainerHigh: p.surfaceRaised,
      surfaceContainerHighest: p.surfaceRaised,
      onSurfaceVariant: p.textSecondary,
      outline: p.border,
      outlineVariant: p.border,
      shadow: Colors.black,
    );

    final text = FfType.textTheme(p.textPrimary, p.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.surfaceBase,
      canvasColor: p.surfaceBase,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[p],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: p.surfaceBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: FfType.titleLarge.copyWith(color: p.textPrimary),
        systemOverlayStyle: p.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: FfRadius.cardRadius,
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.isDark ? const Color(0xFF10100C) : Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: FfSpace.xl),
          textStyle: FfType.titleSmall,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(FfRadius.md)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.borderStrong),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: FfSpace.xl),
          textStyle: FfType.titleSmall,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(FfRadius.md)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: FfType.titleSmall,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceRaised,
        // Selection is the app's accent, not Material's default green, and the
        // label picks whichever of black/white actually wins the contrast
        // comparison against it — the same rule as the category colours.
        selectedColor: p.accent.withValues(alpha: 0.20),
        checkmarkColor: p.accent,
        side: BorderSide(color: p.border),
        labelStyle: FfType.caption.copyWith(color: p.textSecondary),
        secondaryLabelStyle: FfType.caption.copyWith(color: p.textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: FfSpace.sm,
          vertical: FfSpace.xs,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(FfRadius.pill)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceRaised,
        hintStyle: FfType.body.copyWith(color: p.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FfSpace.lg,
          vertical: FfSpace.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FfRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FfRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FfRadius.md),
          borderSide: BorderSide(color: p.accent, width: 1.6),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p.accent.withValues(alpha: 0.28)
              : p.surfaceRaised,
        ),
        trackOutlineColor: WidgetStateProperty.all(p.border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.surfaceRaised,
        thumbColor: p.accent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accent.withValues(alpha: 0.18),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => FfType.caption.copyWith(
            color: s.contains(WidgetState.selected)
                ? p.textPrimary
                : p.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected) ? p.accent : p.textMuted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: FfRadius.sheetRadius),
        showDragHandle: true,
        dragHandleColor: p.borderStrong,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FfRadius.xl),
          side: BorderSide(color: p.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceRaised,
        contentTextStyle: FfType.bodySmall.copyWith(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FfRadius.md),
          side: BorderSide(color: p.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FfRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceRaised,
        circularTrackColor: p.surfaceRaised,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(FfRadius.sm),
          border: Border.all(color: p.border),
        ),
        textStyle: FfType.caption.copyWith(color: p.textPrimary),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
