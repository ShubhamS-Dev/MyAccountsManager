import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../accounts_providers.dart';

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
  bool _initialized = false;
  bool _saving = false;
  String? _error;

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
      await ref.read(accountsRepositoryProvider).updateAccount(
            accountId: widget.accountId,
            name: _nameController.text,
            description: _descriptionController.text,
          );
      ref.invalidate(activeAccountsProvider);
      ref.invalidate(accountByIdProvider(widget.accountId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Account could not be updated. Please try again.';
        })
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountByIdProvider(widget.accountId));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Account')),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Account could not be loaded.')),
        data: (row) {
          if (row == null)
            return const Center(child: Text('Account not found.'))
          if (!_initialized) {
            _nameController.text = row.name;
            _descriptionController.text = row.description ?? '';
            _initialized = true;
          }
          return Form(
            key: _formKey,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Account name *', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an Account name.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Text(
                  'Opening balance is managed separately and cannot be changed from this screen.',
                  style: Theme.of(context).textTheme.bodySmall),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Changes'),
              ),
            ]),
          );
        },
      ),
    );
  }
}
