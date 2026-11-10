# History Screen

## Purpose
Show a month-scoped transaction history with quick search, type selection, Account and Category filters, and access to Transaction Trash.

## Layout
- Month selector pill with previous/next navigation; future months are disabled.
- Income and Expense summary cards with compact progress bars.
- Custom animated All / Expense / Income selector.
- Search field and Account & Category filter bottom sheet.
- Active Account, Category, and type selections appear as removable chips.
- When search or any filter is active, show `Showing X of Y transactions`. Both counts are based on the already-loaded History list; no additional query is issued.
- Transactions are grouped by date using Flutter slivers and pinned `SliverPersistentHeader` date labels.
- Each transaction uses existing Category `iconKey` and `colorValue` from the History projection. If no icon mapping exists, use the income/expense directional arrow.
- Existing transaction details/edit navigation and the Open Trash action remain available.

## Summary calculation
Income and Expense totals always cover the entire selected month and are independent of search, Account, Category, and type filters. The existing calculation is retained.

## Filters
Account and Category filters open a bottom sheet. The current selection is highlighted. Clear resets both staged selections; Apply commits them. Active Account, Category, and type filters can also be removed individually from chips. Search and type selection retain their existing in-memory filtering behavior.

## Delete and restore
- Swipe a transaction to move it to Trash using the existing `softDeleteTransaction` repository method.
- The snackbar Undo action calls the existing `restoreTransaction` method.
- The existing Trash button and Transaction Trash page are unchanged. Permanent deletion remains available only in Trash.

## Empty and loading states
- No transactions in the selected month: premium empty state with Add transaction CTA.
- No results after search/filters: separate empty state with Clear filters CTA.
- Initial loading: built-in animated shimmer placeholders. No shimmer dependency is added.

## Data and architecture constraints
- Category icon and colour are exposed only in `TransactionHistoryItem`, the History repository projection. No Drift table/schema/migration changes.
- No Account type field is assumed.
- No new dependency is added.
- Existing search, filters, month navigation, transaction routes, repository financial logic, and Trash workflow are preserved.


## Widget-test coverage and label matching
- The History summary renders metric captions in uppercase (`INCOME` and `EXPENSES`); widget tests assert the rendered labels rather than title-case source strings.
- History widget coverage exercises previous/next month controls, monthly summary, search and clear-search, All/Expense/Income selection, Account and Category filter sheet sections, Account selection/removal chip, Clear/Apply, Trash tooltip, and the initial empty state.
- Bottom-sheet transitions are settled with `pumpAndSettle()`; the animated type selector uses its 220ms animation duration.

- If a search or filter is active, an empty result always uses the `No matching transactions` state with `Clear filters`, even when the underlying History list itself is empty. The first-run `No transactions yet` state is reserved for an unfiltered empty list.


## Theme-aware visual refinements
- Category metadata is read from the joined Category row and displayed as a coloured circular icon. Known icon keys are preferred; when legacy built-in records have no iconKey, their known category names map to the matching glyph. The income/expense arrow is reserved for an unknown category/key. A missing category colour uses the semantic income/expense fallback colour.
- Selected All / Expense / Income segment uses the theme primary fill and onPrimary foreground for high contrast; unselected items use theme surface and onSurfaceVariant.
- The shared Dashboard / Accounts / History FAB uses the shared hero gradient and theme onPrimary white foreground.
- History screen colors use AppColors semantic tokens or Theme.of(context).colorScheme; no screen-local color literals are introduced.
- Summary progress is clamped to the 0–1 range; a zero total produces an empty bar. Expense progress remains proportional to expense / (income + expense).
- Widget coverage verifies category metadata projection and the History swipe-to-Trash + Undo interaction. Existing filter sheet, removable chips, and both empty-state paths remain covered.


## CI regression coverage
- Run #356 RCA and the deterministic swipe/Undo widget-test strategy are recorded in `docs/UI_IMPLEMENTATION_LOG.md`. The test verifies Dismissible removal, Trash persistence, the rendered Undo action, and restoration to History.


## Run #358 RCA — swipe confirmation and asynchronous deletion
- Run: [Flutter validation #358](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42831800087)
- Drift generation, generated-file verification, Dart formatting, and `flutter analyze` passed. The widget suite failed in `swiping a History row moves it to Trash and Undo restores it` at `test/widget_test.dart:533`: the expected `Transaction moved to Trash` snackbar was not found after the test's leftward 500px drag and two 300ms pumps.
- Production-flow inspection: the History row uses `DismissDirection.endToStart`. Previously, `onDismissed` invoked the page-level `_moveToTrash` callback without awaiting its Future. The snackbar used the `HistoryPage` State's context (not the row's BuildContext), so row unmount alone was not the direct context bug. However, deletion and feedback were detached from the Dismissible lifecycle, making the interaction harder to sequence and verify.
- Corrective production change: move the asynchronous soft-delete into `confirmDismiss`. The callback now returns `Future<bool>`, awaits `softDeleteTransaction`, and only permits dismissal after success. It captures the page-level `ScaffoldMessengerState` before the await and uses that captured messenger for success/error feedback. A failed delete returns false, keeping the row visible.
- Corrective test change: use a high-velocity left fling in the configured `endToStart` direction, then explicitly pump the dismissal and snackbar animations and wait for the snackbar. The test still verifies row removal, Trash persistence, Undo, and restoration to History. No test was skipped, deleted, or weakened.
- Local Flutter/Dart commands were not run; CI remains the validation gate.


## Shared icon resolver
- Category icon rendering uses resolveCategoryIcon from lib/app/icon_resolvers.dart. The mapping, category metadata preference, and income/expense fallback glyph are unchanged; only the resolver location is shared with Add Transaction.
