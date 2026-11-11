import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/icon_catalog.dart';
import '../../../app/icon_picker_sheet.dart';
import '../../../app/icon_resolvers.dart';

/// Icon keys understood by [resolveAccountIcon].
const accountIconChoices = <(String, String)>[
  ('bank', 'Bank'),
  ('wallet', 'Wallet'),
  ('cash', 'Cash'),
  ('card', 'Card'),
  ('savings', 'Savings'),
  ('investment', 'Investment'),
];

List<Color> accountGradientFor(int? colorValue, {int index = 0}) {
  if (colorValue == null) {
    return AppColors.accountGradients[index %
        AppColors.accountGradients.length];
  }
  final base = Color(colorValue);
  return [base, Color.lerp(base, Colors.white, .22)!];
}

/// Live preview shown above the Account form.
class AccountPreviewCard extends StatelessWidget {
  const AccountPreviewCard({
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.balanceLabel,
    super.key,
  });

  final String name;
  final String? iconKey;
  final int? colorValue;
  final String balanceLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: GradientCard(
        key: ValueKey('$iconKey-$colorValue'),
        colors: accountGradientFor(colorValue),
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: AppRadius.card,
        child: SizedBox(
          height: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: .18),
                    child: Icon(
                      resolveAccountIcon(iconKey),
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'PREVIEW',
                    style: AppTypography.metadata.copyWith(
                      color: Colors.white.withValues(alpha: .78),
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                name.trim().isEmpty ? 'Account name' : name.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sectionTitle.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              AmountText(
                balanceLabel,
                style: AppTypography.transactionAmount.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountIconPicker extends StatelessWidget {
  const AccountIconPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = selected ?? 'wallet';
    final custom = accountIconChoices.every((choice) => choice.$1 != current)
        ? catalogIconFor(current)
        : null;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        // A key picked from the full catalog shows first, selected.
        if (custom != null)
          CategoryChip(
            label: custom.label,
            icon: custom.icon,
            selected: true,
            onTap: () {},
          ),
        for (final (key, label) in accountIconChoices)
          CategoryChip(
            label: label,
            icon: resolveAccountIcon(key),
            selected: current == key,
            onTap: () => onChanged(key),
          ),
        CategoryChip(
          key: const ValueKey('account-more-icons'),
          label: 'More icons',
          icon: Icons.grid_view_rounded,
          selected: false,
          onTap: () async {
            final picked = await showIconPickerSheet(
              context,
              selected: current,
              color: Theme.of(context).colorScheme.primary,
            );
            if (picked != null) onChanged(picked);
          },
        ),
      ],
    );
  }
}
