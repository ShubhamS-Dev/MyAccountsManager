import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../accounts/accounts_providers.dart';
import '../data/transactions_repository.dart';
import '../transactions_providers.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _search = TextEditingController();
  String? _accountId;
  String? _category;
  String? _type;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch;

  bool get _hasFilters =>
      _accountId != null ||
      _category != null ||
      _type != null ||
      _search.text.trim().isNotEmpty;

  Future<void> _moveToTrash(TransactionHistoryItem item) async {
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .softDeleteTransaction(item.transaction.id);
      ref.invalidate(accountBalancePaiseProvider(item.transaction.accountId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction moved to Trash'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await ref
                    .read(transactionsRepositoryProvider)
                    .restoreTransaction(item.transaction.id);
                ref.invalidate(
                  accountBalancePaiseProvider(item.transaction.accountId),
                );
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not restore transaction.'),
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not move transaction to Trash. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmTrash(TransactionHistoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: const Text(
          'You can restore this transaction later from Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _moveToTrash(item);
  }

  Future<void> _openFilters({
    required List<AccountRow> accounts,
    required List<String> categories,
  }) async {
    var selectedAccount = _accountId;
    var selectedCategory = _category;
    final result = await showModalBottomSheet<(String?, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter transactions',
                  style: AppTypography.screenTitle,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Account', style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _FilterOption(
                          label: 'All Accounts',
                          selected: selectedAccount == null,
                          onTap: () =>
                              setSheetState(() => selectedAccount = null),
                        ),
                        for (final account in accounts)
                          _FilterOption(
                            label: account.name,
                            selected: selectedAccount == account.id,
                            onTap: () => setSheetState(
                              () => selectedAccount = account.id,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Category', style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _FilterOption(
                          label: 'All Categories',
                          selected: selectedCategory == null,
                          onTap: () =>
                              setSheetState(() => selectedCategory = null),
                        ),
                        for (final category in categories)
                          _FilterOption(
                            label: category,
                            selected: selectedCategory == category,
                            onTap: () => setSheetState(
                              () => selectedCategory = category,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheetState(() {
                          selectedAccount = null;
                          selectedCategory = null;
                        }),
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, (
                          selectedAccount,
                          selectedCategory,
                        )),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _accountId = result.$1;
      _category = result.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(
      transactionHistoryProvider(const TransactionHistoryFilter()),
    );
    final accountsAsync = ref.watch(allAccountsProvider);
    final colors = Theme.of(context).colorScheme;
    final from = _day(DateTime(_month.year, _month.month));
    final through = _day(
      DateTime(_month.year, _month.month + 1).subtract(const Duration(days: 1)),
    );
    final monthLabel = '${_months[_month.month - 1]} ${_month.year}';

    return history.when(
      loading: () => const _HistoryShimmer(),
      error: (error, stack) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(
            transactionHistoryProvider(const TransactionHistoryFilter()),
          ),
          child: const Text('Could not load history. Retry'),
        ),
      ),
      data: (items) {
        final monthItems = items.where(
          (item) =>
              item.transaction.transactionDate >= from &&
              item.transaction.transactionDate <= through,
        );
        var income = 0;
        var expense = 0;
        for (final item in monthItems) {
          if (item.transaction.type == 'income') {
            income += item.transaction.amountPaise;
          } else {
            expense += item.transaction.amountPaise;
          }
        }

        final query = _search.text.trim().toLowerCase();
        final filtered = items.where((item) {
          final transaction = item.transaction;
          if (transaction.transactionDate < from ||
              transaction.transactionDate > through) {
            return false;
          }
          if (_accountId != null && transaction.accountId != _accountId) {
            return false;
          }
          if (_category != null && item.categoryName != _category) {
            return false;
          }
          if (_type != null && transaction.type != _type) return false;
          if (query.isNotEmpty) {
            final searchable =
                '${transaction.note ?? ''} ${item.accountName} '
                        '${item.categoryName} '
                        '${MoneyFormatter.formatPaise(transaction.amountPaise)} '
                        '${transaction.amountPaise}'
                    .toLowerCase();
            if (!searchable.contains(query)) return false;
          }
          return true;
        }).toList();

        final groups = <String, List<TransactionHistoryItem>>{};
        for (final item in filtered) {
          groups
              .putIfAbsent(
                DateOnly.format(item.transaction.transactionDate),
                () => [],
              )
              .add(item);
        }
        final categories =
            items.map((item) => item.categoryName).toSet().toList()..sort();
        final accountRows = accountsAsync.valueOrNull ?? const <AccountRow>[];
        final selectedAccountName = accountRows
            .where((account) => account.id == _accountId)
            .map((account) => account.name)
            .firstOrNull;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Monthly overview',
                            style: AppTypography.sectionTitle,
                          ),
                        ),
                        _MonthPill(
                          label: monthLabel,
                          onPrevious: () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month - 1,
                            ),
                          ),
                          onNext:
                              _month.year == DateTime.now().year &&
                                  _month.month == DateTime.now().month
                              ? null
                              : () => setState(
                                  () => _month = DateTime(
                                    _month.year,
                                    _month.month + 1,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'Income',
                            amount: income,
                            total: income + expense,
                            color: AppColors.positive,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _SummaryCard(
                            label: 'Expenses',
                            amount: expense,
                            total: income + expense,
                            color: AppColors.negative,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search note, Account or amount',
                        prefixIcon: const Icon(Icons.search_rounded, size: 19),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _TypeSegment(
                            value: _type,
                            onChanged: (value) => setState(() => _type = value),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton.filledTonal(
                          tooltip: 'Open Trash',
                          onPressed: () => context.push('/transactions/trash'),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: accountsAsync.when(
                        data: (rows) =>
                            () => _openFilters(
                              accounts: rows,
                              categories: categories,
                            ),
                        loading: () => null,
                        error: (error, stack) => null,
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 17),
                      label: const Text('Account & Category filters'),
                    ),
                    if (_accountId != null ||
                        _category != null ||
                        _type != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (_accountId != null)
                            _SelectedFilterChip(
                              label: selectedAccountName ?? 'Account',
                              onRemove: () => setState(() => _accountId = null),
                            ),
                          if (_category != null)
                            _SelectedFilterChip(
                              label: _category!,
                              onRemove: () => setState(() => _category = null),
                            ),
                          if (_type != null)
                            _SelectedFilterChip(
                              label: _type == 'income' ? 'Income' : 'Expense',
                              onRemove: () => setState(() => _type = null),
                            ),
                        ],
                      ),
                    ],
                    if (_hasFilters) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Showing ${filtered.length} of ${items.where((item) => item.transaction.transactionDate >= from && item.transaction.transactionDate <= through).length} transactions',
                        style: AppTypography.metadata.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: items.isEmpty
                    ? EmptyState(
                        title: 'No transactions yet',
                        message: 'Start tracking your income and expenses.',
                        icon: Icons.receipt_long_rounded,
                        actionLabel: 'Add transaction',
                        onAction: () => context.push('/transaction/new'),
                      )
                    : EmptyState(
                        title: 'No matching transactions',
                        message: 'Try clearing your filters or search.',
                        icon: Icons.filter_alt_off_rounded,
                        actionLabel: 'Clear filters',
                        onAction: () => setState(() {
                          _accountId = null;
                          _category = null;
                          _type = null;
                          _search.clear();
                        }),
                      ),
              )
            else
              for (final group in groups.entries) ...[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DateHeaderDelegate(group.key),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = group.value[index];
                      return _HistoryTile(
                        key: ValueKey(item.transaction.id),
                        item: item,
                        onTap: () =>
                            context.push('/transaction/${item.transaction.id}'),
                        onEdit: () => context.push(
                          '/transaction/${item.transaction.id}/edit',
                        ),
                        onTrash: () => _confirmTrash(item),
                        onSwipeDelete: () => _moveToTrash(item),
                      );
                    }, childCount: group.value.length),
                  ),
                ),
              ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
}

class _MonthPill extends StatelessWidget {
  const _MonthPill({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded, size: 19),
        ),
        Text(
          label,
          style: AppTypography.fieldValue.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, size: 19),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
  });

  final String label;
  final int amount;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : amount / total;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.metadata.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AmountText(MoneyFormatter.formatPaise(amount), color: color),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: color,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = <String?>[null, 'expense', 'income'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (final option in labels)
            Expanded(
              child: _SegmentOption(
                label: option == null
                    ? 'All'
                    : option == 'expense'
                    ? 'Expense'
                    : 'Income',
                selected: value == option,
                onTap: () => onChanged(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  const _SegmentOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(
      color: selected
          ? Theme.of(context).colorScheme.surface
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      boxShadow: selected ? AppShadows.card : null,
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.fieldValue.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label, style: AppTypography.fieldValue),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: true,
  );
}

class _SelectedFilterChip extends StatelessWidget {
  const _SelectedFilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InputChip(
    label: Text(label, style: AppTypography.metadata),
    onDeleted: onRemove,
    deleteIcon: const Icon(Icons.close_rounded, size: 15),
  );
}

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DateHeaderDelegate(this.label);

  final String label;

  @override
  double get minExtent => 42;

  @override
  double get maxExtent => 42;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: scheme.surfaceContainer,
      child: Text(
        label,
        style: AppTypography.sectionTitle.copyWith(color: scheme.onSurface),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onTrash,
    required this.onSwipeDelete,
    super.key,
  });

  final TransactionHistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onTrash;
  final VoidCallback onSwipeDelete;

  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final income = transaction.type == 'income';
    final fallbackColor = income ? AppColors.positive : AppColors.negative;
    final categoryColor = item.categoryColorValue == null
        ? fallbackColor
        : Color(item.categoryColorValue!);
    final categoryIcon = _categoryIcon(item.categoryIconKey, income);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Dismissible(
        key: ValueKey('dismiss-${transaction.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        onDismissed: (_) => onSwipeDelete(),
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: categoryColor.withValues(alpha: .12),
                ),
                child: Icon(categoryIcon, size: 19, color: categoryColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.note?.isNotEmpty == true
                          ? transaction.note!
                          : item.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.fieldValue.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.categoryName} · ${item.accountName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metadata.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AmountText(
                '${income ? '+' : '-'}${MoneyFormatter.formatPaise(transaction.amountPaise)}',
                color: income ? AppColors.positive : AppColors.negative,
              ),
              PopupMenuButton<String>(
                tooltip: 'Transaction actions',
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                  if (action == 'trash') onTrash();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'trash', child: Text('Move to Trash')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String? key, bool income) {
    switch (key) {
      case 'food':
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'salary':
        return Icons.work_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'education':
        return Icons.school_rounded;
      default:
        return income ? Icons.south_west_rounded : Icons.north_east_rounded;
    }
  }
}

class _HistoryShimmer extends StatefulWidget {
  const _HistoryShimmer();

  @override
  State<_HistoryShimmer> createState() => _HistoryShimmerState();
}

class _HistoryShimmerState extends State<_HistoryShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Opacity(opacity: .45 + (_controller.value * .35), child: child),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            height: 38,
            width: 150,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                Expanded(
                  child: Container(
                    height: 88,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                ),
                if (i == 0) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 6; i++) ...[
            Container(
              height: 66,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
