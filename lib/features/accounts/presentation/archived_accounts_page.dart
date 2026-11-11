import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/icon_resolvers.dart';
import '../../../core/database/app_database.dart';
import '../accounts_providers.dart';
import 'account_form.dart';

class ArchivedAccountsPage extends ConsumerWidget {
  const ArchivedAccountsPage({super.key});

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    AccountRow account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountsRepositoryProvider).restoreAccount(account.id);
      ref.invalidate(activeAccountsProvider);
      ref.invalidate(archivedAccountsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('${account.name} is active again')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not restore this Account.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(archivedAccountsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Archived Accounts')),
      body: accounts.when(
        loading: () => const SkeletonList(),
        error: (error, stack) => ScreenErrorState(
          message: 'Archived Accounts could not be loaded.',
          onRetry: () => ref.invalidate(archivedAccountsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: EmptyState(
                title: 'No archived Accounts',
                message:
                    'Accounts you archive will appear here. You can restore them whenever you need.',
                icon: Icons.archive_outlined,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm + 4),
                child: Row(
                  children: [
                    IconBadge(
                      icon: Icons.inventory_2_outlined,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${items.length} ${items.length == 1 ? 'Account' : 'Accounts'}',
                            style: AppTypography.sectionTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hidden from active views. History is preserved.',
                            style: AppTypography.supporting.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final (index, account) in items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ArchivedAccountTile(
                    account: account,
                    index: index,
                    onRestore: () => _restore(context, ref, account),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArchivedAccountTile extends StatelessWidget {
  const _ArchivedAccountTile({
    required this.account,
    required this.index,
    required this.onRestore,
  });

  final AccountRow account;
  final int index;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accountGradientFor(account.colorValue, index: index).first;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm + 4,
        AppSpacing.sm + 2,
        AppSpacing.sm,
        AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          IconBadge(icon: resolveAccountIcon(account.iconKey), color: accent),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.sectionTitle,
                ),
                if (account.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    account.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.supporting.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.unarchive_outlined, size: 16),
            label: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
