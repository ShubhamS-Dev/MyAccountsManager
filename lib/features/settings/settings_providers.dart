import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import 'data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

ThemeMode themeModeFromStorage(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// Persisted Appearance preference. Defaults to following the device.
final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchValue(themeModeSettingKey)
      .map(themeModeFromStorage);
});

Future<void> saveThemeMode(WidgetRef ref, ThemeMode mode) {
  return ref
      .read(settingsRepositoryProvider)
      .setValue(themeModeSettingKey, mode.name);
}
