import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../my_khata/data/khata_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/notification_preferences.dart';

const _dayMs = Duration.millisecondsPerDay;

/// How many days ahead the daily overdue summary is scheduled. Opening the
/// app re-plans, so the window keeps moving forward.
const overdueSummaryDays = 14;

/// Android caps pending alarms per app; stay well below it.
const maxPlannedReminders = 64;

/// One local notification to schedule. [fireAt] is a local wall-clock time.
class PlannedReminder {
  const PlannedReminder({
    required this.key,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.route,
  });

  /// Stable identity, e.g. `khata-due:<entryId>`.
  final String key;
  final DateTime fireAt;
  final String title;
  final String body;

  /// In-app location opened when the notification is tapped.
  final String route;

  /// Android notification id derived from [key] (FNV-1a, 31 bits), so the
  /// same reminder keeps its id across re-plans.
  int get id {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.key == key &&
      other.fireAt == fireAt &&
      other.title == title &&
      other.body == body &&
      other.route == route;

  @override
  int get hashCode => Object.hash(key, fireAt, title, body, route);
}

/// Open MyKhata entries that have a due date.
List<KhataEntryItem> _openWithDueDate(List<KhataEntryItem> entries) => [
  for (final item in entries)
    if (!item.isSettled && item.entry.dueDate != null) item,
];

/// Builds every reminder that should be pending after [now], nearest first.
List<PlannedReminder> planReminders({
  required List<KhataEntryItem> khataEntries,
  required List<TransactionHistoryItem> scheduledTransactions,
  required NotificationPreferences preferences,
  required DateTime now,
}) {
  if (!preferences.enabled) return const [];
  final amounts = preferences.showAmounts;
  DateTime fireOn(int storedDate) {
    final date = DateOnly.fromUtcEpochMilliseconds(storedDate);
    return DateTime(
      date.year,
      date.month,
      date.day,
      preferences.reminderHour,
      preferences.reminderMinute,
    );
  }

  final reminders = <PlannedReminder>[];
  final open = _openWithDueDate(khataEntries);
  for (final item in open) {
    final due = item.entry.dueDate!;
    final route = '/khata/entries/${item.entry.id}';
    if (preferences.khataDayBefore) {
      reminders.add(
        PlannedReminder(
          key: 'khata-before:${item.entry.id}',
          fireAt: fireOn(due - _dayMs),
          title: 'Due tomorrow',
          body: khataReminderText(item, showAmounts: amounts),
          route: route,
        ),
      );
    }
    if (preferences.khataDueDate) {
      reminders.add(
        PlannedReminder(
          key: 'khata-due:${item.entry.id}',
          fireAt: fireOn(due),
          title: 'Due today',
          body: khataReminderText(item, showAmounts: amounts),
          route: route,
        ),
      );
    }
  }

  if (preferences.overdueSummary && open.isNotEmpty) {
    final today = DateOnly.toUtcEpochMilliseconds(now);
    for (var offset = 0; offset < overdueSummaryDays; offset++) {
      final day = today + offset * _dayMs;
      final overdue = [
        for (final item in open)
          if (item.entry.dueDate! < day) item,
      ];
      if (overdue.isEmpty) continue;
      reminders.add(
        PlannedReminder(
          key: 'khata-overdue:$day',
          fireAt: fireOn(day),
          title: overdue.length == 1
              ? '1 MyKhata entry is overdue'
              : '${overdue.length} MyKhata entries are overdue',
          body: overdueSummaryText(overdue, showAmounts: amounts),
          route: '/activity',
        ),
      );
    }
  }

  if (preferences.scheduledTransactions) {
    for (final item in scheduledTransactions) {
      final transaction = item.transaction;
      final income = transaction.type == 'income';
      final details = [
        if (amounts) MoneyFormatter.formatPaise(transaction.amountPaise),
        item.categoryName,
        item.accountName,
      ].join(' · ');
      reminders.add(
        PlannedReminder(
          key: 'transaction:${transaction.id}',
          fireAt: fireOn(transaction.transactionDate),
          title: income
              ? 'Scheduled income counts from today'
              : 'Scheduled expense counts from today',
          body: details,
          route: '/transaction/${transaction.id}',
        ),
      );
    }
  }

  final upcoming = [
    for (final reminder in reminders)
      if (reminder.fireAt.isAfter(now)) reminder,
  ]..sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return upcoming.take(maxPlannedReminders).toList();
}

/// "Collect from Ravi" or, with amounts, "Collect ₹5,000 from Ravi".
String khataReminderText(KhataEntryItem item, {required bool showAmounts}) {
  final amount = showAmounts
      ? ' ${MoneyFormatter.formatPaise(item.outstandingPaise)}'
      : '';
  return item.isLent
      ? 'Collect$amount from ${item.personName}'
      : 'Pay ${item.personName}$amount';
}

/// Names of the people involved or, with amounts, the totals per direction.
String overdueSummaryText(
  List<KhataEntryItem> overdue, {
  required bool showAmounts,
}) {
  if (showAmounts) {
    var collect = 0;
    var pay = 0;
    for (final item in overdue) {
      if (item.isLent) {
        collect += item.outstandingPaise;
      } else {
        pay += item.outstandingPaise;
      }
    }
    return [
      if (collect > 0) '${MoneyFormatter.formatPaise(collect)} to collect',
      if (pay > 0) '${MoneyFormatter.formatPaise(pay)} to pay',
    ].join(' · ');
  }
  final names = <String>{for (final item in overdue) item.personName}.toList();
  if (names.length <= 2) return 'With ${names.join(' and ')}';
  return 'With ${names.take(2).join(', ')} and ${names.length - 2} more';
}

/// What the Activity center shows, derived from the same data as reminders.
class ActivityDigest {
  const ActivityDigest({
    required this.overdue,
    required this.dueSoon,
    required this.scheduled,
    required this.today,
  });

  factory ActivityDigest.build({
    required List<KhataEntryItem> khataEntries,
    required List<TransactionHistoryItem> scheduledTransactions,
    required int today,
  }) {
    final open = _openWithDueDate(khataEntries)
      ..sort((a, b) => a.entry.dueDate!.compareTo(b.entry.dueDate!));
    final soonLimit = today + dueSoonDays * _dayMs;
    return ActivityDigest(
      overdue: [
        for (final item in open)
          if (item.entry.dueDate! < today) item,
      ],
      dueSoon: [
        for (final item in open)
          if (item.entry.dueDate! >= today && item.entry.dueDate! <= soonLimit)
            item,
      ],
      scheduled: [...scheduledTransactions]
        ..sort(
          (a, b) => a.transaction.transactionDate.compareTo(
            b.transaction.transactionDate,
          ),
        ),
      today: today,
    );
  }

  /// Due dates within this many days count as "due soon".
  static const dueSoonDays = 7;

  final List<KhataEntryItem> overdue;
  final List<KhataEntryItem> dueSoon;
  final List<TransactionHistoryItem> scheduled;
  final int today;

  bool get isEmpty => overdue.isEmpty && dueSoon.isEmpty && scheduled.isEmpty;

  /// Items needing action now: overdue plus due today. Drives the bell badge.
  int get attentionCount =>
      overdue.length +
      dueSoon.where((item) => item.entry.dueDate == today).length;
}
