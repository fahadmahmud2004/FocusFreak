/// Milestones, computed from the record rather than awarded by the app.
///
/// There are a hundred of them, and they are **generated from ten families of
/// tiers** rather than written out one by one. That is not laziness: a
/// hand-written list of a hundred is a list where number ninety-three is
/// invented to reach a round number, and an invented milestone is exactly the
/// participation trophy this product does not hand out. Every tier below
/// counts something the app already measures and would defend in a report.
///
/// Every one is derived on the fly from days, blocks, tasks and the streak, so
/// a restored backup or a device log merge lights the right ones without a
/// migration. The database only remembers *when* each was first reached, which
/// is the one fact the numbers cannot reconstruct.
///
/// Three rules, and they are the same rules as the rest of the product
/// (`docs/ARCHITECTURE.md`):
///
/// 1. **Nothing can be lost.** A milestone reached is reached; a bad week does
///    not take it back. Anything that can be revoked is a punishment mechanic.
/// 2. **Nothing is invented.** Every threshold counts *verified* minutes,
///    completed blocks, finished tasks or recorded days. There is no milestone
///    for opening the app.
/// 3. **Nothing shames the empty state.** A locked milestone reads as
///    something ahead of you, never as something you failed.
library;

import '../model/session_state.dart';
import 'streak_engine.dart';

/// What a milestone counts. The unit decides how progress is phrased and which
/// number the engine feeds it.
enum AchievementKind {
  blocks,
  verifiedMinutes,
  bestDayMinutes,
  streakDays,
  earlyBlocks,
  lateBlocks,
  sensorBlocks,
  categoryMinutes,
  tasksDone,
  daysRecorded,
}

/// One family of milestones: the same thing counted, at rising thresholds.
class AchievementFamily {
  const AchievementFamily({
    required this.id,
    required this.label,
    required this.detail,
    required this.kind,
    required this.tiers,
    required this.title,
    this.category,
  });

  final String id;

  /// The heading this family appears under.
  final String label;

  /// One line explaining what is being counted. Shown once, not per tier.
  final String detail;

  final AchievementKind kind;

  /// Thresholds, ascending, in the kind's own unit.
  final List<int> tiers;

  /// How a tier is named on screen.
  final String Function(int tier) title;

  /// Only for [AchievementKind.categoryMinutes].
  final int? category;

  List<Achievement> get achievements => <Achievement>[
    for (final tier in tiers)
      Achievement(
        key: '${id}_$tier',
        title: title(tier),
        detail: detail,
        kind: kind,
        target: tier,
        family: id,
        familyLabel: label,
        category: category,
      ),
  ];
}

/// One milestone.
class Achievement {
  const Achievement({
    required this.key,
    required this.title,
    required this.detail,
    required this.kind,
    required this.target,
    required this.family,
    required this.familyLabel,
    this.category,
  });

  /// Stable, and what the database stores. Never renamed: the key is the only
  /// link between a row and the milestone it recorded.
  final String key;

  final String title;
  final String detail;
  final AchievementKind kind;
  final int target;
  final String family;
  final String familyLabel;
  final int? category;

  static final List<Achievement> values = <Achievement>[
    for (final f in AchievementCatalogue.families) ...f.achievements,
  ];

  static Achievement? byKey(String key) {
    for (final a in values) {
      if (a.key == key) return a;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is Achievement && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// The hundred.
class AchievementCatalogue {
  const AchievementCatalogue._();

  static const List<String> categoryNames = <String>[
    'Deep Work',
    'Active Work',
    'Output',
    'Routine',
    'Nap + Buffer',
    'Sleep',
  ];

  static String _hours(int minutes) => '${minutes ~/ 60}';

  static final List<AchievementFamily> families = <AchievementFamily>[
    AchievementFamily(
      id: 'blocks',
      label: 'Blocks finished',
      detail: 'Blocks you started and saw all the way to the end.',
      kind: AchievementKind.blocks,
      tiers: const <int>[1, 5, 10, 25, 50, 100, 200, 350, 500, 750, 1000],
      title: (t) => t == 1 ? 'Your first block' : '$t blocks finished',
    ),
    AchievementFamily(
      id: 'hours',
      label: 'Verified hours',
      detail: 'Hours where every available check held. Not claimed time.',
      kind: AchievementKind.verifiedMinutes,
      tiers: const <int>[
        60,
        300,
        600,
        1500,
        3000,
        6000,
        12000,
        21000,
        30000,
        45000,
        60000,
      ],
      title: (t) =>
          t == 60 ? 'Your first verified hour' : '${_hours(t)} verified hours',
    ),
    AchievementFamily(
      id: 'bestday',
      label: 'One good day',
      detail: 'Verified hours inside a single day.',
      kind: AchievementKind.bestDayMinutes,
      tiers: const <int>[60, 120, 180, 240, 300, 360, 480, 600],
      title: (t) => 'A ${_hours(t)}-hour day',
    ),
    AchievementFamily(
      id: 'streak',
      label: 'Days without a gap',
      detail: 'Your longest run of days that each had verified time.',
      kind: AchievementKind.streakDays,
      tiers: const <int>[
        2,
        3,
        5,
        7,
        10,
        14,
        21,
        30,
        50,
        75,
        100,
        150,
        200,
        365,
      ],
      title: (t) => '$t days in a row',
    ),
    AchievementFamily(
      id: 'early',
      label: 'Early starts',
      detail: 'Verified blocks that began before 07:00.',
      kind: AchievementKind.earlyBlocks,
      tiers: const <int>[1, 5, 10, 25, 50, 100],
      title: (t) => t == 1 ? 'Before the world wakes' : '$t early starts',
    ),
    AchievementFamily(
      id: 'late',
      label: 'The quiet hours',
      detail: 'Verified blocks that began after 22:00.',
      kind: AchievementKind.lateBlocks,
      tiers: const <int>[1, 5, 10, 25, 50, 100],
      title: (t) => t == 1 ? 'After the house is quiet' : '$t late blocks',
    ),
    AchievementFamily(
      id: 'sensor',
      label: 'The bot vouched',
      detail: 'Blocks your FocusFreak verified from the desk. Needs the bot.',
      kind: AchievementKind.sensorBlocks,
      tiers: const <int>[1, 5, 10, 25, 50, 100],
      title: (t) => t == 1 ? 'The bot vouched' : '$t sensor-verified blocks',
    ),
    AchievementFamily(
      id: 'tasks',
      label: 'Tasks done',
      detail: 'Tasks you ticked off.',
      kind: AchievementKind.tasksDone,
      tiers: const <int>[1, 10, 25, 50, 100, 250, 500],
      title: (t) => t == 1 ? 'First task done' : '$t tasks done',
    ),
    AchievementFamily(
      id: 'days',
      label: 'Days on the record',
      detail:
          'Days with at least one verified block. They need not be in a '
          'row.',
      kind: AchievementKind.daysRecorded,
      tiers: const <int>[1, 7, 30, 60, 100, 180, 365],
      title: (t) => t == 1 ? 'Day one' : '$t days on the record',
    ),
    // Six categories × four tiers. The category ones are last because they are
    // the slowest to move, and a list should not open with what is furthest
    // away.
    for (var c = 0; c < categoryNames.length; c++)
      AchievementFamily(
        id: 'cat$c',
        label: categoryNames[c],
        detail: 'Verified hours in ${categoryNames[c]}.',
        kind: AchievementKind.categoryMinutes,
        category: c,
        tiers: const <int>[60, 300, 600, 1500],
        title: (t) => '${_hours(t)}h of ${categoryNames[c]}',
      ),
  ];

  /// The count is a product decision, not an accident — see the note at the
  /// top of the file. `achievement_test.dart` asserts it.
  static int get total => Achievement.values.length;
}

/// One milestone with its progress filled in.
class AchievementStatus {
  const AchievementStatus({
    required this.achievement,
    required this.progress,
    this.unlockedAt,
  });

  final Achievement achievement;

  /// Counted in the achievement's own unit, and **not** capped at the target:
  /// the screen shows a finished tier as simply done, but the raw number is
  /// what gets persisted.
  final int progress;

  /// When it was first reached, once that has been recorded.
  final DateTime? unlockedAt;

  bool get unlocked => progress >= achievement.target;

  /// 0..1, for the bar.
  double get fraction => achievement.target <= 0
      ? 1
      : (progress / achievement.target).clamp(0.0, 1.0);

  /// "3 of 10 blocks" — or the whole number once it is done.
  String get label => switch (achievement.kind) {
    AchievementKind.verifiedMinutes ||
    AchievementKind.bestDayMinutes ||
    AchievementKind.categoryMinutes =>
      '${(progress / 60).floor()} of ${achievement.target ~/ 60} hours',
    AchievementKind.streakDays ||
    AchievementKind.daysRecorded => '$progress of ${achievement.target} days',
    AchievementKind.blocks => '$progress of ${achievement.target} blocks',
    AchievementKind.tasksDone => '$progress of ${achievement.target} tasks',
    _ => '$progress of ${achievement.target}',
  };
}

/// The facts one finished block contributes.
class BlockFacts {
  const BlockFacts({
    required this.startedAt,
    required this.verifiedSec,
    required this.finalState,
    required this.provenance,
    required this.trackEnabled,
    this.category = 0,
  });

  final DateTime startedAt;
  final int verifiedSec;
  final SessionState finalState;
  final Provenance provenance;
  final bool trackEnabled;
  final int category;

  /// Counted only when it ran to the end. A block that broke is not a
  /// failure to be punished, but it is not a completed block either.
  bool get completed => finalState == SessionState.complete;

  bool get counts => completed && verifiedSec > 0;
}

class AchievementEngine {
  const AchievementEngine();

  List<AchievementStatus> evaluate({
    required List<DaySummary> days,
    required List<BlockFacts> blocks,
    required StreakResult streak,
    int tasksCompleted = 0,
    Map<String, DateTime> unlockedAt = const <String, DateTime>{},
  }) {
    final counted = blocks.where((b) => b.counts).toList();

    final totalBlocks = blocks.where((b) => b.completed).length;
    final verifiedMinutes = days.fold(0, (sum, d) => sum + d.verifiedMin);
    final bestDay = days.fold(
      0,
      (best, d) => d.verifiedMin > best ? d.verifiedMin : best,
    );
    final recordedDays = days.where((d) => d.qualifies).length;
    final early = counted.where((b) => b.startedAt.hour < 7).length;
    final late = counted.where((b) => b.startedAt.hour >= 22).length;
    final sensor = counted
        .where((b) => b.provenance == Provenance.sensorVerified)
        .length;

    // Per category, in minutes. Taken from the blocks rather than the day
    // rollup, which has no category breakdown.
    final byCategory = <int, int>{};
    for (final b in counted) {
      byCategory[b.category] = (byCategory[b.category] ?? 0) + b.verifiedSec;
    }

    int progressOf(Achievement a) => switch (a.kind) {
      AchievementKind.blocks => totalBlocks,
      AchievementKind.verifiedMinutes => verifiedMinutes,
      AchievementKind.bestDayMinutes => bestDay,
      AchievementKind.streakDays => streak.best,
      AchievementKind.earlyBlocks => early,
      AchievementKind.lateBlocks => late,
      AchievementKind.sensorBlocks => sensor,
      AchievementKind.tasksDone => tasksCompleted,
      AchievementKind.daysRecorded => recordedDays,
      AchievementKind.categoryMinutes =>
        (byCategory[a.category ?? -1] ?? 0) ~/ 60,
    };

    return <AchievementStatus>[
      for (final a in Achievement.values)
        AchievementStatus(
          achievement: a,
          progress: progressOf(a),
          unlockedAt: unlockedAt[a.key],
        ),
    ];
  }
}
