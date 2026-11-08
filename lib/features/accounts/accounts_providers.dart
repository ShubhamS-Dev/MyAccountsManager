import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import 'data/accounts_repository.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(appDatabaseProvider));
});
