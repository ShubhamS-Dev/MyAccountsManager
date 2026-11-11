import '../../../core/formatting/date_timestamp.dart';

enum RecurringFrequency {
  daily('Daily', 'day'),
  weekly('Weekly', 'week'),
  monthly('Monthly', 'month'),
  yearly('Yearly', 'year');

  const RecurringFrequency(this.label, this.unit);

  final String label;
  final String unit;

  static RecurringFrequency parse(String value) =>
      values.firstWhere((frequency) => frequency.name == value);
}

int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Stored date of occurrence [index] (0 is [startDate]). Monthly and yearly
/// keep the start day, clamped to shorter months: 31 Jan, 28 Feb, 31 Mar.
int occurrenceDate(int startDate, RecurringFrequency frequency, int index) {
  final start = DateOnly.fromUtcEpochMilliseconds(startDate);
  final DateTime date;
  switch (frequency) {
    case RecurringFrequency.daily:
      date = DateTime.utc(start.year, start.month, start.day + index);
    case RecurringFrequency.weekly:
      date = DateTime.utc(start.year, start.month, start.day + 7 * index);
    case RecurringFrequency.monthly:
      final months = start.month - 1 + index;
      final year = start.year + months ~/ 12;
      final month = months % 12 + 1;
      final day = start.day.clamp(1, _daysInMonth(year, month));
      date = DateTime.utc(year, month, day);
    case RecurringFrequency.yearly:
      final year = start.year + index;
      final day = start.day.clamp(1, _daysInMonth(year, start.month));
      date = DateTime.utc(year, start.month, day);
  }
  return date.millisecondsSinceEpoch;
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Every month on day 31", "Every week on Monday", "Every day".
String recurrenceSummary(RecurringFrequency frequency, int startDate) {
  final start = DateOnly.fromUtcEpochMilliseconds(startDate);
  return switch (frequency) {
    RecurringFrequency.daily => 'Every day',
    RecurringFrequency.weekly =>
      'Every week on ${_weekdays[start.weekday - 1]}',
    RecurringFrequency.monthly => 'Every month on day ${start.day}',
    RecurringFrequency.yearly =>
      'Every year on ${DateOnly.format(startDate).substring(0, 6)}',
  };
}
