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
    final id = await accounts.createAccount(name: '  Home  ', openingBalancePaise: 250000);
    final row = await (database.select(database.accounts)
          ..where((account) => account.id.equals(id)))
        .getSingle();
    expect(row.name, 'Home');
    expect(row.openingBalancePaise, 250000);

    await accounts.archiveAccount(id);
    final archived = await (database.select(database.accounts)
          ..where((account) => account.id.equals(id)))
        .getSingle();
    expect(archived.archivedAt, isNotNull);
  });

  test('creates a transaction with integer paise and validates category type', () async {
    final accountId = await accounts.createAccount(name: 'Monthly Expenses');
    final expense = await (database.select(database.categories)
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
    final saved = await (database.select(database.transactions)
          ..where((transaction) => transaction.id.equals(transactionId)))
        .getSingle();
    expect(saved.amountPaise, 125050);

    expect(
      () => transactions.createTransaction(
        accountId: accountId,
        categoryId: expense.id,
        type: 'income',
        amountPaise: 100,
        transactionDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
      ),
      throwsStateError,
    );
  });

  test('rejects zero and negative transaction amounts', () async {
    expect(
      () => transactions.createTransaction(
        accountId: 'missing',
        categoryId: 'missing',
        type: 'expense',
        amountPaise: 0,
        transactionDate: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
      ),
      throwsArgumentError,
    );
  });
}
