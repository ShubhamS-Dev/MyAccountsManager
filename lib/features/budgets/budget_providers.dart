import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/date_timestamp.dart';
import '../../core/time/today_provider.dart';
import '../settings/settings_providers.dart';
import '../transactions/transactions_providers.dart';
import 'domain/budget.dart';

final budgetSettingsProvider = StreamProvider<BudgetSettings>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchValuesWithPrefix(budgetSettingPrefix)
      .map(BudgetSettings.fromStorage);
});

/// Expenses from the 1st through today; Scheduled ones count from their date.
final monthExpensePaiseProvider = Provider<AsyncValue<int>>((ref) {
  final today = ref.watch(todayProvider);
  final date = DateOnly.fromUtcEpochMilliseconds(today);
  final filter = TransactionHistoryFilter(
    fromDate: DateTime.utc(date.year, date.month, 1).millisecondsSinceEpoch,
    throughDate: today,
  );
  return ref
      .watch(transactionHistoryProvider(filter))
      .whenData(
        (items) => items
            .where((item) => item.transaction.type == 'expense')
            .fold(0, (sum, item) => sum + item.transaction.amountPaise),
      );
});

/// Null data means no budget is set.
final budgetStatusProvider = Provider<AsyncValue<BudgetStatus?>>((ref) {
  final settings = ref.watch(budgetSettingsProvider);
  final spent = ref.watch(monthExpensePaiseProvider);
  if (settings.hasError) {
    return AsyncError(settings.error!, settings.stackTrace!);
  }
  if (spent.hasError) {
    return AsyncError(spent.error!, spent.stackTrace!);
  }
  if (!settings.hasValue || !spent.hasValue) return const AsyncLoading();
  final limit = settings.requireValue.limitPaise;
  if (limit == null) return const AsyncData(null);
  final date = DateOnly.fromUtcEpochMilliseconds(ref.watch(todayProvider));
  return AsyncData(
    BudgetStatus(
      limitPaise: limit,
      spentPaise: spent.requireValue,
      date: DateTime(date.year, date.month, date.day),
    ),
  );
});
