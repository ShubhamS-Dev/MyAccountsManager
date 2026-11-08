import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/app_database.dart';
import 'data/accounts_repository.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(appDatabaseProvider));
});
final activeAccountsProvider = StreamProvider<List<AccountRow>>((ref) {
  return ref.watch(accountsRepositoryProvider).watchActiveAccounts();
});

final accountByIdProvider = FutureProvider.family<AccountRow?, String>((ref, id) {
  return ref.watch(accountsRepositoryProvider).getAccount(id);
});

final archivedAccountsProvider = StreamProvider<List<AccountRow>>((ref) {
  return ref.watch(accountsRepositoryProvider).watchArchivedAccounts();
});

final accountBalancePaiseProvider = FutureProvider.family<int?, String>((ref, id) {
  final now = DateTime.now().toUtc();
  final todayUtc = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;
  return ref.watch(accountsRepositoryProvider).calculateBalancePaise(
    accountId: id,
    asOfDate: todayUtc,
  );
});

final balanceAdjustmentsProvider = StreamProvider.family<List<BalanceAdjustmentRow>, String>((ref, accountId) {
  return ref.watch(accountsRepositoryProvider).watchBalanceAdjustments(accountId);
});

final allAccountsProvider = StreamProvider<List<AccountRow>>((ref) {
  return ref.watch(accountsRepositoryProvider).watchAllAccounts();
});
