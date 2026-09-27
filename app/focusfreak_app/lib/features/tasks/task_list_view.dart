import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ff_format.dart';
import '../../data/db/database.dart';
import '../../data/repo/task_repository.dart';
import '../../design/components/ff_card.dart';
import '../../design/components/ff_states.dart';
import '../../design/ff_colors.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';

final _filterProvider = StateProvider<TaskFilter>((_) => TaskFilter.today);

class TaskListView extends ConsumerWidget {
  const TaskListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_filterProvider);
    final tasks = ref.watch(tasksProvider(filter));

    return Column(
      children: <Widget>[
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: FfSpace.gutter,
              vertical: FfSpace.sm,
            ),
            children: <Widget>[
              for (final f in TaskFilter.values) ...<Widget>[
                _FilterChip(
                  filter: f,
                  selected: f == filter,
                  onTap: () => ref.read(_filterProvider.notifier).state = f,
                ),
                const SizedBox(width: FfSpace.sm),
              ],
            ],
          ),
        ),
        Expanded(
          child: tasks.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FfErrorState(
              message: 'Could not load your tasks',
              detail: '$e',
              onRetry: () => ref.invalidate(tasksProvider(filter)),
            ),
            data: (list) => list.isEmpty
                ? FfEmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: _emptyTitle(filter),
                    message: _emptyMessage(filter),
                    actionLabel: filter == TaskFilter.completed
                        ? null
                        : 'Add a task',
                    onAction: filter == TaskFilter.completed
                        ? null
                        : () => _addTask(context, ref),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      FfSpace.gutter,
                      FfSpace.sm,
                      FfSpace.gutter,
                      FfSpace.xxxl,
                    ),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: FfSpace.sm),
                    itemBuilder: (context, i) {
                      if (i == list.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: FfSpace.md),
                          child: OutlinedButton.icon(
                            onPressed: () => _addTask(context, ref),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add a task'),
                          ),
                        );
                      }
                      return _TaskTile(task: list[i]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  static String _emptyTitle(TaskFilter f) => switch (f) {
    TaskFilter.today => 'Nothing due today',
    TaskFilter.upcoming => 'Nothing scheduled ahead',
    TaskFilter.overdue => 'Nothing overdue',
    TaskFilter.completed => 'Nothing finished yet',
    TaskFilter.all => 'No tasks yet',
  };

  static String _emptyMessage(TaskFilter f) => switch (f) {
    TaskFilter.today =>
      'A clear day is a legitimate result, not an empty screen.',
    TaskFilter.upcoming => 'Tasks with a future due date show up here.',
    TaskFilter.overdue => 'Nothing has slipped. Keep it that way.',
    TaskFilter.completed => 'Finished tasks collect here.',
    TaskFilter.all => 'Tasks are what you work on; routines are when.',
  };

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final title = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const _QuickAddSheet(),
    );
    if (title == null || title.isEmpty) return;
    await ref.read(taskRepositoryProvider).create(title: title);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final TaskFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Material(
      color: selected ? p.accent.withValues(alpha: 0.16) : p.surfaceElevated,
      borderRadius: BorderRadius.circular(FfRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FfRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FfSpace.lg,
            vertical: FfSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FfRadius.pill),
            border: Border.all(
              color: selected ? p.accent.withValues(alpha: 0.5) : p.border,
            ),
          ),
          child: Text(
            switch (filter) {
              TaskFilter.today => 'Today',
              TaskFilter.upcoming => 'Upcoming',
              TaskFilter.overdue => 'Overdue',
              TaskFilter.all => 'All',
              TaskFilter.completed => 'Done',
            },
            style: FfType.caption.copyWith(
              color: selected ? p.accent : p.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final done = task.completedAt != null;
    final due = task.dueAt;
    final overdue = due != null && !done && due.isBefore(DateTime.now());
    final category = task.category;

    return Dismissible(
      key: ValueKey<String>(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: FfSpace.xl),
        decoration: BoxDecoration(
          color: p.broken.withValues(alpha: 0.16),
          borderRadius: FfRadius.cardRadius,
        ),
        child: Icon(Icons.delete_outline_rounded, color: p.broken),
      ),
      onDismissed: (_) => ref.read(taskRepositoryProvider).delete(task.id),
      child: FfCard(
        accent: category == null ? null : FfColors.category(category),
        padding: const EdgeInsets.symmetric(
          horizontal: FfSpace.md,
          vertical: FfSpace.sm,
        ),
        child: Row(
          children: <Widget>[
            Checkbox(
              value: done,
              onChanged: (v) =>
                  ref.read(taskRepositoryProvider).setDone(task.id, v ?? false),
              activeColor: p.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FfRadius.sm),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    task.title,
                    style: FfType.body.copyWith(
                      color: done ? p.textMuted : p.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: p.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (due != null || task.recurrence != null) ...<Widget>[
                    const SizedBox(height: FfSpace.xxs),
                    Row(
                      children: <Widget>[
                        if (due != null) ...<Widget>[
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: overdue ? p.broken : p.textMuted,
                          ),
                          const SizedBox(width: FfSpace.xs),
                          Text(
                            FfFormat.relativeDay(due),
                            style: FfType.caption.copyWith(
                              color: overdue ? p.broken : p.textMuted,
                            ),
                          ),
                        ],
                        if (task.recurrence != null) ...<Widget>[
                          const SizedBox(width: FfSpace.md),
                          Icon(
                            Icons.repeat_rounded,
                            size: 12,
                            color: p.textMuted,
                          ),
                          const SizedBox(width: FfSpace.xs),
                          Text(
                            task.recurrence!,
                            style: FfType.caption.copyWith(color: p.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (task.priority > 0)
              Padding(
                padding: const EdgeInsets.only(left: FfSpace.sm),
                child: Icon(
                  Icons.flag_rounded,
                  size: 15,
                  color: switch (task.priority) {
                    3 => p.broken,
                    2 => p.paused,
                    _ => p.textMuted,
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            'New task',
            style: FfType.titleMedium.copyWith(color: context.ff.textPrimary),
          ),
          const SizedBox(height: FfSpace.lg),
          TextField(
            controller: _c,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'What needs doing?'),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          const SizedBox(height: FfSpace.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_c.text.trim()),
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}
