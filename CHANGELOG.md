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
