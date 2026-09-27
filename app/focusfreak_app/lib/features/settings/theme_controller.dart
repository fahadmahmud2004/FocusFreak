import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repo/settings_repository.dart';
import '../../design/ff_theme.dart';

/// Which of the three looks the app is wearing, persisted.
///
/// Starts from the default synchronously so the first frame never flashes the
/// wrong theme, then reconciles with the stored value once it loads.
class ThemeController extends StateNotifier<FfThemeMode> {
  ThemeController(this._settings) : super(FfThemeMode.dark) {
    _load();
  }

  final SettingsRepository _settings;

  Future<void> _load() async {
    final stored = await _settings.getString(SettingKey.themeMode);
    final mode = _parse(stored);
    if (mounted) state = mode;
  }

  Future<void> set(FfThemeMode mode) async {
    state = mode;
    await _settings.setString(SettingKey.themeMode, mode.name);
  }

  /// Cycles dark → amoled → light → dark. Used by the toolbar toggle.
  Future<void> cycle() => set(switch (state) {
    FfThemeMode.dark => FfThemeMode.amoled,
    FfThemeMode.amoled => FfThemeMode.light,
    FfThemeMode.light => FfThemeMode.dark,
  });

  static FfThemeMode _parse(String v) => switch (v) {
    'light' => FfThemeMode.light,
    'amoled' => FfThemeMode.amoled,
    _ => FfThemeMode.dark,
  };
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, FfThemeMode>(
      (ref) => ThemeController(ref.watch(settingsRepositoryProvider)),
    );
