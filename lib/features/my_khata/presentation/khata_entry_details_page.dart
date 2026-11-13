import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../data/khata_repository.dart';
import '../khata_providers.dart';
import 'khata_widgets.dart';

class KhataEntryDetailsPage extends ConsumerWidget {
  const KhataEntryDetailsPage({required this.entryId, super.key});

  final String entryId;

  Future<void> _deleteEntry(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Delete entry?',
      message: 'This entry will be removed from the ledger.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(khataRepositoryProvider).deleteEntry(entryId);
      router.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Entry deleted')));
    } on StateError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteRepayment(
    BuildContext context,
    WidgetRef ref,
    KhataRepaymentRow repayment, {
    required bool reopens,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: reopens ? 'Remove repayment and reopen?' : 'Remove repayment?',
      message:
          '${ref.read(amountsHiddenProvider) ? 'This repayment' : MoneyFormatter.formatPaise(repayment.amountPaise)} will be added back to the outstanding amount.'
          '${reopens ? ' The entry will be open again.' : ''}',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(khataRepositoryProvider).deleteRepayment(repayment.id);
    } on StateError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _topUp(
    BuildContext context,
    WidgetRef ref,
    KhataEntryItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _TopUpDialog(item: item),
    );
    if (amount == null) return;
    try {
      await ref
          .read(khataRepositoryProvider)
          .topUpEntry(entryId: entryId, amountPaise: amount);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ref.read(amountsHiddenProvider)
                ? 'Amount added'
                : '${MoneyFormatter.formatPaise(amount)} added',
          ),
        ),
      );
    } on StateError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on ArgumentError {
      messenger.showSnackBar(
        const SnackBar(content: Text('That amount is too large.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(khataEntryProvider(entryId));
    final repayments = ref.watch(khataRepaymentsProvider(entryId));
    final hidden = ref.watch(amountsHiddenProvider);
    final scheme = Theme.of(context).colorScheme;
    String money(int paise) =>
        hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(paise);

    return Scaffold(
      appBar: AppBar(title: const Text('Entry details')),
      body: entry.when(
        loading: () => const SkeletonList(rows: 5),
        error: (error, stack) => ScreenErrorState(
          message: 'Entry could not be loaded.',
          onRetry: () => ref.invalidate(khataEntryProvider(entryId)),
        ),
        data: (item) {
          if (item == null) {
            return const Center(
              child: EmptyState(
                title: 'Entry not found',
                message: 'It may have been deleted.',
                icon: Icons.search_off_rounded,
              ),
            );
          }
          final row = item.entry;
          final color = khataDirectionColor(context, row.direction);
          final overdue = isOverdue(item);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md + 4),
                child: Column(
                  children: [
                    IconBadge(
                      icon: item.isSettled
                          ? Icons.verified_rounded
                          : khataDirectionIcon(row.direction),
                      color: item.isSettled ? scheme.positiveText : color,
                      size: 52,
                      iconSize: 26,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.isSettled
                          ? 'Settled'
                          : row.direction == khataLent
                          ? '${item.personName} owes you'
                          : 'You owe ${item.personName}',
                      style: AppTypography.supporting.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AmountText(
                      money(
                        item.isSettled
                            ? row.amountPaise
                            : item.outstandingPaise,
                      ),
                      color: item.isSettled ? scheme.onSurface : color,
                      style: AppTypography.balance.copyWith(fontSize: 28),
                    ),
                    if (overdue) ...[
                      const SizedBox(height: AppSpacing.xs),
                      StatusPill(
                        label: 'Overdue',
                        color: scheme.negativeText,
                        icon: Icons.schedule_rounded,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    RepaymentProgressBar(
                      repaid: item.repaidPaise,
                      total: row.amountPaise,
                      color: item.isSettled ? scheme.positiveText : color,
                      height: 7,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Repaid ${money(item.repaidPaise)}',
                            semanticsLabel: hidden
                                ? 'Repaid amount hidden'
                                : null,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.metadata.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            'of ${money(row.amountPaise)}',
                            semanticsLabel: hidden ? 'of amount hidden' : null,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
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
              const SizedBox(height: AppSpacing.md),
              if (!item.isSettled) ...[
                PrimaryButton(
                  label: 'Record repayment',
                  icon: Icons.payments_outlined,
                  gradient: AppColors.heroGradient,
                  onPressed: () =>
                      context.push('/khata/entries/$entryId/repay'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('khata-entry-add-more'),
                        onPressed: () => _topUp(context, ref, item),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add more'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/khata/entries/$entryId/edit'),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: item.repaidPaise > 0
                            ? null
                            : () => _deleteEntry(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _DetailRow(label: 'Person', value: item.personName),
                    const Divider(height: 1),
                    _DetailRow(
                      label: 'Type',
                      value: row.direction == khataLent
                          ? 'You gave (lent)'
                          : 'You got (borrowed)',
                      valueColor: color,
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      label: 'Date',
                      value: DateOnly.format(row.entryDate),
                    ),
                    if (row.dueDate != null) ...[
                      const Divider(height: 1),
                      _DetailRow(
                        label: 'Due date',
                        value: DateOnly.format(row.dueDate!),
                        valueColor: overdue ? scheme.negativeText : null,
                      ),
                    ],
                    if (row.note != null) ...[
                      const Divider(height: 1),
                      _DetailRow(label: 'Note', value: row.note!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Repayments'),
              const SizedBox(height: AppSpacing.sm),
              repayments.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => ScreenErrorState(
                  message: 'Repayments could not be loaded.',
                  onRetry: () =>
                      ref.invalidate(khataRepaymentsProvider(entryId)),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const AppCard(
                      child: EmptyState(
                        title: 'No repayments yet',
                        message:
                            'Partial and full repayments will appear here.',
                        icon: Icons.history_rounded,
                      ),
                    );
                  }
                  // On a settled entry only the latest repayment is removable.
                  final latest = rows.reduce(
                    (a, b) => b.createdAt > a.createdAt ? b : a,
                  );
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (index, repayment) in rows.indexed) ...[
                          if (index > 0) const Divider(height: 1, indent: 64),
                          ListTile(
                            minTileHeight: 56,
                            leading: IconBadge(
                              icon: Icons.payments_outlined,
                              color: scheme.positiveText,
                              size: 36,
                              iconSize: 17,
                            ),
                            title: AmountText(
                              money(repayment.amountPaise),
                              color: scheme.positiveText,
                            ),
                            subtitle: Text(
                              [
                                DateOnly.format(repayment.repaymentDate),
                                if (repayment.note != null) repayment.note!,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.metadata.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: item.isSettled && repayment != latest
                                ? null
                                : IconButton(
                                    tooltip: 'Remove repayment',
                                    onPressed: () => _deleteRepayment(
                                      context,
                                      ref,
                                      repayment,
                                      reopens: item.isSettled,
                                    ),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              if (item.isSettled) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Settled entries are locked. Remove the latest repayment to reopen.',
                  textAlign: TextAlign.center,
                  style: AppTypography.metadata.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: AppTypography.supporting.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.fieldValue.copyWith(
                color: valueColor ?? scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks how much to add to an open entry; pops the amount in paise.
class _TopUpDialog extends StatefulWidget {
  const _TopUpDialog({required this.item});

  final KhataEntryItem item;

  @override
  State<_TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends State<_TopUpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, parseAmountPaise(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AlertDialog(
      title: Text(
        item.isLent
            ? 'Add more lent to ${item.personName}'
            : 'Add more borrowed from ${item.personName}',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Increases this entry and what is outstanding on it.',
              style: AppTypography.supporting.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AmountFormField(
              key: const ValueKey('khata-top-up-amount'),
              controller: _controller,
              autofocus: true,
              accent: khataDirectionColor(context, item.entry.direction),
              validator: (value) {
                final amount = parseAmountPaise(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter an amount greater than zero.';
                }
                if (amount + item.entry.amountPaise > khataMaxAmountPaise) {
                  return 'Amount is too large.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
