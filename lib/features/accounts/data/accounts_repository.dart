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
