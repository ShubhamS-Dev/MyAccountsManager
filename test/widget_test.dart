import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_router.dart';
import 'package:my_accounts_manager/app/my_accounts_manager_app.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/database/database_provider.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';

late AppDatabase testDatabase;

void main() {
  setUp(() async {
    testDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    await AccountsRepository(testDatabase).createAccount(
      name: 'Widget test Account',
    );
    appRouter.go('/');
  });

  tearDown(() async {
    await testDatabase.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
        ],
        child: const MyAccountsManagerApp(),
      ),
    );
    await pumpUntilFound(tester, find.text('Home'));
  }

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
      reason: 'The expected widget did not appear within '
          '${interval * maxPumps}.',
    );
  }

  testWidgets('launches the home dashboard with primary navigation',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('Your money, clearly organised.'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('MyKhata'), findsOneWidget);
  });

  testWidgets('opens the add transaction form from the floating action button',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntilFound(tester, find.text('How much did you spend?'));

    expect(find.text('Add transaction'), findsOneWidget);
    expect(find.text('How much did you spend?'), findsOneWidget);
  });

  testWidgets('switches the transaction form from expense to income',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add transaction'));
    await pumpUntilFound(tester, find.text('How much did you spend?'));

    await tester.tap(find.text('Income'));
    await pumpUntilFound(tester, find.text('How much did you receive?'));

    expect(find.text('How much did you receive?'), findsOneWidget);
  });
}
