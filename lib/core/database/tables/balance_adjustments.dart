import 'package:drift/drift.dart';

import 'accounts.dart';

@DataClassName('BalanceAdjustmentRow')
class BalanceAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  IntColumn get amountPaise => integer()();
  TextColumn get reason => text().withLength(min: 1, max: 500)();
  IntColumn get adjustmentDate => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (amount_paise != 0)',
        'CHECK (length(trim(reason)) > 0)',
      ];
}
