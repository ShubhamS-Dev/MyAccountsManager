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
