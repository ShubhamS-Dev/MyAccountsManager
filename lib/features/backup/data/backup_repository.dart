import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'backup_codec.dart';

/// Copies the whole database into a [BackupSnapshot] and back.
///
/// Works on raw rows so every table and column (Trash, settings, recurring
/// rules) round-trips without per-table code. A backup from an older schema
/// restores too: its missing columns take their defaults, as a migration would.
class BackupRepository {
  BackupRepository(this._database);

  final AppDatabase _database;

  Future<BackupSnapshot> snapshot() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _database.allTables) {
      final rows = await _database
          .customSelect('SELECT * FROM "${table.actualTableName}"')
          .get();
      tables[table.actualTableName] = [for (final row in rows) row.data];
    }
    return BackupSnapshot(
      schemaVersion: _database.schemaVersion,
      createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      tables: tables,
    );
  }

  /// Throws [BackupFormatException] if [snapshot] does not fit this schema.
  void validate(BackupSnapshot snapshot) {
    if (snapshot.schemaVersion > _database.schemaVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app. Update the app '
        'and try again.',
      );
    }
    final known = {
      for (final table in _database.allTables)
        table.actualTableName: {
          for (final column in table.$columns) column.name,
        },
    };
    for (final MapEntry(key: name, value: rows) in snapshot.tables.entries) {
      final columns = known[name];
      if (columns == null) throw const BackupFormatException();
      for (final row in rows) {
        for (final MapEntry(:key, :value) in row.entries) {
          if (!columns.contains(key)) throw const BackupFormatException();
          if (value != null &&
              value is! int &&
              value is! String &&
              value is! double) {
            throw const BackupFormatException();
          }
        }
      }
    }
  }

  /// Replaces every table with [snapshot] in one transaction; on any error
  /// nothing changes.
  Future<void> restore(BackupSnapshot snapshot) async {
    validate(snapshot);
    // Declared table order already puts parents before children.
    final tables = _database.allTables.toList();
    await _database.transaction(() async {
      await _database.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in tables.reversed) {
        await _database.customStatement(
          'DELETE FROM "${table.actualTableName}"',
        );
      }
      for (final table in tables) {
        for (final row in snapshot.tables[table.actualTableName] ?? const []) {
          if (row.isEmpty) continue;
          final columns = row.keys.map((column) => '"$column"').join(', ');
          final marks = List.filled(row.length, '?').join(', ');
          await _database.customStatement(
            'INSERT INTO "${table.actualTableName}" ($columns) '
            'VALUES ($marks)',
            row.values.toList(),
          );
        }
      }
    });
    // Raw statements skip Drift's change tracking; wake every stream.
    _database.notifyUpdates({
      for (final table in tables) TableUpdate.onTable(table),
    });
  }
}
