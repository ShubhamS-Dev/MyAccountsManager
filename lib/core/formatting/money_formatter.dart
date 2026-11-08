/// Decimal-safe money parsing and Indian rupee formatting.
class MoneyFormatter {
  MoneyFormatter._();

  /// Parses rupees into integer paise without using binary floating point.
  /// Accepts "500", "500.5", "500.50", and "₹1,25,000.75".
  static int parseRupeesToPaise(String input) {
    var value = input.trim().replaceAll('₹', '').replaceAll(' ', '');
    if (value.isEmpty) throw const FormatException('Amount is required.');

    var negative = false;
    if (value.startsWith('-')) {
      negative = true;
      value = value.substring(1);
    } else if (value.startsWith('+')) {
      value = value.substring(1);
    }

    final parts = value.split('.');
    if (parts.length > 2 || parts[0].isEmpty) {
      throw const FormatException('Enter a valid amount.');
    }
    final fraction = parts.length == 2 ? parts[1] : '';
    if ((fraction.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fraction)) ||
        fraction.length > 2) {
      throw const FormatException('Use up to two decimal places.');
    }

    final whole = _ungroup(parts[0]);
    final rupees = int.tryParse(whole);
    if (rupees == null)
      throw const FormatException('Amount is too large or invalid.');
    final paise = int.parse(
        fraction.padRight(2, '0').isEmpty ? '0' : fraction.padRight(2, '0'));
    final result = rupees * 100 + paise;
    return negative ? -result : result;
  }

  /// Formats integer paise using Indian digit grouping.
  /// Whole rupees have no decimal suffix; fractional rupees have two digits.
  static String formatPaise(int paise, {bool includeSymbol = true}) {
    final negative = paise < 0;
    final absolute = paise.abs();
    final rupees = _groupIndian((absolute ~/ 100).toString());
    final fraction = absolute % 100;
    final amount = fraction == 0
        ? rupees
        : '$rupees.${fraction.toString().padLeft(2, '0')}';
    return (negative ? '-' : '') + (includeSymbol ? '₹' : '') + amount;
  }

  static String _ungroup(String value) {
    if (!value.contains(',')) {
      if (!RegExp(r'^\d+$').hasMatch(value)) {
        throw const FormatException('Enter a valid amount.');
      }
      return value;
    }
    final groups = value.split(',');
    if (groups.length < 2 ||
        !RegExp(r'^\d{1,2}$').hasMatch(groups.first) ||
        !RegExp(r'^\d{3}$').hasMatch(groups.last) ||
        groups
            .skip(1)
            .take(groups.length - 2)
            .any((g) => !RegExp(r'^\d{2}$').hasMatch(g))) {
      throw const FormatException('Invalid Indian number grouping.');
    }
    return groups.join();
  }

  static String _groupIndian(String digits) {
    if (digits.length <= 3) return digits;
    var leading = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (leading.length > 2) {
      groups.insert(0, leading.substring(leading.length - 2));
      leading = leading.substring(0, leading.length - 2);
    }
    groups.insert(0, leading);
    return '${groups.join(',')},${digits.substring(digits.length - 3)}';
  }
}
