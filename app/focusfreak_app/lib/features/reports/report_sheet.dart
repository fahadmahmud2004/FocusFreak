import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../app/providers.dart';
import '../../core/ff_format.dart';
import '../../data/repo/settings_repository.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/engine/insight_engine.dart';
import '../../domain/engine/streak_engine.dart';
import 'report_builder.dart';

/// What span a report covers.
enum ReportSpan {
  today('Today', 1),
  week('Last 7 days', 7),
  month('Last 30 days', 30),
  quarter('Last 90 days', 90),
  all('Everything', 0);

  const ReportSpan(this.label, this.days);

  final String label;
  final int days;
}

/// Generate and share a PDF.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key});

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportSpan _span = ReportSpan.week;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FfSpace.gutter,
        FfSpace.sm,
        FfSpace.gutter,
        FfSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Export a report',
            style: FfType.titleMedium.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: FfSpace.xxs),
          Text(
            'A PDF of the period, including the blocks you did not finish. '
            'Nothing leaves your phone until you share it.',
            style: FfType.bodySmall.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: FfSpace.lg),

          Wrap(
            spacing: FfSpace.sm,
            runSpacing: FfSpace.sm,
            children: <Widget>[
              for (final s in ReportSpan.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: s == _span,
                  onSelected: _busy ? null : (_) => setState(() => _span = s),
                ),
            ],
          ),

          if (_error != null) ...<Widget>[
            const SizedBox(height: FfSpace.lg),
            Text(_error!, style: FfType.bodySmall.copyWith(color: p.broken)),
          ],

          const SizedBox(height: FfSpace.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _generate(preview: true),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: FfSpace.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _generate(preview: false),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(_busy ? 'Building…' : 'Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generate({required bool preview}) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(sessionRepositoryProvider);
      final now = DateTime.now();
      final to = FfDates.logicalDay(now);

      final stored = await repo.daySummaries();
      final from = _span.days == 0
          ? (stored.isEmpty ? to : FfDates.startOfDay(stored.first.day))
          : to.subtract(Duration(days: _span.days - 1));

      final byDay = <DateTime, DaySummary>{
        for (final d in stored) FfDates.startOfDay(d.day): d,
      };
      final days = <DaySummary>[
        for (final day in FfDates.daysBetween(from, to))
          byDay[day] ?? DaySummary(day: day),
      ];

      final sessions = await repo.range(from, to);
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

      final bytes = await const ReportBuilder().build(
        title: _title(),
        owner: await ref
            .read(settingsRepositoryProvider)
            .getString(SettingKey.userName),
        from: from,
        to: to,
        days: days,
        sessions: sessions,
        streak: streak,
        insights: insights,
      );

      if (!mounted) return;

      if (preview) {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: _filename());
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not build the report: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _title() => switch (_span) {
    ReportSpan.today => 'Daily focus report',
    ReportSpan.week => 'Weekly focus report',
    ReportSpan.month => 'Monthly focus report',
    ReportSpan.quarter => '90-day focus report',
    ReportSpan.all => 'Complete focus record',
  };

  String _filename() {
    final stamp = DateTime.now().toIso8601String().split('T').first;
    return 'focusfreak-${_span.name}-$stamp.pdf';
  }
}
