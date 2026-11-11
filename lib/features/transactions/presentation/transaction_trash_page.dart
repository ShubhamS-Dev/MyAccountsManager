import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/icon_resolvers.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../accounts/accounts_providers.dart';
import '../data/transactions_repository.dart';
import '../transactions_providers.dart';

class TransactionTrashPage extends ConsumerWidget {
  const TransactionTrashPage({super.key});

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    TransactionHistoryItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .restoreTransaction(item.transaction.id);
      ref.invalidate(accountBalancePaiseProvider(item.transaction.accountId));
      ref.invalidate(transactionTrashProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction restored to History')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not restore this transaction. Refresh and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _permanentlyDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Delete permanently?',
      message:
          'This transaction will be removed from this device and cannot be recovered.',
      confirmLabel: 'Delete permanently',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .permanentlyDeleteTransaction(id);
      ref.invalidate(transactionTrashProvider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not delete this transaction. Refresh and try again.',
          ),
        ),
      );
    }
  }

  void _showActions(
    BuildContext context,
    WidgetRef ref,
    TransactionHistoryItem item,
  ) {
    showActionSheet(
      context,
      title: item.transaction.note?.isNotEmpty == true
          ? item.transaction.note!
          : item.categoryName,
      actions: (sheetContext) => [
        ActionSheetTile(
          icon: Icons.restore_rounded,
          label: 'Restore',
          subtitle: 'Return it to History and Account balances',
          onTap: () {
            Navigator.pop(sheetContext);
            _restore(context, ref, item);
          },
        ),
        ActionSheetTile(
          icon: Icons.delete_forever_outlined,
          label: 'Delete permanently',
          destructive: true,
          onTap: () {
            Navigator.pop(sheetContext);
            _permanentlyDelete(context, ref, item.transaction.id);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(transactionTrashProvider);
    final hidden = ref.watch(amountsHiddenProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Trash')),
      body: trash.when(
        loading: () => const SkeletonList(),
        error: (error, stack) => ScreenErrorState(
          message: 'Could not load Trash.',
          onRetry: () => ref.invalidate(transactionTrashProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: EmptyState(
                title: 'Trash is empty',
                message:
                    'Transactions you move to Trash appear here until you restore or delete them.',
                icon: Icons.delete_outline_rounded,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm + 4),
                child: Row(
                  children: [
                    IconBadge(
                      icon: Icons.info_outline_rounded,
                      color: scheme.primary,
                      size: 36,
                      iconSize: 17,
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        '${items.length} ${items.length == 1 ? 'transaction' : 'transactions'} in Trash. They do not count towards balances. Tap one to restore or delete it.',
                        style: AppTypography.supporting.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (index, item) in items.indexed) ...[
                      if (index > 0) const Divider(height: 1),
                      _TrashRow(
                        item: item,
                        hidden: hidden,
                        onTap: () => _showActions(context, ref, item),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.item,
    required this.hidden,
    required this.onTap,
  });

  final TransactionHistoryItem item;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final transaction = item.transaction;
    final income = transaction.type == 'income';
    final semantic = income ? scheme.positiveText : scheme.negativeText;
    final categoryColor = item.categoryColorValue == null
        ? semantic
        : Color(item.categoryColorValue!);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            IconBadge(
              icon: resolveCategoryIcon(
                item.categoryIconKey ?? item.categoryName,
                income: income,
              ),
              color: categoryColor,
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.note?.isNotEmpty == true
                        ? transaction.note!
                        : item.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.fieldValue.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.accountName} · ${DateOnly.format(transaction.transactionDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metadata.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Deleted ${AuditTimestamp.formatLocalDate(transaction.deletedAt!)}',
                    style: AppTypography.metadata.copyWith(color: scheme.error),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AmountText(
              hidden
                  ? hiddenAmountMask
                  : '${income ? '+' : '-'}${MoneyFormatter.formatPaise(transaction.amountPaise)}',
              color: semantic,
            ),
          ],
        ),
      ),
    );
  }
}
