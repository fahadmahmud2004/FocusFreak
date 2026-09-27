import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/ff_format.dart';
import '../../design/components/ff_card.dart';
import '../../design/ff_colors.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/engine/routine_builder.dart';
import '../../domain/model/template.dart';

/// Build a routine from a few answers, with the day previewed as you go.
class BuildRoutineScreen extends ConsumerStatefulWidget {
  const BuildRoutineScreen({super.key});

  @override
  ConsumerState<BuildRoutineScreen> createState() => _BuildRoutineScreenState();
}

class _BuildRoutineScreenState extends ConsumerState<BuildRoutineScreen> {
  late BuilderInput _input = BuilderInput(
    wakeMin: 5 * 60,
    sleepMin: 22 * 60 + 30,
    targetStudyMinutes: 8 * 60,
    season: RoutineSeason.of(DateTime.now()),
  );
  final TextEditingController _name = TextEditingController(text: 'My Routine');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(BuilderInput next) => setState(() => _input = next);

  Future<void> _pickTime(bool wake) async {
    final current = wake ? _input.wakeMin : _input.sleepMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    _set(wake ? _input.copyWith(wakeMin: m) : _input.copyWith(sleepMin: m));
  }

  Future<void> _create(BuiltRoutine built) async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final id = await ref
        .read(routineRepositoryProvider)
        .createFrom(
          name: name,
          description:
              '${FfFormat.minutes(built.studyMinutes)} of study, '
              '${_input.style.label.toLowerCase()} blocks.',
          blocks: built.blocks,
        );
    if (mounted) context.pushReplacement('/plan/routine/$id');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final built = RoutineBuilder.build(_input);
    final hours = _input.targetStudyMinutes / 60;

    return Scaffold(
      backgroundColor: p.surfaceBase,
      appBar: AppBar(title: const Text('Build a routine')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FfSpace.gutter,
            FfSpace.sm,
            FfSpace.gutter,
            FfSpace.xxxl,
          ),
          children: <Widget>[
            TextField(
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: FfSpace.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TimeField(
                    label: 'Wake up',
                    minutes: _input.wakeMin,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: FfSpace.md),
                Expanded(
                  child: _TimeField(
                    label: 'Sleep',
                    minutes: _input.sleepMin,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FfSpace.xl),
            _Label(
              'Study target: ${FfFormat.minutes(_input.targetStudyMinutes)}',
            ),
            Slider(
              value: hours,
              min: 2,
              max: 14,
              divisions: 24,
              label: FfFormat.minutes(_input.targetStudyMinutes),
              onChanged: (v) =>
                  _set(_input.copyWith(targetStudyMinutes: (v * 60).round())),
            ),
            const SizedBox(height: FfSpace.md),
            _Label('Block style'),
            const SizedBox(height: FfSpace.sm),
            SegmentedButton<BuilderStyle>(
              segments: <ButtonSegment<BuilderStyle>>[
                for (final s in BuilderStyle.values)
                  ButtonSegment<BuilderStyle>(
                    value: s,
                    label: Text(s.label),
                    tooltip: s.detail,
                  ),
              ],
              selected: <BuilderStyle>{_input.style},
              onSelectionChanged: (v) => _set(_input.copyWith(style: v.first)),
            ),
            const SizedBox(height: FfSpace.xs),
            Text(
              _input.style.detail,
              style: FfType.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: FfSpace.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _input.includePrayers,
              onChanged: (v) => _set(_input.copyWith(includePrayers: v)),
              title: const Text('Build around salah'),
            ),
            if (_input.includePrayers)
              SegmentedButton<RoutineSeason>(
                segments: <ButtonSegment<RoutineSeason>>[
                  for (final s in RoutineSeason.values)
                    ButtonSegment<RoutineSeason>(
                      value: s,
                      label: Text(s.label),
                    ),
                ],
                selected: <RoutineSeason>{_input.season},
                onSelectionChanged: (v) =>
                    _set(_input.copyWith(season: v.first)),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _input.includeExercise,
              onChanged: (v) => _set(_input.copyWith(includeExercise: v)),
              title: const Text('Exercise or a walk'),
            ),
            const SizedBox(height: FfSpace.lg),
            _Preview(built: built),
            const SizedBox(height: FfSpace.lg),
            FilledButton.icon(
              onPressed: _saving ? null : () => _create(built),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Create routine'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: FfType.titleSmall.copyWith(color: context.ff.textPrimary),
  );
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.minutes,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return FfCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FfSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: FfType.overline.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: FfSpace.xxs),
          Text(
            FfFormat.timeOfDay(minutes),
            style: FfType.titleMedium.copyWith(color: p.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.built});

  final BuiltRoutine built;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final blocks = built.blocks;

    return FfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${FfFormat.minutes(built.studyMinutes)} of study · '
            '${blocks.length} blocks',
            style: FfType.titleSmall.copyWith(color: p.textPrimary),
          ),
          if (built.shortOfTarget) ...<Widget>[
            const SizedBox(height: FfSpace.xs),
            Text(
              'Only ${FfFormat.minutes(built.studyMinutes)} of study fits '
              'between waking and sleep. Wake earlier, sleep later, or aim '
              'lower.',
              style: FfType.caption.copyWith(color: p.paused),
            ),
          ],
          const SizedBox(height: FfSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(FfRadius.pill),
            child: SizedBox(
              height: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final b in blocks)
                    Expanded(
                      flex: b.durationMin,
                      child: ColoredBox(color: FfColors.category(b.category)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FfSpace.md),
          for (final b in blocks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: FfSpace.xxs),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 48,
                    child: Text(
                      FfFormat.timeOfDay(b.startMin!),
                      style: FfType.caption.copyWith(color: p.textMuted),
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 16,
                    color: FfColors.category(b.category),
                  ),
                  const SizedBox(width: FfSpace.sm),
                  Expanded(
                    child: Text(
                      b.name,
                      style: FfType.bodySmall.copyWith(color: p.textSecondary),
                    ),
                  ),
                  Text(
                    FfFormat.minutes(b.durationMin),
                    style: FfType.caption.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
