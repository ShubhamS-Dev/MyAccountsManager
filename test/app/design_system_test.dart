import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/app_widgets.dart';
import 'package:my_accounts_manager/app/icon_resolvers.dart';

void main() {
  test(
    'shared icon resolvers preserve existing Account and History mappings',
    () {
      expect(resolveAccountIcon('bank'), Icons.account_balance_rounded);
      expect(
        resolveAccountIcon('unknown'),
        Icons.account_balance_wallet_rounded,
      );
      expect(
        resolveCategoryIcon('food', income: false),
        Icons.restaurant_rounded,
      );
      expect(
        resolveCategoryIcon('Transportation', income: false),
        Icons.directions_car_rounded,
      );
      expect(
        resolveCategoryIcon('Vehicle Maintenance', income: false),
        Icons.car_repair_rounded,
      );
      expect(
        resolveCategoryIcon('Others', income: false),
        Icons.category_rounded,
      );
      expect(resolveCategoryIcon('Salary', income: true), Icons.work_rounded);
      expect(
        resolveCategoryIcon('unknown', income: true),
        Icons.south_west_rounded,
      );
    },
  );

  test(
    'design tokens follow the Material 3 type scale and touch dimensions',
    () {
      expect(AppSpacing.buttonHeight, 40);
      expect(AppSpacing.touchTarget, 48);
      expect(AppTypography.screenTitle.fontSize, 22);
      expect(AppTypography.sectionTitle.fontSize, 16);
      expect(AppTypography.fieldValue.fontSize, 14);
      expect(AppTypography.body.fontSize, 14);
      expect(AppTypography.supporting.fontSize, 12);
      expect(AppTypography.metadata.fontSize, 12);
      expect(AppTypography.button.fontSize, 14);
      expect(AppTypography.transactionAmount.fontSize, 16);
      expect(AppTypography.amountInput.fontSize, 28);
      expect(AppTypography.balance.fontSize, greaterThanOrEqualTo(36));
      expect(AppTypography.balance.fontSize, lessThanOrEqualTo(44));
      expect(AppColors.primary, const Color(0xFF4F46E5));
      expect(AppColors.violet, const Color(0xFF7C3AED));
      expect(AppColors.positive, const Color(0xFF10B981));
      expect(AppColors.negative, const Color(0xFFF43F5E));
    },
  );

  testWidgets('CategoryIconBadge resolves names and semantic fallback colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: const Scaffold(
          body: Row(
            children: [
              CategoryIconBadge(
                iconKey: null,
                categoryName: 'Groceries',
                colorValue: null,
                income: false,
              ),
              CategoryIconBadge(
                iconKey: null,
                categoryName: 'Rental Income',
                colorValue: null,
                income: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.shopping_basket_rounded), findsOneWidget);
    expect(find.byIcon(Icons.key_rounded), findsOneWidget);
    final badges = tester.widgetList<CategoryIconBadge>(
      find.byType(CategoryIconBadge),
    );
    expect(badges.length, 2);
    final icons = tester.widgetList<Icon>(
      find.descendant(
        of: find.byType(CategoryIconBadge),
        matching: find.byType(Icon),
      ),
    );
    expect(icons.first.color, AppColors.negative);
    expect(icons.last.color, AppColors.positive);
  });

  testWidgets('CategoryChip can tint an unselected icon per category', (
    tester,
  ) async {
    const categoryColor = Color(0xFF008577);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: const Scaffold(
          body: CategoryChip(
            label: 'Transport',
            icon: Icons.directions_car_rounded,
            selected: false,
            color: categoryColor,
            iconColor: categoryColor,
            onTap: _noop,
          ),
        ),
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.directions_car_rounded)).color,
      categoryColor,
    );
  });

  testWidgets('premium themes expose the right light and dark surfaces', (
    tester,
  ) async {
    final light = buildAppTheme(brightness: Brightness.light);
    final dark = buildAppTheme(brightness: Brightness.dark);

    expect(light.colorScheme.primary, AppColors.primary);
    expect(light.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(dark.colorScheme.primary, AppColors.primary);
    expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);
  });

  testWidgets(
    'reusable primary button preserves a 48px hit area and 40px face',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: PrimaryButton(label: 'Continue', onPressed: _noop),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(PrimaryButton)).height, 48);
      expect(tester.getSize(find.byType(FilledButton)).height, 40);
    },
  );
}

void _noop() {}
