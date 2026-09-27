import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/data/repo/session_repository.dart';
import 'package:focusfreak_app/data/repo/settings_repository.dart';
import 'package:focusfreak_app/features/reports/data_export.dart';
import 'package:focusfreak_app/features/reports/data_import.dart';

/// The claim this file defends: a backup is a way *back*. Everything the
/// export writes, the import can read, and a restore never destroys what is
/// already on the phone.
void main() {
  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(db);
  });
  tearDown(() => db.close());

  Future<String> seedAndExport() async {
    final now = DateTime(2026, 8, 3, 9);
    await db
        .into(db.routines)
        .insert(
          RoutinesCompanion.insert(
            id: 'r1',
            name: 'Exam week',
            description: const Value('Two deep blocks'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.blocks)
        .insert(
          BlocksCompanion.insert(
            id: 'b1',
            routineId: 'r1',
            position: 0,
            name: 'Deep Work 1',
            durationMin: 90,
            category: 0,
            trackEnabled: const Value(true),
            startMin: const Value(540),
          ),
        );
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 't1',
            title: 'Finish problem set',
            createdAt: now,
          ),
        );
    await db
        .into(db.dayLogs)
        .insert(
          DayLogsCompanion.insert(
            day: DateTime(2026, 8, 2),
            verifiedMin: const Value(210),
            claimedMin: const Value(220),
            blocksDone: const Value(3),
          ),
        );
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            id: 's1',
            startedAt: now,
            logicalDay: DateTime(2026, 8, 3),
            blockName: 'Deep Work 1',
            category: 0,
            plannedSec: 5400,
            claimedSec: const Value(5400),
            verifiedSec: const Value(5300),
            finalState: 4,
            provenance: 2,
            trackEnabled: const Value(true),
          ),
        );
    await settings.setString(SettingKey.userName, 'Fahad');

    return const DataExport().fullJson(
      sessions: await db.select(db.sessions).get(),
      days: await SessionRepository(db).allDays(),
      routines: await db.select(db.routines).get(),
      blocks: await db.select(db.blocks).get(),
      tasks: await db.select(db.tasks).get(),
      settings: await settings.exportAll(),
    );
  }

  test('a backup restores into an empty phone', () async {
    final backup = await seedAndExport();

    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);
    final result = await DataImport(fresh).restore(backup);

    expect(result.routines, 1);
    expect(result.blocks, 1);
    expect(result.tasks, 1);
    expect(result.days, 1);
    expect(result.sessions, 1);
    expect(result.skipped, isEmpty);

    final routine = (await fresh.select(fresh.routines).get()).single;
    expect(routine.name, 'Exam week');
    final block = (await fresh.select(fresh.blocks).get()).single;
    expect(block.name, 'Deep Work 1');
    expect(block.durationMin, 90);
    expect(block.trackEnabled, isTrue);
    expect(block.startMin, 540, reason: 'a timed block must stay timed');

    final session = (await fresh.select(fresh.sessions).get()).single;
    expect(session.verifiedSec, 5300);
    expect(
      session.provenance,
      2,
      reason: 'a sensor-verified block cannot come back as app-verified',
    );

    expect(
      await SettingsRepository(fresh).getString(SettingKey.userName),
      'Fahad',
    );
  });

  test('restoring twice changes nothing the second time', () async {
    final backup = await seedAndExport();
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);

    await DataImport(fresh).restore(backup);
    await DataImport(fresh).restore(backup);

    expect((await fresh.select(fresh.sessions).get()), hasLength(1));
    expect((await fresh.select(fresh.routines).get()), hasLength(1));
    expect(
      (await fresh.select(fresh.blocks).get()),
      hasLength(1),
      reason: 'a second restore must not double a routine\'s blocks',
    );
  });

  test('a restore adds to what is here rather than replacing it', () async {
    // The rule that matters most: this is the only copy of the user's history,
    // and one mis-tapped file must not be able to destroy it.
    final backup = await seedAndExport();
    final other = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(other.close);

    await other
        .into(other.sessions)
        .insert(
          SessionsCompanion.insert(
            id: 'mine',
            startedAt: DateTime(2026, 7, 1, 8),
            logicalDay: DateTime(2026, 7, 1),
            blockName: 'Older block',
            category: 1,
            plannedSec: 1500,
            finalState: 4,
            provenance: 1,
          ),
        );

    await DataImport(other).restore(backup);

    final ids = (await other.select(other.sessions).get())
        .map((s) => s.id)
        .toSet();
    expect(ids, containsAll(<String>['mine', 's1']));
  });

  test('a file that is not a backup is refused, not half-applied', () async {
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);

    await expectLater(
      DataImport(fresh).restore('{"hello":"world"}'),
      throwsA(isA<NotABackupException>()),
    );
    await expectLater(
      DataImport(fresh).restore('not json at all'),
      throwsA(isA<NotABackupException>()),
    );
    expect(await fresh.select(fresh.sessions).get(), isEmpty);
  });

  test('one unreadable row costs one row, not the file', () async {
    const partial = '''
{
  "format": "focusfreak-export",
  "version": 1,
  "routines": [{"id": "r9", "name": "Good", "blocks": []}, {"id": "r8"}],
  "sessions": [{"id": "s9", "started_at": "not a date"}],
  "settings": {"theme_mode": "light"}
}''';
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);

    final result = await DataImport(fresh).restore(partial);

    expect(result.routines, 1);
    expect(result.sessions, 0);
    expect(result.skipped, hasLength(2));
    expect(
      await SettingsRepository(fresh).getString(SettingKey.themeMode),
      'light',
      reason: 'a bad session must not cost the settings',
    );
  });

  test('the summary is written for a person', () async {
    final backup = await seedAndExport();
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);

    final result = await DataImport(fresh).restore(backup);
    expect(result.summary, contains('1 routine'));
    expect(result.summary, contains('and'));
    expect(result.summary, isNot(contains('null')));
  });
}
