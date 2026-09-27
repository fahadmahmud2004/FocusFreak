import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/domain/model/bot_state.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/botos/os.dart';
import 'package:focusfreak_app/features/bot/botos_host.dart';
import 'package:focusfreak_app/features/bot/oled_display.dart';

void main() {
  group('eye parameters', () {
    test('every mood has a distinct resting shape', () {
      final shapes = <String>{
        for (final m in Mood.values)
          '${EyeParams.forMood(m).width}x${EyeParams.forMood(m).height}'
              ':${EyeParams.forMood(m).lidTop}:${EyeParams.forMood(m).lidBottom}'
              ':${EyeParams.forMood(m).slant}',
      };
      expect(
        shapes,
        hasLength(Mood.values.length),
        reason: 'two moods that look identical are one mood',
      );
    });

    test('calm is the most open shape', () {
      final calm = EyeParams.forMood(Mood.calm);
      for (final m in Mood.values.where((m) => m != Mood.calm)) {
        expect(
          EyeParams.forMood(m).height,
          lessThan(calm.height),
          reason: '${m.name} should be less open than calm',
        );
      }
    });

    test('happy narrows from the bottom, sleepy from the top', () {
      // This is the difference between a squint and a droop, and it is the
      // whole reason happy reads as a smile rather than as tiredness.
      final happy = EyeParams.forMood(Mood.happy);
      expect(happy.lidBottom, greaterThan(0));
      expect(happy.lidTop, 0);

      final sleepy = EyeParams.forMood(Mood.sleepy);
      expect(sleepy.lidTop, greaterThan(0));
      expect(sleepy.lidBottom, 0);
    });

    test('sad slants downward and looks down', () {
      final sad = EyeParams.forMood(Mood.sad);
      expect(sad.slant, lessThan(0));
      expect(sad.offsetY, greaterThan(0));
    });

    test('lerp moves smoothly between two shapes', () {
      final a = EyeParams.forMood(Mood.calm);
      final b = EyeParams.forMood(Mood.sad);

      expect(EyeParams.lerp(a, b, 0).height, a.height);
      expect(EyeParams.lerp(a, b, 1).height, b.height);

      final mid = EyeParams.lerp(a, b, 0.5);
      expect(mid.height, (a.height + b.height) / 2);
      expect(mid.slant, (a.slant + b.slant) / 2);
    });
  });

  group('BotState.eyes', () {
    final now = DateTime(2026, 8, 2, 10, 42);

    test('a full blink nearly closes the eye', () {
      final open = BotState(mode: BotMode.ambient, mood: Mood.calm, now: now);
      final shut = open.copyWith(blink: 1);

      expect(shut.eyes.height, lessThan(open.eyes.height * 0.1));
      expect(
        shut.eyes.height,
        greaterThan(0),
        reason: 'a zero-height eye would vanish rather than blink',
      );
    });

    test('gaze offsets the eyes without resizing them', () {
      final centred = BotState(
        mode: BotMode.ambient,
        mood: Mood.calm,
        now: now,
      );
      final looking = centred.copyWith(gazeX: 1, gazeY: -1);

      expect(looking.eyes.offsetX, greaterThan(centred.eyes.offsetX));
      expect(looking.eyes.offsetY, lessThan(centred.eyes.offsetY));
      expect(looking.eyes.width, centred.eyes.width);
    });

    test('an explicit eyeShape overrides the mood default', () {
      // This is what carries the 8-frame mood transition. Without it the shape
      // would snap the instant the mood enum changed.
      const custom = EyeParams(width: 1, height: 2, radius: 3);
      final state = BotState(
        mode: BotMode.ambient,
        mood: Mood.calm,
        now: now,
        eyeShape: custom,
      );

      expect(state.eyes.width, 1);
      expect(state.eyes.height, 2);
    });
  });

  group('OledDisplay', () {
    Widget host(BotFrame frame) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 320, child: OledDisplay(frame: frame)),
        ),
      ),
    );

    testWidgets('draws a BotOS frame without throwing', (tester) async {
      final os = BotOs(random: math.Random(1));
      os.tick(BotWorld(now: DateTime(2026, 9, 26, 11)));
      await tester.pumpWidget(
        host(BotFrame(Uint8List.fromList(os.gfx.pixels), 1, 1)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty frame is a black panel, not an error', (
      tester,
    ) async {
      await tester.pumpWidget(host(BotFrame(Uint8List(128 * 64), 0.5, 0)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the 128 x 64 proportions at any width', (tester) async {
      await tester.pumpWidget(host(BotFrame(Uint8List(128 * 64), 1, 0)));
      final size = tester.getSize(find.byType(OledDisplay));
      expect(size.width / size.height, closeTo(2, 0.001));
    });
  });

  group('BotMode', () {
    test('codes match the frozen spec', () {
      expect(BotMode.ambient.code, 'D1');
      expect(BotMode.attention.code, 'D2');
      expect(BotMode.task.code, 'D3');
      expect(BotMode.pet.code, 'D4');
      expect(BotMode.pair.code, 'D5');
      expect(BotMode.dim.code, 'D6');
      expect(BotMode.values, hasLength(6));
    });
  });
}
