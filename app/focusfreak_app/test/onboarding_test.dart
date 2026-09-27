import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/data/repo/routine_repository.dart';
import 'package:focusfreak_app/data/repo/settings_repository.dart';
import 'package:focusfreak_app/domain/model/template.dart';
import 'package:focusfreak_app/features/onboarding/onboarding_screen.dart';

/// First run.
///
/// The flow itself is a widget and is checked by eye; what is tested here is
/// the part that must hold — that the quiz can only ever land on a track this
/// app actually ships, and that the app knows to show the flow exactly once.
void main() {
  test('every chronotype names a real template', () {
    for (final type in Chronotype.values) {
      expect(
        Templates.byKey(type.key),
        isNotNull,
        reason: '${type.label} would recommend a routine that does not exist',
      );
    }
  });

  test('an unknown saved chronotype falls back rather than throwing', () {
    // A restored backup from a future version can carry a track this build
    // does not have.
    expect(Chronotype.fromKey('polyphasic'), Chronotype.standard);
    expect(Chronotype.fromKey(''), Chronotype.standard);
    expect(Chronotype.fromKey('nightOwl'), Chronotype.nightOwl);
  });

  group('the gate', () {
    late AppDatabase db;
    late SettingsRepository settings;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = SettingsRepository(db);
    });
    tearDown(() => db.close());

    test('a new install has not been through it', () async {
      expect(await settings.getBool(SettingKey.onboardingDone), isFalse);
    });

    test('finishing is remembered, and watched', () async {
      final seen = <bool>[];
      final sub = settings
          .watchBool(SettingKey.onboardingDone)
          .listen(seen.add);
      addTearDown(sub.cancel);

      await settings.setBool(SettingKey.onboardingDone, true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        seen.last,
        isTrue,
        reason: 'the app swaps itself over when this flips, so it must emit',
      );
    });

    test('the quiz can point the app at a seeded routine', () async {
      // The setting holds a routine *id*, which only exists after seeding —
      // the flow would otherwise write a key nothing can resolve.
      final routines = RoutineRepository(db);
      await routines.seedTemplates();

      final byKey = await routines.allTemplates();
      for (final type in Chronotype.values) {
        expect(byKey[type.key], isNotNull);
      }

      await settings.setString(
        SettingKey.activeRoutineId,
        byKey[Chronotype.nightOwl.key]!,
      );
      final id = await settings.getString(SettingKey.activeRoutineId);
      final row = await (db.select(
        db.routines,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.templateKey, 'nightOwl');
    });
  });
}
