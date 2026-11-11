import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/privacy_state.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/time/today_provider.dart';
import 'package:my_accounts_manager/features/accounts/accounts_providers.dart';
import 'package:my_accounts_manager/features/categories/categories_providers.dart';
import 'package:my_accounts_manager/features/recurring/data/recurring_repository.dart';
import 'package:my_accounts_manager/features/recurring/domain/recurrence.dart';
import 'package:my_accounts_manager/features/recurring/recurring_providers.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';
import 'package:my_accounts_manager/features/transactions/presentation/add_transaction_page.dart';
import 'package:my_accounts_manager/features/transactions/presentation/edit_transaction_page.dart';
import 'package:my_accounts_manager/features/transactions/presentation/transaction_details_page.dart';
import 'package:my_accounts_manager/features/transactions/presentation/transaction_form_widgets.dart';
import 'package:my_accounts_manager/features/transactions/transactions_providers.dart';

CategoryRow category(String id, String name, {bool active = true}) =>
    CategoryRow(
      id: id,
      name: name,
      type: 'expense',
      isSystem: false,
      sortOrder: 0,
      isActive: active,
      createdAt: 0,
      updatedAt: 0,
    );

AccountRow account(String id, String name, {int? archivedAt}) => AccountRow(
  id: id,
  name: name,
  openingBalancePaise: 0,
  isPinned: false,
  sortOrder: 0,
  archivedAt: archivedAt,
  createdAt: 0,
  updatedAt: 0,
);

final manyCategories = [
  for (final name in [
    'Food & Dining',
    'Groceries',
    'Transportation',
    'Shopping',
    'Health',
    'Education',
    'Travel',
    'Entertainment',
    'Bills',
    'Rent',
    'Fuel',
    'Others',
  ])
    category(name.toLowerCase().replaceAll(' ', '-'), name),
];

final wallet = account('wallet', 'Wallet');
final oldBank = account('old-bank', 'Old Bank', archivedAt: 1);
final hiddenCategory = category('pets', 'Pets', active: false);

final copySource = TransactionRow(
  id: 't1',
  accountId: wallet.id,
  categoryId: 'travel',
  type: 'expense',
  amountPaise: 125050,
  note: 'Cab to airport',
  transactionDate: DateTime.utc(2026, 10, 2).millisecondsSinceEpoch,
  createdAt: 0,
  updatedAt: 0,
);

class _NoSuggestionsRepository extends TransactionsRepository {
  _NoSuggestionsRepository(super.database);

  final duplicated = <(String, int)>[];
  final discarded = <String>[];

  @override
  Future<TransactionRow?> getTransaction(String transactionId) async =>
      transactionId == copySource.id ? copySource : null;

  @override
  Future<String> duplicateTransaction(
    String transactionId, {
    required int transactionDate,
  }) async {
    duplicated.add((transactionId, transactionDate));
    return 'copy-1';
  }

  @override
  Future<void> discardTransaction(String transactionId) async =>
      discarded.add(transactionId);

  @override
  Future<String> createTransaction({
    required String accountId,
    required String categoryId,
    required String type,
    required int amountPaise,
    required int transactionDate,
    String? note,
    String? recurringRuleId,
  }) async => 'new-1';

  @override
  Future<List<String>> suggestNotes(
    String type,
    String query, {
    int limit = 5,
  }) async => const [];

  @override
  Future<String?> suggestCategoryForNote(String type, String note) async =>
      null;
}

class _RecordingRecurringRepository extends RecurringRepository {
  _RecordingRecurringRepository(super.database, super.transactions);

  final started = <(String, RecurringFrequency, int?)>[];

  @override
  Future<String> createFromTransaction({
    required String transactionId,
    required RecurringFrequency frequency,
    required int today,
    int? endDate,
  }) async {
    started.add((transactionId, frequency, endDate));
    return 'rule-1';
  }
}

void main() {
  late AppDatabase database;
  late _NoSuggestionsRepository repository;
  late _RecordingRecurringRepository recurring;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = _NoSuggestionsRepository(database);
    recurring = _RecordingRecurringRepository(database, repository);
  });

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    List<Override> overrides = const [],
  }) async {
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
          transactionsRepositoryProvider.overrideWithValue(repository),
          recurringRepositoryProvider.overrideWithValue(recurring),
          activeAccountsProvider.overrideWith((ref) => Stream.value([wallet])),
          allAccountsProvider.overrideWith(
            (ref) => Stream.value([wallet, oldBank]),
          ),
          accountBalancePaiseProvider.overrideWith(
            (ref, id) => Stream.value(0),
          ),
          storedAmountsHiddenProvider.overrideWith(
            (ref) => Stream.value(false),
          ),
          recentCategoriesByTypeProvider.overrideWith(
            (ref, type) => Stream.value(manyCategories),
          ),
          allCategoriesByTypeProvider.overrideWith(
            (ref, type) => Stream.value([...manyCategories, hiddenCategory]),
          ),
          recentNotesProvider.overrideWith((ref, type) async => const []),
          ...overrides,
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          home: page,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openDropdown(WidgetTester tester, String key) async {
    final dropdown = find.byKey(ValueKey(key));
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
  }

  testWidgets('Category dropdown opens a compact, searchable popover', (
    tester,
  ) async {
    await pump(tester, const AddTransactionPage());
    await openDropdown(tester, 'add-transaction-category-dropdown');

    final menu = find.byKey(const ValueKey('category-dropdown-menu'));
    expect(menu, findsOneWidget);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final menuSize = tester.getSize(menu);
    expect(menuSize.height, lessThanOrEqualTo(380));
    expect(menuSize.height, lessThan(screen.height / 2));
    expect(
      menuSize.width,
      tester
          .getSize(
            find.byKey(const ValueKey('add-transaction-category-dropdown')),
          )
          .width,
    );

    await tester.enterText(
      find.byKey(const ValueKey('category-dropdown-search')),
      'tra',
    );
    await tester.pump();
    expect(
      find.descendant(of: menu, matching: find.text('Transportation')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menu, matching: find.text('Groceries')),
      findsNothing,
    );

    await tester.tap(find.descendant(of: menu, matching: find.text('Travel')));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(
      tester
          .widget<CategoryDropdown>(
            find.byKey(const ValueKey('add-transaction-category-dropdown')),
          )
          .selectedId,
      'travel',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Tapping outside closes the popover without changing it', (
    tester,
  ) async {
    await pump(tester, const AddTransactionPage());
    await openDropdown(tester, 'add-transaction-category-dropdown');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('category-dropdown-menu')), findsNothing);
    expect(
      tester
          .widget<CategoryDropdown>(
            find.byKey(const ValueKey('add-transaction-category-dropdown')),
          )
          .selectedId,
      isNull,
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Edit uses the premium form and keeps hidden saved values', (
    tester,
  ) async {
    await pump(
      tester,
      const EditTransactionPage(transactionId: 't1'),
      overrides: [
        transactionByIdProvider.overrideWith(
          (ref, id) async => TransactionRow(
            id: 't1',
            accountId: oldBank.id,
            categoryId: hiddenCategory.id,
            type: 'expense',
            amountPaise: 125050,
            note: 'Vet visit',
            transactionDate: DateTime.utc(2026, 11, 1).millisecondsSinceEpoch,
            createdAt: 0,
            updatedAt: 0,
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.byType(TransactionTypeSelector), findsOneWidget);
    expect(find.byType(TransactionAccountSelector), findsOneWidget);
    expect(find.text('Old Bank'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('1,250.50'), findsOneWidget);
    expect(find.text('Update transaction'), findsOneWidget);

    final dropdown = find.byKey(
      const ValueKey('edit-transaction-category-dropdown'),
    );
    await tester.ensureVisible(dropdown);
    expect(tester.widget<CategoryDropdown>(dropdown).selectedId, 'pets');
    expect(find.text('Hidden category'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Copy as new prefills the form but keeps today', (tester) async {
    await pump(tester, AddTransactionPage(copyFromId: copySource.id));
    await tester.pump();

    expect(find.text('Copy transaction'), findsOneWidget);
    expect(find.text('1,250.50'), findsOneWidget);
    expect(find.text('Cab to airport'), findsWidgets);
    expect(
      tester
          .widget<CategoryDropdown>(
            find.byKey(const ValueKey('add-transaction-category-dropdown')),
          )
          .selectedId,
      'travel',
    );
    // Today chip is the selected date, not the source's 2 Oct.
    expect(find.text('Pick date'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Details Duplicate saves a copy today and Undo discards it', (
    tester,
  ) async {
    await pump(
      tester,
      TransactionDetailsPage(transactionId: copySource.id),
      overrides: [
        transactionByIdProvider.overrideWith((ref, id) async => copySource),
        todayProvider.overrideWithValue(
          DateTime.utc(2026, 11, 11).millisecondsSinceEpoch,
        ),
      ],
    );
    await tester.pump();

    final duplicate = find.byKey(const ValueKey('transaction-duplicate'));
    await tester.ensureVisible(duplicate);
    await tester.tap(duplicate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.duplicated, [
      (copySource.id, DateTime.utc(2026, 11, 11).millisecondsSinceEpoch),
    ]);
    expect(find.text('Duplicated to today'), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-copy-as-new')), findsOne);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(repository.discarded, ['copy-1']);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Repeat monthly saves the transaction and starts a series', (
    tester,
  ) async {
    await pump(tester, const AddTransactionPage());
    await tester.enterText(
      find.byKey(const ValueKey('add-transaction-amount-input')),
      '25,000',
    );
    final monthly = find.byKey(const ValueKey('repeat-monthly'));
    await tester.ensureVisible(monthly);
    await tester.pumpAndSettle();
    await tester.tap(monthly);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('repeat-summary')), findsOneWidget);
    expect(find.textContaining('Every month on day'), findsOneWidget);
    expect(find.text('No end'), findsOneWidget);

    await tester.tap(find.text('Save transaction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(recurring.started, [('new-1', RecurringFrequency.monthly, null)]);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Never repeat saves without a series', (tester) async {
    await pump(tester, const AddTransactionPage());
    await tester.enterText(
      find.byKey(const ValueKey('add-transaction-amount-input')),
      '100',
    );
    await tester.tap(find.text('Save transaction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(recurring.started, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
