import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/accounts.dart';
import 'tables/app_settings.dart';
import 'tables/balance_adjustments.dart';
import 'tables/categories.dart';
import 'tables/khata.dart';
import 'tables/transactions.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    BalanceAdjustments,
    KhataPeople,
    KhataEntries,
    KhataRepayments,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedDefaultCategories();
      await customStatement(
        'CREATE INDEX transactions_account_date_idx ON transactions (account_id, transaction_date)',
      );
      await customStatement(
        'CREATE INDEX transactions_category_date_idx ON transactions (category_id, transaction_date)',
      );
      await customStatement(
        'CREATE INDEX transactions_date_idx ON transactions (transaction_date)',
      );
      await customStatement(
        'CREATE INDEX transactions_deleted_date_idx ON transactions (deleted_at, transaction_date)',
      );
      await customStatement(
        'CREATE INDEX balance_adjustments_account_date_idx ON balance_adjustments (account_id, adjustment_date)',
      );
      await customStatement(
        'CREATE INDEX balance_adjustments_deleted_date_idx ON balance_adjustments (deleted_at, adjustment_date)',
      );
      await customStatement(
        'CREATE INDEX accounts_archived_sort_idx ON accounts (archived_at, sort_order)',
      );
      await customStatement(
        'CREATE INDEX accounts_pinned_sort_idx ON accounts (is_pinned, sort_order)',
      );
      await customStatement(
        'CREATE INDEX categories_type_active_sort_idx ON categories (type, is_active, sort_order)',
      );
      await _createKhataIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(balanceAdjustments);
        await customStatement(
          'CREATE INDEX balance_adjustments_account_date_idx ON balance_adjustments (account_id, adjustment_date)',
        );
        await customStatement(
          'CREATE INDEX balance_adjustments_deleted_date_idx ON balance_adjustments (deleted_at, adjustment_date)',
        );
      }
      if (from < 3) {
        // Additive only: existing finance tables and rows are untouched.
        await migrator.createTable(khataPeople);
        await migrator.createTable(khataEntries);
        await migrator.createTable(khataRepayments);
        await migrator.createTable(appSettings);
        await _createKhataIndexes();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createKhataIndexes() async {
    await customStatement(
      'CREATE INDEX khata_entries_person_date_idx ON khata_entries (person_id, entry_date)',
    );
    await customStatement(
      'CREATE INDEX khata_entries_deleted_idx ON khata_entries (deleted_at)',
    );
    await customStatement(
      'CREATE INDEX khata_repayments_entry_date_idx ON khata_repayments (entry_id, repayment_date)',
    );
  }

  Future<void> _seedDefaultCategories() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final seeds = <CategoriesCompanion>[
      _category(
        '10000000-0000-4000-8000-000000000001',
        'Food & Dining',
        'expense',
        0,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000002',
        'Groceries',
        'expense',
        1,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000003',
        'Transportation',
        'expense',
        2,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000004',
        'Vehicle Maintenance',
        'expense',
        3,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000005',
        'Housing & Utilities',
        'expense',
        4,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000006',
        'Shopping',
        'expense',
        5,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000007',
        'Household',
        'expense',
        6,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000008',
        'Health & Medical',
        'expense',
        7,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000009',
        'Personal Care',
        'expense',
        8,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000010',
        'Travel & Stay',
        'expense',
        9,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000011',
        'Entertainment',
        'expense',
        10,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000012',
        'Education',
        'expense',
        11,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000013',
        'Family & Gifts',
        'expense',
        12,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000014',
        'Financial Payments',
        'expense',
        13,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000015',
        'Donations',
        'expense',
        14,
        now,
      ),
      _category(
        '10000000-0000-4000-8000-000000000016',
        'Others',
        'expense',
        15,
        now,
      ),
      _category(
        '20000000-0000-4000-8000-000000000001',
        'Salary',
        'income',
        0,
        now,
      ),
      _category(
        '20000000-0000-4000-8000-000000000002',
        'Business',
        'income',
        1,
        now,
      ),
      _category(
        '20000000-0000-4000-8000-000000000003',
        'Freelancing',
        'income',
        2,
        now,
      ),
      _category(
        '20000000-0000-4000-8000-000000000004',
        'Investments',
        'income',
        3,
        now,
      ),
      _category(
        '20000000-0000-4000-8000-000000000005',
        'Rental Income',
        'income',
        4,
        now,
      ),
      _category(
        '20000000-0000-4000-8000-000000000006',
        'Gifts & Rewards',
        'income',
        5,
        now,
      ),
      _category(
        '20000000-0000-4000-8000-000000000007',
        'Refunds',
        'income',
        6,
        now,
      ),
      _category(
        '20000000-0000-4000-8000-000000000008',
        'Others',
        'income',
        7,
        now,
      ),
    ];
    await batch((batch) {
      batch.insertAll(categories, seeds, mode: InsertMode.insertOrIgnore);
    });
  }

  CategoriesCompanion _category(
    String id,
    String name,
    String type,
    int sortOrder,
    int now,
  ) {
    return CategoriesCompanion.insert(
      id: id,
      name: name,
      type: type,
      isSystem: const Value(true),
      sortOrder: Value(sortOrder),
      createdAt: now,
      updatedAt: now,
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'my_accounts_manager.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
