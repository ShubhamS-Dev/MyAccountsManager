import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../notifications/notifications_providers.dart';
import '../../notifications/presentation/activity_center_page.dart';
import '../settings_providers.dart';

const appVersionLabel = '1.0.0 (build 1)';

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
  ThemeMode.system => 'System default',
};

/// More tab: hub for management, preferences and app information.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        GradientCard(
          padding: const EdgeInsets.all(AppSpacing.md + 4),
          radius: AppRadius.card,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private by design',
                      style: AppTypography.sectionTitle.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your data stays on this device. No login, no cloud, no ads.',
                      style: AppTypography.supporting.copyWith(
                        color: Colors.white.withValues(alpha: .82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _GroupLabel('Manage'),
        _TileGroup(
          children: [
            MoreTile(
              icon: Icons.category_rounded,
              color: AppColors.violet,
              title: 'Categories',
              subtitle: 'Add, edit and hide income and expense categories',
              onTap: () => context.push('/more/categories'),
            ),
            MoreTile(
              icon: Icons.repeat_rounded,
              color: const Color(0xFF0EA5E9),
              title: 'Recurring transactions',
              subtitle: 'Rent, salary, SIPs and bills on repeat',
              onTap: () => context.push('/more/recurring'),
            ),
            MoreTile(
              icon: Icons.archive_outlined,
              color: scheme.primary,
              title: 'Archived Accounts',
              subtitle: 'Restore Accounts you have archived',
              onTap: () => context.push('/accounts/archived'),
            ),
            MoreTile(
              icon: Icons.delete_outline_rounded,
              color: AppColors.negative,
              title: 'Transaction Trash',
              subtitle: 'Restore or permanently delete transactions',
              onTap: () => context.push('/transactions/trash'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const _GroupLabel('Preferences'),
        _TileGroup(
          children: [
            MoreTile(
              icon: Icons.palette_outlined,
              color: const Color(0xFFEC4899),
              title: 'Appearance',
              subtitle: themeModeLabel(themeMode),
              onTap: () => context.push('/more/appearance'),
            ),
            MoreTile(
              icon: Icons.currency_rupee_rounded,
              color: AppColors.positive,
              title: 'Currency & Format',
              subtitle: 'INR · Indian digit grouping',
              onTap: () => context.push('/more/currency'),
            ),
            MoreTile(
              icon: Icons.notifications_outlined,
              color: scheme.primary,
              title: 'Notifications',
              subtitle: notificationSummary(
                ref.watch(notificationPreferencesProvider).valueOrNull,
                ref.watch(notificationStatusProvider).valueOrNull,
              ),
              onTap: () => context.push('/more/notifications'),
            ),
            MoreTile(
              icon: Icons.notifications_active_outlined,
              color: const Color(0xFFF59E0B),
              title: 'Budget Alerts',
              subtitle: 'Monthly spending limit with 80% and 100% alerts',
              onTap: () => context.push('/more/budgets'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const _GroupLabel('Data'),
        _TileGroup(
          children: [
            MoreTile(
              icon: Icons.ios_share_rounded,
              color: AppColors.positive,
              title: 'Export data',
              subtitle: 'Transactions and MyKhata as CSV',
              onTap: () => context.push('/more/export'),
            ),
            MoreTile(
              icon: Icons.cloud_sync_outlined,
              color: const Color(0xFF0EA5E9),
              title: 'Backup & Restore',
              subtitle: 'Password-protected .khata backups',
              onTap: () => context.push('/more/backup'),
            ),
            MoreTile(
              icon: Icons.info_outline_rounded,
              color: scheme.onSurfaceVariant,
              title: 'About App',
              subtitle: 'Version $appVersionLabel',
              onTap: () => context.push('/more/about'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.metadata.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _TileGroup extends StatelessWidget {
  const _TileGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const Divider(height: 1, indent: 64),
          child,
        ],
      ],
    ),
  );
}

class MoreTile extends StatelessWidget {
  const MoreTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            IconBadge(icon: icon, color: color, size: 36, iconSize: 18),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.fieldValue.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metadata.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
