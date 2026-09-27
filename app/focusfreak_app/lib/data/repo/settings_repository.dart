import 'package:drift/drift.dart';

import '../db/database.dart';

/// Every persisted preference, in one place.
///
/// Typed keys rather than free-form strings, so a typo is a compile error and
/// the full list of what the app remembers is readable at a glance.
enum SettingKey {
  /// What to call the user. Empty until they say, and never asked for twice.
  userName('user_name', ''),

  /// A photo copied into the app's own storage, or empty for the monogram.
  userPhotoFile('user_photo_file', ''),

  themeMode('theme_mode', 'dark'),
  onboardingDone('onboarding_done', 'false'),
  dailyGoalMinutes('daily_goal_minutes', '240'),
  activeRoutineId('active_routine_id', ''),
  chronotype('chronotype', 'standard'),

  /// Whether app-only verification may use the accelerometer as a dock proxy.
  useStillnessAsDock('use_stillness_dock', 'true'),

  /// Opt-in. The app is fully functional without it.
  useAppUsageTracking('use_app_usage', 'false'),

  /// Whether stepping away pauses the countdown. Off: the block keeps
  /// counting and only the verified minutes stop.
  pauseWhenAway('pause_when_away', 'false'),

  /// Which alarm tone rings at the end of a run. An index into `AlarmTones`.
  alarmTone('alarm_tone', '0'),

  /// Remember the virtual bot, so the Bot tab opens connected to it.
  useVirtualBot('use_virtual_bot', 'false'),

  /// Block start, block end, and the last-three-seconds tick.
  soundEffects('sound_effects', 'true'),

  /// The one that has to reach you in the next room.
  alarmEnabled('alarm_enabled', 'true'),

  notifyBlockStart('notify_block_start', 'true'),
  notifyBlockEnd('notify_block_end', 'true'),
  notifyViolation('notify_violation', 'true'),
  keepScreenOnInFocus('keep_screen_on', 'false'),
  hapticsEnabled('haptics', 'true'),

  /// Strict mode matches the device's EEPROM streak definition: no freeze days.
  strictStreak('strict_streak', 'false'),

  weekStartsMonday('week_starts_monday', 'true'),
  lastDeviceAddress('last_device_address', ''),
  lastLogSyncAt('last_log_sync_at', ''),

  /// The virtual bot's own settings and best scores, as `key=value;` pairs.
  botOsSettings('botos_settings', '');

  const SettingKey(this.key, this.defaultValue);

  final String key;
  final String defaultValue;
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String> getString(SettingKey k) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(k.key))).getSingleOrNull();
    return row?.value ?? k.defaultValue;
  }

  Future<bool> getBool(SettingKey k) async => (await getString(k)) == 'true';

  Future<int> getInt(SettingKey k) async =>
      int.tryParse(await getString(k)) ?? int.tryParse(k.defaultValue) ?? 0;

  Future<DateTime?> getDateTime(SettingKey k) async {
    final v = await getString(k);
    return v.isEmpty ? null : DateTime.tryParse(v);
  }

  Future<void> setString(SettingKey k, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: k.key, value: value),
      );

  Future<void> setBool(SettingKey k, bool value) =>
      setString(k, value ? 'true' : 'false');

  Future<void> setInt(SettingKey k, int value) => setString(k, '$value');

  Future<void> setDateTime(SettingKey k, DateTime value) =>
      setString(k, value.toIso8601String());

  Stream<String> watchString(SettingKey k) =>
      (_db.select(_db.appSettings)..where((t) => t.key.equals(k.key)))
          .watchSingleOrNull()
          .map((row) => row?.value ?? k.defaultValue);

  Stream<bool> watchBool(SettingKey k) =>
      watchString(k).map((v) => v == 'true');

  Stream<int> watchInt(SettingKey k) => watchString(
    k,
  ).map((v) => int.tryParse(v) ?? int.tryParse(k.defaultValue) ?? 0);

  /// Everything at once, for the backup file.
  Future<Map<String, String>> exportAll() async {
    final rows = await _db.select(_db.appSettings).get();
    return <String, String>{for (final r in rows) r.key: r.value};
  }

  /// Restore from a backup.
  ///
  /// Unknown keys are kept rather than dropped: a backup taken from a newer
  /// version must survive a round trip through an older one.
  Future<void> importAll(Map<String, String> values) async {
    await _db.batch((b) {
      for (final e in values.entries) {
        b.insert(
          _db.appSettings,
          AppSettingsCompanion.insert(key: e.key, value: e.value),
          onConflict: DoUpdate(
            (_) => AppSettingsCompanion(value: Value(e.value)),
          ),
        );
      }
    });
  }

  Future<void> reset(SettingKey k) =>
      (_db.delete(_db.appSettings)..where((t) => t.key.equals(k.key))).go();
}
