/// Utilities for date-only business fields and actual audit timestamps.
class DateOnly {
  DateOnly._();

  /// Stores the selected calendar date as UTC midnight, independent of device timezone.
  static int toUtcEpochMilliseconds(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch;
  }

  static DateTime fromUtcEpochMilliseconds(int timestamp) {
    final utc = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  static String format(int timestamp, {bool includeMonthName = true}) {
    final date = fromUtcEpochMilliseconds(timestamp);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    if (!includeMonthName) return '$day/$month/$year';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '$day ${months[date.month - 1]} $year';
  }
}

/// Creates UTC epoch-millisecond timestamps for audit/event fields.
class AuditTimestamp {
  AuditTimestamp._();

  static int nowUtcEpochMilliseconds() =>
      DateTime.now().toUtc().millisecondsSinceEpoch;

  static DateTime fromUtcEpochMilliseconds(int timestamp) =>
      DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
}
