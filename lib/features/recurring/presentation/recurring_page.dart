import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/icon_resolvers.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../../core/time/today_provider.dart';
import '../data/recurring_repository.dart';
import '../domain/recurrence.dart';
import '../recurring_providers.dart';

/// Lists recurring series with pause, edit and delete.
class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring transactions'),
        actions: [
          IconButton(
            key: const ValueKey('recurring-help'),
            tooltip: 'How recurring works',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
      body: rules.when(
        loading: () => const SkeletonList(),
        error: (error, stack) => ScreenErrorState(
          message: 'Could not load recurring transactions.',
          onRetry: () => ref.invalidate(recurringRulesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyState(
                  title: 'Nothing on repeat yet',
                  message:
                      'Add a transaction and choose Repeat for rent, salary, '
                      'SIPs or bills. Each one is added for you on its date.',
                  icon: Icons.repeat_rounded,
                  actionLabel: 'Add transaction',
                  onAction: () => context.push('/transaction/new'),
                ),
              ),
            );
          }
          final today = ref.watch(todayProvider);
          // Blocked series add nothing until fixed, so they are not "active".
          final active = items.where(
            (item) => !item.paused && !item.ended && !item.blocked,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              _Summary(active: active.toList()),
              const SizedBox(height: AppSpacing.md),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RuleCard(item: item, today: today),
                ),
            ],
          );
        },
      ),
    );
  }
}

const _helpPoints = <(IconData, String)>[
  (Icons.event_repeat_rounded, 'Added on its date as Scheduled'),
  (Icons.update_rounded, 'Missed dates fill in when you open the app'),
  (Icons.calendar_month_rounded, '31st falls on the last day of short months'),
  (Icons.pause_circle_outline_rounded, 'Paused dates are skipped, not filled'),
  (Icons.delete_outline_rounded, 'Trash an upcoming one to skip that date'),
  (Icons.history_rounded, 'Deleting a series keeps past entries'),
  (Icons.error_outline_rounded, 'Archived Account or hidden category: on hold'),
  (
    Icons.swap_horiz_rounded,
    'New Account, category or frequency? Start a new series',
  ),
];

Future<void> _showHelp(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  builder: (sheetContext) {
    final scheme = Theme.of(sheetContext).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          key: const ValueKey('recurring-help-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How recurring works',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (icon, text) in _helpPoints)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs + 2,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        text,
                        style: AppTypography.supporting.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  },
);

/// Monthly equivalent of active series, so the screen answers "how much is
/// committed each month".
class _Summary extends ConsumerWidget {
  const _Summary({required this.active});

  final List<RecurringRuleItem> active;

  static double _perMonth(RecurringFrequency frequency) => switch (frequency) {
    RecurringFrequency.daily => 365 / 12,
    RecurringFrequency.weekly => 52 / 12,
    RecurringFrequency.monthly => 1,
    RecurringFrequency.yearly => 1 / 12,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(amountsHiddenProvider);
    var outPaise = 0.0;
    var inPaise = 0.0;
    for (final item in active) {
      final monthly = item.rule.amountPaise * _perMonth(item.frequency);
      if (item.rule.type == 'income') {
        inPaise += monthly;
      } else {
        outPaise += monthly;
      }
    }
    String amount(double paise) =>
        hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(paise.round());

    return GradientCard(
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      radius: AppRadius.card,
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              label: 'Out per month',
              value: amount(outPaise),
            ),
          ),
          Expanded(
            child: _SummaryValue(label: 'In per month', value: amount(inPaise)),
          ),
          _SummaryValue(label: 'Active', value: '${active.length}'),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.metadata.copyWith(
          color: Colors.white.withValues(alpha: .82),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.sectionTitle.copyWith(color: Colors.white),
      ),
    ],
  );
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.item, required this.today});

  final RecurringRuleItem item;
  final int today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rule = item.rule;
    final income = rule.type == 'income';
    final accent = income ? scheme.positiveText : scheme.negativeText;
    final color = item.categoryColorValue == null
        ? (income ? AppColors.positive : AppColors.negative)
        : Color(item.categoryColorValue!);
    final upcoming = item.upcomingDate(today);
    final hidden = ref.watch(amountsHiddenProvider);
    final (String status, Color statusColor, IconData statusIcon) = item.blocked
        ? (
            item.accountArchived
                ? 'On hold: Account is archived'
                : 'On hold: category is hidden',
            scheme.error,
            Icons.error_outline_rounded,
          )
        : item.paused
        ? ('Paused', scheme.onSurfaceVariant, Icons.pause_circle_rounded)
        : item.ended || upcoming == null
        ? ('Ended', scheme.onSurfaceVariant, Icons.check_circle_rounded)
        : (
            'Next on ${DateOnly.format(upcoming)}',
            scheme.primary,
            Icons.event_repeat_rounded,
          );

    return Opacity(
      opacity: item.paused || item.ended ? .7 : 1,
      child: AppCard(
        key: ValueKey('recurring-${rule.id}'),
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => _showActions(context, ref, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: resolveCategoryIcon(
                    item.categoryIconKey ?? item.categoryName,
                    income: income,
                  ),
                  color: color,
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.note ?? item.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.fieldValue.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${recurrenceSummary(item.frequency, rule.startDate)}'
                        ' · ${item.accountName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.metadata.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AmountText(
                  hidden
                      ? hiddenAmountMask
                      : '${income ? '+' : '-'}${MoneyFormatter.formatPaise(rule.amountPaise)}',
                  color: accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    status,
                    style: AppTypography.metadata.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (rule.endDate != null && !item.ended)
                  Text(
                    'Until ${DateOnly.format(rule.endDate!)}',
                    style: AppTypography.metadata.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showActions(
  BuildContext context,
  WidgetRef ref,
  RecurringRuleItem item,
) {
  final repository = ref.read(recurringRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final today = ref.read(todayProvider);

  Future<void> run(Future<void> Function() action, String done) async {
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.rule.note ?? item.categoryName,
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!item.ended)
              ActionSheetTile(
                icon: Icons.edit_outlined,
                label: 'Edit amount, note or end date',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditor(context, ref, item);
                },
              ),
            if (!item.ended)
              ActionSheetTile(
                icon: item.paused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                label: item.paused ? 'Resume' : 'Pause',
                onTap: () {
                  Navigator.pop(sheetContext);
                  run(
                    () => item.paused
                        ? repository.resume(item.rule.id, today: today)
                        : repository.pause(item.rule.id, today: today),
                    item.paused ? 'Series resumed' : 'Series paused',
                  );
                },
              ),
            ActionSheetTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete series',
              destructive: true,
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete this series?'),
                    content: const Text(
                      'Past transactions stay in History. The upcoming '
                      'scheduled one is removed and no more are added.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await run(
                    () => repository.delete(item.rule.id, today: today),
                    'Series deleted',
                  );
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showEditor(
  BuildContext context,
  WidgetRef ref,
  RecurringRuleItem item,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
  ),
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: _RuleEditor(item: item),
  ),
);

class _RuleEditor extends ConsumerStatefulWidget {
  const _RuleEditor({required this.item});

  final RecurringRuleItem item;

  @override
  ConsumerState<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<_RuleEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: MoneyFormatter.formatPaise(
      widget.item.rule.amountPaise,
      includeSymbol: false,
    ),
  );
  late final _note = TextEditingController(text: widget.item.rule.note ?? '');
  late int? _endDate = widget.item.rule.endDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickEnd() async {
    final start = DateOnly.fromUtcEpochMilliseconds(widget.item.rule.startDate);
    final current = _endDate == null
        ? DateTime(start.year + 1, start.month, start.day)
        : DateOnly.fromUtcEpochMilliseconds(_endDate!);
    final picked = await showDatePicker(
      context: context,
      helpText: 'Repeat until',
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(start.year, start.month, start.day + 1),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = DateOnly.toUtcEpochMilliseconds(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(recurringRepositoryProvider)
          .update(
            widget.item.rule.id,
            amountPaise: parseAmountPaise(_amount.text)!,
            note: _note.text,
            endDate: _endDate,
            today: ref.read(todayProvider),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save changes.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          children: [
            const Text('Edit series', style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Applies to upcoming transactions. Ones already added keep '
              'their amount and note.',
              style: AppTypography.supporting.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(title: 'Amount'),
            AmountFormField(
              controller: _amount,
              validator: (value) {
                final paise = parseAmountPaise(value ?? '');
                return paise == null || paise <= 0
                    ? 'Enter an amount greater than ₹0.'
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(title: 'Note', hint: 'Optional'),
            TextFormField(
              controller: _note,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(counterText: ''),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(title: 'Ends'),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('No end'),
                  selected: _endDate == null,
                  onSelected: (_) => setState(() => _endDate = null),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.event_rounded, size: 16),
                  label: Text(
                    _endDate == null
                        ? 'Pick end date'
                        : 'Until ${DateOnly.format(_endDate!)}',
                  ),
                  selected: _endDate != null,
                  onSelected: (_) => _pickEnd(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'To change the Account, category or frequency, delete this '
              'series and add a new one.',
              style: AppTypography.metadata.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              FormErrorBanner(_error!),
            ],
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Save changes',
              icon: Icons.check_rounded,
              gradient: AppColors.heroGradient,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
