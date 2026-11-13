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

/// Records a repayment against one entry, or a single payment from a person
/// that settles their open entries oldest first. A payment above what is due
/// becomes a new opposite-direction entry once the user confirms it.
class RecordRepaymentPage extends ConsumerStatefulWidget {
  const RecordRepaymentPage({required String this.entryId, super.key})
    : personId = null,
      initialDirection = null;

  const RecordRepaymentPage.forPerson({
    required String this.personId,
    this.initialDirection,
    super.key,
  }) : entryId = null;

  final String? entryId;
  final String? personId;

  /// `lent`: they pay you back. `borrowed`: you pay them back.
  final String? initialDirection;

  @override
  ConsumerState<RecordRepaymentPage> createState() =>
      _RecordRepaymentPageState();
}

class _RecordRepaymentPageState extends ConsumerState<RecordRepaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = _today();
  String? _direction;
  bool _saving = false;

  // Unsaved-changes tracking for the back-navigation guard.
  late final String _pristine = _snapshot;
  String get _snapshot =>
      [_amountController.text, _noteController.text, _date].join('\u0000');
  bool get _dirty => !_saving && _snapshot != _pristine;
  String? _error;

  bool get _forEntry => widget.entryId != null;
  String get _title => _forEntry ? 'Record repayment' : 'Record payment';

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
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

  int get _paymentDate => DateOnly.toUtcEpochMilliseconds(_date);

  KhataPaymentPlan _plan(List<KhataEntryItem> entries, String direction) =>
      planKhataPayment(
        entries: entries,
        direction: direction,
        amountPaise: parseAmountPaise(_amountController.text) ?? 0,
        paymentDate: _paymentDate,
      );

  Future<void> _save({
    required List<KhataEntryItem> entries,
    required String direction,
    required String personId,
    required String personName,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    final hidden = ref.read(amountsHiddenProvider);
    String money(int paise) =>
        hidden ? 'The extra amount' : MoneyFormatter.formatPaise(paise);
    final amount = parseAmountPaise(_amountController.text)!;
    final plan = _plan(entries, direction);
    final open = entries.where(
      (item) => !item.isSettled && item.entry.direction == direction,
    );
    final settlesAll = plan.settledCount == open.length;
    if (plan.excessPaise > 0) {
      final confirmed = await confirmAction(
        context,
        title: 'More than the amount due',
        message:
            '${money(plan.excessPaise)} is more than what is due. Everything '
            'due will be settled and the extra recorded as a new entry: '
            '${direction == khataLent ? 'you owe $personName' : '$personName owes you'}.',
        confirmLabel: 'Record extra',
      );
      if (!confirmed || !mounted) return;
    } else if (settlesAll) {
      final confirmed = await confirmAction(
        context,
        title: open.length == 1
            ? 'Settle this entry?'
            : 'Settle ${open.length} entries?',
        message:
            'This payment clears the full outstanding amount and marks '
            '${open.length == 1 ? 'the entry' : 'every open entry'} as settled.',
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
      final result = await repository.recordPayment(
        personId: personId,
        entryId: widget.entryId,
        direction: direction,
        amountPaise: amount,
        paymentDate: _paymentDate,
        note: _noteController.text,
        allowExcess: plan.excessPaise > 0,
      );
      if (!mounted) return;
      final message = result.excessEntryId != null
          ? 'Settled, extra saved as a new entry'
          : settlesAll
          ? (result.settledCount == 1 ? 'Entry settled' : 'All entries settled')
          : 'Payment recorded';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repository.undoPayment(result),
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
        _error = 'Payment could not be saved.';
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      UnsavedChangesGuard(dirty: _dirty, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final AsyncValue<List<KhataEntryItem>> entries = _forEntry
        ? ref
              .watch(khataEntryProvider(widget.entryId!))
              .whenData((item) => [?item])
        : ref.watch(khataEntriesProvider(widget.personId));
    return entries.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: const SkeletonList(rows: 4),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: ScreenErrorState(
          message: 'Entries could not be loaded.',
          onRetry: () => _forEntry
              ? ref.invalidate(khataEntryProvider(widget.entryId!))
              : ref.invalidate(khataEntriesProvider(widget.personId)),
        ),
      ),
      data: (items) {
        final open = items.where((item) => !item.isSettled).toList();
        final directions = [
          for (final direction in const [khataLent, khataBorrowed])
            if (open.any((item) => item.entry.direction == direction))
              direction,
        ];
        if (directions.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(_title)),
            body: const Center(
              child: EmptyState(
                title: 'Nothing to repay',
                message: 'Everything is settled or no longer exists.',
                icon: Icons.verified_outlined,
              ),
            ),
          );
        }
        final direction = directions.contains(_direction)
            ? _direction!
            : directions.first;
        return _buildForm(context, items, open, directions, direction);
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<KhataEntryItem> items,
    List<KhataEntryItem> open,
    List<String> directions,
    String direction,
  ) {
    final hidden = ref.watch(amountsHiddenProvider);
    String money(int paise) =>
        hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(paise);
    final scheme = Theme.of(context).colorScheme;
    final color = khataDirectionColor(context, direction);
    final mine = open
        .where((item) => item.entry.direction == direction)
        .toList();
    final personName = mine.first.personName;
    final personId = mine.first.entry.personId;
    final totalDue = mine.fold(0, (sum, item) => sum + item.outstandingPaise);
    final oldest = mine
        .map((item) => item.entry.entryDate)
        .reduce((a, b) => a < b ? a : b);
    // Only entries dated on or before the payment date can take a share.
    final dueByDate = planKhataPayment(
      entries: items,
      direction: direction,
      amountPaise: khataMaxAmountPaise,
      paymentDate: _paymentDate,
    ).appliedPaise;
    final half = (dueByDate / 2).floor();
    final amount = parseAmountPaise(_amountController.text);
    final plan = amount == null || amount <= 0 ? null : _plan(items, direction);
    final lent = direction == khataLent;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
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
            if (directions.length > 1) ...[
              AppSegmentedControl<String>(
                key: const ValueKey('khata-payment-direction'),
                selected: direction,
                onChanged: (value) => setState(() => _direction = value),
                options: [
                  SegmentOption(
                    value: khataLent,
                    label: 'They paid you',
                    icon: Icons.south_west_rounded,
                    color: scheme.positiveText,
                  ),
                  SegmentOption(
                    value: khataBorrowed,
                    label: 'You paid them',
                    icon: Icons.north_east_rounded,
                    color: scheme.negativeText,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppCard(
              child: Row(
                children: [
                  IconBadge(icon: khataDirectionIcon(direction), color: color),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lent
                              ? '$personName is paying you back'
                              : 'You are paying $personName back',
                          style: AppTypography.fieldValue.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final text = _forEntry
                                ? 'Outstanding ${money(totalDue)} of ${money(mine.first.entry.amountPaise)}'
                                : 'Due ${money(totalDue)} across ${mine.length} ${mine.length == 1 ? 'entry' : 'entries'}';
                            return Text(
                              text,
                              semanticsLabel: maskedAmountSemantics(text),
                              style: AppTypography.metadata.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            );
                          },
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
                if (amount > khataMaxAmountPaise) {
                  return 'Amount is too large.';
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
                    hidden ? 'Full amount' : 'Full ${money(dueByDate)}',
                    style: AppTypography.button,
                  ),
                  onPressed: () => _fill(dueByDate),
                ),
                if (half > 0 && half < dueByDate)
                  ActionChip(
                    label: Text(
                      hidden ? 'Half' : 'Half ${money(half)}',
                      style: AppTypography.button,
                    ),
                    onPressed: () => _fill(half),
                  ),
              ],
            ),
            if (plan != null) ...[
              const SizedBox(height: AppSpacing.md),
              _PaymentPreview(
                plan: plan,
                hidden: hidden,
                excessLabel: lent
                    ? 'Extra: you will owe $personName'
                    : 'Extra: $personName will owe you',
                showEntries: !_forEntry,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            DateShortcutField(
              title: lent ? 'Received on' : 'Paid on',
              date: _date,
              firstDate: localDateFromStored(oldest),
              lastDate: _today(),
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
          label: _forEntry ? 'Save repayment' : 'Save payment',
          icon: Icons.check_rounded,
          gradient: AppColors.heroGradient,
          loading: _saving,
          onPressed: () => _save(
            entries: items,
            direction: direction,
            personId: personId,
            personName: personName,
          ),
        ),
      ),
    );
  }
}

/// Shows how the typed amount will be applied before it is saved.
class _PaymentPreview extends StatelessWidget {
  const _PaymentPreview({
    required this.plan,
    required this.hidden,
    required this.excessLabel,
    required this.showEntries,
  });

  final KhataPaymentPlan plan;
  final bool hidden;
  final String excessLabel;
  final bool showEntries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String money(int paise) =>
        hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(paise);
    final style = AppTypography.metadata.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final rows = <Widget>[
      if (showEntries)
        for (final allocation in plan.allocations)
          _PreviewRow(
            label:
                '${allocation.paise == allocation.item.outstandingPaise ? 'Settles' : 'Part of'} '
                '${DateOnly.format(allocation.item.entry.entryDate)}'
                '${allocation.item.entry.note == null ? '' : ' · ${allocation.item.entry.note}'}',
            amount: money(allocation.paise),
            style: style,
          ),
      if (plan.excessPaise > 0)
        _PreviewRow(
          label: excessLabel,
          amount: money(plan.excessPaise),
          style: style.copyWith(
            color: scheme.negativeText,
            fontWeight: FontWeight.w700,
          ),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('khata-payment-preview'),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'HOW THIS IS APPLIED',
            style: AppTypography.metadata.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...rows,
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.amount,
    required this.style,
  });

  final String label;
  final String amount;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AmountText(amount, style: style),
      ],
    ),
  );
}
