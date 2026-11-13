import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/icon_catalog.dart';
import 'package:my_accounts_manager/app/icon_resolvers.dart';
import 'package:my_accounts_manager/features/accounts/presentation/account_form.dart';

void main() {
  group('icon catalog', () {
    final all = [for (final group in iconCatalog) ...group.icons];

    test('offers about 300 icons with unique keys', () {
      expect(all.length, greaterThanOrEqualTo(280));
      expect(all.map((icon) => icon.key).toSet().length, all.length);
      expect(iconCatalog.every((group) => group.icons.isNotEmpty), isTrue);
    });

    test('keys stored by older builds keep their icons', () {
      const categoryKeys = {
        'food': Icons.restaurant_rounded,
        'Food & Dining': Icons.restaurant_rounded,
        'groceries': Icons.shopping_basket_rounded,
        'shopping': Icons.shopping_bag_rounded,
        'Transportation': Icons.directions_car_rounded,
        'vehicle_maintenance': Icons.car_repair_rounded,
        'Vehicle Maintenance': Icons.car_repair_rounded,
        'Housing & Utilities': Icons.home_rounded,
        'household': Icons.chair_alt_rounded,
        'Health & Medical': Icons.medical_services_rounded,
        'Personal Care': Icons.spa_rounded,
        'Travel & Stay': Icons.flight_rounded,
        'entertainment': Icons.movie_rounded,
        'education': Icons.school_rounded,
        'Family & Gifts': Icons.card_giftcard_rounded,
        'Financial Payments': Icons.account_balance_wallet_rounded,
        'payments': Icons.account_balance_wallet_rounded,
        'donations': Icons.volunteer_activism_rounded,
        'salary': Icons.work_rounded,
        'Business': Icons.work_rounded,
        'Freelancing': Icons.work_rounded,
        'investments': Icons.trending_up_rounded,
        'rental_income': Icons.key_rounded,
        'refunds': Icons.currency_exchange_rounded,
        'others': Icons.category_rounded,
      };
      categoryKeys.forEach((key, icon) {
        expect(resolveCategoryIcon(key, income: false), icon, reason: key);
      });

      const accountKeys = {
        'bank': Icons.account_balance_rounded,
        'cash': Icons.payments_rounded,
        'card': Icons.credit_card_rounded,
        'wallet': Icons.account_balance_wallet_rounded,
        'savings': Icons.savings_rounded,
        'investment': Icons.trending_up_rounded,
        null: Icons.account_balance_wallet_rounded,
      };
      accountKeys.forEach((key, icon) {
        expect(resolveAccountIcon(key), icon, reason: '$key');
      });
    });

    test('new keys resolve for both categories and Accounts', () {
      expect(resolveCategoryIcon('pets', income: false), Icons.pets_rounded);
      expect(resolveAccountIcon('upi'), Icons.qr_code_scanner_rounded);
      expect(canonicalIconKey('payments'), 'wallet');
      expect(canonicalIconKey('unknown'), isNull);
    });

    test('all seeded category names resolve to category icons', () {
      const expenseNames = [
        'Food & Dining',
        'Groceries',
        'Transportation',
        'Vehicle Maintenance',
        'Housing & Utilities',
        'Shopping',
        'Household',
        'Health & Medical',
        'Personal Care',
        'Travel & Stay',
        'Entertainment',
        'Education',
        'Family & Gifts',
        'Financial Payments',
        'Donations',
        'Others',
      ];
      const incomeNames = [
        'Salary',
        'Business',
        'Freelancing',
        'Investments',
        'Rental Income',
        'Gifts & Rewards',
        'Refunds',
        'Others',
      ];

      for (final name in expenseNames) {
        expect(
          resolveCategoryIcon(name, income: false),
          isNot(Icons.north_east_rounded),
          reason: name,
        );
      }
      for (final name in incomeNames) {
        expect(
          resolveCategoryIcon(name, income: true),
          isNot(Icons.south_west_rounded),
          reason: name,
        );
      }
    });

    test('search matches labels, keys and tags', () {
      final petrol = all.where((icon) => icon.matches('petrol'));
      expect(petrol.map((icon) => icon.key), contains('fuel'));
      expect(
        all.where((icon) => icon.matches('cab uber')).map((icon) => icon.key),
        ['taxi'],
      );
    });
  });

  testWidgets('More icons opens the catalog sheet and picks a searched icon', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AccountIconPicker(
              selected: picked,
              onChanged: (key) => setState(() => picked = key),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('account-more-icons')));
    await tester.pumpAndSettle();
    expect(find.text('Choose an icon'), findsOneWidget);
    final sheetHeight = tester.getSize(find.byType(BottomSheet)).height;
    expect(
      sheetHeight,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );

    await tester.enterText(
      find.byKey(const ValueKey('icon-picker-search')),
      'upi',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('icon-option-upi')));
    await tester.pumpAndSettle();

    expect(picked, 'upi');
    // The custom pick now shows first in the quick row, selected.
    expect(find.text('UPI / QR'), findsOneWidget);
  });
}
