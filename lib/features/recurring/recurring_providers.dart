import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../transactions/transactions_providers.dart';
import 'data/recurring_repository.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(transactionsRepositoryProvider),
  );
});

final recurringRulesProvider = StreamProvider<List<RecurringRuleItem>>((ref) {
  return ref.watch(recurringRepositoryProvider).watchRules();
});
