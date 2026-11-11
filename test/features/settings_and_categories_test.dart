import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/privacy_state.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/database/database_provider.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';
import 'package:my_accounts_manager/features/categories/data/categories_repository.dart';
import 'package:my_accounts_manager/features/settings/data/settings_repository.dart';
import 'package:my_accounts_manager/features/settings/settings_providers.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('SettingsRepository', () {
    test('persists and overwrites the theme preference', () async {
      final settings = SettingsRepository(database);
      expect(await settings.watchValue(themeModeSettingKey).first, isNull);

      await settings.setValue(themeModeSettingKey, 'dark');
      expect(await settings.watchValue(themeModeSettingKey).first, 'dark');

      await settings.setValue(themeModeSettingKey, 'light');
      expect(await settings.watchValue(themeModeSettingKey).first, 'light');
    });

    test('keeps the hide-amounts preference across app restarts', () async {
      ProviderContainer launch() {
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
        );
        container.listen(amountsHiddenProvider, (_, _) {});
        return container;
      }

      final first = launch();
      expect(first.read(amountsHiddenProvider), isFalse);
      await first.read(amountsHiddenProvider.notifier).set(true);
      expect(first.read(amountsHiddenProvider), isTrue);
      first.dispose();

      final second = launch();
      await second.read(storedAmountsHiddenProvider.future);
      expect(second.read(amountsHiddenProvider), isTrue);
      second.dispose();
    });

    test('maps stored values to ThemeMode with a system default', () {
      expect(themeModeFromStorage(null), ThemeMode.system);
      expect(themeModeFromStorage('light'), ThemeMode.light);
      expect(themeModeFromStorage('dark'), ThemeMode.dark);
      expect(themeModeFromStorage('unexpected'), ThemeMode.system);
    });
  });

  group('CategoriesRepository management', () {
    test(
      'lists recently used categories first, then configured order',
      () async {
        final categories = CategoriesRepository(database);
        final initial = await categories.watchActiveByType('expense').first;
        final first = initial[0];
        final third = initial[2];
        final last = initial.last;
        final accountId = await AccountsRepository(
          database,
        ).createAccount(name: 'Wallet');
        final transactions = TransactionsRepository(database);
        for (final category in [third, last]) {
          await transactions.createTransaction(
            accountId: accountId,
            categoryId: category.id,
            type: 'expense',
            amountPaise: 100,
            transactionDate: 0,
          );
          // created_at has millisecond resolution.
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        final ordered = await categories
            .watchActiveByTypeByRecentUse('expense')
            .first;
        expect(ordered.map((category) => category.id).take(3), [
          last.id,
          third.id,
          first.id,
        ]);
        expect(ordered, hasLength(initial.length));
      },
    );

    test('creates a custom category at the end of its type', () async {
      final categories = CategoriesRepository(database);
      final id = await categories.createCategory(
        name: ' Pets ',
        type: 'expense',
        iconKey: 'others',
        colorValue: 0xFF0EA5E9,
      );

      final all = await categories.watchAllByType('expense').first;
      expect(all.last.id, id);
      expect(all.last.name, 'Pets');
      expect(all.last.isSystem, isFalse);
      expect(all.last.sortOrder, 16);
    });

    test('rejects duplicate names within a type, case-insensitively', () async {
      final categories = CategoriesRepository(database);
      expect(
        () => categories.createCategory(name: 'groceries', type: 'expense'),
        throwsStateError,
      );
      // Same name under the other type is allowed.
      await categories.createCategory(name: 'Groceries', type: 'income');
    });

    test('hides and restores categories without deleting them', () async {
      final categories = CategoriesRepository(database);
      const groceries = '10000000-0000-4000-8000-000000000002';

      await categories.setActive(groceries, active: false);
      final active = await categories.watchActiveByType('expense').first;
      expect(active.any((row) => row.id == groceries), isFalse);
      final all = await categories.watchAllByType('expense').first;
      expect(all.any((row) => row.id == groceries), isTrue);

      await categories.setActive(groceries, active: true);
      final restored = await categories.watchActiveByType('expense').first;
      expect(restored.any((row) => row.id == groceries), isTrue);
    });

    test('keeps built-in names but allows icon and colour changes', () async {
      final categories = CategoriesRepository(database);
      const groceries = '10000000-0000-4000-8000-000000000002';

      expect(
        () => categories.updateCategory(categoryId: groceries, name: 'Food'),
        throwsStateError,
      );
      await categories.updateCategory(
        categoryId: groceries,
        name: 'Groceries',
        iconKey: 'groceries',
        colorValue: 0xFF10B981,
      );
      final row = (await categories.watchAllByType('expense').first).firstWhere(
        (category) => category.id == groceries,
      );
      expect(row.iconKey, 'groceries');
      expect(row.colorValue, 0xFF10B981);
    });

    test('renames custom categories', () async {
      final categories = CategoriesRepository(database);
      final id = await categories.createCategory(name: 'Pets', type: 'expense');
      await categories.updateCategory(categoryId: id, name: 'Pet care');
      final row = (await categories.watchAllByType('expense').first).firstWhere(
        (category) => category.id == id,
      );
      expect(row.name, 'Pet care');
    });
  });
}
