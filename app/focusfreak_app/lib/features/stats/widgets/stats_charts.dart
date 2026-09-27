import 'package:flutter/material.dart';

import '../../../core/ff_format.dart';
import '../../../design/ff_colors.dart';
import '../../../design/ff_theme.dart';
import '../../../design/ff_tokens.dart';
import '../../../design/ff_typography.dart';
import '../../../domain/engine/streak_engine.dart';

/// Verified against claimed, one pair of bars per day.
///
/// The claimed bar is drawn *behind* the verified one at the same x, so the
/// unverified remainder reads as a gap rather than as a second quantity. The
/// point of the chart is the difference, not two numbers side by side.
class VerifiedVsClaimedChart extends StatelessWidget {
  const VerifiedVsClaimedChart({
    super.key,
    required this.days,
    this.height = 160,
  });

  final List<DaySummary> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    if (days.isEmpty) return SizedBox(height: height);

    final max = days
        .map((d) => d.claimedMin > d.verifiedMin ? d.claimedMin : d.verifiedMin)
        .fold(0, (a, b) => a > b ? a : b);
    final scale = max == 0 ? 1 : max;

    // Past a few weeks, per-day labels stop being readable.
    final labelEvery = (days.length / 7).ceil();

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: days.length > 40 ? 0.5 : 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final claimedH =
                              c.maxHeight * days[i].claimedMin / scale;
                          final verifiedH =
                              c.maxHeight * days[i].verifiedMin / scale;
                          return Stack(
                            alignment: Alignment.bottomCenter,
                            children: <Widget>[
                              Container(
                                height: claimedH,
                                decoration: BoxDecoration(
                                  color: p.claimed.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Container(
                                height: verifiedH,
                                decoration: BoxDecoration(
                                  color: p.verified,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: FfSpace.xs),
                    SizedBox(
                      height: 12,
                      child: i % labelEvery == 0
                          ? FittedBox(
                              child: Text(
                                FfFormat.weekday(days[i].day).substring(0, 1),
                                style: FfType.caption.copyWith(
                                  color: p.textMuted,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A legend that explains the pair, because a bar chart of two overlaid
/// quantities is not self-evident.
class VerifiedLegend extends StatelessWidget {
  const VerifiedLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    Widget swatch(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: FfSpace.sm - 2),
        Text(label, style: FfType.caption.copyWith(color: p.textMuted)),
      ],
    );

    return Row(
      children: <Widget>[
        swatch(p.verified, 'Verified'),
        const SizedBox(width: FfSpace.lg),
        swatch(p.claimed.withValues(alpha: 0.35), 'Claimed'),
      ],
    );
  }
}

/// Verified minutes per category, as a stacked bar plus a key.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({super.key, required this.minutesByCategory});

  final Map<int, int> minutesByCategory;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final total = minutesByCategory.values.fold(0, (a, b) => a + b);

    if (total == 0) {
      return Text(
        'No verified time to break down yet.',
        style: FfType.bodySmall.copyWith(color: p.textMuted),
      );
    }

    final entries =
        FfCategory.values
            .map(
              (c) => MapEntry<FfCategory, int>(c, minutesByCategory[c.id] ?? 0),
            )
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final e in entries)
                  Expanded(
                    flex: e.value,
                    child: ColoredBox(color: e.key.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FfSpace.md),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: FfSpace.sm),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: e.key.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: FfSpace.sm),
                Expanded(
                  child: Text(
                    e.key.label,
                    style: FfType.bodySmall.copyWith(color: p.textSecondary),
                  ),
                ),
                Text(
                  FfFormat.minutes(e.value),
                  style: FfType.caption.copyWith(color: p.textPrimary),
                ),
                const SizedBox(width: FfSpace.sm),
                SizedBox(
                  width: 38,
                  child: Text(
                    FfFormat.percent(e.value / total),
                    textAlign: TextAlign.right,
                    style: FfType.caption.copyWith(color: p.textMuted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// When in the day the verified minutes actually happen.
class HourHistogram extends StatelessWidget {
  const HourHistogram({super.key, required this.minutesByHour});

  final List<int> minutesByHour;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final max = minutesByHour.fold(0, (a, b) => a > b ? a : b);

    if (max == 0) {
      return Text(
        'Not enough data to show when you focus.',
        style: FfType.bodySmall.copyWith(color: p.textMuted),
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: (80 * minutesByHour[h] / max).clamp(2, 80),
                      decoration: BoxDecoration(
                        color: minutesByHour[h] == max
                            ? p.accent
                            : p.verified.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: FfSpace.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (final h in <int>[0, 6, 12, 18, 23])
              Text(
                '${h.toString().padLeft(2, '0')}:00',
                style: FfType.caption.copyWith(color: p.textMuted),
              ),
          ],
        ),
      ],
    );
  }
}

/// A GitHub-style calendar of verified minutes.
class YearHeatmap extends StatelessWidget {
  const YearHeatmap({super.key, required this.days, this.goalMinutes = 240});

  final List<DaySummary> days;

  /// The intensity scale tops out here rather than at the best day, so one
  /// exceptional day does not make every ordinary one look empty.
  final int goalMinutes;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    if (days.isEmpty) return const SizedBox.shrink();

    final byDay = <DateTime, DaySummary>{
      for (final d in days) FfDates.startOfDay(d.day): d,
    };

    // Whole weeks, Monday-anchored, so the columns line up.
    final last = FfDates.startOfDay(days.last.day);
    final firstRaw = FfDates.startOfDay(days.first.day);
    final first = firstRaw.subtract(Duration(days: firstRaw.weekday - 1));

    final weeks = <List<DateTime?>>[];
    var cursor = first;
    while (!cursor.isAfter(last)) {
      final week = <DateTime?>[];
      for (var i = 0; i < 7; i++) {
        week.add(cursor.isAfter(last) ? null : cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final week in weeks)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Column(
                    children: <Widget>[
                      for (final day in week)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: _Cell(
                            day: day,
                            summary: day == null ? null : byDay[day],
                            goalMinutes: goalMinutes,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: FfSpace.sm),
        Row(
          children: <Widget>[
            Text('Less', style: FfType.caption.copyWith(color: p.textMuted)),
            const SizedBox(width: FfSpace.sm),
            for (final level in <double>[0, 0.25, 0.5, 0.75, 1])
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: _colourFor(context, level),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: FfSpace.sm - 3),
            Text('More', style: FfType.caption.copyWith(color: p.textMuted)),
          ],
        ),
      ],
    );
  }

  static Color _colourFor(BuildContext context, double intensity) {
    final p = context.ff;
    if (intensity <= 0) return p.surfaceRaised;
    return Color.lerp(
      p.verified.withValues(alpha: 0.22),
      p.verified,
      intensity,
    )!;
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.summary,
    required this.goalMinutes,
  });

  final DateTime? day;
  final DaySummary? summary;
  final int goalMinutes;

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox(width: 11, height: 11);

    final minutes = summary?.verifiedMin ?? 0;
    final intensity = goalMinutes == 0
        ? 0.0
        : (minutes / goalMinutes).clamp(0.0, 1.0);

    return Tooltip(
      message:
          '${FfFormat.shortDate(day!)} · '
          '${minutes == 0 ? 'nothing verified' : FfFormat.minutes(minutes)}',
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: YearHeatmap._colourFor(context, intensity),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
