import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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
import '../../transactions/transactions_providers.dart';
import '../domain/report.dart';

/// Categorical slots, validated for colour-blind separation on the app's
/// light and dark surfaces. Light slots 3-5 sit under 3:1 contrast, so the
/// category list always labels them.
const _lightSlots = [
  Color(0xFF2A78D6),
  Color(0xFFEB6834),
  Color(0xFF1BAF7A),
  Color(0xFFEDA100),
  Color(0xFFE87BA4),
  Color(0xFF008300),
  Color(0xFF6250D6),
];
const _darkSlots = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFFD55181),
  Color(0xFF008300),
  Color(0xFF9085E9),
];

Color _slotColor(BuildContext context, CategorySlice slice) {
  final scheme = Theme.of(context).colorScheme;
  final slot = slice.colorSlot;
  if (slot == null) return scheme.outline;
  final slots = scheme.brightness == Brightness.dark ? _darkSlots : _lightSlots;
  return slots[slot % slots.length];
}

/// Short Indian-style amounts for axes: ₹950, ₹1.2K, ₹3.4L, ₹1.1Cr.
String compactRupees(int paise) {
  final rupees = paise.abs() / 100;
  final sign = paise < 0 ? '-' : '';
  String trim(double value) => value >= 10
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1).replaceAll('.0', '');
  if (rupees >= 10000000) return '$sign₹${trim(rupees / 10000000)}Cr';
  if (rupees >= 100000) return '$sign₹${trim(rupees / 100000)}L';
  if (rupees >= 1000) return '$sign₹${trim(rupees / 1000)}K';
  return '$sign₹${rupees.toStringAsFixed(0)}';
}

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Interactive spending and income report with filters and drill-downs.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportFilter? _filter;
  var _showNet = false;

  ReportFilter _current(int today) => _filter ??= ReportFilter(
    range: DayRange.preset(RangePreset.thisMonth, today),
  );

  void _update(ReportFilter filter) => setState(() => _filter = filter);

  Future<void> _chooseRange(ReportFilter filter, int today) async {
    final range = await showModalBottomSheet<DayRange>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date range', style: AppTypography.screenTitle),
              const SizedBox(height: AppSpacing.md),
              DateRangeChooser(
                value: filter.range,
                today: today,
                onChanged: (range) => Navigator.pop(sheetContext, range),
              ),
            ],
          ),
        ),
      ),
    );
    if (range != null) _update(filter.copyWith(range: range));
  }

  Future<void> _chooseOption({
    required String title,
    required String allLabel,
    required List<(String, String)> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) async {
    final result = await showModalBottomSheet<(String?,)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.sm),
                child: Text(title, style: AppTypography.screenTitle),
              ),
              for (final (value, label) in [(null, allLabel), ...options])
                ListTile(
                  title: Text(label),
                  trailing: value == selected
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(sheetContext, (value,)),
                ),
            ],
          ),
        ),
      ),
    );
    if (result != null) onSelected(result.$1);
  }

  void _openHistory(ReportFilter filter, ReportData data, {String? category}) {
    final query = {
      'from': '${filter.range.from}',
      'through': '${data.through}',
      'type': filter.type,
      if (filter.accountId != null) 'account': filter.accountId!,
      if ((category ?? filter.category) != null)
        'category': (category ?? filter.category)!,
    };
    context.push(Uri(path: '/history', queryParameters: query).toString());
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final filter = _current(today);
    final history = ref.watch(
      transactionHistoryProvider(const TransactionHistoryFilter()),
    );
    final accounts =
        ref.watch(allAccountsProvider).valueOrNull ?? const <AccountRow>[];
    final hidden = ref.watch(amountsHiddenProvider);
    final scheme = Theme.of(context).colorScheme;

    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(
            transactionHistoryProvider(const TransactionHistoryFilter()),
          ),
          child: const Text('Could not load reports. Retry'),
        ),
      ),
      data: (items) {
        final data = ReportData.build(items, filter, today);
        final categoryNames =
            items
                .where((item) => item.transaction.type == filter.type)
                .map((item) => item.categoryName)
                .toSet()
                .toList()
              ..sort();
        final accountName = accounts
            .where((account) => account.id == filter.accountId)
            .map((account) => account.name)
            .firstOrNull;
        final expenseSide = filter.type == 'expense';

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            112,
          ),
          children: [
            // Filters sit in one row above every chart they drive.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterPill(
                    icon: Icons.date_range_rounded,
                    label:
                        RangePreset.matching(filter.range, today)?.label ??
                        filter.range.label,
                    active: true,
                    onTap: () => _chooseRange(filter, today),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterPill(
                    icon: Icons.account_balance_wallet_outlined,
                    label: accountName ?? 'All Accounts',
                    active: filter.accountId != null,
                    onTap: () => _chooseOption(
                      title: 'Account',
                      allLabel: 'All Accounts',
                      options: [
                        for (final account in accounts)
                          (account.id, account.name),
                      ],
                      selected: filter.accountId,
                      onSelected: (value) =>
                          _update(filter.copyWith(accountId: () => value)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterPill(
                    icon: Icons.category_outlined,
                    label: filter.category ?? 'All Categories',
                    active: filter.category != null,
                    onTap: () => _chooseOption(
                      title: 'Category',
                      allLabel: 'All Categories',
                      options: [for (final name in categoryNames) (name, name)],
                      selected: filter.category,
                      onSelected: (value) =>
                          _update(filter.copyWith(category: () => value)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(
                    label: const Text('Include scheduled'),
                    selected: filter.includeScheduled,
                    onSelected: (value) =>
                        _update(filter.copyWith(includeScheduled: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text('Spending'),
                  icon: Icon(Icons.north_east_rounded),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text('Income'),
                  icon: Icon(Icons.south_west_rounded),
                ),
              ],
              selected: {filter.type},
              showSelectedIcon: false,
              onSelectionChanged: (value) => _update(
                // A category belongs to one side, so switching clears it.
                filter.copyWith(type: value.first, category: () => null),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _KpiGrid(data: data, hidden: hidden),
            const SizedBox(height: AppSpacing.lg),
            if (data.isEmpty)
              AppCard(
                child: EmptyState(
                  title: 'Nothing in this range',
                  message:
                      'Try a longer date range or clear the Account and '
                      'Category filters.',
                  icon: Icons.insights_rounded,
                  actionLabel: 'Show this year',
                  onAction: () => _update(
                    ReportFilter(
                      range: DayRange.preset(RangePreset.thisYear, today),
                      type: filter.type,
                    ),
                  ),
                ),
              )
            else ...[
              SectionHeader(
                title: 'Cash flow',
                action: 'View in History',
                onAction: () => _openHistory(filter, data),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
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
                            _showNet
                                ? 'Running net'
                                : 'Income vs expenses by '
                                      '${data.bucket.name}',
                            style: AppTypography.fieldLabel,
                          ),
                        ),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              tooltip: 'Income vs expenses',
                              icon: Icon(Icons.bar_chart_rounded),
                            ),
                            ButtonSegment(
                              value: true,
                              tooltip: 'Running net',
                              icon: Icon(Icons.show_chart_rounded),
                            ),
                          ],
                          selected: {_showNet},
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                          onSelectionChanged: (value) =>
                              setState(() => _showNet = value.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (hidden)
                      const _HiddenChart()
                    else if (_showNet)
                      _NetLine(data: data)
                    else
                      _CashFlowBars(data: data),
                    const SizedBox(height: AppSpacing.sm),
                    if (_showNet)
                      Text(
                        'Income minus expenses, added up day by day.',
                        style: AppTypography.metadata.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      _Legend(
                        entries: [
                          ('Income', scheme.positiveText),
                          ('Expenses', scheme.negativeText),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(
                title: expenseSide
                    ? 'Spending by category'
                    : 'Income by category',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (data.categories.isEmpty)
                AppCard(
                  child: Text(
                    expenseSide
                        ? 'No spending in this range.'
                        : 'No income in this range.',
                    style: AppTypography.supporting.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                _CategoryBreakdown(
                  data: data,
                  income: !expenseSide,
                  hidden: hidden,
                  onOpen: (slice) =>
                      _openHistory(filter, data, category: slice.name),
                ),
              if (data.accounts.length > 1 && filter.accountId == null) ...[
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'By account'),
                const SizedBox(height: AppSpacing.sm),
                _AccountBreakdown(
                  data: data,
                  income: !expenseSide,
                  hidden: hidden,
                  onOpen: (account) => _update(
                    filter.copyWith(accountId: () => account.accountId),
                  ),
                ),
              ],
              if (data.topTransactions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: expenseSide ? 'Largest expenses' : 'Largest income',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final item in data.topTransactions.take(5))
                        ListTile(
                          onTap: () => context.push(
                            '/transaction/${item.transaction.id}',
                          ),
                          leading: Icon(
                            resolveCategoryIcon(
                              item.categoryIconKey,
                              income: !expenseSide,
                            ),
                            color: scheme.primary,
                          ),
                          title: Text(
                            item.transaction.note?.trim().isNotEmpty == true
                                ? item.transaction.note!.trim()
                                : item.categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.categoryName} · '
                            '${DateOnly.format(item.transaction.transactionDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            hidden
                                ? hiddenAmountMask
                                : MoneyFormatter.formatPaise(
                                    item.transaction.amountPaise,
                                  ),
                            style: AppTypography.fieldValue.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    avatar: Icon(icon, size: 18),
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const Icon(Icons.arrow_drop_down_rounded, size: 20),
      ],
    ),
    showCheckmark: false,
    selected: active,
    onSelected: (_) => onTap(),
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data, required this.hidden});

  final ReportData data;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final perDay = data.days == 0 ? 0 : data.expense ~/ data.days;
    final previousPerDay = data.days == 0
        ? 0
        : data.previousExpense ~/ data.days;
    final tiles = [
      _Kpi(
        label: 'Income',
        amount: data.income,
        previous: data.previousIncome,
        color: scheme.positiveText,
        higherIsGood: true,
      ),
      _Kpi(
        label: 'Expenses',
        amount: data.expense,
        previous: data.previousExpense,
        color: scheme.negativeText,
        higherIsGood: false,
      ),
      _Kpi(
        label: 'Net',
        amount: data.net,
        previous: data.previousIncome - data.previousExpense,
        color: data.net < 0 ? scheme.negativeText : scheme.positiveText,
        higherIsGood: true,
      ),
      _Kpi(
        label: 'Avg spend / day',
        amount: perDay,
        previous: previousPerDay,
        color: scheme.onSurface,
        higherIsGood: false,
      ),
    ];
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiTile(kpi: tiles[row * 2], hidden: hidden),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _KpiTile(kpi: tiles[row * 2 + 1], hidden: hidden),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Kpi {
  const _Kpi({
    required this.label,
    required this.amount,
    required this.previous,
    required this.color,
    required this.higherIsGood,
  });

  final String label;
  final int amount;
  final int previous;
  final Color color;
  final bool higherIsGood;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.kpi, required this.hidden});

  final _Kpi kpi;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final change = kpi.previous == 0
        ? null
        : (kpi.amount - kpi.previous) / kpi.previous.abs() * 100;
    final up = (change ?? 0) >= 0;
    final good = up == kpi.higherIsGood;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kpi.label.toUpperCase(),
            style: AppTypography.metadata.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AmountText(
            hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(kpi.amount),
            color: kpi.color,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            change == null || hidden
                ? 'vs previous period'
                : '${up ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}% '
                      'vs previous',
            style: AppTypography.metadata.copyWith(
              color: change == null || hidden
                  ? scheme.onSurfaceVariant
                  : good
                  ? scheme.positiveText
                  : scheme.negativeText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HiddenChart extends StatelessWidget {
  const _HiddenChart();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Charts are hidden while Hide amounts is on.',
              textAlign: TextAlign.center,
              style: AppTypography.supporting.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _bucketLabel(TrendPoint point, TrendBucket bucket) {
  final day = DateOnly.fromUtcEpochMilliseconds(point.start);
  return switch (bucket) {
    TrendBucket.day => '${day.day}',
    TrendBucket.week => '${day.day} ${_monthShort[day.month - 1]}',
    TrendBucket.month => _monthShort[day.month - 1],
  };
}

String _bucketTitle(TrendPoint point, TrendBucket bucket) {
  final day = DateOnly.fromUtcEpochMilliseconds(point.start);
  return switch (bucket) {
    TrendBucket.day => DateOnly.format(point.start),
    TrendBucket.week => 'Week of ${DateOnly.format(point.start)}',
    TrendBucket.month => '${_monthShort[day.month - 1]} ${day.year}',
  };
}

/// Axis maximum rounded up to a tidy step, and that step.
(double, double) _niceScale(int maxPaise) {
  if (maxPaise <= 0) return (100, 25);
  final raw = maxPaise / 4;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final step = [
    1,
    2,
    2.5,
    5,
    10,
  ].map((m) => m * magnitude).firstWhere((s) => s >= raw);
  return (step * 4, step);
}

AxisTitles _leftAxis(BuildContext context, double interval) => AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 52,
    interval: interval,
    getTitlesWidget: (value, meta) => SideTitleWidget(
      meta: meta,
      child: Text(
        compactRupees(value.round()),
        style: AppTypography.metadata.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  ),
);

FlGridData _grid(BuildContext context, double interval) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (_) => FlLine(
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .6),
    strokeWidth: 1,
  ),
);

class _CashFlowBars extends StatelessWidget {
  const _CashFlowBars({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = data.trend;
    final peak = points.fold<int>(
      0,
      (best, p) => math.max(best, math.max(p.income, p.expense)),
    );
    final (maxY, interval) = _niceScale(peak);
    // Thin bars; label every nth bucket so dates never collide.
    final width = points.length > 20
        ? 4.0
        : points.length > 8
        ? 7.0
        : 12.0;
    final labelEvery = (points.length / 6).ceil().clamp(1, 1000);
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          gridData: _grid(context, interval),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: _leftAxis(context, interval),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index % labelEvery != 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _bucketLabel(points[index], data.bucket),
                      style: AppTypography.metadata.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (rodIndex != 0) return null;
                final point = points[group.x];
                final style = AppTypography.metadata.copyWith(
                  color: scheme.onInverseSurface,
                );
                return BarTooltipItem(
                  '${_bucketTitle(point, data.bucket)}\n',
                  style.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.left,
                  children: [
                    TextSpan(
                      text:
                          'Income ${MoneyFormatter.formatPaise(point.income)}\n'
                          'Expenses ${MoneyFormatter.formatPaise(point.expense)}',
                      style: style,
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (final (index, point) in points.indexed)
              BarChartGroupData(
                x: index,
                barsSpace: 2,
                barRods: [
                  for (final (amount, color) in [
                    (point.income, scheme.positiveText),
                    (point.expense, scheme.negativeText),
                  ])
                    BarChartRodData(
                      toY: amount.toDouble(),
                      color: color,
                      width: width,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NetLine extends StatelessWidget {
  const _NetLine({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = data.trend;
    var running = 0;
    final values = [
      for (final point in points) running += point.income - point.expense,
    ];
    final low = values.fold<int>(0, math.min);
    final high = values.fold<int>(0, math.max);
    final (span, interval) = _niceScale(math.max(high - low, 1));
    final minY = (low / interval).floor() * interval;
    final maxY = math.max(minY + span, (high / interval).ceil() * interval);
    final color = running < 0 ? scheme.negativeText : scheme.primary;
    final labelEvery = (points.length / 6).ceil().clamp(1, 1000);
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: _grid(context, interval),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 0, color: scheme.outline, strokeWidth: 1),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: _leftAxis(context, interval),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (value != index ||
                      index % labelEvery != 0 ||
                      index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _bucketLabel(points[index], data.bucket),
                      style: AppTypography.metadata.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${_bucketTitle(points[spot.x.toInt()], data.bucket)}\n',
                    AppTypography.metadata.copyWith(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.left,
                    children: [
                      TextSpan(
                        text:
                            'Net so far '
                            '${MoneyFormatter.formatPaise(spot.y.round())}',
                        style: AppTypography.metadata.copyWith(
                          color: scheme.onInverseSurface,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final (index, value) in values.indexed)
                  FlSpot(index.toDouble(), value.toDouble()),
              ],
              color: color,
              barWidth: 2,
              isCurved: false,
              dotData: FlDotData(show: points.length <= 12),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: .08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.entries});

  final List<(String, Color)> entries;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    children: [
      for (final (label, color) in entries)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTypography.metadata),
          ],
        ),
    ],
  );
}

class _CategoryBreakdown extends StatefulWidget {
  const _CategoryBreakdown({
    required this.data,
    required this.income,
    required this.hidden,
    required this.onOpen,
  });

  final ReportData data;
  final bool income;
  final bool hidden;
  final ValueChanged<CategorySlice> onOpen;

  @override
  State<_CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<_CategoryBreakdown> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slices = widget.data.categories;
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.amount);
    final focus = _touched != null && _touched! < slices.length
        ? slices[_touched!]
        : null;
    final note = AppTypography.metadata.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          if (!widget.hidden)
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 62,
                      // Surface gap between slices.
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) return;
                          final index =
                              response?.touchedSection?.touchedSectionIndex;
                          setState(
                            () => _touched = index == null || index < 0
                                ? null
                                : index,
                          );
                        },
                      ),
                      sections: [
                        for (final (index, slice) in slices.indexed)
                          PieChartSectionData(
                            value: slice.amount.toDouble(),
                            color: _slotColor(context, slice),
                            radius: index == _touched ? 30 : 24,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          focus?.name ?? 'Total',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: note,
                        ),
                        FittedBox(
                          child: Text(
                            MoneyFormatter.formatPaise(focus?.amount ?? total),
                            style: AppTypography.fieldValue.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (focus != null && total > 0)
                          Text(
                            '${(focus.amount / total * 100).toStringAsFixed(0)}%',
                            style: note,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.hidden) const SizedBox(height: AppSpacing.sm),
          // The list doubles as the legend and the table view.
          for (final (index, slice) in slices.indexed)
            _CategoryRow(
              slice: slice,
              color: _slotColor(context, slice),
              share: total == 0 ? 0 : slice.amount / total,
              income: widget.income,
              hidden: widget.hidden,
              highlighted: index == _touched,
              onTap: slice.isOther ? null : () => widget.onOpen(slice),
            ),
          if (widget.data.categoryCount > ReportData.colorSlots)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Smaller categories are grouped as Other. Filter by '
                'category to see one on its own.',
                style: note,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.slice,
    required this.color,
    required this.share,
    required this.income,
    required this.hidden,
    required this.highlighted,
    required this.onTap,
  });

  final CategorySlice slice;
  final Color color;
  final double share;
  final bool income;
  final bool hidden;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final change = slice.previousAmount == 0
        ? null
        : (slice.amount - slice.previousAmount) / slice.previousAmount * 100;
    // More spending is bad, more income is good.
    final good = change != null && ((change < 0) != income);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: highlighted ? color.withValues(alpha: .08) : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    slice.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.fieldValue.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  hidden
                      ? hiddenAmountMask
                      : MoneyFormatter.formatPaise(slice.amount),
                  style: AppTypography.fieldValue.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  )
                else
                  const SizedBox(width: 18),
              ],
            ),
            if (!hidden) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 12 + AppSpacing.sm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 4,
                        color: color,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 112,
                    child: Text(
                      '${(share * 100).toStringAsFixed(0)}% · '
                      '${slice.count} txn'
                      '${change == null ? '' : ' · ${change >= 0 ? '▲' : '▼'}'
                                '${change.abs().toStringAsFixed(0)}%'}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metadata.copyWith(
                        color: change == null
                            ? scheme.onSurfaceVariant
                            : good
                            ? scheme.positiveText
                            : scheme.negativeText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountBreakdown extends StatelessWidget {
  const _AccountBreakdown({
    required this.data,
    required this.income,
    required this.hidden,
    required this.onOpen,
  });

  final ReportData data;
  final bool income;
  final bool hidden;
  final ValueChanged<AccountSlice> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows =
        data.accounts.where((a) => (income ? a.income : a.expense) > 0).toList()
          ..sort(
            (a, b) => income
                ? b.income.compareTo(a.income)
                : b.expense.compareTo(a.expense),
          );
    final peak = rows.isEmpty
        ? 1
        : (income ? rows.first.income : rows.first.expense);
    final color = income ? scheme.positiveText : scheme.negativeText;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (final account in rows)
            InkWell(
              onTap: () => onOpen(account),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.fieldValue,
                          ),
                        ),
                        Text(
                          hidden
                              ? hiddenAmountMask
                              : MoneyFormatter.formatPaise(
                                  income ? account.income : account.expense,
                                ),
                          style: AppTypography.fieldValue.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (!hidden) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value:
                              (income ? account.income : account.expense) /
                              peak,
                          minHeight: 4,
                          color: color,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No ${income ? 'income' : 'spending'} in this range.',
                style: AppTypography.supporting.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
