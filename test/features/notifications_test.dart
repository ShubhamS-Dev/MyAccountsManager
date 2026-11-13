import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/privacy_state.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/database/database_provider.dart';
import 'package:my_accounts_manager/core/time/today_provider.dart';
import 'package:my_accounts_manager/features/my_khata/data/khata_repository.dart';
import 'package:my_accounts_manager/features/my_khata/khata_providers.dart';
import 'package:my_accounts_manager/features/notifications/data/notification_preferences.dart';
import 'package:my_accounts_manager/features/notifications/domain/reminder_planner.dart';
import 'package:my_accounts_manager/features/notifications/notifications_providers.dart';
import 'package:my_accounts_manager/features/notifications/presentation/activity_center_page.dart';
import 'package:my_accounts_manager/features/notifications/presentation/notification_settings_page.dart';
import 'package:my_accounts_manager/features/settings/data/settings_repository.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';

const day = Duration.millisecondsPerDay;

/// 11 Nov 2026 as stored (UTC midnight).
final today = DateTime.utc(2026, 11, 11).millisecondsSinceEpoch;

KhataEntryItem khata({
  String id = 'e1',
  String person = 'Ravi',
  String direction = khataLent,
  int amount = 500000,
  int repaid = 0,
  int? dueDate,
}) => KhataEntryItem(
  entry: KhataEntryRow(
    id: id,
    personId: 'p-$person',
    direction: direction,
    amountPaise: amount,
    entryDate: today - 10 * day,
    dueDate: dueDate,
    createdAt: 0,
    updatedAt: 0,
  ),
  personName: person,
  repaidPaise: repaid,
);

TransactionHistoryItem scheduledTransaction({
  String id = 't1',
  String type = 'expense',
  int amount = 120000,
  required int date,
  String? recurringRuleId,
  String categoryName = 'Rent',
}) => TransactionHistoryItem(
  transaction: TransactionRow(
    id: id,
    accountId: 'a1',
    categoryId: 'c1',
    type: type,
    amountPaise: amount,
    transactionDate: date,
    createdAt: 0,
    updatedAt: 0,
    recurringRuleId: recurringRuleId,
  ),
  accountName: 'HDFC Savings',
  categoryName: categoryName,
);

List<PlannedReminder> plan({
  List<KhataEntryItem> entries = const [],
  List<TransactionHistoryItem> scheduled = const [],
  NotificationPreferences preferences = const NotificationPreferences(),
  DateTime? now,
}) => planReminders(
  khataEntries: entries,
  scheduledTransactions: scheduled,
  preferences: preferences,
  now: now ?? DateTime(2026, 11, 11, 8),
);

void main() {
  group('NotificationPreferences', () {
    test('defaults to on at 9:00 AM with amounts hidden', () {
      final preferences = NotificationPreferences.fromStorage(const {});
      expect(preferences.enabled, isTrue);
      expect(preferences.reminderMinutes, 540);
      expect(preferences.showAmounts, isFalse);
      expect(preferences.anyTypeEnabled, isTrue);
      expect(reminderTimeLabel(preferences.reminderMinutes), '9:00 AM');
    });

    test('reads stored values and rejects invalid times', () {
      final preferences = NotificationPreferences.fromStorage(const {
        notificationsEnabledKey: 'false',
        reminderMinutesKey: '1110',
        showAmountsKey: 'true',
        overdueSummaryKey: 'false',
      });
      expect(preferences.enabled, isFalse);
      expect(preferences.reminderHour, 18);
      expect(preferences.reminderMinute, 30);
      expect(preferences.showAmounts, isTrue);
      expect(preferences.overdueSummary, isFalse);
      expect(
        NotificationPreferences.fromStorage(const {
          reminderMinutesKey: '1440',
        }).reminderMinutes,
        defaultReminderMinutes,
      );
      expect(reminderTimeLabel(0), '12:00 AM');
      expect(reminderTimeLabel(12 * 60 + 5), '12:05 PM');
    });
  });

  group('planReminders', () {
    test('schedules the day before and the due date at the reminder time', () {
      final reminders = plan(
        entries: [khata(dueDate: today + 3 * day)],
        preferences: const NotificationPreferences(overdueSummary: false),
      );
      expect(reminders.map((r) => r.key), ['khata-before:e1', 'khata-due:e1']);
      expect(reminders[0].fireAt, DateTime(2026, 11, 13, 9));
      expect(reminders[1].fireAt, DateTime(2026, 11, 14, 9));
      expect(reminders[0].title, 'Due tomorrow');
      expect(reminders[1].title, 'Due today');
      expect(reminders[1].route, '/khata/entries/e1');
    });

    test('hides amounts unless the user turns them on', () {
      final entry = khata(
        dueDate: today + 3 * day,
        amount: 500000,
        repaid: 200000,
      );
      expect(plan(entries: [entry]).first.body, 'Collect from Ravi');
      final shown = plan(
        entries: [entry],
        preferences: const NotificationPreferences(showAmounts: true),
      );
      expect(shown.first.body, contains('3,000'));
      expect(
        khataReminderText(
          khata(direction: khataBorrowed, dueDate: today),
          showAmounts: false,
        ),
        'Pay Ravi',
      );
    });

    test(
      'skips settled entries, entries without a due date and past times',
      () {
        expect(
          plan(
            entries: [
              khata(id: 'settled', repaid: 500000, dueDate: today + 2 * day),
              khata(id: 'no-due'),
            ],
          ),
          isEmpty,
        );
        // Due today, but it is already 10:00: nothing left to fire today.
        final late = plan(
          entries: [khata(dueDate: today)],
          preferences: const NotificationPreferences(overdueSummary: false),
          now: DateTime(2026, 11, 11, 10),
        );
        expect(late, isEmpty);
      },
    );

    test('respects the master switch and each type switch', () {
      final entries = [khata(dueDate: today + 3 * day)];
      expect(
        plan(
          entries: entries,
          preferences: const NotificationPreferences(enabled: false),
        ),
        isEmpty,
      );
      expect(
        plan(
          entries: entries,
          preferences: const NotificationPreferences(
            khataDayBefore: false,
            overdueSummary: false,
          ),
        ).map((r) => r.key),
        ['khata-due:e1'],
      );
    });

    test('sends a daily overdue summary while entries stay overdue', () {
      final reminders = plan(
        entries: [
          khata(id: 'a', person: 'Ravi', dueDate: today - 2 * day),
          khata(
            id: 'b',
            person: 'Asha',
            direction: khataBorrowed,
            dueDate: today - day,
          ),
        ],
      );
      final summaries = reminders
          .where((r) => r.key.startsWith('khata-overdue:'))
          .toList();
      expect(summaries, hasLength(overdueSummaryDays));
      expect(summaries.first.fireAt, DateTime(2026, 11, 11, 9));
      expect(summaries.first.title, '2 MyKhata entries are overdue');
      expect(summaries.first.body, 'With Ravi and Asha');
      expect(summaries.first.route, '/activity');

      final withAmounts = plan(
        entries: [
          khata(id: 'a', dueDate: today - day, amount: 100000),
          khata(
            id: 'b',
            direction: khataBorrowed,
            dueDate: today - day,
            amount: 50000,
          ),
        ],
        preferences: const NotificationPreferences(showAmounts: true),
      ).first;
      expect(withAmounts.body, contains('to collect'));
      expect(withAmounts.body, contains('to pay'));
    });

    test('starts the summary on the day after an upcoming due date', () {
      final summaries = plan(
        entries: [khata(dueDate: today + 2 * day)],
      ).where((r) => r.key.startsWith('khata-overdue:')).toList();
      expect(summaries.first.fireAt, DateTime(2026, 11, 14, 9));
      expect(summaries.first.title, '1 MyKhata entry is overdue');
    });

    test('reminds on the day a scheduled transaction starts counting', () {
      final reminders = plan(
        scheduled: [scheduledTransaction(date: today + 5 * day)],
      );
      expect(reminders.single.key, 'transaction:t1');
      expect(reminders.single.fireAt, DateTime(2026, 11, 16, 9));
      expect(reminders.single.title, 'Scheduled expense counts from today');
      expect(reminders.single.body, 'Rent · HDFC Savings');
      expect(reminders.single.route, '/transaction/t1');
      final shown = plan(
        scheduled: [scheduledTransaction(date: today + 5 * day)],
        preferences: const NotificationPreferences(showAmounts: true),
      );
      expect(shown.single.body, startsWith('₹'));
    });

    test(
      'says recurring when the scheduled transaction is part of a series',
      () {
        final reminders = plan(
          scheduled: [
            scheduledTransaction(date: today + 5 * day, recurringRuleId: 'r1'),
            scheduledTransaction(
              id: 't2',
              type: 'income',
              date: today + 6 * day,
              recurringRuleId: 'r2',
            ),
          ],
        );
        expect(reminders.map((r) => r.title), [
          'Recurring expense added today',
          'Recurring income added today',
        ]);
      },
    );

    test('orders nearest first and caps the pending count', () {
      final reminders = plan(
        scheduled: [
          for (var i = 1; i <= 100; i++)
            scheduledTransaction(id: 't$i', date: today + i * day),
        ],
      );
      expect(reminders, hasLength(maxPlannedReminders));
      expect(reminders.first.key, 'transaction:t1');
      for (var i = 1; i < reminders.length; i++) {
        expect(reminders[i].fireAt.isAfter(reminders[i - 1].fireAt), isTrue);
      }
    });

    test('derives stable, positive, distinct notification ids', () {
      final a = PlannedReminder(
        key: 'khata-due:e1',
        fireAt: DateTime(2026),
        title: '',
        body: '',
        route: '/',
      );
      final b = PlannedReminder(
        key: 'khata-before:e1',
        fireAt: DateTime(2026),
        title: '',
        body: '',
        route: '/',
      );
      expect(a.id, a.id);
      expect(a.id, isNot(b.id));
      expect(a.id, greaterThanOrEqualTo(0));
      expect(a.id, lessThanOrEqualTo(0x7fffffff));
    });
  });

  group('ActivityDigest', () {
    test('groups overdue, due soon and scheduled items', () {
      final digest = ActivityDigest.build(
        khataEntries: [
          khata(id: 'late', dueDate: today - 3 * day),
          khata(id: 'today', dueDate: today),
          khata(id: 'week', dueDate: today + 7 * day),
          khata(id: 'later', dueDate: today + 8 * day),
          khata(id: 'settled', dueDate: today - day, repaid: 500000),
        ],
        scheduledTransactions: [
          scheduledTransaction(id: 'late-tx', date: today + 9 * day),
          scheduledTransaction(id: 'soon-tx', date: today + 2 * day),
        ],
        today: today,
      );
      expect(digest.overdue.map((i) => i.entry.id), ['late']);
      expect(digest.dueSoon.map((i) => i.entry.id), ['today', 'week']);
      expect(digest.scheduled.map((i) => i.transaction.id), [
        'soon-tx',
        'late-tx',
      ]);
      expect(digest.attentionCount, 2);
      expect(digest.isEmpty, isFalse);
    });

    test('labels due dates relative to today', () {
      expect(dueLabel(today - 3 * day, today), 'Overdue by 3 days');
      expect(dueLabel(today - day, today), 'Overdue by 1 day');
      expect(dueLabel(today, today), 'Due today');
      expect(dueLabel(today + day, today), 'Due tomorrow');
      expect(dueLabel(today + 3 * day, today), 'Due 14 Nov 2026');
    });
  });

  group('screens', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    Future<void> settle(WidgetTester tester) async {
      // Drift queries complete on real async; then let frames catch up.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> pumpScreen(
      WidgetTester tester,
      Widget screen, {
      List<KhataEntryItem> entries = const [],
      List<TransactionHistoryItem> scheduled = const [],
      bool livePreferences = false,
    }) async {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        // Drift closes query streams on a zero-length timer.
        await tester.pump(const Duration(milliseconds: 1));
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
            khataEntriesProvider.overrideWith(
              (ref, personId) => Stream.value(entries),
            ),
            scheduledTransactionsProvider.overrideWith(
              (ref) => Stream.value(scheduled),
            ),
            if (!livePreferences)
              notificationPreferencesProvider.overrideWith(
                (ref) => Stream.value(const NotificationPreferences()),
              ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            home: screen,
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('Activity center shows an empty state', (tester) async {
      await pumpScreen(tester, const ActivityCenterPage());
      expect(find.text("You're all caught up"), findsOneWidget);
    });

    testWidgets('Activity center lists overdue, due soon and scheduled items', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const ActivityCenterPage(),
        entries: [
          khata(id: 'a', person: 'Ravi', dueDate: today - 2 * day),
          khata(
            id: 'b',
            person: 'Asha',
            direction: khataBorrowed,
            dueDate: today + day,
          ),
        ],
        scheduled: [
          scheduledTransaction(
            date: today + 4 * day,
            categoryName: 'Groceries',
          ),
        ],
      );
      expect(find.text('Overdue (1)'), findsOneWidget);
      expect(find.text('Collect from Ravi'), findsOneWidget);
      expect(find.text('Overdue by 2 days'), findsOneWidget);
      expect(find.text('Due in the next 7 days (1)'), findsOneWidget);
      expect(find.text('Pay Asha'), findsOneWidget);
      expect(find.text('Due tomorrow'), findsOneWidget);
      expect(find.text('Scheduled transactions (1)'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      final scheduledTile = find.ancestor(
        of: find.text('Groceries'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(
          of: scheduledTile,
          matching: find.byIcon(Icons.shopping_basket_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: scheduledTile,
          matching: find.byIcon(Icons.north_east_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('Notification settings save each preference', (tester) async {
      await pumpScreen(
        tester,
        const NotificationSettingsPage(),
        livePreferences: true,
      );
      expect(find.text('9:00 AM'), findsOneWidget);

      await tester.tap(find.text('Show amounts'));
      await settle(tester);
      await tester.tap(find.text('Daily overdue summary'));
      await settle(tester);

      final stored = await tester.runAsync(
        () => SettingsRepository(
          database,
        ).watchValuesWithPrefix(notificationSettingPrefix).first,
      );
      expect(stored![showAmountsKey], 'true');
      expect(stored[overdueSummaryKey], 'false');

      await tester.tap(find.text('Reminders'));
      await settle(tester);
      final switches = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switches.first.value, isFalse);
      expect(switches.skip(1).every((tile) => tile.onChanged == null), isTrue);

      // This screen reads live Drift streams; close them inside the test so
      // their cleanup timer runs before the pending-timer check.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
