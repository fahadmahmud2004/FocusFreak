import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/ff_constants.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Routines,
    Blocks,
    Tasks,
    Subtasks,
    Tags,
    TaskTags,
    Sessions,
    SessionEvents,
    DayLogs,
    DeviceProfiles,
    AppSettings,
    Achievements,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// For tests: an isolated in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => FfApp.dbSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    beforeOpen: (details) async {
      // Cascade deletes are declared on the tables; SQLite ignores them
      // unless foreign keys are switched on for the connection.
      await customStatement('PRAGMA foreign_keys = ON');
    },
    // Add an onUpgrade step here for every schemaVersion bump. This
    // database is the user's only copy of their history — a dropped table
    // is unrecoverable data loss, not a migration shortcut.
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_day '
      'ON sessions (logical_day)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_started '
      'ON sessions (started_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_blocks_routine '
      'ON blocks (routine_id, position)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_events_session '
      'ON session_events (session_id, at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_due '
      'ON tasks (completed_at, due_at)',
    );
  }

  /// On Android/iOS this is a plain file. On web it is SQLite compiled to
  /// WASM, backed by OPFS or IndexedDB — the assets live in `web/` and are
  /// only fetched by the web build.
  ///
  /// Web is a development and preview surface, not the product: the tracking
  /// foreground service the app depends on cannot exist in a browser
  /// (`docs/APP_SPEC.md` §8). It is wired up because the visual work is done
  /// here, and because it keeps a future read-only web dashboard possible.
  static QueryExecutor _open() => driftDatabase(
    name: 'focusfreak',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
