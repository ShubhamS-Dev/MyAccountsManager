import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../accounts/accounts_providers.dart';
import '../../accounts/presentation/account_balance_label.dart';
import '../../accounts/presentation/accounts_page.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/history_page.dart';
import '../../transactions/transactions_providers.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    _ShellDestination(label: 'Home', icon: Icons.home_rounded),
    _ShellDestination(
      label: 'Accounts',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _ShellDestination(label: 'History', icon: Icons.receipt_long_rounded),
    _ShellDestination(label: 'MyKhata', icon: Icons.people_alt_rounded),
    _ShellDestination(label: 'More', icon: Icons.grid_view_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[_selectedIndex].label),
        actions: [
          IconButton(
            tooltip: 'Activity center',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeDashboardPage(
            onNavigate: (index) => setState(() => _selectedIndex = index),
          ),
          const AccountsPage(),
          const HistoryPage(),
          const _PlaceholderPage(
            title: 'MyKhata',
            description:
                'Track money lent and borrowed independently from your Accounts.',
            icon: Icons.people_outline,
          ),
          const _PlaceholderPage(
            title: 'More',
            description:
                'Budgets, savings goals, reports, backup and settings.',
            icon: Icons.grid_view_outlined,
          ),
        ],
      ),
      floatingActionButton: _selectedIndex < 3
          ? FloatingActionButton(
              onPressed: () => context.push('/transaction/new'),
              tooltip: 'Add transaction',
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                label: destination.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _HomeDashboardPage extends ConsumerStatefulWidget {
  const _HomeDashboardPage({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  ConsumerState<_HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends ConsumerState<_HomeDashboardPage> {
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final hideAmounts = ref.watch(amountsHiddenProvider);
    final now = DateTime.now();
    final monthStart = DateTime.utc(
      now.year,
      now.month,
      1,
    ).millisecondsSinceEpoch;
    final today = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final monthFilter = TransactionHistoryFilter(
      fromDate: monthStart,
      throughDate: today,
    );
    final monthTransactions = ref.watch(
      transactionHistoryProvider(monthFilter),
    );
    final latestTransactions = ref.watch(
      transactionHistoryProvider(const TransactionHistoryFilter()),
    );
    final accounts = ref.watch(activeAccountsProvider);
    final totalBalance = ref.watch(totalActiveBalancePaiseProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        112,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OVERVIEW',
                    style: AppTypography.metadata.copyWith(
                      color: scheme.primary,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text('Your finances', style: AppTypography.screenTitle),
                  Text(
                    '$_greeting 👋',
                    style: AppTypography.supporting.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    'A clear view of your money this month.',
                    style: AppTypography.supporting.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: hideAmounts ? 'Show amounts' : 'Hide amounts',
              onPressed: () => ref.read(amountsHiddenProvider.notifier).state = !hideAmounts,
              icon: Icon(
                hideAmounts
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GradientCard(
          colors: AppColors.heroGradient,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Stack(
            children: [
              const Positioned(
                right: -28,
                top: -36,
                child: _GlowOrb(size: 150),
              ),
              const Positioned(
                right: 48,
                bottom: -66,
                child: _GlowOrb(size: 112),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TOTAL ACCOUNT BALANCE',
                          style: AppTypography.metadata.copyWith(
                            color: Colors.white.withValues(alpha: .78),
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white.withValues(alpha: .8),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  totalBalance.when(
                    loading: () => const SizedBox(
                      height: 42,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    error: (error, stack) => Text(
                      'Balance unavailable',
                      style: AppTypography.transactionAmount.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    data: (value) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        hideAmounts
                            ? '₹ ••••••'
                            : MoneyFormatter.formatPaise(value),
                        key: ValueKey('$hideAmounts-$value'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.balance.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Across active Accounts  ·  MyKhata excluded',
                    style: AppTypography.supporting.copyWith(
                      color: Colors.white.withValues(alpha: .78),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'This month overview',
                      style: AppTypography.metadata.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'This month'),
        const SizedBox(height: AppSpacing.sm),
        monthTransactions.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => const Text('Monthly summary unavailable.'),
          data: (items) {
            var income = 0;
            var expense = 0;
            for (final item in items) {
              if (item.transaction.type == 'income') {
                income += item.transaction.amountPaise;
              } else {
                expense += item.transaction.amountPaise;
              }
            }
            final net = income - expense;
            return Row(
              children: [
                Expanded(
                  child: _MonthMetric(
                    label: 'Income',
                    amount: income,
                    color: AppColors.positive,
                    icon: Icons.south_west_rounded,
                    hidden: hideAmounts,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MonthMetric(
                    label: 'Expenses',
                    amount: expense,
                    color: AppColors.negative,
                    icon: Icons.north_east_rounded,
                    hidden: hideAmounts,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MonthMetric(
                    label: 'Net cash flow',
                    amount: net,
                    color: net < 0 ? AppColors.negative : AppColors.positive,
                    icon: Icons.swap_vert_rounded,
                    hidden: hideAmounts,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Quick actions'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.north_east_rounded,
                label: 'Expense',
                color: AppColors.negative,
                onTap: () => context.push('/transaction/new?type=expense'),
              ),
            ),
            Expanded(
              child: _QuickAction(
                icon: Icons.south_west_rounded,
                label: 'Income',
                color: AppColors.positive,
                onTap: () => context.push('/transaction/new?type=income'),
              ),
            ),
            Expanded(
              child: _QuickAction(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Accounts',
                color: scheme.primary,
                onTap: () => widget.onNavigate(1),
              ),
            ),
            Expanded(
              child: _QuickAction(
                icon: Icons.people_alt_rounded,
                label: 'MyKhata',
                color: AppColors.violet,
                onTap: () => widget.onNavigate(3),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: 'Your Accounts',
          action: 'View all',
          onAction: () => widget.onNavigate(1),
        ),
        const SizedBox(height: AppSpacing.sm),
        accounts.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Text(
            'Accounts unavailable.',
            style: AppTypography.supporting.copyWith(color: scheme.error),
          ),
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                title: 'Start with an account',
                message:
                    'Add a bank, wallet or cash account to see your money in one place.',
                icon: Icons.account_balance_wallet_outlined,
                actionLabel: 'Add account',
                onAction: () => context.push('/accounts/new'),
              );
            }
            final ordered = [
              ...items.where((a) => a.isPinned),
              ...items.where((a) => !a.isPinned),
            ];
            return SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ordered.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final account = ordered[index];
                  final gradient =
                      AppColors.accountGradients[index %
                          AppColors.accountGradients.length];
                  return SizedBox(
                    width: 196,
                    child: GradientCard(
                      colors: gradient,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      radius: AppRadius.card,
                      child: InkWell(
                        onTap: () => context.push('/accounts/${account.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const Spacer(),
                            Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.sectionTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (hideAmounts)
                              Text(
                                '₹ ••••••',
                                style: AppTypography.transactionAmount.copyWith(
                                  color: Colors.white,
                                ),
                              )
                            else
                              DefaultTextStyle(
                                style: AppTypography.transactionAmount.copyWith(
                                  color: Colors.white,
                                ),
                                child: AccountBalanceLabel(
                                  accountId: account.id,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Spending by category'),
        const SizedBox(height: AppSpacing.sm),
        monthTransactions.when(
          loading: () => const SizedBox(
            height: 110,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const SizedBox.shrink(),
          data: (items) {
            final totals = <String, int>{};
            for (final item in items.where(
              (e) => e.transaction.type == 'expense',
            )) {
              totals.update(
                item.categoryName,
                (v) => v + item.transaction.amountPaise,
                ifAbsent: () => item.transaction.amountPaise,
              );
            }
            if (totals.isEmpty) {
              return const AppCard(
                child: EmptyState(
                  title: 'No spending yet',
                  message:
                      'Your category breakdown will appear here after your first expense.',
                  icon: Icons.donut_small_rounded,
                ),
              );
            }
            final entries = totals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final total = entries.fold<int>(
              0,
              (sum, entry) => sum + entry.value,
            );
            final colors = [
              AppColors.primary,
              AppColors.positive,
              AppColors.negative,
              AppColors.violet,
              const Color(0xFFF59E0B),
              const Color(0xFF0EA5E9),
            ];
            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 116,
                    height: 116,
                    child: CustomPaint(
                      painter: _DonutPainter(
                        values: entries.map((e) => e.value.toDouble()).toList(),
                        colors: colors,
                      ),
                      child: Center(
                        child: Text(
                          hideAmounts
                              ? '•••'
                              : MoneyFormatter.formatPaise(total),
                          textAlign: TextAlign.center,
                          style: AppTypography.fieldValue.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < entries.take(4).length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: colors[i % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    entries[i].key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.supporting,
                                  ),
                                ),
                                Text(
                                  hideAmounts
                                      ? '•••'
                                      : MoneyFormatter.formatPaise(
                                          entries[i].value,
                                        ),
                                  style: AppTypography.metadata.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: 'Recent transactions',
          action: 'See history',
          onAction: () => widget.onNavigate(2),
        ),
        const SizedBox(height: AppSpacing.sm),
        latestTransactions.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Text(
            'Transactions unavailable.',
            style: AppTypography.supporting.copyWith(color: scheme.error),
          ),
          data: (items) {
            if (items.isEmpty) {
              return AppCard(
                child: EmptyState(
                  title: 'Nothing here yet',
                  message: 'Your recent income and expenses will show up here.',
                  icon: Icons.receipt_long_rounded,
                  actionLabel: 'Add transaction',
                  onAction: () => context.push('/transaction/new'),
                ),
              );
            }
            final recent = items.take(6).toList();
            return AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    _RecentTransaction(item: recent[i], hidden: hideAmounts),
                    if (i != recent.length - 1)
                      Divider(height: 1, color: scheme.outlineVariant),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          Colors.white.withValues(alpha: .22),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _MonthMetric extends StatelessWidget {
  const _MonthMetric({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.hidden,
  });
  final String label;
  final int amount;
  final Color color;
  final IconData icon;
  final bool hidden;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.metadata.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hidden ? '₹ •••' : MoneyFormatter.formatPaise(amount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.transactionAmount.copyWith(color: color),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: amount == 0 ? 0.08 : .72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.metadata,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecentTransaction extends StatelessWidget {
  const _RecentTransaction({required this.item, required this.hidden});
  final TransactionHistoryItem item;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final income = item.transaction.type == 'income';
    final color = income ? AppColors.positive : AppColors.negative;
    return ListTile(
      minVerticalPadding: 10,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          income ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        item.transaction.note?.isNotEmpty == true
            ? item.transaction.note!
            : item.categoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.fieldValue.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${item.accountName} · ${item.categoryName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.metadata.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        hidden
            ? '••••'
            : '${income ? '+' : '-'}${MoneyFormatter.formatPaise(item.transaction.amountPaise)}',
        style: AppTypography.transactionAmount.copyWith(color: color),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    var start = -1.5708;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 6.28318;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect.deflate(8), start, sweep - .035, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.title,
    required this.description,
    required this.icon,
  });
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.screenTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.supporting,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Feature implementation is pending.',
            textAlign: TextAlign.center,
            style: AppTypography.metadata.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
