import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ff_format.dart';
import '../../design/ff_colors.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/engine/session_engine.dart';
import 'session_controller.dart';

/// Start a one-off block without touching a routine.
///
/// The escape hatch that keeps the app usable on a day that does not go to
/// plan. It still records a real session, with the same verification rules, so
/// an unplanned hour of work still counts.
class QuickTimerSheet extends ConsumerStatefulWidget {
  const QuickTimerSheet({super.key});

  @override
  ConsumerState<QuickTimerSheet> createState() => _QuickTimerSheetState();
}

class _QuickTimerSheetState extends ConsumerState<QuickTimerSheet> {
  int _minutes = 25;
  int _category = 0;
  bool _track = true;
  final TextEditingController _name = TextEditingController(text: 'Focus');

  static const List<int> _presets = <int>[15, 25, 45, 52, 90];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ff;

    return Padding(
      padding: EdgeInsets.only(
        left: FfSpace.gutter,
        right: FfSpace.gutter,
        top: FfSpace.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + FfSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Quick timer',
            style: FfType.titleMedium.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: FfSpace.lg),

          TextField(
            controller: _name,
            maxLength: 16,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'What are you doing?'),
          ),

          const SizedBox(height: FfSpace.md),
          Center(
            child: Text(
              FfFormat.minutes(_minutes),
              style: FfType.countdownLg.copyWith(color: p.textPrimary),
            ),
          ),
          const SizedBox(height: FfSpace.md),
          Wrap(
            spacing: FfSpace.sm,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final m in _presets)
                ChoiceChip(
                  label: Text('${m}m'),
                  selected: _minutes == m,
                  onSelected: (_) => setState(() => _minutes = m),
                ),
            ],
          ),
          Slider(
            value: _minutes.toDouble(),
            min: 5,
            max: 180,
            divisions: 35,
            onChanged: (v) => setState(() => _minutes = v.round()),
          ),

          const SizedBox(height: FfSpace.sm),
          Wrap(
            spacing: FfSpace.sm,
            runSpacing: FfSpace.sm,
            children: <Widget>[
              for (final c in FfCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _category == c.id,
                  selectedColor: c.color.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: _category == c.id ? c.color : p.border,
                  ),
                  onSelected: (_) => setState(() => _category = c.id),
                ),
            ],
          ),

          const SizedBox(height: FfSpace.sm),
          SwitchListTile(
            value: _track,
            onChanged: (v) => setState(() => _track = v),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Track this block',
              style: FfType.titleSmall.copyWith(color: p.textPrimary),
            ),
            subtitle: Text(
              _track
                  ? 'Minutes count only while verification holds'
                  : 'A plain timer',
              style: FfType.caption.copyWith(color: p.textMuted),
            ),
          ),

          const SizedBox(height: FfSpace.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }

  void _start() {
    final name = _name.text.trim();
    ref
        .read(sessionControllerProvider.notifier)
        .startBlock(
          ActiveBlock(
            id: 'quick-${DateTime.now().millisecondsSinceEpoch}',
            name: name.isEmpty ? 'Focus' : name,
            category: _category,
            duration: Duration(minutes: _minutes),
            trackEnabled: _track,
          ),
        );
    Navigator.of(context).pop(true);
  }
}
