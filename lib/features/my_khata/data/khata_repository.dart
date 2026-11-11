import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

const khataLent = 'lent';
const khataBorrowed = 'borrowed';

/// Largest amount accepted by money inputs: 12 whole-rupee digits.
const khataMaxAmountPaise = 99999999999999;

class KhataPersonSummary {
  const KhataPersonSummary({
    required this.person,
    required this.receivablePaise,
    required this.payablePaise,
    required this.openEntries,
    required this.totalEntries,
    this.lastEntryDate,
  });

  final KhataPersonRow person;

  /// Outstanding amount this person owes you.
  final int receivablePaise;

  /// Outstanding amount you owe this person.
  final int payablePaise;
  final int openEntries;
  final int totalEntries;
  final int? lastEntryDate;

  /// Positive: you will get money. Negative: you will give money.
  int get netPaise => receivablePaise - payablePaise;
  bool get isSettled => openEntries == 0;
}

class KhataEntryItem {
  const KhataEntryItem({
    required this.entry,
    required this.personName,
    required this.repaidPaise,
  });

  final KhataEntryRow entry;
  final String personName;
  final int repaidPaise;

  int get outstandingPaise => entry.amountPaise - repaidPaise;
  bool get isSettled => outstandingPaise <= 0;
  bool get isLent => entry.direction == khataLent;
}

class KhataTotals {
  const KhataTotals({
    required this.receivablePaise,
    required this.payablePaise,
    required this.people,
    required this.openPeople,
  });

  final int receivablePaise;
  final int payablePaise;
  final int people;
  final int openPeople;

  int get netPaise => receivablePaise - payablePaise;

  static KhataTotals fromSummaries(List<KhataPersonSummary> summaries) {
    var receivable = 0;
    var payable = 0;
    var open = 0;
    for (final summary in summaries) {
      receivable += summary.receivablePaise;
      payable += summary.payablePaise;
      if (!summary.isSettled) open++;
    }
    return KhataTotals(
      receivablePaise: receivable,
      payablePaise: payable,
      people: summaries.length,
      openPeople: open,
    );
  }
}

/// Independent MyKhata ledger. Never reads or writes Account tables.
class KhataRepository {
  KhataRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  static const _repaidSubquery = '''
    LEFT JOIN (
      SELECT entry_id, SUM(amount_paise) AS repaid
      FROM khata_repayments
      WHERE deleted_at IS NULL
      GROUP BY entry_id
    ) r ON r.entry_id = e.id
  ''';

  Stream<List<KhataPersonSummary>> watchPeopleSummaries() {
    return _database
        .customSelect(
          '''
      SELECT p.*,
        COALESCE(SUM(CASE WHEN e.direction = 'lent'
          THEN e.amount_paise - COALESCE(r.repaid, 0) END), 0) AS receivable,
        COALESCE(SUM(CASE WHEN e.direction = 'borrowed'
          THEN e.amount_paise - COALESCE(r.repaid, 0) END), 0) AS payable,
        COUNT(CASE WHEN e.amount_paise > COALESCE(r.repaid, 0)
          THEN 1 END) AS open_entries,
        COUNT(e.id) AS total_entries,
        MAX(e.entry_date) AS last_entry_date
      FROM khata_people p
      LEFT JOIN khata_entries e
        ON e.person_id = p.id AND e.deleted_at IS NULL
      $_repaidSubquery
      GROUP BY p.id
      ORDER BY p.name COLLATE NOCASE
      ''',
          readsFrom: {
            _database.khataPeople,
            _database.khataEntries,
            _database.khataRepayments,
          },
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              KhataPersonSummary(
                person: _database.khataPeople.map(row.data),
                receivablePaise: row.read<int>('receivable'),
                payablePaise: row.read<int>('payable'),
                openEntries: row.read<int>('open_entries'),
                totalEntries: row.read<int>('total_entries'),
                lastEntryDate: row.readNullable<int>('last_entry_date'),
              ),
          ],
        );
  }

  Stream<List<KhataEntryItem>> watchEntries({String? personId}) {
    return _database
        .customSelect(
          '''
      SELECT e.*, p.name AS person_name, COALESCE(r.repaid, 0) AS repaid
      FROM khata_entries e
      INNER JOIN khata_people p ON p.id = e.person_id
      $_repaidSubquery
      WHERE e.deleted_at IS NULL
        ${personId == null ? '' : 'AND e.person_id = ?'}
      ORDER BY e.entry_date DESC, e.created_at DESC
      ''',
          variables: [if (personId != null) Variable.withString(personId)],
          readsFrom: {
            _database.khataPeople,
            _database.khataEntries,
            _database.khataRepayments,
          },
        )
        .watch()
        .map((rows) => rows.map(_entryItem).toList());
  }

  Stream<KhataEntryItem?> watchEntry(String entryId) {
    return _database
        .customSelect(
          '''
      SELECT e.*, p.name AS person_name, COALESCE(r.repaid, 0) AS repaid
      FROM khata_entries e
      INNER JOIN khata_people p ON p.id = e.person_id
      $_repaidSubquery
      WHERE e.id = ? AND e.deleted_at IS NULL
      ''',
          variables: [Variable.withString(entryId)],
          readsFrom: {
            _database.khataPeople,
            _database.khataEntries,
            _database.khataRepayments,
          },
        )
        .watch()
        .map((rows) => rows.isEmpty ? null : _entryItem(rows.single));
  }

  Stream<KhataPersonRow?> watchPerson(String personId) {
    return (_database.select(
      _database.khataPeople,
    )..where((row) => row.id.equals(personId))).watchSingleOrNull();
  }

  Stream<List<KhataRepaymentRow>> watchRepayments(String entryId) {
    return (_database.select(_database.khataRepayments)
          ..where((row) => row.entryId.equals(entryId))
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([
            (row) => OrderingTerm.desc(row.repaymentDate),
            (row) => OrderingTerm.desc(row.createdAt),
          ]))
        .watch();
  }

  KhataEntryItem _entryItem(QueryRow row) => KhataEntryItem(
    entry: _database.khataEntries.map(row.data),
    personName: row.read<String>('person_name'),
    repaidPaise: row.read<int>('repaid'),
  );

  Future<String> createPerson({
    required String name,
    String? phone,
    String? note,
    int? colorValue,
  }) async {
    final normalizedName = _requireName(name);
    final now = _now();
    final id = _uuid.v4();
    await _database
        .into(_database.khataPeople)
        .insert(
          KhataPeopleCompanion.insert(
            id: id,
            name: normalizedName,
            phone: Value(_optional(phone)),
            note: Value(_optional(note)),
            colorValue: Value(colorValue),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updatePerson({
    required String personId,
    required String name,
    String? phone,
    String? note,
    int? colorValue,
  }) async {
    final normalizedName = _requireName(name);
    final changed =
        await (_database.update(
          _database.khataPeople,
        )..where((row) => row.id.equals(personId))).write(
          KhataPeopleCompanion(
            name: Value(normalizedName),
            phone: Value(_optional(phone)),
            note: Value(_optional(note)),
            colorValue: Value(colorValue),
            updatedAt: Value(_now()),
          ),
        );
    if (changed == 0) throw StateError('Person not found.');
  }

  /// Deletes a person only when they have no active ledger entries.
  ///
  /// Entries the user already deleted (and their repayments) are purged with
  /// the person, because they can no longer be shown without them.
  Future<void> deletePerson(String personId) {
    return _database.transaction(() async {
      final active =
          await (_database.select(_database.khataEntries)
                ..where(
                  (row) =>
                      row.personId.equals(personId) & row.deletedAt.isNull(),
                )
                ..limit(1))
              .get();
      if (active.isNotEmpty) {
        throw StateError(
          'This person has ledger entries and cannot be removed.',
        );
      }
      final deletedEntryIds = _database.selectOnly(_database.khataEntries)
        ..addColumns([_database.khataEntries.id])
        ..where(_database.khataEntries.personId.equals(personId));
      await (_database.delete(
        _database.khataRepayments,
      )..where((row) => row.entryId.isInQuery(deletedEntryIds))).go();
      await (_database.delete(
        _database.khataEntries,
      )..where((row) => row.personId.equals(personId))).go();
      await (_database.delete(
        _database.khataPeople,
      )..where((row) => row.id.equals(personId))).go();
    });
  }

  Future<String> createEntry({
    required String personId,
    required String direction,
    required int amountPaise,
    required int entryDate,
    int? dueDate,
    String? note,
  }) {
    _requireDirection(direction);
    _requireAmount(amountPaise);
    _requireDueDate(entryDate, dueDate);
    return _database.transaction(() async {
      final person = await (_database.select(
        _database.khataPeople,
      )..where((row) => row.id.equals(personId))).getSingleOrNull();
      if (person == null) throw StateError('Select a person first.');
      final now = _now();
      final id = _uuid.v4();
      await _database
          .into(_database.khataEntries)
          .insert(
            KhataEntriesCompanion.insert(
              id: id,
              personId: personId,
              direction: direction,
              amountPaise: amountPaise,
              note: Value(_optionalNote(note)),
              entryDate: entryDate,
              dueDate: Value(dueDate),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  /// Updates editable entry fields. The amount cannot drop below what has
  /// already been repaid, and settled entries stay settled.
  Future<void> updateEntry({
    required String entryId,
    required int amountPaise,
    required int entryDate,
    int? dueDate,
    String? note,
  }) {
    _requireAmount(amountPaise);
    _requireDueDate(entryDate, dueDate);
    return _database.transaction(() async {
      final current = await _requireActiveEntry(entryId);
      final repaid = await _repaidPaise(entryId);
      if (repaid >= current.amountPaise) {
        throw StateError('Settled entries cannot be edited.');
      }
      if (amountPaise < repaid) {
        throw StateError(
          'Amount cannot be less than the amount already repaid.',
        );
      }
      if (amountPaise == repaid) {
        throw StateError(
          'Use Record repayment to settle an entry instead of editing it.',
        );
      }
      await (_database.update(
        _database.khataEntries,
      )..where((row) => row.id.equals(entryId))).write(
        KhataEntriesCompanion(
          amountPaise: Value(amountPaise),
          entryDate: Value(entryDate),
          dueDate: Value(dueDate),
          note: Value(_optionalNote(note)),
          updatedAt: Value(_now()),
        ),
      );
    });
  }

  /// Soft-deletes an entry that has no repayments recorded against it.
  Future<void> deleteEntry(String entryId) {
    return _database.transaction(() async {
      await _requireActiveEntry(entryId);
      if (await _repaidPaise(entryId) > 0) {
        throw StateError(
          'Entries with repayments cannot be deleted. Remove the repayments first.',
        );
      }
      final now = _now();
      await (_database.update(
        _database.khataEntries,
      )..where((row) => row.id.equals(entryId))).write(
        KhataEntriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  /// Records a repayment. Overpayment is rejected.
  Future<String> recordRepayment({
    required String entryId,
    required int amountPaise,
    required int repaymentDate,
    String? note,
  }) {
    _requireAmount(amountPaise);
    return _database.transaction(() async {
      final entry = await _requireActiveEntry(entryId);
      final outstanding = entry.amountPaise - await _repaidPaise(entryId);
      if (outstanding <= 0) {
        throw StateError('This entry is already settled.');
      }
      if (amountPaise > outstanding) {
        throw StateError('Repayment cannot exceed the outstanding amount.');
      }
      if (repaymentDate < entry.entryDate) {
        throw StateError('Repayment date cannot be before the entry date.');
      }
      final now = _now();
      final id = _uuid.v4();
      await _database
          .into(_database.khataRepayments)
          .insert(
            KhataRepaymentsCompanion.insert(
              id: id,
              entryId: entryId,
              amountPaise: amountPaise,
              note: Value(_optionalNote(note)),
              repaymentDate: repaymentDate,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  /// Removes a repayment. On a settled entry only the most recent repayment
  /// can be removed, which reopens the entry; this is how a mistaken
  /// settlement is undone.
  Future<void> deleteRepayment(String repaymentId) {
    return _database.transaction(() async {
      final repayment =
          await (_database.select(_database.khataRepayments)
                ..where((row) => row.id.equals(repaymentId))
                ..where((row) => row.deletedAt.isNull()))
              .getSingleOrNull();
      if (repayment == null) throw StateError('Repayment not found.');
      final entry = await _requireActiveEntry(repayment.entryId);
      if (await _repaidPaise(entry.id) >= entry.amountPaise) {
        final latest = await latestRepaymentId(entry.id);
        if (latest != repaymentId) {
          throw StateError(
            'Only the most recent repayment can be removed from a settled entry.',
          );
        }
      }
      final now = _now();
      await (_database.update(
        _database.khataRepayments,
      )..where((row) => row.id.equals(repaymentId))).write(
        KhataRepaymentsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  /// Every active repayment on an active entry, oldest first, optionally for
  /// one person (export and statements).
  Future<List<KhataRepaymentRow>> activeRepayments({String? personId}) {
    final query =
        _database.select(_database.khataRepayments).join([
            innerJoin(
              _database.khataEntries,
              _database.khataEntries.id.equalsExp(
                _database.khataRepayments.entryId,
              ),
            ),
          ])
          ..where(_database.khataRepayments.deletedAt.isNull())
          ..where(_database.khataEntries.deletedAt.isNull())
          ..orderBy([
            OrderingTerm.asc(_database.khataRepayments.repaymentDate),
            OrderingTerm.asc(_database.khataRepayments.createdAt),
          ]);
    if (personId != null) {
      query.where(_database.khataEntries.personId.equals(personId));
    }
    return query.map((row) => row.readTable(_database.khataRepayments)).get();
  }

  /// The most recently recorded active repayment for [entryId], if any.
  Future<String?> latestRepaymentId(String entryId) async {
    final row =
        await (_database.select(_database.khataRepayments)
              ..where((r) => r.entryId.equals(entryId) & r.deletedAt.isNull())
              ..orderBy([
                (r) => OrderingTerm.desc(r.createdAt),
                (r) => OrderingTerm.desc(r.repaymentDate),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  Future<KhataEntryRow> _requireActiveEntry(String entryId) async {
    final entry =
        await (_database.select(_database.khataEntries)
              ..where((row) => row.id.equals(entryId))
              ..where((row) => row.deletedAt.isNull()))
            .getSingleOrNull();
    if (entry == null) throw StateError('Entry not found.');
    return entry;
  }

  Future<int> _repaidPaise(String entryId) async {
    final row = await _database
        .customSelect(
          'SELECT COALESCE(SUM(amount_paise), 0) AS repaid FROM khata_repayments '
          'WHERE entry_id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(entryId)],
          readsFrom: {_database.khataRepayments},
        )
        .getSingle();
    return row.read<int>('repaid');
  }

  static String _requireName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.length > 100) {
      throw ArgumentError.value(name, 'name', 'Enter a name.');
    }
    return normalized;
  }

  static void _requireDirection(String direction) {
    if (direction != khataLent && direction != khataBorrowed) {
      throw ArgumentError.value(direction, 'direction');
    }
  }

  static void _requireAmount(int amountPaise) {
    if (amountPaise <= 0 || amountPaise > khataMaxAmountPaise) {
      throw ArgumentError.value(
        amountPaise,
        'amountPaise',
        'Amount must be positive.',
      );
    }
  }

  static void _requireDueDate(int entryDate, int? dueDate) {
    if (dueDate != null && dueDate < entryDate) {
      throw ArgumentError.value(
        dueDate,
        'dueDate',
        'Due date cannot be before the entry date.',
      );
    }
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _optionalNote(String? value) {
    final trimmed = _optional(value);
    if (trimmed != null && trimmed.length > 500) {
      throw ArgumentError.value(value, 'note', 'Use up to 500 characters.');
    }
    return trimmed;
  }

  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;
}
