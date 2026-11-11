/// Reminder preferences, stored as strings in the app_settings table under
/// the `notifications.` prefix. Missing keys fall back to the defaults.
const notificationSettingPrefix = 'notifications.';
const notificationsEnabledKey = 'notifications.enabled';
const reminderMinutesKey = 'notifications.reminder_minutes';
const khataDayBeforeKey = 'notifications.khata_day_before';
const khataDueDateKey = 'notifications.khata_due_date';
const overdueSummaryKey = 'notifications.overdue_summary';
const scheduledTransactionsKey = 'notifications.scheduled_transactions';
const showAmountsKey = 'notifications.show_amounts';

/// Set once the app has asked for the Android notification permission, so
/// the system prompt is shown at most once without the user asking.
const permissionAskedKey = 'notifications.permission_asked';

/// 9:00 AM, as minutes after local midnight.
const defaultReminderMinutes = 9 * 60;

class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.reminderMinutes = defaultReminderMinutes,
    this.khataDayBefore = true,
    this.khataDueDate = true,
    this.overdueSummary = true,
    this.scheduledTransactions = true,
    this.showAmounts = false,
  });

  factory NotificationPreferences.fromStorage(Map<String, String> values) {
    bool flag(String key, bool fallback) => switch (values[key]) {
      'true' => true,
      'false' => false,
      _ => fallback,
    };
    final minutes = int.tryParse(values[reminderMinutesKey] ?? '');
    return NotificationPreferences(
      enabled: flag(notificationsEnabledKey, true),
      reminderMinutes: minutes != null && minutes >= 0 && minutes < 24 * 60
          ? minutes
          : defaultReminderMinutes,
      khataDayBefore: flag(khataDayBeforeKey, true),
      khataDueDate: flag(khataDueDateKey, true),
      overdueSummary: flag(overdueSummaryKey, true),
      scheduledTransactions: flag(scheduledTransactionsKey, true),
      showAmounts: flag(showAmountsKey, false),
    );
  }

  /// Master switch for every reminder type.
  final bool enabled;

  /// Local time of day all reminders fire, in minutes after midnight.
  final int reminderMinutes;
  final bool khataDayBefore;
  final bool khataDueDate;
  final bool overdueSummary;
  final bool scheduledTransactions;

  /// Amounts can appear on the lock screen, so they are hidden by default.
  final bool showAmounts;

  int get reminderHour => reminderMinutes ~/ 60;
  int get reminderMinute => reminderMinutes % 60;

  bool get anyTypeEnabled =>
      khataDayBefore || khataDueDate || overdueSummary || scheduledTransactions;
}

/// `9:00 AM` style label for a minutes-after-midnight time.
String reminderTimeLabel(int minutes) {
  final hour = minutes ~/ 60;
  final minute = (minutes % 60).toString().padLeft(2, '0');
  final period = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:$minute $period';
}
