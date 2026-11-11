import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/icon_resolvers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/indian_amount_input_formatter.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../accounts/accounts_providers.dart';
import '../../recurring/domain/recurrence.dart';

/// Form building blocks shared by Add and Edit Transaction, so both screens
/// look and behave the same.

enum TransactionKind { expense, income }

/// Shared minimum height of the Note, Amount and Category boxes.
const double transactionInputBoxMinHeight = 60;

const int maxTransactionAmountPaise = 99999999999999;

/// Parses a typed amount ("1,250.50") to paise, or null when invalid.
int? parseTransactionAmountPaise(String raw) {
  final value = raw.trim();
  if (value.isEmpty ||
      !RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(value.replaceAll(',', ''))) {
    return null;
  }
  try {
    final paise = MoneyFormatter.parseRupeesToPaise(value);
    return paise > 0 && paise <= maxTransactionAmountPaise ? paise : null;
  } on FormatException {
    return null;
  }
}

String? validateTransactionAmount(String raw) =>
    parseTransactionAmountPaise(raw) == null
    ? 'Enter an amount greater than ₹0 (up to 2 decimal places).'
    : null;

/// The type's "Others" category, used when the user saves without picking.
String? othersCategoryId(List<CategoryRow> categories) => categories
    .where((category) => category.name.trim().toLowerCase() == 'others')
    .firstOrNull
    ?.id;

Color transactionAccent(BuildContext context, TransactionKind kind) {
  final scheme = Theme.of(context).colorScheme;
  return kind == TransactionKind.expense
      ? scheme.negativeText
      : scheme.positiveText;
}

class TransactionTypeSelector extends StatelessWidget {
  const TransactionTypeSelector({
    super.key,
    required this.kind,
    required this.onChanged,
  });

  final TransactionKind kind;
  final ValueChanged<TransactionKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expense = kind == TransactionKind.expense;
    final selectedBackground = expense
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final selectedForeground = expense
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;

    return Container(
      height: 48,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: expense ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: FractionallySizedBox(
              widthFactor: .5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selectedBackground,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _TypeOption(
                label: 'Expense',
                icon: Icons.north_east_rounded,
                selected: expense,
                selectedColor: selectedForeground,
                onTap: () => onChanged(TransactionKind.expense),
              ),
              _TypeOption(
                label: 'Income',
                icon: Icons.south_west_rounded,
                selected: !expense,
                selectedColor: selectedForeground,
                onTap: () => onChanged(TransactionKind.income),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          key: ValueKey(
            'transaction-kind-${label.toLowerCase()}-${selected ? 'selected' : 'unselected'}',
          ),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: 48,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: AppTypography.button.copyWith(
                  color: selected ? selectedColor : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: selected ? selectedColor : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(label),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TransactionAccountSelector extends StatelessWidget {
  const TransactionAccountSelector({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.hidden,
    required this.keys,
    required this.controller,
    required this.onSelected,
  });

  /// May include one archived Account: the one an edited transaction uses.
  final List<AccountRow> accounts;
  final String? selectedId;
  final bool hidden;
  final Map<String, GlobalKey> keys;
  final ScrollController controller;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TransactionFieldHeading(title: 'Account'),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 20 + MediaQuery.textScalerOf(context).scale(48),
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final account = accounts[index];
              final selected = account.id == selectedId;
              final archived = account.archivedAt != null;
              final color = account.colorValue == null
                  ? scheme.primary
                  : Color(account.colorValue!);
              final key = keys.putIfAbsent(
                account.id,
                () => GlobalKey(debugLabel: 'account-${account.id}'),
              );
              return SizedBox(
                key: key,
                width: 150,
                child: Material(
                  color: selected ? scheme.primaryContainer : scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    onTap: () => onSelected(account.id),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(
                                resolveAccountIcon(account.iconKey),
                                size: 17,
                                color: color,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  account.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.fieldValue.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (archived)
                                Icon(
                                  Icons.archive_outlined,
                                  size: 12,
                                  color: scheme.onSurfaceVariant,
                                )
                              else if (account.isPinned)
                                Icon(
                                  Icons.push_pin_rounded,
                                  size: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (archived)
                            Text(
                              'Archived',
                              style: AppTypography.metadata.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          else
                            _AccountBalance(
                              accountId: account.id,
                              hidden: hidden,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AccountBalance extends ConsumerWidget {
  const _AccountBalance({required this.accountId, required this.hidden});

  final String accountId;
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (hidden) {
      return Text(
        hiddenAmountMask,
        semanticsLabel: 'amount hidden',
        style: AppTypography.metadata.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    final balance = ref.watch(accountBalancePaiseProvider(accountId));
    return balance.when(
      loading: () => Text(
        'Balance',
        style: AppTypography.metadata.copyWith(color: scheme.onSurfaceVariant),
      ),
      error: (error, stack) => Text(
        'Unavailable',
        style: AppTypography.metadata.copyWith(color: scheme.error),
      ),
      data: (value) => Text(
        MoneyFormatter.formatPaise(value ?? 0),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.metadata.copyWith(
          color: scheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class TransactionDateSelector extends StatelessWidget {
  const TransactionDateSelector({
    super.key,
    required this.date,
    required this.label,
    required this.onDate,
    required this.onPick,
    this.keyPrefix = 'add-transaction',
  });

  final DateTime date;
  final String label;
  final ValueChanged<DateTime> onDate;
  final VoidCallback onPick;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TransactionFieldHeading(title: 'Transaction date'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _DateChoice(
              label: 'Today',
              selected: isToday,
              onTap: () => onDate(today),
            ),
            _DateChoice(
              label: 'Yesterday',
              selected: isYesterday,
              onTap: () => onDate(yesterday),
            ),
            _DateChoice(
              key: ValueKey('$keyPrefix-pick-date'),
              label: isToday || isYesterday ? 'Pick date' : label,
              selected: !isToday && !isYesterday,
              icon: Icons.calendar_month_rounded,
              onTap: onPick,
            ),
          ],
        ),
        // A picked date already shows on its chip; Yesterday states its date.
        if (isYesterday) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.fieldValue.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: AppTypography.button.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionNoteInput extends StatelessWidget {
  const TransactionNoteInput({
    super.key,
    required this.controller,
    this.keyPrefix = 'add-transaction',
  });

  final TextEditingController controller;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TransactionFieldHeading(title: 'Note', hint: 'Optional'),
        const SizedBox(height: AppSpacing.sm),
        Container(
          // Matches the Amount box so the two inputs read as a pair.
          constraints: const BoxConstraints(
            minHeight: transactionInputBoxMinHeight,
          ),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: TextField(
            key: ValueKey('$keyPrefix-note-input'),
            controller: controller,
            maxLength: 500,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.sectionTitle.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'What was this transaction for?',
              hintStyle: AppTypography.sectionTitle.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
              filled: false,
              fillColor: Colors.transparent,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counter: controller.text.length > 400
                  ? Text(
                      '${controller.text.length}/500',
                      style: AppTypography.metadata.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class TransactionAmountInput extends StatelessWidget {
  const TransactionAmountInput({
    super.key,
    required this.controller,
    required this.kind,
    required this.error,
    required this.onChanged,
    required this.onQuickAdd,
    this.keyPrefix = 'add-transaction',
  });

  final TextEditingController controller;
  final TransactionKind kind;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onQuickAdd;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = transactionAccent(context, kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TransactionFieldHeading(title: 'Amount'),
        const SizedBox(height: AppSpacing.sm),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(
            minHeight: transactionInputBoxMinHeight,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: error == null ? scheme.outlineVariant : scheme.error,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Align(
                alignment: Alignment.center,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: AppTypography.amountInput.copyWith(color: accent),
                  child: const Text('₹'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  key: ValueKey('$keyPrefix-amount-input'),
                  controller: controller,
                  textAlignVertical: TextAlignVertical.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [IndianAmountInputFormatter()],
                  onChanged: onChanged,
                  style: AppTypography.amountInput.copyWith(
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: AppTypography.amountInput.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: .55),
                    ),
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            key: ValueKey('$keyPrefix-amount-error'),
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  error!,
                  style: AppTypography.fieldValue.copyWith(color: scheme.error),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickAddChip(label: '+100', onTap: () => onQuickAdd(100)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickAddChip(label: '+500', onTap: () => onQuickAdd(500)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickAddChip(
                label: '+1,000',
                onTap: () => onQuickAdd(1000),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          kind == TransactionKind.expense
              ? 'How much did you spend?'
              : 'How much did you receive?',
          style: AppTypography.supporting.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _QuickAddChip extends StatelessWidget {
  const _QuickAddChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.button.copyWith(color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Category field with the rich anchored dropdown and the note suggestion.
class TransactionCategorySelector extends StatelessWidget {
  const TransactionCategorySelector({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.suggestedId,
    required this.kind,
    required this.showValidation,
    required this.onSelected,
    this.keyPrefix = 'add-transaction',
  });

  final List<CategoryRow> categories;
  final String? selectedId;
  final String? suggestedId;
  final TransactionKind kind;
  final bool showValidation;
  final ValueChanged<String> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final income = kind == TransactionKind.income;
    final accent = transactionAccent(context, kind);
    final suggestion = categories
        .where((category) => category.id == suggestedId)
        .firstOrNull;
    final missing = showValidation && selectedId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TransactionFieldHeading(title: 'Category'),
        const SizedBox(height: AppSpacing.sm),
        if (categories.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'No active categories for this transaction type.',
              style: AppTypography.supporting.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          CategoryDropdown(
            key: ValueKey('$keyPrefix-category-dropdown'),
            categories: categories,
            selectedId: selectedId,
            suggestedId: suggestedId,
            income: income,
            accent: accent,
            hasError: missing,
            onSelected: onSelected,
          ),
        if (suggestion != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Suggested from note',
                style: AppTypography.metadata.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: CategoryChip(
              key: ValueKey('$keyPrefix-category-suggestion'),
              label: suggestion.name,
              icon: resolveCategoryIcon(
                suggestion.iconKey ?? suggestion.name,
                income: income,
              ),
              selected: suggestion.id == selectedId,
              color: categoryColor(suggestion, accent),
              iconColor: categoryColor(suggestion, accent),
              onTap: () => onSelected(suggestion.id),
            ),
          ),
        ],
        if (missing) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select a category.',
            style: AppTypography.supporting.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

Color categoryColor(CategoryRow category, Color fallback) =>
    category.colorValue == null ? fallback : Color(category.colorValue!);

/// A field that opens a compact popover anchored to itself, never a full
/// screen list. Shows search once there are enough categories to need it.
class CategoryDropdown extends StatefulWidget {
  const CategoryDropdown({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.suggestedId,
    required this.income,
    required this.accent,
    required this.hasError,
    required this.onSelected,
  });

  final List<CategoryRow> categories;
  final String? selectedId;
  final String? suggestedId;
  final bool income;
  final Color accent;
  final bool hasError;
  final ValueChanged<String> onSelected;

  @override
  State<CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<CategoryDropdown> {
  bool _open = false;

  Future<void> _openMenu() async {
    final navigator = Navigator.of(context);
    final box = context.findRenderObject()! as RenderBox;
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchor = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    FocusScope.of(context).unfocus();
    setState(() => _open = true);
    final picked = await navigator.push<String>(
      _CategoryMenuRoute(
        anchor: anchor,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        menu: _CategoryMenu(
          categories: widget.categories,
          selectedId: widget.selectedId,
          suggestedId: widget.suggestedId,
          income: widget.income,
          accent: widget.accent,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) widget.onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.categories
        .where((category) => category.id == widget.selectedId)
        .firstOrNull;
    final color = selected == null
        ? scheme.onSurfaceVariant
        : categoryColor(selected, widget.accent);
    final String subtitle;
    if (selected == null) {
      subtitle = 'Saved under Others if left empty';
    } else if (!selected.isActive) {
      subtitle = 'Hidden category';
    } else if (selected.id == widget.suggestedId) {
      subtitle = 'Matched to your note';
    } else {
      subtitle = widget.income ? 'Income category' : 'Expense category';
    }
    final borderColor = widget.hasError
        ? scheme.error
        : _open
        ? scheme.primary
        : scheme.outlineVariant;

    return Semantics(
      button: true,
      label: 'Category, ${selected?.name ?? 'none selected'}',
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: _openMenu,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(
              minHeight: transactionInputBoxMinHeight + 8,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 4,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: borderColor, width: _open ? 1.5 : 1),
            ),
            child: Row(
              children: [
                _CategoryTile(
                  icon: selected == null
                      ? Icons.category_outlined
                      : resolveCategoryIcon(
                          selected.iconKey ?? selected.name,
                          income: widget.income,
                        ),
                  color: color,
                  size: 44,
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected?.name ?? 'Choose a category',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sectionTitle.copyWith(
                          color: selected == null
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          fontWeight: selected == null
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.metadata.copyWith(
                          color:
                              selected?.id == widget.suggestedId &&
                                  selected != null
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .32),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: .22), color.withValues(alpha: .10)],
      ),
    ),
    child: Icon(icon, size: size * .48, color: color),
  );
}

class _CategoryMenuRoute extends PopupRoute<String> {
  _CategoryMenuRoute({
    required this.anchor,
    required this.menu,
    required this.capturedThemes,
    required this.barrierLabel,
  });

  final Rect anchor;
  final Widget menu;
  final CapturedThemes capturedThemes;

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: .06);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    return CustomSingleChildLayout(
      delegate: _CategoryMenuLayout(
        anchor: anchor,
        padding:
            media.padding + EdgeInsets.only(bottom: media.viewInsets.bottom),
      ),
      child: capturedThemes.wrap(menu),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: .96, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

/// Places the menu right under the field, or above it when there is more
/// room there, capped so it never covers the whole screen.
class _CategoryMenuLayout extends SingleChildLayoutDelegate {
  _CategoryMenuLayout({required this.anchor, required this.padding});

  static const double _gap = 6;
  static const double _edge = 8;
  static const double _maxHeight = 380;
  static const double _comfortable = 260;

  final Rect anchor;
  final EdgeInsets padding;

  ({bool below, double room}) _space(Size size) {
    final below = size.height - padding.bottom - anchor.bottom - _gap - _edge;
    final above = anchor.top - padding.top - _gap - _edge;
    final useBelow = below >= _comfortable || below >= above;
    return (below: useBelow, room: useBelow ? below : above);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final room = _space(constraints.biggest).room;
    return BoxConstraints(
      minWidth: anchor.width,
      maxWidth: anchor.width,
      maxHeight: room.clamp(160.0, _maxHeight),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = _space(size).below;
    final y = below
        ? anchor.bottom + _gap
        : anchor.top - _gap - childSize.height;
    final maxY = size.height - padding.bottom - childSize.height - _edge;
    return Offset(
      anchor.left,
      y.clamp(padding.top + _edge, maxY < padding.top + _edge ? y : maxY),
    );
  }

  @override
  bool shouldRelayout(_CategoryMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor || padding != oldDelegate.padding;
}

class _CategoryMenu extends StatefulWidget {
  const _CategoryMenu({
    required this.categories,
    required this.selectedId,
    required this.suggestedId,
    required this.income,
    required this.accent,
  });

  static const int searchThreshold = 8;

  final List<CategoryRow> categories;
  final String? selectedId;
  final String? suggestedId;
  final bool income;
  final Color accent;

  @override
  State<_CategoryMenu> createState() => _CategoryMenuState();
}

class _CategoryMenuState extends State<_CategoryMenu> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.categories
        : widget.categories
              .where((category) => category.name.toLowerCase().contains(query))
              .toList();
    final suggestion = query.isEmpty
        ? widget.categories
              .where((category) => category.id == widget.suggestedId)
              .firstOrNull
        : null;

    return Material(
      key: const ValueKey('category-dropdown-menu'),
      color: scheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2215172A),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.categories.length >= _CategoryMenu.searchThreshold)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: TextField(
                  key: const ValueKey('category-dropdown-search'),
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  style: AppTypography.fieldValue.copyWith(
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search categories',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm + 2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(color: scheme.primary),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                children: [
                  if (suggestion != null) ...[
                    const _MenuSection(
                      label: 'Suggested from note',
                      icon: Icons.auto_awesome_rounded,
                    ),
                    _CategoryMenuItem(
                      category: suggestion,
                      selected: suggestion.id == widget.selectedId,
                      income: widget.income,
                      accent: widget.accent,
                    ),
                  ],
                  if (query.isEmpty)
                    const _MenuSection(label: 'Recently used first'),
                  for (final category in matches)
                    _CategoryMenuItem(
                      category: category,
                      selected: category.id == widget.selectedId,
                      income: widget.income,
                      accent: widget.accent,
                    ),
                  if (matches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'No categories match "${_query.trim()}".',
                        textAlign: TextAlign.center,
                        style: AppTypography.supporting.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = icon == null ? scheme.onSurfaceVariant : scheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.metadata.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryMenuItem extends StatelessWidget {
  const _CategoryMenuItem({
    required this.category,
    required this.selected,
    required this.income,
    required this.accent,
  });

  final CategoryRow category;
  final bool selected;
  final bool income;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = categoryColor(category, accent);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color.withValues(alpha: .10) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md - 2),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(category.id),
          borderRadius: BorderRadius.circular(AppRadius.md - 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm - 2,
            ),
            child: Row(
              children: [
                _CategoryTile(
                  icon: resolveCategoryIcon(
                    category.iconKey ?? category.name,
                    income: income,
                  ),
                  color: color,
                  size: 38,
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.fieldValue.copyWith(
                      color: scheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (!category.isActive)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Icon(
                      Icons.visibility_off_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TransactionFieldHeading extends StatelessWidget {
  const TransactionFieldHeading({super.key, required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.fieldLabel.copyWith(color: scheme.onSurface),
        ),
        if (hint != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            hint!,
            style: AppTypography.metadata.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Explains that a future-dated transaction is saved as Scheduled.
class TransactionScheduledNote extends StatelessWidget {
  const TransactionScheduledNote({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      children: [
        const ScheduledBadge(),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Counts towards balances on this date.',
            style: AppTypography.supporting.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Repeat" chips plus the series summary and optional end date.
class TransactionRepeatSelector extends StatelessWidget {
  const TransactionRepeatSelector({
    super.key,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.onFrequency,
    required this.onEndDate,
  });

  final RecurringFrequency? frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final ValueChanged<RecurringFrequency?> onFrequency;
  final ValueChanged<DateTime?> onEndDate;

  Future<void> _pickEnd(BuildContext context) async {
    final first = startDate.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      helpText: 'Repeat until',
      initialDate: endDate ?? DateTime(first.year + 1, first.month, first.day),
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (picked != null) onEndDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = DateOnly.toUtcEpochMilliseconds(startDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TransactionFieldHeading(title: 'Repeat', hint: 'Optional'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _DateChoice(
              key: const ValueKey('repeat-never'),
              label: 'Never',
              selected: frequency == null,
              onTap: () => onFrequency(null),
            ),
            for (final option in RecurringFrequency.values)
              _DateChoice(
                key: ValueKey('repeat-${option.name}'),
                label: option.label,
                selected: frequency == option,
                onTap: () => onFrequency(option),
              ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: frequency == null
              ? const SizedBox(width: double.infinity)
              : Container(
                  key: const ValueKey('repeat-summary'),
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.repeat_rounded, color: scheme.primary),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recurrenceSummary(frequency!, start),
                              style: AppTypography.fieldValue.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Next on ${DateOnly.format(occurrenceDate(start, frequency!, 1))}. '
                              'Added automatically as Scheduled.',
                              style: AppTypography.metadata.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      InputChip(
                        key: const ValueKey('repeat-end'),
                        avatar: Icon(
                          endDate == null
                              ? Icons.all_inclusive_rounded
                              : Icons.event_rounded,
                          size: 16,
                        ),
                        label: Text(
                          endDate == null
                              ? 'No end'
                              : 'Until ${DateOnly.format(DateOnly.toUtcEpochMilliseconds(endDate!)).substring(0, 6)}',
                        ),
                        tooltip: 'Set an end date',
                        onPressed: () => _pickEnd(context),
                        onDeleted: endDate == null
                            ? null
                            : () => onEndDate(null),
                        deleteButtonTooltipMessage: 'Remove end date',
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
