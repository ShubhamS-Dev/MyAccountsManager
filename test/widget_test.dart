import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_router.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/app_widgets.dart';
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

    throw TestFailure(
      'The expected widget did not appear within '
      '${interval * maxPumps}.',
    );
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    bool liveHistory = false,
    bool includeCategories = false,
    List<AccountRow>? accountRows,
    TransactionsRepository? repository,
  }) async {
    final categoryRows = includeCategories
        ? await tester.runAsync(
                () => testDatabase.select(testDatabase.categories).get(),
              ) ??
              <CategoryRow>[]
        : <CategoryRow>[];
    addTearDown(() async {
      // Unmount consumers before closing the in-memory database.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await testDatabase.close();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('app-screenshot-boundary'),
        child: ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDatabase),

            // These are navigation/form tests. Repository stream behavior is
            // covered separately, so use deterministic streams here and avoid
            // opening Drift query subscriptions from the widget tree.
            activeAccountsProvider.overrideWith(
              (ref) => Stream.value(accountRows ?? [testAccount]),
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
              (ref, type) => Stream.value(
                categoryRows
                    .where(
                      (category) => category.type == type && category.isActive,
                    )
                    .toList(),
              ),
            ),
            if (repository != null)
              transactionsRepositoryProvider.overrideWithValue(repository),
            transactionHistoryProvider.overrideWith((ref, filter) {
              if (liveHistory) {
                return TransactionsRepository(testDatabase).watchHistory(
                  accountId: filter.accountId,
                  fromDate: filter.fromDate,
                  throughDate: filter.throughDate,
                  type: filter.type,
                );
              }
              return Stream.value(<TransactionHistoryItem>[]);
            }),
          ],
          child: const MyAccountsManagerApp(),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Home'));
  }

  testWidgets('shared action buttons render at exactly 40px high', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Filled')),
              ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              TextButton(onPressed: () {}, child: const Text('Text')),
            ],
          ),
        ),
      ),
    );

    for (final buttonType in [
      FilledButton,
      ElevatedButton,
      OutlinedButton,
      TextButton,
    ]) {
      expect(
        tester.getSize(find.byType(buttonType)).height,
        40,
        reason: '${buttonType.toString()} should render at exactly 40px high.',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

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
  }, timeout: const Timeout(Duration(seconds: 30)));

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
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets('launches the home dashboard with primary navigation', (
    tester,
  ) async {
    await pumpApp(tester);
    // Dashboard summaries are stream-backed; wait for the monthly metrics
    // instead of asserting before their first values have rendered.
    // Wait for a metric unique to the async monthly summary. 'Income' also
    // appears in the immediately rendered Quick actions row.
    await pumpUntilFound(tester, find.text('Net cash flow'));

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

    // Verify the dashboard privacy control while the page is still at the top.
    // Later account and transaction assertions scroll the dashboard downward.
    final privacyToggle = find.byTooltip('Hide amounts');
    await tester.pumpAndSettle();
    await tester.ensureVisible(privacyToggle);
    expect(privacyToggle, findsOneWidget);
    await tester.tap(privacyToggle);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show amounts'), findsOneWidget);

    final showAmountsToggle = find.byTooltip('Show amounts');
    await tester.ensureVisible(showAmountsToggle);
    await tester.tap(showAmountsToggle);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide amounts'), findsOneWidget);

    // The account section is below the monthly summary and quick actions.
    // Scroll the dashboard's vertical ListView before asserting its heading.
    await tester.scrollUntilVisible(
      find.text('Your Accounts'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('shows and filters the refreshed Accounts overview', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL ACCOUNT BALANCE'), findsOneWidget);
    expect(find.text('Your accounts'), findsOneWidget);
    expect(find.byTooltip('Archived accounts'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide amounts'));
    await tester.pump();
    expect(find.byTooltip('Show amounts'), findsOneWidget);

    final accountsList = find.ancestor(
      of: find.text('Your accounts'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.vertical,
      ),
    );
    await tester.drag(accountsList, const Offset(0, -300));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('1 active account'));
    expect(find.text('1 active account'), findsOneWidget);
    expect(find.text('Widget test Account'), findsOneWidget);

    final accountSearchField = find.byType(TextField);
    await tester.ensureVisible(accountSearchField);
    await tester.enterText(accountSearchField, 'no matching account');
    await tester.pumpAndSettle();
    expect(find.text('No matching accounts'), findsOneWidget);
    expect(find.text('Try another name or clear your search.'), findsOneWidget);

    final clearSearchAction = find.text('Clear search');
    await tester.ensureVisible(clearSearchAction);
    await tester.pumpAndSettle();
    await tester.tap(clearSearchAction);
    await tester.pumpAndSettle();
    expect(find.text('Widget test Account'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('shares the dashboard privacy toggle with Account Details', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.pumpAndSettle();
    final dashboardHideToggle = find.byTooltip('Hide amounts');
    expect(dashboardHideToggle, findsOneWidget);
    await tester.tap(dashboardHideToggle);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show amounts'), findsOneWidget);

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Widget test Account'));

    await tester.tap(find.text('Widget test Account'));
    await pumpUntilFound(tester, find.text('Balance breakdown'));
    await tester.pumpAndSettle();

    final detailsShowToggle = find.byTooltip('Show amounts');
    expect(detailsShowToggle, findsOneWidget);
    expect(find.text('₹ ••••••'), findsOneWidget);
    expect(find.text('₹ •••'), findsNWidgets(4));

    await tester.tap(detailsShowToggle);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Hide amounts'), findsOneWidget);
    expect(find.text('₹0'), findsNWidgets(5));
    expect(find.text('₹ ••••••'), findsNothing);
    expect(find.text('₹ •••'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

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
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(
    'opens the add transaction form from the floating action button',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Add transaction'));
      await pumpUntilFound(tester, find.text('How much did you spend?'));

      expect(find.text('Add transaction'), findsOneWidget);
      expect(find.text('How much did you spend?'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets('shows and interacts with the approved History controls', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();

    expect(find.text('Monthly overview'), findsOneWidget);
    expect(find.text('INCOME'), findsOneWidget);
    expect(find.text('EXPENSES'), findsOneWidget);
    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);

    final monthLabel = find.textContaining(RegExp(r'202[0-9]'));
    expect(monthLabel, findsOneWidget);
    final initialMonth = tester.widget<Text>(monthLabel).data;
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(monthLabel, findsOneWidget);
    expect(tester.widget<Text>(monthLabel).data, isNot(initialMonth));
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(monthLabel).data, initialMonth);

    expect(find.text('Search note, Account or amount'), findsOneWidget);
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'no matching search');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear search'), findsOneWidget);
    expect(find.text('No matching transactions'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsWidgets);
    await tester.tap(find.text('Expense'));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(find.text('Income').last);
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(find.text('All'));
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Account & Category filters'), findsOneWidget);
    expect(find.byTooltip('Open Trash'), findsOneWidget);
    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.text('Add transaction'), findsOneWidget);

    await tester.tap(find.text('Account & Category filters'));
    await tester.pumpAndSettle();
    expect(find.text('Filter transactions'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('All Accounts'), findsOneWidget);
    expect(find.text('All Categories'), findsOneWidget);
    expect(
      find.widgetWithText(ChoiceChip, 'Widget test Account'),
      findsOneWidget,
    );
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Widget test Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    final accountChip = find.widgetWithText(InputChip, 'Widget test Account');
    expect(accountChip, findsOneWidget);
    expect(find.text('No matching transactions'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: accountChip,
        matching: find.byIcon(Icons.close_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(accountChip, findsNothing);

    await tester.tap(find.text('Account & Category filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('No transactions yet'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('swiping a History row moves it to Trash and Undo restores it', (
    tester,
  ) async {
    final category =
        await (testDatabase.select(testDatabase.categories)
              ..where((row) => row.type.equals('expense'))
              ..where((row) => row.name.equals('Food & Dining')))
            .getSingle();
    final transactionId = await TransactionsRepository(testDatabase)
        .createTransaction(
          accountId: testAccount.id,
          categoryId: category.id,
          type: 'expense',
          amountPaise: 12500,
          transactionDate: DateTime.now().millisecondsSinceEpoch,
          note: 'Swipe test transaction',
        );

    await pumpApp(tester, liveHistory: true);
    printOnFailure('step 1: pumpApp completed and app is mounted');
    await tester.tap(find.text('History').last);
    await pumpUntilFound(tester, find.text('Swipe test transaction'));
    printOnFailure('step 2: History opened and transaction row appeared');

    final row = find.byKey(ValueKey('dismiss-$transactionId'));
    expect(row, findsOneWidget);
    // Use a high-velocity left fling, matching endToStart and exceeding the
    // Dismissible threshold without depending on a long pointer drag.
    await tester.fling(row, const Offset(-1000, 0), 2000);
    printOnFailure('step 3: left swipe fling completed');

    // confirmDismiss awaits the real Drift soft-delete future before allowing
    // the row to leave. Pump the dismissal and snackbar animations explicitly;
    // avoid pumpAndSettle because History's shimmer repeats while loading.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    await pumpUntilFound(tester, find.text('Transaction moved to Trash'));
    printOnFailure('step 4: Trash snackbar appeared');
    expect(find.text('Swipe test transaction'), findsNothing);
    expect(
      row,
      findsNothing,
      reason: 'Dismissible must leave the widget tree.',
    );

    // Native Drift work must run outside the widget test's FakeAsync zone.
    await tester.runAsync(() async {
      final trashItems = await TransactionsRepository(
        testDatabase,
      ).watchTrash().first;
      expect(trashItems, hasLength(1));
      expect(trashItems.single.transaction.id, transactionId);
      expect(trashItems.single.transaction.deletedAt, isNotNull);
    });
    printOnFailure('step 5: runAsync Trash persistence check completed');

    // Exercise Undo through the rendered action, not its void callback.
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    printOnFailure('step 6: rendered Undo action tap completed');
    await pumpUntilFound(tester, find.text('Swipe test transaction'));
    expect(find.text('Swipe test transaction'), findsOneWidget);
    printOnFailure('step 7: History row returned after Undo');

    // The live History stream proves the row returned; also verify the
    // persisted soft-delete flag was cleared using real async Drift work.
    await tester.runAsync(() async {
      final restored = await (testDatabase.select(
        testDatabase.transactions,
      )..where((row) => row.id.equals(transactionId))).getSingle();
      expect(restored.deletedAt, isNull);
    });
    printOnFailure('step 8: persisted restore check completed');

    // Dispose the live Drift-backed History subscription before the test
    // binding performs its pending-timer invariant check.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    printOnFailure('step 9: widget tree unmounted inside the test body');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('switches the transaction form from expense to income', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntilFound(tester, find.text('How much did you spend?'));

    final incomeSegment = find.byKey(
      const ValueKey('transaction-kind-income-unselected'),
    );
    expect(incomeSegment, findsOneWidget);
    await tester.tap(incomeSegment);
    await pumpUntilFound(tester, find.text('How much did you receive?'));

    expect(find.text('How much did you receive?'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
  testWidgets('transaction form follows approved field order and date label', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntilFound(tester, find.text('How much did you spend?'));
    final formListViewFinder = find.descendant(
      of: find.byType(Form),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.vertical,
      ),
    );
    expect(formListViewFinder, findsOneWidget);
    final formListView = tester.widget<ListView>(formListViewFinder);
    final children =
        (formListView.childrenDelegate as SliverChildListDelegate).children;
    final fieldOrder = <String>[
      'add-transaction-account',
      'add-transaction-date',
      'add-transaction-note',
      'add-transaction-amount',
      'add-transaction-category',
    ];
    final fieldIndexes = fieldOrder.map((key) {
      return children.indexWhere((child) => child.key == ValueKey(key));
    }).toList();
    expect(fieldIndexes.every((index) => index >= 0), isTrue);
    for (var index = 0; index < fieldIndexes.length - 1; index++) {
      expect(fieldIndexes[index], lessThan(fieldIndexes[index + 1]));
    }

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('What was this transaction for?'), findsOneWidget);
    expect(find.text('Save transaction'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
  testWidgets('Home income shortcut opens a preselected income form', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Income').last);
    await pumpUntilFound(tester, find.text('How much did you receive?'));

    expect(
      find.byKey(const ValueKey('transaction-kind-income-selected')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('transaction-kind-expense-unselected')),
      findsOneWidget,
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Add Transaction quick-add preserves paise and Indian grouping', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntilFound(tester, find.text('How much did you spend?'));

    final quickAddTops = [
      tester.getTopLeft(find.text('+100')).dy,
      tester.getTopLeft(find.text('+500')).dy,
      tester.getTopLeft(find.text('+1,000')).dy,
    ];
    expect(quickAddTops[0], quickAddTops[1]);
    expect(quickAddTops[1], quickAddTops[2]);

    final amountField = find.byKey(
      const ValueKey('add-transaction-amount-input'),
    );
    await tester.enterText(amountField, '10.50');
    await tester.pump();
    await tester.tap(find.text('+100'));
    await tester.pump();

    expect(
      tester.widget<TextFormField>(amountField).controller!.text,
      '110.50',
    );

    await tester.enterText(amountField, '100000');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(amountField).controller!.text,
      '1,00,000',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Add Transaction amount input enforces the 12-digit limit', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntilFound(tester, find.text('How much did you spend?'));

    final amountField = find.byKey(
      const ValueKey('add-transaction-amount-input'),
    );
    await tester.enterText(amountField, '999999999999');
    await tester.pump();
    final before = tester.widget<TextFormField>(amountField).controller!.text;

    await tester.tap(find.text('+100'));
    await tester.pump();

    expect(tester.widget<TextFormField>(amountField).controller!.text, before);
    expect(find.textContaining('Maximum amount is'), findsOneWidget);

    await tester.enterText(amountField, '1000000000000');
    await tester.pump();
    expect(tester.widget<TextFormField>(amountField).controller!.text, before);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(
    'Add Transaction amount typing keeps 28px prominence and captures screenshot',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Add transaction'));
      await pumpUntilFound(tester, find.text('How much did you spend?'));

      final amountField = find.byKey(
        const ValueKey('add-transaction-amount-input'),
      );
      await tester.ensureVisible(amountField);
      await tester.enterText(amountField, '12,500.75');
      await tester.pump(const Duration(milliseconds: 200));

      // TextFormField is a FormField wrapper; its visual text style and
      // decoration belong to the rendered EditableText and InputDecorator.
      // Inspect those concrete widgets instead of reading nonexistent
      // TextFormField.style/decoration properties.
      final amountEditableText = tester.widget<EditableText>(
        find.descendant(
          of: amountField,
          matching: find.byType(EditableText),
        ),
      );
      expect(
        amountEditableText.style.fontSize,
        AppTypography.amountInput.fontSize,
      );
      final amountDecoration = tester
          .widget<InputDecorator>(
            find.descendant(
              of: amountField,
              matching: find.byType(InputDecorator),
            ),
          )
          .decoration;
      expect(
        amountDecoration.hintStyle?.fontSize,
        AppTypography.amountInput.fontSize,
      );
      expect(
        tester.widget<TextFormField>(amountField).controller!.text,
        '12,500.75',
      );

      final noteFieldFinder = find.byKey(
        const ValueKey('add-transaction-note-input'),
      );
      final noteDecoration = tester
          .widget<InputDecorator>(
            find.descendant(
              of: noteFieldFinder,
              matching: find.byType(InputDecorator),
            ),
          )
          .decoration;
      expect(noteDecoration.filled, isFalse);
      expect(noteDecoration.fillColor, Colors.transparent);
      expect(noteDecoration.border, InputBorder.none);

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('app-screenshot-boundary')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final screenshot = File(
        'build/screenshots/add_transaction_amount_typing.png',
      );
      await screenshot.parent.create(recursive: true);
      await screenshot.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Add Transaction has no-active-Account empty state and Add account CTA',
    (tester) async {
      await pumpApp(tester, accountRows: <AccountRow>[]);

      await tester.tap(find.byTooltip('Add transaction'));
      await pumpUntilFound(tester, find.text('No active accounts'));

      expect(find.text('Add account'), findsOneWidget);
      expect(find.text('Save transaction'), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Add Transaction Account chips scroll and keep the selected chip visible',
    (tester) async {
      final rows = <AccountRow>[testAccount];
      await tester.runAsync(() async {
        for (var index = 2; index <= 7; index++) {
          final id = await AccountsRepository(
            testDatabase,
          ).createAccount(name: 'Account $index');
          rows.add((await AccountsRepository(testDatabase).getAccount(id))!);
        }
      });

      await pumpApp(tester, accountRows: rows);
      await tester.tap(find.byTooltip('Add transaction'));
      await pumpUntilFound(tester, find.text('Account'));
      final accountList = find.byType(ListView).last;
      await tester.drag(accountList, const Offset(-1200, 0));
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.text('Account 7'));

      await tester.ensureVisible(find.text('Account 7'));
      await tester.pump();
      await tester.tap(find.text('Account 7'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Account 7'), findsOneWidget);
      expect(
        tester
            .getRect(find.text('Account 7'))
            .overlaps(tester.getRect(find.byType(ListView).last)),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Add Transaction saves integer paise with the selected transaction type',
    (tester) async {
      final completion = Completer<String>();
      final repository = _RecordingTransactionsRepository(
        testDatabase,
        completion: completion,
      );
      await pumpApp(tester, includeCategories: true, repository: repository);

      await tester.tap(find.byTooltip('Add transaction'));
      await pumpUntilFound(tester, find.text('How much did you spend?'));
      await tester.tap(
        find.byKey(const ValueKey('transaction-kind-income-unselected')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await scrollFormToBottom(tester);
      await pumpUntilFound(tester, find.text('Salary'));
      await tester.ensureVisible(find.text('Salary'));
      await tester.pump();
      await tester.tap(find.text('Salary'));
      await scrollFormToTop(tester);
      await tester.enterText(find.byType(TextFormField), '1,250.50');
      await tester.pump();
      await tester.tap(find.text('Save transaction'));
      await tester.pump();
      expect(repository.saveCalls, 1);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(repository.saveCalls, 1);
      completion.complete('recorded-transaction');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(repository.savedType, 'income');
      expect(repository.savedAmountPaise, 125050);
      expect(repository.savedAccountId, testAccount.id);
      final storedDate = DateTime.fromMillisecondsSinceEpoch(
        repository.savedTransactionDate!,
        isUtc: true,
      );
      expect(storedDate.hour, 0);
      expect(storedDate.minute, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Add Transaction Yesterday displays DD MMM YYYY rather than Yesterday',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Add transaction'));
      await pumpUntilFound(tester, find.text('Today'));
      await tester.tap(find.text('Yesterday'));
      await tester.pump();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(
                r'^\d{2} [A-Z][a-z]{2} \d{4}$',
              ).hasMatch(widget.data ?? ''),
        ),
        findsOneWidget,
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Add Transaction categories follow the selected Expense or Income type',
    (tester) async {
      await pumpApp(tester, includeCategories: true);

      await tester.tap(find.byTooltip('Add transaction'));
      await pumpUntilFound(tester, find.text('How much did you spend?'));
      await scrollFormToBottom(tester);
      await pumpUntilFound(tester, find.text('Food & Dining'));
      expect(find.text('Salary'), findsNothing);

      await scrollFormToTop(tester);
      await tester.tap(
        find.byKey(const ValueKey('transaction-kind-income-unselected')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await scrollFormToBottom(tester);
      await pumpUntilFound(tester, find.text('Salary'));

      expect(find.text('Food & Dining'), findsNothing);
      expect(find.text('Salary'), findsOneWidget);

      await scrollFormToTop(tester);
      await tester.tap(
        find.byKey(const ValueKey('transaction-kind-expense-unselected')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await scrollFormToBottom(tester);
      await pumpUntilFound(tester, find.text('Food & Dining'));
      expect(find.text('Salary'), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Add Transaction note counter appears only after 400 characters',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Add transaction'));
      await pumpUntilFound(tester, find.text('What was this transaction for?'));

      final noteField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'What was this transaction for?',
      );
      await tester.enterText(noteField, 'a' * 400);
      await tester.pump();
      expect(find.text('400/500'), findsNothing);

      await tester.enterText(noteField, 'a' * 401);
      await tester.pump();
      expect(find.text('401/500'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

Future<void> scrollFormToTop(WidgetTester tester) async {
  final formListView = find.descendant(
    of: find.byType(Form),
    matching: find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
    ),
  );
  final formScrollable = find.descendant(
    of: formListView,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          widget.restorationId == null &&
          widget.axisDirection == AxisDirection.down,
    ),
  );
  await tester.drag(formScrollable, const Offset(0, 700));
  await tester.pumpAndSettle();
}

Future<void> scrollFormToBottom(WidgetTester tester) async {
  final formListView = find.descendant(
    of: find.byType(Form),
    matching: find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
    ),
  );
  final formScrollable = find.descendant(
    of: formListView,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          widget.restorationId == null &&
          widget.axisDirection == AxisDirection.down,
    ),
  );
  await tester.drag(formScrollable, const Offset(0, -700));
  await tester.pumpAndSettle();
}

class _RecordingTransactionsRepository extends TransactionsRepository {
  _RecordingTransactionsRepository(super.database, {this.completion});

  final Completer<String>? completion;
  int saveCalls = 0;

  String? savedType;
  int? savedAmountPaise;
  String? savedAccountId;
  int? savedTransactionDate;

  @override
  Future<String> createTransaction({
    required String accountId,
    required String categoryId,
    required String type,
    required int amountPaise,
    required int transactionDate,
    String? note,
  }) {
    saveCalls++;
    savedAccountId = accountId;
    savedType = type;
    savedAmountPaise = amountPaise;
    savedTransactionDate = transactionDate;
    return completion?.future ?? Future.value('recorded-transaction');
  }
}
