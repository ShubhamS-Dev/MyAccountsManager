import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../accounts/accounts_providers.dart';
import '../transactions_providers.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String? _accountId;
  String? _type;
  DateTimeRange? _range;

  int _utcDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch;

  String _money(int paise) {
    final absolute = paise.abs();
    final digits = (absolute ~/ 100).toString();
    final grouped = digits.replaceAllMapped(
        RegExp(r'(?<=\d)(?=(\d{2})+\d{3}$)'), (_) => ',');
    final fraction = absolute % 100;
    return '${paise < 0 ? '-' : ''}₹$grouped${fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}'}';
  }

  String _dateLabel(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _moveToTrash(String transactionId, String accountId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move to Trash?'),
        content:
            const Text('You can restore this transaction later from Trash.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Move to Trash')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .softDeleteTransaction(transactionId);
      ref.invalidate(accountBalancePaiseProvider(accountId));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not move transaction to Trash. Refresh and try again.'))); }
    }
  }

  Future<void> _chooseRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (selected != null) setState(() => _range = selected);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(allAccountsProvider);
    final filter = TransactionHistoryFilter(
      accountId: _accountId,
      fromDate: _range == null ? null : _utcDate(_range!.start),
      throughDate: _range == null ? null : _utcDate(_range!.end),
      type: _type,
    );
    final history = ref.watch(transactionHistoryProvider(filter));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            accounts.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) =>
                  const Text('Account filters unavailable.'),
              data: (rows) => DropdownButtonFormField<String>(
                initialValue: _accountId ?? '__all__',
                decoration: const InputDecoration(
                    labelText: 'Account',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: [
                  const DropdownMenuItem<String>(
                      value: '__all__', child: Text('All Accounts')),
                  for (final account in rows)
                    DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(
                            '${account.name}${account.archivedAt == null ? '' : ' (Archived)'}')),
                ],
                onChanged: (value) => setState(
                    () => _accountId = value == '__all__' ? null : value),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: SegmentedButton<String?>(
                segments: const [
                  ButtonSegment<String?>(value: null, label: Text('All')),
                  ButtonSegment<String?>(
                      value: 'expense', label: Text('Expense')),
                  ButtonSegment<String?>(
                      value: 'income', label: Text('Income')),
                ],
                selected: {_type},
                onSelectionChanged: (value) =>
                    setState(() => _type = value.first),
                showSelectedIcon: false,
              )),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip:
                    _range == null ? 'Filter by date' : 'Change date filter',
                onPressed: _chooseRange,
                icon: const Icon(Icons.date_range_outlined),
              ),
              if (_range != null)
                IconButton(
                    tooltip: 'Clear date filter',
                    onPressed: () => setState(() => _range = null),
                    icon: const Icon(Icons.close)),
            ]),
            if (_range != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      '${_range!.start.day}/${_range!.start.month}/${_range!.start.year} – ${_range!.end.day}/${_range!.end.month}/${_range!.end.year}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/transactions/trash'),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Trash'),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(transactionHistoryProvider(filter)),
                    child: const Text('Could not load history. Retry'))),
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('No transactions match these filters.',
                            textAlign: TextAlign.center)));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final transaction = item.transaction;
                  final isIncome = transaction.type == 'income';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(isIncome
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded),
                      ),
                      title: Text(
                          transaction.note?.isNotEmpty == true
                              ? transaction.note!
                              : item.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${item.categoryName} · ${item.accountName}\n${_dateLabel(transaction.transactionDate)}',
                          maxLines: 2),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isIncome ? '+' : '-'}${_money(transaction.amountPaise)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Transaction actions',
                            onSelected: (action) {
                              if (action == 'edit')
                                context.push(
                                    '/transaction/${transaction.id}/edit')
                              if (action == 'trash')
                                _moveToTrash(
                                    transaction.id, transaction.accountId)
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Edit'))),
                              PopupMenuItem(
                                  value: 'trash',
                                  child: ListTile(
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Move to Trash'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
