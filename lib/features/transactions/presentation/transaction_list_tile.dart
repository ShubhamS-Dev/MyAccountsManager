import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../accounts/accounts_providers.dart';
import '../data/transactions_repository.dart';
import '../transactions_providers.dart';
import 'transaction_copy_actions.dart';

/// Soft-deletes [item] and offers Undo. Returns false if the write failed, so
/// a swipe-to-delete can snap the row back.
Future<bool> moveTransactionToTrash(
  BuildContext context,
  WidgetRef ref,
  TransactionHistoryItem item,
) async {
  // Capture before awaiting. A Dismissible may be removed as soon as
  // confirmDismiss returns true, taking its context with it.
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final transaction = item.transaction;
  try {
    await container
        .read(transactionsRepositoryProvider)
        .softDeleteTransaction(transaction.id);
    container.invalidate(accountBalancePaiseProvider(transaction.accountId));
    if (!messenger.mounted) return true;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Transaction moved to Trash'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await container
                    .read(transactionsRepositoryProvider)
                    .restoreTransaction(transaction.id);
                container.invalidate(
                  accountBalancePaiseProvider(transaction.accountId),
                );
              } catch (_) {
                if (messenger.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Could not restore transaction.'),
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    return true;
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not move transaction to Trash. Try again.'),
        ),
      );
    }
    return false;
  }
}

/// Asks first, then moves [item] to Trash.
Future<void> confirmMoveTransactionToTrash(
  BuildContext context,
  WidgetRef ref,
  TransactionHistoryItem item,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Move to Trash?'),
      content: const Text('You can restore this transaction later from Trash.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Move to Trash'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await moveTransactionToTrash(context, ref, item);
  }
}

/// The standard transaction row used by History and Account Details: category
/// badge, title, metadata, signed amount, overflow actions, swipe to Trash.
class TransactionListTile extends ConsumerWidget {
  const TransactionListTile({
    required this.item,
    super.key,
    this.scheduled = false,
    this.hidden = false,
    this.showAccount = true,
  });

  final TransactionHistoryItem item;
  final bool scheduled;
  final bool hidden;

  /// False on screens already scoped to one account.
  final bool showAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final transaction = item.transaction;
    final income = transaction.type == 'income';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Dismissible(
        key: ValueKey('dismiss-${transaction.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: scheme.onErrorContainer,
          ),
        ),
        confirmDismiss: (_) => moveTransactionToTrash(context, ref, item),
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          onTap: () => context.push('/transaction/${transaction.id}'),
          child: Row(
            children: [
              CategoryIconBadge(
                iconKey: item.categoryIconKey,
                categoryName: item.categoryName,
                colorValue: item.categoryColorValue,
                income: income,
              ),
              const SizedBox(width: AppSpacing.sm),
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
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (scheduled) ...[
                          const ScheduledBadge(),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        if (transaction.recurringRuleId != null) ...[
                          Icon(
                            Icons.repeat_rounded,
                            size: 14,
                            semanticLabel: 'Recurring',
                            color: scheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            showAccount
                                ? '${item.categoryName} · ${item.accountName}'
                                : item.categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.metadata.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AmountText(
                hidden
                    ? hiddenAmountMask
                    : '${income ? '+' : '-'}${MoneyFormatter.formatPaise(transaction.amountPaise)}',
                color: income ? scheme.positiveText : scheme.negativeText,
              ),
              PopupMenuButton<String>(
                tooltip: 'Transaction actions',
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      context.push('/transaction/${transaction.id}/edit');
                    case 'duplicate':
                      duplicateTransaction(
                        context,
                        ref,
                        transactionId: transaction.id,
                        accountId: transaction.accountId,
                      );
                    case 'copy':
                      copyTransactionAsNew(context, transaction.id);
                    case 'trash':
                      confirmMoveTransactionToTrash(context, ref, item);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: _MenuLabel(Icons.edit_outlined, 'Edit'),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: _MenuLabel(
                      Icons.control_point_duplicate_rounded,
                      'Duplicate',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: _MenuLabel(
                      Icons.content_copy_rounded,
                      'Copy as new',
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'trash',
                    child: _MenuLabel(
                      Icons.delete_outline_rounded,
                      'Move to Trash',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: AppSpacing.sm + 4),
      Text(label),
    ],
  );
}
