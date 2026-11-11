import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

class CategoriesRepository {
  CategoriesRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Stream<List<CategoryRow>> watchActiveByType(String type) {
    _requireType(type);
    return (_database.select(_database.categories)
          ..where((category) => category.type.equals(type))
          ..where((category) => category.isActive.equals(true))
          ..orderBy([(category) => OrderingTerm.asc(category.sortOrder)]))
        .watch();
  }

  /// Active categories of a type, most recently used first. Categories never
  /// used keep their configured order after the used ones.
  Stream<List<CategoryRow>> watchActiveByTypeByRecentUse(String type) {
    _requireType(type);
    return _database
        .customSelect(
          'SELECT c.* FROM categories c '
          'LEFT JOIN (SELECT category_id, MAX(created_at) AS last_used '
          'FROM transactions WHERE deleted_at IS NULL '
          'GROUP BY category_id) t ON t.category_id = c.id '
          'WHERE c.type = ? AND c.is_active = 1 '
          'ORDER BY t.last_used IS NULL, t.last_used DESC, c.sort_order ASC',
          variables: [Variable.withString(type)],
          readsFrom: {_database.categories, _database.transactions},
        )
        .watch()
        .map(
          (rows) =>
              rows.map((row) => _database.categories.map(row.data)).toList(),
        );
  }

  /// All categories of a type, including hidden ones, for management.
  Stream<List<CategoryRow>> watchAllByType(String type) {
    _requireType(type);
    return (_database.select(_database.categories)
          ..where((category) => category.type.equals(type))
          ..orderBy([
            (category) => OrderingTerm.desc(category.isActive),
            (category) => OrderingTerm.asc(category.sortOrder),
          ]))
        .watch();
  }

  Future<String> createCategory({
    required String name,
    required String type,
    String? iconKey,
    int? colorValue,
  }) async {
    _requireType(type);
    final normalized = _requireName(name);
    return _database.transaction(() async {
      await _requireUniqueName(type, normalized);
      final last =
          await (_database.select(_database.categories)
                ..where((row) => row.type.equals(type))
                ..orderBy([(row) => OrderingTerm.desc(row.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final id = _uuid.v4();
      await _database
          .into(_database.categories)
          .insert(
            CategoriesCompanion.insert(
              id: id,
              name: normalized,
              type: type,
              iconKey: Value(iconKey),
              colorValue: Value(colorValue),
              sortOrder: Value((last?.sortOrder ?? -1) + 1),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  /// Built-in categories keep their name; only custom ones can be renamed.
  Future<void> updateCategory({
    required String categoryId,
    required String name,
    String? iconKey,
    int? colorValue,
  }) {
    final normalized = _requireName(name);
    return _database.transaction(() async {
      final current = await _requireCategory(categoryId);
      if (current.isSystem && normalized != current.name) {
        throw StateError('Built-in categories cannot be renamed.');
      }
      if (normalized.toLowerCase() != current.name.toLowerCase()) {
        await _requireUniqueName(current.type, normalized);
      }
      await (_database.update(
        _database.categories,
      )..where((row) => row.id.equals(categoryId))).write(
        CategoriesCompanion(
          name: Value(normalized),
          iconKey: Value(iconKey),
          colorValue: Value(colorValue),
          updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        ),
      );
    });
  }

  /// Hidden categories stay attached to existing transactions but are not
  /// offered for new ones.
  Future<void> setActive(String categoryId, {required bool active}) async {
    final changed =
        await (_database.update(
          _database.categories,
        )..where((row) => row.id.equals(categoryId))).write(
          CategoriesCompanion(
            isActive: Value(active),
            updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          ),
        );
    if (changed == 0) throw StateError('Category not found.');
  }

  Future<CategoryRow> _requireCategory(String categoryId) async {
    final row = await (_database.select(
      _database.categories,
    )..where((category) => category.id.equals(categoryId))).getSingleOrNull();
    if (row == null) throw StateError('Category not found.');
    return row;
  }

  Future<void> _requireUniqueName(String type, String name) async {
    final existing = await _database
        .customSelect(
          'SELECT 1 FROM categories WHERE type = ? AND lower(name) = lower(?) LIMIT 1',
          variables: [Variable.withString(type), Variable.withString(name)],
          readsFrom: {_database.categories},
        )
        .get();
    if (existing.isNotEmpty) {
      throw StateError('A category with this name already exists.');
    }
  }

  static String _requireName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.length > 80) {
      throw ArgumentError.value(name, 'name', 'Enter a category name.');
    }
    return normalized;
  }

  static void _requireType(String type) {
    if (type != 'expense' && type != 'income') {
      throw ArgumentError.value(type, 'type', 'Expected expense or income.');
    }
  }
}
