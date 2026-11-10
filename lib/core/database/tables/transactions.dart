import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';

@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get type => text()();
  IntColumn get amountPaise => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get transactionDate => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('expense', 'income'))",
    'CHECK (amount_paise > 0)',
  ];
}
