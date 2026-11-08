import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../accounts_providers.dart';

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
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  int? _parsePaise(String input) {
    final value = input.trim().replaceAll(',', '');
    if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(value)) return null;
    final negative = value.startsWith('-');
    final unsigned = negative ? value.substring(1) : value;
    final parts = unsigned.split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) return null;
    final fraction = parts.length == 1 ? '' : parts[1].padRight(2, '0');
    final total = rupees * 100 + (fraction.isEmpty ? 0 : int.parse(fraction));
    return negative ? -total : total;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final paise = _parsePaise(_openingBalanceController.text);
    if (paise == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(accountsRepositoryProvider).createAccount(
          name: _nameController.text,
          description: _descriptionController.text,
          openingBalancePaise: paise);
      ref.invalidate(activeAccountsProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Account could not be saved. Please try again.';
        })
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Account')),
        body: Form(
            key: _formKey,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Account name *',
                      hintText: 'e.g. Monthly Expenses',
                      border: OutlineInputBorder()),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an Account name.'
                      : null),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _openingBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(
                      labelText: 'Opening balance (₹)',
                      helperText:
                          'Use a negative amount if the Account starts in deficit.',
                      border: OutlineInputBorder()),
                  validator: (value) => _parsePaise(value ?? '') == null
                      ? 'Enter a valid amount with up to 2 decimal places.'
                      : null),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))
              ],
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Account')),
            ])),
      );
}
