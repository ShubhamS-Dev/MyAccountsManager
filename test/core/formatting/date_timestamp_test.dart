import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/formatting/date_timestamp.dart';

void main() {
  group('DateOnly', () {
    test('stores selected calendar components at UTC midnight', () {
      final selected = DateTime(2026, 11, 8, 18, 45);
      final timestamp = DateOnly.toUtcEpochMilliseconds(selected);
      final stored = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
      expect(stored, DateTime.utc(2026, 11, 8));
    });

    test('round trips and displays a date without time', () {
      final timestamp = DateOnly.toUtcEpochMilliseconds(DateTime(2026, 11, 8));
      expect(DateOnly.format(timestamp), '08 Nov 2026');
      expect(DateOnly.format(timestamp, includeMonthName: false), '08/11/2026');
    });

    test('ignores time components of selected date', () {
      final timestamp = DateOnly.toUtcEpochMilliseconds(DateTime(2026, 2, 8, 23, 59));
      expect(DateOnly.fromUtcEpochMilliseconds(timestamp), DateTime.utc(2026, 2, 8));
    });
  });

  test('AuditTimestamp produces a UTC instant', () {
    final timestamp = AuditTimestamp.nowUtcEpochMilliseconds();
    expect(AuditTimestamp.fromUtcEpochMilliseconds(timestamp).isUtc, isTrue);
  });
}
