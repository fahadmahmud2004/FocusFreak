import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../device/device_verification_source.dart';
import '../domain/engine/verification_source.dart';
import '../platform/phone_verification_source.dart';
import '../data/repo/achievement_repository.dart';
import '../data/repo/routine_repository.dart';
import '../data/repo/session_repository.dart';
import '../data/repo/settings_repository.dart';
import '../data/repo/task_repository.dart';

/// Dependency graph.
///
/// The database is created once and overridden in tests with an in-memory one,
/// which is why nothing below constructs its own.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepository(ref.watch(databaseProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepository(ref.watch(databaseProvider)),
);

/// The bot's half of verification.
///
/// Created once for the life of the app and *re-pointed* at each new
/// connection rather than rebuilt — see [DeviceVerificationSource.attach].
/// Rebuilding it would rebuild the session's composite source, and with it the
/// `SessionController`, discarding a block that was running when the bot
/// connected.
final deviceVerificationSourceProvider = Provider<DeviceVerificationSource>((
  ref,
) {
  final source = DeviceVerificationSource();
  ref.onDispose(source.dispose);
  return source;
});

/// The phone's own half of verification: screen lock, stillness as a dock
/// proxy, and — if the user opts in — whether another app was opened.
///
/// Long-lived for the same reason as the device source above: it is a member of
/// the session's composite, and replacing it would rebuild the composite and
/// discard a running block. `PhoneTracker` starts and stops the *observation*
/// inside it instead.
///
/// Overridden in tests with a `ManualVerificationSource`, which is also what
/// keeps the test suite free of platform channels.
final phoneVerificationSourceProvider = Provider<VerificationSource>((ref) {
  final source = PhoneVerificationSource();
  ref.onDispose(source.dispose);
  return source;
});

/// One-time startup work: install any templates this version ships that the
/// user does not have yet.
final bootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(routineRepositoryProvider).seedTemplates();
});

// --- derived data -----------------------------------------------------------

final routinesProvider = StreamProvider<List<Routine>>(
  (ref) => ref.watch(routineRepositoryProvider).watchAll(),
);

/// Routines the user has hidden.
///
/// Hiding a built-in template archives it, and for a while there was no way
/// back — the only route to it was a database edit. Anything a single tap can
/// remove, a single tap has to be able to restore.
final hiddenRoutinesProvider = StreamProvider<List<Routine>>(
  (ref) => ref
      .watch(routineRepositoryProvider)
      .watchAll(includeArchived: true)
      .map((all) => all.where((r) => r.archived).toList()),
);

final routineDetailProvider = StreamProvider.family<RoutineWithBlocks?, String>(
  (ref, id) => ref.watch(routineRepositoryProvider).watch(id),
);

final tasksProvider = StreamProvider.family<List<Task>, TaskFilter>(
  (ref, filter) => ref.watch(taskRepositoryProvider).watch(filter),
);

final todayLogProvider = StreamProvider<DayLog?>(
  (ref) => ref.watch(sessionRepositoryProvider).watchToday(),
);
