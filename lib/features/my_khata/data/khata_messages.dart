import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import 'khata_repository.dart';

/// Text for reminders and statements a user sends from Person Details, plus
/// the phone links behind Call and WhatsApp. Amounts are always shown: the
/// user is choosing to send them.
abstract final class KhataMessages {
  /// Earliest due date among open entries this person owes you.
  static int? earliestDueDate(List<KhataEntryItem> entries) {
    final dates = [
      for (final item in entries)
        if (item.isLent && !item.isSettled && item.entry.dueDate != null)
          item.entry.dueDate!,
    ]..sort();
    return dates.firstOrNull;
  }

  static String reminder({
    required String name,
    required int owedPaise,
    required int? dueDate,
    required int today,
  }) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    final due = switch (dueDate) {
      null => '',
      final date when date < today =>
        ' It was due on ${DateOnly.format(date)}.',
      final date when date == today => ' It is due today.',
      final date => ' It is due on ${DateOnly.format(date)}.',
    };
    return 'Hi $first, a friendly reminder that '
        '${MoneyFormatter.formatPaise(owedPaise)} is pending.$due '
        'Please settle it when you can. Thank you!';
  }

  /// Plain-text ledger for one person: open entries, settled entries,
  /// repayments and the net position.
  static String statement({
    required String name,
    required List<KhataEntryItem> entries,
    required List<KhataRepaymentRow> repayments,
    required int today,
  }) {
    String money(int paise) => MoneyFormatter.formatPaise(paise);
    String line(KhataEntryItem item) {
      final verb = item.isLent ? 'You gave' : 'You got';
      final parts = [
        '${DateOnly.format(item.entry.entryDate)}  $verb ${money(item.entry.amountPaise)}',
        if (item.repaidPaise > 0 && !item.isSettled)
          'repaid ${money(item.repaidPaise)}, ${money(item.outstandingPaise)} left',
        if (!item.isSettled && item.entry.dueDate != null)
          'due ${DateOnly.format(item.entry.dueDate!)}'
              '${item.entry.dueDate! < today ? ' (overdue)' : ''}',
        if (item.entry.note case final note? when note.isNotEmpty) note,
      ];
      return parts.join(' · ');
    }

    final ordered = [...entries]
      ..sort((a, b) => a.entry.entryDate.compareTo(b.entry.entryDate));
    final open = ordered.where((item) => !item.isSettled).toList();
    final settled = ordered.where((item) => item.isSettled).toList();
    final byId = {for (final item in ordered) item.entry.id: item};
    var net = 0;
    for (final item in open) {
      net += item.isLent ? item.outstandingPaise : -item.outstandingPaise;
    }

    return [
      'MyKhata statement: ${name.trim()}',
      'As of ${DateOnly.format(today)}',
      if (open.isNotEmpty) ...['', 'Open', ...open.map(line)],
      if (settled.isNotEmpty) ...['', 'Settled', ...settled.map(line)],
      if (repayments.isNotEmpty) ...[
        '',
        'Repayments',
        for (final repayment in repayments)
          if (byId[repayment.entryId] case final item?)
            '${DateOnly.format(repayment.repaymentDate)}  '
                '${item.isLent ? '${name.trim()} paid' : 'You paid'} '
                '${money(repayment.amountPaise)}'
                '${repayment.note?.isNotEmpty == true ? ' · ${repayment.note}' : ''}',
      ],
      '',
      switch (net) {
        0 => 'All settled',
        > 0 => '${name.trim()} owes you ${money(net)}',
        _ => 'You owe ${name.trim()} ${money(-net)}',
      },
    ].join('\n');
  }

  /// International digits for wa.me, assuming India (+91) when the number
  /// has no country code. Null when it cannot be a phone number.
  static String? whatsAppNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.trim().startsWith('+') || phone.trim().startsWith('00')) {
      final international = digits.startsWith('00')
          ? digits.substring(2)
          : digits;
      return international.length >= 8 && international.length <= 15
          ? international
          : null;
    }
    if (digits.length == 10) return '91$digits';
    if (digits.length == 11 && digits.startsWith('0')) {
      return '91${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) return digits;
    return null;
  }

  static Uri whatsAppUri(String number, {String? text}) =>
      Uri.https('wa.me', '/$number', text == null ? null : {'text': text});

  static Uri callUri(String phone) =>
      Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
}
