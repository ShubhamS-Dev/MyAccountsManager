import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      final dateOnlyUtc = DateTime.utc(_date.year, _date.month, _date.day)
          .millisecondsSinceEpoch;
      await ref.read(transactionsRepositoryProvider).createTransaction(
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

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(activeAccountsProvider);
    final categories = ref.watch(activeCategoriesByTypeProvider(_kind.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
            child: TextButton(
          onPressed: () => ref.invalidate(activeAccountsProvider),
          child: const Text('Could not load Accounts. Retry'),
        )),
        data: (accountRows) {
          if (accountRows.isEmpty) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Create an Account before adding a transaction.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () => context.push('/accounts/new'),
                    child: const Text('Create Account')),
              ]),
            ));
          }
          _accountId ??= accountRows.length == 1 ? accountRows.first.id : null;
          if (_accountId != null && !accountRows.any((a) => a.id == _accountId)) {
            _accountId = null;
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SegmentedButton<TransactionKind>(
                  segments: const [
                    ButtonSegment(
                        value: TransactionKind.expense,
                        label: Text('Expense'),
                        icon: Icon(Icons.arrow_upward_rounded)),
                    ButtonSegment(
                        value: TransactionKind.income,
                        label: Text('Income'),
                        icon: Icon(Icons.arrow_downward_rounded)),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (selection) => setState(() {
                    _kind = selection.first;
                    _categoryId = null;
                  }),
                ),
                const SizedBox(height: 22),
                Text(
                    _kind == TransactionKind.expense
                        ? 'How much did you spend?'
                        : 'How much did you receive?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: '0.00',
                      labelText: 'Amount',
                      border: OutlineInputBorder()),
                  validator: (value) {
                    final paise = _parsePaise(value ?? '');
                    return paise == null || paise <= 0
                        ? 'Enter an amount greater than ₹0 (up to 2 decimal places).'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(
                      labelText: 'Account', border: OutlineInputBorder()),
                  items: [
                    for (final account in accountRows)
                      DropdownMenuItem(
                          value: account.id, child: Text(account.name))
                  ],
                  onChanged: (value) => setState(() => _accountId = value),
                  validator: (value) =>
                      value == null ? 'Select an Account.' : null,
                ),
                const SizedBox(height: 16),
                categories.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => TextButton(
                      onPressed: () => ref.invalidate(
                          activeCategoriesByTypeProvider(_kind.name)),
                      child: const Text('Could not load categories. Retry')),
                  data: (categoryRows) {
                    if (categoryRows.isEmpty) {
                      return const Text(
                          'No active categories for this transaction type.');
                    }
                    if (_categoryId != null &&
                        !categoryRows.any((c) => c.id == _categoryId))
                      _categoryId = null;
                    return DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(
                          labelText: 'Category', border: OutlineInputBorder()),
                      items: [
                        for (final category in categoryRows)
                          DropdownMenuItem(
                              value: category.id, child: Text(category.name))
                      ],
                      onChanged: (value) => setState(() => _categoryId = value),
                      validator: (value) =>
                          value == null ? 'Select a category.' : null,
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Transaction date'),
                  subtitle: Text(
                      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLength: 500,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'What was this transaction for?',
                      border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save transaction'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
