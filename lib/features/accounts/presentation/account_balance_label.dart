import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounts_providers.dart';

class AccountBalanceLabel extends ConsumerWidget {
  const AccountBalanceLabel({required this.accountId, super.key});
  final String accountId;

  String _format(int paise) {
    final negative = paise < 0;
    final absolute = paise.abs();
    final rupees = (absolute ~/ 100).toString();
    final grouped = rupees.replaceAllMapped(
        RegExp(r'(?<=\d)(?=(\d{2})+\d{3}$)'), (m) => ',');
    final fraction = absolute % 100;
    return '${negative ? '-' : ''}₹$grouped${fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(accountBalancePaiseProvider(accountId));
    return balance.when(
      loading: () =>
          Text('Balance: …', style: Theme.of(context).textTheme.bodySmall),
      error: (error, stack) => Text('Balance unavailable',
          style: Theme.of(context).textTheme.bodySmall),
      data: (value) => Text(
          value == null ? 'Balance unavailable' : 'Balance: ${_format(value)}',
          style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
