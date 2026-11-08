import 'package:drift/drift.dart';

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => text()();
  TextColumn get iconKey => text().nullable()();
  IntColumn get colorValue => integer().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (type IN ('expense', 'income'))",
        'CHECK (length(trim(name)) > 0)',
      ];
}
