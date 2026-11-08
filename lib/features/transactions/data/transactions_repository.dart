import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

class TransactionsRepository {
  TransactionsRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

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
