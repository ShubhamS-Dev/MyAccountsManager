import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';

import '../../accounts/accounts_providers.dart';
import '../../categories/categories_providers.dart';
import '../transactions_providers.dart';

class EditTransactionPage extends ConsumerStatefulWidget {
  const EditTransactionPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<EditTransactionPage> createState() =>
      _EditTransactionPageState();
}

class _EditTransactionPageState extends ConsumerState<EditTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _accountId;
  String? _categoryId;
  String? _kind;
  DateTime? _date;
  bool _initialized = false;
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

  void _initialize(TransactionRow transaction) {
    if (_initialized) return;
    _initialized = true;
    _accountId = transaction.accountId;
    _categoryId = transaction.categoryId;
    _kind = transaction.type;
    _date = DateTime.fromMillisecondsSinceEpoch(transaction.transactionDate,
        isUtc: true);
    final amount = transaction.amountPaise;
    _amountController.text =
        '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
    _noteController.text = transaction.note ?? '';
  }

  Future<void> _pickDate() async {
    final current = _date ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(String originalAccountId) async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _parsePaise(_amountController.text);
    if (amount == null ||
        amount <= 0 ||
        _accountId == null ||
        _categoryId == null ||
        _kind == null ||
        _date == null) return;

    setState(() {
      _saving = true;
      _error = null;
    })
    try {
      final dateOnlyUtc = DateTime.utc(_date!.year, _date!.month, _date!.day)
          .millisecondsSinceEpoch;
      await ref.read(transactionsRepositoryProvider).updateTransaction(
            transactionId: widget.transactionId,
            accountId: _accountId!,
            categoryId: _categoryId!,
            type: _kind!,
            amountPaise: amount,
            transactionDate: dateOnlyUtc,
            note: _noteController.text,
          );
      ref.invalidate(accountBalancePaiseProvider(originalAccountId));
      ref.invalidate(accountBalancePaiseProvider(_accountId!));
      ref.invalidate(transactionByIdProvider(widget.transactionId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not update transaction. Check the Account and Category selections.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction =
        ref.watch(transactionByIdProvider(widget.transactionId));
    final accounts = ref.watch(allAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit transaction')),
      body: transaction.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
            child: TextButton(
                onPressed: () => ref
                    .invalidate(transactionByIdProvider(widget.transactionId)),
                child: const Text('Could not load transaction. Retry'))),
        data: (row) {
          if (row == null || row.deletedAt != null)
            return const Center(
                child: Text(
                    'This transaction is unavailable or has been moved to Trash.'))
          _initialize(row);
          return accounts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
                child: TextButton(
                    onPressed: () => ref.invalidate(allAccountsProvider),
                    child: const Text('Could not load Accounts. Retry'))),
            data: (accountRows) {
              if (!accountRows.any((account) => account.id == _accountId))
                return const Center(
                    child: Text('The original Account is unavailable.'))
              final categories =
                  ref.watch(activeCategoriesByTypeProvider(_kind!));
              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'expense',
                            label: Text('Expense'),
                            icon: Icon(Icons.arrow_upward_rounded)),
                        ButtonSegment(
                            value: 'income',
                            label: Text('Income'),
                            icon: Icon(Icons.arrow_downward_rounded)),
                      ],
                      selected: {_kind!},
                      onSelectionChanged: (selection) => setState(() {
                        _kind = selection.first;
                        _categoryId = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          prefixText: '₹ ',
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
                            value: account.id,
                            enabled: account.archivedAt == null ||
                                account.id == _accountId,
                            child: Text(
                                '${account.name}${account.archivedAt == null ? '' : ' (Archived — keep only)'}'),
                          ),
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
                              activeCategoriesByTypeProvider(_kind!)),
                          child:
                              const Text('Could not load categories. Retry')),
                      data: (categoryRows) {
                        if (_categoryId != null &&
                            !categoryRows
                                .any((category) => category.id == _categoryId))
                          _categoryId = null;
                        if (categoryRows.isEmpty) { return const Text(
                              'No active categories for this transaction type.')
                        return DropdownButtonFormField<String>(
                          initialValue: _categoryId,
                          decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder()),
                          items: [
                            for (final category in categoryRows)
                              DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name))
                          ],
                          onChanged: (value) =>
                              setState(() => _categoryId = value),
                          validator: (value) =>
                              value == null ? 'Select a category.' : null,
                        ); }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Transaction date'),
                      subtitle: Text(
                          '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickDate,
                    ),
                    TextFormField(
                      controller: _noteController,
                      maxLength: 500,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          labelText: 'Note (optional)',
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
                      onPressed: _saving ? null : () => _save(row.accountId),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Update transaction'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
