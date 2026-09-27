import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/design/ff_theme.dart';
import 'package:focusfreak_app/features/dev/gallery_screen.dart';

/// All three themes are shipped designs, so all three are tested.
///
/// The light palette in particular cannot reuse the logo's gold as-is — that
/// gold is a light-on-dark colour and fails on paper. These assertions are what
/// stop it drifting back.
void main() {
  final palettes = <String, FfPalette>{
    'dark': FfPalette.darkPalette,
    'amoled': FfPalette.amoledPalette,
    'light': FfPalette.lightPalette,
  };

  group('palette contrast', () {
    palettes.forEach((name, p) {
      test('$name: body text on every surface is readable', () {
        for (final surface in <(String, Color)>[
          ('base', p.surfaceBase),
          ('elevated', p.surfaceElevated),
          ('raised', p.surfaceRaised),
        ]) {
          expect(
            _contrast(p.textPrimary, surface.$2),
            greaterThanOrEqualTo(7.0),
            reason: '$name primary text on ${surface.$1}',
          );
          expect(
            _contrast(p.textSecondary, surface.$2),
            greaterThanOrEqualTo(4.5),
            reason: '$name secondary text on ${surface.$1}',
          );
          // Muted text is metadata, not content — WCAG AA large / UI minimum.
          expect(
            _contrast(p.textMuted, surface.$2),
            greaterThanOrEqualTo(3.0),
            reason: '$name muted text on ${surface.$1}',
          );
        }
      });

      test('$name: accent and status colours clear the 3:1 UI minimum', () {
        for (final entry in <(String, Color)>[
          ('accent', p.accent),
          ('verified', p.verified),
          ('paused', p.paused),
          ('broken', p.broken),
        ]) {
          expect(
            _contrast(entry.$2, p.surfaceElevated),
            greaterThanOrEqualTo(3.0),
            reason: '$name ${entry.$1} on the card surface',
          );
        }
      });

      test('$name: borders are visible against their own surface', () {
        expect(
          _contrast(p.border, p.surfaceElevated),
          greaterThan(1.1),
          reason: '$name border would be invisible',
        );
      });
    });
  });

  group('theme construction', () {
    for (final mode in FfThemeMode.values) {
      testWidgets('${mode.name} renders the gallery without exceptions', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: FfTheme.of(mode),
              home: const GalleryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Design system'), findsOneWidget);
        expect(find.text('Deep Work'), findsOneWidget);
      });
    }

    test('every mode carries an FfPalette extension', () {
      for (final mode in FfThemeMode.values) {
        expect(FfTheme.of(mode).extension<FfPalette>(), isNotNull);
      }
    });

    test('scaffold background follows the palette, not Material defaults', () {
      expect(
        FfTheme.of(FfThemeMode.amoled).scaffoldBackgroundColor,
        FfPalette.amoledPalette.surfaceBase,
      );
      expect(
        FfTheme.of(FfThemeMode.light).scaffoldBackgroundColor,
        FfPalette.lightPalette.surfaceBase,
      );
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
