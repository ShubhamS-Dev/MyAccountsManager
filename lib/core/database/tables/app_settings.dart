import 'package:drift/drift.dart';

/// Small key/value store for local presentation preferences.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}
