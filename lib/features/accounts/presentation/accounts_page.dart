import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/money_formatter.dart';
import '../accounts_providers.dart';
import 'account_balance_label.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  final _searchController = TextEditingController();
  bool _hideBalances = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(activeAccountsProvider);
    final total = ref.watch(totalActiveBalancePaiseProvider);
    return accounts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _MessageState(
        message: 'Accounts could not be loaded.',
        action: 'Retry',
        onAction: () => ref.invalidate(activeAccountsProvider),
      ),
      data: (items) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered =
            items
                .where(
                  (account) =>
                      account.name.toLowerCase().contains(query) ||
                      (account.description ?? '').toLowerCase().contains(query),
                )
                .toList()
              ..sort((a, b) {
                if (a.isPinned == b.isPinned) {
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                }
                return a.isPinned ? -1 : 1;
              });

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
          children: [
            _BalanceOverview(
              total: total,
              hidden: _hideBalances,
              onToggle: () => setState(() => _hideBalances = !_hideBalances),
              onArchived: () => context.push('/accounts/archived'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your accounts',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${items.length} active',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Add Account',
                  onPressed: () => context.push('/accounts/new'),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search accounts',
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  items.isEmpty
                      ? 'No accounts yet. Add your first account.'
                      : 'No accounts match your search.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 120,
                ),
                itemBuilder: (context, index) {
                  final AccountRow account = filtered[index];
                  return _AccountCard(
                    account: account,
                    hidden: _hideBalances,
                    onTap: () => context.push('/accounts/${account.id}'),
                    onAction: (action) =>
                        _handleAction(context, account, action),
                  );
                },
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/accounts/new'),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Add new account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    AccountRow account,
    String action,
  ) async {
    final repository = ref.read(accountsRepositoryProvider);
    if (action == 'details') {
      context.push('/accounts/${account.id}');
    } else if (action == 'edit') {
      context.push('/accounts/${account.id}/edit');
    } else if (action == 'adjust') {
      context.push('/accounts/${account.id}/adjustments');
    } else if (action == 'pin' || action == 'unpin') {
      await repository.setPinned(account.id, pinned: action == 'pin');
    } else if (action == 'archive') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Archive account?'),
          content: Text(
            '${account.name} will be hidden from active accounts. Its transaction history will be preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirmed == true) await repository.archiveAccount(account.id);
    }
  }
}

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({
    required this.total,
    required this.hidden,
    required this.onToggle,
    required this.onArchived,
  });
  final AsyncValue<int> total;
  final bool hidden;
  final VoidCallback onToggle;
  final VoidCallback onArchived;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF263F78)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TOTAL ACCOUNT BALANCE',
                  style: AppTypography.supporting.copyWith(
                    color: Colors.white.withValues(alpha: 0.76),
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggle,
                tooltip: hidden ? 'Show balance' : 'Hide balance',
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: onArchived,
                tooltip: 'Archived accounts',
                icon: const Icon(Icons.archive_outlined, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          total.when(
            loading: () =>
                const SizedBox(height: 26, child: LinearProgressIndicator()),
            error: (error, stack) => const Text('Balance unavailable'),
            data: (value) => Text(
              hidden ? '₹ ••••••' : MoneyFormatter.formatPaise(value),
              style: AppTypography.transactionAmount.copyWith(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Across active accounts · MyKhata excluded',
            style: AppTypography.supporting.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.hidden,
    required this.onTap,
    required this.onAction,
  });
  final AccountRow account;
  final bool hidden;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showMenu(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: colors.primary,
                  ),
                ),
                if (account.isPinned) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.push_pin_rounded, size: 14, color: colors.primary),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: 'Account actions',
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Text('View details'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'adjust',
                      child: Text('Adjust balance'),
                    ),
                    PopupMenuItem(
                      value: account.isPinned ? 'unpin' : 'pin',
                      child: Text(account.isPinned ? 'Unpin' : 'Pin to top'),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive'),
                    ),
                  ],
                  child: const Icon(Icons.more_horiz, size: 20),
                ),
              ],
            ),
            const Spacer(),
            Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (hidden)
              const Text(
                '₹ ••••••',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              )
            else
              AccountBalanceLabel(accountId: account.id),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View details'),
              onTap: () {
                Navigator.pop(context);
                onAction('details');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                onAction('edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(context);
                onAction('archive');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.action,
    required this.onAction,
  });
  final String message;
  final String action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton(onPressed: onAction, child: Text(action)),
      ],
    ),
  );
}
