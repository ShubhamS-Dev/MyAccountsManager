import 'package:flutter/services.dart';

import 'money_formatter.dart';

/// Live Indian digit grouping for amount inputs: up to 12 whole-rupee digits
/// and two decimal places. With [allowSign], a leading `-` (or `+`) is kept
/// for signed values such as opening balances and adjustments.
class IndianAmountInputFormatter extends TextInputFormatter {
  const IndianAmountInputFormatter({this.allowSign = false});

  final bool allowSign;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    var sign = '';
    if (allowSign && text.isNotEmpty && (text[0] == '-' || text[0] == '+')) {
      sign = text[0];
      text = text.substring(1);
    }
    final raw = text.replaceAll(',', '');
    if (raw.isEmpty) {
      return TextEditingValue(
        text: sign,
        selection: TextSelection.collapsed(offset: sign.length),
      );
    }
    if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(raw)) return oldValue;

    final parts = raw.split('.');
    final whole = parts.first;
    if (whole.length > 12) return oldValue;

    final formattedWhole = _group(whole);
    final formatted = parts.length == 2
        ? '$formattedWhole.${parts[1]}'
        : formattedWhole;

    final cursor = (newValue.selection.baseOffset - sign.length).clamp(
      0,
      text.length,
    );
    final prefix = text.substring(0, cursor).replaceAll(',', '');
    final prefixParts = prefix.split('.');
    final formattedPrefix = _group(prefixParts.first);
    final nextCursor =
        (formattedPrefix.length +
                (prefixParts.length == 2 ? 1 + prefixParts[1].length : 0))
            .clamp(0, formatted.length);

    return TextEditingValue(
      text: '$sign$formatted',
      selection: TextSelection.collapsed(offset: sign.length + nextCursor),
    );
  }

  static String _group(String whole) => whole.isEmpty
      ? ''
      : MoneyFormatter.formatPaise(
          int.parse(whole) * 100,
          includeSymbol: false,
        );
}
