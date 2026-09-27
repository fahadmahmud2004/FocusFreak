import '../../core/ff_format.dart';
import 'streak_engine.dart';

/// One thing worth saying about the data.
class Insight {
  const Insight({required this.text, required this.kind, this.priority = 0});

  final String text;
  final InsightKind kind;

  /// Higher wins when only one line has room.
  final int priority;
}

enum InsightKind {
  /// A plain statement of what the numbers say.
  fact,

  /// A pattern worth knowing about.
  pattern,

  /// Something the user might reasonably do next. Never an instruction.
  suggestion,
}

/// One session, reduced to what the insight engine needs.
class SessionFacts {
  const SessionFacts({
    required this.startedAt,
    required this.verifiedSec,
    required this.claimedSec,
    required this.category,
    required this.violations,
    required this.trackEnabled,
  });

  final DateTime startedAt;
  final int verifiedSec;
  final int claimedSec;
  final int category;
  final int violations;
  final bool trackEnabled;
}

/// Turns the data into short, factual sentences.
///
/// Three rules, and they are the product's tone in miniature:
///
///  * **Never shame.** No "you only managed", no "you failed to". A person who
///    feels judged by their tools stops opening them, and an unopened app has
///    an effect size of zero.
///  * **Never flatter.** No invented streaks, no rounding up, no praise for a
///    bad week. The whole premise is that this app tells the truth about your
///    time; a cheerful lie here would undo the point of the hardware.
///  * **Never claim what the data cannot support.** Below a minimum sample,
///    the engine says nothing rather than reading noise as a pattern.
class InsightEngine {
  const InsightEngine();

  /// Below this many sessions, hour-of-day and category patterns are noise.
  static const int _minSessionsForPattern = 8;

  /// Consecutive hard days before a lighter one is worth suggesting.
  static const int _deloadAfterDays = 6;

  /// A day counts as "hard" past this many verified minutes.
  static const int _hardDayMinutes = 240;

  List<Insight> generate({
    required List<DaySummary> days,
    required List<SessionFacts> sessions,
    required StreakResult streak,
    DateTime? now,
  }) {
    final out = <Insight>[];
    final today = now ?? DateTime.now();

    final verified = days.fold(0, (s, d) => s + d.verifiedMin);
    final claimed = days.fold(0, (s, d) => s + d.claimedMin);

    if (claimed == 0) {
      return const <Insight>[
        Insight(
          text:
              'Nothing tracked yet. Verified minutes are the ones you can '
              'prove. The gap between verified and claimed is the number '
              'worth watching.',
          kind: InsightKind.fact,
          priority: 100,
        ),
      ];
    }

    // The headline. Always first, because it is the product's whole claim.
    final ratio = FfFormat.ratio(verified, claimed);
    out.add(
      Insight(
        text:
            'You verified ${FfFormat.percent(ratio)} of your claimed time '
            '(${FfFormat.minutes(verified)} of ${FfFormat.minutes(claimed)}).',
        kind: InsightKind.fact,
        priority: 90,
      ),
    );

    _addBestHours(out, sessions);
    _addCategoryShape(out, sessions);
    _addViolationPattern(out, sessions);
    _addStreak(out, streak);
    _addDeload(out, days, today);
    _addConsistency(out, days);

    out.sort((a, b) => b.priority.compareTo(a.priority));
    return out;
  }

  /// The single line for a dashboard.
  Insight? headline({
    required List<DaySummary> days,
    required List<SessionFacts> sessions,
    required StreakResult streak,
    DateTime? now,
  }) {
    final all = generate(
      days: days,
      sessions: sessions,
      streak: streak,
      now: now,
    );
    return all.isEmpty ? null : all.first;
  }

  // --- individual observations --------------------------------------------------

  void _addBestHours(List<Insight> out, List<SessionFacts> sessions) {
    final tracked = sessions.where((s) => s.trackEnabled).toList();
    if (tracked.length < _minSessionsForPattern) return;

    // Verified seconds per hour of day.
    final byHour = <int, int>{};
    for (final s in tracked) {
      byHour.update(
        s.startedAt.hour,
        (v) => v + s.verifiedSec,
        ifAbsent: () => s.verifiedSec,
      );
    }
    if (byHour.length < 3) return;

    final ranked = byHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    if (best.value == 0) return;

    // Only worth saying if the peak is genuinely a peak.
    final total = byHour.values.fold(0, (s, v) => s + v);
    if (best.value / total < 0.25) return;

    final from = best.key.toString().padLeft(2, '0');
    final to = ((best.key + 1) % 24).toString().padLeft(2, '0');
    out.add(
      Insight(
        text: 'Your most verified hour is $from:00 to $to:00.',
        kind: InsightKind.pattern,
        priority: 70,
      ),
    );
  }

  void _addCategoryShape(List<Insight> out, List<SessionFacts> sessions) {
    if (sessions.length < _minSessionsForPattern) return;

    final byCategory = <int, int>{};
    for (final s in sessions) {
      byCategory.update(
        s.category,
        (v) => v + s.verifiedSec,
        ifAbsent: () => s.verifiedSec,
      );
    }
    final total = byCategory.values.fold(0, (s, v) => s + v);
    if (total == 0) return;

    final deep = byCategory[0] ?? 0;
    final share = deep / total;

    // Reported either way, without a verdict attached. What counts as the right
    // amount of deep work is the user's call, not the app's.
    out.add(
      Insight(
        text: 'Deep Work is ${FfFormat.percent(share)} of your verified time.',
        kind: InsightKind.pattern,
        priority: 50,
      ),
    );
  }

  void _addViolationPattern(List<Insight> out, List<SessionFacts> sessions) {
    final tracked = sessions.where((s) => s.trackEnabled).toList();
    if (tracked.length < _minSessionsForPattern) return;

    final withViolations = tracked.where((s) => s.violations > 0).length;
    if (withViolations == 0) {
      out.add(
        const Insight(
          text: 'No interruptions in any tracked block.',
          kind: InsightKind.fact,
          priority: 60,
        ),
      );
      return;
    }

    final share = withViolations / tracked.length;
    out.add(
      Insight(
        text:
            '${FfFormat.percent(share)} of your tracked blocks were '
            'interrupted at least once.',
        kind: InsightKind.pattern,
        priority: 55,
      ),
    );
  }

  void _addStreak(List<Insight> out, StreakResult streak) {
    if (streak.current <= 1) return;

    if (streak.freezesUsed > 0) {
      out.add(
        Insight(
          text: '${streak.current}-day streak, with one missed day absorbed.',
          kind: InsightKind.fact,
          priority: 65,
        ),
      );
      return;
    }

    out.add(
      Insight(
        text:
            '${streak.current} days in a row'
            '${streak.best > streak.current ? ' (best ${streak.best})' : ''}.',
        kind: InsightKind.fact,
        priority: 65,
      ),
    );
  }

  void _addDeload(List<Insight> out, List<DaySummary> days, DateTime now) {
    final recent = days.where((d) => d.qualifies).toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    if (recent.length < _deloadAfterDays) return;

    // Strictly consecutive. Unlike a streak, this has no freeze: a day off in
    // the middle is exactly the rest that makes the suggestion unnecessary.
    var consecutiveHard = 0;
    DateTime? expected;

    for (final d in recent) {
      final day = FfDates.startOfDay(d.day);

      if (expected == null) {
        // The run may start today or yesterday — at midday today's blocks may
        // simply not have happened yet.
        final today = FfDates.logicalDay(now);
        if (day != today && day != today.subtract(const Duration(days: 1))) {
          return;
        }
      } else if (day != expected) {
        break;
      }

      if (d.verifiedMin < _hardDayMinutes) break;
      consecutiveHard++;
      expected = day.subtract(const Duration(days: 1));
    }

    if (consecutiveHard >= _deloadAfterDays) {
      // Offered, not prescribed.
      out.add(
        Insight(
          text:
              '$consecutiveHard hard days in a row. The Deload template is '
              'one tap away if you want it.',
          kind: InsightKind.suggestion,
          priority: 80,
        ),
      );
    }
  }

  void _addConsistency(List<Insight> out, List<DaySummary> days) {
    final active = days.where((d) => d.claimedMin > 0).toList();
    if (active.length < 5) return;

    final verified = active.map((d) => d.verifiedMin).toList()..sort();
    final median = verified[verified.length ~/ 2];
    if (median == 0) return;

    final best = verified.last;
    // A big gap between the median and the best day says the good days are
    // outliers rather than the norm. Stated as an observation, not a failing.
    if (best > median * 2) {
      out.add(
        Insight(
          text:
              'Your best day (${FfFormat.minutes(best)}) is well above your '
              'typical day (${FfFormat.minutes(median)}).',
          kind: InsightKind.pattern,
          priority: 40,
        ),
      );
    }
  }
}
