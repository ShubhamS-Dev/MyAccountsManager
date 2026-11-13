import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../my_khata/data/khata_repository.dart';
import '../../my_khata/presentation/khata_widgets.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/notification_gateway.dart';
import '../data/notification_preferences.dart';
import '../domain/reminder_planner.dart';
import '../notifications_providers.dart';

/// Everything that needs attention: overdue and upcoming MyKhata due dates
/// and Scheduled transactions.
class ActivityCenterPage extends ConsumerWidget {
  const ActivityCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final digest = ref.watch(activityDigestProvider);
    final hidden = ref.watch(amountsHiddenProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => context.push('/more/notifications'),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: digest.when(
        loading: () => const SkeletonList(),
        error: (error, _) => ScreenErrorState(
          message: 'Activity could not be loaded.',
          onRetry: () => ref.invalidate(activityDigestProvider),
        ),
        data: (digest) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            const _NotificationsOffBanner(),
            if (digest.isEmpty)
              const AppCard(
                child: EmptyState(
                  title: "You're all caught up",
                  message:
                      'Overdue MyKhata entries, upcoming due dates and scheduled transactions show up here.',
                  icon: Icons.notifications_none_rounded,
                ),
              ),
            if (digest.overdue.isNotEmpty)
              _Section(
                title: 'Overdue',
                count: digest.overdue.length,
                children: [
                  for (final item in digest.overdue)
                    _KhataReminderTile(
                      item: item,
                      today: digest.today,
                      hidden: hidden,
                    ),
                ],
              ),
            if (digest.dueSoon.isNotEmpty)
              _Section(
                title: 'Due in the next ${ActivityDigest.dueSoonDays} days',
                count: digest.dueSoon.length,
                children: [
                  for (final item in digest.dueSoon)
                    _KhataReminderTile(
                      item: item,
                      today: digest.today,
                      hidden: hidden,
                    ),
                ],
              ),
            if (digest.scheduled.isNotEmpty)
              _Section(
                title: 'Scheduled transactions',
                count: digest.scheduled.length,
                children: [
                  for (final item in digest.scheduled)
                    _ScheduledTile(item: item, hidden: hidden),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Explains why reminders will not arrive and offers the fix.
class _NotificationsOffBanner extends ConsumerWidget {
  const _NotificationsOffBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(notificationStatusProvider).valueOrNull;
    final preferences = ref.watch(notificationPreferencesProvider).valueOrNull;
    if (status == null || preferences == null || !status.supported) {
      return const SizedBox.shrink();
    }
    final String message;
    final String action;
    final VoidCallback onAction;
    if (!preferences.enabled) {
      message = 'Reminders are turned off.';
      action = 'Settings';
      onAction = () => context.push('/more/notifications');
    } else if (!status.permitted) {
      message =
          'Notifications are blocked for this app, so reminders will not appear.';
      action = 'Allow';
      onAction = () => allowNotifications(ref);
    } else {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_off_outlined, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: AppTypography.supporting)),
            TextButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

/// Asks for the permission, or opens system settings once Android stops
/// showing the prompt.
Future<void> allowNotifications(WidgetRef ref) async {
  final gateway = ref.read(notificationGatewayProvider);
  final granted = await gateway.requestPermission();
  if (!granted) await gateway.openSettings();
  ref.invalidate(notificationStatusProvider);
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: '$title ($count)'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const Divider(height: 1, indent: 64),
                child,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// "Overdue by 3 days", "Due today", "Due tomorrow" or "Due 14 Nov 2026".
String dueLabel(int dueDate, int today) {
  final days = (dueDate - today) ~/ Duration.millisecondsPerDay;
  return switch (days) {
    < -1 => 'Overdue by ${-days} days',
    -1 => 'Overdue by 1 day',
    0 => 'Due today',
    1 => 'Due tomorrow',
    _ => 'Due ${DateOnly.format(dueDate)}',
  };
}

class _KhataReminderTile extends StatelessWidget {
  const _KhataReminderTile({
    required this.item,
    required this.today,
    required this.hidden,
  });

  final KhataEntryItem item;
  final int today;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = khataDirectionColor(context, item.entry.direction);
    final due = item.entry.dueDate!;
    return ListTile(
      minVerticalPadding: 10,
      onTap: () => context.push('/khata/entries/${item.entry.id}'),
      leading: IconBadge(
        icon: khataDirectionIcon(item.entry.direction),
        color: color,
      ),
      title: Text(
        khataReminderText(item, showAmounts: false),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.fieldValue.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        dueLabel(due, today),
        style: AppTypography.metadata.copyWith(
          color: due < today ? scheme.negativeText : scheme.onSurfaceVariant,
        ),
      ),
      trailing: AmountText(
        hidden
            ? hiddenAmountMask
            : MoneyFormatter.formatPaise(item.outstandingPaise),
        color: color,
      ),
    );
  }
}

class _ScheduledTile extends StatelessWidget {
  const _ScheduledTile({required this.item, required this.hidden});

  final TransactionHistoryItem item;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final income = transaction.type == 'income';
    final scheme = Theme.of(context).colorScheme;
    final color = income ? scheme.positiveText : scheme.negativeText;
    return ListTile(
      minVerticalPadding: 10,
      onTap: () => context.push('/transaction/${transaction.id}'),
      leading: CategoryIconBadge(
        iconKey: item.categoryIconKey,
        categoryName: item.categoryName,
        colorValue: item.categoryColorValue,
        income: income,
      ),
      title: Text(
        transaction.note?.isNotEmpty == true
            ? transaction.note!
            : item.categoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.fieldValue.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${DateOnly.format(transaction.transactionDate)} · ${item.accountName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.metadata.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: AmountText(
        hidden
            ? hiddenAmountMask
            : '${income ? '+' : '-'}${MoneyFormatter.formatPaise(transaction.amountPaise)}',
        color: color,
      ),
    );
  }
}

/// Subtitle for the More tile and the settings header.
String notificationSummary(
  NotificationPreferences? preferences,
  NotificationStatus? status,
) {
  if (preferences == null) return '';
  if (!preferences.enabled) return 'Off';
  if (status != null && status.supported && !status.permitted) {
    return 'Blocked in system settings';
  }
  return 'On · ${reminderTimeLabel(preferences.reminderMinutes)}';
}
