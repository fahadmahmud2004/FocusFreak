/// When each milestone was first reached.
///
/// Progress itself is *derived* — [AchievementEngine] recomputes it from the
/// record every time, so a restored backup or a merged device log lights the
/// right ones with no migration. The one thing arithmetic cannot recover is
/// the date, so that is all this table really holds.
///
/// **A recorded date is never cleared.** If a later recount says a milestone
/// is no longer met — a deleted session, a corrected day — the date stands.
/// Taking a milestone back is a punishment mechanic (`docs/ARCHITECTURE.md`).
library;

import 'package:drift/drift.dart';

import '../db/database.dart';

class AchievementRepository {
  AchievementRepository(this._db);

  final AppDatabase _db;

  Future<Map<String, DateTime>> unlockedDates() async {
    final rows = await _db.select(_db.achievements).get();
    return <String, DateTime>{
      for (final r in rows)
        if (r.unlockedAt != null) r.key: r.unlockedAt!,
    };
  }

  /// Records progress, and stamps anything newly reached.
  ///
  /// Returns the keys that crossed their target on *this* call, so a caller
  /// can celebrate them. Everything already stamped is left exactly as it was.
  Future<List<String>> record(
    Map<String, ({int progress, bool unlocked})> current, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final existing = await _db.select(_db.achievements).get();
    final byKey = <String, AchievementRow>{for (final r in existing) r.key: r};
    final fresh = <String>[];

    await _db.batch((b) {
      for (final entry in current.entries) {
        final was = byKey[entry.key];
        final alreadyStamped = was?.unlockedAt != null;
        final stamp = alreadyStamped
            ? was!.unlockedAt
            : (entry.value.unlocked ? at : null);
        if (!alreadyStamped && entry.value.unlocked) fresh.add(entry.key);

        b.insert(
          _db.achievements,
          AchievementsCompanion.insert(
            key: entry.key,
            progress: Value(entry.value.progress),
            unlockedAt: Value(stamp),
          ),
          onConflict: DoUpdate(
            (_) => AchievementsCompanion(
              progress: Value(entry.value.progress),
              unlockedAt: Value(stamp),
            ),
          ),
        );
      }
    });

    return fresh;
  }

  Stream<List<AchievementRow>> watch() => _db.select(_db.achievements).watch();
}
