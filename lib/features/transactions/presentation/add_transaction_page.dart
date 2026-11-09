import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../accounts/accounts_providers.dart';
import '../../categories/categories_providers.dart';
import '../transactions_providers.dart';

enum TransactionKind { expense, income }

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({super.key});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TransactionKind _kind = TransactionKind.expense;
  String? _accountId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? _parsePaise(String raw) {
    final value = raw.trim().replaceAll(',', '');
    if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) return null;
    final paise = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return rupees * 100 + paise;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _parsePaise(_amountController.text);
    if (amount == null ||
        amount <= 0 ||
        _accountId == null ||
        _categoryId == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dateOnlyUtc = DateTime.utc(
        _date.year,
        _date.month,
        _date.day,
      ).millisecondsSinceEpoch;
      await ref
          .read(transactionsRepositoryProvider)
          .createTransaction(
            accountId: _accountId!,
            categoryId: _categoryId!,
            type: _kind.name,
            amountPaise: amount,
            transactionDate: dateOnlyUtc,
            note: _noteController.text,
          );
      ref.invalidate(accountBalancePaiseProvider(_accountId!));
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save transaction. Check your selections and try again.';
        });
      }
    }
  }

  Widget _label(BuildContext context, String value, {String? hint}) {
    final style = AppTypography.supporting.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(value, style: style),
          if (hint != null) ...[
            const SizedBox(width: 5),
            Text(
              hint,
              style: AppTypography.supporting.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _surface(BuildContext context, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(activeAccountsProvider);
    final categories = ref.watch(activeCategoriesByTypeProvider(_kind.name));
    final scheme = Theme.of(context).colorScheme;
    final accent = _kind == TransactionKind.expense
        ? AppColors.negative
        : AppColors.positive;
    return Scaffold(
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 34),
                    const SizedBox(height: 12),
                    const Text(
                      'Create an Account before adding a transaction.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => context.push('/accounts/new'),
                      child: const Text('Create Account'),
                    ),
                  ],
                ),
              ),
            );
          }
          _accountId ??= accountRows.length == 1 ? accountRows.first.id : null;
          if (_accountId != null &&
              !accountRows.any((a) => a.id == _accountId)) {
            _accountId = null;
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.65,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SegmentedButton<TransactionKind>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
                      textStyle: const WidgetStatePropertyAll(
                        AppTypography.button,
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: TransactionKind.expense,
                        label: Text('Expense'),
                        icon: Icon(Icons.arrow_upward_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: TransactionKind.income,
                        label: Text('Income'),
                        icon: Icon(Icons.arrow_downward_rounded, size: 16),
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (selection) => setState(() {
                      _kind = selection.first;
                      _categoryId = null;
                    }),
                  ),
                ),
                const SizedBox(height: 18),
                _label(context, 'Account'),
                _surface(
                  context,
                  DropdownButtonFormField<String>(
                    initialValue: _accountId,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    decoration: const InputDecoration(
                      hintText: 'Choose an account',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    menuMaxHeight: 320,
                    items: [
                      for (final account in accountRows)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            account.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _accountId = value),
                    validator: (value) =>
                        value == null ? 'Select an Account.' : null,
                  ),
                ),
                const SizedBox(height: 15),
                _label(context, 'Transaction date'),
                _surface(
                  context,
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            _isToday(_date)
                                ? 'Today'
                                : DateOnly.format(
                                    DateOnly.toUtcEpochMilliseconds(_date),
                                  ),
                            style: AppTypography.supporting.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                _label(context, 'Note', hint: 'Optional'),
                TextFormField(
                  controller: _noteController,
                  maxLength: 500,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.supporting.copyWith(
                    color: scheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'What was this transaction for?',
                    counterStyle: AppTypography.supporting,
                  ),
                ),
                const SizedBox(height: 14),
                _label(context, 'Amount'),
                _surface(
                  context,
                  Row(
                    children: [
                      Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTypography.transactionAmount.copyWith(
                            fontSize: 22,
                            color: scheme.onSurface,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          validator: (value) {
                            final paise = _parsePaise(value ?? '');
                            return paise == null || paise <= 0
                                ? 'Enter an amount greater than ₹0 (up to 2 decimal places).'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _kind == TransactionKind.expense
                      ? 'How much did you spend?'
                      : 'How much did you receive?',
                  style: AppTypography.supporting.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 15),
                _label(context, 'Category'),
                categories.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => TextButton(
                    onPressed: () => ref.invalidate(
                      activeCategoriesByTypeProvider(_kind.name),
                    ),
                    child: const Text('Could not load categories. Retry'),
                  ),
                  data: (categoryRows) {
                    if (categoryRows.isEmpty) {
                      return _surface(
                        context,
                        const Text(
                          'No active categories for this transaction type.',
                          style: AppTypography.supporting,
                        ),
                      );
                    }
                    if (_categoryId != null &&
                        !categoryRows.any((c) => c.id == _categoryId)) {
                      _categoryId = null;
                    }
                    return _surface(
                      context,
                      DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        decoration: const InputDecoration(
                          hintText: 'Choose a category',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        menuMaxHeight: 320,
                        items: [
                          for (final category in categoryRows)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(
                                category.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                        validator: (value) =>
                            value == null ? 'Select a category.' : null,
                      ),
                    );
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save transaction'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
