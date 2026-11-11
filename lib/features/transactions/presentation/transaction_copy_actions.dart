import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/today_provider.dart';
import '../../accounts/accounts_providers.dart';
import '../transactions_providers.dart';

/// Saves a copy of the transaction dated today and offers Undo.
Future<void> duplicateTransaction(
  BuildContext context,
  WidgetRef ref, {
  required String transactionId,
  required String accountId,
}) async {
  // Capture before awaiting; the calling widget may rebuild or go away.
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final repository = ref.read(transactionsRepositoryProvider);
  final String copyId;
  try {
    copyId = await repository.duplicateTransaction(
      transactionId,
      transactionDate: ref.read(todayProvider),
    );
  } on StateError {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            "Can't duplicate: its Account is archived or its Category is "
            'hidden. Use Copy as new to pick others.',
          ),
        ),
      );
    return;
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Could not duplicate. Try again.')),
      );
    return;
  }
  container.invalidate(accountBalancePaiseProvider(accountId));
  if (!messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Duplicated to today'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await repository.discardTransaction(copyId);
              container.invalidate(accountBalancePaiseProvider(accountId));
            } catch (_) {
              if (messenger.mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Could not undo duplicate.')),
                );
              }
            }
          },
        ),
      ),
    );
}

/// Opens Add Transaction prefilled from the transaction, dated today.
void copyTransactionAsNew(BuildContext context, String transactionId) =>
    context.push('/transaction/new?copyOf=$transactionId');
