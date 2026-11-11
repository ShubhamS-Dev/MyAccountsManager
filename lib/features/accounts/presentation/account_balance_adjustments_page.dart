import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../accounts_providers.dart';

class AccountBalanceAdjustmentsPage extends ConsumerStatefulWidget {
  const AccountBalanceAdjustmentsPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountBalanceAdjustmentsPage> createState() =>
      _AccountBalanceAdjustmentsPageState();
}

class _AccountBalanceAdjustmentsPageState
    extends ConsumerState<AccountBalanceAdjustmentsPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime _date = _today();
  bool _increase = true;
  bool _saving = false;

  // Unsaved-changes tracking for the back-navigation guard.
  late final String _pristine = _snapshot;
  String get _snapshot =>
      [_amountController.text, _reasonController.text].join('\u0000');
  bool get _dirty => !_saving && _snapshot != _pristine;
  String? _error;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _signed(int paise) =>
      '${paise > 0 ? '+' : ''}${MoneyFormatter.formatPaise(paise)}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final magnitude = parseAmountPaise(_amountController.text);
    if (magnitude == null || magnitude == 0) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(accountsRepositoryProvider)
          .createBalanceAdjustment(
            accountId: widget.accountId,
            amountPaise: _increase ? magnitude : -magnitude,
            reason: _reasonController.text,
            adjustmentDate: DateOnly.toUtcEpochMilliseconds(_date),
          );
      if (!mounted) return;
      ref.invalidate(accountBalancePaiseProvider(widget.accountId));
      _amountController.clear();
      _reasonController.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _date = _today();
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Adjustment saved')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save adjustment. Check the amount and Account status.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      UnsavedChangesGuard(dirty: _dirty, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final account = ref.watch(accountByIdProvider(widget.accountId));
    final adjustments = ref.watch(balanceAdjustmentsProvider(widget.accountId));
    final balance = ref.watch(accountBalancePaiseProvider(widget.accountId));
    final hidden = ref.watch(amountsHiddenProvider);
    final scheme = Theme.of(context).colorScheme;
    final accent = _increase ? scheme.positiveText : scheme.negativeText;

    return Scaffold(
      appBar: AppBar(title: const Text('Balance adjustments')),
      body: account.when(
        loading: () => const SkeletonList(rows: 5),
        error: (error, stack) => ScreenErrorState(
          message: 'Account could not be loaded.',
          onRetry: () => ref.invalidate(accountByIdProvider(widget.accountId)),
        ),
        data: (row) {
          if (row == null) {
            return const Center(
              child: EmptyState(
                title: 'Account not found',
                message: 'It may have been removed from this device.',
                icon: Icons.search_off_rounded,
              ),
            );
          }
          final isArchived = row.archivedAt != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              GradientCard(
                padding: const EdgeInsets.all(AppSpacing.md + 4),
                radius: AppRadius.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metadata.copyWith(
                        color: Colors.white.withValues(alpha: .78),
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AmountText(
                      hidden
                          ? hiddenAmountMask
                          : balance.whenOrNull(
                                  data: (value) =>
                                      MoneyFormatter.formatPaise(value ?? 0),
                                ) ??
                                '…',
                      style: AppTypography.transactionAmount.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Current balance · corrections never change the opening balance',
                      style: AppTypography.supporting.copyWith(
                        color: Colors.white.withValues(alpha: .78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isArchived)
                AppCard(
                  child: Row(
                    children: [
                      IconBadge(
                        icon: Icons.archive_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      const Expanded(
                        child: Text(
                          'This Account is archived. Restore it before adding a balance adjustment.',
                          style: AppTypography.supporting,
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  child: Form(
                    key: _formKey,
                    onChanged: () => setState(() {}),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'New adjustment',
                          style: AppTypography.sectionTitle,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppSegmentedControl<bool>(
                          selected: _increase,
                          onChanged: (value) =>
                              setState(() => _increase = value),
                          options: [
                            SegmentOption(
                              value: true,
                              label: 'Increase',
                              icon: Icons.add_rounded,
                              color: scheme.positiveText,
                            ),
                            SegmentOption(
                              value: false,
                              label: 'Decrease',
                              icon: Icons.remove_rounded,
                              color: scheme.negativeText,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const FieldHeading(title: 'Amount'),
                        AmountFormField(
                          controller: _amountController,
                          accent: accent,
                          validator: (value) {
                            final amount = parseAmountPaise(value ?? '');
                            return amount == null || amount == 0
                                ? 'Enter a non-zero amount.'
                                : null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const FieldHeading(title: 'Reason'),
                        TextFormField(
                          controller: _reasonController,
                          maxLength: 500,
                          minLines: 1,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Why is this balance being corrected?',
                            counterText: '',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a reason for the adjustment.'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DateShortcutField(
                          title: 'Adjustment date',
                          date: _date,
                          onChanged: (date) => setState(() => _date = date),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          FormErrorBanner(_error!),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        PrimaryButton(
                          label: 'Save adjustment',
                          icon: Icons.check_rounded,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Adjustment history'),
              const SizedBox(height: AppSpacing.sm),
              adjustments.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => ScreenErrorState(
                  message: 'Could not load adjustments.',
                  onRetry: () => ref.invalidate(
                    balanceAdjustmentsProvider(widget.accountId),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const AppCard(
                      child: EmptyState(
                        title: 'No adjustments yet',
                        message:
                            'Corrections you record will be listed here with their reason.',
                        icon: Icons.tune_rounded,
                      ),
                    );
                  }
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (index, item) in items.indexed) ...[
                          if (index > 0) const Divider(height: 1),
                          _AdjustmentRow(
                            reason: item.reason,
                            date: DateOnly.format(item.adjustmentDate),
                            amount: hidden
                                ? hiddenAmountMask
                                : _signed(item.amountPaise),
                            positive: item.amountPaise > 0,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({
    required this.reason,
    required this.date,
    required this.amount,
    required this.positive,
  });

  final String reason;
  final String date;
  final String amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = positive ? scheme.positiveText : scheme.negativeText;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          IconBadge(
            icon: positive ? Icons.add_rounded : Icons.remove_rounded,
            color: color,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.fieldValue.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: AppTypography.metadata.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AmountText(amount, color: color),
        ],
      ),
    );
  }
}
