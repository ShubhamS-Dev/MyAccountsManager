import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/privacy_state.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/features/accounts/accounts_providers.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';
import 'package:my_accounts_manager/features/categories/categories_providers.dart';
import 'package:my_accounts_manager/features/transactions/data/note_suggestions.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';
import 'package:my_accounts_manager/features/transactions/presentation/add_transaction_page.dart';
import 'package:my_accounts_manager/features/transactions/presentation/edit_transaction_page.dart';
import 'package:my_accounts_manager/features/transactions/transactions_providers.dart';

CategoryRow category(String id, String name, {String type = 'expense'}) =>
    CategoryRow(
      id: id,
      name: name,
      type: type,
      isSystem: true,
      sortOrder: 0,
      isActive: true,
      createdAt: 0,
      updatedAt: 0,
    );

final food = category('food', 'Food & Dining');
final groceries = category('groceries', 'Groceries');
final transport = category('transport', 'Transportation');
final shopping = category('shopping', 'Shopping');
final salary = category('salary', 'Salary', type: 'income');
final expenseCategories = [food, groceries, transport, shopping];

/// Suggestion methods answer from in-memory history, so widget tests never
/// open a real Drift query inside the fake-async zone.
class FakeSuggestionsRepository extends TransactionsRepository {
  FakeSuggestionsRepository(super.database, this.history);

  final List<NoteUse> history;

  @override
  Future<List<String>> suggestNotes(
    String type,
    String query, {
    int limit = 5,
  }) async => matchingNotesFrom(history, query, limit: limit);

  @override
  Future<String?> suggestCategoryForNote(String type, String note) async =>
      suggestCategoryFrom(
        history,
        type == 'income' ? [salary] : expenseCategories,
        note,
      );
}

void main() {
  group('note suggestion helpers', () {
    const uses = [
      NoteUse(note: 'Swiggy dinner', categoryId: 'food'),
      NoteUse(note: 'Milk', categoryId: 'groceries'),
      NoteUse(note: 'swiggy  dinner', categoryId: 'food'),
      NoteUse(note: 'Uber to office', categoryId: 'transport'),
      NoteUse(note: 'Big bazaar', categoryId: 'shopping'),
      NoteUse(note: 'Milk', categoryId: 'groceries'),
    ];

    test('recent notes are distinct and newest first', () {
      expect(recentNotesFrom(uses), [
        'Swiggy dinner',
        'Milk',
        'Uber to office',
        'Big bazaar',
      ]);
      expect(recentNotesFrom(uses, limit: 2), ['Swiggy dinner', 'Milk']);
    });

    test('matching notes rank prefix, then word prefix, then substring', () {
      const pool = [
        NoteUse(note: 'Office lunch', categoryId: 'food'),
        NoteUse(note: 'Uber to office', categoryId: 'transport'),
        NoteUse(note: 'Officeworks', categoryId: 'shopping'),
        NoteUse(note: 'Backoffice snacks', categoryId: 'food'),
      ];
      expect(matchingNotesFrom(pool, 'off'), [
        'Office lunch',
        'Officeworks',
        'Uber to office',
        'Backoffice snacks',
      ]);
    });

    test('matching notes skip an exact match and prefer frequent notes', () {
      expect(matchingNotesFrom(uses, 'milk'), isEmpty);
      const pool = [
        NoteUse(note: 'Movie night', categoryId: 'food'),
        NoteUse(note: 'Movie tickets', categoryId: 'food'),
        NoteUse(note: 'Movie tickets', categoryId: 'food'),
      ];
      expect(matchingNotesFrom(pool, 'mov'), ['Movie tickets', 'Movie night']);
    });

    test('history beats keywords for the same note', () {
      const pool = [NoteUse(note: 'Swiggy', categoryId: 'groceries')];
      expect(
        suggestCategoryFrom(pool, expenseCategories, 'swiggy'),
        'groceries',
      );
      expect(
        suggestCategoryFrom(const [], expenseCategories, 'Swiggy'),
        'food',
      );
    });

    test('history weights recent use over older habits', () {
      final pool = [
        for (var i = 0; i < 3; i++)
          const NoteUse(note: 'Weekly box', categoryId: 'groceries'),
        for (var i = 0; i < 3; i++)
          const NoteUse(note: 'Weekly box', categoryId: 'shopping'),
      ];
      expect(
        suggestCategoryFrom(pool, expenseCategories, 'weekly box'),
        'groceries',
      );
    });

    test('keywords match words and phrases, not substrings', () {
      expect(
        suggestCategoryFrom(const [], expenseCategories, 'Petrol refill'),
        'transport',
      );
      expect(
        suggestCategoryFrom(const [], expenseCategories, 'autograph'),
        isNull,
      );
      expect(
        suggestCategoryFrom(const [], expenseCategories, 'misc stuff'),
        isNull,
      );
    });

    test('custom categories match on their own name', () {
      final custom = category('pets', 'Pet Care');
      expect(
        suggestCategoryFrom(const [], [
          ...expenseCategories,
          custom,
        ], 'pet care'),
        'pets',
      );
    });

    test('never suggests an inactive or other-type category', () {
      const pool = [NoteUse(note: 'Swiggy', categoryId: 'hidden')];
      expect(suggestCategoryFrom(pool, expenseCategories, 'Swiggy'), 'food');
      expect(suggestCategoryFrom(const [], [salary], 'Swiggy'), isNull);
    });
  });

  group('TransactionsRepository suggestions', () {
    late AppDatabase database;
    late TransactionsRepository transactions;
    late String accountId;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      transactions = TransactionsRepository(database);
      accountId = await AccountsRepository(
        database,
      ).createAccount(name: 'Wallet');
    });

    tearDown(() => database.close());

    Future<String> categoryId(String name, String type) async =>
        (await (database.select(database.categories)..where(
                  (row) => row.name.equals(name) & row.type.equals(type),
                ))
                .getSingle())
            .id;

    Future<String> add(
      String note,
      String categoryName, {
      String type = 'expense',
    }) async => transactions.createTransaction(
      accountId: accountId,
      categoryId: await categoryId(categoryName, type),
      type: type,
      amountPaise: 1000,
      transactionDate: DateTime.utc(2026, 11, 10).millisecondsSinceEpoch,
      note: note,
    );

    test('skips Trash and keeps expense and income apart', () async {
      await add('Chai', 'Food & Dining');
      final trashed = await add('Cinema', 'Entertainment');
      await add('Salary credit', 'Salary', type: 'income');
      await transactions.softDeleteTransaction(trashed);

      expect(await transactions.recentNotes('expense'), ['Chai']);
      expect(await transactions.recentNotes('income'), ['Salary credit']);
      expect(await transactions.suggestNotes('expense', 'cin'), isEmpty);
    });

    test('suggests the category used before for the same note', () async {
      await add('Chai', 'Groceries');
      expect(
        await transactions.suggestCategoryForNote('expense', 'chai'),
        await categoryId('Groceries', 'expense'),
      );
      expect(
        await transactions.suggestCategoryForNote('expense', 'Zomato order'),
        await categoryId('Food & Dining', 'expense'),
      );
      expect(await transactions.suggestCategoryForNote('expense', ' '), isNull);
    });

    test('ignores a hidden category even with history', () async {
      await add('Chai', 'Groceries');
      await (database.update(database.categories)
            ..where((row) => row.name.equals('Groceries')))
          .write(const CategoriesCompanion(isActive: Value(false)));
      expect(
        await transactions.suggestCategoryForNote('expense', 'chai'),
        isNull,
      );
    });
  });

  group('transaction forms', () {
    late AppDatabase database;
    late AccountRow account;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    Future<void> pump(
      WidgetTester tester,
      Widget page, {
      required List<NoteUse> history,
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
      account = (await tester.runAsync(() async {
        final id = await AccountsRepository(
          database,
        ).createAccount(name: 'Wallet');
        return (database.select(
          database.accounts,
        )..where((row) => row.id.equals(id))).getSingle();
      }))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsRepositoryProvider.overrideWithValue(
              FakeSuggestionsRepository(database, history),
            ),
            activeAccountsProvider.overrideWith(
              (ref) => Stream.value([account]),
            ),
            allAccountsProvider.overrideWith((ref) => Stream.value([account])),
            accountBalancePaiseProvider.overrideWith(
              (ref, id) => Stream.value(0),
            ),
            storedAmountsHiddenProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            activeCategoriesByTypeProvider.overrideWith(
              (ref, type) =>
                  Stream.value(type == 'income' ? [salary] : expenseCategories),
            ),
            recentNotesProvider.overrideWith(
              (ref, type) async => recentNotesFrom(history),
            ),
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

    bool chipSelected(WidgetTester tester, String label) =>
        tester
            .widget<Semantics>(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is Semantics &&
                          widget.properties.button == true,
                    ),
                  )
                  .first,
            )
            .properties
            .selected ==
        true;

    testWidgets('Add shows recent notes and auto-selects the category', (
      tester,
    ) async {
      await pump(
        tester,
        const AddTransactionPage(),
        history: const [
          NoteUse(note: 'Weekly veggies', categoryId: 'groceries'),
          NoteUse(note: 'Uber to office', categoryId: 'transport'),
        ],
      );

      expect(find.text('Recent'), findsOneWidget);
      await tester.tap(find.text('Weekly veggies'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Suggested from note'), findsOneWidget);
      expect(chipSelected(tester, 'Groceries'), isTrue);

      await tester.enterText(
        find.byKey(const ValueKey('add-transaction-note-input')),
        'Uber',
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Suggestions'), findsOneWidget);
      expect(find.text('Uber to office'), findsOneWidget);
      expect(chipSelected(tester, 'Transportation'), isTrue);
      expect(chipSelected(tester, 'Groceries'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('Add never overrides a category the user picked', (
      tester,
    ) async {
      await pump(tester, const AddTransactionPage(), history: const []);

      await tester.ensureVisible(find.text('Shopping'));
      await tester.tap(find.text('Shopping'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('add-transaction-note-input')),
        'Swiggy dinner',
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(chipSelected(tester, 'Shopping'), isTrue);
      expect(chipSelected(tester, 'Food & Dining'), isFalse);
      expect(find.text('Suggested from note'), findsNothing);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('Edit suggests a category and applies it only on Use', (
      tester,
    ) async {
      await pump(
        tester,
        const EditTransactionPage(transactionId: 't1'),
        history: const [],
        overrides: [
          transactionByIdProvider.overrideWith(
            (ref, id) async => TransactionRow(
              id: 't1',
              accountId: account.id,
              categoryId: 'shopping',
              type: 'expense',
              amountPaise: 25000,
              note: 'Gift',
              transactionDate: DateTime.utc(
                2026,
                11,
                10,
              ).millisecondsSinceEpoch,
              createdAt: 0,
              updatedAt: 0,
            ),
          ),
        ],
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('edit-transaction-category-suggestion')),
        findsNothing,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Gift'),
        'Zomato',
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Suggested from note: Food & Dining'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);

      await tester.tap(find.text('Use'));
      await tester.pump();
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-transaction-category-suggestion')),
        findsNothing,
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
