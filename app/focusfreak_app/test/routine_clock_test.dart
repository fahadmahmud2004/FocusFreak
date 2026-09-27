import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/core/ff_constants.dart';
import 'package:focusfreak_app/domain/engine/routine_clock.dart';
import 'package:focusfreak_app/domain/engine/session_engine.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/domain/model/template.dart';
import 'package:focusfreak_app/domain/model/verification.dart';

/// How routine time works: which block is on, the three ways to start, and
/// what the bot is given. Pure functions of the blocks and an explicit `now`,
/// so every boundary is checked to the second.
void main() {
  const seq = FfFirmware.sequentialStartMin;

  List<TimedBlock> timed(RoutineTemplate t) => <TimedBlock>[
    for (final b in t.blocks)
      (startMin: b.startMin ?? seq, durationMin: b.durationMin),
  ];

  DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 9, 26, h, m, s);

  // 22:00 Wind down (60) · 23:00 Sleep (420, across midnight) · 06:00 Study (960)
  const day = <TimedBlock>[
    (startMin: 1320, durationMin: 60),
    (startMin: seq, durationMin: 420),
    (startMin: seq, durationMin: 960),
  ];

  group('which block is on', () {
    test('a sequential block starts where the one before it ends', () {
      expect(RoutineClock.starts(day), <int>[1320, 1380, 360]);
    });

    test('a routine with no first time has no clock', () {
      const sprint = <TimedBlock>[
        (startMin: seq, durationMin: 25),
        (startMin: seq, durationMin: 5),
      ];
      expect(RoutineClock.starts(sprint), isNull);
      expect(RoutineClock.blockAt(sprint, at(10, 0)), isNull);
    });

    test('resolves to the second', () {
      final hit = RoutineClock.blockAt(day, at(22, 30, 15))!;
      expect(hit.index, 0);
      expect(hit.elapsed, const Duration(minutes: 30, seconds: 15));
    });

    test('a block that wraps past midnight is found on both sides', () {
      expect(RoutineClock.blockAt(day, at(23, 59))!.index, 1);
      final after = RoutineClock.blockAt(day, at(2, 0))!;
      expect(after.index, 1);
      expect(after.elapsed, const Duration(hours: 3));
    });

    test('the last second of a block still belongs to it', () {
      expect(RoutineClock.blockAt(day, at(22, 59, 59))!.index, 0);
      expect(RoutineClock.blockAt(day, at(23, 0))!.index, 1);
    });

    test('a part-day routine has nothing on outside its hours', () {
      const morning = <TimedBlock>[
        (startMin: 360, durationMin: 90),
        (startMin: seq, durationMin: 30),
      ];
      expect(RoutineClock.blockAt(morning, at(9, 0)), isNull);
      expect(RoutineClock.blockAt(morning, at(7, 45))!.index, 1);
    });

    test('every shipped full day has a block on at every minute', () {
      for (final t in Templates.all.where((t) => t.isClockAnchored)) {
        for (var m = 0; m < 24 * 60; m += 7) {
          expect(
            RoutineClock.blockAt(timed(t), at(m ~/ 60, m % 60)),
            isNotNull,
            reason: '${t.name} has nothing on at $m',
          );
        }
      }
    });
  });

  group('the three ways to start', () {
    test('start now begins at the top with full length', () {
      final start = RoutineClock.plan(RoutineStartMode.now, day, at(2, 0))!;
      expect(start.index, 0);
      expect(start.offset, Duration.zero);
    });

    test('follow the clock joins the current block part-way', () {
      final start = RoutineClock.plan(RoutineStartMode.clock, day, at(7, 30))!;
      expect(start.index, 2);
      expect(start.offset, const Duration(minutes: 90));
    });

    test('follow the clock has nothing to join outside the routine', () {
      const morning = <TimedBlock>[(startMin: 360, durationMin: 60)];
      expect(
        RoutineClock.plan(RoutineStartMode.clock, morning, at(12, 0)),
        isNull,
      );
    });

    test('from a block gives that block its full length', () {
      final start = RoutineClock.plan(
        RoutineStartMode.fromBlock,
        day,
        at(7, 30),
        index: 1,
      )!;
      expect(start.index, 1);
      expect(start.offset, Duration.zero);
    });

    test('a full day recommends the clock, a sprint recommends now', () {
      expect(
        RoutineClock.recommended(timed(Templates.standard), at(10, 0)),
        RoutineStartMode.clock,
      );
      expect(
        RoutineClock.recommended(
          timed(Templates.byKey('pomodoro')!),
          at(10, 0),
        ),
        RoutineStartMode.now,
      );
    });
  });

  group('editing time', () {
    test('retime derives every start from the anchor', () {
      expect(RoutineClock.retime(<int>[60, 420, 960], 1320), <int>[
        1320,
        1380,
        360,
      ]);
    });

    test('a move across midnight is the short way round', () {
      expect(RoutineClock.deltaMinutes(10, 1430), 20);
      expect(RoutineClock.deltaMinutes(1430, 10), -20);
      expect(RoutineClock.deltaMinutes(600, 540), 60);
    });
  });

  group('the bot window', () {
    test('holds sixteen blocks from the current one', () {
      final w = RoutineClock.deviceWindow(35, 4);
      expect((w.start, w.end), (4, 20));
    });

    test('shrinks to what is left near the end', () {
      final w = RoutineClock.deviceWindow(35, 30);
      expect((w.start, w.end), (30, 35));
    });

    test('a short routine goes over whole', () {
      final w = RoutineClock.deviceWindow(11, 0);
      expect((w.start, w.end), (0, 11));
    });
  });

  group('joining a block part-way', () {
    final t0 = DateTime(2026, 9, 26, 7, 30);
    const verified = VerificationSnapshot(
      factors: <VerificationFactor, FactorState>{
        VerificationFactor.screenLock: FactorState.holding,
      },
      trackEnabled: true,
    );

    ActiveBlock block({Duration offset = Duration.zero}) => ActiveBlock(
      id: 'b',
      name: 'Study',
      category: 0,
      duration: const Duration(minutes: 60),
      trackEnabled: true,
      startOffset: offset,
    );

    test('the countdown and ring pick up where the clock is', () {
      final e = SessionEngine()
        ..start(block(offset: const Duration(minutes: 45)), t0);
      e.tick(t0, verified);
      expect(e.remaining, const Duration(minutes: 15));
      expect(e.progress, closeTo(0.75, 0.001));
    });

    test('only the time actually run is claimed', () {
      final e = SessionEngine()
        ..start(block(offset: const Duration(minutes: 45)), t0);
      e.tick(t0, verified);
      for (var s = 1; s <= 15 * 60; s++) {
        e.tick(t0.add(Duration(seconds: s)), verified);
      }
      expect(e.state, SessionState.complete);
      expect(
        e.claimed,
        const Duration(minutes: 15),
        reason: 'the 45 minutes before the start were not watched',
      );
      expect(e.verified, const Duration(minutes: 15));
    });
  });
}
