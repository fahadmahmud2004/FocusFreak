import 'package:characters/characters.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/core/ff_constants.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/data/repo/settings_repository.dart';
import 'package:focusfreak_app/features/settings/profile_store.dart';

/// The name and face on the More tab.
///
/// Covered at the repository and helper level rather than through the widget:
/// `MoreScreen` builds the live provider graph, and a widget test that touches
/// that **hangs rather than fails** under the fake clock.
void main() {
  group('the monogram', () {
    test('takes one letter from each of two names', () {
      expect(initialsOf('Fahad Mahmud'), 'FM');
      expect(initialsOf('  ada   lovelace  '), 'AL');
    });

    test('takes two letters from a single name', () {
      expect(initialsOf('Fahad'), 'FA');
    });

    test('uses the first and last of three', () {
      expect(initialsOf('Ada Byron Lovelace'), 'AL');
    });

    test('counts characters, not bytes', () {
      // Cutting a name by code unit would render half a glyph. Bangla is the
      // case that matters here, and it is the language the project's own
      // documents are written in.
      expect(initialsOf('ফাহাদ'), isNotEmpty);
      expect(initialsOf('ফাহাদ মাহমুদ'), isNotEmpty);
      expect(initialsOf('ফাহাদ').characters.length, lessThanOrEqualTo(2));
    });

    test('nothing in, nothing out', () {
      // An empty monogram is the signal to fall back to the app's own mark.
      expect(initialsOf(''), '');
      expect(initialsOf('   '), '');
    });
  });

  group('the profile', () {
    late AppDatabase db;
    late SettingsRepository settings;
    late ProfileStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = SettingsRepository(db);
      store = ProfileStore(settings);
    });
    tearDown(() => db.close());

    test('starts empty — the app never assumes a name', () async {
      expect(await settings.getString(SettingKey.userName), '');
      expect(await settings.getString(SettingKey.userPhotoFile), '');
    });

    test('a name is trimmed and kept', () async {
      await store.setName('  Fahad Mahmud  ');
      expect(await settings.getString(SettingKey.userName), 'Fahad Mahmud');
    });

    test('clearing the name is allowed', () async {
      await store.setName('Fahad');
      await store.setName('');
      expect(await settings.getString(SettingKey.userName), '');
    });

    test('removing a photo that was never set is harmless', () async {
      await store.removePhoto();
      expect(await settings.getString(SettingKey.userPhotoFile), '');
    });
  });

  group('the colophon', () {
    test('the one link the app opens is https', () {
      expect(FfApp.siteUrl, startsWith('https://'));
    });

    test('the motto is the product one', () {
      expect(FfApp.tagline, 'Your daily focus buddy');
    });
  });
}
