import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/database/database_provider.dart';
import 'package:my_accounts_manager/core/time/today_provider.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';
import 'package:my_accounts_manager/features/export/data/csv_export.dart';
import 'package:my_accounts_manager/features/export/export_providers.dart';
import 'package:my_accounts_manager/features/my_khata/data/khata_repository.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';

void main() {
  final nov1 = DateTime.utc(2026, 11, 1).millisecondsSinceEpoch;
  final nov5 = DateTime.utc(2026, 11, 5).millisecondsSinceEpoch;
  final nov11 = DateTime.utc(2026, 11, 11).millisecondsSinceEpoch;
  final nov20 = DateTime.utc(2026, 11, 20).millisecondsSinceEpoch;

  group('CsvExport fields', () {
    test('formats dates and rupee amounts for spreadsheets', () {
      expect(CsvExport.isoDate(nov5), '2026-11-05');
      expect(CsvExport.rupees(150050), '1500.50');
      expect(CsvExport.rupees(5), '0.05');
      expect(CsvExport.rupees(1000000000), '10000000.00');
    });

    test('quotes separators and neutralises formulas', () {
      expect(CsvExport.field('Rent'), 'Rent');
      expect(CsvExport.field('Tea, snacks'), '"Tea, snacks"');
      expect(CsvExport.field('He said "hi"'), '"He said ""hi"""');
      expect(CsvExport.field('line\nbreak'), '"line\nbreak"');
      expect(CsvExport.field('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
      expect(CsvExport.field('+91 98765'), "'+91 98765");
      expect(CsvExport.field('@home'), "'@home");
    });
  });

  group('with a database', () {
    late AppDatabase database;
    late ProviderContainer container;
    late Directory directory;
    final shared = <List<File>>[];

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      directory = await Directory.systemTemp.createTemp('export_test');
      shared.clear();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          todayProvider.overrideWithValue(nov11),
          exportDirectoryProvider.overrideWith((ref) async => directory),
          fileSharerProvider.overrideWithValue((files, subject) async {
            shared.add(files);
          }),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
      await directory.delete(recursive: true);
    });

    Future<String> category(String type) async =>
        (await (database.select(database.categories)
                  ..where((row) => row.type.equals(type))
                  ..limit(1))
                .getSingle())
            .id;

    test('transactions file: posted, scheduled, notes, no Trash', () async {
      final accountId = await AccountsRepository(
        database,
      ).createAccount(name: 'HDFC Savings');
      final transactions = TransactionsRepository(database);
      await transactions.createTransaction(
        accountId: accountId,
        categoryId: await category('expense'),
        type: 'expense',
        amountPaise: 150050,
        transactionDate: nov5,
        note: 'Groceries, weekly',
      );
      await transactions.createTransaction(
        accountId: accountId,
        categoryId: await category('income'),
        type: 'income',
        amountPaise: 5000000,
        transactionDate: nov20,
      );
      final trashed = await transactions.createTransaction(
        accountId: accountId,
        categoryId: await category('expense'),
        type: 'expense',
        amountPaise: 999,
        transactionDate: nov5,
        note: 'Trashed one',
      );
      await transactions.softDeleteTransaction(trashed);

      final count = await exportCsv(
        container.read,
        transactions: true,
        khata: false,
      );

      expect(count, 1);
      final file = shared.single.single;
      expect(file.path, endsWith('transactions_20261111.csv'));
      // UTF-8 BOM so Excel reads ₹ and non-Latin names; Dart's decoder
      // drops it again on read.
      final bytes = await file.readAsBytes();
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(bytes);
      expect(text, startsWith('Date,Type,Account,Category,'));
      final lines = text.trim().split('\r\n');
      expect(lines, hasLength(3));
      expect(lines[1], startsWith('2026-11-20,Income,HDFC Savings,'));
      expect(lines[1], endsWith(',50000.00,,Scheduled'));
      expect(lines[2], startsWith('2026-11-05,Expense,HDFC Savings,'));
      expect(lines[2], endsWith(',1500.50,"Groceries, weekly",Posted'));
      expect(text, isNot(contains('Trashed one')));
    });

    test('MyKhata file: entries numbered, repayments linked', () async {
      final khata = KhataRepository(database);
      final asha = await khata.createPerson(name: 'Asha');
      final ravi = await khata.createPerson(name: 'Ravi');
      final lent = await khata.createEntry(
        personId: asha,
        direction: khataLent,
        amountPaise: 100000,
        entryDate: nov1,
        dueDate: nov5,
      );
      await khata.createEntry(
        personId: ravi,
        direction: khataBorrowed,
        amountPaise: 20000,
        entryDate: nov5,
      );
      await khata.recordRepayment(
        entryId: lent,
        amountPaise: 40000,
        repaymentDate: nov5,
        note: 'UPI',
      );

      await exportCsv(container.read, transactions: true, khata: true);

      final files = shared.single;
      expect(files.map((f) => f.path.split('/').last), [
        'transactions_20261111.csv',
        'mykhata_20261111.csv',
      ]);
      final lines = (await files.last.readAsString()).trim().split('\r\n');
      expect(lines, [
        CsvExport.khataHeader.join(','),
        'Entry,1,2026-11-01,Asha,Lent,1000.00,600.00,2026-11-05,Overdue,',
        'Entry,2,2026-11-05,Ravi,Borrowed,200.00,200.00,,Open,',
        'Repayment,1,2026-11-05,Asha,Received,400.00,,,,UPI',
      ]);
    });

    test('nothing selected shares nothing', () async {
      expect(
        await exportCsv(container.read, transactions: false, khata: false),
        0,
      );
      expect(shared, isEmpty);
    });
  });
}
