# Changelog

## Unreleased

### Accounts screen — premium UI refresh
- Reused shared Dashboard gradients, cards, typography, amount and empty-state widgets.
- Connected Accounts amount visibility to the shared Dashboard privacy preference.
- Refreshed Account cards, summary, search section, add-account affordance and action bottom sheet.
- Corrected the active Account count label for singular and plural counts; updated the Accounts widget test to use the shared amount-visibility tooltips.
- Used existing account icon/color metadata with a safe palette fallback.
- UI-only change: Account data, provider/repository logic, navigation, search, ordering, pinning and archive behaviour are unchanged.

### History screen — premium UI refresh
- Added month pill, monthly summary cards, animated type selector, filter bottom sheet, removable filter chips, and filtered-result count.
- Added pinned date-group headers, category icon/colour presentation, swipe-to-trash with Undo, shimmer loading, and separate first-run/no-results empty states.
- Monthly totals continue to represent the full selected month regardless of active filters.
- Expanded History widget coverage for month navigation, search, type selection, Account/Category filters, removable chips, Trash access, and empty state.
- Corrected empty-state selection so active search/filters show the no-results state even when there are no stored transactions.
- Reused shared design tokens/widgets; no new package, schema migration, or navigation change.

- Refined History category icon mapping, selected-segment contrast, and shared gradient FAB; added metadata-projection and swipe/Undo regression coverage. History color usage remains token/theme-driven for future Light-theme support.


### Add Transaction — premium form refresh
- Rebuilt the Add Transaction experience with animated Expense/Income selection, pinned-first Account chips, date shortcuts, expandable Note, prominent Indian-formatted paise-safe Amount input, quick-add chips, and Category chips.
- Added the dedicated 28px `AppTypography.amountInput` exception; all standard transaction amount typography remains 16px.
- Added opt-in gradient support to `PrimaryButton`; the default appearance for all existing callers remains solid.
- Added shared Account and Category icon resolvers without changing Accounts or History presentation.
- Preserved UTC date-only storage, category-type filtering, repository validation/save flow, and Home Income shortcut.
- No schema migration, package, Edit Transaction change, or shared shadow change.


### Add Transaction — review refinements
- Kept the three quick-add amounts in one compact horizontal row and removed the nested TextField fill from the Note pill.
- Aligned the rupee symbol, amount and hint to the dedicated 28px amount typography; added a CI-captured screenshot while an amount is entered.
- Applied per-category icon tints and distinct Transportation / Vehicle Maintenance / Others icon mappings through the shared resolver used by History.
- Reduced the horizontal Account card selector height from 76px to 68px.
