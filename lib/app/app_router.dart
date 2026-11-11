import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/account_balance_adjustments_page.dart';
import '../features/accounts/presentation/account_details_page.dart';
import '../features/accounts/presentation/archived_accounts_page.dart';
import '../features/accounts/presentation/create_account_page.dart';
import '../features/accounts/presentation/edit_account_page.dart';
import '../features/categories/presentation/categories_page.dart';
import '../features/export/presentation/export_page.dart';
import '../features/my_khata/presentation/khata_entry_details_page.dart';
import '../features/my_khata/presentation/khata_entry_form_page.dart';
import '../features/my_khata/presentation/person_details_page.dart';
import '../features/my_khata/presentation/person_form_page.dart';
import '../features/my_khata/presentation/record_repayment_page.dart';
import '../features/notifications/presentation/activity_center_page.dart';
import '../features/notifications/presentation/notification_settings_page.dart';
import '../features/settings/presentation/appearance_page.dart';
import '../features/settings/presentation/info_pages.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/transactions/presentation/add_transaction_page.dart';
import '../features/transactions/presentation/edit_transaction_page.dart';
import '../features/transactions/presentation/transaction_details_page.dart';
import '../features/transactions/presentation/transaction_trash_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AppShell()),
    // Static Account paths must precede the /accounts/:accountId matcher.
    GoRoute(
      path: '/accounts/archived',
      builder: (context, state) => const ArchivedAccountsPage(),
    ),
    GoRoute(
      path: '/accounts/new',
      builder: (context, state) => const CreateAccountPage(),
    ),
    GoRoute(
      path: '/accounts/:accountId/edit',
      builder: (context, state) =>
          EditAccountPage(accountId: state.pathParameters['accountId']!),
    ),
    GoRoute(
      path: '/accounts/:accountId/adjustments',
      builder: (context, state) => AccountBalanceAdjustmentsPage(
        accountId: state.pathParameters['accountId']!,
      ),
    ),
    GoRoute(
      path: '/accounts/:accountId',
      builder: (context, state) =>
          AccountDetailsPage(accountId: state.pathParameters['accountId']!),
    ),
    GoRoute(
      path: '/transaction/:transactionId/edit',
      builder: (context, state) => EditTransactionPage(
        transactionId: state.pathParameters['transactionId']!,
      ),
    ),
    GoRoute(
      path: '/transactions/trash',
      builder: (context, state) => const TransactionTrashPage(),
    ),
    GoRoute(
      path: '/transaction/new',
      builder: (context, state) =>
          AddTransactionPage(initialType: state.uri.queryParameters['type']),
    ),
    // Must follow /transaction/new so "new" is not read as an id.
    GoRoute(
      path: '/transaction/:transactionId',
      builder: (context, state) => TransactionDetailsPage(
        transactionId: state.pathParameters['transactionId']!,
      ),
    ),
    // MyKhata: static paths precede their :id matchers.
    GoRoute(
      path: '/khata/people/new',
      builder: (context, state) => const PersonFormPage(),
    ),
    GoRoute(
      path: '/khata/people/:personId/edit',
      builder: (context, state) =>
          PersonFormPage(personId: state.pathParameters['personId']!),
    ),
    GoRoute(
      path: '/khata/people/:personId',
      builder: (context, state) =>
          PersonDetailsPage(personId: state.pathParameters['personId']!),
    ),
    GoRoute(
      path: '/khata/entries/new',
      builder: (context, state) => KhataEntryFormPage(
        initialPersonId: state.uri.queryParameters['personId'],
        initialDirection: state.uri.queryParameters['direction'],
      ),
    ),
    GoRoute(
      path: '/khata/entries/:entryId/edit',
      builder: (context, state) =>
          KhataEntryFormPage(entryId: state.pathParameters['entryId']!),
    ),
    GoRoute(
      path: '/khata/entries/:entryId/repay',
      builder: (context, state) =>
          RecordRepaymentPage(entryId: state.pathParameters['entryId']!),
    ),
    GoRoute(
      path: '/khata/entries/:entryId',
      builder: (context, state) =>
          KhataEntryDetailsPage(entryId: state.pathParameters['entryId']!),
    ),
    GoRoute(
      path: '/activity',
      builder: (context, state) => const ActivityCenterPage(),
    ),
    GoRoute(
      path: '/more/notifications',
      builder: (context, state) => const NotificationSettingsPage(),
    ),
    GoRoute(
      path: '/more/appearance',
      builder: (context, state) => const AppearancePage(),
    ),
    GoRoute(
      path: '/more/categories',
      builder: (context, state) => const CategoriesPage(),
    ),
    GoRoute(
      path: '/more/currency',
      builder: (context, state) => const CurrencyFormatPage(),
    ),
    GoRoute(
      path: '/more/budgets',
      builder: (context, state) => const ComingSoonPage.budgets(),
    ),
    GoRoute(
      path: '/more/export',
      builder: (context, state) => const ExportPage(),
    ),
    GoRoute(
      path: '/more/backup',
      builder: (context, state) => const ComingSoonPage.backup(),
    ),
    GoRoute(
      path: '/more/about',
      builder: (context, state) => const AboutAppPage(),
    ),
  ],
);
