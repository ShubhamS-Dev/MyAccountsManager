import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_formatter.dart';
import '../accounts_providers.dart';

class AccountBalanceLabel extends ConsumerWidget {
  const AccountBalanceLabel({required this.accountId, super.key});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(accountBalancePaiseProvider(accountId));
    final colors = Theme.of(context).colorScheme;
    return balance.when(
      loading: () => Text('Balance: …', style: Theme.of(context).textTheme.bodySmall),
      error: (error, stack) => Text('Balance unavailable', style: Theme.of(context).textTheme.bodySmall),
      data: (value) {
        if (value == null) {
          return Text('Balance unavailable', style: Theme.of(context).textTheme.bodySmall);
        }
        return Text(
          'Balance: ${MoneyFormatter.formatPaise(value)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: value < 0 ? colors.error : colors.tertiary,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}
