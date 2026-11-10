# Shared Premium Design System

This document describes the shared UI foundation used by Home and feature screens. Reuse these tokens and widgets instead of introducing screen-local visual values.

## Colors and gradients
- Primary indigo: `AppColors.primary` (#4F46E5); violet: `AppColors.violet` (#7C3AED).
- Semantic income/success: `AppColors.positive` (emerald); expense/error: `AppColors.negative` (rose).
- Hero gradient: `AppColors.heroGradient` (primary to violet).
- Account fallback gradients: `AppColors.accountGradients`. Account-specific `colorValue` may supply the card base color.
- Theme surfaces, foregrounds, outlines, and containers must come from `Theme.of(context).colorScheme`.

## Typography
Use `AppTypography`: screen title 16px, section title 14px, balance 38px, transaction amount 16px, and supporting/field/metadata text 11px. Amounts use tabular figures. Do not introduce local font families or arbitrary font sizes for standard content.

## Spacing, radius, and elevation
- Spacing: `AppSpacing.xs/sm/md/lg/xl/xxl` (4/8/16/24/32/40).
- Standard action visual height: `AppSpacing.buttonHeight` (40); interactive hit area: `AppSpacing.touchTarget` (48).
- Radius: `AppRadius.sm/md/button/input/card/hero/pill`.
- Card elevation: `AppShadows.card`; hero elevation is encapsulated by `GradientCard`.

## Shared widgets
- `AppCard`: themed surface card with standard border, radius, and shadow. Use for grouped content and tappable surface cards.
- `GradientCard`: branded hero/account card. Pass a shared gradient token or a data-driven account gradient.
- `AmountText`: monetary text with tabular figures and consistent overflow handling.
- `SectionHeader`: section title and optional action.
- `PrimaryButton`: standard 40px action button with a 48px touch area.
- `CategoryChip`: accessible selectable chip.
- `EmptyState`: icon-led empty/error illustration, supporting copy, and optional CTA.

## Motion and accessibility
- Use short, non-blocking transitions; Dashboard amount visibility uses a 250ms `AnimatedSwitcher`.
- Preserve theme-aware contrast, text scaling, semantic labels, and at least 48px interactive hit areas. Icon-only buttons retain 40x40 visual controls within accessible interaction constraints.
- Do not duplicate presentation preferences: monetary privacy uses `amountsHiddenProvider`.

## Usage
```dart
GradientCard(
  colors: AppColors.heroGradient,
  child: AmountText(
    formattedAmount,
    style: AppTypography.balance.copyWith(color: Colors.white),
  ),
)
```

## History screen patterns
- Use `AppCard`, `AmountText`, `EmptyState`, `AppTypography`, `AppColors`, `AppSpacing`, `AppRadius`, and `AppShadows` for transaction history presentation.
- Keep the month selector compact and pill-shaped. Monthly income/expense totals represent the entire selected month and are independent of list filters.
- Use a custom animated type selector and filter bottom sheets with explicit Clear/Apply actions. Render active Account, Category, and type filters as removable chips.
- Group transactions with Flutter slivers and pinned `SliverPersistentHeader` date headings; do not add a sticky-header dependency.
- Category icon/color may be projected from existing category metadata for History only. Fall back to the semantic income/expense arrow when no icon mapping exists.
- Use built-in animation for shimmer placeholders; do not add a shimmer package.
- Swipe-to-delete must use the repository's soft-delete operation and offer Undo through its existing restore operation. The Trash destination remains available.


## History theme compatibility
- History-specific selection, transaction, date-header, empty-state, and swipe surfaces must use AppColors semantic tokens or Theme.of(context).colorScheme; do not add literal colors or screen-local color constants.
- Selected History type segments use colorScheme.primary with colorScheme.onPrimary text to preserve high contrast. Unselected segments use themed surface and onSurfaceVariant.
- The shared Dashboard, Accounts, and History FAB uses AppColors.heroGradient with colorScheme.onPrimary foreground.
