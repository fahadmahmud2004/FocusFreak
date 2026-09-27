import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/domain/engine/insight_engine.dart';
import 'package:focusfreak_app/domain/engine/streak_engine.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/features/reports/report_builder.dart';

void main() {
  // The builder loads the logo from the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  const builder = ReportBuilder();
  final from = DateTime(2026, 7, 27);
  final to = DateTime(2026, 8, 2);

  Session session(
    int dayOffset,
    String name, {
    int verifiedSec = 5400,
    int claimedSec = 5400,
    int category = 0,
    int violations = 0,
    Provenance provenance = Provenance.sensorVerified,
  }) => Session(
    id: 's$dayOffset$name',
    startedAt: from.add(Duration(days: dayOffset, hours: 9)),
    endedAt: from.add(Duration(days: dayOffset, hours: 10, minutes: 30)),
    logicalDay: from.add(Duration(days: dayOffset)),
    blockName: name,
    category: category,
    plannedSec: 5400,
    claimedSec: claimedSec,
    verifiedSec: verifiedSec,
    finalState: SessionState.complete.index,
    provenance: provenance.index,
    factorMask: 7,
    trackEnabled: true,
    violations: violations,
  );

  List<DaySummary> week() => <DaySummary>[
    for (var i = 0; i < 7; i++)
      DaySummary(
        day: from.add(Duration(days: i)),
        verifiedMin: i == 3 ? 0 : 60 + i * 20,
        claimedMin: i == 3 ? 0 : 90 + i * 20,
        blocksDone: i == 3 ? 0 : 1,
        blocksTotal: 1,
        violations: i.isEven ? 1 : 0,
      ),
  ];

  Future<List<int>> buildReport({
    List<DaySummary>? days,
    List<Session>? sessions,
    List<Insight> insights = const <Insight>[],
    String owner = '',
  }) => builder.build(
    title: 'Weekly focus report',
    owner: owner,
    from: from,
    to: to,
    days: days ?? week(),
    sessions:
        sessions ??
        <Session>[
          session(0, 'Deep Work 1'),
          session(1, 'Deep Work 2', violations: 2, verifiedSec: 3600),
          session(2, 'Output', category: 2, provenance: Provenance.appVerified),
          session(
            4,
            'Break',
            category: 4,
            verifiedSec: 900,
            claimedSec: 900,
            provenance: Provenance.untracked,
          ),
        ],
    streak: const StreakResult(
      current: 4,
      best: 11,
      lastQualifyingDay: null,
      freezesUsed: 0,
    ),
    insights: insights,
  );

  group('PDF output', () {
    test('produces a valid, non-trivial PDF', () async {
      final bytes = await buildReport();

      expect(bytes, isNotEmpty);
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: 'the file must actually be a PDF',
      );
      expect(
        bytes.length,
        greaterThan(3000),
        reason: 'a report this small would mean the content did not render',
      );
    });

    test('handles an entirely empty period without throwing', () async {
      final bytes = await buildReport(
        days: <DaySummary>[
          for (var i = 0; i < 7; i++)
            DaySummary(day: from.add(Duration(days: i))),
        ],
        sessions: const <Session>[],
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('handles a single day', () async {
      final bytes = await builder.build(
        title: 'Daily focus report',
        from: to,
        to: to,
        days: <DaySummary>[
          DaySummary(
            day: to,
            verifiedMin: 82,
            claimedMin: 90,
            blocksDone: 1,
            blocksTotal: 1,
          ),
        ],
        sessions: <Session>[session(6, 'Deep Work 1')],
        streak: StreakResult.empty,
        insights: const <Insight>[],
      );
      expect(bytes, isNotEmpty);
    });

    test('includes the insight block when there is one', () async {
      final withInsights = await buildReport(
        insights: const <Insight>[
          Insight(
            text: 'You verified 68% of your claimed time.',
            kind: InsightKind.fact,
          ),
        ],
      );
      final without = await buildReport();

      expect(
        withInsights.length,
        greaterThan(without.length),
        reason: 'the insight panel should add content',
      );
    });

    test('a long period still renders', () async {
      final bytes = await buildReport(
        days: <DaySummary>[
          for (var i = 0; i < 90; i++)
            DaySummary(
              day: from.add(Duration(days: i)),
              verifiedMin: 60 + (i % 7) * 15,
              claimedMin: 90 + (i % 7) * 15,
              blocksDone: 1,
              blocksTotal: 1,
            ),
        ],
        sessions: <Session>[
          for (var i = 0; i < 90; i++) session(i, 'Block $i'),
        ],
      );
      expect(bytes, isNotEmpty);
      expect(
        bytes.length,
        greaterThan(10000),
        reason: '90 days of blocks should span several pages',
      );
    });

    test('a name on it makes it a document rather than a printout', () async {
      // Whose record this is. The PDF has built-in Helvetica metrics, so the
      // name is passed through the same ASCII mapper as every block name.
      final named = await buildReport(owner: 'Fahad Mahmud');
      final anonymous = await buildReport();

      expect(named, isNotEmpty);
      expect(
        named.length,
        isNot(anonymous.length),
        reason: 'the name should actually reach the page',
      );
    });

    test('no name is not an empty line', () async {
      expect(await buildReport(owner: '   '), isNotEmpty);
    });

    test('a zero-duration day does not divide by zero', () async {
      final bytes = await buildReport(
        days: <DaySummary>[DaySummary(day: from, blocksTotal: 1)],
        sessions: <Session>[session(0, 'Empty', verifiedSec: 0, claimedSec: 0)],
      );
      expect(bytes, isNotEmpty);
    });
  });
}
