/// The routines the bot carries itself, so it runs a study day with no phone.
///
/// The firmware stores these same templates in flash
/// (`firmware/focusfreak/assets.cpp`, generated from this list by
/// `tools/make_firmware_assets.py` as `ROUTINE_KEYS`). Keep the two lists
/// the same, in the same order: the Routines menu is drawn from them on both.
library;

import '../domain/model/template.dart';

class BotRoutines {
  const BotRoutines._();

  /// Sequential sprints of at most 16 blocks: what fits on the bot.
  static const List<String> keys = <String>[
    'pomodoro',
    'fiftyTwo',
    'deepWork',
    'ultradian',
  ];

  static List<RoutineTemplate> get all => <RoutineTemplate>[
    for (final k in keys) Templates.byKey(k)!,
  ];

  /// "4h 10m", or "5h" on the hour, for the menu.
  static String length(RoutineTemplate t) {
    final m = t.totalMinutes;
    return m % 60 == 0 ? '${m ~/ 60}h' : '${m ~/ 60}h ${m % 60}m';
  }
}
