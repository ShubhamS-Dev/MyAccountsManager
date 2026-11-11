import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/time/day_range.dart';
import 'package:my_accounts_manager/features/reports/domain/report.dart';
import 'package:my_accounts_manager/features/reports/presentation/reports_page.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';

int _d(int year, int month, int day) =>
    DateTime.utc(year, month, day).millisecondsSinceEpoch;

var _seq = 0;

TransactionHistoryItem _item(
  int date,
  int paise, {
  String type = 'expense',
  String category = 'Food',
  String account = 'a1',
}) {
  _seq++;
  return TransactionHistoryItem(
    transaction: TransactionRow(
      id: 't$_seq',
      accountId: account,
      categoryId: 'c-$category',
      type: type,
      amountPaise: paise,
      transactionDate: date,
      createdAt: 0,
      updatedAt: 0,
    ),
    accountName: account == 'a1' ? 'Wallet' : 'Bank',
    categoryName: category,
  );
}

void main() {
  final today = _d(2026, 11, 11);

  group('DayRange', () {
    test('presets cover whole calendar periods', () {
      expect(
        DayRange.preset(RangePreset.thisMonth, today),
        DayRange(_d(2026, 11, 1), _d(2026, 11, 30)),
      );
      expect(
        DayRange.preset(RangePreset.lastMonth, today),
        DayRange(_d(2026, 10, 1), _d(2026, 10, 31)),
      );
      expect(
        DayRange.preset(RangePreset.last7Days, today),
        DayRange(_d(2026, 11, 5), today),
      );
      expect(
        DayRange.preset(RangePreset.last3Months, today),
        DayRange(_d(2026, 9, 1), _d(2026, 11, 30)),
      );
      expect(
        DayRange.preset(RangePreset.lastYear, today),
        DayRange(_d(2025, 1, 1), _d(2025, 12, 31)),
      );
      // January rolls back into the previous year.
      expect(
        DayRange.preset(RangePreset.lastMonth, _d(2027, 1, 15)),
        DayRange(_d(2026, 12, 1), _d(2026, 12, 31)),
      );
    });

    test('labels, length, previous period and preset matching', () {
      final range = DayRange(_d(2026, 11, 1), _d(2026, 11, 11));
      expect(range.days, 11);
      expect(range.label, '01 Nov – 11 Nov 2026');
      expect(range.previous, DayRange(_d(2026, 10, 21), _d(2026, 10, 31)));
      expect(
        DayRange(_d(2025, 12, 20), _d(2026, 1, 5)).label,
        '20 Dec 2025 – 05 Jan 2026',
      );
      expect(
        RangePreset.matching(
          DayRange.preset(RangePreset.thisYear, today),
          today,
        ),
        RangePreset.thisYear,
      );
      expect(RangePreset.matching(range, today), isNull);
    });
  });

  group('ReportData', () {
    final thisMonth = DayRange.preset(RangePreset.thisMonth, today);

    test('totals, previous period and scheduled exclusion', () {
      final items = [
        _item(_d(2026, 11, 2), 10000),
        _item(_d(2026, 11, 3), 50000, type: 'income', category: 'Salary'),
        // Scheduled: after today.
        _item(_d(2026, 11, 20), 7000),
        // Previous period (21-31 Oct for an 11-day counted range).
        _item(_d(2026, 10, 25), 4000),
        // Outside both.
        _item(_d(2026, 9, 1), 99900),
      ];
      final data = ReportData.build(
        items,
        ReportFilter(range: thisMonth),
        today,
      );
      expect(data.income, 50000);
      expect(data.expense, 10000);
      expect(data.net, 40000);
      expect(data.count, 2);
      expect(data.through, today);
      expect(data.days, 11);
      expect(data.previousExpense, 4000);
      expect(data.bucket, TrendBucket.day);
      expect(data.trend, hasLength(11));
      expect(data.trend[1].expense, 10000);
      expect(data.trend[2].income, 50000);

      final withScheduled = ReportData.build(
        items,
        ReportFilter(range: thisMonth, includeScheduled: true),
        today,
      );
      expect(withScheduled.expense, 17000);
      expect(withScheduled.trend, hasLength(30));
    });

    test('filters by account and category', () {
      final items = [
        _item(_d(2026, 11, 2), 100, account: 'a1'),
        _item(_d(2026, 11, 2), 200, account: 'a2', category: 'Travel'),
      ];
      final byAccount = ReportData.build(
        items,
        ReportFilter(range: thisMonth, accountId: 'a2'),
        today,
      );
      expect(byAccount.expense, 200);
      final byCategory = ReportData.build(
        items,
        ReportFilter(range: thisMonth, category: 'Food'),
        today,
      );
      expect(byCategory.expense, 100);
      final all = ReportData.build(
        items,
        ReportFilter(range: thisMonth),
        today,
      );
      expect(all.accounts.map((a) => a.name), ['Bank', 'Wallet']);
    });

    test('buckets by week and month for longer ranges', () {
      final quarter = DayRange.preset(RangePreset.last3Months, today);
      final weekly = ReportData.build(
        [_item(_d(2026, 11, 11), 100)],
        ReportFilter(range: quarter),
        today,
      );
      expect(weekly.bucket, TrendBucket.week);
      // 11 Nov 2026 is a Wednesday; its week starts Monday 9 Nov.
      expect(weekly.trend.last.start, _d(2026, 11, 9));
      expect(weekly.trend.last.expense, 100);

      final yearly = ReportData.build(
        [_item(_d(2026, 3, 15), 100)],
        ReportFilter(range: DayRange.preset(RangePreset.thisYear, today)),
        today,
      );
      expect(yearly.bucket, TrendBucket.month);
      expect(yearly.trend, hasLength(11));
      expect(yearly.trend[2].expense, 100);
    });

    test('category colours follow the category and small ones fold', () {
      final names = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
      // Lifetime spend ranks A highest, I lowest.
      final items = [
        for (final (index, name) in names.indexed)
          _item(_d(2026, 1, 1), (names.length - index) * 1000, category: name),
        _item(_d(2026, 11, 2), 500, category: 'G'),
        _item(_d(2026, 11, 2), 300, category: 'H'),
        _item(_d(2026, 11, 2), 200, category: 'I'),
        _item(_d(2026, 11, 3), 100, category: 'A'),
      ];
      final data = ReportData.build(
        items,
        ReportFilter(range: thisMonth),
        today,
      );
      expect(data.categoryCount, 4);
      // Other always comes last, whatever its size.
      expect(data.categories.map((c) => c.name), [
        'G',
        'A',
        'Other categories',
      ]);
      // G keeps slot 6 even though it leads this month.
      expect(data.categories.first.colorSlot, 6);
      expect(data.categories[1].colorSlot, 0);
      expect(data.categories.last.isOther, isTrue);
      expect(data.categories.last.amount, 500);
    });

    test('a range entirely in the future is empty', () {
      final data = ReportData.build(
        [_item(_d(2026, 12, 5), 100)],
        ReportFilter(range: DayRange(_d(2026, 12, 1), _d(2026, 12, 31))),
        today,
      );
      expect(data.isEmpty, isTrue);
      expect(data.trend, isEmpty);
    });
  });

  test('compact axis amounts use Indian units', () {
    expect(compactRupees(95000), '₹950');
    expect(compactRupees(120000), '₹1.2K');
    expect(compactRupees(34000000), '₹3.4L');
    expect(compactRupees(1100000000), '₹1.1Cr');
    expect(compactRupees(-250000), '-₹2.5K');
  });
}
