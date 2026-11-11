import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_form_widgets.dart';
import 'package:my_accounts_manager/core/formatting/indian_amount_input_formatter.dart';

TextEditingValue _type(IndianAmountInputFormatter formatter, String text) =>
    formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );

void main() {
  group('IndianAmountInputFormatter', () {
    test('groups digits the Indian way and keeps paise', () {
      const formatter = IndianAmountInputFormatter();
      expect(_type(formatter, '100000').text, '1,00,000');
      expect(_type(formatter, '1234567.5').text, '12,34,567.5');
    });

    test('rejects a sign unless signed input is allowed', () {
      const unsigned = IndianAmountInputFormatter();
      expect(_type(unsigned, '-500').text, isEmpty);

      const signed = IndianAmountInputFormatter(allowSign: true);
      expect(_type(signed, '-100000').text, '-1,00,000');
      expect(_type(signed, '-').text, '-');
    });

    test('caps whole rupees at 12 digits', () {
      const formatter = IndianAmountInputFormatter();
      expect(_type(formatter, '1234567890123').text, isEmpty);
    });
  });

  group('parseAmountPaise', () {
    test('parses grouped input into integer paise', () {
      expect(parseAmountPaise('1,00,000.50'), 10000050);
      expect(parseAmountPaise('-2,500', allowSign: true), -250000);
    });

    test('returns null for empty, bare signs or disallowed signs', () {
      expect(parseAmountPaise(''), isNull);
      expect(parseAmountPaise('-', allowSign: true), isNull);
      expect(parseAmountPaise('-50'), isNull);
    });
  });

  group('dateLabel', () {
    test('shows Today for the current local date', () {
      expect(dateLabel(DateTime.now()), 'Today');
    });

    test('shows DD MMM YYYY for any other date', () {
      expect(dateLabel(DateTime(2026, 11, 8)), '08 Nov 2026');
    });

    test('round-trips stored UTC dates without shifting the day', () {
      final stored = DateTime.utc(2026, 3, 1).millisecondsSinceEpoch;
      expect(localDateFromStored(stored), DateTime(2026, 3, 1));
    });
  });
}
