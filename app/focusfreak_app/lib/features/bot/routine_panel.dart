import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ff_shell.dart';
import '../../app/providers.dart';
import '../../core/ff_format.dart';
import '../../data/repo/settings_repository.dart';
import '../../design/components/ff_card.dart';
import '../../design/ff_colors.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/model/session_state.dart';
import '../routines/widgets/start_routine_sheet.dart';
import '../timer/floating_timer.dart';
import '../timer/session_controller.dart';

/// The routine the Bot tab offers to start: the last one switched on.
final activeRoutineIdProvider = StreamProvider<String>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watchString(SettingKey.activeRoutineId),
);

/// The Bot tab's routine switch.
///
/// While a routine runs this is its dashboard — the block, what is left of it,
/// what comes next, and the controls. Otherwise it is the way to turn one on,
/// through the same three-way start as everywhere else.
class RoutinePanel extends ConsumerWidget {
  const RoutinePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionControllerProvider);
    return s.isActive ? _Running(s: s) : const _Idle();
  }
}

class _Running extends ConsumerWidget {
  const _Running({required this.s});

  final SessionSnapshot s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final controller = ref.read(sessionControllerProvider.notifier);
    final block = s.block!;
    final category = FfCategory.fromId(block.category);
    final paused = s.state == SessionState.paused;
    final next = s.nextBlock;

    return FfCard(
      accent: category.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            s.autoMode
                ? 'BLOCK ${s.queueIndex + 1} OF ${s.queue.length}'
                : 'FOCUS',
            style: FfType.overline.copyWith(color: p.accent),
          ),
          const SizedBox(height: FfSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      block.name,
                      style: FfType.titleMedium.copyWith(color: p.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      switch (s.state) {
                        SessionState.paused when s.pausedByUser => 'Paused',
                        SessionState.paused => 'Waiting for you',
                        SessionState.armed => s.state.label,
                        _ => category.label,
                      },
                      style: FfType.caption.copyWith(
                        color: s.state == SessionState.running
                            ? category.color
                            : p.paused,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                FfFormat.clock(s.remaining),
                style: FfType.countdownMd.copyWith(
                  color: paused ? p.textMuted : p.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: FfSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(FfRadius.pill),
            child: LinearProgressIndicator(
              value: s.progress,
              minHeight: 6,
              color: paused ? p.paused : category.color,
              backgroundColor: p.surfaceRaised,
            ),
          ),
          if (next != null) ...<Widget>[
            const SizedBox(height: FfSpace.sm),
            Text(
              'Next: ${next.name} · '
              '${FfFormat.humanDuration(next.duration)}',
              style: FfType.caption.copyWith(color: p.textMuted),
            ),
          ],
          const SizedBox(height: FfSpace.md),
          Row(
            children: <Widget>[
              FilledButton.tonalIcon(
                // Nothing to pause until the block is actually counting.
                onPressed: s.state == SessionState.armed
                    ? null
                    : paused
                    ? controller.resume
                    : controller.pause,
                icon: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 18,
                ),
                label: Text(paused ? 'Resume' : 'Pause'),
              ),
              const SizedBox(width: FfSpace.sm),
              TextButton.icon(
                onPressed: () => _confirmStop(context, controller),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Stop'),
              ),
              const Spacer(),
              if (s.autoMode)
                IconButton(
                  tooltip: next == null ? 'Finish this block' : 'Skip to next',
                  onPressed: controller.skip,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmStop(
    BuildContext context,
    SessionController controller,
  ) async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.autoMode ? 'Stop the routine?' : 'Stop this block?'),
        content: const Text('Time you have already put in is kept.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (stop == true) await controller.stop();
  }
}

class _Idle extends ConsumerWidget {
  const _Idle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final id = ref.watch(activeRoutineIdProvider).valueOrNull ?? '';
    final detail = id.isEmpty
        ? null
        : ref.watch(routineDetailProvider(id)).valueOrNull;

    return SizedBox(
      width: double.infinity,
      child: FfCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'NO ROUTINE RUNNING',
              textAlign: TextAlign.center,
              style: FfType.overline.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: FfSpace.xs),
            Text(
              detail == null
                  ? 'Pick a routine and the bot follows it block by block.'
                  : '${detail.routine.name} · ${detail.blocks.length} blocks',
              style: FfType.body.copyWith(color: p.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FfSpace.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: FfSpace.sm,
              runSpacing: FfSpace.sm,
              children: <Widget>[
                if (detail != null && detail.blocks.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => startRoutineFlow(context, ref, detail),
                    icon: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 18,
                    ),
                    label: const Text('Switch on'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => openQuickTimer(context),
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: const Text('Timer'),
                ),
                OutlinedButton(
                  onPressed: () => context.go(FfTab.plan.path),
                  child: Text(
                    detail == null ? 'Choose a routine' : 'Choose another',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
