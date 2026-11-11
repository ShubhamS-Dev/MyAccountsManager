import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';

/// A repeating transaction. Occurrence n falls on [startDate] advanced n
/// periods of [frequency]; monthly and yearly keep the start day, clamped to
/// the month's last day.
@DataClassName('RecurringRuleRow')
class RecurringRules extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get type => text()();
  IntColumn get amountPaise => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get frequency => text()();
  IntColumn get startDate => integer()();

  /// Last date an occurrence may fall on, inclusive.
  IntColumn get endDate => integer().nullable()();

  /// Index of the next occurrence not yet saved as a transaction.
  IntColumn get nextIndex => integer().withDefault(const Constant(1))();
  IntColumn get pausedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('expense', 'income'))",
    "CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly'))",
    'CHECK (amount_paise > 0)',
    'CHECK (next_index >= 0)',
  ];
}
