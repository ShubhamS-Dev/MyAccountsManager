import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';
import 'package:my_accounts_manager/features/recurring/data/recurring_repository.dart';
import 'package:my_accounts_manager/features/recurring/domain/recurrence.dart';
import 'package:my_accounts_manager/features/transactions/data/transactions_repository.dart';

int day(int year, int month, int date) =>
    DateTime.utc(year, month, date).millisecondsSinceEpoch;

void main() {
  group('occurrenceDate', () {
    test('monthly keeps the start day, clamped to short months', () {
      final start = day(2026, 1, 31);
      expect(
        occurrenceDate(start, RecurringFrequency.monthly, 1),
        day(2026, 2, 28),
      );
      expect(
        occurrenceDate(start, RecurringFrequency.monthly, 2),
        day(2026, 3, 31),
      );
      expect(
        occurrenceDate(start, RecurringFrequency.monthly, 12),
        day(2027, 1, 31),
      );
    });

    test('daily, weekly and leap-day yearly', () {
      final start = day(2028, 2, 29);
      expect(
        occurrenceDate(start, RecurringFrequency.daily, 2),
        day(2028, 3, 2),
      );
      expect(
        occurrenceDate(start, RecurringFrequency.weekly, 1),
        day(2028, 3, 7),
      );
      expect(
        occurrenceDate(start, RecurringFrequency.yearly, 1),
        day(2029, 2, 28),
      );
      expect(
        occurrenceDate(start, RecurringFrequency.yearly, 4),
        day(2032, 2, 29),
      );
    });

    test('summary text', () {
      expect(
        recurrenceSummary(RecurringFrequency.monthly, day(2026, 11, 1)),
        'Every month on day 1',
      );
      expect(
        recurrenceSummary(RecurringFrequency.weekly, day(2026, 11, 11)),
        'Every week on Wednesday',
      );
    });
  });

  group('RecurringRepository', () {
    late AppDatabase database;
    late TransactionsRepository transactions;
    late RecurringRepository recurring;
    late String accountId;
    late String categoryId;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      transactions = TransactionsRepository(database);
      recurring = RecurringRepository(database, transactions);
      accountId = await AccountsRepository(
        database,
      ).createAccount(name: 'Bank');
      categoryId =
          (await (database.select(database.categories)
                    ..where((row) => row.name.equals('Housing & Utilities')))
                  .getSingle())
              .id;
    });

    tearDown(() => database.close());

    Future<String> rent(int date) => transactions.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: 'expense',
      amountPaise: 2500000,
      transactionDate: date,
      note: 'Rent',
    );

    Future<List<TransactionRow>> occurrences(String ruleId) =>
        (database.select(database.transactions)
              ..where((row) => row.recurringRuleId.equals(ruleId))
              ..orderBy([(row) => OrderingTerm.asc(row.transactionDate)]))
            .get();

    test('keeps exactly one upcoming occurrence scheduled', () async {
      final first = await rent(day(2026, 11, 1));
      final ruleId = await recurring.createFromTransaction(
        transactionId: first,
        frequency: RecurringFrequency.monthly,
        today: day(2026, 11, 11),
      );

      final rows = await occurrences(ruleId);
      expect(rows.map((row) => row.transactionDate), [
        day(2026, 11, 1),
        day(2026, 12, 1),
      ]);
      expect(rows.every((row) => row.note == 'Rent'), isTrue);

      // Re-running the same day changes nothing.
      expect(await recurring.materializeDue(today: day(2026, 11, 11)), 0);
    });

    test('catches up missed months after time away', () async {
      final first = await rent(day(2026, 11, 1));
      final ruleId = await recurring.createFromTransaction(
        transactionId: first,
        frequency: RecurringFrequency.monthly,
        today: day(2026, 11, 11),
      );

      final created = await recurring.materializeDue(today: day(2027, 2, 15));
      expect(created, 3); // Jan and Feb now, Mar scheduled.
      expect((await occurrences(ruleId)).last.transactionDate, day(2027, 3, 1));
    });

    test('a backdated start fills in past dates', () async {
      final first = await rent(day(2026, 9, 1));
      final ruleId = await recurring.createFromTransaction(
        transactionId: first,
        frequency: RecurringFrequency.monthly,
        today: day(2026, 11, 11),
      );
      expect((await occurrences(ruleId)).length, 4); // Sep, Oct, Nov, Dec.
    });

    test('stops at the end date', () async {
      final first = await rent(day(2026, 11, 1));
      final ruleId = await recurring.createFromTransaction(
        transactionId: first,
        frequency: RecurringFrequency.monthly,
        today: day(2026, 11, 11),
        endDate: day(2027, 1, 1),
      );
      await recurring.materializeDue(today: day(2027, 6, 1));
      expect((await occurrences(ruleId)).length, 3);
      final item = (await recurring.watchRules().first).single;
      expect(item.ended, isTrue);
    });

    test(
      'pause removes the upcoming occurrence; resume skips the gap',
      () async {
        final first = await rent(day(2026, 11, 1));
        final ruleId = await recurring.createFromTransaction(
          transactionId: first,
          frequency: RecurringFrequency.monthly,
          today: day(2026, 11, 11),
        );
        await recurring.pause(ruleId, today: day(2026, 11, 11));
        expect((await occurrences(ruleId)).length, 1);
        expect(await recurring.materializeDue(today: day(2027, 3, 5)), 0);

        await recurring.resume(ruleId, today: day(2027, 3, 5));
        expect((await occurrences(ruleId)).map((row) => row.transactionDate), [
          day(2026, 11, 1),
          day(2027, 4, 1),
        ]);
      },
    );

    test('update re-creates the upcoming occurrence with new values', () async {
      final first = await rent(day(2026, 11, 1));
      final ruleId = await recurring.createFromTransaction(
        transactionId: first,
        frequency: RecurringFrequency.monthly,
        today: day(2026, 11, 11),
      );
      await recurring.update(
        ruleId,
        amountPaise: 2700000,
        note: 'Rent (revised)',
        endDate: null,
        today: day(2026, 11, 11),
      );
      final rows = await occurrences(ruleId);
      expect(rows.length, 2);
      expect(rows.first.amountPaise, 2500000);
      expect(rows.last.amountPaise, 2700000);
      expect(rows.last.note, 'Rent (revised)');
    });

    test(
      'delete keeps past occurrences and removes the upcoming one',
      () async {
        final first = await rent(day(2026, 11, 1));
        final ruleId = await recurring.createFromTransaction(
          transactionId: first,
          frequency: RecurringFrequency.monthly,
          today: day(2026, 11, 11),
        );
        await recurring.delete(ruleId, today: day(2026, 11, 11));
        expect((await occurrences(ruleId)).length, 1);
        expect(await recurring.watchRules().first, isEmpty);
        expect(await recurring.materializeDue(today: day(2027, 1, 5)), 0);
      },
    );

    test(
      'an archived Account blocks new occurrences without failing',
      () async {
        final first = await rent(day(2026, 11, 1));
        final ruleId = await recurring.createFromTransaction(
          transactionId: first,
          frequency: RecurringFrequency.monthly,
          today: day(2026, 11, 11),
        );
        await AccountsRepository(database).archiveAccount(accountId);
        expect(await recurring.materializeDue(today: day(2027, 1, 5)), 0);
        final item = (await recurring.watchRules().first).single;
        expect(item.blocked, isTrue);
        expect((await occurrences(ruleId)).length, 2);
      },
    );
  });
}
