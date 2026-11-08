import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import 'data/transactions_repository.dart';

class TransactionHistoryFilter {
  const TransactionHistoryFilter(
      {this.accountId, this.fromDate, this.throughDate, this.type});
  final String? accountId;
  final int? fromDate;
  final int? throughDate;
  final String? type;

  @override
  bool operator ==(Object other) =>
      other is TransactionHistoryFilter &&
      other.accountId == accountId &&
      other.fromDate == fromDate &&
      other.throughDate == throughDate &&
      other.type == type;

  @override
  int get hashCode => Object.hash(accountId, fromDate, throughDate, type);
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref.watch(appDatabaseProvider));
});

final transactionHistoryProvider = StreamProvider.family<
    List<TransactionHistoryItem>, TransactionHistoryFilter>((ref, filter) {
  return ref.watch(transactionsRepositoryProvider).watchHistory(
        accountId: filter.accountId,
        fromDate: filter.fromDate,
        throughDate: filter.throughDate,
        type: filter.type,
      );
});

final transactionTrashProvider =
    StreamProvider<List<TransactionHistoryItem>>((ref) {
  return ref.watch(transactionsRepositoryProvider).watchTrash();
});

final transactionByIdProvider =
    FutureProvider.family<TransactionRow?, String>((ref, id) {
  return ref.watch(transactionsRepositoryProvider).getTransaction(id);
});
