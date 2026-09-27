/// Milestones.
///
/// Reached, not awarded: every number here is recomputed from the record, so
/// nothing on this screen is a claim the rest of the app would not make. A
/// locked one reads as something ahead of you — there is no "you failed to"
/// anywhere in it.
///
/// A hundred of them would be a wall, so they are grouped by family and each
/// family opens to show its tiers. Closed, a family shows the one number that
/// matters: how far along the *next* tier is.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ff_shell.dart';
import '../../app/providers.dart';
import '../../core/ff_format.dart';
import '../../design/components/ff_card.dart';
import '../../design/components/ff_states.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/engine/achievement_engine.dart';
import '../../domain/engine/streak_engine.dart';
import '../../domain/model/session_state.dart';

/// Recomputed on every read, then the new unlocks are stamped.
///
/// Deriving rather than incrementing a counter is what makes a restored backup
/// or a merged device log light the right milestones with no migration.
final achievementsProvider = FutureProvider<List<AchievementStatus>>((
  ref,
) async {
  final sessions = ref.watch(sessionRepositoryProvider);
  final days = await sessions.daySummaries();
  final rows = await sessions.allSessions();
  final streak = const StreakEngine().compute(days, today: DateTime.now());
  final tasks = await ref.watch(taskRepositoryProvider).completedCount();

  final store = ref.watch(achievementRepositoryProvider);
  final statuses = const AchievementEngine().evaluate(
    days: days,
    blocks: <BlockFacts>[
      for (final s in rows)
        BlockFacts(
          startedAt: s.startedAt,
          verifiedSec: s.verifiedSec,
          finalState: SessionState.fromWire(s.finalState),
          provenance: Provenance.values[s.provenance],
          trackEnabled: s.trackEnabled,
          category: s.category,
        ),
    ],
    streak: streak,
    tasksCompleted: tasks,
    unlockedAt: await store.unlockedDates(),
  );

  await store.record(<String, ({int progress, bool unlocked})>{
    for (final s in statuses)
      s.achievement.key: (progress: s.progress, unlocked: s.unlocked),
  });

  // Re-read the dates so anything stamped just now shows its date rather than
  // appearing unlocked-but-undated.
  final dates = await store.unlockedDates();
  return <AchievementStatus>[
    for (final s in statuses)
      AchievementStatus(
        achievement: s.achievement,
        progress: s.progress,
        unlockedAt: dates[s.achievement.key],
      ),
  ];
});

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final async = ref.watch(achievementsProvider);

    return FfPage(
      title: 'Milestones',
      subtitle: 'Counted from your record, never rounded up.',
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: FfSpace.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => FfEmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Could not count these up',
          message: '$e',
        ),
        data: (all) {
          final reached = all.where((a) => a.unlocked).length;

          // Grouped in catalogue order, which puts the families that move
          // soonest first.
          final byFamily = <String, List<AchievementStatus>>{};
          for (final a in all) {
            byFamily
                .putIfAbsent(a.achievement.family, () => <AchievementStatus>[])
                .add(a);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FfCard(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.emoji_events_outlined, color: p.accent),
                    const SizedBox(width: FfSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '$reached of ${all.length} reached',
                            style: FfType.titleMedium.copyWith(
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            reached == 0
                                ? 'The first one is a single finished block.'
                                : 'Every one of these is counted from blocks '
                                      'you actually finished.',
                            style: FfType.bodySmall.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FfSpace.lg),
              for (final entry in byFamily.entries)
                _FamilyCard(tiers: entry.value),
            ],
          );
        },
      ),
    );
  }
}

/// One family, closed to a single line until it is opened.
class _FamilyCard extends StatelessWidget {
  const _FamilyCard({required this.tiers});

  final List<AchievementStatus> tiers;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final reached = tiers.where((t) => t.unlocked).length;
    final done = reached == tiers.length;

    // The tier being worked towards. Once the family is finished there is no
    // "next", and the card says so rather than showing a full bar forever.
    final next = tiers.firstWhere((t) => !t.unlocked, orElse: () => tiers.last);

    return Padding(
      padding: const EdgeInsets.only(bottom: FfSpace.sm),
      child: FfCard(
        padding: EdgeInsets.zero,
        child: Theme(
          // The default divider on an ExpansionTile draws a hairline across
          // the card's rounded corner.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: FfSpace.lg,
              vertical: FfSpace.xxs,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              FfSpace.lg,
              0,
              FfSpace.lg,
              FfSpace.md,
            ),
            iconColor: p.textMuted,
            collapsedIconColor: p.textMuted,
            title: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    next.achievement.familyLabel,
                    style: FfType.titleSmall.copyWith(color: p.textPrimary),
                  ),
                ),
                Text(
                  '$reached of ${tiers.length}',
                  style: FfType.caption.copyWith(
                    color: done ? p.verified : p.textMuted,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: FfSpace.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(FfRadius.sm),
                    child: LinearProgressIndicator(
                      value: done ? 1 : next.fraction,
                      minHeight: 4,
                      backgroundColor: p.surfaceRaised,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        done ? p.verified : p.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: FfSpace.xs),
                  Text(
                    done
                        ? 'All of them, reached.'
                        : 'Next: ${next.achievement.title} · ${next.label}',
                    style: FfType.caption.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  next.achievement.detail,
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
              ),
              const SizedBox(height: FfSpace.sm),
              for (final tier in tiers) _TierRow(status: tier),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.status});

  final AchievementStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final done = status.unlocked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FfSpace.xs),
      child: Row(
        children: <Widget>[
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: done ? p.verified : p.textMuted,
            size: 18,
          ),
          const SizedBox(width: FfSpace.sm),
          Expanded(
            child: Text(
              status.achievement.title,
              style: FfType.bodySmall.copyWith(
                color: done ? p.textPrimary : p.textSecondary,
              ),
            ),
          ),
          Text(
            done && status.unlockedAt != null
                ? FfFormat.shortDate(status.unlockedAt!)
                : status.label,
            style: FfType.caption.copyWith(color: p.textMuted),
          ),
        ],
      ),
    );
  }
}
