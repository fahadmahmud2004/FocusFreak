import '../../core/ff_format.dart';

/// One day's summary. Mirrors the firmware `DayLog` struct.
class DaySummary {
  const DaySummary({
    required this.day,
    this.verifiedMin = 0,
    this.claimedMin = 0,
    this.blocksDone = 0,
    this.blocksTotal = 0,
    this.violations = 0,
  });

  /// Logical day (04:00 rollover already applied).
  final DateTime day;

  final int verifiedMin;
  final int claimedMin;
  final int blocksDone;
  final int blocksTotal;
  final int violations;

  /// A day counts toward a streak when at least one tracked block was
  /// completed — the definition in `docs/APP_SPEC.md`.
  bool get qualifies => blocksDone > 0 && verifiedMin > 0;

  double get verifiedRatio => FfFormat.ratio(verifiedMin, claimedMin);
}

class StreakResult {
  const StreakResult({
    required this.current,
    required this.best,
    required this.lastQualifyingDay,
    required this.freezesUsed,
  });

  final int current;
  final int best;
  final DateTime? lastQualifyingDay;

  /// How many single-day gaps the current streak has absorbed.
  final int freezesUsed;

  static const StreakResult empty = StreakResult(
    current: 0,
    best: 0,
    lastQualifyingDay: null,
    freezesUsed: 0,
  );
}

/// Streak arithmetic.
///
/// One deliberate softening: a single missed day does not reset the streak, it
/// spends a *freeze*, and only one freeze may be outstanding at a time. A
/// person who studies eleven days straight and then gets ill has not undone
/// eleven days of work, and a counter that says otherwise teaches them to stop
/// trusting the counter.
///
/// Two missed days in a row still resets. The streak has to mean something.
class StreakEngine {
  const StreakEngine({this.allowFreeze = true});

  /// Set false for the strict definition the device uses in EEPROM.
  final bool allowFreeze;

  /// Compute from a full history. [days] may be in any order and may contain
  /// gaps; only qualifying days matter.
  StreakResult compute(Iterable<DaySummary> days, {DateTime? today}) {
    final qualifying =
        days
            .where((d) => d.qualifies)
            .map((d) => FfDates.startOfDay(d.day))
            .toSet()
            .toList()
          ..sort();

    if (qualifying.isEmpty) return StreakResult.empty;

    // Longest run anywhere in history, for "best".
    var best = 1;
    var run = 1;
    for (var i = 1; i < qualifying.length; i++) {
      final gap = qualifying[i].difference(qualifying[i - 1]).inDays;
      if (gap == 1 || (allowFreeze && gap == 2)) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
    }

    // Current run, walking backwards from the most recent qualifying day.
    final now = FfDates.logicalDay(today ?? DateTime.now());
    final last = qualifying.last;
    final sinceLast = now.difference(last).inDays;

    // The streak is alive if today qualifies, or yesterday did, or — with a
    // freeze available — the day before that.
    final maxIdle = allowFreeze ? 2 : 1;
    if (sinceLast > maxIdle) {
      return StreakResult(
        current: 0,
        best: best,
        lastQualifyingDay: last,
        freezesUsed: 0,
      );
    }

    var current = 1;
    var freezes = sinceLast == 2 ? 1 : 0;
    for (var i = qualifying.length - 1; i > 0; i--) {
      final gap = qualifying[i].difference(qualifying[i - 1]).inDays;
      if (gap == 1) {
        current++;
      } else if (allowFreeze && gap == 2 && freezes == 0) {
        current++;
        freezes++;
      } else {
        break;
      }
    }

    return StreakResult(
      current: current,
      best: best > current ? best : current,
      lastQualifyingDay: last,
      freezesUsed: freezes,
    );
  }
}
