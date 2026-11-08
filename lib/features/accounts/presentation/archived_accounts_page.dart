import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts_providers.dart';

class ArchivedAccountsPage extends ConsumerWidget {
  const ArchivedAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(archivedAccountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Accounts')),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(archivedAccountsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No archived Accounts.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Archived Accounts are hidden from active views. Restore one to use it again.'),
              const SizedBox(height: 12),
              for (final account in items)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.archive_outlined)),
                    title: Text(account.name),
                    subtitle: account.description == null ? null : Text(account.description!),
                    trailing: TextButton(
                      onPressed: () async {
                        await ref.read(accountsRepositoryProvider).restoreAccount(account.id);
                        ref.invalidate(activeAccountsProvider);
                        ref.invalidate(archivedAccountsProvider);
                      },
                      child: const Text('Restore'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
