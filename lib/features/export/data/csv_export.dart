import '../../../core/database/app_database.dart';
import '../../../core/time/today_provider.dart';
import '../../my_khata/data/khata_repository.dart';
import '../../transactions/data/transactions_repository.dart';

/// Builds the CSV files offered by More > Export data. Pure functions so the
/// output can be tested without files or the share sheet.
///
/// Dates are ISO `yyyy-MM-dd` and amounts are plain rupee decimals
/// (`1500.50`) so spreadsheets read them as dates and numbers.
abstract final class CsvExport {
  static const transactionsHeader = [
    'Date',
    'Type',
    'Account',
    'Category',
    'Amount (INR)',
    'Note',
    'Status',
  ];

  static const khataHeader = [
    'Record',
    'Entry #',
    'Date',
    'Person',
    'Direction',
    'Amount (INR)',
    'Outstanding (INR)',
    'Due date',
    'Status',
    'Note',
  ];

  /// Regular transactions, newest first as given. Trash is never passed in.
  static String transactions(List<TransactionHistoryItem> items, int today) =>
      _csv([
        transactionsHeader,
        for (final item in items)
          [
            isoDate(item.transaction.transactionDate),
            item.transaction.type == 'income' ? 'Income' : 'Expense',
            item.accountName,
            item.categoryName,
            rupees(item.transaction.amountPaise),
            item.transaction.note ?? '',
            isScheduledDate(item.transaction.transactionDate, today)
                ? 'Scheduled'
                : 'Posted',
          ],
      ]);

  /// MyKhata entries followed by their repayments. Repayments point back to
  /// their entry through the "Entry #" column.
  static String khata(
    List<KhataEntryItem> entries,
    List<KhataRepaymentRow> repayments,
    int today,
  ) {
    final ordered = [...entries]
      ..sort((a, b) => a.entry.entryDate.compareTo(b.entry.entryDate));
    final number = {
      for (final (index, item) in ordered.indexed) item.entry.id: index + 1,
    };
    final byId = {for (final item in ordered) item.entry.id: item};
    return _csv([
      khataHeader,
      for (final item in ordered)
        [
          'Entry',
          '${number[item.entry.id]}',
          isoDate(item.entry.entryDate),
          item.personName,
          item.isLent ? 'Lent' : 'Borrowed',
          rupees(item.entry.amountPaise),
          rupees(item.outstandingPaise < 0 ? 0 : item.outstandingPaise),
          item.entry.dueDate == null ? '' : isoDate(item.entry.dueDate!),
          _entryStatus(item, today),
          item.entry.note ?? '',
        ],
      for (final repayment in repayments)
        if (byId[repayment.entryId] case final item?)
          [
            'Repayment',
            '${number[repayment.entryId]}',
            isoDate(repayment.repaymentDate),
            item.personName,
            item.isLent ? 'Received' : 'Paid',
            rupees(repayment.amountPaise),
            '',
            '',
            '',
            repayment.note ?? '',
          ],
    ]);
  }

  static String _entryStatus(KhataEntryItem item, int today) {
    if (item.isSettled) return 'Settled';
    final due = item.entry.dueDate;
    return due != null && due < today ? 'Overdue' : 'Open';
  }

  static String isoDate(int storedDate) {
    final date = DateTime.fromMillisecondsSinceEpoch(storedDate, isUtc: true);
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String rupees(int paise) {
    final sign = paise < 0 ? '-' : '';
    final value = paise.abs();
    return '$sign${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
  }

  /// RFC 4180 rows with CRLF line ends and a UTF-8 BOM, so Excel shows ₹ and
  /// non-Latin names correctly.
  static String _csv(List<List<String>> rows) =>
      '\uFEFF${rows.map((row) => row.map(field).join(',')).join('\r\n')}\r\n';

  /// Quotes when needed, and neutralises text a spreadsheet would run as a
  /// formula (=, +, -, @) by prefixing an apostrophe.
  static String field(String value) {
    var text = value;
    if (text.isNotEmpty && '=+-@\t\r'.contains(text[0])) text = "'$text";
    if (text.contains(RegExp(r'[",\r\n]'))) {
      text = '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
