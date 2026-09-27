import '../model/template.dart';

/// How study is cut up.
enum BuilderStyle {
  deep('Deep', '90 on, 20 off', 90, 20),
  balanced('Balanced', '50 on, 10 off', 50, 10),
  pomodoro('Pomodoro', '25 on, 5 off', 25, 5);

  const BuilderStyle(this.label, this.detail, this.work, this.rest);

  final String label;
  final String detail;
  final int work;
  final int rest;
}

/// The answers the generator works from.
class BuilderInput {
  const BuilderInput({
    required this.wakeMin,
    required this.sleepMin,
    required this.targetStudyMinutes,
    this.style = BuilderStyle.deep,
    this.includePrayers = true,
    this.includeExercise = true,
    this.season = RoutineSeason.summer,
  });

  /// Minutes since midnight.
  final int wakeMin;
  final int sleepMin;
  final int targetStudyMinutes;
  final BuilderStyle style;
  final bool includePrayers;
  final bool includeExercise;
  final RoutineSeason season;

  BuilderInput copyWith({
    int? wakeMin,
    int? sleepMin,
    int? targetStudyMinutes,
    BuilderStyle? style,
    bool? includePrayers,
    bool? includeExercise,
    RoutineSeason? season,
  }) => BuilderInput(
    wakeMin: wakeMin ?? this.wakeMin,
    sleepMin: sleepMin ?? this.sleepMin,
    targetStudyMinutes: targetStudyMinutes ?? this.targetStudyMinutes,
    style: style ?? this.style,
    includePrayers: includePrayers ?? this.includePrayers,
    includeExercise: includeExercise ?? this.includeExercise,
    season: season ?? this.season,
  );
}

/// A generated day, and how much study actually fit.
class BuiltRoutine {
  const BuiltRoutine(this.blocks, this.studyMinutes, this.targetMinutes);

  final List<TemplateBlock> blocks;
  final int studyMinutes;
  final int targetMinutes;

  /// FW's rule: say so when the day falls short of the target by more than
  /// twenty minutes.
  bool get shortOfTarget => studyMinutes < targetMinutes - 20;
}

/// FW Mentorship's "build your own routine", ported from `buildRoutine`.
///
/// Lays study blocks between waking and sleep, puts meals and salah in by
/// clock time, and stops once the study target is met. What is left before
/// bed becomes free time, never pretend study. Meals and salah go in by
/// *clock time* rather than minutes since waking: "lunch seven hours after
/// wake" is what once gave a 3 AM riser a 10 AM Dhuhr.
///
/// Every block name fits the bot's 16 characters.
class RoutineBuilder {
  const RoutineBuilder._();

  static BuiltRoutine build(BuilderInput input) {
    final work = input.style.work;
    final rest = input.style.rest;
    final awake = (input.sleepMin - input.wakeMin) % 1440;
    final target = input.targetStudyMinutes;
    final s = input.season;

    final parts = <_Part>[];
    var used = 0;
    var studied = 0;
    void push(_Part p) {
      if (p.minutes <= 0) return;
      parts.add(p);
      used += p.minutes;
      if (p.track) studied += p.minutes;
    }

    push(
      input.includePrayers
          ? const _Part(30, 3, 'Wake & Fajr', 'Fajr, water, sunlight')
          : const _Part(30, 3, 'Wake Up', 'Water and sunlight'),
    );

    final slots = <(int, _Part)>[
      if (input.includePrayers) ...<(int, _Part)>[
        (435, const _Part(30, 3, 'Breakfast')),
        (s.dhuhr, const _Part(55, 3, 'Dhuhr & Lunch', 'Salah, shower, lunch')),
        (s.asr, const _Part(30, 3, 'Asr & Snack')),
        (s.maghrib, const _Part(40, 3, 'Maghrib Salah')),
        (s.isha, const _Part(50, 3, 'Isha & Dinner', 'Salah, then dinner')),
      ] else ...<(int, _Part)>[
        (435, const _Part(30, 3, 'Breakfast')),
        (780, const _Part(55, 3, 'Shower & Lunch')),
        (960, const _Part(25, 4, 'Afternoon Snack')),
        (1200, const _Part(50, 3, 'Dinner')),
      ],
    ];

    // A slot fires once the running clock has reached it. Slots already
    // behind the wake-up time are dropped, not replayed at breakfast.
    var next = 0;
    void dueSlots() {
      while (next < slots.length) {
        final (clock, part) = slots[next];
        final offset = (clock - input.wakeMin) % 1440;
        if (offset > used) break;
        next++;
        if (offset + part.minutes > awake) continue;
        push(part);
      }
    }

    dueSlots();

    var n = 0;
    while (studied < target && used + work + rest < awake - 60) {
      n++;
      final review = n > 2 && n % 3 == 0;
      push(switch (n) {
        _ when review => _Part(work, 2, 'Revision & MCQ', 'Book shut, recall'),
        1 => _Part(work, 0, 'Hardest Subject', 'Fresh head, hard work'),
        2 => _Part(work, 0, 'Same Subject', 'Keep going'),
        _ when n.isOdd => _Part(work, 0, 'Other Subject', 'Interleave'),
        _ => _Part(work, 0, 'Keep Going'),
      });
      dueSlots();
      if (studied >= target) break;
      push(
        n.isEven
            ? _Part(rest, 4, 'Walk Break', 'Get up, walk a little')
            : _Part(rest, 4, 'Break'),
      );
      dueSlots();
    }

    // Anchors the study loop never reached still have to happen, and at
    // their own time. FW stacked them straight after the last study block,
    // which put a winter Isha at 18:45; the wait before each is free time.
    while (next < slots.length) {
      final (clock, part) = slots[next];
      next++;
      final offset = (clock - input.wakeMin) % 1440;
      final start = offset > used ? offset : used;
      if (start + part.minutes > awake - 30) continue;
      if (start > used) {
        push(_Part(start - used, 4, 'Free Time', 'Family and rest'));
      }
      push(part);
    }

    if (input.includeExercise && used + 40 < awake - 60) {
      push(const _Part(40, 3, 'Exercise / Walk'));
    }
    if (used + 30 < awake - 30) {
      push(const _Part(30, 2, 'Day Revision', '+ flashcards'));
    }

    final leftover = awake - used - 30;
    if (leftover > 15) push(_Part(leftover, 4, 'Free Time', 'Family and rest'));
    push(_Part(awake - used, 4, 'Plan Tomorrow', 'Day done, write the plan'));
    push(_Part(1440 - awake, 5, 'Sleep'));

    // Times are derived from the durations, never set on their own.
    final blocks = <TemplateBlock>[];
    var t = input.wakeMin;
    for (final p in parts) {
      blocks.add(
        TemplateBlock(
          name: p.name,
          description: p.description,
          durationMin: p.minutes,
          category: p.category,
          track: p.track,
          startMin: t,
        ),
      );
      t = (t + p.minutes) % 1440;
    }
    return BuiltRoutine(blocks, studied, target);
  }
}

class _Part {
  const _Part(this.minutes, this.category, this.name, [this.description = '']);

  final int minutes;
  final int category;
  final String name;
  final String description;

  /// Study is tracked; everything else is not.
  bool get track => category <= 2;
}
