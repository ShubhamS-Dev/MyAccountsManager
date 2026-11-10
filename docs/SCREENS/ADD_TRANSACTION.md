# Add Transaction Screen

## Scope and invariants
- This document describes the premium Add Transaction form only.
- Edit Transaction is a separate screen and is intentionally unchanged in this implementation.
- Expense/Income remains above the fields. Preserve this exact field and keyboard traversal order:
  1. Account
  2. Transaction date
  3. Note
  4. Amount
  5. Category
- The repository's create flow, financial validation, and transaction persistence are unchanged. No schema migration or new package.

## Expense / Income
- A built-in animated sliding selector sits above the fields.
- Expense uses the semantic rose/error tint; Income uses the semantic emerald/positive tint.
- Selected foreground uses the matching ColorScheme on-container color for contrast.
- Changing type switches the existing activeCategoriesByTypeProvider(type) stream and clears an incompatible category selection.
- Home's Income shortcut continues to route to Add Transaction with initialType: income.

## Account
- Active Accounts are shown as horizontal, scrollable chips with icon, metadata color, name, and current balance.
- Account icon and color use existing iconKey and colorValue.
- Balance uses accountBalancePaiseProvider and respects amountsHiddenProvider.
- Existing repository order is retained: pinned Accounts first, followed by sort order and name. The first item is preselected.
- Selecting a chip ensures it remains visible in the horizontal viewport.
- If no active Account exists, show an EmptyState and the Add account CTA to /accounts/new.
- No last-used Account persistence is introduced.

## Date
- Shortcuts: Today, Yesterday, Pick date. Pick date opens Flutter's native date picker.
- The visible date label is exactly Today for the device's current local calendar date; all other selected dates use DD MMM YYYY.
- A selected Yesterday shortcut therefore displays yesterday's actual formatted date beneath the shortcuts.
- Persist with DateOnly.toUtcEpochMilliseconds; the date-only value remains UTC midnight and is never converted through local time.

## Note
- Optional note starts at one line and grows up to four visible lines.
- Preserve the existing 500-character limit.
- The character count is hidden through 400 characters and shown only after that point.

## Amount
- Use the dedicated AppTypography.amountInput token at 28px. This is the only approved exception to the standard 16px transaction amount token.
- Rupee symbol and amount use the current Expense/Income semantic accent.
- Live Indian grouping uses the shared MoneyFormatter; persisted value is integer paise.
- Preserve existing validation: 1–12 whole-rupee digits, positive amount, and at most two decimal places.
- Quick-add chips add rupees to the current paise amount. Example: ₹10.50 + ₹100 = ₹110.50.
- Reject input beyond 12 whole-rupee digits and prevent quick-add from exceeding that limit.
- Validation messages remain inline and readable.

## Category
- Display active categories for the current transaction type as a wrapping grid of shared CategoryChip widgets.
- Use the shared category icon resolver and existing iconKey / colorValue, with semantic type color as fallback.
- Selected category state animates through the shared chip presentation.
- Recent categories are intentionally deferred; no schema or history-query expansion is included.

## Save and keyboard
- Save remains in the bottom safe area and moves above the keyboard with Scaffold resizing.
- Uses PrimaryButton with the opt-in AppColors.heroGradient; other PrimaryButton callers remain solid by default.
- Button face is 40px with a 48px interaction area.
- Saving disables the action and guards against duplicate taps.
- After the existing repository save succeeds, provide built-in haptic feedback and a short AnimatedSwitcher checkmark, then close the screen. No blocking success animation.
- The form scrolls naturally to keep focused inputs visible; no third-party keyboard or animation package.

## Shared code and unchanged screens
- Shared icon mappings live in lib/app/icon_resolvers.dart; Accounts and History use the same mappings they used before extraction.
- PrimaryButton.gradient is optional and defaults to the existing solid style.
- Shared shadows are unchanged.
- Edit Transaction is not redesigned and does not adopt the 28px amount token.

## Regression coverage
- Keep Home Income shortcut, type switch, field order, and Today label tests.
- Verify non-Today DD MMM YYYY date presentation.
- Verify live Indian grouping, paise-safe quick-add, 12-digit cap, and integer-paise save.
- Verify pinned-first preselection, Account chip horizontal scrolling/selection visibility, and no-active-Account empty state.
- Verify Category type filtering, save flow, and no duplicate save while saving.
- All widget tests use explicit per-test timeouts. Drift-backed operations in widget tests run through tester.runAsync; unmount the tree in the test body when a live Drift subscription is used.
