import 'package:flutter/material.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../core/formatting/money_formatter.dart';
import 'more_page.dart';

class _InfoScaffold extends StatelessWidget {
  const _InfoScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: children,
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.supporting.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.fieldValue.copyWith(
              color: color ?? scheme.onSurface,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _rows(List<Widget> rows) => AppCard(
  padding: EdgeInsets.zero,
  child: Column(
    children: [
      for (final (index, row) in rows.indexed) ...[
        if (index > 0) const Divider(height: 1),
        row,
      ],
    ],
  ),
);

class CurrencyFormatPage extends StatelessWidget {
  const CurrencyFormatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    return _InfoScaffold(
      title: 'Currency & Format',
      children: [
        GradientCard(
          padding: const EdgeInsets.all(AppSpacing.md + 4),
          radius: AppRadius.card,
          colors: AppColors.accountGradients[1],
          child: Row(
            children: [
              Text(
                '₹',
                style: AppTypography.balance.copyWith(color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Indian Rupee (INR)',
                      style: AppTypography.sectionTitle.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'All amounts are stored exactly in paise.',
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
        const SectionHeader(title: 'Indian digit grouping'),
        const SizedBox(height: AppSpacing.sm),
        _rows([
          for (final paise in const [100000, 10000000, 1000000000])
            _InfoRow(
              label: 'One ${_spoken(paise)}',
              value: MoneyFormatter.formatPaise(paise),
            ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Precision and signs'),
        const SizedBox(height: AppSpacing.sm),
        _rows([
          _InfoRow(
            label: 'Whole rupees',
            value: MoneyFormatter.formatPaise(50000),
          ),
          _InfoRow(
            label: 'With paise',
            value: MoneyFormatter.formatPaise(50050),
          ),
          _InfoRow(
            label: 'Income',
            value: '+${MoneyFormatter.formatPaise(250000)}',
            color: scheme.positiveText,
          ),
          _InfoRow(
            label: 'Expense or deficit',
            value: MoneyFormatter.formatPaise(-100000),
            color: scheme.negativeText,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Dates'),
        const SizedBox(height: AppSpacing.sm),
        _rows([
          _InfoRow(label: 'Current date', value: dateLabel(today)),
          _InfoRow(label: 'Any other date', value: dateLabel(yesterday)),
        ]),
        const SizedBox(height: AppSpacing.md),
        Text(
          'INR is currently the only supported currency.',
          style: AppTypography.supporting.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _spoken(int paise) => switch (paise) {
    100000 => 'thousand',
    10000000 => 'lakh',
    _ => 'crore',
  };
}

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const principles = [
      (Icons.wifi_off_rounded, 'Fully offline', 'Works without internet.'),
      (
        Icons.phone_android_rounded,
        'Stored on this device',
        'Financial data never leaves your phone.',
      ),
      (
        Icons.no_accounts_outlined,
        'No login, ads or tracking',
        'Nothing to sign up for.',
      ),
      (
        Icons.call_split_rounded,
        'Separate ledgers',
        'MyKhata never changes Account balances.',
      ),
    ];
    return _InfoScaffold(
      title: 'About App',
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.heroGradient),
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'MyAccountsManager',
          textAlign: TextAlign.center,
          style: AppTypography.screenTitle,
        ),
        Text(
          'Version $appVersionLabel',
          textAlign: TextAlign.center,
          style: AppTypography.supporting.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, (icon, title, detail))
                  in principles.indexed) ...[
                if (index > 0) const Divider(height: 1, indent: 64),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                  child: Row(
                    children: [
                      IconBadge(
                        icon: icon,
                        color: scheme.primary,
                        size: 36,
                        iconSize: 18,
                      ),
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
                            Text(
                              detail,
                              style: AppTypography.metadata.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'MyAccountsManager',
              applicationVersion: appVersionLabel,
            ),
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text('Open-source licences'),
          ),
        ),
      ],
    );
  }
}
