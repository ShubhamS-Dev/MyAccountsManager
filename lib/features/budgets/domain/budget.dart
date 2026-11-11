import '../../../core/formatting/money_formatter.dart';

/// Budget settings live in app_settings under the `budget.` prefix.
const budgetSettingPrefix = 'budget.';
const budgetLimitKey = 'budget.monthly_limit_paise';
const budgetAlertsKey = 'budget.alerts_enabled';

/// Highest alert already sent for a month: `budget.alerted.2026-11` = 80.
const budgetAlertedPrefix = 'budget.alerted.';

String budgetAlertedKey(DateTime month) =>
    '$budgetAlertedPrefix${month.year}-${month.month.toString().padLeft(2, '0')}';

/// Alert thresholds, as percent of the limit.
const budgetThresholds = [80, 100];

class BudgetSettings {
  const BudgetSettings({
    this.limitPaise,
    this.alertsEnabled = true,
    this.alerted = const {},
  });

  factory BudgetSettings.fromStorage(Map<String, String> values) {
    final limit = int.tryParse(values[budgetLimitKey] ?? '');
    return BudgetSettings(
      limitPaise: limit != null && limit > 0 ? limit : null,
      alertsEnabled: values[budgetAlertsKey] != 'false',
      alerted: {
        for (final entry in values.entries)
          if (entry.key.startsWith(budgetAlertedPrefix))
            entry.key: int.tryParse(entry.value) ?? 0,
      },
    );
  }

  /// Null means no budget is set.
  final int? limitPaise;
  final bool alertsEnabled;

  /// Highest threshold already alerted, keyed by [budgetAlertedKey].
  final Map<String, int> alerted;

  int alertedFor(DateTime month) => alerted[budgetAlertedKey(month)] ?? 0;
}

enum BudgetLevel { onTrack, warning, over }

/// This month's spending against the limit. [date] is the local day the
/// figures are for.
class BudgetStatus {
  const BudgetStatus({
    required this.limitPaise,
    required this.spentPaise,
    required this.date,
  });

  final int limitPaise;
  final int spentPaise;
  final DateTime date;

  double get ratio => spentPaise / limitPaise;
  int get percent => (ratio * 100).floor();
  int get remainingPaise => limitPaise - spentPaise;

  BudgetLevel get level => ratio >= 1
      ? BudgetLevel.over
      : ratio >= .8
      ? BudgetLevel.warning
      : BudgetLevel.onTrack;

  /// Days left including today.
  int get daysLeft => DateTime(date.year, date.month + 1, 0).day - date.day + 1;

  /// What can still be spent per day to stay within the limit.
  int get dailyAllowancePaise =>
      remainingPaise <= 0 ? 0 : remainingPaise ~/ daysLeft;

  /// Highest threshold reached, or 0.
  int get thresholdReached => budgetThresholds.lastWhere(
    (threshold) => percent >= threshold,
    orElse: () => 0,
  );
}

/// Title and body for the alert at [threshold] percent.
({String title, String body}) budgetAlertText(
  BudgetStatus status,
  int threshold, {
  required bool showAmounts,
}) {
  final title = threshold >= 100
      ? 'Monthly budget exceeded'
      : '$threshold% of monthly budget used';
  if (!showAmounts) {
    return (title: title, body: 'Tap to see where this month stands.');
  }
  final spent = MoneyFormatter.formatPaise(status.spentPaise);
  final limit = MoneyFormatter.formatPaise(status.limitPaise);
  final body = threshold >= 100
      ? '$spent spent of $limit. Over by '
            '${MoneyFormatter.formatPaise(-status.remainingPaise)}.'
      : '$spent spent of $limit. '
            '${MoneyFormatter.formatPaise(status.remainingPaise)} left for '
            '${status.daysLeft} ${status.daysLeft == 1 ? 'day' : 'days'}.';
  return (title: title, body: body);
}
