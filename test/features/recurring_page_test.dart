import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/privacy_state.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/time/today_provider.dart';
import 'package:my_accounts_manager/features/recurring/data/recurring_repository.dart';
import 'package:my_accounts_manager/features/recurring/presentation/recurring_page.dart';
import 'package:my_accounts_manager/features/recurring/recurring_providers.dart';

int day(int year, int month, int date) =>
    DateTime.utc(year, month, date).millisecondsSinceEpoch;

RecurringRuleItem item({
  required String id,
  required String type,
  required int amountPaise,
  String? note,
  int nextIndex = 2,
  int? pausedAt,
  bool archived = false,
}) => RecurringRuleItem(
  rule: RecurringRuleRow(
    id: id,
    accountId: 'bank',
    categoryId: 'cat',
    type: type,
    amountPaise: amountPaise,
    note: note,
    frequency: 'monthly',
    startDate: day(2026, 11, 1),
    nextIndex: nextIndex,
    pausedAt: pausedAt,
    createdAt: 0,
    updatedAt: 0,
  ),
  accountName: 'HDFC',
  accountArchived: archived,
  categoryName: type == 'income' ? 'Salary' : 'Rent',
  categoryActive: true,
);

void main() {
  Future<void> pump(WidgetTester tester, List<RecurringRuleItem> rules) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringRulesProvider.overrideWith((ref) => Stream.value(rules)),
          todayProvider.overrideWithValue(day(2026, 11, 11)),
          storedAmountsHiddenProvider.overrideWith(
            (ref) => Stream.value(false),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          home: const RecurringPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows an empty state that explains Repeat', (tester) async {
    await pump(tester, const []);
    expect(find.text('Nothing on repeat yet'), findsOneWidget);
    expect(find.text('Add transaction'), findsOneWidget);
  });

  testWidgets('lists series with next date, status and monthly totals', (
    tester,
  ) async {
    await pump(tester, [
      item(id: 'r1', type: 'expense', amountPaise: 2500000, note: 'Flat rent'),
      item(id: 'r2', type: 'income', amountPaise: 9000000),
      item(id: 'r3', type: 'expense', amountPaise: 50000, pausedAt: 1),
      item(id: 'r4', type: 'expense', amountPaise: 10000, archived: true),
    ]);

    expect(find.text('Flat rent'), findsOneWidget);
    expect(find.text('Every month on day 1 · HDFC'), findsNWidgets(4));
    expect(find.text('Next on 01 Dec 2026'), findsNWidgets(2));
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('On hold: Account is archived'), findsOneWidget);
    // Paused and blocked series are left out of the monthly totals.
    expect(find.text('₹25,000'), findsOneWidget);
    expect(find.text('₹90,000'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Flat rent'));
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Delete series'), findsOneWidget);
  });

  testWidgets('the ? button explains the rules in short bullets', (
    tester,
  ) async {
    await pump(tester, const []);
    await tester.tap(find.byKey(const ValueKey('recurring-help')));
    await tester.pumpAndSettle();
    expect(find.text('How recurring works'), findsOneWidget);
    expect(find.text('Paused dates are skipped, not filled'), findsOneWidget);
    expect(find.text('Deleting a series keeps past entries'), findsOneWidget);
  });
}
