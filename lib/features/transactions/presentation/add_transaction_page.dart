import 'package:flutter/material.dart';

enum TransactionKind { expense, income }

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  TransactionKind _kind = TransactionKind.expense;

  @override
  Widget build(BuildContext context) {
    final isExpense = _kind == TransactionKind.expense;

    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<TransactionKind>(
            segments: const [
              ButtonSegment(
                value: TransactionKind.expense,
                label: Text('Expense'),
                icon: Icon(Icons.arrow_upward_rounded),
              ),
              ButtonSegment(
                value: TransactionKind.income,
                label: Text('Income'),
                icon: Icon(Icons.arrow_downward_rounded),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (selection) {
              setState(() => _kind = selection.first);
            },
          ),
          const SizedBox(height: 24),
          Text(
            isExpense ? 'How much did you spend?' : 'How much did you receive?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          TextField(
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              hintText: '0.00',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Note',
              hintText: 'What was this transaction for?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.calendar_today_outlined),
            title: Text('Date'),
            subtitle: Text('Today'),
            trailing: Icon(Icons.chevron_right_rounded),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_balance_wallet_outlined),
            title: Text('Account'),
            subtitle: Text('Select an Account'),
            trailing: Icon(Icons.chevron_right_rounded),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.category_outlined),
            title: Text('Category'),
            subtitle: Text('Select a category'),
            trailing: Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: null,
            child: const Text('Save transaction'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Saving will be enabled when the local database and validation rules are implemented.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
