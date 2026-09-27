import 'package:intl/intl.dart';

import 'ff_constants.dart';

/// Formatting helpers. Centralised so the app, the PDF reports and the virtual
/// bot all render a duration the same way.
class FfFormat {
  const FfFormat._();

  /// `MM:SS`, or `H:MM:SS` past an hour. This is the countdown format the
  /// device screen uses.
  static String clock(Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    final h = total.inHours;
    final m = total.inMinutes.remainder(60);
    final s = total.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// Compact human duration: `2h 15m`, `45m`, `30s`.
  static String humanDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Minutes as a headline figure: `4h 12m`.
  static String minutes(int mins) => humanDuration(Duration(minutes: mins));

  /// Minutes since midnight as `05:30`.
  static String timeOfDay(int minutesSinceMidnight) {
    if (minutesSinceMidnight == FfFirmware.sequentialStartMin) {
      return 'Any time';
    }
    final m = minutesSinceMidnight % (24 * 60);
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$h:$mm';
  }

  static final DateFormat _dayMonth = DateFormat('EEEE, d MMM');
  static final DateFormat _shortDate = DateFormat('d MMM');
  static final DateFormat _weekday = DateFormat('EEE');
  static final DateFormat _fullDate = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _wallClock = DateFormat('HH:mm');

  static String dayMonth(DateTime d) => _dayMonth.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);
  static String weekday(DateTime d) => _weekday.format(d);
  static String fullDate(DateTime d) => _fullDate.format(d);
  static String wallClock(DateTime d) => _wallClock.format(d);

  /// `68%` — used constantly for verified-vs-claimed.
  static String percent(double fraction) =>
      '${(fraction.clamp(0, 1) * 100).round()}%';

  /// Verified ÷ claimed, guarding the empty-day divide-by-zero.
  static double ratio(int verified, int claimed) =>
      claimed <= 0 ? 0 : (verified / claimed).clamp(0.0, 1.0);

  /// "Today", "Yesterday", or the date.
  static String relativeDay(DateTime d, {DateTime? now}) {
    final today = FfDates.startOfDay(now ?? DateTime.now());
    final target = FfDates.startOfDay(d);
    final diff = today.difference(target).inDays;
    return switch (diff) {
      0 => 'Today',
      1 => 'Yesterday',
      -1 => 'Tomorrow',
      _ => _shortDate.format(d),
    };
  }
}

/// Day-boundary maths.
///
/// FocusFreak's day does not start at midnight — it starts at
/// [FfApp.dayRolloverHour]. A Night Owl user studying at 01:30 is still having
/// yesterday, and their streak should say so.
class FfDates {
  const FfDates._();

  static DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

  /// The logical day a moment belongs to, honouring the 04:00 rollover.
  static DateTime logicalDay(DateTime t) {
    final shifted = t.subtract(const Duration(hours: FfApp.dayRolloverHour));
    return startOfDay(shifted);
  }

  /// Days since 2026-01-01 — the firmware's `DayLog.date_code`.
  static int dateCode(DateTime day) =>
      startOfDay(day).difference(DateTime(2026, 1, 1)).inDays;

  static DateTime fromDateCode(int code) =>
      DateTime(2026, 1, 1).add(Duration(days: code));

  /// Monday-anchored week start for the logical day of [t].
  static DateTime startOfWeek(DateTime t) {
    final d = logicalDay(t);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static DateTime startOfMonth(DateTime t) {
    final d = logicalDay(t);
    return DateTime(d.year, d.month);
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Inclusive list of logical days in `[from, to]`.
  static List<DateTime> daysBetween(DateTime from, DateTime to) {
    final start = startOfDay(from);
    final end = startOfDay(to);
    final out = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }
}
