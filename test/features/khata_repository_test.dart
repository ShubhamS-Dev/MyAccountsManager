import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/features/accounts/data/accounts_repository.dart';
import 'package:my_accounts_manager/features/my_khata/data/khata_repository.dart';

void main() {
  late AppDatabase database;
  late KhataRepository khata;
  final day1 = DateTime.utc(2026, 11, 1).millisecondsSinceEpoch;
  final day5 = DateTime.utc(2026, 11, 5).millisecondsSinceEpoch;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    khata = KhataRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<String> lend(String personId, int paise) => khata.createEntry(
    personId: personId,
    direction: khataLent,
    amountPaise: paise,
    entryDate: day1,
  );

  test('summarises receivable and payable per person and overall', () async {
    final asha = await khata.createPerson(name: '  Asha  ');
    final ravi = await khata.createPerson(name: 'Ravi', phone: '98765 43210');
    await lend(asha, 50000);
    await khata.createEntry(
      personId: asha,
      direction: khataBorrowed,
      amountPaise: 12050,
      entryDate: day1,
    );
    await khata.createEntry(
      personId: ravi,
      direction: khataBorrowed,
      amountPaise: 200000,
      entryDate: day1,
    );

    final summaries = await khata.watchPeopleSummaries().first;
    expect(summaries.map((s) => s.person.name), ['Asha', 'Ravi']);
    expect(summaries.first.receivablePaise, 50000);
    expect(summaries.first.payablePaise, 12050);
    expect(summaries.first.netPaise, 37950);
    expect(summaries.last.netPaise, -200000);

    final totals = KhataTotals.fromSummaries(summaries);
    expect(totals.receivablePaise, 50000);
    expect(totals.payablePaise, 212050);
    expect(totals.netPaise, -162050);
    expect(totals.openPeople, 2);
  });

  test('records partial and full repayments and settles the entry', () async {
    final person = await khata.createPerson(name: 'Asha');
    final entry = await lend(person, 100050);

    await khata.recordRepayment(
      entryId: entry,
      amountPaise: 50000,
      repaymentDate: day5,
    );
    var item = (await khata.watchEntry(entry).first)!;
    expect(item.repaidPaise, 50000);
    expect(item.outstandingPaise, 50050);
    expect(item.isSettled, isFalse);

    await khata.recordRepayment(
      entryId: entry,
      amountPaise: 50050,
      repaymentDate: day5,
    );
    item = (await khata.watchEntry(entry).first)!;
    expect(item.isSettled, isTrue);
    final summary = (await khata.watchPeopleSummaries().first).single;
    expect(summary.isSettled, isTrue);
    expect(summary.receivablePaise, 0);
  });

  test('rejects overpayment and repayments on settled entries', () async {
    final person = await khata.createPerson(name: 'Asha');
    final entry = await lend(person, 10000);

    expect(
      () => khata.recordRepayment(
        entryId: entry,
        amountPaise: 10001,
        repaymentDate: day5,
      ),
      throwsStateError,
    );
    await khata.recordRepayment(
      entryId: entry,
      amountPaise: 10000,
      repaymentDate: day5,
    );
    expect(
      () => khata.recordRepayment(
        entryId: entry,
        amountPaise: 1,
        repaymentDate: day5,
      ),
      throwsStateError,
    );
  });

  test('rejects a repayment dated before the entry', () async {
    final person = await khata.createPerson(name: 'Asha');
    final entry = await khata.createEntry(
      personId: person,
      direction: khataLent,
      amountPaise: 10000,
      entryDate: day5,
    );
    expect(
      () => khata.recordRepayment(
        entryId: entry,
        amountPaise: 100,
        repaymentDate: day1,
      ),
      throwsStateError,
    );
  });

  test(
    'reopens a settled entry only by removing its latest repayment',
    () async {
      final person = await khata.createPerson(name: 'Asha');
      final entry = await lend(person, 10000);
      final partial = await khata.recordRepayment(
        entryId: entry,
        amountPaise: 4000,
        repaymentDate: day1,
      );
      final last = await khata.recordRepayment(
        entryId: entry,
        amountPaise: 6000,
        repaymentDate: day5,
      );
      expect((await khata.watchEntry(entry).first)!.isSettled, isTrue);
      expect(await khata.latestRepaymentId(entry), last);

      expect(() => khata.deleteRepayment(partial), throwsStateError);

      await khata.deleteRepayment(last);
      final reopened = (await khata.watchEntry(entry).first)!;
      expect(reopened.isSettled, isFalse);
      expect(reopened.repaidPaise, 4000);

      await khata.deleteRepayment(partial);
      expect((await khata.watchEntry(entry).first)!.repaidPaise, 0);
    },
  );

  test('guards entry edits and deletion against repaid amounts', () async {
    final person = await khata.createPerson(name: 'Asha');
    final entry = await lend(person, 10000);
    await khata.recordRepayment(
      entryId: entry,
      amountPaise: 6000,
      repaymentDate: day5,
    );

    expect(
      () =>
          khata.updateEntry(entryId: entry, amountPaise: 5000, entryDate: day1),
      throwsStateError,
    );
    expect(() => khata.deleteEntry(entry), throwsStateError);

    await khata.updateEntry(
      entryId: entry,
      amountPaise: 12000,
      entryDate: day1,
      note: 'Rent share',
    );
    final item = (await khata.watchEntry(entry).first)!;
    expect(item.entry.amountPaise, 12000);
    expect(item.outstandingPaise, 6000);
    expect(item.entry.note, 'Rent share');
  });

  test('soft-deletes entries without repayments', () async {
    final person = await khata.createPerson(name: 'Asha');
    final entry = await lend(person, 10000);
    await khata.deleteEntry(entry);

    expect(await khata.watchEntry(entry).first, isNull);
    expect(await khata.watchEntries(personId: person).first, isEmpty);
    final stored = await (database.select(
      database.khataEntries,
    )..where((row) => row.id.equals(entry))).getSingle();
    expect(stored.deletedAt, isNotNull);
  });

  test('removes a person whose entries were all deleted', () async {
    final person = await khata.createPerson(name: 'Asha');
    final entry = await lend(person, 10000);
    final repayment = await khata.recordRepayment(
      entryId: entry,
      amountPaise: 1000,
      repaymentDate: day5,
    );
    await khata.deleteRepayment(repayment);
    await khata.deleteEntry(entry);

    await khata.deletePerson(person);

    expect(await khata.watchPeopleSummaries().first, isEmpty);
    expect(await database.select(database.khataEntries).get(), isEmpty);
    expect(await database.select(database.khataRepayments).get(), isEmpty);
  });

  test('removes a person only when they have no ledger history', () async {
    final withHistory = await khata.createPerson(name: 'Asha');
    final empty = await khata.createPerson(name: 'Ravi');
    await lend(withHistory, 100);

    expect(() => khata.deletePerson(withHistory), throwsStateError);
    await khata.deletePerson(empty);
    final names = (await khata.watchPeopleSummaries().first).map(
      (s) => s.person.name,
    );
    expect(names, ['Asha']);
  });

  test('validates names, amounts, directions, and due dates', () async {
    expect(() => khata.createPerson(name: '   '), throwsArgumentError);
    final person = await khata.createPerson(name: 'Asha');
    expect(
      () => khata.createEntry(
        personId: person,
        direction: khataLent,
        amountPaise: 0,
        entryDate: day1,
      ),
      throwsArgumentError,
    );
    expect(
      () => khata.createEntry(
        personId: person,
        direction: 'gift',
        amountPaise: 100,
        entryDate: day1,
      ),
      throwsArgumentError,
    );
    expect(
      () => khata.createEntry(
        personId: person,
        direction: khataLent,
        amountPaise: 100,
        entryDate: day5,
        dueDate: day1,
      ),
      throwsArgumentError,
    );
  });

  test('never changes regular Account balances', () async {
    final accounts = AccountsRepository(database);
    final accountId = await accounts.createAccount(
      name: 'Savings',
      openingBalancePaise: 500000,
    );
    final asOf = DateTime.utc(2026, 12, 31).millisecondsSinceEpoch;
    final before = await accounts
        .watchTotalActiveBalancePaise(asOfDate: asOf)
        .first;

    final person = await khata.createPerson(name: 'Asha');
    final entry = await lend(person, 250000);
    await khata.recordRepayment(
      entryId: entry,
      amountPaise: 100000,
      repaymentDate: day5,
    );

    expect(
      await accounts.watchTotalActiveBalancePaise(asOfDate: asOf).first,
      before,
    );
    expect(
      await accounts.calculateBalancePaise(
        accountId: accountId,
        asOfDate: asOf,
      ),
      500000,
    );
  });

  test('emits updated summaries reactively after a repayment', () async {
    final person = await khata.createPerson(name: 'Asha');
    final entry = await lend(person, 10000);

    final emissions = khata
        .watchPeopleSummaries()
        .map((rows) => rows.single.receivablePaise)
        .take(2)
        .toList();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await khata.recordRepayment(
      entryId: entry,
      amountPaise: 2500,
      repaymentDate: day5,
    );

    expect(await emissions, [10000, 7500]);
  });
}
