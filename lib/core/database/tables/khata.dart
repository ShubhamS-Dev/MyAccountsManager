import 'package:drift/drift.dart';

/// MyKhata tables form an independent ledger. Nothing here references
/// Accounts or regular Transactions, so khata activity can never change
/// Account balances or income/expense totals.
@DataClassName('KhataPersonRow')
class KhataPeople extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get colorValue => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (length(trim(name)) > 0)'];
}

@DataClassName('KhataEntryRow')
class KhataEntries extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().references(KhataPeople, #id)();

  /// `lent` (they owe you) or `borrowed` (you owe them).
  TextColumn get direction => text()();
  IntColumn get amountPaise => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get entryDate => integer()();
  IntColumn get dueDate => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (direction IN ('lent', 'borrowed'))",
    'CHECK (amount_paise > 0)',
  ];
}

@DataClassName('KhataRepaymentRow')
class KhataRepayments extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().references(KhataEntries, #id)();
  IntColumn get amountPaise => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get repaymentDate => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (amount_paise > 0)'];
}
