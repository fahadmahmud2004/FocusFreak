import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ff_format.dart';
import '../../data/db/database.dart';
import '../../domain/engine/insight_engine.dart';
import '../../domain/engine/streak_engine.dart';

/// The window the stats screen is looking at.
enum StatsRange {
  week('This week', 7),
  month('This month', 30),
  quarter('90 days', 90),
  year('This year', 365),
  all('All time', 0);

  const StatsRange(this.label, this.days);

  final String label;

  /// 0 means "everything".
  final int days;

  DateTime from(DateTime now) => days == 0
      ? DateTime(2026)
      : FfDates.logicalDay(now).subtract(Duration(days: days - 1));
}

final statsRangeProvider = StateProvider<StatsRange>((_) => StatsRange.week);

/// Everything the stats screen renders, computed once.
class StatsData {
  const StatsData({
    required this.range,
    required this.from,
    required this.to,
    required this.days,
    required this.sessions,
    required this.streak,
    required this.insights,
  });

  final StatsRange range;
  final DateTime from;
  final DateTime to;

  /// One entry per day in the window, including days with nothing in them —
  /// a chart that silently omits empty days flatters the user.
  final List<DaySummary> days;

  final List<Session> sessions;
  final StreakResult streak;
  final List<Insight> insights;

  int get verifiedMin => days.fold(0, (s, d) => s + d.verifiedMin);
  int get claimedMin => days.fold(0, (s, d) => s + d.claimedMin);
  int get blocksDone => days.fold(0, (s, d) => s + d.blocksDone);
  int get violations => days.fold(0, (s, d) => s + d.violations);

  double get verifiedRatio => FfFormat.ratio(verifiedMin, claimedMin);

  int get activeDays => days.where((d) => d.claimedMin > 0).length;

  int get bestDayMin => days.isEmpty
      ? 0
      : days.map((d) => d.verifiedMin).reduce((a, b) => a > b ? a : b);

  /// Verified minutes per category, for the breakdown.
  Map<int, int> get byCategory {
    final out = <int, int>{};
    for (final s in sessions) {
      out.update(
        s.category,
        (v) => v + s.verifiedSec ~/ 60,
        ifAbsent: () => s.verifiedSec ~/ 60,
      );
    }
    return out;
  }

  /// Verified minutes per hour of day, 0..23.
  List<int> get byHour {
    final out = List<int>.filled(24, 0);
    for (final s in sessions) {
      out[s.startedAt.hour] += s.verifiedSec ~/ 60;
    }
    return out;
  }

  /// The longest single verified stretch in the window.
  int get longestSessionMin => sessions.isEmpty
      ? 0
      : sessions
            .map((s) => s.verifiedSec ~/ 60)
            .reduce((a, b) => a > b ? a : b);
}

final statsProvider = FutureProvider<StatsData>((ref) async {
  final range = ref.watch(statsRangeProvider);

  // Recompute whenever today's totals move.
  ref.watch(todayLogProvider);

  final repo = ref.watch(sessionRepositoryProvider);
  final now = DateTime.now();
  final to = FfDates.logicalDay(now);
  final from = range.from(now);

  final stored = await repo.daySummaries();
  final byDay = <DateTime, DaySummary>{
    for (final d in stored) FfDates.startOfDay(d.day): d,
  };

  final effectiveFrom = range == StatsRange.all && stored.isNotEmpty
      ? FfDates.startOfDay(stored.first.day)
      : from;

  final days = <DaySummary>[
    for (final day in FfDates.daysBetween(effectiveFrom, to))
      byDay[day] ?? DaySummary(day: day),
  ];

  final sessions = await repo.range(effectiveFrom, to);

  // The streak is a property of the whole history, not of the window — showing
  // a "7-day streak" that only counts the visible week would be nonsense.
  final streak = const StreakEngine().compute(stored, today: now);

  final insights = const InsightEngine().generate(
    days: days,
    sessions: <SessionFacts>[
      for (final s in sessions)
        SessionFacts(
          startedAt: s.startedAt,
          verifiedSec: s.verifiedSec,
          claimedSec: s.claimedSec,
          category: s.category,
          violations: s.violations,
          trackEnabled: s.trackEnabled,
        ),
    ],
    streak: streak,
    now: now,
  );

  return StatsData(
    range: range,
    from: effectiveFrom,
    to: to,
    days: days,
    sessions: sessions,
    streak: streak,
    insights: insights,
  );
});
