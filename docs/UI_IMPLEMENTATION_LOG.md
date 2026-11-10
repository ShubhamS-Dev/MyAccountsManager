# UI Implementation Log

This document records actual UI implementation work, decisions, files changed, and validation evidence for the UI refresh branch. A listed screen is not considered complete merely because a route or placeholder exists.

## Branch and baseline

- Repository: `ShubhamS-Dev/MyAccountsManager`
- Working branch: `feature/20261109/ui-refresh`
- Base: `feature/20261108/project-foundation`
- Product/architecture baseline: `README.md`, `agent.md`, `milestone.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE_SCHEMA_V1.md`, and `docs/UI_UX_REQUIREMENTS.md`.
- The user's confirmed screen inventory is recorded in `docs/UI_UX_REQUIREMENTS.md`.
- All standard action buttons are 40 logical pixels high. Screen titles are at most 16px, section headings 14px, amounts 16px, and supporting/label text 11px.
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
