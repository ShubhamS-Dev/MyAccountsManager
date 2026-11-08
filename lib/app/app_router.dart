import 'package:go_router/go_router.dart';

import '../features/shell/presentation/app_shell.dart';
import '../features/accounts/presentation/create_account_page.dart';
import '../features/accounts/presentation/edit_account_page.dart';
import '../features/accounts/presentation/archived_accounts_page.dart';
import '../features/transactions/presentation/add_transaction_page.dart';
import '../features/transactions/presentation/transaction_trash_page.dart';
import '../features/transactions/presentation/edit_transaction_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AppShell(),
    ),
    GoRoute(
      path: '/accounts/archived',
      builder: (context, state) => const ArchivedAccountsPage(),
    ),
    GoRoute(
      path: '/accounts/:accountId/edit',
      builder: (context, state) => EditAccountPage(accountId: state.pathParameters['accountId']!),
    ),
    GoRoute(
      path: '/accounts/new',
      builder: (context, state) => const CreateAccountPage(),
    ),
    GoRoute(
      path: '/transaction/:transactionId/edit',
      builder: (context, state) => EditTransactionPage(transactionId: state.pathParameters['transactionId']!),
    ),
    GoRoute(
      path: '/transactions/trash',
      builder: (context, state) => const TransactionTrashPage(),
    ),
    GoRoute(
      path: '/transaction/new',
      builder: (context, state) => const AddTransactionPage(),
    ),
  ],
);
