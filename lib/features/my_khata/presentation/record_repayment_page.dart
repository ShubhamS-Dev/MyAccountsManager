import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../data/khata_repository.dart';
import '../khata_providers.dart';
import 'khata_widgets.dart';

class RecordRepaymentPage extends ConsumerStatefulWidget {
  const RecordRepaymentPage({required this.entryId, super.key});

  final String entryId;

  @override
  ConsumerState<RecordRepaymentPage> createState() =>
      _RecordRepaymentPageState();
}

class _RecordRepaymentPageState extends ConsumerState<RecordRepaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = _today();
  bool _saving = false;

  // Unsaved-changes tracking for the back-navigation guard.
  late final String _pristine = _snapshot;
  String get _snapshot =>
      [_amountController.text, _noteController.text, _date].join('\u0000');
  bool get _dirty => !_saving && _snapshot != _pristine;
  String? _error;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _fill(int paise) {
    _amountController.text = MoneyFormatter.formatPaise(
      paise,
      includeSymbol: false,
    );
    setState(() {});
  }

  Future<void> _save(KhataEntryItem item) async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseAmountPaise(_amountController.text)!;
    final settles = amount == item.outstandingPaise;
    if (settles) {
      final confirmed = await confirmAction(
        context,
        title: 'Settle this entry?',
        message:
            'This repayment clears the full outstanding amount and marks the '
            'entry as settled.',
        confirmLabel: 'Settle',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(khataRepositoryProvider);
    try {
      final repaymentId = await repository.recordRepayment(
        entryId: widget.entryId,
        amountPaise: amount,
        repaymentDate: DateOnly.toUtcEpochMilliseconds(_date),
        note: _noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settles ? 'Entry settled' : 'Repayment recorded'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repository.deleteRepayment(repaymentId),
          ),
        ),
      );
      context.pop();
    } on StateError catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Repayment could not be saved.';
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      UnsavedChangesGuard(dirty: _dirty, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final entry = ref.watch(khataEntryProvider(widget.entryId));
    final hidden = ref.watch(amountsHiddenProvider);
    String money(int paise) =>
        hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(paise);
    final scheme = Theme.of(context).colorScheme;
    return entry.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Record repayment')),
        body: const SkeletonList(rows: 4),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Record repayment')),
        body: ScreenErrorState(
          message: 'Entry could not be loaded.',
          onRetry: () => ref.invalidate(khataEntryProvider(widget.entryId)),
        ),
      ),
      data: (item) {
        if (item == null || item.isSettled) {
          return Scaffold(
            appBar: AppBar(title: const Text('Record repayment')),
            body: const Center(
              child: EmptyState(
                title: 'Nothing to repay',
                message: 'This entry is settled or no longer exists.',
                icon: Icons.verified_outlined,
              ),
            ),
          );
        }
        final outstanding = item.outstandingPaise;
        final color = khataDirectionColor(context, item.entry.direction);
        final half = (outstanding / 2).floor();
        return Scaffold(
          appBar: AppBar(title: const Text('Record repayment')),
          body: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      IconBadge(
                        icon: khataDirectionIcon(item.entry.direction),
                        color: color,
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.isLent
                                  ? '${item.personName} is paying you back'
                                  : 'You are paying ${item.personName} back',
                              style: AppTypography.fieldValue.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Outstanding ${money(outstanding)} of ${money(item.entry.amountPaise)}',
                              semanticsLabel: maskedAmountSemantics(
                                'Outstanding ${money(outstanding)} of ${money(item.entry.amountPaise)}',
                              ),
                              style: AppTypography.metadata.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const FieldHeading(title: 'Amount'),
                AmountFormField(
                  key: const ValueKey('khata-repayment-amount'),
                  controller: _amountController,
                  autofocus: true,
                  accent: color,
                  validator: (value) {
                    final amount = parseAmountPaise(value ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Enter an amount greater than zero.';
                    }
                    if (amount > outstanding) {
                      return hidden
                          ? 'Cannot exceed the outstanding amount.'
                          : 'Cannot exceed the outstanding ${MoneyFormatter.formatPaise(outstanding)}.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.done_all_rounded, size: 16),
                      label: Text(
                        hidden
                            ? 'Full amount'
                            : 'Full ${MoneyFormatter.formatPaise(outstanding)}',
                        style: AppTypography.button,
                      ),
                      onPressed: () => _fill(outstanding),
                    ),
                    if (half > 0 && half < outstanding)
                      ActionChip(
                        label: Text(
                          hidden
                              ? 'Half'
                              : 'Half ${MoneyFormatter.formatPaise(half)}',
                          style: AppTypography.button,
                        ),
                        onPressed: () => _fill(half),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                DateShortcutField(
                  title: 'Repayment date',
                  date: _date,
                  firstDate: localDateFromStored(item.entry.entryDate),
                  onChanged: (date) => setState(() => _date = date),
                ),
                const SizedBox(height: AppSpacing.lg),
                const FieldHeading(title: 'Note', hint: 'Optional'),
                TextFormField(
                  controller: _noteController,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Paid via UPI',
                    counterText: '',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FormErrorBanner(_error!),
                ],
              ],
            ),
          ),
          bottomNavigationBar: StickyActionBar(
            child: PrimaryButton(
              label: 'Save repayment',
              icon: Icons.check_rounded,
              gradient: AppColors.heroGradient,
              loading: _saving,
              onPressed: () => _save(item),
            ),
          ),
        );
      },
    );
  }
}
