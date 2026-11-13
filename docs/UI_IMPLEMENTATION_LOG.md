# UI Implementation Log

This document records actual UI implementation work, decisions, files changed, and validation evidence for the UI refresh branch. A listed screen is not considered complete merely because a route or placeholder exists.

## Branch and baseline

- Repository: `ShubhamS-Dev/MyAccountsManager`
- Working branch: `feature/20261109/ui-refresh`
- Base: `feature/20261108/project-foundation`
- Product/architecture baseline: `README.md`, `agent.md`, `milestone.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE_SCHEMA_V1.md`, and `docs/UI_UX_REQUIREMENTS.md`.
- The user's confirmed screen inventory is recorded in `docs/UI_UX_REQUIREMENTS.md`.
- All standard action buttons are 40 logical pixels high. Screen titles are at most 16px, section headings 14px, standard transaction amounts 16px (Add Transaction input exception 28px), and supporting/label text 11px.
- Light mode is the default; Dark mode is supported. Currency is INR only. Date-only business values use UTC-midnight storage and display as `DD MMM YYYY`.

## Implemented in this branch

### Shared theme foundation

Files:
- `lib/app/app_theme.dart`
- `lib/app/my_accounts_manager_app.dart`

Changes:
- Added centralized premium-minimal color and typography tokens.
- Added Light and Dark theme construction, with Light selected as the default.
- Standardized app bars, input fields, cards, navigation bar, dividers, and icon-button dimensions.
- Applied 40px visual height to Filled, Elevated, Outlined, and Text action buttons.
- Set icon-only action controls to 40 × 40 logical pixels.

### Accounts overview

File:
- `lib/features/accounts/presentation/accounts_page.dart`

Behavior:
- Displays the total active Account balance and explicitly notes that MyKhata is excluded.
- Provides show/hide balance control.
- Provides navigation to Archived Accounts.
- Displays active Accounts in a two-column grid, preserving repository ordering (pinned first).
- Provides name/description search and an Add Account action.
- Account cards open Account Details.
- Three-dot actions include View Details, Edit, Adjust Balance, Pin/Unpin, and Archive.
- Long-press opens a compact action sheet with View Details, Edit, and Archive.
- Archive requires confirmation and preserves transaction history.
- Uses reactive account and balance providers; no copied balance is stored in the UI.

### Account Details

Files:
- `lib/features/accounts/presentation/account_details_page.dart`
- `lib/app/app_router.dart`

Behavior:
- Added route `/accounts/:accountId`. Static routes for `/accounts/archived` and `/accounts/new` are ordered before the dynamic Account Details route to prevent route shadowing.
- Displays Account name, description, and current calculated balance.
- Shows opening balance, income, expenses, and balance adjustments as separate breakdown rows. Income/expense/adjustment totals in the breakdown are restricted to records effective on or before the current local calendar date, matching the authoritative current-balance rule.
- Displays recent Account transaction history (up to 30 entries), with date-only formatting and explicit income/expense signs.
- Transaction rows navigate to the existing Edit Transaction screen.
- Provides direct navigation to Edit Account and Balance Adjustments.
- Reads existing database-backed providers/repositories; does not add a duplicate balance store.

### Regression test

File:
- `test/widget_test.dart`

Added a widget test covering navigation from the Accounts tab to Account Details and asserting the balance breakdown, current balance, and transaction history sections are rendered.

## Known gaps / follow-up implementation

- Home Dashboard still needs migration from the foundation scaffold to the previously approved dashboard composition (month income/expense/net, pinned account grid, latest five transactions, separate MyKhata summary, eye control).
- Account Details transaction history may include future-dated transactions as upcoming records; the current-balance breakdown excludes future-dated transactions and adjustments, matching the authoritative effective-date calculation.
- Accounts archived screen still needs the approved premium styling and any remaining archive-management actions. Permanent Account deletion must not be added until its data-loss confirmation and repository behavior are fully specified.
- MyKhata, Global Categories, More, Settings, budgets, savings, and backup/restore workflows remain pending unless separately recorded as implemented.
- The Add Transaction page still requires a full pass for exact field order, Today/date label, shared formatter, compact date picker, and global button styling.
- Existing screens need visual review for exact 40px button rendering and typography, not just theme defaults.

## Validation record

At the time of this entry:
- Dart format: **Not run** (no Flutter SDK execution performed in this session).
- Flutter analyze: **Not run**.
- Flutter tests: **Not run**. A regression test was added but is not yet a passing test result.
- Android debug build: **Not run**.
- Android device/emulator visual review: **Not run**.

Do not report any of these checks as passed until a Flutter-enabled runner or developer machine executes them and the result is inspected.


## CI root-cause analysis and corrective changes — Run #217

Run: [Flutter validation #217](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42573625248)

- Commit under validation: `3ef527f95e80c7e652db0f226291d336d1f87cc8`.
- The workflow successfully checked out the feature branch, installed Flutter 3.47.9, resolved dependencies, generated Drift code, and formatted Dart sources.
- The job failed at `flutter analyze`; tests and Android debug APK build were skipped as downstream steps.
- Root causes: Account Details referenced `TransactionHistoryItem` without importing its defining repository library; this caused follow-on invalid type/nullability/fold diagnostics. The theme supplied `CardTheme` instead of Flutter 3.47.9's `CardThemeData`.
- Additional analyzer findings included an unused local, missing braces, import ordering, and deprecated `withOpacity` calls.

Corrective source changes committed after Run #217:
- `account_details_page.dart`: import the concrete transaction repository type, reuse a single typed history filter for watch/invalidation, add explicit null-account block, remove unused color variable, and use typed transaction history items for integer-paise aggregation.
- `app_theme.dart`: use `CardThemeData` and `Color.withValues(alpha: ...)`.
- `accounts_page.dart`: sort imports and replace deprecated opacity calls.

These changes are fixes, not validation evidence. A new workflow run must pass analysis, tests, and Android debug build before the UI refresh can be considered validated. Do not start the next feature slice until that run is inspected.

## CI root-cause analysis and corrective change — Run #222

Run: [Flutter validation #222](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42574187648)

- Commit under validation: `84cbef57469576576af150ec517f20e2c94b2c74`.
- Dependency resolution, Drift code generation, and Dart formatting passed.
- `flutter analyze` failed on one remaining deprecated API call: `colors.outlineVariant.withOpacity(0.7)` in `lib/features/accounts/presentation/accounts_page.dart` (line 284, column 59).
- The prior Run #217 remediation had replaced other deprecated opacity calls in this file but missed the Account Card border.
- Corrective change: replaced the call with `colors.outlineVariant.withValues(alpha: 0.7)`. This preserves the intended 70% opacity and does not change layout or behavior.
- Source fix commit: `6c4320a99bcca4c6a9614bfaad02d0734ac7a912`.

This correction is not validation evidence. Inspect the subsequent workflow run and require `flutter analyze`, tests, and Android debug APK build to pass before starting another feature slice.


## CI root-cause analysis and corrective change — Run #224

Run: [Flutter validation #224](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42574668809)

- Commit under validation: `e95a55902e42667c8ccf131dc41471c7b2ae88e9`.
- Checkout, Flutter setup, dependency resolution, Drift code generation, formatting, and `flutter analyze` passed.
- The widget test `opens Account Details from the Accounts grid` failed with Flutter's pending-timer invariant: `A Timer is still pending even after the widget tree was disposed`.
- Root cause identified in `test/widget_test.dart`: the test ProviderScope replaced the Account and transaction streams with deterministic `Stream.value` overrides, but omitted `balanceAdjustmentsProvider`. Account Details watches this provider, so the test unintentionally opened a real Drift query stream against the in-memory database. The widget teardown then closed the database while the query stream's internal timer/subscription lifecycle was still active.
- Corrective test change: override `balanceAdjustmentsProvider` with `Stream.value(<BalanceAdjustmentRow>[])`, consistent with the test's existing strategy of avoiding database-backed query subscriptions in navigation/form widget tests. Repository stream behavior remains the responsibility of repository tests.
- Test fix commit: `d6a3cbc5fa82aaa639f736dabcf9989d3a1c5a5c`.

This is a source-level RCA and correction, not passing validation evidence. Confirm the new workflow run passes the complete test suite and Android debug APK build before proceeding.


## Approved UI refresh — Phases 1–3 implementation slice

User approval: implement Phases 1–3 first; stop for user review before beginning MyKhata and More.

### Shared UI foundation
- Tightened shared input decoration vertical padding while preserving the 40px standard action-button theme and 40×40 icon action target.
- Reduced card corner radius and adjusted bottom navigation sizing for a more compact, consistent visual rhythm.
- Kept Light as default and Dark theme support intact.
- Removed the global Add Transaction FAB from MyKhata and More tabs; it remains available on Home, Accounts, and History.

### Home Dashboard
- Replaced the foundation welcome/lock/getting-started composition with a live finance dashboard.
- Added current-month Income, Expenses, and Net Cash Flow from the reactive transaction-history stream.
- Added active Account balance summary, pinned-first two-column Account cards, and the latest five transactions.
- Added a local show/hide amounts control covering dashboard balances and transaction amounts.
- MyKhata summary is intentionally deferred until the separately approved MyKhata phase; no placeholder financial value is fabricated.

### Accounts and forms
- Tightened Accounts overview spacing, total-balance card proportions, and Account grid card height without changing the approved two-column layout or Account actions.
- Compactened Create Account and Edit Account form spacing; shared theme field padding now applies.
- Compactened Add Transaction form spacing while retaining the approved Account → Date → Note → Amount → Category order and Today/date behavior.
- Reordered Edit Transaction to match the same field sequence, including Today / DD MMM YYYY date presentation.
- Compactened History filter spacing and removed nested ListTile padding from Edit / Move to Trash popup menu items.
- Balance Adjustments now uses the shared MoneyFormatter and DateOnly formatter instead of its own currency/date presentation logic, with tighter form spacing.

### Regression coverage and validation
- Extended the Home dashboard widget test to assert the monthly summary, Account section, and recent transaction section.
- Source updates are committed to the feature branch. Flutter format, analyze, tests, Android debug APK, and device visual review must be verified by the next CI run; no completion claim is made before those checks pass.
- MyKhata and More implementation remains out of scope until the user reviews Phases 1–3.


## Run #240 RCA — Flutter analyze failure

- Run: [#240](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42579437350)
- Head commit: `40970476c5efc806a30b80bd4a85b1aaff99c0e6`
- Pipeline reached `flutter analyze`; dependency resolution, Drift generation, and `dart format .` completed successfully.
- Failure: analyzer returned exit code 1 for two `curly_braces_in_flow_control_structures` info diagnostics in `lib/features/shell/presentation/app_shell.dart`. Both were single-line early returns in empty-state handling (empty Accounts and empty Recent Transactions). This workflow treats analyzer infos as validation failures.
- Tests, Android debug APK build, and artifact upload were skipped because the analyze step failed.
- Corrective action: wrap both conditional return statements in braces. No behavior change intended.
- Next gate: rerun the full validation workflow and confirm analyze, tests, and APK build all pass.


## Run #242 RCA — ambiguous widget finder in transaction test

- Run: [#242](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42579884890)
- Flutter formatting and `flutter analyze` passed with no issues.
- Test failure: `switches the transaction form from expense to income` at `test/widget_test.dart:142`.
- Root cause: `find.text('Income')` matched both the Home dashboard monthly Income metric and the Income label in the Add Transaction `SegmentedButton`. The widget test attempted to tap a finder with two matches.
- Corrective action: scope the finder to the `SegmentedButton` using `find.byWidgetPredicate`, assert exactly one matching Income segment, then tap it.
- This changes only the test target selection; transaction form behavior is unchanged.
- Android debug APK build was skipped in Run #242 because the test step failed. Re-run full validation after this fix.


## Run #244 RCA — SQLite native asset checksum download failure

- Run: [#244](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42580416899)
- Dependency resolution, Drift generation, formatting, Flutter analysis, and all tests passed.
- Android debug APK build failed inside the `sqlite3 3.8.0` native-assets hook while downloading `libsqlite3.arm.android.so`.
- Exact failure: downloaded asset SHA-256 `bef140a1...e8a29e8a` differed from the package-pinned expected SHA-256 `d0d6eeaf...fceecf3`.
- This occurs before application compilation and indicates a corrupted/inconsistent downloaded native asset, not an application source or test failure. Do not bypass checksum validation or alter the expected hash.
- Corrective action: classify the sqlite3 native asset checksum-mismatch message as a retryable download failure in the Android debug build retry loop. A subsequent attempt reruns Flutter's native asset hook and performs the package's own checksum verification again. The existing three-attempt cap remains in place.
- APK upload remains gated on a successful debug build.


## Accounts screen premium redesign — UI-only

- File: `lib/features/accounts/presentation/accounts_page.dart`.
- Replaced screen-local balance privacy with shared `amountsHiddenProvider`; Dashboard, Accounts and Account Details now reflect the same presentation preference.
- Replaced the screen-specific navy summary with `GradientCard` and the shared Dashboard hero gradient.
- Account cards use `GradientCard`, shared spacing/radius/typography, existing `iconKey` and `colorValue`, with the Dashboard account palette as fallback.
- Added shared `SectionHeader`, `AmountText`, `AppCard`, and `EmptyState` usage, plus a premium bottom sheet for View details, Edit, Adjust balance, Pin/Unpin and Archive.
- No Delete action, Account type field, schema/model change, provider/repository change, or route change.
- Search, pinned-first ordering, balance sources, and archive confirmation remain as before.
- Validation for this slice: pending CI run; do not claim analyzer/tests passed until the run is inspected.


## Accounts count-label and widget-test correction — Run #339 follow-up

- Updated the Accounts summary count to use singular/plural wording: `1 active account` and `2 active accounts`.
- Updated the Accounts overview widget test to assert the singular label and use the shared privacy tooltips (`Hide amounts` / `Show amounts`).
- Reviewed all files under `test/` for stale Accounts presentation assertions. The obsolete count label and old balance tooltip names were the only stale Accounts UI expectations found; Dashboard privacy assertions already used the current shared tooltip labels. No test was removed or skipped.
- Updated `docs/SCREENS/ACCOUNTS.md` to document the count-label behavior.
- Validation: local Dart/Flutter commands were not run in this environment. CI is the agreed validation gate for this correction; record the new run result after it completes.


## Run #340 RCA — Accounts empty-state CTA visibility in widget test

- Run: [Flutter validation #340](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42785859897)
- Drift generation, generated-file verification, Dart formatting, and `flutter analyze` passed. The test suite failed in `shows and filters the refreshed Accounts overview` at `test/widget_test.dart:307`.
- Exact failure: `Expected: exactly one matching candidate; Actual: Found 0 widgets with text "Widget test Account".` The preceding tap on the `Clear search` EmptyState action produced a hit-test warning: its center was outside the visible area and the hit test landed on the bottom-navigation `History` item. Therefore the search was not cleared and the Account remained filtered out.
- Corrective test change: explicitly call `tester.ensureVisible(clearSearchAction)` and settle before tapping the existing CTA. The test and UI behavior remain intact; no test was removed or skipped.
- Local Dart/Flutter validation was not run; CI remains the agreed validation gate.


## Run #341 RCA — lazy Accounts list items were outside the viewport

- Run: [Flutter validation #341](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42786176088)
- Drift generation, generated-file verification, Dart formatting, and `flutter analyze` passed. The test suite failed in `shows and filters the refreshed Accounts overview` at `test/widget_test.dart:292`.
- Exact failure: `Expected: exactly one matching candidate; Actual: Found 0 widgets with text "1 active account".`
- Root cause: the Accounts screen is a scrollable list. Its summary count and Account card are below the initial viewport and are lazily built; the test queried them before scrolling them into view. The previous run also showed a CTA hit-test issue, which was separately fixed by ensuring the EmptyState action is visible before tapping.
- Corrective test change: scroll the Accounts list until the count and Account card are visible before asserting them, and explicitly ensure the shared privacy control and search field are visible before interaction. This preserves all test coverage and does not alter screen behavior.
- Local Dart/Flutter validation was not run; CI remains the agreed validation gate.


## Run #342 RCA — scroll helper could not resolve the Accounts scrollable

- Run: [Flutter validation #342](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42786543124)
- Drift generation, generated-file verification, Dart formatting, and `flutter analyze` passed. The test failed at `test/widget_test.dart:292` before reaching the count assertion.
- Exact error: `StateError: Bad state: No element`, originating from `WidgetController.dragUntilVisible` / `scrollUntilVisible` while resolving the supplied `find.byType(Scrollable).first` finder.
- Corrective test change: target the Accounts page's own `ListView` by locating the ancestor of its unique `Your accounts` heading, then drag that list into the needed scroll position. This avoids selecting a non-existent/ambiguous generic Scrollable and retains the UI assertions.
- Local Dart/Flutter validation was not run; CI remains the agreed validation gate.


## Run #343 RCA — wait for active Accounts stream before count assertion

- Run: [Flutter validation #343](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42786847210)
- Drift generation, generated-file verification, Dart formatting, and `flutter analyze` passed. The test failed at `test/widget_test.dart:298`.
- Exact failure: `Expected: exactly one matching candidate; Actual: Found 0 widgets with text "1 active account".`
- Root-cause refinement: after bringing the Accounts ListView into position, the test asserted the count immediately after `pumpAndSettle`. The test supplies an asynchronous `Stream.value` override for `activeAccountsProvider`; the assertion must wait for that stream-backed UI text rather than assume it has emitted by the time the animation settles.
- Corrective test change: after scrolling the Accounts ListView, use the existing `pumpUntilFound` helper to wait for the singular count label before asserting it. No production behavior or test coverage is removed.
- Local Dart/Flutter validation was not run; CI remains the agreed validation gate.


## Run #344 RCA — production count-label change was missing from the committed tree

- Run: [Flutter validation #344](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42787239566)
- Formatting and `flutter analyze` passed; the widget test failed at `test/widget_test.dart:298` with: `Expected: exactly one matching candidate; Actual: Found 0 widgets with text "1 active account".`
- Exact source inspection after the run showed `accounts_page.dart` still contained `'${items.length} active accounts'`. The earlier corrective commit updated the test and docs but did not retain the production source change in its Git tree. Therefore the test was asserting the new label while the UI still rendered the old plural-only label. This was a commit-tree construction issue, not a Flutter/runtime issue.
- Corrective action: now update the production Accounts count label and Accounts screen documentation in the current branch tree, preserving the already committed widget-test fixes and CI RCA history.
- Local Dart/Flutter validation was not run; CI remains the agreed validation gate.


## Run #345 RCA — header action assertion occurred after scrolling header off-screen

- Run: [Flutter validation #345](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42787614030)
- The production singular/plural count change is now present in the committed Accounts source. Formatting and `flutter analyze` passed. Tests advanced past the count and Account assertions, then failed at `test/widget_test.dart:301`.
- Exact failure: `Expected: exactly one matching candidate; Actual: Found 0 widgets with widget matching predicate` for `find.byTooltip('Archived accounts')`.
- Root cause: the test scrolled the Accounts list before checking an icon tooltip located in the hero header, which had moved off-screen. This is a test ordering issue, not missing production UI.
- Corrective test change: assert the Archived Accounts action and exercise the shared hide/show amount control while the hero header is visible, then scroll down to assert the active count and Account card.
- Local Dart/Flutter validation was not run; CI remains the agreed validation gate.


## History screen — approved premium redesign

- File: `lib/features/transactions/presentation/history_page.dart`.
- Reused shared AppCard, AmountText, EmptyState, typography, colour, spacing, radius, and shadow tokens.
- Added a month pill, monthly income/expense summary cards with progress bars, animated All/Expense/Income selector, Account/Category filter bottom sheet, removable selected-filter chips, and filtered-result count caption.
- Monthly summary remains independent of filters and uses the existing selected-month calculation.
- Added date-grouped slivers with pinned Flutter `SliverPersistentHeader` headings, category metadata in the History projection, fallback income/expense icons, built-in animated shimmer placeholders, and two distinct empty states.
- Swipe-to-delete calls existing `softDeleteTransaction`; Undo calls existing `restoreTransaction`. Existing Trash navigation and Trash page remain unchanged.
- No dependency or database schema migration added. Account/category/type filtering, search, month selection, transaction details/edit navigation, and repository financial logic remain unchanged.
- Updated History widget assertions; repository tests for filtering, soft delete, restore, and permanent delete are retained.
- Local Dart/Flutter validation was not run; CI is the validation gate.


## Run #350 RCA — History summary caption assertion

- Run: [Flutter validation #350](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42809164074)
- Drift generation, generated-file verification, formatting, and Flutter analysis passed. The widget suite reported 40 passing tests and one failure.
- Exact failure: `Expected: exactly one matching candidate; Actual: _TextWidgetFinder:<Found 0 widgets with text "Expenses": []>`, at `test/widget_test.dart:415`, in `shows the approved History filters and monthly summary`.
- Root cause: stale test expectation (a). The History summary's `_SummaryCard` applies `label.toUpperCase()`, so the rendered caption is `EXPENSES`, not `Expenses`. The production History UI was rendering the approved uppercase caption; no UI fix is required.
- Corrective test update: assert the actual uppercase `INCOME` and `EXPENSES` captions and expand the same widget test to exercise month navigation, search/clear, All/Expense/Income, Account/Category sheet controls, Account selection/removal chip, Clear/Apply, Trash tooltip, and the empty state. Bottom-sheet transitions use `pumpAndSettle()`; the 180ms segmented animation is pumped for 220ms.
- Reviewed every Dart file under `test/`: the other `Expenses` assertion belongs to the Home dashboard, and the remaining `Account`, `Category`, and `SegmentedButton` finders cover current Account Details or Add Transaction form UI, not stale History controls. Repository History tests remain unchanged.
- Local Dart/Flutter commands were not run; CI is the validation gate.


## Run #352 RCA — active search rendered the first-run empty state

- Run: [Flutter validation #352](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42812475640)
- Drift generation, generated-file verification, formatting, and `flutter analyze` passed. The widget suite failed in `shows and interacts with the approved History controls` at `test/widget_test.dart:435`.
- Exact failure: `Expected: exactly one matching candidate; Actual: _TextWidgetFinder:<Found 0 widgets with text "No matching transactions": []>`.
- Root cause: implementation bug (b). The History empty-state branch selected `No transactions yet` solely from `items.isEmpty`, ignoring an active search/filter. With the test's empty underlying stream and an entered search term, the page incorrectly showed the first-run empty state instead of the no-results state.
- Production fix: show the first-run state only when `items.isEmpty && !_hasFilters`; active search or filters now show `No matching transactions` and `Clear filters`, even if the underlying list is empty. The widget assertion is retained; no test was weakened or removed.
- Run #351's formatter auto-commit is `4678a7f`; this fix is based on that latest branch head. Local Flutter/Dart commands were not run; CI is the validation gate.


## History visual refinement — category metadata, contrast, and FAB
- Confirmed the History projection is wired: watchHistory joins Categories and copies iconKey/colorValue into TransactionHistoryItem. Added a repository assertion proving both values reach the projection.
- Expanded History category icon-key aliases and added a display fallback for legacy built-in categories whose seeded iconKey is null. Known category names render their glyph inside the existing coloured circle; directional arrows are reserved for unknown categories/keys. Missing color metadata falls back to the semantic income/expense color.
- Increased selected segmented-control contrast using theme primary/onPrimary colors. No literal color values are added to History screen code.
- Updated the shared shell FAB to use the hero gradient and onPrimary foreground, so Dashboard, Accounts, and History remain visually consistent.
- Kept summary progress proportional and bounded: zero total is empty; Expense is full only when expenses equal the combined income-plus-expense total.
- Added a live-provider widget test for swipe-to-Trash and Undo. Existing bottom-sheet, removable-chip, and both empty-state tests remain in place.
- Light-theme implementation/verification remains intentionally out of scope per user instruction; no Light-theme validation claim is made.


## CI RCA — run #356 (2026-11-10)
- Format and Analyze passed; the widget-test job failed in the History swipe/Undo test at `test/widget_test.dart:537` while calling `tester.tap(find.text('Undo'))`.
- Exact failure: `TimeoutException after 0:10:00.000000: Test timed out after 10 minutes. Guarded function conflict. The guarded method "tapAt" from class "WidgetController" was called from .../test/widget_test.dart on line 537. Then, the "pumpWidget" method from class "WidgetTester" was called from .../test/widget_test.dart on line 55. The first method (WidgetController.tapAt) had not yet finished executing at the time the second method (WidgetTester.pumpWidget) was called.`
- The test used `pumpAndSettle` around a screen that contains an intentionally repeating shimmer while its provider is loading. The swipe test also relied on an asynchronous live Drift stream to remove the dismissed row. The row removal and Trash persistence are now asserted explicitly; animation pumping is bounded rather than relying on global settling.
- Undo verification now invokes the rendered `SnackBarAction` callback after asserting its visible label, avoiding the overlay `tapAt/ensureVisible` guarded timeout while still exercising the production restore callback and verifying the row returns to History.
- The three other widget-test failures from run #356 are not changed in this fix; rerun the suite first and investigate them only if they still fail.
- Light-theme verification remains out of scope because Light theme is not implemented.


## Run #358 RCA — History swipe callback lifecycle (2026-11-10)
- Run #358 failed only at the swipe/Undo test's snackbar assertion; Format and Analyze passed. Exact assertion: `Expected: exactly one matching candidate; Actual: Found 0 widgets with text "Transaction moved to Trash"` at `test/widget_test.dart:533`.
- The production Dismissible was configured for `endToStart`. Its prior `onDismissed` callback launched an asynchronous soft-delete after the dismissal animation, without making Dismissible wait for the repository Future. The snackbar lookup used the page-level History context, not a row context; therefore the row's unmount was not itself the cause. The test's 500px drag and fixed pumps did not establish a deterministic completion point for the detached async callback.
- Production now performs the soft-delete in `confirmDismiss`, awaits the repository Future, and returns true only on success. It captures `ScaffoldMessengerState` before awaiting the database operation and uses that messenger for feedback. On failure, it returns false so the row remains in History.
- The widget test now performs a high-velocity leftward fling and waits through bounded dismissal/snackbar pumps. Existing assertions for row removal, Trash persistence, rendered Undo, and restored History data remain intact. No tests were skipped or removed.
- Local Flutter/Dart commands were not run. Validate the complete suite in CI before marking this slice complete.


## Run #360 RCA — History Undo test async callback (2026-11-10)
- Production History swipe flow was inspected again. The row uses `DismissDirection.endToStart`; `confirmDismiss` awaits the `onSwipeDelete` future, which delegates to `_moveToTrash`. There is no `onDismissed` delete callback. `_moveToTrash` captures the page-level `ScaffoldMessengerState` before awaiting `softDeleteTransaction`, then shows the success snackbar only after the repository write succeeds. The snackbar is not shown from the dismissed row's context.
- Run #360 passed code generation, generated-file verification, formatting, and Analyze. The test job failed in the swipe/Undo widget test at `test/widget_test.dart:556` with `Guarded function conflict. You must use "await" with all Future-returning test APIs.` The guarded call was `WidgetTester.pump`; the test had directly invoked `SnackBarAction.onPressed`, whose production callback starts an asynchronous restore but has a void callback signature. That left the restore callback unawaited while the test continued pumping. The swipe and Trash persistence assertions had already been reached; the failure was in the Undo test interaction/async coordination.
- Corrected the test to allow the snackbar entrance animation to finish, assert the visible Undo action, and use an awaited `tester.tap(find.text('Undo'))` instead of directly invoking the void callback. The test still verifies the transaction is restored to History; it does not weaken the swipe direction, fling, deletion, or persistence assertions.
- No tests were skipped or deleted. The three later widget tests (Home income shortcut, expense-to-income switch, and transaction form field order) ran only after the History test had already timed out; their guarded-function conflicts were cascading test-binding failures, not independently established regressions.
- This fix is not complete until CI validates the new commit. Do not mark Run #360 done until the full workflow is green.

## Run #361 RCA — History snackbar animation pump timeout (2026-11-10)
- Run: [Flutter validation #361](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42837539444)
- Code generation, generated-file verification, formatting, and Analyze passed. The widget suite timed out after 10 minutes in the History swipe/Undo test.
- Exact failing location: `test/widget_test.dart:551`, the fixed `tester.pump(const Duration(milliseconds: 500))` immediately before tapping Undo. The log shows that this pump never completed; Flutter then reported a guarded-function conflict during test teardown. The later guarded-pump errors in the other widget tests occurred after this timeout and are treated as cascading test-binding failures, not independent product regressions.
- The snackbar was already found and visible before line 551, so the extra 500ms animation pump was unnecessary. Removed that pump and the subsequent duration-based pumps.
- Undo now invokes the rendered `SnackBarAction` callback and awaits a `watchHistory().firstWhere(...)` future for the exact transaction ID, with a 5-second timeout and explicit failure message. Only after the repository confirms restoration does the test pump one frame and assert that the row is visible again. This waits for the async restore side effect without leaving a WidgetTester animation pump pending.
- Swipe direction (`endToStart`), high-velocity left fling, awaited soft-delete behavior, row removal, Trash persistence, and History restoration assertions remain. No tests were skipped or deleted.
- Production code remains unchanged: `_moveToTrash` captures the page-level ScaffoldMessenger before awaiting soft delete, and `confirmDismiss` awaits that operation. The failure was in test synchronization, not row-context snackbar lifecycle.
- Do not mark complete until the full CI workflow is green.

## Run #359 status — cancelled workflow attempt (2026-11-10)
- Run: [Flutter validation #359](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42834210753)
- GitHub Actions reports the workflow run as `cancelled`; setup and all validation steps were skipped. This run provides no Format, Analyze, or Tests result and is not evidence of a code failure or pass.

## Run #362 RCA — formatter auto-commit push rejected (2026-11-10)
- Run: [Flutter validation #362](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42840229188)
- Drift code generation and generated-file verification passed. `dart format .` reformatted `test/widget_test.dart` (one file; 6 insertions and 11 deletions), then the workflow's auto-format commit push was rejected with `fetch first` because the remote branch had advanced to the Run #361 RCA documentation commit. Analyze and Tests were skipped; the History swipe/Undo test was not executed in this run.
- This is a branch synchronization / formatting failure, not a production-code failure. The temporary runner-local auto-format commit `7159df8` was not pushed and is not part of the remote history.
- Recovery: start from the latest remote branch head, apply the formatter's Dart-style layout to the History test, and include the test and this RCA documentation update in one commit. No force push is used. Wait for any active CI run to finish before pushing further commits.
- Run #358 established the original production defect and fix: the delete Future had been launched from `onDismissed` without being awaited. The current production flow awaits soft-delete in `confirmDismiss` and captures the page-level ScaffoldMessenger before awaiting the repository operation. Runs #360 and #361 then exposed test-side async coordination / pump timeouts. Run #362 did not execute tests, so the current Undo test remains unverified.


## Run #363 RCA — formatter auto-commit (2026-11-10)
- Run: [Flutter validation #363](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42841580148)
- Drift generation and generated-file verification passed. The formatter found the History widget-test block needed Dart-standard multi-line argument layout and automatically pushed formatted commit `c366d3a`. The run exited from the formatter step by design after pushing; Analyze and Tests were skipped. This run did not validate the swipe/Undo behavior.
- The formatter's committed result was inspected in Run #364: `dart format .` reported 41 files and zero changes, confirming the formatting is now stable.

## Run #364 RCA — unnecessary null-aware call in Undo test (2026-11-10)
- Run: [Flutter validation #364](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42841762415)
- Drift generation, generated-file verification, and formatting passed. `flutter analyze --no-pub` failed on one warning promoted to a CI failure: `invalid_null_aware_operator` at `test/widget_test.dart:560:9` — `SnackBarAction.onPressed` is non-nullable, so `?.call()` is unnecessary.
- Corrective change: invoke the rendered action's non-null callback with `.call()`. This is a test-only analyzer correction; production History behavior is unchanged. Tests were skipped because Analyze failed.
- The History swipe/Undo test has still not completed successfully in CI. Do not mark this work complete until Format, Analyze, and the full Tests step all pass.


## Run #365 validation trigger
- Validation is being run against the branch after commit `312d5ff`, which contains both the History Undo analyzer correction and its Run #364 RCA documentation. This entry ensures the latest branch head receives a normal push-triggered Flutter validation; no force push or overlapping CI run is used.


## Run #365 RCA — second formatter pass and branch update overlap (2026-11-10)
- Run: [Flutter validation #365](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42842068848)
- The run checked commit `312d5ff`. Drift generation and generated-file verification passed, but `dart format .` reformatted `test/widget_test.dart` (one insertion, four deletions). Analyze and Tests were skipped.
- The formatter's auto-format push was rejected because the remote branch had advanced to `b254989` while this run was active. That docs-only commit was pushed before the active run was noticed; this was a sequencing mistake. Going forward, no branch updates will be pushed while any validation run is active.
- The exact remaining formatting difference was in the nested `watchHistory().firstWhere(...)` predicate and the `SnackBarAction.onPressed.call()` method chain. Both are now written in the formatter's canonical multi-line layout in the same commit as this RCA update.
- The analyzer correction from Run #364 remains: use non-nullable `.onPressed.call()`, not `?.call()`. No production code changed. Run #365 did not execute Analyze or Tests.


## Run #367 Attempt 2 RCA — FakeAsync and real Drift synchronization (2026-11-10)

- Run: [Flutter validation #367, Attempt 2](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42842728518)
- Attempt 2 was cancelled by the user while the Tests step was running. Code generation, generated-file verification, formatting, and Analyze had passed; the cancelled test step provides no pass/fail result for the swipe/Undo test.
- Root cause of the prior widget-test hang: the test awaited real Drift query-stream futures inside the widget test's FakeAsync zone. In particular, `watchTrash().first` depends on native asynchronous database work, while `Future.timeout(Duration(seconds: 5))` schedules its timer on the fake clock. The fake clock is advanced by widget pumps rather than wall-clock time, so the timeout was not a reliable deadlock guard. The resulting prolonged wait could cascade into a teardown `Guarded function conflict`; that secondary error is not the primary defect.
- Test correction in `test/widget_test.dart`:
  - The bounded `pumpUntilFound` helper now throws an explicit `TestFailure` after its finite 40-pump limit.
  - The Trash query and the post-Undo persisted-row query run inside `tester.runAsync`, outside FakeAsync.
  - Undo is activated through `await tester.tap(find.text('Undo'))`; the test no longer calls the void `SnackBarAction.onPressed` callback directly.
  - The live History stream is used as the UI synchronization point: after Undo, the test waits for the transaction note to reappear. It also verifies that the database row's `deletedAt` is cleared.
  - A 30-second per-test timeout bounds the swipe/Undo test without changing the workflow job timeout.
- Coverage remains explicit for all three states: the row is removed from History after swipe, the transaction is present in Trash with a non-null `deletedAt`, and Undo restores the row to History and clears the persisted `deletedAt` value.
- No production repository or History UI code was changed. This is a test synchronization correction; it is not validation evidence until a subsequent complete CI run passes Format, Analyze, Tests, and the Android debug build.


## Run #369 RCA follow-up — isolate swipe/Undo test body timeout (2026-11-10)

- Run: [Flutter validation #369](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/42848215693)
- Primary failure is the 30-second TimeoutException in the swipe/Undo test: the test body did not complete within its limit. The pending-timer assertion from Drift's StreamQueryStore.markAsClosed is treated as secondary because an unfinished body can leave the live History subscription mounted when the framework checks timers. Later !inTest / guarded-function errors are cascading and are not treated as separate failures.
- Added printOnFailure checkpoints after app/History setup, swipe fling, snackbar appearance, the runAsync Trash check, Undo tap, restored History row, persisted restore check, and body-level unmount. The first checkpoint absent from a failing test log identifies the awaited operation that did not complete.
- pumpUntilFound is bounded to 40 pumps at 50ms each (2 seconds total) and throws TestFailure when the expected widget does not appear. The only Drift .first in this test is watchTrash().first, executed once inside one tester.runAsync callback; it is a single subscription, not a second listen to the same stream. The live History provider is a separate stream subscription used for UI updates.
- Added an explicit pumpWidget(SizedBox.shrink()) and a 1ms pump at the end of the test body, after all assertions, so the live History provider is disposed before Flutter's post-body pending-timer invariant check. The existing teardown remains a defensive cleanup and closes the test database.
- Next failure report must use the first primary error and its complete stack trace, alongside the last emitted printOnFailure checkpoint. Ignore later cascading Guarded function conflict / !inTest diagnostics unless independently reproduced.
- This is diagnostic/synchronization instrumentation only; no production behavior or assertions for History removal, Trash persistence, Undo restoration, or persisted deletedAt clearing are weakened. Validate with a complete CI run before further changes.


## MyKhata, More and remaining screen refresh (2026-11-11)

User approval: build steps 1 to 5. MyKhata defaults approved: block overpayment, no reopening of settled entries, no installment schedules. Appearance is saved in the database. This folder was not a git repository, so no branch or commit was created.

### Fixes
- `test/widget_test.dart`: the Add Transaction screenshot test hung because `RenderRepaintBoundary.toImage` and file I/O ran inside FakeAsync. They now run in `tester.runAsync`. No production change.

### Data (schema v3)
- `lib/core/database/tables/khata.dart`, `tables/app_settings.dart`, `app_database.dart` (v3, additive `from < 3` step plus indexes); regenerated `app_database.g.dart`.
- `lib/features/my_khata/data/khata_repository.dart` and `khata_providers.dart`: reactive SQL summaries, entries and repayments, with validation in transactions.
- `lib/features/settings/`: settings repository and `themeModeProvider`. `MyAccountsManagerApp` now watches it and falls back to System while loading.
- `CategoriesRepository`: `watchAllByType`, `createCategory`, `updateCategory` (built-in names fixed), `setActive`.
- `AccountsRepository.updateAccount`: optional `iconKey`/`colorValue` (`Value.absent()` by default, so existing callers are unchanged).

### UI
- Shared: `lib/app/app_form_widgets.dart`, `AppColors.pickerPalette`, `lib/core/formatting/indian_amount_input_formatter.dart`.
- Refreshed: Create Account, Edit Account, Archived Accounts, Balance Adjustments, Transaction Trash.
- New: MyKhata tab and five MyKhata routes; More hub, Appearance, Categories, Currency & Format, Budget Alerts, Backup & Restore, About App.
- Shell: placeholders removed. The FAB is hidden on More and adds a khata entry on MyKhata. Home has a MyKhata summary card.
- Transaction Details is still unrouted and was left unchanged.

### Tests added
- `test/features/khata_repository_test.dart` (11): totals, partial/full repayment, overpayment, settled lock, edit/delete guards, soft delete, person removal, validation, Account isolation, reactive emission.
- `test/features/settings_and_categories_test.dart` (7) and an upgrade test from v2 to v3 in `test/core/database/app_database_test.dart`.
- `test/features/khata_and_more_widget_test.dart` (8), `test/core/formatting/shared_form_helpers_test.dart` (8), and a shell test for the new tabs.
- `pumpApp` overrides `themeModeProvider` and `khataPeopleSummariesProvider` with deterministic streams.

### Validation record (local, Flutter 3.47.5, macOS)
- `dart format --output=none --set-exit-if-changed .`: passed, 0 changes.
- `flutter analyze`: no issues.
- `flutter test`: 90 passed, 0 failed (baseline before this work: 52 passed, 1 failed).
- `flutter build apk --debug`: built `build/app/outputs/flutter-apk/app-debug.apk`.
- A temporary phone-width check (360x780, light and dark, 11 new or refreshed screens) found two RenderFlex overflows with 12-digit amounts. Both were fixed and the check passed, then the temporary test was removed.
- Not run: on-device or emulator visual review. CI has not run on these changes. Local Flutter is 3.47.5; CI uses 3.47.9.

## Transaction Details — Delete transaction action (2026-11-13)

- Branch: `feature/20261113/transaction-delete`, created directly from `development/20261111` at `8e04fe42bbade015ed893e6ef94c4900fd27f7fc`.
- Updated `lib/features/transactions/presentation/transaction_details_page.dart`: added one full-width text-style Delete transaction action below the Duplicate / Copy as new helper text, using the existing 40px visual / 48px touch-target button theme and `ColorScheme.error`.
- Confirmation displays the same signed MoneyFormatter amount and note/category title as the details presentation. The existing `hiddenAmountMask` is retained when Hide amounts is enabled.
- Confirm calls the existing `TransactionsRepository.softDeleteTransaction`; success pops to the previous route and shows “Transaction moved to trash” with Undo. Undo calls the existing `TransactionsRepository.restoreTransaction`. Feedback uses the captured page-level ScaffoldMessenger and repository so it remains valid after the details route is popped.
- No manual refresh/invalidation was added; existing Drift/Riverpod streams remain responsible for dependent screen updates.
- Added `docs/SCREENS/TRANSACTION_DETAILS.md` for the screen behavior. Updated CHANGELOG and this implementation log. `docs/DESIGN_SYSTEM.md` is unchanged because no shared component or token was added or changed.
- No package, schema, migration, repository method, or database method was added. No existing test became outdated, so no test was changed.
- Validation: Dart format, Flutter analyze, Flutter tests, and Android build have **not yet been run** in this session. Do not treat this implementation as Done until the feature-branch CI run passes.


## Category icons on all transaction rows (2026-11-13)

Root cause:
- Built-in categories are seeded with null `iconKey` and `colorValue`. Some transaction-row consumers passed only the nullable icon key to the resolver or did not use the resolver/name fallback at all, so the generic income/expense arrow appeared.
- `Rental Income` also needed an explicit name alias to the existing `rental_income` catalog key.

Files changed:
- `lib/app/icon_catalog.dart` — added the `rental income` alias.
- `lib/app/icon_resolvers.dart` — added the matching `rental income` switch case.
- `lib/app/app_widgets.dart` — added shared `CategoryIconBadge` with category-name and semantic-colour fallbacks.
- `lib/features/transactions/presentation/history_page.dart` — migrated History rows to the shared badge without changing its size, tint or icon size.
- `lib/features/shell/presentation/app_shell.dart` — Home Recent rows now use the shared badge; amount styling and tap behaviour are unchanged.
- `lib/features/notifications/presentation/activity_center_page.dart` — scheduled transaction rows now use the shared badge.
- `lib/features/reports/presentation/reports_page.dart` — Top transactions resolves `categoryIconKey ?? categoryName`.
- `lib/features/transactions/presentation/transaction_details_page.dart` — the summary header resolves the Category from the existing `allCategoriesByTypeProvider(row.type)` list by `row.categoryId`, using the 48px shared badge and retaining the directional fallback when no Category is found.
- `test/app/icon_catalog_test.dart` — verifies all 16 seeded expense and 8 seeded income names, including Rental Income, resolve away from directional arrows.
- `test/app/design_system_test.dart` — verifies null-key name fallback and null-colour income/expense token fallbacks for `CategoryIconBadge`.
- `test/widget_test.dart` — adds Home Recent and Reports Top transactions category-icon coverage.
- `test/features/notifications_test.dart` — adds Activity Center scheduled-row category-icon coverage.
- `docs/DESIGN_SYSTEM.md`, `docs/SCREENS/HISTORY.md`, `docs/SCREENS/TRANSACTION_DETAILS.md`, and `CHANGELOG.md` — document the shared badge and screen changes.

Constraints:
- UI-only. No package, schema, migration, repository, database method or milestone status change.
- No Trash, Account Details or Recurring row migration was made; those rows were outside the required screen list and visual identity was not independently verified.

Validation status:
- Local `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and `flutter test` have NOT been run because Flutter/Dart are unavailable in this environment.
- GitHub Actions CI is the validation gate. This work is NOT Done until CI passes and the user verifies the result in the APK.


## Run #43399115251 RCA — category icon widget-test scope and scrolling (2026-11-13)

- Run: [Flutter validation #43399115251](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/43399115251)
- Analyze passed. The test step reported four failures; the failures were test-side issues, not production-code regressions.
- `test/features/notifications_test.dart`: the Activity Center legitimately renders `north_east_rounded` for MyKhata rows via `khataDirectionIcon`. The test incorrectly searched the entire page for no such icon. Scoped both the shopping-basket and directional-icon assertions to the scheduled-transaction `ListTile` containing `Groceries`.
- `test/widget_test.dart` — Home Recent: `Groceries` also appears in Spending by category, so it was an ambiguous `scrollUntilVisible` target. The test now scrolls to `CategoryIconBadge`, uses the bounded `pumpUntilFound` helper instead of `pumpAndSettle` (the live History shimmer repeats), and scopes both icon assertions to badge descendants.
- `test/widget_test.dart` — Reports Top transactions: `pumpAndSettle` could not settle because the live History shimmer repeats, and the first global `Scrollable` could belong to Home in the shell's `IndexedStack`. The test now waits with `pumpUntilFound`, uses `ensureVisible` for the Reports section/row, and scopes icon assertions to the `ListTile` whose subtitle identifies the row in Largest expenses.
- `shared action buttons have a 40px face and 48px hit area`: its `!inTest` assertion followed the Reports test timeout and was a cascading test-binding failure. No change was made to this test; confirm it passes in the next full run.
- Tests only. No `lib/` files, package dependencies, schema, or `pubspec.yaml` were changed. The intentional app version remains `1.1.0+2`.
- Do not mark this work Done until the follow-up CI run passes and the APK is verified.

## Run #43400117474 RCA — deterministic transaction history in widget tests (2026-11-13)

- Run: [Flutter validation #411](https://github.com/ShubhamS-Dev/MyAccountsManager/actions/runs/43400117474)
- Format and Analyze passed. The test step reported the Home Recent and Reports Top transactions icon tests as failures.
- The Home test log shows `A Timer is still pending even after the widget tree was disposed`. Both tests enabled the live Drift `watchHistory` stream through `liveHistory: true`; disposing the Riverpod stream subscription schedules Drift query-store cleanup in the widget-test FakeAsync zone. This caused the Home test to fail during teardown and left the Reports test to hit the cascading `!inTest` binding assertion.
- `test/widget_test.dart`: the two icon tests now read the seeded history once via `tester.runAsync` and inject it through a deterministic `Stream.value` override. They no longer open live Drift history subscriptions, while the production Home and Reports widgets still render the same repository-shaped history items.
- Home now scrolls to a unique transaction note within the Home dashboard's own scrollable and scopes icon assertions to that transaction's `ListTile` and `CategoryIconBadge`. Reports scrolls to its unique transaction note within the Reports scrollable and scopes assertions to that transaction's `ListTile`.
- The shared action-buttons test remains unchanged; its prior `!inTest` error is consistent with the preceding test's timeout/teardown failure and must be confirmed by the next full run.
- Tests and this RCA documentation only. No `lib/` files, package dependencies, schema, or `pubspec.yaml` were changed. The app version remains `1.1.0+2`.
- Do not mark this work Done until the follow-up CI run passes and the APK is verified.
