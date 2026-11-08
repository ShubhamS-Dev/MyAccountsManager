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
- Android APK/release: **Not Started**
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
- Added an Archived Accounts screen with restore action, archived/active Riverpod streams, and restore repository operation. Added per-Account balance display based on opening balance plus effective transactions through the current UTC calendar date. Expense/Income transaction entry and filtered transaction history are now connected to SQLite. Permanent Account deletion, transaction editing, balance adjustments, attachments, custom ordering, and Account-specific dashboard remain pending. Transaction soft-delete, restore, and confirmed permanent deletion from Trash are implemented; Flutter validation remains unverified.
- Android native platform scaffolding and package identifier wiring remain pending; it must be generated/configured and built before this milestone can be marked Done.
- Flutter formatting, analysis, tests, and Android build have **not** been run in this environment. No successful build is claimed.

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
