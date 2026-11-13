import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../../core/time/today_provider.dart';
import '../../accounts/accounts_providers.dart';
import '../../categories/categories_providers.dart';
import '../transactions_providers.dart';
import 'transaction_copy_actions.dart';

class TransactionDetailsPage extends ConsumerWidget {
  const TransactionDetailsPage({super.key, required this.transactionId});
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(transactionByIdProvider(transactionId));
    final hidden = ref.watch(amountsHiddenProvider);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction details')),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(transactionByIdProvider(transactionId)),
            child: const Text('Could not load transaction. Retry'),
          ),
        ),
        data: (row) {
          if (row == null || row.deletedAt != null) {
            return const Center(
              child: Text(
                'This transaction is unavailable or has been moved to Trash.',
              ),
            );
          }
          final accounts = ref.watch(allAccountsProvider);
          // Include hidden categories so older transactions keep their label.
          final categories = ref.watch(allCategoriesByTypeProvider(row.type));
          final income = row.type == 'income';
          final scheduled = isScheduledDate(
            row.transactionDate,
            ref.watch(todayProvider),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  children: [
                    Icon(
                      income
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      size: 28,
                      color: income ? colors.positiveText : colors.negativeText,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      income ? 'Income' : 'Expense',
                      style: AppTypography.supporting.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AmountText(
                      hidden
                          ? hiddenAmountMask
                          : '${income ? '+' : '-'}${MoneyFormatter.formatPaise(row.amountPaise)}',
                      color: income ? colors.positiveText : colors.negativeText,
                    ),
                    if (scheduled) ...[
                      const SizedBox(height: 8),
                      const ScheduledBadge(),
                      const SizedBox(height: 4),
                      Text(
                        'Counts towards balances from '
                        '${DateOnly.format(row.transactionDate)}.',
                        textAlign: TextAlign.center,
                        style: AppTypography.supporting.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (row.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        row.note!,
                        style: AppTypography.sectionTitle.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                label: 'Account',
                value: accounts.when(
                  data: (v) {
                    final matches = v.where((a) => a.id == row.accountId);
                    return matches.isEmpty ? 'Unavailable' : matches.first.name;
                  },
                  loading: () => 'Loading…',
                  error: (e, s) => 'Unavailable',
                ),
              ),
              _DetailRow(
                label: 'Category',
                value: categories.when(
                  data: (v) {
                    final matches = v.where((c) => c.id == row.categoryId);
                    return matches.isEmpty ? 'Unavailable' : matches.first.name;
                  },
                  loading: () => 'Loading…',
                  error: (e, s) => 'Unavailable',
                ),
              ),
              _DetailRow(
                label: 'Transaction date',
                value: DateOnly.format(row.transactionDate),
              ),
              if (row.recurringRuleId != null)
                ListTile(
                  key: const ValueKey('transaction-recurring'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.repeat_rounded, color: colors.primary),
                  title: Text(
                    'Part of a recurring series',
                    style: AppTypography.supporting.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Changes here affect only this transaction.',
                    style: AppTypography.metadata.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () => context.push('/more/recurring'),
                    child: const Text('Manage'),
                  ),
                ),
              _DetailRow(
                label: 'Created',
                value: AuditTimestamp.formatLocalDate(row.createdAt),
              ),
              _DetailRow(
                label: 'Last updated',
                value: AuditTimestamp.formatLocalDate(row.updatedAt),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push('/transaction/$transactionId/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit transaction'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('transaction-duplicate'),
                      onPressed: () => duplicateTransaction(
                        context,
                        ref,
                        transactionId: row.id,
                        accountId: row.accountId,
                      ),
                      icon: const Icon(Icons.control_point_duplicate_rounded),
                      label: const Text('Duplicate'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('transaction-copy-as-new'),
                      onPressed: () => copyTransactionAsNew(context, row.id),
                      icon: const Icon(Icons.content_copy_rounded),
                      label: const Text('Copy as new'),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Duplicate saves a copy dated today. Copy as new lets you '
                  'change it first.',
                  textAlign: TextAlign.center,
                  style: AppTypography.metadata.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const ValueKey('transaction-delete'),
                  onPressed: () async {
                    final amount = hidden
                        ? hiddenAmountMask
                        : '${income ? '+' : '-'}${MoneyFormatter.formatPaise(row.amountPaise)}';
                    final transactionTitle = row.note?.trim().isNotEmpty == true
                        ? row.note!.trim()
                        : categories.when(
                            data: (v) {
                              final matches = v.where(
                                (c) => c.id == row.categoryId,
                              );
                              return matches.isEmpty
                                  ? 'Transaction'
                                  : matches.first.name;
                            },
                            loading: () => 'Transaction',
                            error: (e, s) => 'Transaction',
                          );
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Delete this transaction?'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              amount,
                              style: AppTypography.transactionAmount.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              transactionTitle,
                              style: AppTypography.body.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final repository = ref.read(transactionsRepositoryProvider);
                    try {
                      await repository.softDeleteTransaction(row.id);
                      if (!context.mounted || !messenger.mounted) return;
                      context.pop();
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: const Text('Transaction moved to trash'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () async {
                                try {
                                  await repository.restoreTransaction(row.id);
                                } catch (_) {
                                  if (messenger.mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not restore transaction.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                    } catch (_) {
                      if (context.mounted && messenger.mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not move transaction to Trash. Try again.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete transaction'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.supporting.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.supporting.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
