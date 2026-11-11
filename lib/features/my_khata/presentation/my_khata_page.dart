import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../data/khata_repository.dart';
import '../khata_providers.dart';
import 'khata_widgets.dart';

enum _PeopleFilter { all, open, overdue, settled }

/// MyKhata tab: independent lending and borrowing ledger.
class MyKhataPage extends ConsumerStatefulWidget {
  const MyKhataPage({super.key});

  @override
  ConsumerState<MyKhataPage> createState() => _MyKhataPageState();
}

class _MyKhataPageState extends ConsumerState<MyKhataPage> {
  final _searchController = TextEditingController();
  _PeopleFilter _filter = _PeopleFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(khataPeopleSummariesProvider);
    final totals = ref.watch(khataTotalsProvider);
    final hidden = ref.watch(amountsHiddenProvider);
    final scheme = Theme.of(context).colorScheme;
    final overdue = (ref.watch(khataEntriesProvider(null)).valueOrNull ?? [])
        .where(isOverdue)
        .toList();
    final overduePeople = {for (final item in overdue) item.entry.personId};

    return people.when(
      loading: () => const SkeletonList(rows: 5),
      error: (error, stack) => ScreenErrorState(
        message: 'MyKhata could not be loaded.',
        onRetry: () => ref.invalidate(khataPeopleSummariesProvider),
      ),
      data: (items) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = items.where((summary) {
          final matchesQuery =
              query.isEmpty ||
              summary.person.name.toLowerCase().contains(query) ||
              (summary.person.phone ?? '').contains(query);
          final matchesFilter = switch (_filter) {
            _PeopleFilter.all => true,
            _PeopleFilter.open => !summary.isSettled,
            _PeopleFilter.overdue => overduePeople.contains(summary.person.id),
            _PeopleFilter.settled => summary.isSettled,
          };
          return matchesQuery && matchesFilter;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            112,
          ),
          children: [
            _KhataHero(
              totals: totals.valueOrNull,
              hidden: hidden,
              onToggle: () =>
                  ref.read(amountsHiddenProvider.notifier).set(!hidden),
              overdueEntries: overdue.length,
              onShowOverdue: () =>
                  setState(() => _filter = _PeopleFilter.overdue),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'People',
              action: 'Add',
              onAction: () => context.push('/khata/people/new'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              AppCard(
                child: EmptyState(
                  title: 'Start your khata',
                  message:
                      'Add a person to track money you lend or borrow. It never affects your Account balances.',
                  icon: Icons.people_outline_rounded,
                  actionLabel: 'Add person',
                  onAction: () => context.push('/khata/people/new'),
                ),
              )
            else ...[
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search people',
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
              const SizedBox(height: AppSpacing.sm),
              AppSegmentedControl<_PeopleFilter>(
                selected: _filter,
                onChanged: (filter) => setState(() => _filter = filter),
                options: const [
                  SegmentOption(value: _PeopleFilter.all, label: 'All'),
                  SegmentOption(value: _PeopleFilter.open, label: 'Open'),
                  SegmentOption(value: _PeopleFilter.overdue, label: 'Overdue'),
                  SegmentOption(value: _PeopleFilter.settled, label: 'Settled'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (filtered.isEmpty)
                AppCard(
                  child: EmptyState(
                    title: 'No matching people',
                    message: 'Try another name or filter.',
                    icon: Icons.search_off_rounded,
                    actionLabel: 'Show everyone',
                    onAction: () {
                      _searchController.clear();
                      setState(() => _filter = _PeopleFilter.all);
                    },
                  ),
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (index, summary) in filtered.indexed) ...[
                        if (index > 0) const Divider(height: 1, indent: 68),
                        _PersonRow(
                          summary: summary,
                          hidden: hidden,
                          onTap: () => context.push(
                            '/khata/people/${summary.person.id}',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'MyKhata is a separate ledger and never changes Account balances, income or expenses.',
                textAlign: TextAlign.center,
                style: AppTypography.metadata.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KhataHero extends StatelessWidget {
  const _KhataHero({
    required this.totals,
    required this.hidden,
    required this.onToggle,
    this.overdueEntries = 0,
    this.onShowOverdue,
  });

  final KhataTotals? totals;
  final bool hidden;
  final VoidCallback onToggle;
  final int overdueEntries;
  final VoidCallback? onShowOverdue;

  String _money(int paise) =>
      hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(paise);

  @override
  Widget build(BuildContext context) {
    final net = totals?.netPaise ?? 0;
    return GradientCard(
      colors: const [Color(0xFF6D28D9), AppColors.primary],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'NET KHATA POSITION',
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
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: AmountText(
              hidden
                  ? hiddenAmountMask
                  : '${net > 0 ? '+' : ''}${MoneyFormatter.formatPaise(net)}',
              key: ValueKey('$hidden-$net'),
              style: AppTypography.balance.copyWith(
                color: Colors.white,
                fontSize: 32,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            net == 0
                ? 'All square with everyone'
                : net > 0
                ? 'Overall, people owe you'
                : 'Overall, you owe people',
            style: AppTypography.supporting.copyWith(
              color: Colors.white.withValues(alpha: .82),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: "You'll get",
                  value: _money(totals?.receivablePaise ?? 0),
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroMetric(
                  label: "You'll give",
                  value: _money(totals?.payablePaise ?? 0),
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
          if (overdueEntries > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                onTap: onShowOverdue,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.touchTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            overdueEntries == 1
                                ? '1 entry is overdue'
                                : '$overdueEntries entries are overdue',
                            style: AppTypography.fieldValue.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'View',
                          style: AppTypography.button.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm + 2),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.metadata.copyWith(
                  color: Colors.white.withValues(alpha: .82),
                ),
              ),
              AmountText(
                value,
                style: AppTypography.transactionAmount.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.summary,
    required this.hidden,
    required this.onTap,
  });

  final KhataPersonSummary summary;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final person = summary.person;
    final subtitle = summary.totalEntries == 0
        ? 'No entries yet'
        : summary.isSettled
        ? 'All settled · ${summary.totalEntries} ${summary.totalEntries == 1 ? 'entry' : 'entries'}'
        : '${summary.openEntries} open · last ${DateOnly.format(summary.lastEntryDate!)}';
    // One spoken item per row: name, amounts and status together.
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            children: [
              PersonAvatar(name: person.name, color: personColor(person)),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.fieldValue.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metadata.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: NetPositionLabel(
                  netPaise: summary.netPaise,
                  hidden: hidden,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
