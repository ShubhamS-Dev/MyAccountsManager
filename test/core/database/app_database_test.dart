import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('creates the version one schema and seeds built-in categories', () async {
    final expenseCategories = await (database.select(database.categories)
          ..where((category) => category.type.equals('expense')))
        .get();
    final incomeCategories = await (database.select(database.categories)
          ..where((category) => category.type.equals('income')))
        .get();

    expect(expenseCategories.length, 16);
    expect(incomeCategories.length, 8);
    expect(expenseCategories.every((category) => category.isSystem), isTrue);
    expect(incomeCategories.every((category) => category.isSystem), isTrue);
  });

  test('keeps default category seed stable after database initialization', () async {
    final before = await database.select(database.categories).get();
    await database.customStatement('SELECT 1');
    final after = await database.select(database.categories).get();
    expect(after.length, before.length);
    expect(after.map((row) => row.id).toSet(), before.map((row) => row.id).toSet());
  });
}
