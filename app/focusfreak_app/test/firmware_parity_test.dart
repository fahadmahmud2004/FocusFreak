import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/core/ff_constants.dart';
import 'package:focusfreak_app/design/ff_colors.dart';

/// Guards the values the app shares with the firmware.
///
/// If one of these fails, the app and the device disagree about something the
/// user can see — a colour, a grace period, a struct size. Fix the mismatch;
/// do not relax the test.
void main() {
  group('category colours', () {
    test('the six RGB565 words match the firmware palette', () {
      expect(FfColors.categoryRgb565, <int>[
        0x1A5F, // Deep Work
        0x0651, // Active Work
        0xFC00, // Output / Practice
        0x2664, // Routine
        0x8817, // Nap + Buffer
        0x4208, // Sleep
      ]);
    });

    test('there is exactly one colour per category enum value', () {
      expect(FfColors.categoryRgb565.length, FfCategory.values.length);
      for (final c in FfCategory.values) {
        expect(c.rgb565, FfColors.categoryRgb565[c.index]);
        expect(c.id, c.index, reason: 'the enum index is the wire value');
      }
    });

    test('RGB565 expansion scales channels to full range', () {
      // Full-scale in must be full-scale out. A naive shift would give
      // 0xF8/0xFC and every "white" on the device would read slightly grey.
      expect(FfColors.fromRgb565(0xFFFF), const Color(0xFFFFFFFF));
      expect(FfColors.fromRgb565(0x0000), const Color(0xFF000000));

      // Pure channels.
      expect(FfColors.fromRgb565(0xF800), const Color(0xFFFF0000));
      expect(FfColors.fromRgb565(0x07E0), const Color(0xFF00FF00));
      expect(FfColors.fromRgb565(0x001F), const Color(0xFF0000FF));
    });

    test('toRgb565 round-trips every category word', () {
      for (final word in FfColors.categoryRgb565) {
        expect(
          FfColors.toRgb565(FfColors.fromRgb565(word)),
          word,
          reason:
              '0x${word.toRadixString(16)} must survive a round trip, '
              'because the app pushes colours back to the device',
        );
      }
    });

    test('every category label is legible on its own colour', () {
      for (final c in FfCategory.values) {
        final ratio = _contrast(c.onColor, c.color);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${c.label}: on-colour text contrast is $ratio',
        );
      }
    });
  });

  group('firmware constants', () {
    test('presence window and attention threshold', () {
      expect(FfFirmware.presenceMinCm, 20);
      expect(FfFirmware.presenceMaxCm, 90);
      expect(FfFirmware.attentionCm, 70);
      expect(
        FfFirmware.attentionCm,
        lessThan(FfFirmware.presenceMaxCm),
        reason: 'you must be inside the presence window before the face wakes',
      );
    });

    test('grace periods match the verification table', () {
      expect(FfFirmware.graceRunning, const Duration(seconds: 30));
      expect(FfFirmware.gracePaused, const Duration(minutes: 5));
      expect(FfFirmware.armTimeout, const Duration(seconds: 15));
      expect(FfFirmware.heartbeatTimeout, const Duration(seconds: 25));
    });

    test('heartbeat fires at least twice inside its own timeout', () {
      // One dropped packet must not be enough to fail verification.
      expect(
        FfFirmware.heartbeatInterval * 2,
        lessThan(FfFirmware.heartbeatTimeout),
      );
    });

    test('device capacity matches the EEPROM map', () {
      expect(FfFirmware.maxDeviceBlocks, 16);
      expect(FfFirmware.blockNameMaxChars, 16);
      expect(FfFirmware.blockDescMaxChars, 24);
      expect(FfFirmware.deviceLogDays, 30);
      expect(FfFirmware.sequentialStartMin, 0xFFFF);
    });

    test('16 blocks still fit the 768-byte EEPROM routine region', () {
      const blockStructBytes = 48;
      expect(FfFirmware.maxDeviceBlocks * blockStructBytes, 768);
    });

    test('link settings match the frozen spec', () {
      expect(FfFirmware.baudRate, 9600);
      expect(FfFirmware.sppUuid, '00001101-0000-1000-8000-00805F9B34FB');
    });
  });
}

/// WCAG relative-luminance contrast ratio.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _luminance(Color c) => c.computeLuminance();
