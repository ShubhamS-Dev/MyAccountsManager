import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';

import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/time/today_provider.dart';

import '../../accounts/accounts_providers.dart';
import '../../categories/categories_providers.dart';
import '../transactions_providers.dart';
import 'note_suggestion_chips.dart';

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

  // Note-driven suggestions. The category is only ever suggested here; the
  // user applies it with "Use".
  String? _suggestedCategoryId;
  List<String> _noteSuggestions = const [];
  Timer? _suggestDebounce;
  int _suggestRequest = 0;
  int _categoryFieldVersion = 0;

  // Unsaved-changes tracking for the back-navigation guard.
  String? _pristine;
  String get _snapshot => [
    _amountController.text,
    _noteController.text,
    _accountId,
    _categoryId,
    _kind,
    _date,
  ].join('\u0000');
  bool get _dirty => !_saving && _pristine != null && _snapshot != _pristine;
  String? _error;

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _noteController.removeListener(_noteChanged);
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
    _date = DateTime.fromMillisecondsSinceEpoch(
      transaction.transactionDate,
      isUtc: true,
    );
    final amount = transaction.amountPaise;
    _amountController.text =
        '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
    _noteController.text = transaction.note ?? '';
    _noteController.addListener(_noteChanged);
    _pristine = _snapshot;
  }

  void _noteChanged() {
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(
      const Duration(milliseconds: 300),
      _refreshSuggestions,
    );
  }

  Future<void> _refreshSuggestions() async {
    final type = _kind;
    if (type == null) return;
    final request = ++_suggestRequest;
    final note = _noteController.text;
    final repository = ref.read(transactionsRepositoryProvider);
    List<String> notes = const [];
    String? categoryId;
    try {
      notes = await repository.suggestNotes(type, note);
      categoryId = await repository.suggestCategoryForNote(type, note);
    } catch (_) {
      // Suggestions are optional and must never block editing.
    }
    if (!mounted || request != _suggestRequest) return;
    setState(() {
      _noteSuggestions = notes;
      _suggestedCategoryId = categoryId;
    });
  }

  void _useNote(String note) {
    _noteController.value = TextEditingValue(
      text: note,
      selection: TextSelection.collapsed(offset: note.length),
    );
    _suggestDebounce?.cancel();
    _refreshSuggestions();
  }

  void _useSuggestedCategory() {
    setState(() {
      _categoryId = _suggestedCategoryId;
      _categoryFieldVersion++;
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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
        _date == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dateOnlyUtc = DateTime.utc(
        _date!.year,
        _date!.month,
        _date!.day,
      ).millisecondsSinceEpoch;
      await ref
          .read(transactionsRepositoryProvider)
          .updateTransaction(
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
  Widget build(BuildContext context) =>
      UnsavedChangesGuard(dirty: _dirty, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final transaction = ref.watch(
      transactionByIdProvider(widget.transactionId),
    );
    final accounts = ref.watch(allAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit transaction')),
      body: transaction.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(transactionByIdProvider(widget.transactionId)),
            child: const Text('Could not load transaction. Retry'),
          ),
        ),
        data: (row) {
          if (row == null || row.deletedAt != null) {
            return const Center(
              child: Text(
                'This transaction is unavailable or has been moved to Trash.',
              ),
            );
          }
          _initialize(row);
          return accounts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(allAccountsProvider),
                child: const Text('Could not load Accounts. Retry'),
              ),
            ),
            data: (accountRows) {
              if (!accountRows.any((account) => account.id == _accountId)) {
                return const Center(
                  child: Text('The original Account is unavailable.'),
                );
              }
              final categories = ref.watch(
                activeCategoriesByTypeProvider(_kind!),
              );
              return Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('Expense'),
                          icon: Icon(Icons.north_east_rounded),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('Income'),
                          icon: Icon(Icons.south_west_rounded),
                        ),
                      ],
                      selected: {_kind!},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _kind = selection.first;
                          _categoryId = null;
                          _suggestedCategoryId = null;
                          _noteSuggestions = const [];
                        });
                        _refreshSuggestions();
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final account in accountRows)
                          DropdownMenuItem(
                            value: account.id,
                            enabled:
                                account.archivedAt == null ||
                                account.id == _accountId,
                            child: Text(
                              '${account.name}${account.archivedAt == null ? '' : ' (Archived — keep only)'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                      validator: (value) =>
                          value == null ? 'Select an Account.' : null,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Transaction date'),
                      subtitle: Text(
                        _isToday(_date!)
                            ? 'Today'
                            : DateOnly.format(
                                DateOnly.toUtcEpochMilliseconds(_date!),
                              ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickDate,
                    ),
                    if (isScheduledDate(
                      DateOnly.toUtcEpochMilliseconds(_date!),
                      ref.watch(todayProvider),
                    ))
                      const _ScheduledNote(),
                    TextFormField(
                      controller: _noteController,
                      maxLength: 500,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_noteController.text.trim().isEmpty)
                      NoteSuggestionChips(
                        key: const ValueKey('edit-transaction-recent-notes'),
                        label: 'Recent',
                        notes:
                            ref
                                .watch(recentNotesProvider(_kind!))
                                .valueOrNull ??
                            const [],
                        onSelected: _useNote,
                      )
                    else
                      NoteSuggestionChips(
                        key: const ValueKey('edit-transaction-note-matches'),
                        label: 'Suggestions',
                        notes: _noteSuggestions,
                        onSelected: _useNote,
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final paise = _parsePaise(value ?? '');
                        return paise == null || paise <= 0
                            ? 'Enter an amount greater than ₹0 (up to 2 decimal places).'
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    categories.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stack) => TextButton(
                        onPressed: () => ref.invalidate(
                          activeCategoriesByTypeProvider(_kind!),
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
                        if (categoryRows.isEmpty) {
                          return const Text(
                            'No active categories for this transaction type.',
                          );
                        }
                        final suggestion =
                            _suggestedCategoryId == null ||
                                _suggestedCategoryId == _categoryId
                            ? null
                            : categoryRows
                                  .where(
                                    (category) =>
                                        category.id == _suggestedCategoryId,
                                  )
                                  .firstOrNull;
                        final dropdown = DropdownButtonFormField<String>(
                          key: ValueKey(
                            'edit-transaction-category-$_categoryFieldVersion',
                          ),
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
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
                        );
                        if (suggestion == null) return dropdown;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            dropdown,
                            Row(
                              key: const ValueKey(
                                'edit-transaction-category-suggestion',
                              ),
                              children: [
                                const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Suggested from note: ${suggestion.name}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _useSuggestedCategory,
                                  child: const Text('Use'),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : () => _save(row.accountId),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
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

/// Explains that a future-dated transaction is saved as Scheduled.
class _ScheduledNote extends StatelessWidget {
  const _ScheduledNote();

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
