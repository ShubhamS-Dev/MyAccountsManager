import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'creates the version two schema and seeds built-in categories',
    () async {
      final expenseCategories = await (database.select(
        database.categories,
      )..where((category) => category.type.equals('expense'))).get();
      final incomeCategories = await (database.select(
        database.categories,
      )..where((category) => category.type.equals('income'))).get();

      expect(expenseCategories.length, 16);
      expect(incomeCategories.length, 8);
      expect(expenseCategories.every((category) => category.isSystem), isTrue);
      expect(incomeCategories.every((category) => category.isSystem), isTrue);
    },
  );

  test(
    'keeps default category seed stable after database initialization',
    () async {
      final before = await database.select(database.categories).get();
      await database.customStatement('SELECT 1');
      final after = await database.select(database.categories).get();
      expect(after.length, before.length);
      expect(
        after.map((row) => row.id).toSet(),
        before.map((row) => row.id).toSet(),
      );
    },
  );

  test('creates the balance adjustment table', () async {
    expect(await database.select(database.balanceAdjustments).get(), isEmpty);
  });

  test('creates MyKhata and settings tables in schema version three', () async {
    expect(database.schemaVersion, 3);
    expect(await database.select(database.khataPeople).get(), isEmpty);
    expect(await database.select(database.khataEntries).get(), isEmpty);
    expect(await database.select(database.khataRepayments).get(), isEmpty);
    expect(await database.select(database.appSettings).get(), isEmpty);
  });

  test('upgrades a version two database without losing finance data', () async {
    final directory = await Directory.systemTemp.createTemp('mam_migration');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/v2.sqlite');

    // Build a database, then reduce it to the exact version-two shape.
    final seeded = AppDatabase.forTesting(NativeDatabase(file));
    final accountId = await AccountsRepository(
      seeded,
    ).createAccount(name: 'Legacy', openingBalancePaise: 123450);
    await seeded.customStatement('DROP TABLE khata_repayments');
    await seeded.customStatement('DROP TABLE khata_entries');
    await seeded.customStatement('DROP TABLE khata_people');
    await seeded.customStatement('DROP TABLE app_settings');
    await seeded.customStatement('PRAGMA user_version = 2');
    await seeded.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);
    final account = await AccountsRepository(upgraded).getAccount(accountId);
    expect(account?.openingBalancePaise, 123450);
    expect((await upgraded.select(upgraded.categories).get()).length, 24);
    expect(await upgraded.select(upgraded.khataPeople).get(), isEmpty);
    expect(await upgraded.select(upgraded.appSettings).get(), isEmpty);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 3);
  });
}
