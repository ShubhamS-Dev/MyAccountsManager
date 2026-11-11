import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/recurrence.dart';

/// A rule with the names and state the Recurring screen shows.
class RecurringRuleItem {
  const RecurringRuleItem({
    required this.rule,
    required this.accountName,
    required this.accountArchived,
    required this.categoryName,
    required this.categoryActive,
    this.categoryIconKey,
    this.categoryColorValue,
  });

  final RecurringRuleRow rule;
  final String accountName;
  final bool accountArchived;
  final String categoryName;
  final bool categoryActive;
  final String? categoryIconKey;
  final int? categoryColorValue;

  RecurringFrequency get frequency => RecurringFrequency.parse(rule.frequency);

  bool get paused => rule.pausedAt != null;

  /// Date of the next occurrence not yet saved, or null once past endDate.
  int? get nextUnsavedDate {
    final date = occurrenceDate(rule.startDate, frequency, rule.nextIndex);
    final end = rule.endDate;
    return end != null && date > end ? null : date;
  }

  bool get ended => nextUnsavedDate == null;

  /// The next date this series adds a transaction: its saved Scheduled
  /// occurrence, else the next one to save. Null when ended or paused.
  int? upcomingDate(int today) {
    if (paused) return null;
    if (rule.nextIndex > 0) {
      final saved = occurrenceDate(
        rule.startDate,
        frequency,
        rule.nextIndex - 1,
      );
      if (saved > today) return saved;
    }
    return nextUnsavedDate;
  }

  /// Occurrences cannot be saved until the Account or category is usable.
  bool get blocked => accountArchived || !categoryActive;
}

/// Saves recurring rules and turns them into ordinary transactions.
///
/// Each active rule keeps exactly one upcoming occurrence saved as a
/// Scheduled transaction, so it counts on its date and gets the usual
/// scheduled-transaction reminder even if the app is not opened that day.
/// [materializeDue] catches up anything missed and schedules the next one.
class RecurringRepository {
  RecurringRepository(this._database, this._transactions);

  final AppDatabase _database;
  final TransactionsRepository _transactions;
  static const _uuid = Uuid();

  /// Upper bound on occurrences saved for one rule in one pass, e.g. a daily
  /// rule after a year away.
  static const maxCatchUp = 400;

  Stream<List<RecurringRuleItem>> watchRules() {
    final query =
        _database.select(_database.recurringRules).join([
            innerJoin(
              _database.accounts,
              _database.accounts.id.equalsExp(
                _database.recurringRules.accountId,
              ),
            ),
            innerJoin(
              _database.categories,
              _database.categories.id.equalsExp(
                _database.recurringRules.categoryId,
              ),
            ),
          ])
          ..where(_database.recurringRules.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(_database.recurringRules.createdAt)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          RecurringRuleItem(
            rule: row.readTable(_database.recurringRules),
            accountName: row.readTable(_database.accounts).name,
            accountArchived:
                row.readTable(_database.accounts).archivedAt != null,
            categoryName: row.readTable(_database.categories).name,
            categoryActive: row.readTable(_database.categories).isActive,
            categoryIconKey: row.readTable(_database.categories).iconKey,
            categoryColorValue: row.readTable(_database.categories).colorValue,
          ),
      ],
    );
  }

  Future<RecurringRuleRow?> getRule(String ruleId) => (_database.select(
    _database.recurringRules,
  )..where((row) => row.id.equals(ruleId))).getSingleOrNull();

  /// Turns an already-saved transaction into the first occurrence of a new
  /// rule, then saves whatever is due through the next upcoming date.
  Future<String> createFromTransaction({
    required String transactionId,
    required RecurringFrequency frequency,
    required int today,
    int? endDate,
  }) async {
    final source = await _transactions.getTransaction(transactionId);
    if (source == null) throw StateError('Transaction was not found.');
    if (endDate != null && endDate < source.transactionDate) {
      throw ArgumentError.value(endDate, 'endDate', 'Ends before it starts.');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction(() async {
      await _database
          .into(_database.recurringRules)
          .insert(
            RecurringRulesCompanion.insert(
              id: id,
              accountId: source.accountId,
              categoryId: source.categoryId,
              type: source.type,
              amountPaise: source.amountPaise,
              note: Value(source.note),
              frequency: frequency.name,
              startDate: source.transactionDate,
              endDate: Value(endDate),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await (_database.update(_database.transactions)
            ..where((row) => row.id.equals(transactionId)))
          .write(TransactionsCompanion(recurringRuleId: Value(id)));
    });
    await materializeDue(today: today, ruleId: id);
    return id;
  }

  /// Saves every due occurrence of active rules, plus the next upcoming one
  /// as Scheduled. Rules whose Account is archived or category hidden are
  /// skipped until fixed. Returns how many transactions were created.
  Future<int> materializeDue({required int today, String? ruleId}) async {
    final query = _database.select(_database.recurringRules)
      ..where((row) => row.deletedAt.isNull() & row.pausedAt.isNull());
    if (ruleId != null) query.where((row) => row.id.equals(ruleId));
    var created = 0;
    for (final candidate in await query.get()) {
      created += await _database.transaction(() async {
        // Re-read inside the transaction so overlapping passes (resume and
        // midnight together) never save the same occurrence twice.
        final rule = await getRule(candidate.id);
        if (rule == null || rule.deletedAt != null || rule.pausedAt != null) {
          return 0;
        }
        final frequency = RecurringFrequency.parse(rule.frequency);
        var index = rule.nextIndex;
        var saved = 0;
        while (saved < maxCatchUp) {
          // One upcoming occurrence is enough; it was saved already.
          if (index > 0 &&
              occurrenceDate(rule.startDate, frequency, index - 1) > today) {
            break;
          }
          final date = occurrenceDate(rule.startDate, frequency, index);
          if (rule.endDate != null && date > rule.endDate!) break;
          try {
            await _transactions.createTransaction(
              accountId: rule.accountId,
              categoryId: rule.categoryId,
              type: rule.type,
              amountPaise: rule.amountPaise,
              transactionDate: date,
              note: rule.note,
              recurringRuleId: rule.id,
            );
          } on StateError {
            break; // Archived Account or hidden category.
          }
          index++;
          saved++;
        }
        if (index != rule.nextIndex) {
          await _setNextIndex(rule.id, index);
        }
        return saved;
      });
    }
    return created;
  }

  Future<void> pause(String ruleId, {required int today}) =>
      _database.transaction(() async {
        final rule = await _require(ruleId);
        await _removeUpcoming(rule, today);
        await _write(
          ruleId,
          RecurringRulesCompanion(
            pausedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          ),
        );
      });

  /// Restarts from the first occurrence on or after [today]; dates missed
  /// while paused are skipped, not back-filled.
  Future<void> resume(String ruleId, {required int today}) async {
    await _database.transaction(() async {
      final rule = await _require(ruleId);
      final frequency = RecurringFrequency.parse(rule.frequency);
      var index = rule.nextIndex;
      while (occurrenceDate(rule.startDate, frequency, index) < today) {
        index++;
      }
      await _write(
        ruleId,
        RecurringRulesCompanion(
          pausedAt: const Value(null),
          nextIndex: Value(index),
        ),
      );
    });
    await materializeDue(today: today, ruleId: ruleId);
  }

  /// Changes amount, note or end date for upcoming occurrences. Saved past
  /// occurrences keep their values.
  Future<void> update(
    String ruleId, {
    required int amountPaise,
    required String? note,
    required int? endDate,
    required int today,
  }) async {
    if (amountPaise <= 0) {
      throw ArgumentError.value(amountPaise, 'amountPaise', 'Must be > 0.');
    }
    await _database.transaction(() async {
      final rule = await _require(ruleId);
      if (endDate != null && endDate < rule.startDate) {
        throw ArgumentError.value(endDate, 'endDate', 'Ends before it starts.');
      }
      await _removeUpcoming(rule, today);
      final trimmed = note?.trim();
      await _write(
        ruleId,
        RecurringRulesCompanion(
          amountPaise: Value(amountPaise),
          note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
          endDate: Value(endDate),
        ),
      );
    });
    await materializeDue(today: today, ruleId: ruleId);
  }

  /// Stops the rule and removes its upcoming Scheduled occurrence. Saved
  /// past occurrences stay as ordinary transactions.
  Future<void> delete(String ruleId, {required int today}) =>
      _database.transaction(() async {
        final rule = await _require(ruleId);
        await _removeUpcoming(rule, today);
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await _write(ruleId, RecurringRulesCompanion(deletedAt: Value(now)));
      });

  /// Hard-deletes the rule's Scheduled occurrences (they never counted) and
  /// rewinds [RecurringRuleRow.nextIndex] so they can be saved again.
  Future<void> _removeUpcoming(RecurringRuleRow rule, int today) async {
    final removed =
        await (_database.delete(_database.transactions)..where(
              (row) =>
                  row.recurringRuleId.equals(rule.id) &
                  row.deletedAt.isNull() &
                  row.transactionDate.isBiggerThanValue(today),
            ))
            .go();
    if (removed > 0) {
      await _setNextIndex(
        rule.id,
        (rule.nextIndex - removed).clamp(0, rule.nextIndex),
      );
    }
  }

  Future<RecurringRuleRow> _require(String ruleId) async {
    final rule = await getRule(ruleId);
    if (rule == null || rule.deletedAt != null) {
      throw StateError('Recurring rule was not found.');
    }
    return rule;
  }

  Future<void> _setNextIndex(String ruleId, int index) =>
      _write(ruleId, RecurringRulesCompanion(nextIndex: Value(index)));

  Future<void> _write(String ruleId, RecurringRulesCompanion changes) =>
      (_database.update(
        _database.recurringRules,
      )..where((row) => row.id.equals(ruleId))).write(
        changes.copyWith(
          updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        ),
      );
}
