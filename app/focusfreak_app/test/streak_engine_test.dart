import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/domain/engine/streak_engine.dart';

void main() {
  final today = DateTime(2026, 8, 2, 12);

  DaySummary day(int daysAgo, {bool good = true}) => DaySummary(
    day: DateTime(2026, 8, 2).subtract(Duration(days: daysAgo)),
    verifiedMin: good ? 90 : 0,
    claimedMin: good ? 120 : 0,
    blocksDone: good ? 1 : 0,
    blocksTotal: 1,
  );

  group('qualification', () {
    final d = DateTime(2026, 8, 2);

    test('a day needs a completed block AND verified minutes', () {
      expect(
        DaySummary(day: d, blocksDone: 1, verifiedMin: 30).qualifies,
        isTrue,
      );
      expect(
        DaySummary(day: d, blocksDone: 1).qualifies,
        isFalse,
        reason: 'zero verified minutes is not a study day',
      );
      expect(
        DaySummary(day: d, verifiedMin: 30).qualifies,
        isFalse,
        reason: 'verified minutes with no completed block is a partial day',
      );
    });
  });

  group('current streak', () {
    test('empty history is zero, not an error', () {
      expect(const StreakEngine().compute(<DaySummary>[]).current, 0);
    });

    test('counts consecutive qualifying days', () {
      final r = const StreakEngine().compute(<DaySummary>[
        day(0),
        day(1),
        day(2),
        day(3),
      ], today: today);
      expect(r.current, 4);
    });

    test('an unqualifying day in the middle spends the freeze', () {
      final r = const StreakEngine().compute(<DaySummary>[
        day(0),
        day(1),
        day(2, good: false),
        day(3),
        day(4),
      ], today: today);
      expect(
        r.current,
        4,
        reason: 'days 0,1,3,4 chain because the freeze absorbs day 2',
      );
      expect(r.freezesUsed, 1);
    });

    test('strict mode stops at the same gap', () {
      final r = const StreakEngine(allowFreeze: false).compute(<DaySummary>[
        day(0),
        day(1),
        day(2, good: false),
        day(3),
        day(4),
      ], today: today);
      expect(r.current, 2);
    });

    test('yesterday still counts — the day is not over', () {
      final r = const StreakEngine().compute(<DaySummary>[
        day(1),
        day(2),
      ], today: today);
      expect(r.current, 2);
    });

    test('two missed days resets', () {
      final r = const StreakEngine().compute(<DaySummary>[
        day(3),
        day(4),
        day(5),
      ], today: today);
      expect(r.current, 0);
      expect(r.best, 3, reason: 'history is preserved even when the run ends');
    });
  });

  group('the freeze', () {
    test('one missed day is absorbed', () {
      final r = const StreakEngine().compute(<DaySummary>[
        day(0),
        day(1),
        day(3),
        day(4),
      ], today: today);
      expect(r.current, 4);
      expect(r.freezesUsed, 1);
    });

    test('only one freeze may be outstanding', () {
      final r = const StreakEngine().compute(<DaySummary>[
        day(0),
        day(2),
        day(4),
        day(6),
      ], today: today);
      expect(r.current, 2, reason: 'the second gap cannot also be forgiven');
      expect(r.freezesUsed, 1);
    });

    test('strict mode matches the device definition', () {
      final r = const StreakEngine(
        allowFreeze: false,
      ).compute(<DaySummary>[day(0), day(1), day(3), day(4)], today: today);
      expect(r.current, 2);
      expect(r.freezesUsed, 0);
    });
  });

  group('best', () {
    test('remembers the longest run in history', () {
      final r = const StreakEngine(allowFreeze: false).compute(<DaySummary>[
        for (var i = 20; i <= 30; i++) day(i), // an 11-day run long ago
        day(0),
        day(1),
      ], today: today);
      expect(r.current, 2);
      expect(r.best, 11);
    });

    test('best is never below current', () {
      final r = const StreakEngine().compute(<DaySummary>[
        day(0),
        day(1),
        day(2),
      ], today: today);
      expect(r.best, greaterThanOrEqualTo(r.current));
    });
  });

  test('duplicate entries for one day are not double-counted', () {
    final r = const StreakEngine().compute(<DaySummary>[
      day(0),
      day(0),
      day(1),
      day(1),
    ], today: today);
    expect(r.current, 2);
  });
}
