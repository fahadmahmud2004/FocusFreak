import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ff_constants.dart';
import '../../core/ff_format.dart';
import '../../data/db/database.dart';
import '../../data/repo/routine_repository.dart';
import '../../design/components/ff_card.dart';
import '../../design/components/ff_states.dart';
import '../../design/ff_colors.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import 'widgets/block_editor_sheet.dart';
import 'widgets/start_routine_sheet.dart';
import 'widgets/routine_card.dart';

class RoutineEditorScreen extends ConsumerWidget {
  const RoutineEditorScreen({super.key, required this.routineId});

  final String routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final detail = ref.watch(routineDetailProvider(routineId));

    return detail.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: FfErrorState(
          message: 'Could not open this routine',
          detail: '$e',
        ),
      ),
      data: (d) {
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const FfEmptyState(
              icon: Icons.help_outline_rounded,
              title: 'Routine not found',
              message: 'It may have been deleted.',
            ),
          );
        }

        final readOnly = d.routine.isBuiltIn;

        return Scaffold(
          backgroundColor: p.surfaceBase,
          appBar: AppBar(
            title: Text(d.routine.name),
            actions: <Widget>[
              if (readOnly)
                TextButton.icon(
                  onPressed: () async {
                    final id = await ref
                        .read(routineRepositoryProvider)
                        .duplicate(routineId);
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => RoutineEditorScreen(routineId: id),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Duplicate'),
                ),
              const SizedBox(width: FfSpace.sm),
            ],
          ),
          floatingActionButton: d.blocks.isEmpty
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!readOnly) ...<Widget>[
                      FloatingActionButton(
                        heroTag: 'addBlock',
                        backgroundColor: p.surfaceRaised,
                        foregroundColor: p.textPrimary,
                        elevation: 0,
                        onPressed: () => _addBlock(context, ref, d),
                        child: const Icon(Icons.add_rounded),
                      ),
                      const SizedBox(width: FfSpace.md),
                    ],
                    FloatingActionButton.extended(
                      heroTag: 'runRoutine',
                      backgroundColor: p.accent,
                      foregroundColor: p.isDark ? Colors.black : Colors.white,
                      onPressed: () => startRoutineFlow(context, ref, d),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start'),
                    ),
                  ],
                ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                _Summary(detail: d, readOnly: readOnly),
                Expanded(
                  child: d.blocks.isEmpty
                      ? FfEmptyState(
                          icon: Icons.view_agenda_outlined,
                          title: 'No blocks yet',
                          message:
                              'A block is a stretch of time with a name, a '
                              'category, and a choice about whether it is tracked.',
                          actionLabel: readOnly ? null : 'Add the first block',
                          onAction: readOnly
                              ? null
                              : () => _addBlock(context, ref, d),
                        )
                      : _BlockList(detail: d, readOnly: readOnly),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addBlock(
    BuildContext context,
    WidgetRef ref,
    RoutineWithBlocks d,
  ) async {
    final result = await showModalBottomSheet<BlockDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const BlockEditorSheet(),
    );
    if (result == null) return;
    await ref
        .read(routineRepositoryProvider)
        .addBlock(
          routineId,
          name: result.name,
          description: result.description,
          durationMin: result.durationMin,
          category: result.category,
          trackEnabled: result.trackEnabled,
          startMin: result.startMin ?? FfFirmware.sequentialStartMin,
        );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.detail, required this.readOnly});

  final RoutineWithBlocks detail;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FfSpace.gutter,
        FfSpace.md,
        FfSpace.gutter,
        FfSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          RoutineShapeBar(blocks: detail.blocks, height: 10),
          const SizedBox(height: FfSpace.md),
          Wrap(
            spacing: FfSpace.lg,
            runSpacing: FfSpace.xs,
            children: <Widget>[
              _Metric(
                label: 'Total',
                value: FfFormat.minutes(detail.totalMinutes),
              ),
              _Metric(
                label: 'Deep work',
                value: FfFormat.minutes(detail.deepWorkMinutes),
              ),
              _Metric(label: 'Blocks', value: '${detail.blocks.length}'),
              _Metric(label: 'Tracked', value: '${detail.trackedCount}'),
            ],
          ),
          if (!detail.fitsDevice) ...<Widget>[
            const SizedBox(height: FfSpace.md),
            // The honest version of a limit: say what happens instead of
            // letting the user discover it on the desk.
            Container(
              padding: const EdgeInsets.all(FfSpace.md),
              decoration: BoxDecoration(
                color: p.paused.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(FfRadius.md),
                border: Border.all(color: p.paused.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.memory_rounded, size: 16, color: p.paused),
                  const SizedBox(width: FfSpace.md),
                  Expanded(
                    child: Text(
                      'The bot holds ${FfFirmware.maxDeviceBlocks} blocks at '
                      'a time. While this routine runs, the app sends it the '
                      'next ones as the day goes.',
                      style: FfType.caption.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (readOnly) ...<Widget>[
            const SizedBox(height: FfSpace.md),
            Text(
              'This is a built-in template. Duplicate it to make changes.',
              style: FfType.caption.copyWith(color: p.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: FfType.overline.copyWith(color: p.textMuted),
        ),
        Text(value, style: FfType.titleSmall.copyWith(color: p.textPrimary)),
      ],
    );
  }
}

class _BlockList extends ConsumerWidget {
  const _BlockList({required this.detail, required this.readOnly});

  final RoutineWithBlocks detail;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(routineRepositoryProvider);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        FfSpace.gutter,
        FfSpace.sm,
        FfSpace.gutter,
        FfSpace.xxxl * 2,
      ),
      buildDefaultDragHandles: false,
      itemCount: detail.blocks.length,
      onReorder: (from, to) {
        if (readOnly) return;
        // ReorderableListView reports the destination index in the *pre-removal*
        // list when moving down, so it needs adjusting before it reaches the
        // repository, which works on final positions.
        repo.reorder(detail.routine.id, from, to > from ? to - 1 : to);
      },
      itemBuilder: (context, i) => Padding(
        key: ValueKey<String>(detail.blocks[i].id),
        padding: const EdgeInsets.only(bottom: FfSpace.sm),
        child: _BlockTile(
          block: detail.blocks[i],
          index: i,
          readOnly: readOnly,
        ),
      ),
    );
  }
}

class _BlockTile extends ConsumerWidget {
  const _BlockTile({
    required this.block,
    required this.index,
    required this.readOnly,
  });

  final Block block;
  final int index;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final category = FfCategory.fromId(block.category);
    final sequential = block.startMin == FfFirmware.sequentialStartMin;

    return FfCard(
      accent: category.color,
      padding: const EdgeInsets.symmetric(
        horizontal: FfSpace.md,
        vertical: FfSpace.md,
      ),
      onTap: readOnly ? null : () => _edit(context, ref),
      child: Row(
        children: <Widget>[
          if (!readOnly)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: FfSpace.sm),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: p.textMuted,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        block.name,
                        style: FfType.titleSmall.copyWith(color: p.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (block.trackEnabled) ...<Widget>[
                      const SizedBox(width: FfSpace.sm),
                      Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: p.verified,
                      ),
                    ],
                  ],
                ),
                if (block.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    block.description,
                    style: FfType.caption.copyWith(color: p.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: FfSpace.xs),
                Row(
                  children: <Widget>[
                    Text(
                      category.label,
                      style: FfType.caption.copyWith(color: category.color),
                    ),
                    Text(
                      ' · ',
                      style: FfType.caption.copyWith(color: p.textMuted),
                    ),
                    Text(
                      FfFormat.minutes(block.durationMin),
                      style: FfType.caption.copyWith(color: p.textSecondary),
                    ),
                    if (!sequential) ...<Widget>[
                      Text(
                        ' · ',
                        style: FfType.caption.copyWith(color: p.textMuted),
                      ),
                      Text(
                        FfFormat.timeOfDay(block.startMin),
                        style: FfType.caption.copyWith(color: p.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<BlockDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => BlockEditorSheet(
        initial: BlockDraft(
          name: block.name,
          description: block.description,
          durationMin: block.durationMin,
          category: block.category,
          trackEnabled: block.trackEnabled,
          startMin: block.startMin == FfFirmware.sequentialStartMin
              ? null
              : block.startMin,
        ),
        allowDelete: true,
      ),
    );
    if (result == null) return;

    final repo = ref.read(routineRepositoryProvider);
    if (result.deleted) {
      await repo.deleteBlock(block.id);
      return;
    }
    await repo.updateBlock(
      block.id,
      name: result.name,
      description: result.description,
      durationMin: result.durationMin,
      category: result.category,
      trackEnabled: result.trackEnabled,
      startMin: result.startMin ?? FfFirmware.sequentialStartMin,
    );
  }
}
