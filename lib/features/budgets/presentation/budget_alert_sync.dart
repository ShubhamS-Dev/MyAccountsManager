import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/notifications_providers.dart';
import '../../settings/settings_providers.dart';
import '../budget_providers.dart';
import '../domain/budget.dart';

/// Posts a notification the first time this month's spending reaches 80%
/// and 100% of the budget. Spending that drops back below a threshold
/// (a deleted expense) re-arms it.
class BudgetAlertSync extends ConsumerStatefulWidget {
  const BudgetAlertSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BudgetAlertSync> createState() => _BudgetAlertSyncState();
}

class _BudgetAlertSyncState extends ConsumerState<BudgetAlertSync> {
  @override
  void initState() {
    super.initState();
    if (!ref.read(notificationGatewayProvider).supported) return;
    ref.listenManual(budgetStatusProvider, (_, next) {
      final status = next.valueOrNull;
      if (status != null) _check(status);
    }, fireImmediately: true);
  }

  Future<void> _check(BudgetStatus status) async {
    final settings = ref.read(budgetSettingsProvider).valueOrNull;
    if (settings == null) return;
    final reached = status.thresholdReached;
    final alerted = settings.alertedFor(status.date);
    if (reached == alerted) return;
    await ref
        .read(settingsRepositoryProvider)
        .setValue(budgetAlertedKey(status.date), '$reached');
    if (!mounted || reached < alerted || !settings.alertsEnabled) return;
    // Await rather than read: nothing else may be listening yet.
    final preferences = await ref.read(notificationPreferencesProvider.future);
    if (!preferences.enabled || !mounted) return;
    final text = budgetAlertText(
      status,
      reached,
      showAmounts: preferences.showAmounts,
    );
    await ref
        .read(notificationGatewayProvider)
        .showNow(
          key: budgetAlertedKey(status.date),
          title: text.title,
          body: text.body,
          route: '/more/budgets',
        );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
