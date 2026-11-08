import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

class AccountsRepository {
  AccountsRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Stream<List<AccountRow>> watchActiveAccounts() {
    return (_database.select(_database.accounts)
          ..where((account) => account.archivedAt.isNull())
          ..orderBy([
            (account) => OrderingTerm.desc(account.isPinned),
            (account) => OrderingTerm.asc(account.sortOrder),
            (account) => OrderingTerm.asc(account.name),
          ]))
        .watch();
  }

  Future<String> createAccount({
    required String name,
    String? description,
    int openingBalancePaise = 0,
    String? iconKey,
    int? colorValue,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Account name is required.');
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _database.into(_database.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            name: normalizedName,
            description: Value(description?.trim().isEmpty == true ? null : description?.trim()),
            openingBalancePaise: Value(openingBalancePaise),
            iconKey: Value(iconKey),
            colorValue: Value(colorValue),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Returns the Account balance in paise as of [asOfDate].
  ///
  /// Only non-deleted transactions dated on or before [asOfDate] are included.
  /// The caller supplies a UTC-midnight calendar date.
  Future<int?> calculateBalancePaise({
    required String accountId,
    required int asOfDate,
  }) async {
    final account = await (_database.select(_database.accounts)
          ..where((row) => row.id.equals(accountId)))
        .getSingleOrNull();
    if (account == null) return null;

    final entries = await (_database.select(_database.transactions)
          ..where((row) => row.accountId.equals(accountId))
          ..where((row) => row.deletedAt.isNull())
          ..where((row) => row.transactionDate.isSmallerOrEqualValue(asOfDate)))
        .get();

    var balancePaise = account.openingBalancePaise;
    for (final entry in entries) {
      if (entry.type == 'income') {
        balancePaise += entry.amountPaise;
      } else if (entry.type == 'expense') {
        balancePaise -= entry.amountPaise;
      }
    }
    return balancePaise;
  }

  Future<AccountRow?> getAccount(String accountId) {
    return (_database.select(_database.accounts)
          ..where((row) => row.id.equals(accountId)))
        .getSingleOrNull();
  }

  Future<void> updateAccount({
    required String accountId,
    required String name,
    String? description,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Account name is required.');
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final changed = await (_database.update(_database.accounts)
          ..where((row) => row.id.equals(accountId))
          ..where((row) => row.archivedAt.isNull()))
        .write(AccountsCompanion(
      name: Value(normalizedName),
      description: Value(description?.trim().isEmpty == true ? null : description?.trim()),
      updatedAt: Value(now),
    ));
    if (changed == 0) throw StateError('Account not found or archived.');
  }

  Future<void> setPinned(String accountId, {required bool pinned}) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final changed = await (_database.update(_database.accounts)
          ..where((row) => row.id.equals(accountId))
          ..where((row) => row.archivedAt.isNull()))
        .write(AccountsCompanion(
      isPinned: Value(pinned),
      updatedAt: Value(now),
    ));
    if (changed == 0) throw StateError('Account not found or archived.');
  }

  Future<void> archiveAccount(String accountId) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_database.update(_database.accounts)
          ..where((account) => account.id.equals(accountId))
          ..where((account) => account.archivedAt.isNull()))
        .write(AccountsCompanion(
      archivedAt: Value(now),
      updatedAt: Value(now),
    ));
  }
}
