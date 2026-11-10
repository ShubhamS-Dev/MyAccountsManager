import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(activeAccountsProvider);
    final total = ref.watch(totalActiveBalancePaiseProvider);
    final hidden = ref.watch(amountsHiddenProvider);
    final scheme = Theme.of(context).colorScheme;

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
            items.where((account) {
              return account.name.toLowerCase().contains(query) ||
                  (account.description ?? '').toLowerCase().contains(query);
            }).toList()..sort((a, b) {
              if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            104,
          ),
          children: [
            _BalanceOverview(
              total: total,
              hidden: hidden,
              onToggle: () {
                ref.read(amountsHiddenProvider.notifier).state = !hidden;
              },
              onArchived: () => context.push('/accounts/archived'),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'Your accounts',
              action: 'Add',
              onAction: () => context.push('/accounts/new'),
            ),
            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.md),
            if (filtered.isEmpty)
              AppCard(
                child: EmptyState(
                  title: items.isEmpty
                      ? 'No accounts yet'
                      : 'No matching accounts',
                  message: items.isEmpty
                      ? 'Add an account to start tracking your money.'
                      : 'Try another name or clear your search.',
                  icon: items.isEmpty
                      ? Icons.account_balance_wallet_outlined
                      : Icons.search_off_rounded,
                  actionLabel: items.isEmpty
                      ? 'Add new account'
                      : 'Clear search',
                  onAction: items.isEmpty
                      ? () => context.push('/accounts/new')
                      : () {
                          _searchController.clear();
                          setState(() {});
                        },
                ),
              )
            else ...[
              Text(
                '${items.length} active accounts',
                style: AppTypography.supporting.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  mainAxisExtent: 148,
                ),
                itemBuilder: (context, index) {
                  final account = filtered[index];
                  return _AccountCard(
                    account: account,
                    hidden: hidden,
                    index: index,
                    onTap: () => context.push('/accounts/${account.id}'),
                    onAction: (action) =>
                        _handleAction(context, account, action),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _AddAccountCard(onTap: () => context.push('/accounts/new')),
            ],
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
            '${account.name} will be hidden from active accounts. '
            'Its transaction history will be preserved.',
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
    return GradientCard(
      colors: AppColors.heroGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TOTAL ACCOUNT BALANCE',
                  style: AppTypography.metadata.copyWith(
                    color: Colors.white.withValues(alpha: .78),
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: hidden ? 'Show amounts' : 'Hide amounts',
                onPressed: onToggle,
                color: Colors.white,
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Archived accounts',
                onPressed: onArchived,
                color: Colors.white,
                icon: const Icon(Icons.archive_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          total.when(
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
              child: AmountText(
                hidden ? '₹ ••••••' : MoneyFormatter.formatPaise(value),
                key: ValueKey('$hidden-$value'),
                style: AppTypography.balance.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Across active accounts · MyKhata excluded',
            style: AppTypography.supporting.copyWith(
              color: Colors.white.withValues(alpha: .78),
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
    required this.index,
    required this.onTap,
    required this.onAction,
  });

  final AccountRow account;
  final bool hidden;
  final int index;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final palette =
        AppColors.accountGradients[index % AppColors.accountGradients.length];
    final baseColor = account.colorValue == null
        ? palette.first
        : Color(account.colorValue!);
    final gradient = account.colorValue == null
        ? palette
        : [baseColor, Color.lerp(baseColor, Colors.white, .22)!];

    return GradientCard(
      colors: gradient,
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withValues(alpha: .18),
                  child: Icon(
                    _accountIcon(account.iconKey),
                    size: 19,
                    color: Colors.white,
                  ),
                ),
                if (account.isPinned) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'Account actions',
                  onPressed: () => _showMenu(context),
                  color: Colors.white,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
            const Spacer(),
            Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sectionTitle.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (hidden)
              AmountText(
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
                child: AccountBalanceLabel(accountId: account.id),
              ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(account.name, style: AppTypography.sectionTitle),
              ),
              const SizedBox(height: AppSpacing.sm),
              _AccountActionTile(
                icon: Icons.open_in_new_rounded,
                label: 'View details',
                onTap: () => _selectAction(sheetContext, 'details'),
              ),
              _AccountActionTile(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () => _selectAction(sheetContext, 'edit'),
              ),
              _AccountActionTile(
                icon: Icons.tune_rounded,
                label: 'Adjust balance',
                onTap: () => _selectAction(sheetContext, 'adjust'),
              ),
              _AccountActionTile(
                icon: Icons.push_pin_outlined,
                label: account.isPinned ? 'Unpin' : 'Pin to top',
                onTap: () => _selectAction(
                  sheetContext,
                  account.isPinned ? 'unpin' : 'pin',
                ),
              ),
              _AccountActionTile(
                icon: Icons.archive_outlined,
                label: 'Archive',
                destructive: true,
                onTap: () => _selectAction(sheetContext, 'archive'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectAction(BuildContext context, String action) {
    Navigator.pop(context);
    onAction(action);
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          label,
          style: AppTypography.fieldValue.copyWith(color: color),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

class _AddAccountCard extends StatelessWidget {
  const _AddAccountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline_rounded, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Add new account',
              style: AppTypography.sectionTitle.copyWith(color: scheme.primary),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

IconData _accountIcon(String? iconKey) {
  switch (iconKey?.toLowerCase()) {
    case 'bank':
    case 'account_balance':
      return Icons.account_balance_rounded;
    case 'cash':
    case 'money':
      return Icons.payments_rounded;
    case 'card':
    case 'credit_card':
      return Icons.credit_card_rounded;
    case 'wallet':
      return Icons.account_balance_wallet_rounded;
    case 'savings':
      return Icons.savings_rounded;
    case 'investment':
      return Icons.trending_up_rounded;
    default:
      return Icons.account_balance_wallet_rounded;
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
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        child: EmptyState(
          title: 'Something went wrong',
          message: message,
          icon: Icons.cloud_off_rounded,
          actionLabel: action,
          onAction: onAction,
        ),
      ),
    ),
  );
}
