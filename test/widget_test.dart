import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_accounts_manager/app/my_accounts_manager_app.dart';

void main() {
  testWidgets('launches the home dashboard with primary navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyAccountsManagerApp()));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Your money, clearly organised.'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('MyKhata'), findsOneWidget);
  });

  testWidgets('opens the add transaction form from the floating action button',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyAccountsManagerApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Add transaction'), findsOneWidget);
    expect(find.text('How much did you spend?'), findsOneWidget);
  });

  testWidgets('switches the transaction form from expense to income',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyAccountsManagerApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    expect(find.text('How much did you receive?'), findsOneWidget);
  });
}
