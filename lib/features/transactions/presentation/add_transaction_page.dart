import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/icon_resolvers.dart';
import '../../../app/privacy_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../accounts/accounts_providers.dart';
import '../../categories/categories_providers.dart';
import '../transactions_providers.dart';

enum TransactionKind { expense, income }

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({super.key, this.initialType});

  final String? initialType;

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  static const int _maxAmountPaise = 99999999999999;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _accountScrollController = ScrollController();
  final Map<String, GlobalKey> _accountKeys = {};

  TransactionKind _kind = TransactionKind.expense;
  String? _accountId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _saved = false;
  bool _showValidation = false;
  String? _error;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    if (widget.initialType == 'income') {
      _kind = TransactionKind.income;
    }
    _noteController.addListener(_noteChanged);
  }

  void _noteChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _noteController.removeListener(_noteChanged);
    _amountController.dispose();
    _noteController.dispose();
    _accountScrollController.dispose();
    super.dispose();
  }

  int? _parsePaise(String raw) {
    final value = raw.trim();
    if (value.isEmpty ||
        !RegExp(
          r'^\d{1,12}(\.\d{1,2})?$',
        ).hasMatch(value.replaceAll(',', ''))) {
      return null;
    }
    try {
      final paise = MoneyFormatter.parseRupeesToPaise(value);
      return paise > 0 && paise <= _maxAmountPaise ? paise : null;
    } on FormatException {
      return null;
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _dateLabel() => _isToday(_date)
      ? 'Today'
      : DateOnly.format(DateOnly.toUtcEpochMilliseconds(_date));

  Color _accent() => _kind == TransactionKind.expense
      ? AppColors.negative
      : AppColors.positive;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _selectAccount(String id) {
    setState(() => _accountId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _accountKeys[id]?.currentContext;
      if (target != null && mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  void _addQuickAmount(int rupees) {
    final current = _amountController.text.trim().isEmpty
        ? 0
        : _parsePaise(_amountController.text) ?? 0;
    final next = current + rupees * 100;
    if (next > _maxAmountPaise) {
      setState(() {
        _amountError =
            'Maximum amount is ${MoneyFormatter.formatPaise(_maxAmountPaise)}.';
      });
      return;
    }
    final formatted = MoneyFormatter.formatPaise(next, includeSymbol: false);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() => _amountError = null);
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() {
      _showValidation = true;
      _error = null;
      _amountError = null;
    });

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _accountId == null || _categoryId == null) {
      if (_accountId == null) {
        setState(() => _error = 'Select an Account to continue.');
      } else if (_categoryId == null) {
        setState(() => _error = 'Select a Category to continue.');
      }
      return;
    }
    final amountPaise = _parsePaise(_amountController.text);
    if (amountPaise == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .createTransaction(
            accountId: _accountId!,
            categoryId: _categoryId!,
            type: _kind.name,
            amountPaise: amountPaise,
            transactionDate: DateOnly.toUtcEpochMilliseconds(_date),
            note: _noteController.text,
          );
      ref.invalidate(accountBalancePaiseProvider(_accountId!));
      if (!mounted) return;
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {
        // Haptic feedback is optional and must not affect a successful save.
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save transaction. Check your selections and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(activeAccountsProvider);
    final categories = ref.watch(activeCategoriesByTypeProvider(_kind.name));
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Add transaction')),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(activeAccountsProvider),
            child: const Text('Could not load Accounts. Retry'),
          ),
        ),
        data: (accountRows) {
          if (accountRows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyState(
                  title: 'No active accounts',
                  message:
                      'Add an Account before recording your first transaction.',
                  icon: Icons.account_balance_wallet_outlined,
                  actionLabel: 'Add account',
                  onAction: () => context.push('/accounts/new'),
                ),
              ),
            );
          }

          _accountId ??= accountRows.first.id;
          if (!accountRows.any((account) => account.id == _accountId)) {
            _accountId = accountRows.first.id;
          }

          return Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                _TypeSelector(
                  kind: _kind,
                  onChanged: (kind) {
                    setState(() {
                      _kind = kind;
                      _categoryId = null;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-account'),
                  child: _AccountSelector(
                    accounts: accountRows,
                    selectedId: _accountId,
                    hidden: ref.watch(amountsHiddenProvider),
                    keys: _accountKeys,
                    controller: _accountScrollController,
                    onSelected: _selectAccount,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-date'),
                  child: _DateSelector(
                    date: _date,
                    label: _dateLabel(),
                    onDate: (date) => setState(() => _date = date),
                    onPick: _pickDate,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-note'),
                  child: _NoteInput(controller: _noteController),
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-amount'),
                  child: _AmountInput(
                    controller: _amountController,
                    kind: _kind,
                    accent: accent,
                    error: _amountError,
                    onChanged: (_) {
                      if (_amountError != null) {
                        setState(() => _amountError = null);
                      }
                    },
                    onQuickAdd: _addQuickAmount,
                    validator: (value) {
                      final amount = _parsePaise(value ?? '');
                      if (amount == null) {
                        return 'Enter an amount greater than ₹0 (up to 2 decimal places).';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-category'),
                  child: categories.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) => TextButton(
                      onPressed: () => ref.invalidate(
                        activeCategoriesByTypeProvider(_kind.name),
                      ),
                      child: const Text('Could not load categories. Retry'),
                    ),
                    data: (categoryRows) {
                      if (_categoryId != null &&
                          !categoryRows.any(
                            (category) => category.id == _categoryId,
                          )) {
                        _categoryId = null;
                      }
                      return _CategorySelector(
                        categories: categoryRows,
                        selectedId: _categoryId,
                        kind: _kind,
                        showValidation: _showValidation,
                        onSelected: (id) => setState(() {
                          _categoryId = id;
                          _error = null;
                        }),
                      );
                    },
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: AppTypography.supporting.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: accounts.maybeWhen(
        data: (rows) => rows.isEmpty
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: PrimaryButton(
                    label: _saved ? 'Saved' : 'Save transaction',
                    gradient: AppColors.heroGradient,
                    onPressed: _saving || _saved ? null : _save,
                    leading: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        _saved ? Icons.check_rounded : Icons.save_rounded,
                        key: ValueKey(_saved),
                        size: 18,
                        color: scheme.onPrimary,
                      ),
                    ),
                    loading: _saving,
                  ),
                ),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.kind, required this.onChanged});

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
                icon: Icons.arrow_upward_rounded,
                selected: expense,
                selectedColor: selectedForeground,
                onTap: () => onChanged(TransactionKind.expense),
              ),
              _TypeOption(
                label: 'Income',
                icon: Icons.arrow_downward_rounded,
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

class _AccountSelector extends StatelessWidget {
  const _AccountSelector({
    required this.accounts,
    required this.selectedId,
    required this.hidden,
    required this.keys,
    required this.controller,
    required this.onSelected,
  });

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
        const _FieldHeading(title: 'Account'),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 68,
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final account = accounts[index];
              final selected = account.id == selectedId;
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
                              if (account.isPinned)
                                Icon(
                                  Icons.push_pin_rounded,
                                  size: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
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
        '₹ ••••••',
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

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.date,
    required this.label,
    required this.onDate,
    required this.onPick,
  });

  final DateTime date;
  final String label;
  final ValueChanged<DateTime> onDate;
  final VoidCallback onPick;

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
        const _FieldHeading(title: 'Transaction date'),
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
              label: 'Pick date',
              selected: !isToday && !isYesterday,
              icon: Icons.calendar_month_rounded,
              onTap: onPick,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (!isToday)
          Text(
            label,
            style: AppTypography.metadata.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
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
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
                  size: 15,
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

class _NoteInput extends StatelessWidget {
  const _NoteInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldHeading(title: 'Note', hint: 'Optional'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          radius: AppRadius.md,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: TextField(
            key: const ValueKey('add-transaction-note-input'),
            controller: controller,
            maxLength: 500,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.fieldValue.copyWith(color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: 'What was this transaction for?',
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

class _AmountInput extends StatelessWidget {
  const _AmountInput({
    required this.controller,
    required this.kind,
    required this.accent,
    required this.error,
    required this.onChanged,
    required this.onQuickAdd,
    required this.validator,
  });

  final TextEditingController controller;
  final TransactionKind kind;
  final Color accent;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onQuickAdd;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldHeading(title: 'Amount'),
        const SizedBox(height: AppSpacing.sm),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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
                  key: const ValueKey('add-transaction-amount-input'),
                  controller: controller,
                  textAlignVertical: TextAlignVertical.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_IndianAmountInputFormatter()],
                  validator: validator,
                  onChanged: onChanged,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
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
          Text(
            error!,
            style: AppTypography.supporting.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickAddChip(
                label: '+100',
                onTap: () => onQuickAdd(100),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickAddChip(
                label: '+500',
                onTap: () => onQuickAdd(500),
              ),
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

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selectedId,
    required this.kind,
    required this.showValidation,
    required this.onSelected,
  });

  final List<CategoryRow> categories;
  final String? selectedId;
  final TransactionKind kind;
  final bool showValidation;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final income = kind == TransactionKind.income;
    final accent = income ? AppColors.positive : AppColors.negative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldHeading(title: 'Category'),
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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final category in categories)
                _CategoryChoice(
                  category: category,
                  selected: category.id == selectedId,
                  accent: accent,
                  income: income,
                  onTap: () => onSelected(category.id),
                ),
            ],
          ),
        if (showValidation && selectedId == null) ...[
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

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.category,
    required this.selected,
    required this.accent,
    required this.income,
    required this.onTap,
  });

  final CategoryRow category;
  final bool selected;
  final Color accent;
  final bool income;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = category.colorValue == null
        ? accent
        : Color(category.colorValue!);
    return AnimatedScale(
      scale: selected ? 1.025 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: CategoryChip(
        label: category.name,
        icon: resolveCategoryIcon(
          category.iconKey ?? category.name,
          income: income,
        ),
        selected: selected,
        color: color,
        iconColor: color,
        onTap: onTap,
      ),
    );
  }
}

class _FieldHeading extends StatelessWidget {
  const _FieldHeading({required this.title, this.hint});

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

class _IndianAmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(raw)) return oldValue;

    final parts = raw.split('.');
    final whole = parts.first;
    if (whole.length > 12) return oldValue;

    final formattedWhole = whole.isEmpty
        ? ''
        : MoneyFormatter.formatPaise(
            int.parse(whole) * 100,
            includeSymbol: false,
          );
    final formatted = parts.length == 2
        ? '$formattedWhole.${parts[1]}'
        : formattedWhole;

    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final prefix = newValue.text.substring(0, cursor).replaceAll(',', '');
    final prefixParts = prefix.split('.');
    final prefixWhole = prefixParts.first;
    final formattedPrefix = prefixWhole.isEmpty
        ? ''
        : MoneyFormatter.formatPaise(
            int.parse(prefixWhole) * 100,
            includeSymbol: false,
          );
    final nextCursor =
        (formattedPrefix.length +
                (prefixParts.length == 2 ? 1 + prefixParts[1].length : 0))
            .clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
  }
}
