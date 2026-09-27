import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ff_shell.dart';
import '../../core/ff_format.dart';
import '../../design/components/ff_card.dart';
import '../../design/components/ff_stat_tile.dart';
import '../../design/components/ff_states.dart';
import '../../design/ff_colors.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/engine/insight_engine.dart';
import '../../domain/model/session_state.dart';
import '../reports/report_sheet.dart';
import 'stats_providers.dart';
import 'widgets/stats_charts.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(statsRangeProvider);
    final stats = ref.watch(statsProvider);

    return FfPage(
      title: 'Stats',
      subtitle: range.label,
      actions: <Widget>[
        IconButton(
          tooltip: 'Export a report',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            builder: (_) => const ReportSheet(),
          ),
        ),
        const SizedBox(width: FfSpace.sm),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final r in StatsRange.values) ...<Widget>[
                  ChoiceChip(
                    label: Text(r.label),
                    selected: r == range,
                    onSelected: (_) =>
                        ref.read(statsRangeProvider.notifier).state = r,
                  ),
                  const SizedBox(width: FfSpace.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: FfSpace.lg),
          stats.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(FfSpace.xxxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => FfErrorState(
              message: 'Could not load your stats',
              detail: '$e',
              onRetry: () => ref.invalidate(statsProvider),
            ),
            data: (d) => _Body(data: d),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});

  final StatsData data;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;

    if (data.claimedMin == 0) {
      return const FfEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'Nothing to chart yet',
        message:
            'Run a tracked block and the numbers start here. '
            'Verified against claimed is the pair worth watching.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FfStatGrid(
          tiles: <Widget>[
            FfStatTile(
              label: 'Verified',
              value: FfFormat.minutes(data.verifiedMin),
              secondary:
                  'of ${FfFormat.minutes(data.claimedMin)} claimed · '
                  '${FfFormat.percent(data.verifiedRatio)}',
              valueColor: p.verified,
              icon: Icons.verified_outlined,
            ),
            FfStatTile(
              label: 'Active days',
              value: '${data.activeDays}',
              secondary: 'of ${data.days.length} in range',
              icon: Icons.calendar_today_outlined,
            ),
            FfStatTile(
              label: 'Blocks done',
              value: '${data.blocksDone}',
              secondary: '${data.violations} violations',
              icon: Icons.task_alt_rounded,
            ),
            FfStatTile(
              label: 'Best day',
              value: FfFormat.minutes(data.bestDayMin),
              secondary:
                  'Longest block '
                  '${FfFormat.minutes(data.longestSessionMin)}',
              icon: Icons.trending_up_rounded,
            ),
          ],
        ),

        if (data.insights.isNotEmpty) ...<Widget>[
          const SizedBox(height: FfSpace.xl),
          for (final insight in data.insights.take(3)) ...<Widget>[
            FfInsightLine(
              text: insight.text,
              icon: switch (insight.kind) {
                InsightKind.fact => Icons.insights_rounded,
                InsightKind.pattern => Icons.timeline_rounded,
                InsightKind.suggestion => Icons.lightbulb_outline_rounded,
              },
            ),
            const SizedBox(height: FfSpace.sm),
          ],
        ],

        const SizedBox(height: FfSpace.lg),
        FfSection(
          title: 'Verified vs claimed',
          subtitle: 'The gap is the part you could not prove.',
          children: <Widget>[
            FfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  VerifiedVsClaimedChart(days: data.days),
                  const SizedBox(height: FfSpace.md),
                  const VerifiedLegend(),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: FfSpace.xl),
        FfSection(
          title: 'Where the time went',
          children: <Widget>[
            FfCard(
              child: CategoryBreakdown(minutesByCategory: data.byCategory),
            ),
          ],
        ),

        const SizedBox(height: FfSpace.xl),
        FfSection(
          title: 'When you focus',
          subtitle: 'Verified minutes by hour of day.',
          children: <Widget>[
            FfCard(child: HourHistogram(minutesByHour: data.byHour)),
          ],
        ),

        if (data.days.length > 14) ...<Widget>[
          const SizedBox(height: FfSpace.xl),
          FfSection(
            title: 'Calendar',
            children: <Widget>[FfCard(child: YearHeatmap(days: data.days))],
          ),
        ],

        const SizedBox(height: FfSpace.xl),
        _SessionLog(data: data),
      ],
    );
  }
}

/// The individual blocks, newest first. The evidence behind every chart above.
class _SessionLog extends StatelessWidget {
  const _SessionLog({required this.data});

  final StatsData data;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final sessions = data.sessions.reversed.take(30).toList();
    if (sessions.isEmpty) return const SizedBox.shrink();

    return FfSection(
      title: 'Blocks',
      subtitle: sessions.length < data.sessions.length
          ? 'Most recent ${sessions.length} of ${data.sessions.length}'
          : '${sessions.length} in range',
      children: <Widget>[
        for (final s in sessions)
          FfCard(
            accent: FfColors.category(s.category),
            padding: const EdgeInsets.symmetric(
              horizontal: FfSpace.md,
              vertical: FfSpace.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        s.blockName,
                        style: FfType.titleSmall.copyWith(color: p.textPrimary),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${FfFormat.relativeDay(s.startedAt)} '
                        '${FfFormat.wallClock(s.startedAt)} · '
                        '${Provenance.values[s.provenance].label}'
                        '${s.violations > 0 ? ' · ${s.violations} interruption'
                                  '${s.violations == 1 ? '' : 's'}' : ''}',
                        style: FfType.caption.copyWith(color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      FfFormat.minutes(s.verifiedSec ~/ 60),
                      style: FfType.titleSmall.copyWith(
                        color: s.verifiedSec > 0 ? p.verified : p.textMuted,
                      ),
                    ),
                    Text(
                      'of ${FfFormat.minutes(s.claimedSec ~/ 60)}',
                      style: FfType.caption.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
