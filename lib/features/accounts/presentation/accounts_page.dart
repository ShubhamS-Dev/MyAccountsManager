import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../accounts_providers.dart';
import 'account_balance_label.dart';

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
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${items.length} active ${items.length == 1 ? 'Account' : 'Accounts'}', style: Theme.of(context).textTheme.titleSmall),
              TextButton.icon(onPressed: () => context.push('/accounts/archived'), icon: const Icon(Icons.archive_outlined), label: const Text('Archived')),
            ]),
            const SizedBox(height: 12),
            for (final account in items)
              Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
                title: Text(account.name),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (account.description != null) Text(account.description!), AccountBalanceLabel(accountId: account.id)]),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    final repository = ref.read(accountsRepositoryProvider);
                    if (action == 'edit') {
                      context.push('/accounts/${account.id}/edit');
                    } else if (action == 'pin' || action == 'unpin') {
                      await repository.setPinned('${account.id}', pinned: action == 'pin');
                      ref.invalidate(activeAccountsProvider);
                    } else if (action == 'archive') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Archive Account?'),
                          content: const Text('${account.name} will be hidden from active Accounts. Its transactions and history will be preserved.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Archive')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await repository.archiveAccount('${account.id}');
                        ref.invalidate(activeAccountsProvider);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: account.isPinned ? 'unpin' : 'pin', child: Text(account.isPinned ? 'Unpin' : 'Pin to top')),
                    const PopupMenuItem(value: 'archive', child: Text('Archive')),
                  ],
                ),
              )),
          ]);
        },
      ),
    );
  }
}
