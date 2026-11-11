import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

const themeModeSettingKey = 'appearance.theme_mode';

class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  Stream<String?> watchValue(String key) {
    return (_database.select(_database.appSettings)
          ..where((row) => row.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  /// All stored values whose key starts with [prefix], keyed by full key.
  Stream<Map<String, String>> watchValuesWithPrefix(String prefix) {
    return (_database.select(_database.appSettings)
          ..where((row) => row.key.like('$prefix%')))
        .watch()
        .map((rows) => {for (final row in rows) row.key: row.value});
  }

  Future<void> setValue(String key, String value) {
    return _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
  }
}
