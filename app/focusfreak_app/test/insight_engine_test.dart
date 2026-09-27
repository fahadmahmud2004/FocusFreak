import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/domain/engine/insight_engine.dart';
import 'package:focusfreak_app/domain/engine/streak_engine.dart';

void main() {
  const engine = InsightEngine();
  final today = DateTime(2026, 8, 2, 12);

  DaySummary day(int daysAgo, {int verified = 90, int claimed = 120}) =>
      DaySummary(
        day: DateTime(2026, 8, 2).subtract(Duration(days: daysAgo)),
        verifiedMin: verified,
        claimedMin: claimed,
        blocksDone: verified > 0 ? 1 : 0,
        blocksTotal: 1,
      );

  SessionFacts session({
    int hour = 9,
    int verifiedSec = 5400,
    int claimedSec = 5400,
    int category = 0,
    int violations = 0,
    bool track = true,
  }) => SessionFacts(
    startedAt: DateTime(2026, 8, 2, hour),
    verifiedSec: verifiedSec,
    claimedSec: claimedSec,
    category: category,
    violations: violations,
    trackEnabled: track,
  );

  List<Insight> run({
    List<DaySummary>? days,
    List<SessionFacts>? sessions,
    StreakResult streak = StreakResult.empty,
  }) => engine.generate(
    days: days ?? <DaySummary>[day(0)],
    sessions: sessions ?? <SessionFacts>[],
    streak: streak,
    now: today,
  );

  group('empty state', () {
    test('says what the metric means rather than showing a zero', () {
      final out = engine.generate(
        days: const <DaySummary>[],
        sessions: const <SessionFacts>[],
        streak: StreakResult.empty,
        now: today,
      );
      expect(out, hasLength(1));
      expect(out.single.text, contains('Nothing tracked yet'));
    });
  });

  group('the headline', () {
    test('always leads with verified versus claimed', () {
      final out = run(days: <DaySummary>[day(0, verified: 68, claimed: 100)]);
      expect(out.first.text, contains('68%'));
      expect(out.first.text, contains('claimed'));
    });

    test('headline() returns the highest-priority line', () {
      final insight = engine.headline(
        days: <DaySummary>[day(0)],
        sessions: <SessionFacts>[],
        streak: StreakResult.empty,
        now: today,
      );
      expect(insight, isNotNull);
      expect(insight!.text, contains('%'));
    });
  });

  group('sample size', () {
    test('says nothing about hour-of-day below the minimum', () {
      final out = run(sessions: <SessionFacts>[session(), session()]);
      expect(
        out.where((i) => i.text.contains('most verified hour')),
        isEmpty,
        reason: 'two sessions is not a pattern, it is noise',
      );
    });

    test('reports a peak hour once there is enough data', () {
      final out = run(
        sessions: <SessionFacts>[
          for (var i = 0; i < 8; i++) session(hour: 7),
          session(hour: 14, verifiedSec: 600),
          session(hour: 20, verifiedSec: 600),
        ],
      );
      expect(out.where((i) => i.text.contains('07:00 to 08:00')), hasLength(1));
    });

    test('stays quiet when no hour actually dominates', () {
      final out = run(
        sessions: <SessionFacts>[
          for (var h = 6; h < 16; h++) session(hour: h, verifiedSec: 3600),
        ],
      );
      expect(
        out.where((i) => i.text.contains('most verified hour')),
        isEmpty,
        reason: 'an even spread has no peak worth reporting',
      );
    });
  });

  group('violations', () {
    test('a clean run is stated plainly, without praise', () {
      final out = run(
        sessions: <SessionFacts>[for (var i = 0; i < 10; i++) session()],
      );
      final line = out.firstWhere((i) => i.text.contains('interrupt'));
      expect(line.text, 'No interruptions in any tracked block.');
      expect(line.text, isNot(contains('!')));
    });

    test('interruptions are counted, not editorialised', () {
      final out = run(
        sessions: <SessionFacts>[
          for (var i = 0; i < 5; i++) session(violations: 1),
          for (var i = 0; i < 5; i++) session(),
        ],
      );
      final line = out.firstWhere((i) => i.text.contains('interrupted'));
      expect(line.text, contains('50%'));
    });

    test('untracked sessions are excluded from the violation rate', () {
      final out = run(
        sessions: <SessionFacts>[
          for (var i = 0; i < 10; i++) session(track: true),
          for (var i = 0; i < 50; i++) session(track: false, violations: 1),
        ],
      );
      final line = out.firstWhere((i) => i.text.contains('interrupt'));
      expect(
        line.text,
        'No interruptions in any tracked block.',
        reason: 'an untracked block cannot be violated',
      );
    });
  });

  group('deload', () {
    test('suggests a lighter day after six hard ones', () {
      final out = run(
        days: <DaySummary>[
          for (var i = 0; i < 7; i++) day(i, verified: 300, claimed: 360),
        ],
      );
      final line = out.firstWhere((i) => i.kind == InsightKind.suggestion);
      expect(line.text, contains('Deload'));
      expect(
        line.text,
        contains('if you want it'),
        reason: 'offered, never prescribed',
      );
    });

    test('does not suggest deload after light days', () {
      final out = run(
        days: <DaySummary>[
          for (var i = 0; i < 7; i++) day(i, verified: 60, claimed: 90),
        ],
      );
      expect(out.where((i) => i.kind == InsightKind.suggestion), isEmpty);
    });

    test('a gap in the run stops the count', () {
      final out = run(
        days: <DaySummary>[
          for (var i = 0; i < 3; i++) day(i, verified: 300, claimed: 360),
          // day 3 missing entirely
          for (var i = 4; i < 8; i++) day(i, verified: 300, claimed: 360),
        ],
      );
      expect(out.where((i) => i.text.contains('Deload')), isEmpty);
    });
  });

  group('tone', () {
    test('never shames and never over-praises', () {
      final out = run(
        days: <DaySummary>[
          for (var i = 0; i < 10; i++) day(i, verified: 20, claimed: 300),
        ],
        sessions: <SessionFacts>[
          for (var i = 0; i < 12; i++) session(violations: 2),
        ],
        streak: const StreakResult(
          current: 3,
          best: 9,
          lastQualifyingDay: null,
          freezesUsed: 0,
        ),
      );

      const banned = <String>[
        'only',
        'failed',
        'poor',
        'bad',
        'should',
        'must',
        'disappoint',
        'wasted',
        'lazy',
        'great job',
        'amazing',
        'crushed',
      ];
      for (final insight in out) {
        final lower = insight.text.toLowerCase();
        for (final word in banned) {
          expect(
            lower,
            isNot(contains(word)),
            reason: '"${insight.text}" uses "$word"',
          );
        }
        expect(insight.text, isNot(contains('!')));
      }
    });
  });

  group('streak', () {
    test('mentions an absorbed day rather than hiding it', () {
      final out = run(
        streak: const StreakResult(
          current: 5,
          best: 5,
          lastQualifyingDay: null,
          freezesUsed: 1,
        ),
      );
      final line = out.firstWhere((i) => i.text.contains('streak'));
      expect(
        line.text,
        contains('absorbed'),
        reason: 'a freeze the user does not know about is a lie by omission',
      );
    });

    test('says nothing about a streak of one', () {
      final out = run(
        streak: const StreakResult(
          current: 1,
          best: 1,
          lastQualifyingDay: null,
          freezesUsed: 0,
        ),
      );
      expect(out.where((i) => i.text.contains('in a row')), isEmpty);
    });
  });
}
