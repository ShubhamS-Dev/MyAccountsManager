import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../data/notification_gateway.dart';
import '../data/notification_preferences.dart';
import '../notifications_providers.dart';
import 'activity_center_page.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(notificationPreferencesProvider).valueOrNull ??
        const NotificationPreferences();
    final status = ref.watch(notificationStatusProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final on = preferences.enabled;

    void save(String key, Object value) =>
        saveNotificationSetting(ref, key, value);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Reminders are scheduled on this device. Nothing is sent over the internet.',
            style: AppTypography.supporting.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (status != null && status.supported) ...[
            _DeviceStatusCard(status: status),
            const SizedBox(height: AppSpacing.lg),
          ],
          _Group(
            children: [
              SwitchListTile(
                value: on,
                onChanged: (value) => save(notificationsEnabledKey, value),
                title: const Text('Reminders'),
                subtitle: Text(on ? 'On' : 'Off'),
              ),
              ListTile(
                enabled: on,
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Reminder time'),
                subtitle: const Text('All reminders arrive at this time'),
                trailing: Text(
                  reminderTimeLabel(preferences.reminderMinutes),
                  style: AppTypography.fieldValue.copyWith(
                    fontWeight: FontWeight.w700,
                    color: on ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: preferences.reminderHour,
                      minute: preferences.reminderMinute,
                    ),
                  );
                  if (picked != null) {
                    save(reminderMinutesKey, picked.hour * 60 + picked.minute);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Remind me about'),
          const SizedBox(height: AppSpacing.sm),
          _Group(
            children: [
              SwitchListTile(
                value: preferences.khataDayBefore,
                onChanged: on
                    ? (value) => save(khataDayBeforeKey, value)
                    : null,
                title: const Text('MyKhata due tomorrow'),
                subtitle: const Text('The day before an entry is due'),
              ),
              SwitchListTile(
                value: preferences.khataDueDate,
                onChanged: on ? (value) => save(khataDueDateKey, value) : null,
                title: const Text('MyKhata due today'),
                subtitle: const Text('On the due date'),
              ),
              SwitchListTile(
                value: preferences.overdueSummary,
                onChanged: on
                    ? (value) => save(overdueSummaryKey, value)
                    : null,
                title: const Text('Daily overdue summary'),
                subtitle: const Text('Every day while any entry is overdue'),
              ),
              SwitchListTile(
                value: preferences.scheduledTransactions,
                onChanged: on
                    ? (value) => save(scheduledTransactionsKey, value)
                    : null,
                title: const Text('Scheduled transactions'),
                subtitle: const Text('On the day they start counting'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Privacy'),
          const SizedBox(height: AppSpacing.sm),
          _Group(
            children: [
              SwitchListTile(
                value: preferences.showAmounts,
                onChanged: on ? (value) => save(showAmountsKey, value) : null,
                title: const Text('Show amounts'),
                subtitle: const Text(
                  'Notifications can appear on your lock screen. When off, they show names only.',
                ),
              ),
            ],
          ),
          if (status != null && status.supported) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () async {
                await ref
                    .read(notificationGatewayProvider)
                    .showTest(
                      title: 'Test reminder',
                      body: 'Notifications from MyAccountsManager are working.',
                    );
                if (!status.permitted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Allow notifications first to see the test reminder.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Send a test notification'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Android permission and timing state with a fix for each.
class _DeviceStatusCard extends ConsumerWidget {
  const _DeviceStatusCard({required this.status});

  final NotificationStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateway = ref.read(notificationGatewayProvider);
    return _Group(
      children: [
        _StatusRow(
          icon: status.permitted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          ok: status.permitted,
          title: status.permitted
              ? 'Notifications allowed'
              : 'Notifications blocked',
          subtitle: status.permitted
              ? 'Reminders can appear on this device'
              : 'Reminders will not appear until you allow them',
          action: status.permitted ? null : 'Allow',
          onAction: () => allowNotifications(ref),
        ),
        _StatusRow(
          icon: Icons.alarm_rounded,
          ok: status.exactTiming,
          title: status.exactTiming ? 'On time' : 'Within a few minutes',
          subtitle: status.exactTiming
              ? 'Alarms & reminders access is on'
              : 'Allow Alarms & reminders for on-time delivery',
          action: status.exactTiming ? null : 'Allow',
          onAction: () async {
            await gateway.requestExactTiming();
            ref.invalidate(notificationStatusProvider);
          },
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.ok,
    required this.title,
    required this.subtitle,
    required this.onAction,
    this.action,
  });

  final IconData icon;
  final bool ok;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      icon,
      color: ok
          ? Theme.of(context).colorScheme.positiveText
          : Theme.of(context).colorScheme.negativeText,
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: action == null
        ? null
        : TextButton(onPressed: onAction, child: Text(action!)),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const Divider(height: 1),
          child,
        ],
      ],
    ),
  );
}
