import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../accounts_providers.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider);
    return Scaffold(
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Accounts could not be loaded.'),
          FilledButton(onPressed: () => ref.invalidate(activeAccountsProvider), child: const Text('Retry')),
        ])),
        data: (items) {
          if (items.isEmpty) return Center(child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_balance_wallet_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('No Accounts yet', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Create separate spaces for monthly expenses, home, office or a trip.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => context.push('/accounts/new'), icon: const Icon(Icons.add), label: const Text('Create Account')),
            ]),
          ));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
            Text('${items.length} active ${items.length == 1 ? 'Account' : 'Accounts'}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final account in items)
              Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
                title: Text(account.name),
                subtitle: account.description == null ? null : Text(account.description!),
                trailing: account.isPinned ? const Icon(Icons.push_pin, size: 18) : null,
              )),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/accounts/new'), icon: const Icon(Icons.add), label: const Text('Add Account')),
    );
  }
}
