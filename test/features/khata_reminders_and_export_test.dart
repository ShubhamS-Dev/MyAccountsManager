import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/privacy_state.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/database/database_provider.dart';
import 'package:my_accounts_manager/core/platform/external_apps.dart';
import 'package:my_accounts_manager/core/time/today_provider.dart';
import 'package:my_accounts_manager/features/export/export_providers.dart';
import 'package:my_accounts_manager/features/export/presentation/export_page.dart';
import 'package:my_accounts_manager/features/my_khata/data/khata_messages.dart';
import 'package:my_accounts_manager/features/my_khata/data/khata_repository.dart';
import 'package:my_accounts_manager/features/my_khata/khata_providers.dart';
import 'package:my_accounts_manager/features/my_khata/presentation/my_khata_page.dart';
import 'package:my_accounts_manager/features/my_khata/presentation/person_details_page.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';
import 'package:my_accounts_manager/features/transactions/transactions_providers.dart';

int day(int y, int m, int d) => DateTime.utc(y, m, d).millisecondsSinceEpoch;

KhataEntryItem entry(
  String id, {
  String personId = 'p1',
  String personName = 'Asha Rao',
  String direction = khataLent,
  int amount = 100000,
  int repaid = 0,
  int? entryDate,
  int? dueDate,
  String? note,
}) => KhataEntryItem(
  entry: KhataEntryRow(
    id: id,
    personId: personId,
    direction: direction,
    amountPaise: amount,
    entryDate: entryDate ?? day(2026, 11, 1),
    dueDate: dueDate,
    note: note,
    createdAt: 0,
    updatedAt: 0,
  ),
  personName: personName,
  repaidPaise: repaid,
);

KhataRepaymentRow repayment(String entryId, int amount, int date) =>
    KhataRepaymentRow(
      id: 'r-$entryId-$date',
      entryId: entryId,
      amountPaise: amount,
      repaymentDate: date,
      createdAt: 0,
      updatedAt: 0,
    );

class _FakeKhataRepository extends KhataRepository {
  _FakeKhataRepository(super.database, {this.repayments = const []});

  final List<KhataRepaymentRow> repayments;

  @override
  Stream<List<KhataEntryItem>> watchEntries({String? personId}) =>
      Stream.value(const []);

  @override
  Future<List<KhataRepaymentRow>> activeRepayments({String? personId}) async =>
      repayments;
}

class _FakeTransactionsRepository extends TransactionsRepository {
  _FakeTransactionsRepository(super.database);

  @override
  Stream<List<TransactionHistoryItem>> watchHistory({
    String? accountId,
    int? fromDate,
    int? throughDate,
    String? type,
  }) => Stream.value(const []);
}

void main() {
  final today = day(2026, 11, 11);

  group('KhataMessages', () {
    test('WhatsApp numbers default to India', () {
      expect(KhataMessages.whatsAppNumber('98765 43210'), '919876543210');
      expect(KhataMessages.whatsAppNumber('098765-43210'), '919876543210');
      expect(KhataMessages.whatsAppNumber('+91 98765 43210'), '919876543210');
      expect(KhataMessages.whatsAppNumber('919876543210'), '919876543210');
      expect(KhataMessages.whatsAppNumber('+44 7700 900123'), '447700900123');
      expect(KhataMessages.whatsAppNumber('0044 7700 900123'), '447700900123');
      expect(KhataMessages.whatsAppNumber('12345'), isNull);
      expect(KhataMessages.whatsAppNumber(''), isNull);
    });

    test('links encode the message and keep + on calls', () {
      expect(
        KhataMessages.whatsAppUri('919876543210', text: 'Hi & bye').toString(),
        'https://wa.me/919876543210?text=Hi+%26+bye',
      );
      expect(
        KhataMessages.callUri('+91 98765-43210').toString(),
        'tel:+919876543210',
      );
    });

    test('reminder names the amount and the due date', () {
      String remind(int? due) => KhataMessages.reminder(
        name: 'Asha Rao',
        owedPaise: 150000,
        dueDate: due,
        today: today,
      );
      expect(
        remind(day(2026, 11, 5)),
        'Hi Asha, a friendly reminder that ₹1,500 is pending. '
        'It was due on 05 Nov 2026. Please settle it when you can. Thank you!',
      );
      expect(remind(today), contains('It is due today.'));
      expect(remind(day(2026, 11, 20)), contains('It is due on 20 Nov 2026.'));
      expect(remind(null), isNot(contains('due')));
    });

    test('earliest due date ignores settled and borrowed entries', () {
      expect(
        KhataMessages.earliestDueDate([
          entry('a', dueDate: day(2026, 11, 20)),
          entry('b', dueDate: day(2026, 11, 3), repaid: 100000),
          entry('c', dueDate: day(2026, 11, 1), direction: khataBorrowed),
          entry('d', dueDate: day(2026, 11, 9)),
        ]),
        day(2026, 11, 9),
      );
    });

    test('statement lists open, settled, repayments and net', () {
      final text = KhataMessages.statement(
        name: 'Asha Rao',
        entries: [
          entry(
            'a',
            amount: 100000,
            repaid: 40000,
            dueDate: day(2026, 11, 5),
            note: 'Rent share',
          ),
          entry(
            'b',
            direction: khataBorrowed,
            amount: 20000,
            repaid: 20000,
            entryDate: day(2026, 10, 1),
          ),
        ],
        repayments: [
          repayment('b', 20000, day(2026, 10, 15)),
          repayment('a', 40000, day(2026, 11, 6)),
        ],
        today: today,
      );
      expect(
        text,
        'MyKhata statement: Asha Rao\n'
        'As of 11 Nov 2026\n'
        '\n'
        'Open\n'
        '01 Nov 2026  You gave ₹1,000 · repaid ₹400, ₹600 left · '
        'due 05 Nov 2026 (overdue) · Rent share\n'
        '\n'
        'Settled\n'
        '01 Oct 2026  You got ₹200\n'
        '\n'
        'Repayments\n'
        '15 Oct 2026  You paid ₹200\n'
        '06 Nov 2026  Asha Rao paid ₹400\n'
        '\n'
        'Asha Rao owes you ₹600',
      );
    });
  });

  group('screens', () {
    late AppDatabase database;
    final launched = <Uri>[];
    final sharedText = <String>[];

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      launched.clear();
      sharedText.clear();
    });

    Future<void> pumpScreen(
      WidgetTester tester,
      Widget screen, {
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
            appDatabaseProvider.overrideWithValue(database),
            todayProvider.overrideWithValue(today),
            storedAmountsHiddenProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            externalLauncherProvider.overrideWithValue((uri) async {
              launched.add(uri);
              return true;
            }),
            textSharerProvider.overrideWithValue((text, {subject}) async {
              sharedText.add(text);
            }),
            ...overrides,
          ],
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            home: screen,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    List<Override> personOverrides({
      String? phone = '98765 43210',
      int receivable = 60000,
      List<KhataEntryItem>? entries,
    }) => [
      khataRepositoryProvider.overrideWith(
        (ref) => _FakeKhataRepository(
          database,
          repayments: [repayment('a', 40000, day(2026, 11, 6))],
        ),
      ),
      khataPersonProvider.overrideWith(
        (ref, id) => Stream.value(
          KhataPersonRow(
            id: 'p1',
            name: 'Asha Rao',
            phone: phone,
            createdAt: 0,
            updatedAt: 0,
          ),
        ),
      ),
      khataEntriesProvider.overrideWith(
        (ref, id) => Stream.value(
          entries ??
              [
                entry(
                  'a',
                  amount: 100000,
                  repaid: 40000,
                  dueDate: day(2026, 11, 5),
                ),
              ],
        ),
      ),
      khataPeopleSummariesProvider.overrideWith(
        (ref) => Stream.value([
          KhataPersonSummary(
            person: KhataPersonRow(
              id: 'p1',
              name: 'Asha Rao',
              phone: phone,
              createdAt: 0,
              updatedAt: 0,
            ),
            receivablePaise: receivable,
            payablePaise: 0,
            openEntries: 1,
            totalEntries: 1,
          ),
        ]),
      ),
    ];

    testWidgets('phone opens Call and WhatsApp', (tester) async {
      await pumpScreen(
        tester,
        const PersonDetailsPage(personId: 'p1'),
        overrides: personOverrides(),
      );

      await tester.tap(find.text('98765 43210'));
      await tester.pumpAndSettle();
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Send reminder on WhatsApp'), findsOneWidget);
      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();
      expect(launched.single.toString(), 'tel:9876543210');

      await tester.tap(find.text('98765 43210'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(launched.last.toString(), 'https://wa.me/919876543210');
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('Send reminder prefills WhatsApp or the share sheet', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const PersonDetailsPage(personId: 'p1'),
        overrides: personOverrides(),
      );

      await tester.tap(find.text('Send reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      final text = launched.single.queryParameters['text']!;
      expect(text, contains('₹600 is pending'));
      expect(text, contains('It was due on 05 Nov 2026.'));

      await tester.tap(find.text('Send reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other apps'));
      await tester.pumpAndSettle();
      expect(sharedText.single, text);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('no reminder when they owe nothing; statement still shares', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const PersonDetailsPage(personId: 'p1'),
        overrides: personOverrides(phone: null, receivable: 0),
      );

      expect(find.text('Send reminder'), findsNothing);
      await tester.tap(find.text('Statement'));
      await tester.pumpAndSettle();
      expect(sharedText.single, startsWith('MyKhata statement: Asha Rao'));
      expect(sharedText.single, contains('06 Nov 2026  Asha Rao paid ₹400'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('MyKhata shows overdue entries and filters to them', (
      tester,
    ) async {
      KhataPersonSummary summary(String id, String name) => KhataPersonSummary(
        person: KhataPersonRow(id: id, name: name, createdAt: 0, updatedAt: 0),
        receivablePaise: 50000,
        payablePaise: 0,
        openEntries: 1,
        totalEntries: 1,
        lastEntryDate: day(2026, 11, 1),
      );
      await pumpScreen(
        tester,
        const Scaffold(body: MyKhataPage()),
        overrides: [
          khataPeopleSummariesProvider.overrideWith(
            (ref) => Stream.value([
              summary('p1', 'Asha Rao'),
              summary('p2', 'Ravi'),
            ]),
          ),
          khataEntriesProvider.overrideWith(
            (ref, id) => Stream.value([
              // Long past, so overdue whatever the test machine's date.
              entry('a', dueDate: day(2020, 1, 1)),
              entry('b', personId: 'p2', personName: 'Ravi'),
            ]),
          ),
        ],
      );

      expect(find.text('1 entry is overdue'), findsOneWidget);
      await tester.tap(find.text('1 entry is overdue'));
      await tester.pumpAndSettle();
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Ravi'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Ravi'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('Export page shares the chosen CSV files', (tester) async {
      final directory = Directory.systemTemp.createTempSync('export_page');
      addTearDown(() => directory.deleteSync(recursive: true));
      final shared = <List<String>>[];
      await pumpScreen(
        tester,
        const ExportPage(),
        overrides: [
          transactionsRepositoryProvider.overrideWith(
            (ref) => _FakeTransactionsRepository(database),
          ),
          khataRepositoryProvider.overrideWith(
            (ref) => _FakeKhataRepository(database),
          ),
          exportDirectoryProvider.overrideWith((ref) async => directory),
          fileSharerProvider.overrideWithValue((files, subject) async {
            shared.add([for (final f in files) f.path.split('/').last]);
          }),
        ],
      );

      await tester.tap(find.text('MyKhata'));
      await tester.pump();
      // File writes are real I/O, so let them finish outside FakeAsync.
      await tester.runAsync(() async {
        await tester.tap(find.text('Share CSV'));
        for (var i = 0; i < 20 && shared.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      expect(shared.single, ['transactions_20261111.csv']);

      await tester.tap(find.text('Transactions'));
      await tester.pump();
      final button = tester.widget<FilledButton>(
        find
            .descendant(
              of: find.ancestor(
                of: find.text('Share CSV'),
                matching: find.byType(Material),
              ),
              matching: find.byType(FilledButton),
            )
            .first,
      );
      expect(button.onPressed, isNull);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
