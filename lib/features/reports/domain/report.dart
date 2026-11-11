import 'dart:math' as math;

import '../../../core/formatting/date_timestamp.dart';
import '../../../core/time/day_range.dart';
import '../../../core/time/today_provider.dart';
import '../../transactions/data/transactions_repository.dart';

/// What the Reports tab is looking at.
class ReportFilter {
  const ReportFilter({
    required this.range,
    this.type = 'expense',
    this.accountId,
    this.category,
    this.includeScheduled = false,
  });

  final DayRange range;

  /// Which side the category breakdown shows: 'expense' or 'income'.
  final String type;
  final String? accountId;

  /// Category name, matching History's filter.
  final String? category;
  final bool includeScheduled;

  ReportFilter copyWith({
    DayRange? range,
    String? type,
    String? Function()? accountId,
    String? Function()? category,
    bool? includeScheduled,
  }) => ReportFilter(
    range: range ?? this.range,
    type: type ?? this.type,
    accountId: accountId == null ? this.accountId : accountId(),
    category: category == null ? this.category : category(),
    includeScheduled: includeScheduled ?? this.includeScheduled,
  );
}

enum TrendBucket { day, week, month }

class TrendPoint {
  const TrendPoint({
    required this.start,
    required this.income,
    required this.expense,
  });

  /// First day of the bucket (UTC-midnight milliseconds).
  final int start;
  final int income;
  final int expense;
}

class CategorySlice {
  const CategorySlice({
    required this.name,
    required this.amount,
    required this.previousAmount,
    required this.count,
    this.colorSlot,
    this.iconKey,
  });

  /// Null for the folded "Other" slice.
  final String name;
  final int amount;
  final int previousAmount;
  final int count;

  /// Fixed categorical slot, stable while filters change; null = Other.
  final int? colorSlot;
  final String? iconKey;

  bool get isOther => colorSlot == null;
}

class AccountSlice {
  const AccountSlice({
    required this.accountId,
    required this.name,
    required this.income,
    required this.expense,
  });

  final String accountId;
  final String name;
  final int income;
  final int expense;
}

/// Everything the Reports tab draws, computed from History items.
class ReportData {
  const ReportData({
    required this.through,
    required this.income,
    required this.expense,
    required this.previousIncome,
    required this.previousExpense,
    required this.count,
    required this.days,
    required this.bucket,
    required this.trend,
    required this.categories,
    required this.categoryCount,
    required this.accounts,
    required this.topTransactions,
  });

  /// Last day counted: the range end, or today when Scheduled is excluded.
  final int through;
  final int income;
  final int expense;
  final int previousIncome;
  final int previousExpense;
  final int count;

  /// Days counted, for averages.
  final int days;
  final TrendBucket bucket;
  final List<TrendPoint> trend;

  /// Largest first; categories without a colour slot fold into one Other.
  final List<CategorySlice> categories;

  /// Distinct categories before folding.
  final int categoryCount;
  final List<AccountSlice> accounts;

  /// Largest transactions of the selected type.
  final List<TransactionHistoryItem> topTransactions;

  int get net => income - expense;
  bool get isEmpty => count == 0;

  /// Categorical slots available before folding into Other.
  static const colorSlots = 7;

  static ReportData build(
    List<TransactionHistoryItem> items,
    ReportFilter filter,
    int today,
  ) {
    final range = filter.range;
    final through = filter.includeScheduled
        ? range.through
        : math.min(range.through, today);
    final counted = through < range.from
        ? DayRange(range.from, range.from)
        : DayRange(range.from, through);
    final empty = through < range.from;

    bool matches(TransactionHistoryItem item) {
      final t = item.transaction;
      if (filter.accountId != null && t.accountId != filter.accountId) {
        return false;
      }
      if (filter.category != null && item.categoryName != filter.category) {
        return false;
      }
      if (!filter.includeScheduled &&
          isScheduledDate(t.transactionDate, today)) {
        return false;
      }
      return true;
    }

    final scoped = items.where(matches).toList();
    final current = empty
        ? <TransactionHistoryItem>[]
        : scoped
              .where((i) => counted.contains(i.transaction.transactionDate))
              .toList();
    final previousRange = counted.previous;
    final previous = scoped
        .where((i) => previousRange.contains(i.transaction.transactionDate))
        .toList();

    var income = 0;
    var expense = 0;
    for (final item in current) {
      if (item.transaction.type == 'income') {
        income += item.transaction.amountPaise;
      } else {
        expense += item.transaction.amountPaise;
      }
    }
    var previousIncome = 0;
    var previousExpense = 0;
    for (final item in previous) {
      if (item.transaction.type == 'income') {
        previousIncome += item.transaction.amountPaise;
      } else {
        previousExpense += item.transaction.amountPaise;
      }
    }

    final bucket = counted.days <= 31
        ? TrendBucket.day
        : counted.days <= 120
        ? TrendBucket.week
        : TrendBucket.month;

    return ReportData(
      through: counted.through,
      income: income,
      expense: expense,
      previousIncome: previousIncome,
      previousExpense: previousExpense,
      count: current.length,
      days: counted.days,
      bucket: bucket,
      trend: empty ? const [] : _trend(current, counted, bucket),
      categories: _categories(items, current, previous, filter.type),
      categoryCount: current
          .where((i) => i.transaction.type == filter.type)
          .map((i) => i.categoryName)
          .toSet()
          .length,
      accounts: _accounts(current),
      topTransactions:
          current.where((i) => i.transaction.type == filter.type).toList()
            ..sort(
              (a, b) => b.transaction.amountPaise.compareTo(
                a.transaction.amountPaise,
              ),
            ),
    );
  }

  /// First day of the bucket holding [date].
  static int bucketStart(int date, TrendBucket bucket) {
    final day = DateOnly.fromUtcEpochMilliseconds(date);
    return switch (bucket) {
      TrendBucket.day => date,
      // Weeks start on Monday.
      TrendBucket.week =>
        date - (day.weekday - 1) * Duration.millisecondsPerDay,
      TrendBucket.month => DateTime.utc(
        day.year,
        day.month,
      ).millisecondsSinceEpoch,
    };
  }

  static int _nextBucket(int start, TrendBucket bucket) {
    final day = DateOnly.fromUtcEpochMilliseconds(start);
    return switch (bucket) {
      TrendBucket.day => start + Duration.millisecondsPerDay,
      TrendBucket.week => start + 7 * Duration.millisecondsPerDay,
      TrendBucket.month => DateTime.utc(
        day.year,
        day.month + 1,
      ).millisecondsSinceEpoch,
    };
  }

  static List<TrendPoint> _trend(
    List<TransactionHistoryItem> items,
    DayRange range,
    TrendBucket bucket,
  ) {
    final income = <int, int>{};
    final expense = <int, int>{};
    for (final item in items) {
      final key = bucketStart(item.transaction.transactionDate, bucket);
      final target = item.transaction.type == 'income' ? income : expense;
      target.update(
        key,
        (value) => value + item.transaction.amountPaise,
        ifAbsent: () => item.transaction.amountPaise,
      );
    }
    // Every bucket in the range, so quiet periods show as gaps.
    return [
      for (
        var start = bucketStart(range.from, bucket);
        start <= range.through;
        start = _nextBucket(start, bucket)
      )
        TrendPoint(
          start: start,
          income: income[start] ?? 0,
          expense: expense[start] ?? 0,
        ),
    ];
  }

  static List<CategorySlice> _categories(
    List<TransactionHistoryItem> all,
    List<TransactionHistoryItem> current,
    List<TransactionHistoryItem> previous,
    String type,
  ) {
    // Colour slots go to the biggest categories across all time, so a
    // category keeps its colour while the date or Account filter changes.
    final lifetime = <String, int>{};
    for (final item in all.where((i) => i.transaction.type == type)) {
      lifetime.update(
        item.categoryName,
        (value) => value + item.transaction.amountPaise,
        ifAbsent: () => item.transaction.amountPaise,
      );
    }
    final ranked = lifetime.keys.toList()
      ..sort((a, b) {
        final byAmount = lifetime[b]!.compareTo(lifetime[a]!);
        return byAmount != 0 ? byAmount : a.compareTo(b);
      });
    final slots = {
      for (final (index, name) in ranked.take(colorSlots).indexed) name: index,
    };

    final amount = <String, int>{};
    final count = <String, int>{};
    final icon = <String, String?>{};
    for (final item in current.where((i) => i.transaction.type == type)) {
      amount.update(
        item.categoryName,
        (value) => value + item.transaction.amountPaise,
        ifAbsent: () => item.transaction.amountPaise,
      );
      count.update(item.categoryName, (value) => value + 1, ifAbsent: () => 1);
      icon[item.categoryName] ??= item.categoryIconKey;
    }
    final before = <String, int>{};
    for (final item in previous.where((i) => i.transaction.type == type)) {
      before.update(
        item.categoryName,
        (value) => value + item.transaction.amountPaise,
        ifAbsent: () => item.transaction.amountPaise,
      );
    }

    final slices = <CategorySlice>[];
    var otherAmount = 0;
    var otherPrevious = 0;
    var otherCount = 0;
    for (final name in amount.keys) {
      final slot = slots[name];
      if (slot == null) {
        otherAmount += amount[name]!;
        otherPrevious += before[name] ?? 0;
        otherCount += count[name]!;
        continue;
      }
      slices.add(
        CategorySlice(
          name: name,
          amount: amount[name]!,
          previousAmount: before[name] ?? 0,
          count: count[name]!,
          colorSlot: slot,
          iconKey: icon[name],
        ),
      );
    }
    slices.sort((a, b) => b.amount.compareTo(a.amount));
    if (otherCount > 0) {
      slices.add(
        CategorySlice(
          name: 'Other categories',
          amount: otherAmount,
          previousAmount: otherPrevious,
          count: otherCount,
        ),
      );
    }
    return slices;
  }

  static List<AccountSlice> _accounts(List<TransactionHistoryItem> items) {
    final byId = <String, AccountSlice>{};
    for (final item in items) {
      final t = item.transaction;
      final old = byId[t.accountId];
      byId[t.accountId] = AccountSlice(
        accountId: t.accountId,
        name: item.accountName,
        income: (old?.income ?? 0) + (t.type == 'income' ? t.amountPaise : 0),
        expense: (old?.expense ?? 0) + (t.type == 'income' ? 0 : t.amountPaise),
      );
    }
    return byId.values.toList()
      ..sort((a, b) => (b.income + b.expense).compareTo(a.income + a.expense));
  }
}
