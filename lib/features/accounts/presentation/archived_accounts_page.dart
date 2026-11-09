import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../accounts_providers.dart';

class ArchivedAccountsPage extends ConsumerWidget {
  const ArchivedAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(archivedAccountsProvider);
    final colors = Theme.of(context).colorScheme;

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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.archive_outlined,
                        color: colors.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No archived Accounts',
                      style: AppTypography.sectionTitle.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Accounts you archive will appear here. You can restore them whenever you need.',
                      textAlign: TextAlign.center,
                      style: AppTypography.supporting.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Archived Accounts',
                      style: AppTypography.sectionTitle.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length} ${items.length == 1 ? 'Account' : 'Accounts'}',
                    style: AppTypography.supporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'These Accounts are hidden from active views. Restore an Account to use it again.',
                style: AppTypography.supporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              for (final account in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.archive_outlined,
                          color: colors.onSurfaceVariant,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.sectionTitle.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                            if (account.description?.isNotEmpty == true) ...[
                              const SizedBox(height: 3),
                              Text(
                                account.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.supporting.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(accountsRepositoryProvider)
                              .restoreAccount(account.id);
                          ref.invalidate(activeAccountsProvider);
                          ref.invalidate(archivedAccountsProvider);
                        },
                        icon: const Icon(Icons.unarchive_outlined, size: 16),
                        label: const Text('Restore'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
