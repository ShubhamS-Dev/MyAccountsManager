import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../core/formatting/money_formatter.dart';
import '../accounts_providers.dart';
import 'account_form.dart';

class CreateAccountPage extends ConsumerStatefulWidget {
  const CreateAccountPage({super.key});
  @override
  ConsumerState<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends ConsumerState<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  String _iconKey = 'wallet';
  int? _colorValue;
  bool _saving = false;

  // Unsaved-changes tracking for the back-navigation guard.
  late final String _pristine = _snapshot;
  String get _snapshot => [
    _nameController.text,
    _descriptionController.text,
    _openingBalanceController.text,
    _iconKey,
    _colorValue,
  ].join('\u0000');
  bool get _dirty => !_saving && _snapshot != _pristine;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Keep the preview card and semantic amount colour in sync.
    _nameController.addListener(_refresh);
    _openingBalanceController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final paise = parseAmountPaise(
      _openingBalanceController.text,
      allowSign: true,
    );
    if (paise == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(accountsRepositoryProvider)
          .createAccount(
            name: _nameController.text,
            description: _descriptionController.text,
            openingBalancePaise: paise,
            iconKey: _iconKey,
            colorValue: _colorValue,
          );
      ref.invalidate(activeAccountsProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Account could not be saved. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      UnsavedChangesGuard(dirty: _dirty, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final balance = parseAmountPaise(
      _openingBalanceController.text,
      allowSign: true,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Form(
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
              balanceLabel: MoneyFormatter.formatPaise(balance ?? 0),
            ),
            const SizedBox(height: AppSpacing.lg),
            const FieldHeading(title: 'Account name'),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. HDFC Savings',
                counterText: '',
              ),
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
              decoration: const InputDecoration(
                hintText: 'What is this Account for?',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(
              title: 'Opening balance',
              hint: 'Use - if it starts in deficit',
            ),
            AmountFormField(
              controller: _openingBalanceController,
              allowSign: true,
              accent: (balance ?? 0) < 0
                  ? Theme.of(context).colorScheme.negativeText
                  : null,
              validator: (value) =>
                  parseAmountPaise(value ?? '', allowSign: true) == null
                  ? 'Enter a valid amount with up to 2 decimal places.'
                  : null,
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
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              FormErrorBanner(_error!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        child: PrimaryButton(
          label: 'Save Account',
          icon: Icons.check_rounded,
          gradient: AppColors.heroGradient,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
