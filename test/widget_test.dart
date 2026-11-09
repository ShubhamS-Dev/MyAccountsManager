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
import 'package:my_accounts_manager/features/accounts/presentation/archived_accounts_page.dart';
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

  testWidgets('shows the empty Archived Accounts state', (tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await testDatabase.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          archivedAccountsProvider.overrideWith(
            (ref) => Stream.value(<AccountRow>[]),
          ),
        ],
        child: const MaterialApp(home: ArchivedAccountsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Archived Accounts'), findsOneWidget);
    expect(find.text('No archived Accounts'), findsOneWidget);
    expect(
      find.textContaining('Accounts you archive will appear here'),
      findsOneWidget,
    );
  });

  testWidgets(
    'restores an archived Account from the Archived Accounts screen',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await testDatabase.close();
      });

      final repository = AccountsRepository(testDatabase);
      final archivedId = await repository.createAccount(
        name: 'Archived test Account',
        description: 'Savings account',
      );
      await repository.archiveAccount(archivedId);
      final archivedAccount = (await repository.getAccount(archivedId))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDatabase),
            archivedAccountsProvider.overrideWith(
              (ref) => Stream.value([archivedAccount]),
            ),
          ],
          child: const MaterialApp(home: ArchivedAccountsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Archived test Account'), findsOneWidget);
      expect(find.text('Savings account'), findsOneWidget);
      expect(find.text('1 Account'), findsOneWidget);

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      final restored = await repository.getAccount(archivedId);
      expect(restored, isNotNull);
      expect(restored!.archivedAt, isNull);
    },
  );

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
    expect(find.text('A clear view of your money this month.'), findsOneWidget);
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

    // Verify navigation through user-visible taps instead of inspecting
    // NavigationBar internals. This covers the actual destination behavior.
    for (final destination in [
      'Accounts',
      'History',
      'MyKhata',
      'More',
      'Home',
    ]) {
      await tester.tap(find.text(destination).last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(destination),
        ),
        findsOneWidget,
        reason: 'Selecting $destination should update the app bar title.',
      );
    }

    // Home retains its scroll position when switching destinations. Return
    // to the top before interacting with the header privacy control.
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();

    // The balance privacy control must remain interactive.
    expect(find.byTooltip('Hide amounts'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide amounts'));
    await tester.pump();
    expect(find.byTooltip('Show amounts'), findsOneWidget);
    await tester.tap(find.byTooltip('Show amounts'));
    await tester.pump();
    expect(find.byTooltip('Hide amounts'), findsOneWidget);
  });

  testWidgets('shows and filters the refreshed Accounts overview', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL ACCOUNT BALANCE'), findsOneWidget);
    expect(find.text('Your accounts'), findsOneWidget);
    expect(find.text('1 active'), findsOneWidget);
    expect(find.text('Widget test Account'), findsOneWidget);
    expect(find.byTooltip('Archived accounts'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide balance'));
    await tester.pump();
    expect(find.byTooltip('Show balance'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no matching account');
    await tester.pumpAndSettle();
    expect(find.text('No matching accounts'), findsOneWidget);
    expect(find.text('Try another name or clear your search.'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Widget test Account'), findsOneWidget);
  });

  testWidgets('opens Account Details from the Accounts grid', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Widget test Account'));

    await tester.tap(find.text('Widget test Account'));
    await pumpUntilFound(tester, find.text('Balance breakdown'));

    expect(find.text('CURRENT BALANCE'), findsOneWidget);
    expect(find.text('Balance breakdown'), findsOneWidget);
    expect(find.text('Opening balance'), findsOneWidget);
    expect(find.text('Total income'), findsOneWidget);
    expect(find.text('Total expenses'), findsOneWidget);
    expect(find.text('Transaction history'), findsOneWidget);
    expect(
      find.text('No transactions recorded for this account yet.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit account'), findsOneWidget);
    expect(find.byTooltip('Balance adjustments'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Manage balance adjustments'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final adjustmentsAction = find.widgetWithText(
      OutlinedButton,
      'Manage balance adjustments',
    );
    expect(adjustmentsAction, findsOneWidget);
    expect(tester.getSize(adjustmentsAction).height, 40);
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

  testWidgets('shows the approved History filters and monthly summary', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();

    expect(find.text('Monthly overview'), findsOneWidget);
    expect(find.text('Income'), findsWidgets);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Search note, Account or amount'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.byTooltip('Open Trash'), findsOneWidget);
    expect(find.text('No transactions yet'), findsOneWidget);
  });

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
  testWidgets('transaction form follows approved field order and date label', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntilFound(tester, find.text('How much did you spend?'));
    await pumpUntilFound(tester, find.text('Category'));

    final accountY = tester.getTopLeft(find.text('Account').first).dy;
    final dateY = tester.getTopLeft(find.text('Transaction date').first).dy;
    final noteY = tester.getTopLeft(find.text('Note').first).dy;
    final amountY = tester.getTopLeft(find.text('Amount').first).dy;
    final categoryY = tester.getTopLeft(find.text('Category').first).dy;

    expect(accountY, lessThan(dateY));
    expect(dateY, lessThan(noteY));
    expect(noteY, lessThan(amountY));
    expect(amountY, lessThan(categoryY));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('What was this transaction for?'), findsOneWidget);
    // Find the Scrollable owned by this Form's ListView. Other
    // Scrollables under Form can belong to dropdown controls.
    final formListView = find.descendant(
      of: find.byType(Form),
      matching: find.byType(ListView),
    );
    expect(formListView, findsOneWidget);
    // The form contains nested TextFormFields. Flutter gives each editable
    // field its own Scrollable (for caret/selection handling), so matching
    // every Scrollable below the Form is ambiguous. The outer ListView's
    // Scrollable has no restorationId; editable field scrollables use
    // restorationId "editable". Match the actual form viewport explicitly.
    final formScrollable = find.descendant(
      of: formListView,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            widget.restorationId == null &&
            widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(formScrollable, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save transaction'),
      250,
      scrollable: formScrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('Save transaction'), findsOneWidget);
  });
}
