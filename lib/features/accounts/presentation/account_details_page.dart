import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/privacy_state.dart';
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
    final hideAmounts = ref.watch(amountsHiddenProvider);
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
            tooltip: hideAmounts ? 'Show amounts' : 'Hide amounts',
            onPressed: () =>
                ref.read(amountsHiddenProvider.notifier).state = !hideAmounts,
            icon: Icon(
              hideAmounts
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _BalanceCard(
                name: row.name,
                description: row.description,
                balance: balance,
                hidden: hideAmounts,
              ),
              const SizedBox(height: 16),
              const Text(
                'Balance breakdown',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 8),
              _BreakdownCard(
                openingBalance: row.openingBalancePaise,
                history: history,
                adjustments: adjustments,
                hidden: hideAmounts,
              ),
              const SizedBox(height: 18),
              const Text(
                'Transaction history',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 8),
              history.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Could not load history.'),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            transactionHistoryProvider(filter),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptyHistory();
                  }
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < items.take(30).length;
                          index++
                        ) ...[
                          _TransactionTile(
                            item: items[index],
                            hidden: hideAmounts,
                          ),
                          if (index != items.take(30).length - 1)
                            Divider(
                              height: 1,
                              indent: 56,
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                        ],
                      ],
                    ),
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
    required this.hidden,
  });
  final String name;
  final String? description;
  final AsyncValue<int?> balance;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF243B75)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
          if (description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'CURRENT BALANCE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          balance.when(
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            error: (error, stack) => const Text(
              'Balance unavailable',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            data: (value) => Text(
              value == null
                  ? '—'
                  : hidden
                  ? '₹ ••••••'
                  : MoneyFormatter.formatPaise(value),
              style: AppTypography.transactionAmount.copyWith(
                color: Colors.white,
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
    required this.hidden,
  });
  final int openingBalance;
  final AsyncValue<List<TransactionHistoryItem>> history;
  final AsyncValue<List<BalanceAdjustmentRow>> adjustments;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    hidden: hidden,
                  ),
                  _BreakdownRow(
                    label: 'Total income',
                    amount: income,
                    positive: true,
                    hidden: hidden,
                  ),
                  _BreakdownRow(
                    label: 'Total expenses',
                    amount: -expense,
                    negative: true,
                    hidden: hidden,
                  ),
                  _BreakdownRow(
                    label: 'Balance adjustments',
                    amount: adjustment,
                    hidden: hidden,
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
    required this.hidden,
  });
  final String label;
  final int amount;
  final bool positive;
  final bool negative;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = positive
        ? colors.tertiary
        : negative || amount < 0
        ? colors.error
        : colors.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.supporting.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            hidden ? '₹ •••' : MoneyFormatter.formatPaise(amount),
            style: AppTypography.transactionAmount.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item, required this.hidden});
  final TransactionHistoryItem item;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final income = transaction.type == 'income';
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        minVerticalPadding: 8,
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
          style: AppTypography.supporting.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${item.categoryName} · ${DateOnly.format(transaction.transactionDate)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          hidden
              ? '••••'
              : '${income ? '+' : '-'}${MoneyFormatter.formatPaise(transaction.amountPaise)}',
          style: TextStyle(
            fontSize: 16,
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: colors.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No transactions recorded for this account yet.',
            textAlign: TextAlign.center,
            style: AppTypography.supporting.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
