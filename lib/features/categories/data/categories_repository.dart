import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class CategoriesRepository {
  CategoriesRepository(this._database);

  final AppDatabase _database;

  Stream<List<CategoryRow>> watchActiveByType(String type) {
    if (type != 'expense' && type != 'income') {
      throw ArgumentError.value(type, 'type', 'Expected expense or income.');
    }
    return (_database.select(_database.categories)
          ..where((category) => category.type.equals(type))
          ..where((category) => category.isActive.equals(true))
          ..orderBy([(category) => OrderingTerm.asc(category.sortOrder)]))
        .watch();
  }
}
