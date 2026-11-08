import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounts_providers.dart';

class AccountBalanceAdjustmentsPage extends ConsumerStatefulWidget {
  const AccountBalanceAdjustmentsPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountBalanceAdjustmentsPage> createState() =>
      _AccountBalanceAdjustmentsPageState();
}

class _AccountBalanceAdjustmentsPageState
    extends ConsumerState<AccountBalanceAdjustmentsPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  int? _parseSignedPaise(String raw) {
    final value = raw.trim().replaceAll(',', '');
    if (!RegExp(r'^[+-]?\d{1,12}(\.\d{1,2})?$').hasMatch(value)) return null;
    final negative = value.startsWith('-');
    final unsigned = value.replaceFirst(RegExp(r'^[+-]'), '');
    final parts = unsigned.split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) return null;
    final paise = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
    final amount = rupees * 100 + paise;
    return negative ? -amount : amount;
  }

  String _money(int paise) {
    final absolute = paise.abs();
    final digits = (absolute ~/ 100).toString();
    final grouped = digits.replaceAllMapped(
        RegExp(r'(?<=\d)(?=(\d{2})+\d{3}$)'), (_) => ',');
    final fraction = absolute % 100;
    return '${paise < 0 ? '-' : paise > 0 ? '+' : ''}₹$grouped${fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}'}';
  }

  String _dateLabel(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
    final amount = _parseSignedPaise(_amountController.text);
    if (amount == null || amount == 0) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(accountsRepositoryProvider).createBalanceAdjustment(
            accountId: widget.accountId,
            amountPaise: amount,
            reason: _reasonController.text,
            adjustmentDate: DateTime.utc(_date.year, _date.month, _date.day)
                .millisecondsSinceEpoch,
          );
      if (!mounted) return;
      ref.invalidate(accountBalancePaiseProvider(widget.accountId));
      _amountController.clear();
      _reasonController.clear();
      setState(() {
        _date = DateTime.now();
        _saving = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error =
              'Could not save adjustment. Check the amount and Account status.';
        }) { ; }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountByIdProvider(widget.accountId));
    final adjustments = ref.watch(balanceAdjustmentsProvider(widget.accountId));
    return Scaffold(
      appBar: AppBar(title: const Text('Balance adjustments')),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Account could not be loaded.')),
        data: (row) {
          if (row == null)
            return const Center(child: Text('Account not found.')) { ; }
          final isArchived = row.archivedAt != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(row.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(
                  'Add a signed correction without changing the original opening balance.'),
              const SizedBox(height: 16),
              if (isArchived)
                const Card(
                    child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                            'This Account is archived. Restore it before adding a balance adjustment.')))
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: const InputDecoration(
                                labelText: 'Adjustment amount',
                                prefixText: '₹ ',
                                hintText: '+500 or -250.50',
                                border: OutlineInputBorder()),
                            validator: (value) {
                              final amount = _parseSignedPaise(value ?? '');
                              return amount == null || amount == 0
                                  ? 'Enter a non-zero amount; use + to increase or - to decrease.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _reasonController,
                            maxLength: 500,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                                labelText: 'Reason *',
                                hintText:
                                    'Why is this balance being corrected?',
                                border: OutlineInputBorder()),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter a reason for the adjustment.'
                                    : null,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: const Text('Adjustment date'),
                            subtitle: Text(
                                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _pickDate,
                          ),
                          if (_error != null)
                            Text(_error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('Save adjustment'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text('Adjustment history',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              adjustments.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => TextButton(
                    onPressed: () => ref.invalidate(
                        balanceAdjustmentsProvider(widget.accountId)),
                    child: const Text('Could not load adjustments. Retry')),
                data: (items) {
                  if (items.isEmpty)
                    return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No balance adjustments yet.')) { ; }
                  return Column(
                    children: [
                      for (final item in items)
                        Card(
                          child: ListTile(
                            leading: Icon(item.amountPaise > 0
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline),
                            title: Text(item.reason),
                            subtitle: Text(_dateLabel(item.adjustmentDate)),
                            trailing: Text(
                              _money(item.amountPaise),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
