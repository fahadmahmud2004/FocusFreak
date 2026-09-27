import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/core/ff_constants.dart';
import 'package:focusfreak_app/domain/engine/routine_builder.dart';
import 'package:focusfreak_app/domain/engine/session_engine.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/domain/model/template.dart';
import 'package:focusfreak_app/domain/model/verification.dart';

void main() {
  group('the routine generator', () {
    BuiltRoutine build({
      int wake = 300,
      int sleep = 1350,
      int hours = 8,
      BuilderStyle style = BuilderStyle.deep,
      bool prayers = true,
      RoutineSeason season = RoutineSeason.summer,
    }) => RoutineBuilder.build(
      BuilderInput(
        wakeMin: wake,
        sleepMin: sleep,
        targetStudyMinutes: hours * 60,
        style: style,
        includePrayers: prayers,
        season: season,
      ),
    );

    test('fills exactly one day with no gaps', () {
      for (final style in BuilderStyle.values) {
        final r = build(style: style);
        expect(r.blocks.fold(0, (s, b) => s + b.durationMin), 1440);
        for (var i = 0; i + 1 < r.blocks.length; i++) {
          final b = r.blocks[i];
          expect(
            (b.startMin! + b.durationMin) % 1440,
            r.blocks[i + 1].startMin,
          );
        }
        expect(r.blocks.first.startMin, 300);
        expect(r.blocks.last.category, 5);
      }
    });

    test('meets a reachable study target', () {
      final r = build(hours: 8);
      expect(r.studyMinutes, greaterThanOrEqualTo(8 * 60));
      expect(r.shortOfTarget, isFalse);
    });

    test('says so when the target cannot fit', () {
      final r = build(wake: 420, sleep: 1260, hours: 14);
      expect(r.shortOfTarget, isTrue);
    });

    test('salah goes in by the clock, never before its time', () {
      // A 03:00 riser must not get Dhuhr at 10:00.
      final r = build(wake: 180, sleep: 1290);
      final dhuhr = r.blocks.firstWhere((b) => b.name == 'Dhuhr & Lunch');
      expect(dhuhr.startMin, greaterThanOrEqualTo(RoutineSeason.summer.dhuhr));
      expect(dhuhr.startMin! - RoutineSeason.summer.dhuhr, lessThan(90));
    });

    test('winter moves the salah blocks with it', () {
      final r = build(season: RoutineSeason.winter);
      final isha = r.blocks.firstWhere((b) => b.name == 'Isha & Dinner');
      expect(isha.startMin, greaterThanOrEqualTo(RoutineSeason.winter.isha));
      expect(isha.startMin, lessThan(RoutineSeason.summer.isha));
    });

    test('every block fits the bot', () {
      for (final prayers in <bool>[true, false]) {
        for (final b in build(prayers: prayers).blocks) {
          expect(
            b.name.length,
            lessThanOrEqualTo(FfFirmware.blockNameMaxChars),
          );
          expect(
            b.description.length,
            lessThanOrEqualTo(FfFirmware.blockDescMaxChars),
          );
          expect(b.durationMin, greaterThan(0));
        }
      }
    });
  });

  group('a tracked block with no sensor at all', () {
    final t0 = DateTime(2026, 9, 26, 11);
    const nothing = VerificationSnapshot(
      factors: <VerificationFactor, FactorState>{},
      trackEnabled: true,
    );
    ActiveBlock block() => const ActiveBlock(
      id: 'b',
      name: 'Focus',
      category: 0,
      duration: Duration(minutes: 25),
      trackEnabled: true,
    );

    test('runs, and every second is claimed but none verified', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0, nothing);
      expect(e.state, SessionState.running);
      for (var s = 1; s <= 120; s++) {
        e.tick(t0.add(Duration(seconds: s)), nothing);
      }
      expect(
        e.state,
        SessionState.running,
        reason: 'nothing was violated, so nothing pauses',
      );
      expect(e.claimed, const Duration(minutes: 2));
      expect(e.verified, Duration.zero);
    });
  });
}
