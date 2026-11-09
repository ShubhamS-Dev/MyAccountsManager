import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_formatter.dart';
import '../../accounts/accounts_providers.dart';
import '../../accounts/presentation/accounts_page.dart';
import '../../accounts/presentation/account_balance_label.dart';
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
    _ShellDestination(label: 'Home', icon: Icons.home_outlined),
    _ShellDestination(
      label: 'Accounts',
      icon: Icons.account_balance_wallet_outlined,
    ),
    _ShellDestination(label: 'History', icon: Icons.receipt_long_outlined),
    _ShellDestination(label: 'MyKhata', icon: Icons.people_outline),
    _ShellDestination(label: 'More', icon: Icons.grid_view_outlined),
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
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _HomeFoundationPage(),
          AccountsPage(),
          HistoryPage(),
          _PlaceholderPage(
            title: 'MyKhata',
            description:
                'Track money lent and borrowed independently from your Accounts.',
            icon: Icons.people_outline,
          ),
          _PlaceholderPage(
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
              child: const Icon(Icons.add_rounded),
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

class _HomeFoundationPage extends ConsumerStatefulWidget {
  const _HomeFoundationPage();

  @override
  ConsumerState<_HomeFoundationPage> createState() => _HomeFoundationPageState();
}

class _HomeFoundationPageState extends ConsumerState<_HomeFoundationPage> {
  bool _hideAmounts = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime.utc(now.year, now.month, 1).millisecondsSinceEpoch;
    final today = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;
    final monthFilter = TransactionHistoryFilter(fromDate: monthStart, throughDate: today);
    final monthTransactions = ref.watch(transactionHistoryProvider(monthFilter));
    final latestTransactions = ref.watch(transactionHistoryProvider(const TransactionHistoryFilter()));
    final accounts = ref.watch(activeAccountsProvider);
    final totalBalance = ref.watch(totalActiveBalancePaiseProvider);
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            Expanded(child: Text('Your money, clearly organised.', style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
              tooltip: _hideAmounts ? 'Show amounts' : 'Hide amounts',
              onPressed: () => setState(() => _hideAmounts = !_hideAmounts),
              icon: Icon(_hideAmounts ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          ],
        ),
        Text('A clear view of your finances this month.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL ACCOUNT BALANCE', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: .5)),
                const SizedBox(height: 8),
                totalBalance.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => const Text('Balance unavailable'),
                  data: (value) => Text(_hideAmounts ? '₹ ••••••' : MoneyFormatter.formatPaise(value),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: value < 0 ? colors.error : colors.tertiary)),
                ),
                Text('Across active Accounts · MyKhata excluded', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('This month', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
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
                Expanded(child: _MonthMetric(label: 'Income', amount: income, color: colors.tertiary, hidden: _hideAmounts)),
                const SizedBox(width: 8),
                Expanded(child: _MonthMetric(label: 'Expenses', amount: expense, color: colors.error, hidden: _hideAmounts)),
                const SizedBox(width: 8),
                Expanded(child: _MonthMetric(label: 'Net cash flow', amount: net, color: net < 0 ? colors.error : colors.tertiary, hidden: _hideAmounts)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text('Your Accounts', style: Theme.of(context).textTheme.titleMedium)),
            TextButton(onPressed: () => context.go('/'), child: const Text('')),
          ],
        ),
        accounts.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => const Text('Accounts unavailable.'),
          data: (items) {
            if (items.isEmpty) return const Text('Add an Account to start tracking your money.');
            final pinned = items.where((a) => a.isPinned).toList();
            final rest = items.where((a) => !a.isPinned).toList();
            final ordered = [...pinned, ...rest];
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ordered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.75),
              itemBuilder: (context, index) {
                final account = ordered[index];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push('/accounts/${account.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 18, color: colors.primary),
                          const SizedBox(height: 6),
                          Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          if (_hideAmounts)
                            Text('₹ ••••••', style: Theme.of(context).textTheme.bodySmall)
                          else
                            AccountBalanceLabel(accountId: account.id),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        latestTransactions.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => const Text('Transactions unavailable.'),
          data: (items) {
            if (items.isEmpty) return const Text('Your latest transactions will appear here.');
            return Column(
              children: [
                for (final item in items.take(5))
                  Card(
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: Icon(item.transaction.type == 'income' ? Icons.south_west_rounded : Icons.north_east_rounded,
                        color: item.transaction.type == 'income' ? colors.tertiary : colors.error),
                      title: Text(item.transaction.note?.isNotEmpty == true ? item.transaction.note! : item.categoryName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${item.accountName} · ${item.categoryName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(_hideAmounts ? '••••' : '${item.transaction.type == 'income' ? '+' : '-'}${MoneyFormatter.formatPaise(item.transaction.amountPaise)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: item.transaction.type == 'income' ? colors.tertiary : colors.error)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MonthMetric extends StatelessWidget {
  const _MonthMetric({required this.label, required this.amount, required this.color, required this.hidden});
  final String label;
  final int amount;
  final Color color;
  final bool hidden;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        Text(hidden ? '₹ •••' : MoneyFormatter.formatPaise(amount), maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
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
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Foundation placeholder — feature implementation is pending.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
