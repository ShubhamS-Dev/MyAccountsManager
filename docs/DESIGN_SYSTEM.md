# Shared Premium Design System

This document describes the shared UI foundation used by Home and feature screens. Reuse these tokens and widgets instead of introducing screen-local visual values.

## Colors and gradients
- Primary indigo: `AppColors.primary` (#4F46E5); violet: `AppColors.violet` (#7C3AED).
- Semantic income/success: `AppColors.positive` (emerald); expense/error: `AppColors.negative` (rose).
- Hero gradient: `AppColors.heroGradient` (primary to violet).
- Account fallback gradients: `AppColors.accountGradients`. Account-specific `colorValue` may supply the card base color.
- Theme surfaces, foregrounds, outlines, and containers must come from `Theme.of(context).colorScheme`.

## Typography
`AppTypography` follows the Material 3 type scale (approved 2026-11-11, replacing the earlier 11/14/16px rule):

| Token | Size | M3 role | Use |
|---|---|---|---|
| `screenTitle` | 22px | titleLarge | App bar and page titles |
| `sectionTitle` | 16px | titleMedium | Section headings |
| `balance` | 36px | displaySmall | Hero balances |
| `amountInput` | 28px | headlineMedium | Add Transaction amount entry |
| `transactionAmount` | 16px | titleMedium | Amounts in lists and detail rows |
| `fieldValue`, `body` | 14px | bodyMedium | Values, list titles, input text, running text |
| `button` | 14px | labelLarge | Button labels |
| `fieldLabel`, `metadata` | 12px | labelMedium | Labels, dates, chips |
| `supporting` | 12px | bodySmall | Secondary lines and captions |

The theme's `textTheme` maps every M3 role. Text always honours the device font-size setting: never clamp `textScaler`, and size any fixed-height container as a fixed part plus `MediaQuery.textScalerOf(context).scale(textPart)`. Amounts use tabular figures. Do not introduce local font families or arbitrary font sizes.

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
- `PrimaryButton`: 40px action button (grows with the device font size) with a 48px touch area. Optional `gradient` is opt-in; omitted gradient retains the default solid style.
- `CategoryChip`: accessible selectable chip with optional per-category icon tint (`iconColor`).
- `EmptyState`: icon-led empty/error illustration, supporting copy, and optional CTA.

## Motion and accessibility
- Use short, non-blocking transitions; Dashboard amount visibility uses a 250ms `AnimatedSwitcher`.
- Preserve theme-aware contrast, text scaling, semantic labels, and at least 48px interactive hit areas. Icon-only buttons retain 40x40 visual controls within accessible interaction constraints.
- Do not duplicate presentation preferences: monetary privacy uses `amountsHiddenProvider`, which is saved in `app_settings` (`privacy.amounts_hidden`) and survives restarts.
- Theme buttons use `MaterialTapTargetSize.padded`: 40px visual face, 48px hit area.
- Forms wrap their page in `UnsavedChangesGuard`; it asks "Discard changes?" on back navigation only when the form differs from its starting values.
- Future-dated transactions show `ScheduledBadge` (see Scheduled transactions below).

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


## Add Transaction amount-input exception
- `AppTypography.amountInput` is 28px and is reserved exclusively for the prominent Add Transaction amount input.
- The standard `AppTypography.transactionAmount` is 16px everywhere else, including History, Account Details, summaries, and Edit Transaction.
- The Add Transaction Save action may opt into `PrimaryButton.gradient` with `AppColors.heroGradient`; all existing PrimaryButton callers remain solid by default.
- Expense/Income selection, account selection, date shortcuts, amount quick-add controls, and category chips use built-in Flutter animation and shared semantic/theme colors.


## Shared form and feedback widgets (lib/app/app_form_widgets.dart)
Added 2026-11-11 for the forms and screens outside Add Transaction. Reuse these rather than building screen-local variants.
- `FieldHeading`: 12px field label with optional hint.
- `AppSegmentedControl<T>`: animated pill selector (180ms). Each `SegmentOption` can carry a semantic colour, for example emerald for Increase/You gave and rose for Decrease/You got.
- `DateShortcutField`: Today / Yesterday / Pick date with the shared `dateLabel` (Today or DD MMM YYYY). It supports a `firstDate` floor.
- `AmountFormField`: rupee field with live Indian grouping via `IndianAmountInputFormatter`, 16px amount typography and optional signed input. `parseAmountPaise` converts to integer paise.
- `IconBadge`, `StatusPill` (MyKhata), `ColorChoiceRow` (`AppColors.pickerPalette`), `ActionSheetTile` + `showActionSheet`, `confirmAction`, `FormErrorBanner`, `StickyActionBar`, `ScreenErrorState`, `SkeletonList`.
- `IndianAmountInputFormatter` now lives in `lib/core/formatting/` and is shared with Add Transaction; Add Transaction's behaviour is unchanged.
- Save actions on full-screen forms sit in a `StickyActionBar` and opt into the hero gradient.


## Scheduled transactions (approved 2026-11-11)
- A regular transaction dated after the device's local today is Scheduled. Use `isScheduledDate(storedDate, ref.watch(todayProvider))` from `lib/core/time/today_provider.dart`; do not compare against `DateTime.now()` directly.
- Scheduled items are listed with `ScheduledBadge` but excluded from Account balances, Home's month totals and History's month totals until their date. They count automatically from that date; there is no reminder and no schema field.
- `todayProvider` rebuilds just after local midnight, so balances and badges roll over without a restart.
- Home shows an Upcoming card (count and next date) and keeps Recent transactions to money that has already moved. History can open future months that contain scheduled items.
- MyKhata entry dates are capped at today; scheduled lending is not supported.
