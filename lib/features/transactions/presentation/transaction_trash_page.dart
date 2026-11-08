import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/accounts_providers.dart';
import '../transactions_providers.dart';

class TransactionTrashPage extends ConsumerWidget {
  const TransactionTrashPage({super.key});

  String _money(int paise) {
    final absolute = paise.abs();
    final digits = (absolute ~/ 100).toString();
    final grouped = digits.replaceAllMapped(RegExp(r'(?<=\\d)(?=(\\d{2})+\\d{3}$)'), (_) => ',');
    final fraction = absolute % 100;
    return '${paise < 0 ? '-' : ''}₹$grouped${fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}'}';
  }

  String _dateLabel(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _permanentlyDelete(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: const Text('This transaction will be removed from this device and cannot be recovered.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete permanently')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(transactionsRepositoryProvider).permanentlyDeleteTransaction(id);
      ref.invalidate(transactionTrashProvider);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete this transaction. Refresh and try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(transactionTrashProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Trash')),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: TextButton(onPressed: () => ref.invalidate(transactionTrashProvider), child: const Text('Could not load Trash. Retry'))),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('Trash is empty.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = items[index];
              final transaction = item.transaction;
              final income = transaction.type == 'income';
              return Card(
                child: ListTile(
                  title: Text(transaction.note?.isNotEmpty == true ? transaction.note! : item.categoryName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${item.categoryName} · ${item.accountName}\n${_dateLabel(transaction.transactionDate)} · Deleted ${_dateLabel(transaction.deletedAt!)}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Trash actions',
                    onSelected: (action) async {
                      if (action == 'restore') {
                        try {
                          await ref.read(transactionsRepositoryProvider).restoreTransaction(transaction.id);
                          ref.invalidate(accountBalancePaiseProvider(transaction.accountId));
                          ref.invalidate(transactionTrashProvider);
                        } catch (_) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not restore this transaction. Refresh and try again.')));
                        }
                      } else if (action == 'delete') {
                        await _permanentlyDelete(context, ref, transaction.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'restore', child: ListTile(leading: Icon(Icons.restore), title: Text('Restore'))),
                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever_outlined), title: Text('Delete permanently'))),
                    ],
                  ),
                  leading: CircleAvatar(child: Icon(income ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded)),
                  trailing: Text(
                    '${income ? '+' : '-'}${_money(transaction.amountPaise)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  dense: false,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
