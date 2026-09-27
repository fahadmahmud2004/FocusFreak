import '../../core/ff_constants.dart';

part 'template_catalog.dart';

/// A block inside a built-in template.
class TemplateBlock {
  const TemplateBlock({
    required this.name,
    required this.durationMin,
    required this.category,
    this.description = '',
    this.track = false,
    this.startMin,
  }) : assert(
         name.length <= FfFirmware.blockNameMaxChars,
         'name exceeds the firmware char name[16]',
       ),
       assert(
         description.length <= FfFirmware.blockDescMaxChars,
         'description exceeds the firmware char desc[24]',
       );

  final String name;
  final String description;
  final int durationMin;
  final int category;
  final bool track;

  /// Minutes since midnight, or null for sequential.
  final int? startMin;
}

/// Which salah timetable a full-day routine was built on.
///
/// Salah in Dhaka moves by up to an hour and a half across the year, so every
/// full-day routine ships twice. Getting this wrong is not cosmetic: it is how
/// the old hand-timed templates ended up with a 3 PM Maghrib.
enum RoutineSeason {
  summer('Summer', 'Mar-Oct', 285, 780, 1005, 1110, 1220),
  winter('Winter', 'Nov-Feb', 320, 780, 975, 1085, 1160),
  ramadan('Ramadan', 'Fasting month', 300, 750, 980, 1080, 1160);

  const RoutineSeason(
    this.label,
    this.months,
    this.fajr,
    this.dhuhr,
    this.asr,
    this.maghrib,
    this.isha,
  );

  final String label;
  final String months;

  /// Salah times in Dhaka, minutes since midnight. The same table FW
  /// Mentorship's engine anchors its routines to.
  final int fajr;
  final int dhuhr;
  final int asr;
  final int maghrib;
  final int isha;

  /// The season a date falls in. Ramadan moves every year, so it is never
  /// picked automatically — the user chooses that routine themselves.
  static RoutineSeason of(DateTime date) =>
      date.month >= DateTime.november || date.month <= DateTime.february
      ? winter
      : summer;
}

/// A shipped routine.
class RoutineTemplate {
  const RoutineTemplate({
    required this.key,
    required this.name,
    required this.description,
    required this.blocks,
    this.basis = '',
    this.season,
  });

  final String key;
  final String name;
  final String description;

  /// The research the shape rests on. Shown in the template preview — a claim
  /// with a citation behind it is worth more than a claim without one, in the
  /// app and in the viva.
  final String basis;

  /// Null for the short sprints, which have no clock times to be seasonal.
  final RoutineSeason? season;

  final List<TemplateBlock> blocks;

  int get totalMinutes => blocks.fold(0, (sum, b) => sum + b.durationMin);

  int get deepWorkMinutes => blocks
      .where((b) => b.category == 0)
      .fold(0, (sum, b) => sum + b.durationMin);

  int get trackedBlocks => blocks.where((b) => b.track).length;

  /// True when every block is an appointment on the wall clock.
  bool get isClockAnchored => blocks.every((b) => b.startMin != null);
}

/// The shipped template catalogue.
///
/// Ported from FW Mentorship: 13 full days, each built on the season's salah
/// times and emitted once for summer and once for winter (Ramadan once), plus
/// four sprints that run from whenever they are started. The data is generated
/// by `tools/make_routines.py`; this class only names the parts of it the rest
/// of the app asks for.
class Templates {
  const Templates._();

  /// Everything shipped, in presentation order.
  static List<RoutineTemplate> get all => _catalog;

  static RoutineTemplate get standard => byKey('standard')!;
  static RoutineTemplate get earlyBird => byKey('earlyBird')!;
  static RoutineTemplate get nightOwl => byKey('nightOwl')!;

  /// The three chronotype tracks onboarding chooses between, summer timings.
  static List<RoutineTemplate> get dayTracks => <RoutineTemplate>[
    standard,
    earlyBird,
    nightOwl,
  ];

  static RoutineTemplate? byKey(String key) {
    for (final t in _catalog) {
      if (t.key == key) return t;
    }
    return null;
  }

  /// The variant of [key] built for [season], falling back to [key] itself
  /// when the routine has no such variant (sprints, Ramadan).
  static String keyFor(String key, RoutineSeason season) {
    final base = key.endsWith('Winter')
        ? key.substring(0, key.length - 'Winter'.length)
        : key;
    final variant = season == RoutineSeason.winter ? '${base}Winter' : base;
    return byKey(variant) != null ? variant : key;
  }

  /// Convenience for the onboarding quiz result.
  static RoutineTemplate forWakeHour(int hour) {
    if (hour <= 4) return earlyBird;
    if (hour >= 9) return nightOwl;
    return standard;
  }
}
