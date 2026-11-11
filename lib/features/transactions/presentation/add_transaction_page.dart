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
import '../../recurring/domain/recurrence.dart';
import '../../recurring/recurring_providers.dart';
import '../transactions_providers.dart';
import 'note_suggestion_chips.dart';
import 'transaction_form_widgets.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({
    super.key,
    this.initialType,
    this.initialAccountId,
    this.copyFromId,
  });

  final String? initialType;

  /// Preselects this Account, e.g. when opened from Account Details.
  final String? initialAccountId;

  /// Prefills type, Account, category, amount and note from this
  /// transaction ("Copy as new"). The date stays today.
  final String? copyFromId;

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
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
  RecurringFrequency? _repeat;
  DateTime? _repeatEnd;

  // Note-driven suggestions. Once the user picks a Category themselves the
  // suggestion never overrides it.
  bool _categoryTouched = false;
  String? _suggestedCategoryId;
  List<String> _noteSuggestions = const [];
  Timer? _suggestDebounce;
  int _suggestRequest = 0;

  // Unsaved-changes tracking for the back-navigation guard.
  late String _pristine = _snapshot;
  String get _snapshot => [
    _amountController.text,
    _noteController.text,
    _date,
    _repeat,
  ].join('\u0000');
  bool get _dirty => !_saving && !_saved && _snapshot != _pristine;
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
    _accountId = widget.initialAccountId;
    _noteController.addListener(_noteChanged);
    if (widget.copyFromId != null) _prefillFromCopy(widget.copyFromId!);
  }

  Future<void> _prefillFromCopy(String transactionId) async {
    TransactionRow? source;
    try {
      source = await ref
          .read(transactionsRepositoryProvider)
          .getTransaction(transactionId);
    } catch (_) {
      // Fall back to a blank form; copying is a convenience.
    }
    if (!mounted || source == null) return;
    final amount = MoneyFormatter.formatPaise(
      source.amountPaise,
      includeSymbol: false,
    );
    setState(() {
      _kind = source!.type == 'income'
          ? TransactionKind.income
          : TransactionKind.expense;
      // An archived Account or hidden category is dropped by the build
      // checks, so the user picks an active one instead.
      _accountId = source.accountId;
      _categoryId = source.categoryId;
      _categoryTouched = true;
      _amountController.text = amount;
      _noteController.text = source.note ?? '';
      // Leaving an untouched copy should not prompt about unsaved changes.
      _pristine = _snapshot;
    });
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
      // Suggestions are optional and must never block entry.
    }
    if (!mounted || request != _suggestRequest) return;
    setState(() {
      _noteSuggestions = notes;
      _suggestedCategoryId = categoryId;
      if (!_categoryTouched) _categoryId = categoryId;
      if (_categoryId != null) _error = null;
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

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _noteController.removeListener(_noteChanged);
    _amountController.dispose();
    _noteController.dispose();
    _accountScrollController.dispose();
    super.dispose();
  }

  /// The type's "Others" category, used when the user saves without picking.
  String? _fallbackCategoryId() => othersCategoryId(
    ref.read(recentCategoriesByTypeProvider(_kind.name)).valueOrNull ??
        const <CategoryRow>[],
  );

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

  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() {
      _showValidation = true;
      _error = null;
      _amountError = null;
    });

    final amountError = validateTransactionAmount(_amountController.text);
    _categoryId ??= _fallbackCategoryId();
    if (amountError != null || _accountId == null || _categoryId == null) {
      if (amountError != null) setState(() => _amountError = amountError);
      if (amountError != null) {
        // The amount message is shown under the field.
      } else if (_accountId == null) {
        setState(() => _error = 'Select an Account to continue.');
      } else if (_categoryId == null) {
        setState(() => _error = 'Select a Category to continue.');
      }
      return;
    }
    final amountPaise = parseTransactionAmountPaise(_amountController.text);
    if (amountPaise == null) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final transactionId = await ref
          .read(transactionsRepositoryProvider)
          .createTransaction(
            accountId: _accountId!,
            categoryId: _categoryId!,
            type: _kind.name,
            amountPaise: amountPaise,
            transactionDate: DateOnly.toUtcEpochMilliseconds(_date),
            note: _noteController.text,
          );
      if (_repeat != null) await _startSeries(transactionId, messenger);
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

  /// The transaction is already saved; a failed series is reported, not
  /// treated as a failed save.
  Future<void> _startSeries(
    String transactionId,
    ScaffoldMessengerState messenger,
  ) async {
    final end = _repeatEnd;
    try {
      await ref
          .read(recurringRepositoryProvider)
          .createFromTransaction(
            transactionId: transactionId,
            frequency: _repeat!,
            today: ref.read(todayProvider),
            endDate: end != null && end.isAfter(_date)
                ? DateOnly.toUtcEpochMilliseconds(end)
                : null,
          );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Transaction saved, but the repeat could not be set up.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      UnsavedChangesGuard(dirty: _dirty, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final accounts = ref.watch(activeAccountsProvider);
    final categories = ref.watch(recentCategoriesByTypeProvider(_kind.name));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.copyFromId == null ? 'Add transaction' : 'Copy transaction',
        ),
      ),
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
            onChanged: () => setState(() {}),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                TransactionTypeSelector(
                  kind: _kind,
                  onChanged: (kind) {
                    setState(() {
                      _kind = kind;
                      _categoryId = null;
                      _categoryTouched = false;
                      _suggestedCategoryId = null;
                      _noteSuggestions = const [];
                      _error = null;
                    });
                    _refreshSuggestions();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-account'),
                  child: TransactionAccountSelector(
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
                  child: TransactionDateSelector(
                    date: _date,
                    label: _dateLabel(),
                    onDate: (date) => setState(() => _date = date),
                    onPick: _pickDate,
                  ),
                ),
                if (isScheduledDate(
                  DateOnly.toUtcEpochMilliseconds(_date),
                  ref.watch(todayProvider),
                ))
                  const TransactionScheduledNote(),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-note'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TransactionNoteInput(controller: _noteController),
                      if (_noteController.text.trim().isEmpty)
                        NoteSuggestionChips(
                          key: const ValueKey('add-transaction-recent-notes'),
                          label: 'Recent',
                          notes:
                              ref
                                  .watch(recentNotesProvider(_kind.name))
                                  .valueOrNull ??
                              const [],
                          onSelected: _useNote,
                        )
                      else
                        NoteSuggestionChips(
                          key: const ValueKey('add-transaction-note-matches'),
                          label: 'Suggestions',
                          notes: _noteSuggestions,
                          onSelected: _useNote,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-amount'),
                  child: TransactionAmountInput(
                    controller: _amountController,
                    kind: _kind,
                    error: _amountError,
                    onChanged: (value) {
                      final error = value.trim().isEmpty && !_showValidation
                          ? null
                          : validateTransactionAmount(value);
                      if (error != _amountError) {
                        setState(() => _amountError = error);
                      }
                    },
                    onQuickAdd: _addQuickAmount,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-category'),
                  child: categories.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) => TextButton(
                      onPressed: () => ref.invalidate(
                        recentCategoriesByTypeProvider(_kind.name),
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
                      return TransactionCategorySelector(
                        categories: categoryRows,
                        selectedId: _categoryId,
                        suggestedId: _suggestedCategoryId,
                        kind: _kind,
                        showValidation: _showValidation,
                        onSelected: (id) => setState(() {
                          _categoryId = id;
                          _categoryTouched = true;
                          _error = null;
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const ValueKey('add-transaction-repeat'),
                  child: TransactionRepeatSelector(
                    frequency: _repeat,
                    startDate: _date,
                    endDate: _repeatEnd,
                    onFrequency: (frequency) =>
                        setState(() => _repeat = frequency),
                    onEndDate: (date) => setState(() => _repeatEnd = date),
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
