import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'icon_resolvers.dart';

class CategoryIconBadge extends StatelessWidget {
  const CategoryIconBadge({
    required this.iconKey,
    required this.categoryName,
    required this.colorValue,
    required this.income,
    super.key,
    this.fallbackColor,
    this.size = 40,
  });

  final String? iconKey;
  final String categoryName;
  final int? colorValue;
  final bool income;

  /// Used when the category has no colour; defaults to the income/expense hue.
  final Color? fallbackColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = colorValue == null
        ? fallbackColor ?? (income ? AppColors.positive : AppColors.negative)
        : Color(colorValue!);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .12),
      ),
      child: Icon(
        resolveCategoryIcon(iconKey ?? categoryName, income: income),
        size: 19,
        color: color,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.radius = AppRadius.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: AppShadows.card,
          ),
          child: child,
        ),
      ),
    );
  }
}

class GradientCard extends StatelessWidget {
  const GradientCard({
    required this.child,
    super.key,
    this.colors = AppColors.heroGradient,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.hero,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final List<Color> colors;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    // The gradient is painted with Ink so the tap ripple shows on top of it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x263D35A8),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: onTap == null && onLongPress == null
              ? Padding(padding: padding, child: child)
              : InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  splashColor: Colors.white.withValues(alpha: .16),
                  highlightColor: Colors.white.withValues(alpha: .08),
                  child: Padding(padding: padding, child: child),
                ),
        ),
      ),
    );
  }
}

/// Shown in place of every amount while Hide amounts is on.
const hiddenAmountMask = '₹ ••••';

/// [text] with each [hiddenAmountMask] spoken as "amount hidden", for
/// `semanticsLabel`; null when nothing in [text] is masked.
String? maskedAmountSemantics(String text) => text.contains(hiddenAmountMask)
    ? text.replaceAll(hiddenAmountMask, 'amount hidden')
    : null;

class AmountText extends StatelessWidget {
  const AmountText(
    this.value, {
    super.key,
    this.color,
    this.style,
    this.maxLines = 1,
  });

  final String value;
  final Color? color;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(
    value,
    semanticsLabel: maskedAmountSemantics(value),
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: (style ?? AppTypography.transactionAmount).copyWith(
      color: color ?? style?.color ?? Theme.of(context).colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: AppTypography.sectionTitle)),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.loading = false,
    this.gradient,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final List<Color>? gradient;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The face is 40px at default text size and grows with the device font
    // size; the outer box keeps the 48px hit area.
    final face = SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: gradient == null
            ? FilledButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : FilledButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: scheme.onSurface.withValues(
                  alpha: .12,
                ),
                foregroundColor: scheme.onPrimary,
                disabledForegroundColor: scheme.onSurfaceVariant,
                shadowColor: Colors.transparent,
              ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.sm),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 17),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: (AppSpacing.touchTarget - AppSpacing.buttonHeight) / 2,
      ),
      child: Center(
        heightFactor: 1,
        child: gradient == null
            ? face
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient!,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: face,
              ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
    this.color,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? accent.withValues(alpha: .12) : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? accent : scheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color:
                      iconColor ??
                      (selected ? accent : scheme.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(label, style: AppTypography.fieldValue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.receipt_long_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
            ),
            child: Icon(icon, size: 34, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.supporting.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Marks a future-dated transaction that is not yet counted in balances.
class ScheduledBadge extends StatelessWidget {
  const ScheduledBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 12,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            'Scheduled',
            style: AppTypography.metadata.copyWith(
              fontSize: 11,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
