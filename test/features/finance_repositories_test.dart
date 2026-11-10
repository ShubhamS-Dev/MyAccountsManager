import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase database;
  late AccountsRepository accounts;
  late TransactionsRepository transactions;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accounts = AccountsRepository(database);
    transactions = TransactionsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates and archives an Account without deleting its record', () async {
    final id = await accounts.createAccount(
      name: '  Home  ',
      openingBalancePaise: 250000,
    );
    final row = await (database.select(
      database.accounts,
    )..where((account) => account.id.equals(id))).getSingle();
    expect(row.name, 'Home');
    expect(row.openingBalancePaise, 250000);

    await accounts.archiveAccount(id);
    final archived = await (database.select(
      database.accounts,
    )..where((account) => account.id.equals(id))).getSingle();
    expect(archived.archivedAt, isNotNull);
  });

  test(
    'creates a transaction with integer paise and validates category type',
    () async {
      final accountId = await accounts.createAccount(name: 'Monthly Expenses');
      final expense =
          await (database.select(database.categories)
                ..where((category) => category.type.equals('expense'))
                ..where((category) => category.name.equals('Food & Dining')))
              .getSingle();

      final transactionId = await transactions.createTransaction(
        accountId: accountId,
        categoryId: expense.id,
        type: 'expense',
        amountPaise: 125050,
        transactionDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
      );
      final saved =
          await (database.select(database.transactions)
                ..where((transaction) => transaction.id.equals(transactionId)))
              .getSingle();
      expect(saved.amountPaise, 125050);

      await expectLater(
        transactions.createTransaction(
          accountId: accountId,
          categoryId: expense.id,
          type: 'income',
          amountPaise: 100,
          transactionDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
        ),
        throwsStateError,
      );
    },
  );

  test('rejects zero and negative transaction amounts', () async {
    await expectLater(
      transactions.createTransaction(
        accountId: 'missing',
        categoryId: 'missing',
        type: 'expense',
        amountPaise: 0,
        transactionDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
      ),
      throwsArgumentError,
    );
  });
  test(
    'calculates Account balance using effective, non-deleted transactions',
    () async {
      final accountId = await accounts.createAccount(
        name: 'Home',
        openingBalancePaise: 100000,
      );
      final expense =
          await (database.select(database.categories)
                ..where((category) => category.type.equals('expense'))
                ..where((category) => category.name.equals('Food & Dining')))
              .getSingle();
      final income =
          await (database.select(database.categories)
                ..where((category) => category.type.equals('income'))
                ..where((category) => category.name.equals('Salary')))
              .getSingle();

      final today = DateTime.utc(2026, 11, 8).millisecondsSinceEpoch;
      final tomorrow = DateTime.utc(2026, 11, 9).millisecondsSinceEpoch;
      final deletedExpenseId = await transactions.createTransaction(
        accountId: accountId,
        categoryId: expense.id,
        type: 'expense',
        amountPaise: 25000,
        transactionDate: today,
      );
      await transactions.createTransaction(
        accountId: accountId,
        categoryId: income.id,
        type: 'income',
        amountPaise: 50000,
        transactionDate: today,
      );
      await transactions.createTransaction(
        accountId: accountId,
        categoryId: expense.id,
        type: 'expense',
        amountPaise: 10000,
        transactionDate: tomorrow,
      );
      await (database.update(
        database.transactions,
      )..where((row) => row.id.equals(deletedExpenseId))).write(
        TransactionsCompanion(
          deletedAt: Value(
            DateTime.utc(2026, 11, 8, 12).millisecondsSinceEpoch,
          ),
        ),
      );

      final balance = await accounts.calculateBalancePaise(
        accountId: accountId,
        asOfDate: today,
      );
      expect(balance, 150000);
    },
  );

  test(
    'reactively emits Account balance after a transaction is created',
    () async {
      final accountId = await accounts.createAccount(
        name: 'Reactive balance',
        openingBalancePaise: 10000,
      );
      final today = DateTime.utc(2026, 11, 8).millisecondsSinceEpoch;
      final expense =
          await (database.select(database.categories)
                ..where((row) => row.type.equals('expense'))
                ..where((row) => row.name.equals('Food & Dining')))
              .getSingle();

      final expectation = expectLater(
        accounts.watchBalancePaise(accountId: accountId, asOfDate: today),
        emitsInOrder([10000, 7500]),
      );
      await Future<void>.delayed(Duration.zero);
      await transactions.createTransaction(
        accountId: accountId,
        categoryId: expense.id,
        type: 'expense',
        amountPaise: 2500,
        transactionDate: today,
      );
      await expectation;
    },
  );

  test(
    'returns null when calculating balance for an unknown Account',
    () async {
      final balance = await accounts.calculateBalancePaise(
        accountId: 'missing',
        asOfDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
      );
      expect(balance, isNull);
    },
  );

  test(
    'updates Account details and pin state without changing opening balance',
    () async {
      final id = await accounts.createAccount(
        name: 'Old name',
        openingBalancePaise: 12345,
      );
      await accounts.updateAccount(
        accountId: id,
        name: 'New name',
        description: 'Updated',
      );
      await accounts.setPinned(id, pinned: true);
      final row = await accounts.getAccount(id);
      expect(row?.name, 'New name');
      expect(row?.description, 'Updated');
      expect(row?.openingBalancePaise, 12345);
      expect(row?.isPinned, isTrue);
      await accounts.setPinned(id, pinned: false);
      expect((await accounts.getAccount(id))?.isPinned, isFalse);
    },
  );

  test('rejects blank Account names during edit', () async {
    final id = await accounts.createAccount(name: 'Valid');
    await expectLater(
      accounts.updateAccount(accountId: id, name: '   '),
      throwsArgumentError,
    );
  });

  test(
    'restores archived Account without changing its financial data',
    () async {
      final id = await accounts.createAccount(
        name: 'Trip',
        openingBalancePaise: 7654,
      );
      await accounts.archiveAccount(id);
      expect(
        (await accounts.watchActiveAccounts().first).any((row) => row.id == id),
        isFalse,
      );
      expect(
        (await accounts.watchArchivedAccounts().first).any(
          (row) => row.id == id,
        ),
        isTrue,
      );
      await accounts.restoreAccount(id);
      final restored = await accounts.getAccount(id);
      expect(restored?.archivedAt, isNull);
      expect(restored?.openingBalancePaise, 7654);
      expect(
        (await accounts.watchActiveAccounts().first).any((row) => row.id == id),
        isTrue,
      );
    },
  );

  test(
    'watches transaction history joined with Account and category and applies filters',
    () async {
      final accountId = await accounts.createAccount(name: 'Office');
      final expense =
          await (database.select(database.categories)
                ..where((row) => row.type.equals('expense'))
                ..where((row) => row.name.equals('Food & Dining')))
              .getSingle();
      final income =
          await (database.select(database.categories)
                ..where((row) => row.type.equals('income'))
                ..where((row) => row.name.equals('Salary')))
              .getSingle();
      await (database.update(database.categories)
            ..where((row) => row.id.equals(expense.id)))
          .write(
            const CategoriesCompanion(
              iconKey: Value('food'),
              colorValue: Value(0xFF008577),
            ),
          );
      final date = DateTime.utc(2026, 11, 8).millisecondsSinceEpoch;
      await transactions.createTransaction(
        accountId: accountId,
        categoryId: expense.id,
        type: 'expense',
        amountPaise: 2500,
        transactionDate: date,
        note: 'Lunch',
      );
      await transactions.createTransaction(
        accountId: accountId,
        categoryId: income.id,
        type: 'income',
        amountPaise: 500000,
        transactionDate: date,
      );

      final all = await transactions.watchHistory().first;
      expect(all, hasLength(2));
      expect(all.first.accountName, 'Office');
      expect(all.first.categoryName, 'Salary');
      expect(all.first.transaction.type, 'income');
      final foodItem = all.singleWhere(
        (item) => item.categoryName == 'Food & Dining',
      );
      expect(foodItem.categoryIconKey, 'food');
      expect(foodItem.categoryColorValue, 0xFF008577);

      final expenses = await transactions
          .watchHistory(
            accountId: accountId,
            type: 'expense',
            fromDate: date,
            throughDate: date,
          )
          .first;
      expect(expenses, hasLength(1));
      expect(expenses.single.transaction.note, 'Lunch');
    },
  );

  test(
    'moves transactions to Trash, restores them, and permanently deletes only trashed rows',
    () async {
      final accountId = await accounts.createAccount(name: 'Personal');
      final category =
          await (database.select(database.categories)
                ..where((row) => row.type.equals('expense'))
                ..where((row) => row.name.equals('Food & Dining')))
              .getSingle();
      final id = await transactions.createTransaction(
        accountId: accountId,
        categoryId: category.id,
        type: 'expense',
        amountPaise: 1200,
        transactionDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
        note: 'Coffee',
      );

      await transactions.softDeleteTransaction(id);
      expect(await transactions.watchHistory().first, isEmpty);
      final trashed = await transactions.watchTrash().first;
      expect(trashed, hasLength(1));
      expect(trashed.single.transaction.id, id);
      expect(trashed.single.transaction.deletedAt, isNotNull);

      await transactions.restoreTransaction(id);
      expect(await transactions.watchTrash().first, isEmpty);
      expect(
        (await transactions.watchHistory().first).single.transaction.id,
        id,
      );

      await transactions.softDeleteTransaction(id);
      await transactions.permanentlyDeleteTransaction(id);
      expect(await transactions.watchTrash().first, isEmpty);
      expect(
        await (database.select(
          database.transactions,
        )..where((row) => row.id.equals(id))).getSingleOrNull(),
        isNull,
      );
      await expectLater(
        transactions.permanentlyDeleteTransaction(id),
        throwsStateError,
      );
    },
  );

  test(
    'updates transaction fields and allows moving it to another active Account',
    () async {
      final sourceAccountId = await accounts.createAccount(name: 'Personal');
      final targetAccountId = await accounts.createAccount(name: 'Office');
      final expense =
          await (database.select(database.categories)
                ..where((row) => row.type.equals('expense'))
                ..where((row) => row.name.equals('Food & Dining')))
              .getSingle();
      final income =
          await (database.select(database.categories)
                ..where((row) => row.type.equals('income'))
                ..where((row) => row.name.equals('Salary')))
              .getSingle();
      final originalDate = DateTime.utc(2026, 11, 7).millisecondsSinceEpoch;
      final updatedDate = DateTime.utc(2026, 11, 8).millisecondsSinceEpoch;
      final id = await transactions.createTransaction(
        accountId: sourceAccountId,
        categoryId: expense.id,
        type: 'expense',
        amountPaise: 2500,
        transactionDate: originalDate,
        note: 'Old note',
      );

      await transactions.updateTransaction(
        transactionId: id,
        accountId: targetAccountId,
        categoryId: income.id,
        type: 'income',
        amountPaise: 990050,
        transactionDate: updatedDate,
        note: '  Updated note  ',
      );

      final updated = await transactions.getTransaction(id);
      expect(updated?.accountId, targetAccountId);
      expect(updated?.categoryId, income.id);
      expect(updated?.type, 'income');
      expect(updated?.amountPaise, 990050);
      expect(updated?.transactionDate, updatedDate);
      expect(updated?.note, 'Updated note');
      expect(
        (await transactions.watchHistory(accountId: sourceAccountId).first),
        isEmpty,
      );
      expect(
        (await transactions.watchHistory(accountId: targetAccountId).first)
            .single
            .transaction
            .id,
        id,
      );
    },
  );

  test(
    'does not allow editing a trashed transaction or moving a transaction into an archived Account',
    () async {
      final activeAccountId = await accounts.createAccount(name: 'Active');
      final archivedAccountId = await accounts.createAccount(name: 'Archived');
      await accounts.archiveAccount(archivedAccountId);
      final category =
          await (database.select(database.categories)
                ..where((row) => row.type.equals('expense'))
                ..where((row) => row.name.equals('Food & Dining')))
              .getSingle();
      final id = await transactions.createTransaction(
        accountId: activeAccountId,
        categoryId: category.id,
        type: 'expense',
        amountPaise: 100,
        transactionDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
      );

      await expectLater(
        transactions.updateTransaction(
          transactionId: id,
          accountId: archivedAccountId,
          categoryId: category.id,
          type: 'expense',
          amountPaise: 200,
          transactionDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
        ),
        throwsStateError,
      );
      await transactions.softDeleteTransaction(id);
      await expectLater(
        transactions.updateTransaction(
          transactionId: id,
          accountId: activeAccountId,
          categoryId: category.id,
          type: 'expense',
          amountPaise: 200,
          transactionDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'balance adjustments affect Account balance by date and preserve reason history',
    () async {
      final accountId = await accounts.createAccount(
        name: 'Home',
        openingBalancePaise: 100000,
      );
      final today = DateTime.utc(2026, 11, 8).millisecondsSinceEpoch;
      final tomorrow = DateTime.utc(2026, 11, 9).millisecondsSinceEpoch;

      await accounts.createBalanceAdjustment(
        accountId: accountId,
        amountPaise: 25000,
        reason: 'Cash found during reconciliation',
        adjustmentDate: today,
      );
      await accounts.createBalanceAdjustment(
        accountId: accountId,
        amountPaise: -10000,
        reason: 'Correct entry mistake',
        adjustmentDate: tomorrow,
      );

      expect(
        await accounts.calculateBalancePaise(
          accountId: accountId,
          asOfDate: today,
        ),
        125000,
      );
      expect(
        await accounts.calculateBalancePaise(
          accountId: accountId,
          asOfDate: tomorrow,
        ),
        115000,
      );
      final history = await accounts.watchBalanceAdjustments(accountId).first;
      expect(history, hasLength(2));
      expect(history.first.reason, 'Correct entry mistake');
      expect(history.first.amountPaise, -10000);
    },
  );

  test(
    'rejects zero, blank-reason, and archived Account balance adjustments',
    () async {
      final activeAccountId = await accounts.createAccount(name: 'Active');
      await expectLater(
        accounts.createBalanceAdjustment(
          accountId: activeAccountId,
          amountPaise: 0,
          reason: 'Invalid zero',
          adjustmentDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
        ),
        throwsArgumentError,
      );
      await expectLater(
        accounts.createBalanceAdjustment(
          accountId: activeAccountId,
          amountPaise: 100,
          reason: '   ',
          adjustmentDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
        ),
        throwsArgumentError,
      );

      await accounts.archiveAccount(activeAccountId);
      await expectLater(
        accounts.createBalanceAdjustment(
          accountId: activeAccountId,
          amountPaise: 100,
          reason: 'Should not be allowed',
          adjustmentDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
        ),
        throwsStateError,
      );
    },
  );
}
