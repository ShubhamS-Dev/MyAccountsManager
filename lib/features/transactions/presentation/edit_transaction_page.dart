import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../../core/time/today_provider.dart';
import '../../accounts/accounts_providers.dart';
import '../../categories/categories_providers.dart';
import '../transactions_providers.dart';
import 'note_suggestion_chips.dart';
import 'transaction_form_widgets.dart';

class EditTransactionPage extends ConsumerStatefulWidget {
  const EditTransactionPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<EditTransactionPage> createState() =>
      _EditTransactionPageState();
}

class _EditTransactionPageState extends ConsumerState<EditTransactionPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _accountScrollController = ScrollController();
  final Map<String, GlobalKey> _accountKeys = {};

  TransactionRow? _original;
  TransactionKind _kind = TransactionKind.expense;
  String? _accountId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _saved = false;
  bool _showValidation = false;
  String? _error;
  String? _amountError;

  // Note-driven suggestions. Editing never overrides the saved category; the
  // suggestion is offered as a chip the user can tap.
  String? _suggestedCategoryId;
  List<String> _noteSuggestions = const [];
  Timer? _suggestDebounce;
  int _suggestRequest = 0;

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
  bool get _dirty =>
      !_saving && !_saved && _pristine != null && _snapshot != _pristine;

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _noteController.removeListener(_noteChanged);
    _amountController.dispose();
    _noteController.dispose();
    _accountScrollController.dispose();
    super.dispose();
  }

  void _initialize(TransactionRow transaction) {
    if (_original != null) return;
    _original = transaction;
    _accountId = transaction.accountId;
    _categoryId = transaction.categoryId;
    _kind = transaction.type == 'income'
        ? TransactionKind.income
        : TransactionKind.expense;
    final date = DateOnly.fromUtcEpochMilliseconds(transaction.transactionDate);
    _date = DateTime(date.year, date.month, date.day);
    _amountController.text = MoneyFormatter.formatPaise(
      transaction.amountPaise,
      includeSymbol: false,
    );
    _noteController.text = transaction.note ?? '';
    _noteController.addListener(_noteChanged);
    _pristine = _snapshot;
  }

  void _noteChanged() {
    if (!mounted) return;
    setState(() {});
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(
      const Duration(milliseconds: 300),
      _refreshSuggestions,
    );
  }

  Future<void> _refreshSuggestions() async {
    final request = ++_suggestRequest;
    final type = _kind.name;
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _dateLabel() => _isToday(_date)
      ? 'Today'
      : DateOnly.format(DateOnly.toUtcEpochMilliseconds(_date));

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
        : parseTransactionAmountPaise(_amountController.text) ?? 0;
    final next = current + rupees * 100;
    if (next > maxTransactionAmountPaise) {
      setState(() {
        _amountError =
            'Maximum amount is ${MoneyFormatter.formatPaise(maxTransactionAmountPaise)}.';
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

  /// Active categories, plus the saved one when it has since been hidden so
  /// editing never silently drops it.
  List<CategoryRow> _categoryOptions(List<CategoryRow> active) {
    final original = _original;
    if (original == null ||
        original.type != _kind.name ||
        active.any((category) => category.id == original.categoryId)) {
      return active;
    }
    final hidden =
        (ref.watch(allCategoriesByTypeProvider(_kind.name)).valueOrNull ??
                const <CategoryRow>[])
            .where((category) => category.id == original.categoryId)
            .firstOrNull;
    return hidden == null ? active : [hidden, ...active];
  }

  Future<void> _save(List<CategoryRow> categories) async {
    if (_saving || _saved) return;
    setState(() {
      _showValidation = true;
      _error = null;
      _amountError = null;
    });

    final amountError = validateTransactionAmount(_amountController.text);
    _categoryId ??= othersCategoryId(categories);
    if (amountError != null) {
      setState(() => _amountError = amountError);
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Select an Account to continue.');
      return;
    }
    if (_categoryId == null) {
      setState(() => _error = 'Select a Category to continue.');
      return;
    }
    final amountPaise = parseTransactionAmountPaise(_amountController.text);
    if (amountPaise == null) return;

    final originalAccountId = _original!.accountId;
    setState(() => _saving = true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .updateTransaction(
            transactionId: widget.transactionId,
            accountId: _accountId!,
            categoryId: _categoryId!,
            type: _kind.name,
            amountPaise: amountPaise,
            transactionDate: DateOnly.toUtcEpochMilliseconds(_date),
            note: _noteController.text,
          );
      ref.invalidate(accountBalancePaiseProvider(originalAccountId));
      ref.invalidate(accountBalancePaiseProvider(_accountId!));
      ref.invalidate(transactionByIdProvider(widget.transactionId));
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
    final scheme = Theme.of(context).colorScheme;

    Widget? body;
    List<CategoryRow> categoryOptions = const [];
    transaction.when(
      loading: () => body = const Center(child: CircularProgressIndicator()),
      error: (error, stack) => body = Center(
        child: TextButton(
          onPressed: () =>
              ref.invalidate(transactionByIdProvider(widget.transactionId)),
          child: const Text('Could not load transaction. Retry'),
        ),
      ),
      data: (row) {
        if (row == null || row.deletedAt != null) {
          body = const Center(
            child: Text(
              'This transaction is unavailable or has been moved to Trash.',
            ),
          );
          return;
        }
        _initialize(row);
      },
    );
    final ready = body == null;
    if (ready) {
      final categories = ref.watch(recentCategoriesByTypeProvider(_kind.name));
      categoryOptions = _categoryOptions(
        categories.valueOrNull ?? const <CategoryRow>[],
      );
      body = accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(allAccountsProvider),
            child: const Text('Could not load Accounts. Retry'),
          ),
        ),
        data: (accountRows) {
          // Archived Accounts stay hidden unless this transaction uses one.
          final selectable = accountRows
              .where(
                (account) =>
                    account.archivedAt == null ||
                    account.id == _original!.accountId,
              )
              .toList();
          if (!selectable.any((account) => account.id == _accountId)) {
            return const Center(
              child: Text('The original Account is unavailable.'),
            );
          }
          return _buildForm(selectable, categories, categoryOptions);
        },
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Edit transaction')),
      body: body,
      bottomNavigationBar: ready && accounts.hasValue
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: PrimaryButton(
                  label: _saved ? 'Updated' : 'Update transaction',
                  gradient: AppColors.heroGradient,
                  onPressed: _saving || _saved
                      ? null
                      : () => _save(categoryOptions),
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
            )
          : null,
    );
  }

  Widget _buildForm(
    List<AccountRow> accountRows,
    AsyncValue<List<CategoryRow>> categories,
    List<CategoryRow> categoryOptions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        if (_original!.recurringRuleId != null) ...[
          Container(
            key: const ValueKey('edit-transaction-recurring-note'),
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.repeat_rounded, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Part of a recurring series. Changes apply to this '
                    'transaction only.',
                    style: AppTypography.supporting.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/more/recurring'),
                  child: const Text('Series'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        TransactionTypeSelector(
          kind: _kind,
          onChanged: (kind) {
            if (kind == _kind) return;
            setState(() {
              _kind = kind;
              // The saved category belongs to the original type only.
              _categoryId = kind.name == _original!.type
                  ? _original!.categoryId
                  : null;
              _suggestedCategoryId = null;
              _noteSuggestions = const [];
              _error = null;
            });
            _refreshSuggestions();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TransactionAccountSelector(
          accounts: accountRows,
          selectedId: _accountId,
          hidden: ref.watch(amountsHiddenProvider),
          keys: _accountKeys,
          controller: _accountScrollController,
          onSelected: _selectAccount,
        ),
        const SizedBox(height: AppSpacing.md),
        TransactionDateSelector(
          keyPrefix: 'edit-transaction',
          date: _date,
          label: _dateLabel(),
          onDate: (date) => setState(() => _date = date),
          onPick: _pickDate,
        ),
        if (isScheduledDate(
          DateOnly.toUtcEpochMilliseconds(_date),
          ref.watch(todayProvider),
        ))
          const TransactionScheduledNote(),
        const SizedBox(height: AppSpacing.md),
        TransactionNoteInput(
          keyPrefix: 'edit-transaction',
          controller: _noteController,
        ),
        if (_noteController.text.trim().isEmpty)
          NoteSuggestionChips(
            key: const ValueKey('edit-transaction-recent-notes'),
            label: 'Recent',
            notes:
                ref.watch(recentNotesProvider(_kind.name)).valueOrNull ??
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
        const SizedBox(height: AppSpacing.md),
        TransactionAmountInput(
          keyPrefix: 'edit-transaction',
          controller: _amountController,
          kind: _kind,
          error: _amountError,
          onChanged: (value) {
            final error = value.trim().isEmpty && !_showValidation
                ? null
                : validateTransactionAmount(value);
            if (error != _amountError) setState(() => _amountError = error);
          },
          onQuickAdd: _addQuickAmount,
        ),
        const SizedBox(height: AppSpacing.md),
        categories.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => TextButton(
            onPressed: () =>
                ref.invalidate(recentCategoriesByTypeProvider(_kind.name)),
            child: const Text('Could not load categories. Retry'),
          ),
          data: (_) {
            // The saved category may still be loading if it is hidden.
            if (_categoryId != null &&
                _categoryId != _original!.categoryId &&
                !categoryOptions.any(
                  (category) => category.id == _categoryId,
                )) {
              _categoryId = null;
            }
            return TransactionCategorySelector(
              keyPrefix: 'edit-transaction',
              categories: categoryOptions,
              selectedId: _categoryId,
              suggestedId: _suggestedCategoryId,
              kind: _kind,
              showValidation: _showValidation,
              onSelected: (id) => setState(() {
                _categoryId = id;
                _error = null;
              }),
            );
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: AppTypography.supporting.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}
