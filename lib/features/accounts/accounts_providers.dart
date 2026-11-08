import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import 'data/accounts_repository.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(appDatabaseProvider));
});
final activeAccountsProvider = StreamProvider<List<AccountRow>>((ref) {
  return ref.watch(accountsRepositoryProvider).watchActiveAccounts();
});

final accountByIdProvider = FutureProvider.family<AccountRow?, String>((
  ref,
  id,
) {
  return ref.watch(accountsRepositoryProvider).getAccount(id);
});

final archivedAccountsProvider = StreamProvider<List<AccountRow>>((ref) {
  return ref.watch(accountsRepositoryProvider).watchArchivedAccounts();
});

int _todayUtcDate() {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;
}

final accountBalancePaiseProvider = StreamProvider.family<int?, String>((
  ref,
  id,
) {
  return ref.watch(accountsRepositoryProvider).watchBalancePaise(
    accountId: id,
    asOfDate: _todayUtcDate(),
  );
});

final totalActiveBalancePaiseProvider = StreamProvider<int>((ref) {
  return ref.watch(accountsRepositoryProvider).watchTotalActiveBalancePaise(
    asOfDate: _todayUtcDate(),
  );
});

final balanceAdjustmentsProvider =
    StreamProvider.family<List<BalanceAdjustmentRow>, String>((ref, accountId) {
      return ref
          .watch(accountsRepositoryProvider)
          .watchBalanceAdjustments(accountId);
    });

final allAccountsProvider = StreamProvider<List<AccountRow>>((ref) {
  return ref.watch(accountsRepositoryProvider).watchAllAccounts();
});
