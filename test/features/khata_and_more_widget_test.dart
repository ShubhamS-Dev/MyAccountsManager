import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_form_widgets.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/privacy_state.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/database/database_provider.dart';
import 'package:my_accounts_manager/features/categories/categories_providers.dart';
import 'package:my_accounts_manager/features/categories/presentation/categories_page.dart';
import 'package:my_accounts_manager/features/my_khata/data/khata_repository.dart';
import 'package:my_accounts_manager/features/my_khata/khata_providers.dart';
import 'package:my_accounts_manager/features/my_khata/presentation/khata_entry_form_page.dart';
import 'package:my_accounts_manager/features/my_khata/presentation/my_khata_page.dart';
import 'package:my_accounts_manager/features/my_khata/presentation/record_repayment_page.dart';
import 'package:my_accounts_manager/features/notifications/data/notification_preferences.dart';
import 'package:my_accounts_manager/features/notifications/notifications_providers.dart';
import 'package:my_accounts_manager/features/settings/data/settings_repository.dart';
import 'package:my_accounts_manager/features/settings/presentation/appearance_page.dart';
import 'package:my_accounts_manager/features/settings/presentation/info_pages.dart';
import 'package:my_accounts_manager/features/settings/presentation/more_page.dart';
import 'package:my_accounts_manager/features/settings/settings_providers.dart';

late AppDatabase database;

KhataPersonRow person(String id, String name) =>
    KhataPersonRow(id: id, name: name, createdAt: 0, updatedAt: 0);

KhataEntryItem entryItem({
  int amount = 10000000,
  int repaid = 2500000,
  String direction = khataLent,
}) => KhataEntryItem(
  entry: KhataEntryRow(
    id: 'entry-1',
    personId: 'p1',
    direction: direction,
    amountPaise: amount,
    entryDate: DateTime.utc(2026, 11, 1).millisecondsSinceEpoch,
    createdAt: 0,
    updatedAt: 0,
  ),
  personName: 'Asha Rao',
  repaidPaise: repaid,
);

void main() {
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    List<Override> overrides = const [],
  }) async {
    // Typical phone viewport (about 411 x 914 logical pixels).
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await database.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          themeModeProvider.overrideWith(
            (ref) => Stream.value(ThemeMode.light),
          ),
          storedAmountsHiddenProvider.overrideWith(
            (ref) => Stream.value(false),
          ),
          // The bell badge and More tile read these; keep Drift out of the tree.
          khataEntriesProvider.overrideWith(
            (ref, personId) => Stream.value(<KhataEntryItem>[]),
          ),
          notificationPreferencesProvider.overrideWith(
            (ref) => Stream.value(const NotificationPreferences()),
          ),
          ...overrides,
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('MyKhata tab shows net position and people', (tester) async {
    await pumpScreen(
      tester,
      const MyKhataPage(),
      overrides: [
        khataPeopleSummariesProvider.overrideWith(
          (ref) => Stream.value([
            KhataPersonSummary(
              person: person('p1', 'Asha Rao'),
              receivablePaise: 15000000,
              payablePaise: 0,
              openEntries: 1,
              totalEntries: 1,
              lastEntryDate: DateTime.utc(2026, 11, 1).millisecondsSinceEpoch,
            ),
            KhataPersonSummary(
              person: person('p2', 'Ravi'),
              receivablePaise: 0,
              payablePaise: 20050,
              openEntries: 1,
              totalEntries: 1,
              lastEntryDate: DateTime.utc(2026, 11, 2).millisecondsSinceEpoch,
            ),
          ]),
        ),
      ],
    );

    expect(find.text('NET KHATA POSITION'), findsOneWidget);
    // ₹1,50,000 receivable minus ₹200.50 payable.
    expect(find.text('+₹1,49,799.50'), findsOneWidget);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('₹1,50,000'), findsNWidgets(2));
    expect(find.text('₹200.50'), findsNWidgets(2));
    expect(find.text('AR'), findsOneWidget);

    await tester.tap(find.text('Settled'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('No matching people'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(TextField), 'rav');
    await tester.pump();
    expect(find.text('Ravi'), findsOneWidget);
    expect(find.text('Asha Rao'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('MyKhata empty state invites adding a person', (tester) async {
    await pumpScreen(
      tester,
      const MyKhataPage(),
      overrides: [
        khataPeopleSummariesProvider.overrideWith(
          (ref) => Stream.value(const <KhataPersonSummary>[]),
        ),
      ],
    );
    expect(find.text('Start your khata'), findsOneWidget);
    expect(find.text('Add person'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Record repayment confirms an amount above the outstanding', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const RecordRepaymentPage(entryId: 'entry-1'),
      overrides: [
        khataEntryProvider.overrideWith((ref, id) => Stream.value(entryItem())),
      ],
    );

    expect(find.text('Outstanding ₹75,000 of ₹1,00,000'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('khata-repayment-amount')),
      '80000',
    );
    await tester.pump();
    expect(find.text('80,000'), findsOneWidget);
    expect(find.text('Extra: you will owe Asha Rao'), findsOneWidget);
    expect(find.text('₹5,000'), findsOneWidget);

    await tester.tap(find.text('Save repayment'));
    await tester.pumpAndSettle();
    expect(find.text('More than the amount due'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Full ₹75,000'));
    await tester.pump();
    expect(find.text('75,000'), findsOneWidget);
    expect(find.byKey(const ValueKey('khata-payment-preview')), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Person payment previews oldest-first split', (tester) async {
    KhataEntryItem item(String id, int day, int amount) => KhataEntryItem(
      entry: KhataEntryRow(
        id: id,
        personId: 'p1',
        direction: khataLent,
        amountPaise: amount,
        entryDate: DateTime.utc(2026, 11, day).millisecondsSinceEpoch,
        createdAt: day,
        updatedAt: day,
      ),
      personName: 'Asha Rao',
      repaidPaise: 0,
    );
    await pumpScreen(
      tester,
      const RecordRepaymentPage.forPerson(personId: 'p1'),
      overrides: [
        khataEntriesProvider.overrideWith(
          (ref, personId) =>
              Stream.value([item('e2', 5, 30000), item('e1', 1, 20000)]),
        ),
      ],
    );

    expect(find.text('Record payment'), findsOneWidget);
    expect(find.text('Due ₹500 across 2 entries'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('khata-repayment-amount')),
      '250',
    );
    await tester.pump();
    expect(find.text('Settles 01 Nov 2026'), findsOneWidget);
    expect(find.text('Part of 05 Nov 2026'), findsOneWidget);
    expect(find.text('Save payment'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Date field names a picked date on its chip like Add '
      'Transaction', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(2026, 3, 9);
    await pumpScreen(
      tester,
      DateShortcutField(
        title: 'Date',
        date: picked,
        firstDate: today,
        lastDate: today,
        onChanged: (_) {},
      ),
    );
    expect(find.text('09 Mar 2026'), findsOneWidget);
    expect(find.text('Pick date'), findsNothing);
    // Yesterday is before firstDate: visible but disabled.
    final yesterday = tester.widget<InkWell>(
      find.ancestor(of: find.text('Yesterday'), matching: find.byType(InkWell)),
    );
    expect(yesterday.onTap, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Khata entry form keeps Person, Date, Note, Amount order', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const KhataEntryFormPage(initialPersonId: 'p1'),
      overrides: [
        khataPeopleSummariesProvider.overrideWith(
          (ref) => Stream.value([
            KhataPersonSummary(
              person: person('p1', 'Asha Rao'),
              receivablePaise: 0,
              payablePaise: 0,
              openEntries: 0,
              totalEntries: 0,
            ),
          ]),
        ),
      ],
    );

    double top(String text) => tester.getTopLeft(find.text(text).first).dy;
    expect(top('Person'), lessThan(top('Date')));
    expect(top('Date'), lessThan(top('Note')));
    expect(top('Note'), lessThan(top('Amount')));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('They will owe you this amount.'), findsOneWidget);

    await tester.tap(find.text('You got'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('You will owe them this amount.'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Appearance saves the chosen theme to the database', (
    tester,
  ) async {
    await pumpScreen(tester, const AppearancePage());

    await tester.tap(find.text('Dark'));
    await tester.pump();

    final stored = await tester.runAsync(
      () => SettingsRepository(database).watchValue(themeModeSettingKey).first,
    );
    expect(stored, 'dark');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('More hub lists every approved destination', (tester) async {
    await pumpScreen(tester, const MorePage());

    for (final title in [
      'Categories',
      'Archived Accounts',
      'Transaction Trash',
      'Appearance',
      'Currency & Format',
      'Budget Alerts',
      'Backup & Restore',
      'About App',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(title), findsOneWidget);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Categories switches between expense and income lists', (
    tester,
  ) async {
    final rows =
        await tester.runAsync(
          () => database.select(database.categories).get(),
        ) ??
        <CategoryRow>[];
    await pumpScreen(
      tester,
      const CategoriesPage(),
      overrides: [
        allCategoriesByTypeProvider.overrideWith(
          (ref, type) =>
              Stream.value(rows.where((row) => row.type == type).toList()),
        ),
      ],
    );

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);

    await tester.tap(find.text('Income'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Currency & Format shows live Indian grouping examples', (
    tester,
  ) async {
    await pumpScreen(tester, const CurrencyFormatPage());

    expect(find.text('₹1,000'), findsOneWidget);
    expect(find.text('₹1,00,000'), findsOneWidget);
    expect(find.text('₹1,00,00,000'), findsOneWidget);
    expect(find.text('One crore'), findsOneWidget);
    expect(find.text('₹500.50'), findsOneWidget);
    expect(find.text('-₹1,000'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
