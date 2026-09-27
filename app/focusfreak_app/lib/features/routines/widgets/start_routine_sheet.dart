import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide Block;

import '../../../app/ff_shell.dart';
import '../../../app/providers.dart';
import '../../../core/ff_format.dart';
import '../../../data/repo/routine_repository.dart';
import '../../../data/repo/settings_repository.dart';
import '../../../design/components/ff_card.dart';
import '../../../design/ff_colors.dart';
import '../../../design/ff_theme.dart';
import '../../../design/ff_tokens.dart';
import '../../../design/ff_typography.dart';
import '../../../domain/engine/routine_clock.dart';
import '../../timer/session_controller.dart';

/// Switch a routine on: ask how, start it, and go to the Bot tab.
///
/// Every entry point — the Plan list, the routine page, the Bot tab — comes
/// through here, so the three ways to start are the same everywhere. The Bot
/// tab is where a running routine lives: the face reacts to the block, and on
/// a connected bot the same block is running on the desk.
Future<void> startRoutineFlow(
  BuildContext context,
  WidgetRef ref,
  RoutineWithBlocks detail,
) async {
  if (detail.blocks.isEmpty) return;

  final running = ref.read(sessionControllerProvider);
  if (running.isActive) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop what is running?'),
        content: Text(
          '${running.block?.name ?? 'The current block'} will stop and '
          '${detail.routine.name} will start.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (replace != true || !context.mounted) return;
  }

  final start = await showModalBottomSheet<RoutineStart>(
    context: context,
    isScrollControlled: true,
    // Above the tab bar and the floating timer, not underneath them.
    useRootNavigator: true,
    builder: (_) => StartRoutineSheet(detail: detail, now: DateTime.now()),
  );
  if (start == null || !context.mounted) return;

  await ref
      .read(sessionControllerProvider.notifier)
      .startRoutine(
        detail.blocks,
        routineId: detail.routine.id,
        from: start.index,
        offset: start.offset,
      );
  // The Bot tab offers this routine again next time.
  await ref
      .read(settingsRepositoryProvider)
      .setString(SettingKey.activeRoutineId, detail.routine.id);
  if (context.mounted) context.go(FfTab.bot.path);
}

/// The three ways to start a routine, then — for the third — the block list.
class StartRoutineSheet extends StatefulWidget {
  const StartRoutineSheet({super.key, required this.detail, required this.now});

  final RoutineWithBlocks detail;

  /// Taken once when the sheet opens, so what it offers does not shift while
  /// it is being read.
  final DateTime now;

  @override
  State<StartRoutineSheet> createState() => _StartRoutineSheetState();
}

class _StartRoutineSheetState extends State<StartRoutineSheet> {
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    final timed = widget.detail.timed;
    final hit = RoutineClock.blockAt(timed, widget.now);

    return SafeArea(
      child: AnimatedSize(
        duration: FfMotion.normal,
        curve: FfMotion.standard,
        alignment: Alignment.topCenter,
        child: _picking
            ? _BlockPicker(
                detail: widget.detail,
                nowIndex: hit?.index,
                onBack: () => setState(() => _picking = false),
              )
            : _Options(
                detail: widget.detail,
                now: widget.now,
                hit: hit,
                onPick: () => setState(() => _picking = true),
              ),
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.detail,
    required this.now,
    required this.hit,
    required this.onPick,
  });

  final RoutineWithBlocks detail;
  final DateTime now;
  final ClockHit? hit;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final timed = detail.timed;
    final recommended = RoutineClock.recommended(timed, now);
    final first = detail.blocks.first;
    final hit = this.hit;

    final String clockDetail;
    if (hit != null) {
      final block = detail.blocks[hit.index];
      final left = Duration(minutes: block.durationMin) - hit.elapsed;
      clockDetail =
          'Joins ${block.name} '
          '(${FfFormat.timeOfDay(hit.startMin)}) with '
          '${FfFormat.humanDuration(left)} left, and keeps to the times '
          'after it.';
    } else if (detail.isTimed) {
      clockDetail = 'Nothing in this routine is on right now.';
    } else {
      clockDetail = 'This routine has no set times.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FfSpace.gutter,
        FfSpace.sm,
        FfSpace.gutter,
        FfSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Start ${detail.routine.name}',
            style: FfType.titleMedium.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: FfSpace.xxs),
          Text(
            '${detail.blocks.length} blocks · '
            '${FfFormat.minutes(detail.totalMinutes)}',
            style: FfType.bodySmall.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: FfSpace.lg),
          _Option(
            icon: Icons.play_arrow_rounded,
            title: 'Start now',
            detail:
                'Starts with ${first.name}. Each block runs its full '
                'length from now on.',
            recommended: recommended == RoutineStartMode.now,
            onTap: () => Navigator.of(
              context,
            ).pop(RoutineClock.plan(RoutineStartMode.now, timed, now)),
          ),
          const SizedBox(height: FfSpace.sm),
          _Option(
            icon: Icons.schedule_rounded,
            title: 'Follow the clock',
            detail: clockDetail,
            recommended: recommended == RoutineStartMode.clock,
            onTap: hit == null
                ? null
                // Resolved at the tap, not when the sheet opened: a sheet
                // left open for ten minutes must not start ten minutes behind.
                // If the block ended meanwhile, the next one is joined.
                : () => Navigator.of(context).pop(
                    RoutineClock.plan(
                          RoutineStartMode.clock,
                          timed,
                          DateTime.now(),
                        ) ??
                        RoutineClock.plan(RoutineStartMode.clock, timed, now),
                  ),
          ),
          const SizedBox(height: FfSpace.sm),
          _Option(
            icon: Icons.low_priority_rounded,
            title: 'Start from a block',
            detail:
                'Pick where to begin. That block gets its full length '
                'and the rest follow in order.',
            recommended: false,
            onTap: onPick,
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.detail,
    required this.recommended,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool recommended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: FfCard(
        onTap: onTap,
        borderColor: recommended ? p.accent.withValues(alpha: 0.6) : null,
        padding: const EdgeInsets.all(FfSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              size: 22,
              color: recommended ? p.accent : p.textSecondary,
            ),
            const SizedBox(width: FfSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          title,
                          style: FfType.titleSmall.copyWith(
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      if (recommended) ...<Widget>[
                        const SizedBox(width: FfSpace.sm),
                        _Pill(label: 'RECOMMENDED', color: p.accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: FfSpace.xxs),
                  Text(
                    detail,
                    style: FfType.caption.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockPicker extends StatefulWidget {
  const _BlockPicker({
    required this.detail,
    required this.nowIndex,
    required this.onBack,
  });

  final RoutineWithBlocks detail;
  final int? nowIndex;
  final VoidCallback onBack;

  @override
  State<_BlockPicker> createState() => _BlockPickerState();
}

class _BlockPickerState extends State<_BlockPicker> {
  final GlobalKey _nowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // A full day is up to 35 blocks; open on the one that is on now rather
    // than at 04:45.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _nowKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: 0.3);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final blocks = widget.detail.blocks;
    final starts = RoutineClock.starts(widget.detail.timed);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FfSpace.sm,
              FfSpace.xs,
              FfSpace.gutter,
              FfSpace.md,
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Back',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Text(
                  'Start from',
                  style: FfType.titleMedium.copyWith(color: p.textPrimary),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                FfSpace.gutter,
                0,
                FfSpace.gutter,
                FfSpace.xl,
              ),
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < blocks.length; i++)
                    Padding(
                      key: i == widget.nowIndex ? _nowKey : null,
                      padding: const EdgeInsets.only(bottom: FfSpace.sm),
                      child: _PickerRow(
                        name: blocks[i].name,
                        category: FfCategory.fromId(blocks[i].category),
                        meta: <String>[
                          if (starts != null) FfFormat.timeOfDay(starts[i]),
                          FfFormat.minutes(blocks[i].durationMin),
                          if (blocks[i].trackEnabled) 'tracked',
                        ].join(' · '),
                        isNow: i == widget.nowIndex,
                        onTap: () => Navigator.of(context).pop(
                          RoutineClock.plan(
                            RoutineStartMode.fromBlock,
                            widget.detail.timed,
                            DateTime.now(),
                            index: i,
                          ),
                        ),
                      ),
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

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.name,
    required this.category,
    required this.meta,
    required this.isNow,
    required this.onTap,
  });

  final String name;
  final FfCategory category;
  final String meta;
  final bool isNow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return FfCard(
      accent: category.color,
      padding: const EdgeInsets.symmetric(
        horizontal: FfSpace.md,
        vertical: FfSpace.md,
      ),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: FfType.titleSmall.copyWith(color: p.textPrimary),
                ),
                Text(
                  '${category.label} · $meta',
                  style: FfType.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          if (isNow) _Pill(label: 'NOW', color: p.accent),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FfSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(FfRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: FfType.overline.copyWith(color: color)),
    );
  }
}
