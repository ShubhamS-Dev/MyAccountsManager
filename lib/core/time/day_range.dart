import '../formatting/date_timestamp.dart';

/// An inclusive range of stored business dates (UTC-midnight milliseconds).
class DayRange {
  const DayRange(this.from, this.through);

  /// The range a [preset] covers on [today] (UTC-midnight milliseconds).
  factory DayRange.preset(RangePreset preset, int today) {
    final day = DateOnly.fromUtcEpochMilliseconds(today);
    int at(int year, int month, int date) =>
        DateTime.utc(year, month, date).millisecondsSinceEpoch;
    int daysAgo(int days) => today - days * Duration.millisecondsPerDay;
    return switch (preset) {
      RangePreset.last7Days => DayRange(daysAgo(6), today),
      RangePreset.last30Days => DayRange(daysAgo(29), today),
      RangePreset.thisMonth => DayRange(
        at(day.year, day.month, 1),
        at(day.year, day.month + 1, 0),
      ),
      RangePreset.lastMonth => DayRange(
        at(day.year, day.month - 1, 1),
        at(day.year, day.month, 0),
      ),
      RangePreset.last3Months => DayRange(
        at(day.year, day.month - 2, 1),
        at(day.year, day.month + 1, 0),
      ),
      RangePreset.last6Months => DayRange(
        at(day.year, day.month - 5, 1),
        at(day.year, day.month + 1, 0),
      ),
      RangePreset.thisYear => DayRange(
        at(day.year, 1, 1),
        at(day.year, 12, 31),
      ),
      RangePreset.lastYear => DayRange(
        at(day.year - 1, 1, 1),
        at(day.year - 1, 12, 31),
      ),
    };
  }

  final int from;
  final int through;

  int get days => (through - from) ~/ Duration.millisecondsPerDay + 1;

  bool contains(int date) => date >= from && date <= through;

  /// The same number of days immediately before this range.
  DayRange get previous => DayRange(
    from - days * Duration.millisecondsPerDay,
    from - Duration.millisecondsPerDay,
  );

  String get label {
    if (from == through) return DateOnly.format(from);
    final start = DateOnly.fromUtcEpochMilliseconds(from);
    final end = DateOnly.fromUtcEpochMilliseconds(through);
    final endLabel = DateOnly.format(through);
    if (start.year == end.year) {
      // "01 Nov – 11 Nov 2026"
      return '${DateOnly.format(from).substring(0, 6)} – $endLabel';
    }
    return '${DateOnly.format(from)} – $endLabel';
  }

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.from == from && other.through == through;

  @override
  int get hashCode => Object.hash(from, through);
}

enum RangePreset {
  thisMonth('This month'),
  lastMonth('Last month'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  last3Months('Last 3 months'),
  last6Months('Last 6 months'),
  thisYear('This year'),
  lastYear('Last year');

  const RangePreset(this.label);
  final String label;

  /// The preset that produces [range] on [today], if any.
  static RangePreset? matching(DayRange range, int today) {
    for (final preset in values) {
      if (DayRange.preset(preset, today) == range) return preset;
    }
    return null;
  }
}
