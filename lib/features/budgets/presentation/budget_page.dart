import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../notifications/notifications_providers.dart';
import '../../settings/settings_providers.dart';
import '../budget_providers.dart';
import '../domain/budget.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Colour for a budget level, shared with the Home card.
Color budgetLevelColor(ColorScheme scheme, BudgetLevel level) =>
    switch (level) {
      BudgetLevel.onTrack => scheme.primary,
      BudgetLevel.warning => const Color(0xFFF59E0B),
      BudgetLevel.over => scheme.error,
    };

/// One overall monthly spending limit with 80% and 100% alerts.
class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  final _formKey = GlobalKey<FormState>();
  final _limit = TextEditingController();
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save(BudgetStatus? current) async {
    if (!_formKey.currentState!.validate()) return;
    final paise = parseAmountPaise(_limit.text)!;
    setState(() => _saving = true);
    final settings = ref.read(settingsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await settings.setValue(budgetLimitKey, '$paise');
      // What this screen already shows should not also arrive as an alert.
      if (current != null) {
        final status = BudgetStatus(
          limitPaise: paise,
          spentPaise: current.spentPaise,
          date: current.date,
        );
        await settings.setValue(
          budgetAlertedKey(status.date),
          '${status.thresholdReached}',
        );
      }
      messenger.showSnackBar(const SnackBar(content: Text('Budget saved')));
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save budget. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove budget?'),
        content: const Text('Alerts stop until you set a new limit.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(settingsRepositoryProvider).setValue(budgetLimitKey, '0');
    _limit.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(budgetSettingsProvider);
    final status = ref.watch(budgetStatusProvider);
    final spent = ref.watch(monthExpensePaiseProvider).valueOrNull;
    final notificationsOn =
        ref.watch(notificationPreferencesProvider).valueOrNull?.enabled ?? true;

    final limit = settings.valueOrNull?.limitPaise;
    if (!_prefilled && settings.hasValue) {
      _prefilled = true;
      if (limit != null) {
        _limit.text = MoneyFormatter.formatPaise(limit, includeSymbol: false);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Budget Alerts')),
      body: settings.when(
        loading: () => const SkeletonList(rows: 3),
        error: (error, stack) => ScreenErrorState(
          message: 'Could not load your budget.',
          onRetry: () => ref.invalidate(budgetSettingsProvider),
        ),
        data: (budget) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              if (status.valueOrNull case final current?)
                BudgetProgressCard(status: current, large: true)
              else
                _NoBudgetHero(spentPaise: spent),
              const SizedBox(height: AppSpacing.lg),
              const FieldHeading(title: 'Monthly spending limit'),
              AmountFormField(
                key: const ValueKey('budget-limit-input'),
                controller: _limit,
                hint: 'e.g. 50,000',
                validator: (value) {
                  final paise = parseAmountPaise(value ?? '');
                  return paise == null || paise <= 0
                      ? 'Enter a limit greater than ₹0.'
                      : null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: limit == null ? 'Set budget' : 'Update budget',
                icon: Icons.check_rounded,
                gradient: AppColors.heroGradient,
                loading: _saving,
                onPressed: () => _save(status.valueOrNull),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  key: const ValueKey('budget-alerts-switch'),
                  value: budget.alertsEnabled,
                  onChanged: (value) => ref
                      .read(settingsRepositoryProvider)
                      .setValue(budgetAlertsKey, '$value'),
                  title: const Text('Alert at 80% and 100%'),
                  subtitle: Text(
                    notificationsOn
                        ? 'Once each, every month'
                        : 'Notifications are off in More > Notifications',
                  ),
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: scheme.primary,
                  ),
                ),
              ),
              if (!notificationsOn)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.push('/more/notifications'),
                    child: const Text('Open notification settings'),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              const _HowItCounts(),
              if (limit != null) ...[
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton.icon(
                    key: const ValueKey('budget-remove'),
                    onPressed: _remove,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error,
                    ),
                    label: Text(
                      'Remove budget',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoBudgetHero extends ConsumerWidget {
  const _NoBudgetHero({required this.spentPaise});

  final int? spentPaise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(amountsHiddenProvider);
    return GradientCard(
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      radius: AppRadius.card,
      child: Row(
        children: [
          const Icon(Icons.savings_rounded, color: Colors.white, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set one limit for the month',
                  style: AppTypography.sectionTitle.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spentPaise == null
                      ? 'Get a heads-up at 80% and when you go over.'
                      : 'Spent so far this month: '
                            '${hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(spentPaise!)}',
                  style: AppTypography.supporting.copyWith(
                    color: Colors.white.withValues(alpha: .85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spent vs limit with a progress bar. Used on this screen and on Home.
class BudgetProgressCard extends ConsumerWidget {
  const BudgetProgressCard({
    super.key,
    required this.status,
    this.large = false,
    this.onTap,
  });

  final BudgetStatus status;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hidden = ref.watch(amountsHiddenProvider);
    final color = budgetLevelColor(scheme, status.level);
    String money(int paise) =>
        hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(paise);
    final over = status.level == BudgetLevel.over;
    final headline = over
        ? 'Over by ${money(-status.remainingPaise)}'
        : '${money(status.remainingPaise)} left';
    final detail = over
        ? 'Resets on the 1st'
        : '${money(status.dailyAllowancePaise)}/day for ${status.daysLeft} '
              '${status.daysLeft == 1 ? 'day' : 'days'}';

    return AppCard(
      key: const ValueKey('budget-progress-card'),
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: over
                    ? Icons.warning_amber_rounded
                    : Icons.savings_rounded,
                color: color,
                size: large ? 44 : 36,
                iconSize: large ? 22 : 18,
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_monthNames[status.date.month - 1]} budget',
                      style: AppTypography.metadata.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      headline,
                      style:
                          (large
                                  ? AppTypography.screenTitle
                                  : AppTypography.sectionTitle)
                              .copyWith(color: over ? color : scheme.onSurface),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${status.percent}%',
                  style: AppTypography.metadata.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: status.ratio.clamp(0, 1)),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: large ? 10 : 8,
                color: color,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${money(status.spentPaise)} of ${money(status.limitPaise)}',
                  style: AppTypography.metadata.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                detail,
                style: AppTypography.metadata.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItCounts extends StatelessWidget {
  const _HowItCounts();

  static const _points = <(IconData, String)>[
    (Icons.north_east_rounded, 'Expenses from the 1st to today'),
    (Icons.event_rounded, 'Scheduled expenses count on their date'),
    (Icons.block_rounded, "Income and MyKhata don't count"),
    (Icons.restart_alt_rounded, 'Resets on the 1st of each month'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldHeading(title: 'How it counts'),
        for (final (icon, text) in _points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.supporting.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
