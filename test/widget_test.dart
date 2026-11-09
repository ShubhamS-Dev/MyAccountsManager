import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_router.dart';
import 'package:my_accounts_manager/app/my_accounts_manager_app.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/database/database_provider.dart';
import 'package:my_accounts_manager/features/accounts/accounts_providers.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';
import 'package:my_accounts_manager/features/categories/categories_providers.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';
import 'package:my_accounts_manager/features/transactions/transactions_providers.dart';

late AppDatabase testDatabase;
late AccountRow testAccount;

void main() {
  setUp(() async {
    testDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    final accountId = await AccountsRepository(
      testDatabase,
    ).createAccount(name: 'Widget test Account');
    testAccount = (await AccountsRepository(
      testDatabase,
    ).getAccount(accountId))!;
    appRouter.go('/');
  });

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration interval = const Duration(milliseconds: 50),
    int maxPumps = 40,
  }) async {
    for (var attempt = 0; attempt < maxPumps; attempt++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(interval);
    }

    expect(
      finder,
      findsOneWidget,
      reason:
          'The expected widget did not appear within '
          '${interval * maxPumps}.',
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    addTearDown(() async {
      // Unmount consumers before closing the in-memory database.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await testDatabase.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),

          // These are navigation/form tests. Repository stream behavior is
          // covered separately, so use deterministic streams here and avoid
          // opening Drift query subscriptions from the widget tree.
          activeAccountsProvider.overrideWith(
            (ref) => Stream.value([testAccount]),
          ),
          allAccountsProvider.overrideWith(
            (ref) => Stream.value([testAccount]),
          ),
          totalActiveBalancePaiseProvider.overrideWith(
            (ref) => Stream.value(0),
          ),
          accountBalancePaiseProvider.overrideWith(
            (ref, accountId) => Stream.value(0),
          ),
          balanceAdjustmentsProvider.overrideWith(
            (ref, accountId) => Stream.value(<BalanceAdjustmentRow>[]),
          ),
          activeCategoriesByTypeProvider.overrideWith(
            (ref, type) => Stream.value(<CategoryRow>[]),
          ),
          transactionHistoryProvider.overrideWith(
            (ref, filter) => Stream.value(<TransactionHistoryItem>[]),
          ),
        ],
        child: const MyAccountsManagerApp(),
      ),
    );
    await pumpUntilFound(tester, find.text('Home'));
  }

  testWidgets('launches the home dashboard with primary navigation', (
    tester,
  ) async {
    await pumpApp(tester);
    // Dashboard summaries are stream-backed; wait for the monthly metrics
    // instead of asserting before their first values have rendered.
    await pumpUntilFound(tester, find.text('Income'));

    // Verify the refreshed dashboard hierarchy and approved content.
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('Your finances'), findsOneWidget);
    expect(
      find.text('A clear view of your money this month.'),
      findsOneWidget,
    );
    expect(find.text('TOTAL ACCOUNT BALANCE'), findsOneWidget);
    expect(
      find.text('Across active Accounts  ·  MyKhata excluded'),
      findsOneWidget,
    );
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Net cash flow'), findsOneWidget);
    expect(find.text('Your Accounts'), findsOneWidget);

    // Recent transactions is below the account grid in the ListView, so
    // scroll it into the viewport before asserting its lazily built header.
    await tester.scrollUntilVisible(
      find.text('Recent transactions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Recent transactions'), findsOneWidget);

    // NavigationBar only paints labels according to its label behavior;
    // inspect its configured destinations rather than expecting every label
    // to be present in the rendered tree while Home is selected.
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    final destinationLabels = navigationBar.destinations
        .whereType<NavigationDestination>()
        .map((destination) => destination.label);
    expect(
      destinationLabels,
      containsAll(['Home', 'Accounts', 'History', 'MyKhata', 'More']),
    );

    // The balance privacy control must remain interactive.
    expect(find.byTooltip('Hide amounts'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide amounts'));
    await tester.pump();
    expect(find.byTooltip('Show amounts'), findsOneWidget);
    await tester.tap(find.byTooltip('Show amounts'));
    await tester.pump();
    expect(find.byTooltip('Hide amounts'), findsOneWidget);
  });

  testWidgets('opens Account Details from the Accounts grid', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Widget test Account'));

    await tester.tap(find.text('Widget test Account'));
    await pumpUntilFound(tester, find.text('Balance breakdown'));

    expect(find.text('CURRENT BALANCE'), findsOneWidget);
    expect(find.text('Transaction history'), findsOneWidget);
  });

  testWidgets(
    'opens the add transaction form from the floating action button',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Add transaction'));
      await pumpUntilFound(tester, find.text('How much did you spend?'));

      expect(find.text('Add transaction'), findsOneWidget);
      expect(find.text('How much did you spend?'), findsOneWidget);
    },
  );

  testWidgets('switches the transaction form from expense to income', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntilFound(tester, find.text('How much did you spend?'));

    final incomeSegment = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is SegmentedButton),
      matching: find.text('Income'),
    );
    expect(incomeSegment, findsOneWidget);
    await tester.tap(incomeSegment);
    await pumpUntilFound(tester, find.text('How much did you receive?'));

    expect(find.text('How much did you receive?'), findsOneWidget);
  });
}
