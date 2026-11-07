import 'package:go_router/go_router.dart';

import '../features/shell/presentation/app_shell.dart';
import '../features/transactions/presentation/add_transaction_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AppShell(),
    ),
    GoRoute(
      path: '/transaction/new',
      builder: (context, state) => const AddTransactionPage(),
    ),
  ],
);
