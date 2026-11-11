import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../khata_providers.dart';
import 'khata_widgets.dart';

/// Add Person (no [personId]) or Edit Person.
class PersonFormPage extends ConsumerStatefulWidget {
  const PersonFormPage({super.key, this.personId});

  final String? personId;

  @override
  ConsumerState<PersonFormPage> createState() => _PersonFormPageState();
}

class _PersonFormPageState extends ConsumerState<PersonFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  int? _colorValue;
  bool _initialized = false;
  bool _saving = false;

  // Unsaved-changes tracking for the back-navigation guard.
  String? _pristine;
  String get _snapshot => [
    _nameController.text,
    _phoneController.text,
    _noteController.text,
    _colorValue,
  ].join('\u0000');
  bool get _dirty => !_saving && _pristine != null && _snapshot != _pristine;
  String? _error;

  bool get _editing => widget.personId != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    if (!_editing) {
      _colorValue = AppColors.pickerPalette.first.toARGB32();
      _initialized = true;
      _pristine = _snapshot;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(khataRepositoryProvider);
    try {
      if (_editing) {
        await repository.updatePerson(
          personId: widget.personId!,
          name: _nameController.text,
          phone: _phoneController.text,
          note: _noteController.text,
          colorValue: _colorValue,
        );
        if (mounted) context.pop();
      } else {
        final id = await repository.createPerson(
          name: _nameController.text,
          phone: _phoneController.text,
          note: _noteController.text,
          colorValue: _colorValue,
        );
        if (mounted) context.pushReplacement('/khata/people/$id');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Person could not be saved. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      UnsavedChangesGuard(dirty: _dirty, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    if (_editing && !_initialized) {
      final person = ref.watch(khataPersonProvider(widget.personId!));
      return Scaffold(
        appBar: AppBar(title: const Text('Edit person')),
        body: person.when(
          loading: () => const SkeletonList(rows: 3),
          error: (error, stack) => ScreenErrorState(
            message: 'Person could not be loaded.',
            onRetry: () =>
                ref.invalidate(khataPersonProvider(widget.personId!)),
          ),
          data: (row) {
            if (row == null) {
              return const Center(
                child: EmptyState(
                  title: 'Person not found',
                  message: 'They may have been removed.',
                  icon: Icons.person_off_outlined,
                ),
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _initialized) return;
              setState(() {
                _nameController.text = row.name;
                _phoneController.text = row.phone ?? '';
                _noteController.text = row.note ?? '';
                _colorValue = row.colorValue;
                _initialized = true;
                _pristine = _snapshot;
              });
            });
            return const SkeletonList(rows: 3);
          },
        ),
      );
    }

    final color = _colorValue == null
        ? AppColors.pickerPalette.first
        : Color(_colorValue!);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit person' : 'Add person')),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          children: [
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: PersonAvatar(
                  key: ValueKey(_colorValue),
                  name: _nameController.text.isEmpty
                      ? '?'
                      : _nameController.text,
                  color: color,
                  size: 72,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const FieldHeading(title: 'Name'),
            TextFormField(
              key: const ValueKey('khata-person-name'),
              controller: _nameController,
              autofocus: !_editing,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Rahul Sharma',
                counterText: '',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a name.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(title: 'Phone', hint: 'Optional'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-]')),
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: const InputDecoration(
                hintText: '+91 98765 43210',
                prefixIcon: Icon(Icons.phone_outlined, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(title: 'Note', hint: 'Optional'),
            TextFormField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Relationship or reminder',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(title: 'Colour'),
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
          label: _editing ? 'Save changes' : 'Add person',
          icon: Icons.check_rounded,
          gradient: AppColors.heroGradient,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
