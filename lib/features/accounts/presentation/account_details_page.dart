import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/transactions_providers.dart';
import '../accounts_providers.dart';

class AccountDetailsPage extends ConsumerWidget {
  const AccountDetailsPage({required this.accountId, super.key});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountByIdProvider(accountId));
    final balance = ref.watch(accountBalancePaiseProvider(accountId));
    final adjustments = ref.watch(balanceAdjustmentsProvider(accountId));
    final filter = TransactionHistoryFilter(accountId: accountId);
    final history = ref.watch(transactionHistoryProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details'),
        actions: [
          IconButton(
            tooltip: 'Edit account',
            onPressed: () => context.push('/accounts/$accountId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Balance adjustments',
            onPressed: () => context.push('/accounts/$accountId/adjustments'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Account could not be loaded.')),
        data: (row) {
          if (row == null) {
            return const Center(child: Text('Account not found.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _BalanceCard(
                name: row.name,
                description: row.description,
                balance: balance,
              ),
              const SizedBox(height: 16),
              const Text(
                'Balance breakdown',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _BreakdownCard(
                openingBalance: row.openingBalancePaise,
                history: history,
                adjustments: adjustments,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Transaction history',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('All history'),
                  ),
                ],
              ),
              history.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => TextButton(
                  onPressed: () =>
                      ref.invalidate(transactionHistoryProvider(filter)),
                  child: const Text('Could not load history. Retry'),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptyHistory();
                  }
                  return Column(
                    children: [
                      for (final item in items.take(30))
                        _TransactionTile(item: item),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/accounts/$accountId/adjustments'),
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Manage balance adjustments'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.name,
    required this.description,
    required this.balance,
  });
  final String name;
  final String? description;
  final AsyncValue<int?> balance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (description?.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(description!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 18),
          Text(
            'CURRENT BALANCE',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 0.7),
          ),
          const SizedBox(height: 5),
          balance.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => const Text('Balance unavailable'),
            data: (value) => Text(
              value == null ? '—' : MoneyFormatter.formatPaise(value),
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: (value ?? 0) < 0 ? colors.error : colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.openingBalance,
    required this.history,
    required this.adjustments,
  });
  final int openingBalance;
  final AsyncValue<List<TransactionHistoryItem>> history;
  final AsyncValue<List<BalanceAdjustmentRow>> adjustments;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: history.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => const Text('Breakdown unavailable.'),
          data: (items) => adjustments.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => const Text('Breakdown unavailable.'),
            data: (rows) {
              final asOfDate = DateOnly.toUtcEpochMilliseconds(DateTime.now());
              final effectiveItems = items.where(
                (item) => item.transaction.transactionDate <= asOfDate,
              );
              final effectiveAdjustments = rows.where(
                (item) => item.adjustmentDate <= asOfDate,
              );
              final income = effectiveItems
                  .where((item) => item.transaction.type == 'income')
                  .fold<int>(
                    0,
                    (sum, item) => sum + item.transaction.amountPaise,
                  );
              final expense = effectiveItems
                  .where((item) => item.transaction.type == 'expense')
                  .fold<int>(
                    0,
                    (sum, item) => sum + item.transaction.amountPaise,
                  );
              final adjustment = effectiveAdjustments.fold<int>(
                0,
                (sum, item) => sum + item.amountPaise,
              );
              return Column(
                children: [
                  _BreakdownRow(
                    label: 'Opening balance',
                    amount: openingBalance,
                  ),
                  _BreakdownRow(
                    label: 'Total income',
                    amount: income,
                    positive: true,
                  ),
                  _BreakdownRow(
                    label: 'Total expenses',
                    amount: -expense,
                    negative: true,
                  ),
                  _BreakdownRow(
                    label: 'Balance adjustments',
                    amount: adjustment,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.amount,
    this.positive = false,
    this.negative = false,
  });
  final String label;
  final int amount;
  final bool positive;
  final bool negative;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = positive
        ? colors.tertiary
        : negative || amount < 0
        ? colors.error
        : colors.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            MoneyFormatter.formatPaise(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item});
  final TransactionHistoryItem item;
  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final income = transaction.type == 'income';
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: income
              ? colors.tertiaryContainer
              : colors.errorContainer,
          child: Icon(
            income ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 16,
            color: income ? colors.tertiary : colors.error,
          ),
        ),
        title: Text(
          transaction.note?.isNotEmpty == true
              ? transaction.note!
              : item.categoryName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${item.categoryName} · ${DateOnly.format(transaction.transactionDate)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '${income ? '+' : '-'}${MoneyFormatter.formatPaise(transaction.amountPaise)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: income ? colors.tertiary : colors.error,
          ),
        ),
        onTap: () => context.push('/transaction/${transaction.id}/edit'),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 28),
    child: Center(
      child: Text('No transactions recorded for this account yet.'),
    ),
  );
}
