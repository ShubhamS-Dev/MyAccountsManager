import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/date_range_chooser.dart';
import '../../../app/icon_resolvers.dart';
import '../../../app/privacy_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../../core/time/day_range.dart';
import '../../../core/time/today_provider.dart';
import '../../accounts/accounts_providers.dart';
import '../data/transactions_repository.dart';
import '../transactions_providers.dart';
import 'transaction_copy_actions.dart';

/// History as a full page, opened from Home and from Reports drill-downs.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    this.accountId,
    this.category,
    this.type,
    this.from,
    this.through,
    super.key,
  });

  final String? accountId;
  final String? category;
  final String? type;
  final int? from;
  final int? through;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('History')),
    body: HistoryPage(
      initialAccountId: accountId,
      initialCategory: category,
      initialType: type,
      initialRange: from != null && through != null && from! <= through!
          ? DayRange(from!, through!)
          : null,
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => context.push('/transaction/new'),
      tooltip: 'Add transaction',
      child: const Icon(Icons.add_rounded),
    ),
  );
}

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({
    this.initialAccountId,
    this.initialCategory,
    this.initialType,
    this.initialRange,
    super.key,
  });

  final String? initialAccountId;
  final String? initialCategory;
  final String? initialType;

  /// Shows this range instead of a single month.
  final DayRange? initialRange;

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _search = TextEditingController();
  late String? _accountId = widget.initialAccountId;
  late String? _category = widget.initialCategory;
  late String? _type = widget.initialType;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// A chosen date range replaces the month view while set.
  late DayRange? _range = widget.initialRange;

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
      _range != null ||
      _accountId != null ||
      _category != null ||
      _type != null ||
      _search.text.trim().isNotEmpty;

  Future<bool> _moveToTrash(TransactionHistoryItem item) async {
    // Capture the page-level messenger before awaiting the database write.
    // The Dismissible may be removed as soon as confirmDismiss returns true.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .softDeleteTransaction(item.transaction.id);
      ref.invalidate(accountBalancePaiseProvider(item.transaction.accountId));
      if (!mounted || !messenger.mounted) return true;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
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
      return true;
    } catch (_) {
      if (mounted && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not move transaction to Trash. Try again.'),
          ),
        );
      }
      return false;
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
    var selectedRange = _range;
    final today = ref.read(todayProvider);
    final result = await showModalBottomSheet<(String?, String?, DayRange?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
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
                const Text('Date range', style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.sm),
                DateRangeChooser(
                  value: selectedRange,
                  today: today,
                  noneLabel: 'Month by month',
                  onChanged: (range) =>
                      setSheetState(() => selectedRange = range),
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
                          selectedRange = null;
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
                          selectedRange,
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
      _range = result.$3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(
      transactionHistoryProvider(const TransactionHistoryFilter()),
    );
    final accountsAsync = ref.watch(allAccountsProvider);
    final colors = Theme.of(context).colorScheme;
    final range = _range;
    final from = range?.from ?? _day(DateTime(_month.year, _month.month));
    final through =
        range?.through ??
        _day(
          DateTime(
            _month.year,
            _month.month + 1,
          ).subtract(const Duration(days: 1)),
        );
    final monthLabel = '${_months[_month.month - 1]} ${_month.year}';
    final today = ref.watch(todayProvider);
    final hidden = ref.watch(amountsHiddenProvider);

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
        // Scheduled (future-dated) items are listed but not counted yet,
        // matching Home and Account balances.
        var income = 0;
        var expense = 0;
        var scheduledCount = 0;
        for (final item in monthItems) {
          if (isScheduledDate(item.transaction.transactionDate, today)) {
            scheduledCount++;
          } else if (item.transaction.type == 'income') {
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
                        Expanded(
                          child: Text(
                            range == null ? 'Monthly overview' : 'Overview',
                            style: AppTypography.sectionTitle,
                          ),
                        ),
                        if (range != null)
                          Flexible(
                            flex: 3,
                            child: _RangePill(
                              label: range.label,
                              onClear: () => setState(() => _range = null),
                            ),
                          )
                        else
                          _MonthPill(
                            label: monthLabel,
                            onPrevious: () => setState(
                              () => _month = DateTime(
                                _month.year,
                                _month.month - 1,
                              ),
                            ),
                            // Future months open only when something is
                            // scheduled after this month.
                            onNext:
                                !_month.isBefore(
                                      DateTime(
                                        DateTime.now().year,
                                        DateTime.now().month,
                                      ),
                                    ) &&
                                    !items.any(
                                      (item) =>
                                          item.transaction.transactionDate >
                                          through,
                                    )
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
                            color: colors.positiveText,
                            hidden: hidden,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _SummaryCard(
                            label: 'Expenses',
                            amount: expense,
                            total: income + expense,
                            color: colors.negativeText,
                            hidden: hidden,
                          ),
                        ),
                      ],
                    ),
                    if (scheduledCount > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$scheduledCount scheduled · counted on their dates',
                        style: AppTypography.supporting.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                      label: const Text('Date, Account & Category filters'),
                    ),
                    if (_range != null ||
                        _accountId != null ||
                        _category != null ||
                        _type != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (range != null)
                            _SelectedFilterChip(
                              label: range.label,
                              onRemove: () => setState(() => _range = null),
                            ),
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
                child: items.isEmpty && !_hasFilters
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
                          _range = null;
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
                        hidden: hidden,
                        scheduled: isScheduledDate(
                          item.transaction.transactionDate,
                          today,
                        ),
                        onTap: () =>
                            context.push('/transaction/${item.transaction.id}'),
                        onEdit: () => context.push(
                          '/transaction/${item.transaction.id}/edit',
                        ),
                        onTrash: () => _confirmTrash(item),
                        onDuplicate: () => duplicateTransaction(
                          context,
                          ref,
                          transactionId: item.transaction.id,
                          accountId: item.transaction.accountId,
                        ),
                        onCopy: () =>
                            copyTransactionAsNew(context, item.transaction.id),
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

class _RangePill extends StatelessWidget {
  const _RangePill({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.date_range_rounded, size: 16, color: scheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.fieldValue.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Back to month view',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
    required this.hidden,
  });

  final String label;
  final int amount;
  final int total;
  final Color color;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    // The bar would reveal the income/expense ratio, so it empties too.
    final progress = total == 0 || hidden
        ? 0.0
        : (amount / total).clamp(0.0, 1.0);
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
          AmountText(
            hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(amount),
            color: color,
          ),
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: selected ? AppShadows.card : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        // With the selector's 3px padding the row is a full 48px tap target.
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.touchTarget - 6,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.fieldValue.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
    required this.onDuplicate,
    required this.onCopy,
    required this.onSwipeDelete,
    this.scheduled = false,
    this.hidden = false,
    super.key,
  });

  final TransactionHistoryItem item;
  final bool scheduled;
  final bool hidden;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onTrash;
  final VoidCallback onDuplicate;
  final VoidCallback onCopy;
  final Future<bool> Function() onSwipeDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final transaction = item.transaction;
    final income = transaction.type == 'income';
    final fallbackColor = income ? AppColors.positive : AppColors.negative;
    final categoryColor = item.categoryColorValue == null
        ? fallbackColor
        : Color(item.categoryColorValue!);
    final categoryIcon = resolveCategoryIcon(
      item.categoryIconKey ?? item.categoryName,
      income: income,
    );
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
        confirmDismiss: (_) => onSwipeDelete(),
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
                    Row(
                      children: [
                        if (scheduled) ...[
                          const ScheduledBadge(),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        if (transaction.recurringRuleId != null) ...[
                          Icon(
                            Icons.repeat_rounded,
                            size: 14,
                            semanticLabel: 'Recurring',
                            color: scheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            '${item.categoryName} · ${item.accountName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.metadata.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AmountText(
                hidden
                    ? hiddenAmountMask
                    : '${income ? '+' : '-'}${MoneyFormatter.formatPaise(transaction.amountPaise)}',
                color: income ? scheme.positiveText : scheme.negativeText,
              ),
              PopupMenuButton<String>(
                tooltip: 'Transaction actions',
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                  if (action == 'duplicate') onDuplicate();
                  if (action == 'copy') onCopy();
                  if (action == 'trash') onTrash();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: _MenuLabel(Icons.edit_outlined, 'Edit'),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: _MenuLabel(
                      Icons.control_point_duplicate_rounded,
                      'Duplicate',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: _MenuLabel(
                      Icons.content_copy_rounded,
                      'Copy as new',
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'trash',
                    child: _MenuLabel(
                      Icons.delete_outline_rounded,
                      'Move to Trash',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: AppSpacing.sm + 4),
      Text(label),
    ],
  );
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
