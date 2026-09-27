import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../data/repo/routine_repository.dart';
import '../../design/components/ff_states.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/model/template.dart';
import '../tasks/task_list_view.dart';
import 'widgets/routine_card.dart';
import 'widgets/start_routine_sheet.dart';

/// Routines and tasks, under one tab.
///
/// They are two views of one intent — a routine is *when* you will work, a task
/// is *what* you will work on — so they live together rather than each taking a
/// slot in the bottom bar.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ff;

    return Scaffold(
      backgroundColor: p.surfaceBase,
      appBar: AppBar(
        title: const Text('Plan'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: p.textPrimary,
          unselectedLabelColor: p.textMuted,
          indicatorColor: p.accent,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: p.border,
          labelStyle: FfType.titleSmall,
          tabs: const <Widget>[
            Tab(text: 'Routines'),
            Tab(text: 'Tasks'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: const <Widget>[_RoutinesTab(), TaskListView()],
        ),
      ),
    );
  }
}

class _RoutinesTab extends ConsumerWidget {
  const _RoutinesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final routines = ref.watch(routinesProvider);

    return routines.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FfErrorState(
        message: 'Could not load your routines',
        detail: '$e',
        onRetry: () => ref.invalidate(routinesProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          // Reachable two ways: a fresh install before seeding, and hiding
          // every template. The second is why the hidden list is offered here
          // too — otherwise this screen is a dead end.
          return ListView(
            padding: const EdgeInsets.all(FfSpace.gutter),
            children: <Widget>[
              FfEmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'No routines',
                message: 'Start from a template, or build your own day.',
                actionLabel: 'Bring back the templates',
                onAction: () =>
                    ref.read(routineRepositoryProvider).restoreTemplates(),
              ),
              const SizedBox(height: FfSpace.lg),
              const _HiddenRoutines(),
              OutlinedButton.icon(
                onPressed: () => _createRoutine(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New empty routine'),
              ),
            ],
          );
        }

        final builtIn = list.where((r) => r.isBuiltIn).toList();
        final mine = list.where((r) => !r.isBuiltIn).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            FfSpace.gutter,
            FfSpace.lg,
            FfSpace.gutter,
            FfSpace.xxxl,
          ),
          children: <Widget>[
            _NewRoutineRow(onEmpty: () => _createRoutine(context, ref)),
            const SizedBox(height: FfSpace.xl),
            if (mine.isNotEmpty) ...<Widget>[
              _Heading(
                title: 'Your routines',
                subtitle: '${mine.length} custom',
              ),
              for (final r in mine) ...<Widget>[
                _RoutineTile(routine: r),
                const SizedBox(height: FfSpace.sm),
              ],
              const SizedBox(height: FfSpace.xl),
            ],
            for (final group in _TemplateGroup.arrange(builtIn)) ...<Widget>[
              _Heading(title: group.title, subtitle: group.subtitle),
              for (final r in group.routines) ...<Widget>[
                _RoutineTile(routine: r),
                const SizedBox(height: FfSpace.sm),
              ],
              const SizedBox(height: FfSpace.xl),
            ],
            const _HiddenRoutines(),
            Text(
              'The bot holds 16 blocks at a time. A longer routine runs here in '
              'full, and the bot gets the next blocks as the day goes.',
              style: FfType.caption.copyWith(color: p.textMuted),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createRoutine(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const NameDialog(title: 'New routine'),
    );
    if (name == null || name.isEmpty) return;
    final id = await ref.read(routineRepositoryProvider).create(name: name);
    if (context.mounted) context.push('/plan/routine/$id');
  }
}

/// New routines start at the top of the list, where they are looked for.
class _NewRoutineRow extends StatelessWidget {
  const _NewRoutineRow({required this.onEmpty});

  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push('/plan/build'),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Build my routine'),
          ),
        ),
        const SizedBox(width: FfSpace.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEmpty,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Empty routine'),
          ),
        ),
      ],
    );
  }
}

class _RoutineTile extends ConsumerWidget {
  const _RoutineTile({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(routineDetailProvider(routine.id));

    return detail.when(
      loading: () => const SizedBox(height: 140),
      error: (_, __) => const SizedBox.shrink(),
      data: (d) => d == null
          ? const SizedBox.shrink()
          : RoutineCard(
              detail: d,
              onTap: () => context.push('/plan/routine/${routine.id}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Start',
                    onPressed: d.blocks.isEmpty
                        ? null
                        : () => startRoutineFlow(context, ref, d),
                    icon: Icon(
                      Icons.play_circle_outline_rounded,
                      color: context.ff.accent,
                    ),
                  ),
                  _RoutineMenu(detail: d),
                ],
              ),
            ),
    );
  }
}

class _RoutineMenu extends ConsumerWidget {
  const _RoutineMenu({required this.detail});

  final RoutineWithBlocks detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(routineRepositoryProvider);
    final isBuiltIn = detail.routine.isBuiltIn;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: context.ff.textMuted),
      onSelected: (value) async {
        switch (value) {
          case 'start':
            await startRoutineFlow(context, ref, detail);
          case 'duplicate':
            final id = await repo.duplicate(detail.routine.id);
            if (context.mounted) context.push('/plan/routine/$id');
          case 'open':
            context.push('/plan/routine/${detail.routine.id}');
          case 'delete':
            await repo.delete(detail.routine.id);
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        if (detail.blocks.isNotEmpty)
          const PopupMenuItem<String>(value: 'start', child: Text('Start')),
        PopupMenuItem<String>(
          value: 'open',
          child: Text(isBuiltIn ? 'Preview' : 'Edit'),
        ),
        const PopupMenuItem<String>(
          value: 'duplicate',
          child: Text('Duplicate'),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(isBuiltIn ? 'Hide' : 'Delete'),
        ),
      ],
    );
  }
}

/// The built-ins, grouped the way someone chooses between them.
///
/// Full days come first, and the ones built on this season's salah times come
/// before the other season's — the winter variants are not wrong in summer,
/// just an hour off. Ramadan is never picked by date, so it has its own group.
class _TemplateGroup {
  const _TemplateGroup(this.title, this.subtitle, this.routines);

  final String title;
  final String subtitle;
  final List<Routine> routines;

  static List<_TemplateGroup> arrange(List<Routine> builtIn, {DateTime? now}) {
    final current = RoutineSeason.of(now ?? DateTime.now());
    final other = current == RoutineSeason.summer
        ? RoutineSeason.winter
        : RoutineSeason.summer;

    RoutineSeason? seasonOf(Routine r) =>
        r.templateKey == null ? null : Templates.byKey(r.templateKey!)?.season;

    List<Routine> where(bool Function(RoutineSeason? s) test) =>
        builtIn.where((r) => test(seasonOf(r))).toList();

    return <_TemplateGroup>[
      _TemplateGroup(
        'Full days · ${current.label}',
        'Salah times for ${current.months}. Duplicate one to make it yours.',
        where((s) => s == current),
      ),
      _TemplateGroup(
        'Focus sprints',
        'No set times. They start when you do.',
        where((s) => s == null),
      ),
      _TemplateGroup(
        'Ramadan',
        'Built around sehri and iftar.',
        where((s) => s == RoutineSeason.ramadan),
      ),
      _TemplateGroup(
        'Full days · ${other.label}',
        'Salah times for ${other.months}.',
        where((s) => s == other),
      ),
    ].where((g) => g.routines.isNotEmpty).toList();
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Padding(
      padding: const EdgeInsets.only(
        left: FfSpace.xs,
        right: FfSpace.xs,
        bottom: FfSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: FfType.overline.copyWith(color: p.accent),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: FfSpace.xxs),
            Text(
              subtitle!,
              style: FfType.bodySmall.copyWith(color: p.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared single-field dialog.
class NameDialog extends StatefulWidget {
  const NameDialog({
    super.key,
    required this.title,
    this.initial = '',
    this.hint = 'Name',
    this.maxLength = 60,
    this.confirmLabel = 'Create',
  });

  final String title;
  final String initial;
  final String hint;
  final int maxLength;
  final String confirmLabel;

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: widget.maxLength,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_c.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Routines the user hid, and the way back.
///
/// Hiding a template used to be permanent: it left the list and nothing in the
/// app could bring it back. Anything one tap can remove, one tap has to be able
/// to restore.
class _HiddenRoutines extends ConsumerStatefulWidget {
  const _HiddenRoutines();

  @override
  ConsumerState<_HiddenRoutines> createState() => _HiddenRoutinesState();
}

class _HiddenRoutinesState extends ConsumerState<_HiddenRoutines> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final hidden = ref.watch(hiddenRoutinesProvider).valueOrNull;
    if (hidden == null || hidden.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextButton.icon(
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(
            _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            size: 18,
          ),
          label: Text('Hidden (${hidden.length})'),
        ),
        if (_open) ...<Widget>[
          const SizedBox(height: FfSpace.sm),
          for (final routine in hidden) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    routine.name,
                    style: FfType.body.copyWith(color: p.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(routineRepositoryProvider)
                      .archive(routine.id, archived: false),
                  child: const Text('Show'),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: FfSpace.lg),
      ],
    );
  }
}
