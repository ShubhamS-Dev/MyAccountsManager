# Project Milestones — MyAccountsManager

This file is the project progress tracker. Update it whenever a milestone changes, and keep every status aligned with work that is actually present in the repository and verified.

**Status definitions**
- **Not Started** — work has not begun.
- **In Progress** — work is actively underway; acceptance criteria are not all met.
- **Blocked** — work cannot proceed until a dependency or decision is resolved.
- **Done** — acceptance criteria are met and the relevant checks have actually passed.

> Do not mark a milestone Done because only a GitHub Actions YAML file changed, a commit was created, or a build workflow ran. Application milestones require the corresponding source-code implementation.

## Current project status

- Overall status: **In Progress — requirements and implementation planning**
- Application source implementation: **In Progress — project foundation and initial local database source**
- Android native scaffold and debug APK: **In Progress** — CI now generates the missing Android platform folder, verifies the confirmed application ID, builds a debug APK, and uploads it as a workflow artifact; execution is pending.
- Current baseline commit: see repository history.

## Branching workflow

- Production/release: `master`.
- Daily development integration: `development/YYYYMMDD`.
- Feature/task work: `feature/YYYYMMDD/<short-description>`.
- Create the development branch from the latest `master`; create feature branches from the active development branch.
- Merge feature branches into the matching development branch through review/validation. Merge development into `master` only for an explicitly approved release.
- Never implement features directly on `master`; never treat YAML-only changes as application implementation.

Current branches created for the initial foundation work:

- `development/20261108`
- `feature/20261108/project-foundation`

## Milestone tracker

| ID | Milestone | Status | Completion evidence / acceptance criteria |
|---|---|---|---|
| M0 | Repository and project instructions | Done | README, agent instructions, and this milestone tracker are committed and consistent. |
| M1 | Product requirements finalization | In Progress | PRD covers all approved modules, workflows, edge cases, and open decisions. Material ambiguities are resolved with the user. |
| M2 | Technical architecture and data design | In Progress | Architecture, feature boundaries, database entities/relations, migration strategy, security design, and backup format are documented and reviewed. |
| M3 | Flutter project foundation | In Progress | Real Flutter/Dart source project exists; app launches; approved dependencies, routing, Riverpod setup, theme, and feature structure are in place. |
| M4 | Local database and integrity foundation | In Progress | Version 1 schema and migration policy are documented in docs/DATABASE_SCHEMA_V1.md. Drift table definitions, database connection, version-1 creation/seed logic, repository classes, Riverpod providers, and initial database/repository tests have been added. Generated code and all checks remain unverified until the Flutter workflow completes. |
| M5 | Accounts, categories, and transactions | In Progress | Account management, categories, income/expense, adjustments, future-dated records, history, attachments, and Trash meet approved requirements. |
| M6 | Dashboards and budgets | Not Started | Global and Account dashboards, date filters, configurable sections, budgets, and alerts work as specified. |
| M7 | Recurring transactions and notifications | Not Started | Automatic and reminder-based recurrence, catch-up/idempotency, notification center, preferences, and Quiet Hours are implemented and tested. |
| M8 | Savings Goals | Not Started | Goal lifecycle, contributions/withdrawals, transaction linking, history, dashboard widget, and reminders meet approved requirements. |
| M9 | MyKhata | Not Started | Person profiles, independent lending/borrowing ledgers, installments, repayments, allocation, settlement, audit history, attachments, and reports are implemented and tested. |
| M10 | Reports and exports | Not Started | Regular finance and MyKhata reports, PDF preview/export, and filtered CSV export work as specified. |
| M11 | Backup, restore, and storage management | Not Started | Encrypted versioned `.khata` archives, password handling, validation, Replace/Merge, conflict resolution, recovery snapshots, retention, and storage review are implemented and tested. |
| M12 | UX polish, accessibility, and resilience | Not Started | Onboarding, loading/error/recovery states, empty states, navigation, responsive layouts, accessibility, and performance are reviewed. |
| M13 | Quality assurance and release readiness | Not Started | Formatting, static analysis, automated tests, migration/backup tests, Android build, permissions, and release checks pass; limitations are documented. |
| M14 | Android distribution | Not Started | User-approved distribution method and signing configuration are in place; release artifact is generated and verified. |

## Confirmed decisions

- Money is displayed as rupees: whole values without unnecessary decimals (e.g. `₹500`) and fractional values with two decimal places (e.g. `₹500.50`).
- Date fields use timestamp storage; the UI displays date-only values (Option A). Date-only business dates are UTC-normalized calendar dates, while audit timestamps represent actual UTC instants.
- Database and domain calculations use integer paise (₹500 = `50000`, ₹500.50 = `50050`); binary floating-point is not used for stored money.

## Latest implementation update — 2026-11-08

- Confirmed Android application ID: `com.shubhams.myaccountsmanager`.
- Created Flutter/Dart source foundation on `feature/20261108/project-foundation`.
- Added `pubspec.yaml` with Flutter, Riverpod, go_router, and Flutter test/lint baselines.
- Added `lib/main.dart`, app theme host, GoRouter configuration, five-destination navigation shell, initial Home placeholder, and Expense/Income entry-form scaffold.
- Added Dart static-analysis configuration.
- Added initial widget tests for app launch, navigation shell, FAB route, and Expense/Income selection.
- Added draft `docs/ARCHITECTURE.md` documenting approved boundaries, dependency direction, data principles, security design work, and open decisions.
- Added a shared `MoneyFormatter` utility for integer-paise parsing and Indian rupee display, plus unit tests covering whole/fractional values, grouping, and invalid input. These tests are committed; local execution is unavailable.
- Added Drift/SQLite dependencies, version-1 table definitions for Accounts, Categories, and Transactions, a local database connection, schema creation, initial category seeding, and supporting indexes.
- Added account/category/transaction repositories and Riverpod providers, plus in-memory database and repository tests.
- Added integer-paise Account balance calculation using opening balance plus effective income minus effective expenses; deleted and future-dated transactions are excluded based on a supplied UTC calendar date. Added tests for these rules, but execution remains unverified.
- Connected the Accounts navigation destination to a Drift-backed active Account list with loading, error/retry, and empty states.
- Added Account creation UI with required name, optional description, and signed opening balance input parsed directly into integer paise. Account rows persist through the repository and appear through the Riverpod stream.
- Changed the app default to Light mode, retaining the existing Dark theme definition.
- Added a Flutter GitHub Actions validation workflow to generate Drift source, format, analyze, and run tests. The workflow has not yet been verified as successful.
- Documented the initial SQLite/Drift schema and migration policy in `docs/DATABASE_SCHEMA_V1.md`, covering Accounts, Categories, and regular Transactions, including fields, indexes, integrity rules, seed behavior, and deferred feature tables.
- Confirmed timestamp storage with date-only UI display. Architecture distinguishes UTC-normalized calendar-date timestamps from actual UTC audit/event timestamps.
- Added `DateOnly` and `AuditTimestamp` utilities with tests for UTC-midnight date storage, date-only formatting, and UTC audit instants. Tests are committed but not yet executed.
- Added Account edit UI for name/description, repository update and lookup methods, pin/unpin actions, and confirmed archive action that preserves financial history. Opening balance is intentionally not exposed in edit UI. A formal balance-adjustment feature is not yet implemented, so the opening-balance lock rule still needs enforcement when that feature is added.
- Added an Archived Accounts screen with restore action, archived/active Riverpod streams, and restore repository operation. Added per-Account balance display based on opening balance plus effective transactions through the current UTC calendar date. Expense/Income transaction entry and filtered transaction history are now connected to SQLite. Permanent Account deletion, adjustment editing/Trash, attachments, custom ordering, and Account-specific dashboard remain pending. Balance adjustments now have a dedicated schema-v2 table, signed paise values, required reason, date-aware balance calculation, entry UI, and history. Transaction editing now supports amount, type, Category, Account, date, and note updates with validation and balance refresh. Transaction soft-delete, restore, and confirmed permanent deletion from Trash are implemented; Flutter validation remains unverified.
- Android native platform scaffolding and package identifier wiring remain pending; it must be generated/configured and built before this milestone can be marked Done.
- Flutter formatting, analysis, tests, and Android build have **not** been run in this environment. No successful build is claimed.

## Root-cause repair update — 2026-11-08

The previous control-flow lint cleanup introduced invalid Dart by appending empty blocks after statements and inserting a block between `ScaffoldMessenger.of(context)` and `.showSnackBar`. This was traced through the diffs of commits `29cc58a`, `47d9d6a`, `e2144a3`, `728a415`, `9d8be32`, `5a7057d`, `bfb2a1c`, `ac582fe`, and `29369f1`. The malformed syntax has been removed from the affected source files. Future lint cleanup must add braces around the complete intended statement body; it must never append braces after an already-complete statement.

## Open decisions / blockers

Track unresolved decisions here. Do not silently decide them in code.

- Exact cryptographic implementation and parameters for backup encryption/password derivation require a security-reviewed design.
- Remaining recurrence edge cases and editing semantics must be finalized before implementing recurrence.
- Remaining MyKhata overpayment and settled-ledger reopening semantics must be finalized before implementing those flows.
- Savings Goal transaction-linking treatment in regular budgets/reports must be confirmed before implementation.
- Budget period and total-budget semantics must be finalized before implementation.
- Deployment branch policy, signing, and distribution details must be explicitly approved before configuring release automation.

Remove an item only after the decision is recorded in the approved requirements or architecture documentation.

## Update log

| Date | Update |
|---|---|
| 2026-11-08 | Added project-level agent instructions and milestone tracker. No Flutter application source implementation is claimed by this documentation change. |
| 2026-11-08 | Added decimal-safe integer-paise money parsing/formatting utility and unit tests on `feature/20261108/project-foundation`; execution remains pending Flutter toolchain availability. |
| 2026-11-08 | Recorded timestamp storage with date-only UI presentation and explicit UTC semantics for business dates versus audit timestamps. |
| 2026-11-08 | Added date-only and audit timestamp utilities plus unit tests; Flutter test execution remains pending toolchain availability. |
| 2026-11-08 | Documented initial SQLite/Drift schema version 1 and migration strategy; Drift source definitions and validation remain pending. |
| 2026-11-08 | Added Drift dependencies, initial tables/database/seed, repositories/providers, persistence tests, and a CI workflow for code generation and validation. Generated code and workflow results remain unverified. |

## Change log format

When updating this file, record:
- Date
- Milestone ID(s)
- Status before and after
- Evidence: source files, tests, build output, or approved decision/document

Keep this tracker concise and evidence-based.

| 2026-11-08 | Added date-aware Account balance calculation and repository tests for future/deleted transaction exclusion. Generated Drift source is present on the feature branch; Flutter validation results remain unverified. |

| 2026-11-08 | M5 started: connected Accounts navigation to the local database, implemented active Account list and Account creation form with integer-paise opening balance parsing; set Light mode as default. Formatting, analysis, tests, and device build remain unverified. |
\n| 2026-11-08 | M5: added Account edit form, pin/unpin, archive confirmation and repository operations; added repository tests for edit/pin behavior. Permanent deletion and balance-adjustment-aware opening-balance lock remain pending. Checks are not yet executed. |\n\n| 2026-11-08 | M5: added archived Account listing and restore, active/archived streams, and current-date Account balance display. Added repository restore test. Flutter validation and Android build remain unverified. |\n\n| 2026-11-08 | M5: connected Expense/Income entry UI to SQLite repository with Account/category selection, date-only UTC storage, decimal-safe integer-paise parsing, optional note, validation, and Account balance invalidation after save. No runtime or CI validation is claimed. |\n
| 2026-11-08 | M5: added joined transaction history query and History navigation screen with active/archived Account filter, Expense/Income filter, inclusive date-range filter, and newest-first ordering. Added repository test for joins and filters. Flutter validation remains unverified. |

| 2026-11-08 | M5: added transaction soft-delete, Trash listing, restore, and confirmation-gated permanent deletion. History now exposes Move to Trash and a Trash entry point; repository lifecycle tests were added. Flutter formatting, analysis, tests, and Android build remain unverified. |

| 2026-11-08 | M5: added transaction editing from History, typed transaction lookup, validated repository updates, Account reassignment, archived-Account safeguards, and tests for edits and invalid states. Flutter formatting, analysis, tests, and Android build remain unverified. |

| 2026-11-08 | M5/M4: introduced schema version 2 with a non-destructive balance-adjustment migration; added signed adjustment storage, reason and date validation, date-aware balance calculations, Account-level adjustment entry/history UI, and repository/database tests. Drift code generation, formatting, analysis, tests, and Android build are not yet verified. |
| 2026-11-08 | M5: removed an accidentally duplicated trailing fragment from the Add Transaction screen that caused Dart parser errors. CI formatting, analysis, and tests must still pass before validation is considered complete. |
| 2026-11-08 | M5: fixed static-analysis findings in transaction editing, Trash list layout, and Drift/Matcher test imports. Validation is running again; test results remain pending. |

| 2026-11-08 | M5/M13: traced formatter failures to nine earlier commits that incorrectly appended empty `{ ; }` blocks or malformed `ScaffoldMessenger` member access while attempting to fix curly-brace lint. Restored the original valid statements across transaction, Account, adjustment, and money-formatting source files. Root cause identified as an unsafe source-editing transformation, not Flutter tooling. Formatting, analysis, tests, and Android build must be rerun before validation is claimed. |


## CI root-cause analysis — 2026-11-08

Run #144 completed dependency resolution, Drift generation, Dart formatting, and the generated/formatted-source commit. It failed only at flutter analyze: 24 informational curly_braces_in_flow_control_structures findings caused analyzer exit code 1; tests were skipped. The syntax repairs therefore restored parseability but did not clear the analyzer gate.

Root cause: (1) 24 unbraced control-flow statements remained across money formatting, Account/adjustment screens, transaction repository, and transaction screens. (2) analysis_options.yaml includes package:flutter_lints/flutter.yaml, which enables this rule; the current CI analyzer command fails on info-level findings. (3) The previous cleanup used unsafe text-level brace insertion rather than wrapping each complete statement body, causing semicolon loss, extra braces, and malformed chained ScaffoldMessenger calls. (4) CI formatting and code generation succeeded in run #144 and were not the cause of that run's failure.

Corrective approach: explicitly wrap each complete intended statement body, preserve expression chains and semicolons, and keep dart fix --apply and blind brace insertion out of the workflow. All analyzer-reported sites have now been edited with complete blocks. Validation remains pending the next CI run.


## Android build pipeline update — 2026-11-08

- Updated the Flutter validation workflow to generate the missing Android platform scaffold only when absent, using the confirmed application ID `com.shubhams.myaccountsmanager`.
- The workflow now builds a debug APK after formatting, analysis, and all tests pass, then uploads `app-debug.apk` as the `myaccountsmanager-debug-apk` artifact for 14 days.
- The generated `android/` folder is committed only after the full validation and APK build succeed. No APK or Android scaffold completion is claimed until that run passes.


## Gradle download failure RCA and mitigation — 2026-11-08

- Run #187 passed Android scaffold generation, dependency resolution, Drift generation, Dart formatting, static analysis, and all 28 automated tests.
- APK assembly failed before compilation because the Gradle wrapper could not download Gradle 9.3.1 from the Gradle GitHub release endpoint; the endpoint returned HTTP 504. APK upload and generated Android scaffold commit were consequently skipped.
- Root cause is a transient external distribution-download gateway timeout. The run contains no evidence of an application source, Android manifest, or Gradle build-script compilation defect.
- Updated CI to cache Gradle wrapper distributions and dependency caches using the wrapper properties as the cache key. Added up to three bounded APK build attempts, with increasing delays, only when logs indicate transient HTTP 5xx/network failures. Non-network build failures fail immediately and are not masked.
- The mitigation is committed; it is not yet verified. A subsequent successful APK build is required before marking Android scaffold/APK milestone complete.


## Android Gradle distribution endpoint repair — 2026-11-08

- Run #190 passed Android scaffold generation, dependency resolution, Drift code generation, formatting, static analysis, and all 28 tests.
- APK assembly again failed before Android compilation: all three configured attempts received HTTP 504 from the generated wrapper's GitHub release URL for Gradle 9.3.1. The Gradle cache had no prior distribution to restore, so the wrapper had to download it.
- The previous retry-only mitigation was insufficient because the failing endpoint remained unchanged across all attempts.
- Updated the workflow to rewrite the generated Gradle wrapper distribution URL to the Gradle downloads host (downloads.gradle.org) while preserving the generated Gradle version and archive type. Added a 120-second wrapper network timeout. Existing wrapper/dependency caching and bounded retry behavior remain in place.
- This endpoint change is not yet validated. The next successful run must pass Gradle distribution download, Android compilation, APK upload, and generated scaffold commit before Android build completion is claimed.

## UI/UX requirements update — 2026-11-08

The user reviewed the current Android screens and approved cross-app UI/UX requirements. The detailed source of truth is docs/UI_UX_REQUIREMENTS.md; agent.md and docs/ARCHITECTURE.md require future implementation to follow it.

Confirmed requirements recorded (not yet implemented or validated as a complete UI refresh):
- Premium, cohesive visual design with purposeful, smooth, non-blocking animations.
- Compact dropdowns, popup menus, and date-picker dialogs/calendars, while retaining accessible touch targets.
- Add Transaction input order: **Account → Transaction date → Note → Amount → Category/other details**. Expense/Income type selection may remain as a compact selector above the fields.
- Show **Today** when the selected transaction date matches the device's current local calendar date; otherwise show **DD MMM YYYY**, e.g. **08 Nov 2026**. This is display-only; UTC-normalized date-only storage remains unchanged.
- Use Indian digit grouping for displayed amounts (e.g. ₹1,00,000), preserve the existing whole-rupee/two-decimal precision rule, and use consistent semantic colors for positive/income and negative/expense values while retaining explicit signs.
- Ensure Drift/Riverpod reactive updates keep Home, Accounts, History, and other dependent screens synchronized after all relevant mutations. Add propagation tests; manual refresh is not a substitute.

Status: requirements documented; implementation remains pending. M12 remains Not Started until the design system, interaction polish, accessibility, and resilience acceptance criteria are implemented and verified. Reactive refresh and transaction-form/date behavior must also be validated in their respective feature milestones.

| Date | Update |
|---|---|
| 2026-11-08 | Documented approved premium UI/UX, compact control, transaction-form ordering, Today/date display, Indian amount grouping, semantic amount color, and reactive data-refresh requirements in docs/UI_UX_REQUIREMENTS.md; linked the requirements from agent instructions and architecture. Documentation only; no app source behavior changed in this commit. |


## Premium UI/UX implementation sequence — 2026-11-08

Implementation has started on the existing project-foundation feature branch. Work is intentionally sequenced to stabilize financial correctness before visual polish:

1. **Reactive data synchronization:** replace one-shot balance reads with Drift queries watching Accounts, Transactions, and BalanceAdjustments; make Home's combined active-Account balance database-backed; add stream propagation tests.
2. **Financial presentation:** centralize all amount display through MoneyFormatter and apply semantic positive/negative colors consistently across Home, Accounts, History, and future modules.
3. **Transaction entry:** reorder fields to Account → Date → Note → Amount → Category/other details; display Today for the current local calendar date and DD MMM YYYY otherwise; compact dropdown/date-picker controls.
4. **Premium design system:** refine shared theme, typography, spacing, cards, navigation, compact controls, loading/empty/error states, and restrained animations.
5. **Regression and APK validation:** format, analyze, test, build debug APK, and review the installed screens.

Current implementation slice (not yet CI-validated):
- Added reactive Drift SQL streams for individual Account balance and combined active-Account balance, with dependencies declared for all source tables.
- Changed Account balance provider to a StreamProvider and added a reactive Home total-balance provider.
- Replaced Home's hardcoded ₹0.00 with the live combined balance.
- Updated Account balance labels to use shared MoneyFormatter and semantic positive/negative colors.
- Reordered Add Transaction inputs and made Account/Category dropdowns denser with bounded menu height.
- Added Today / DD MMM YYYY transaction-date label behavior.
- Updated History to use the shared currency/date formatters and semantic amount colors.
- Added a repository stream test for a transaction mutation changing the watched Account balance.

The source changes are committed, but the new workflow must pass before this slice is considered validated. Remaining tasks include checking the new Drift SQL at runtime, adding provider/widget propagation coverage, compacting date-picker presentation, polishing shared theme and animations, and applying semantic amount colors to every remaining monetary display.

