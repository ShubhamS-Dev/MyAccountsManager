import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/core/formatting/money_formatter.dart';

void main() {
  group('MoneyFormatter', () {
    test('formats whole and fractional rupees', () {
      expect(MoneyFormatter.formatPaise(50000), '₹500');
      expect(MoneyFormatter.formatPaise(50050), '₹500.50');
      expect(MoneyFormatter.formatPaise(50005), '₹500.05');
    });

    test('uses Indian digit grouping', () {
      expect(MoneyFormatter.formatPaise(12500000), '₹1,25,000');
      expect(MoneyFormatter.formatPaise(12500075), '₹1,25,000.75');
    });

    test('parses rupees to integer paise', () {
      expect(MoneyFormatter.parseRupeesToPaise('500'), 50000);
      expect(MoneyFormatter.parseRupeesToPaise('500.5'), 50050);
      expect(MoneyFormatter.parseRupeesToPaise('₹1,25,000.75'), 12500075);
    });

    test('rejects excess decimals and malformed grouping', () {
      expect(() => MoneyFormatter.parseRupeesToPaise('1.234'), throwsFormatException);
      expect(() => MoneyFormatter.parseRupeesToPaise('1,234,56'), throwsFormatException);
    });
  });
}
