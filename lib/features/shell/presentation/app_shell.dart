import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../accounts/presentation/accounts_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    _ShellDestination(label: 'Home', icon: Icons.home_outlined),
    _ShellDestination(label: 'Accounts', icon: Icons.account_balance_wallet_outlined),
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
          _PlaceholderPage(
            title: 'History',
            description: 'Income, expenses and balance adjustments will appear here.',
            icon: Icons.receipt_long_outlined,
          ),
          _PlaceholderPage(
            title: 'MyKhata',
            description: 'Track money lent and borrowed independently from your Accounts.',
            icon: Icons.people_outline,
          ),
          _PlaceholderPage(
            title: 'More',
            description: 'Budgets, savings goals, reports, backup and settings.',
            icon: Icons.grid_view_outlined,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transaction/new'),
        tooltip: 'Add transaction',
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
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

class _HomeFoundationPage extends StatelessWidget {
  const _HomeFoundationPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Text(
          'Your money, clearly organised.',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'A private, offline space for your finances.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        const _SummaryCard(),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your data stays on this device. No account or cloud sync required.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Getting started', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const _GettingStartedCard(),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total balance', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              '₹0.00',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Balances will appear after you create an Account.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 28),
            const SizedBox(height: 12),
            Text(
              'Create your first Account',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Accounts are separate spaces for tracking things like monthly expenses, home, office or a trip.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Open the Accounts tab to create and manage your financial spaces.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
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
