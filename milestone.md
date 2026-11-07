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
- Application source implementation: **Not Started**
- Android APK/release: **Not Started**
- Current baseline commit: see repository history.

## Milestone tracker

| ID | Milestone | Status | Completion evidence / acceptance criteria |
|---|---|---|---|
| M0 | Repository and project instructions | In Progress | README, agent instructions, and this milestone tracker are committed and consistent. |
| M1 | Product requirements finalization | In Progress | PRD covers all approved modules, workflows, edge cases, and open decisions. Material ambiguities are resolved with the user. |
| M2 | Technical architecture and data design | Not Started | Architecture, feature boundaries, database entities/relations, migration strategy, security design, and backup format are documented and reviewed. |
| M3 | Flutter project foundation | Not Started | Real Flutter/Dart source project exists; app launches; approved dependencies, routing, Riverpod setup, theme, and feature structure are in place. |
| M4 | Local database and integrity foundation | Not Started | Drift schema, repositories, migrations, UUID strategy, transaction boundaries, and recovery behavior are implemented and tested. |
| M5 | Accounts, categories, and transactions | Not Started | Account management, categories, income/expense, adjustments, future-dated records, history, attachments, and Trash meet approved requirements. |
| M6 | Dashboards and budgets | Not Started | Global and Account dashboards, date filters, configurable sections, budgets, and alerts work as specified. |
| M7 | Recurring transactions and notifications | Not Started | Automatic and reminder-based recurrence, catch-up/idempotency, notification center, preferences, and Quiet Hours are implemented and tested. |
| M8 | Savings Goals | Not Started | Goal lifecycle, contributions/withdrawals, transaction linking, history, dashboard widget, and reminders meet approved requirements. |
| M9 | MyKhata | Not Started | Person profiles, independent lending/borrowing ledgers, installments, repayments, allocation, settlement, audit history, attachments, and reports are implemented and tested. |
| M10 | Reports and exports | Not Started | Regular finance and MyKhata reports, PDF preview/export, and filtered CSV export work as specified. |
| M11 | Backup, restore, and storage management | Not Started | Encrypted versioned `.khata` archives, password handling, validation, Replace/Merge, conflict resolution, recovery snapshots, retention, and storage review are implemented and tested. |
| M12 | UX polish, accessibility, and resilience | Not Started | Onboarding, loading/error/recovery states, empty states, navigation, responsive layouts, accessibility, and performance are reviewed. |
| M13 | Quality assurance and release readiness | Not Started | Formatting, static analysis, automated tests, migration/backup tests, Android build, permissions, and release checks pass; limitations are documented. |
| M14 | Android distribution | Not Started | User-approved distribution method and signing configuration are in place; release artifact is generated and verified. |

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

## Change log format

When updating this file, record:
- Date
- Milestone ID(s)
- Status before and after
- Evidence: source files, tests, build output, or approved decision/document

Keep this tracker concise and evidence-based.
