import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/money_formatter.dart';
import '../accounts_providers.dart';
import 'account_form.dart';

class EditAccountPage extends ConsumerStatefulWidget {
  const EditAccountPage({required this.accountId, super.key});
  final String accountId;

  @override
  ConsumerState<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends ConsumerState<EditAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _iconKey;
  int? _colorValue;
  bool _initialized = false;
  bool _saving = false;

  // Unsaved-changes tracking for the back-navigation guard.
  String? _pristine;
  String get _snapshot => [
    _nameController.text,
    _descriptionController.text,
    _iconKey,
    _colorValue,
  ].join('\u0000');
  bool get _dirty => !_saving && _pristine != null && _snapshot != _pristine;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(accountsRepositoryProvider)
          .updateAccount(
            accountId: widget.accountId,
            name: _nameController.text,
            description: _descriptionController.text,
            iconKey: Value(_iconKey),
            colorValue: Value(_colorValue),
          );
      ref.invalidate(activeAccountsProvider);
      ref.invalidate(accountByIdProvider(widget.accountId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Account could not be updated. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      UnsavedChangesGuard(dirty: _dirty, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final account = ref.watch(accountByIdProvider(widget.accountId));
    final balance = ref.watch(accountBalancePaiseProvider(widget.accountId));
    final hidden = ref.watch(amountsHiddenProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Account')),
      body: account.when(
        loading: () => const SkeletonList(rows: 5),
        error: (error, stack) => ScreenErrorState(
          message: 'Account could not be loaded.',
          onRetry: () => ref.invalidate(accountByIdProvider(widget.accountId)),
        ),
        data: (row) {
          if (row == null) {
            return const Center(
              child: EmptyState(
                title: 'Account not found',
                message: 'It may have been removed from this device.',
                icon: Icons.search_off_rounded,
              ),
            );
          }
          if (!_initialized) {
            _nameController.text = row.name;
            _descriptionController.text = row.description ?? '';
            _iconKey = row.iconKey;
            _colorValue = row.colorValue;
            _initialized = true;
            _pristine = _snapshot;
          }
          return Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                AccountPreviewCard(
                  name: _nameController.text,
                  iconKey: _iconKey,
                  colorValue: _colorValue,
                  balanceLabel: hidden
                      ? hiddenAmountMask
                      : MoneyFormatter.formatPaise(balance.valueOrNull ?? 0),
                ),
                const SizedBox(height: AppSpacing.lg),
                const FieldHeading(title: 'Account name'),
                TextFormField(
                  controller: _nameController,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(counterText: ''),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an Account name.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                const FieldHeading(title: 'Description', hint: 'Optional'),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.lg),
                const FieldHeading(title: 'Icon'),
                AccountIconPicker(
                  selected: _iconKey,
                  onChanged: (key) => setState(() => _iconKey = key),
                ),
                const SizedBox(height: AppSpacing.lg),
                const FieldHeading(title: 'Card colour'),
                ColorChoiceRow(
                  selected: _colorValue,
                  onChanged: (value) => setState(() => _colorValue = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  onTap: () =>
                      context.push('/accounts/${widget.accountId}/adjustments'),
                  child: Row(
                    children: [
                      IconBadge(
                        icon: Icons.lock_outline_rounded,
                        color: scheme.primary,
                        size: 36,
                        iconSize: 17,
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: Text(
                          'Opening balance is locked here. Use Balance adjustments for corrections.',
                          style: AppTypography.supporting.copyWith(
                            color: scheme.onSurfaceVariant,
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
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FormErrorBanner(_error!),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: account.valueOrNull == null
          ? null
          : StickyActionBar(
              child: PrimaryButton(
                label: 'Save Changes',
                icon: Icons.check_rounded,
                gradient: AppColors.heroGradient,
                loading: _saving,
                onPressed: _save,
              ),
            ),
    );
  }
}
