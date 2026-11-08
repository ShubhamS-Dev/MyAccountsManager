import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

class TransactionHistoryItem {
  const TransactionHistoryItem({required this.transaction, required this.accountName, required this.categoryName});
  final TransactionRow transaction;
  final String accountName;
  final String categoryName;
}

class TransactionsRepository {
  TransactionsRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Stream<List<TransactionHistoryItem>> watchHistory({String? accountId, int? fromDate, int? throughDate, String? type}) {
    final query = _database.select(_database.transactions).join([
      innerJoin(_database.accounts, _database.accounts.id.equalsExp(_database.transactions.accountId)),
      innerJoin(_database.categories, _database.categories.id.equalsExp(_database.transactions.categoryId)),
    ])..where(_database.transactions.deletedAt.isNull());
    if (accountId != null) query.where(_database.transactions.accountId.equals(accountId));
    if (fromDate != null) query.where(_database.transactions.transactionDate.isBiggerOrEqualValue(fromDate));
    if (throughDate != null) query.where(_database.transactions.transactionDate.isSmallerOrEqualValue(throughDate));
    if (type != null) query.where(_database.transactions.type.equals(type));
    query.orderBy([OrderingTerm.desc(_database.transactions.transactionDate), OrderingTerm.desc(_database.transactions.createdAt)]);
    return query.watch().map((rows) => rows.map((row) => TransactionHistoryItem(
      transaction: row.readTable(_database.transactions),
      accountName: row.readTable(_database.accounts).name,
      categoryName: row.readTable(_database.categories).name,
    )).toList());
  }

  Future<String> createTransaction({
    required String accountId,
    required String categoryId,
    required String type,
    required int amountPaise,
    required int transactionDate,
    String? note,
  }) async {
    if (type != 'expense' && type != 'income') {
      throw ArgumentError.value(type, 'type', 'Expected expense or income.');
    }
    if (amountPaise <= 0) {
      throw ArgumentError.value(amountPaise, 'amountPaise', 'Amount must be positive paise.');
    }

    return _database.transaction(() async {
      final account = await (_database.select(_database.accounts)
            ..where((row) => row.id.equals(accountId)))
          .getSingleOrNull();
      if (account == null || account.archivedAt != null) {
        throw StateError('The selected Account does not exist or is archived.');
      }

      final category = await (_database.select(_database.categories)
            ..where((row) => row.id.equals(categoryId)))
          .getSingleOrNull();
      if (category == null || !category.isActive || category.type != type) {
        throw StateError('Select an active category matching the transaction type.');
      }

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final id = _uuid.v4();
      await _database.into(_database.transactions).insert(
            TransactionsCompanion.insert(
              id: id,
              accountId: accountId,
              categoryId: categoryId,
              type: type,
              amountPaise: amountPaise,
              transactionDate: transactionDate,
              note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }
}
