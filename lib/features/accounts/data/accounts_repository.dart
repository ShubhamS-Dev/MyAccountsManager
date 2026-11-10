import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

class AccountsRepository {
  AccountsRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Stream<List<AccountRow>> watchAllAccounts() => (_database.select(
    _database.accounts,
  )..orderBy([(a) => OrderingTerm.asc(a.name)])).watch();

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

  Stream<List<AccountRow>> watchArchivedAccounts() {
    return (_database.select(_database.accounts)
          ..where((account) => account.archivedAt.isNotNull())
          ..orderBy([(account) => OrderingTerm.desc(account.archivedAt)]))
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
    await _database
        .into(_database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            name: normalizedName,
            description: Value(
              description?.trim().isEmpty == true ? null : description?.trim(),
            ),
            openingBalancePaise: Value(openingBalancePaise),
            iconKey: Value(iconKey),
            colorValue: Value(colorValue),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Stream<List<BalanceAdjustmentRow>> watchBalanceAdjustments(String accountId) {
    return (_database.select(_database.balanceAdjustments)
          ..where((row) => row.accountId.equals(accountId))
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([
            (row) => OrderingTerm.desc(row.adjustmentDate),
            (row) => OrderingTerm.desc(row.createdAt),
          ]))
        .watch();
  }

  Future<String> createBalanceAdjustment({
    required String accountId,
    required int amountPaise,
    required String reason,
    required int adjustmentDate,
  }) async {
    if (amountPaise == 0) {
      throw ArgumentError.value(
        amountPaise,
        'amountPaise',
        'Adjustment must not be zero.',
      );
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty || normalizedReason.length > 500) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Enter a reason of up to 500 characters.',
      );
    }

    return _database.transaction(() async {
      final account = await (_database.select(
        _database.accounts,
      )..where((row) => row.id.equals(accountId))).getSingleOrNull();
      if (account == null || account.archivedAt != null) {
        throw StateError('Select an active Account to adjust its balance.');
      }
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final id = _uuid.v4();
      await _database
          .into(_database.balanceAdjustments)
          .insert(
            BalanceAdjustmentsCompanion.insert(
              id: id,
              accountId: accountId,
              amountPaise: amountPaise,
              reason: normalizedReason,
              adjustmentDate: adjustmentDate,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  /// Reactively watches the effective Account balance from all source tables.
  Stream<int?> watchBalancePaise({
    required String accountId,
    required int asOfDate,
  }) {
    return _database
        .customSelect(
          '''
      SELECT a.opening_balance_paise
        + COALESCE((
          SELECT SUM(CASE WHEN t.type = 'income'
            THEN t.amount_paise ELSE -t.amount_paise END)
          FROM transactions t
          WHERE t.account_id = a.id AND t.deleted_at IS NULL
            AND t.transaction_date <= ?
        ), 0)
        + COALESCE((
          SELECT SUM(b.amount_paise)
          FROM balance_adjustments b
          WHERE b.account_id = a.id AND b.deleted_at IS NULL
            AND b.adjustment_date <= ?
        ), 0) AS balance_paise
      FROM accounts a WHERE a.id = ?
      ''',
          variables: [
            Variable.withInt(asOfDate),
            Variable.withInt(asOfDate),
            Variable.withString(accountId),
          ],
          readsFrom: {
            _database.accounts,
            _database.transactions,
            _database.balanceAdjustments,
          },
        )
        .watch()
        .map(
          (rows) =>
              rows.isEmpty ? null : rows.single.read<int>('balance_paise'),
        );
  }

  /// Reactively watches combined balances across all active Accounts.
  Stream<int> watchTotalActiveBalancePaise({required int asOfDate}) {
    return _database
        .customSelect(
          '''
      SELECT COALESCE(SUM(
        a.opening_balance_paise
        + COALESCE((
          SELECT SUM(CASE WHEN t.type = 'income'
            THEN t.amount_paise ELSE -t.amount_paise END)
          FROM transactions t
          WHERE t.account_id = a.id AND t.deleted_at IS NULL
            AND t.transaction_date <= ?
        ), 0)
        + COALESCE((
          SELECT SUM(b.amount_paise)
          FROM balance_adjustments b
          WHERE b.account_id = a.id AND b.deleted_at IS NULL
            AND b.adjustment_date <= ?
        ), 0)
      ), 0) AS total_balance_paise
      FROM accounts a WHERE a.archived_at IS NULL
      ''',
          variables: [Variable.withInt(asOfDate), Variable.withInt(asOfDate)],
          readsFrom: {
            _database.accounts,
            _database.transactions,
            _database.balanceAdjustments,
          },
        )
        .watch()
        .map((rows) => rows.single.read<int>('total_balance_paise'));
  }

  /// Returns the Account balance in paise as of [asOfDate].
  ///
  /// Only non-deleted transactions dated on or before [asOfDate] are included.
  /// The caller supplies a UTC-midnight calendar date.
  Future<int?> calculateBalancePaise({
    required String accountId,
    required int asOfDate,
  }) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(accountId))).getSingleOrNull();
    if (account == null) return null;

    final entries =
        await (_database.select(_database.transactions)
              ..where((row) => row.accountId.equals(accountId))
              ..where((row) => row.deletedAt.isNull())
              ..where(
                (row) => row.transactionDate.isSmallerOrEqualValue(asOfDate),
              ))
            .get();

    final adjustments =
        await (_database.select(_database.balanceAdjustments)
              ..where((row) => row.accountId.equals(accountId))
              ..where((row) => row.deletedAt.isNull())
              ..where(
                (row) => row.adjustmentDate.isSmallerOrEqualValue(asOfDate),
              ))
            .get();

    var balancePaise = account.openingBalancePaise;
    for (final adjustment in adjustments) {
      balancePaise += adjustment.amountPaise;
    }
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
    return (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(accountId))).getSingleOrNull();
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
    final changed =
        await (_database.update(_database.accounts)
              ..where((row) => row.id.equals(accountId))
              ..where((row) => row.archivedAt.isNull()))
            .write(
              AccountsCompanion(
                name: Value(normalizedName),
                description: Value(
                  description?.trim().isEmpty == true
                      ? null
                      : description?.trim(),
                ),
                updatedAt: Value(now),
              ),
            );
    if (changed == 0) throw StateError('Account not found or archived.');
  }

  Future<void> setPinned(String accountId, {required bool pinned}) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final changed =
        await (_database.update(_database.accounts)
              ..where((row) => row.id.equals(accountId))
              ..where((row) => row.archivedAt.isNull()))
            .write(
              AccountsCompanion(isPinned: Value(pinned), updatedAt: Value(now)),
            );
    if (changed == 0) throw StateError('Account not found or archived.');
  }

  Future<void> restoreAccount(String accountId) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final changed =
        await (_database.update(_database.accounts)
              ..where((account) => account.id.equals(accountId))
              ..where((account) => account.archivedAt.isNotNull()))
            .write(
              AccountsCompanion(
                archivedAt: const Value(null),
                updatedAt: Value(now),
              ),
            );
    if (changed == 0) throw StateError('Archived Account not found.');
  }

  Future<void> archiveAccount(String accountId) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_database.update(_database.accounts)
          ..where((account) => account.id.equals(accountId))
          ..where((account) => account.archivedAt.isNull()))
        .write(
          AccountsCompanion(archivedAt: Value(now), updatedAt: Value(now)),
        );
  }
}
