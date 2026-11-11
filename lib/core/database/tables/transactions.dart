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

  /// The recurring rule that created this transaction, if any. Plain text,
  /// not a foreign key, so the v4 migration can add it with ALTER TABLE.
  TextColumn get recurringRuleId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('expense', 'income'))",
    'CHECK (amount_paise > 0)',
  ];
}
