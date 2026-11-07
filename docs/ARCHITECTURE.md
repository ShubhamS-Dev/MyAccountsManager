# Technical Architecture — MyAccountsManager

**Status:** Draft / baseline in progress  
**Android application ID:** `com.shubhams.myaccountsmanager`  
**Flutter package name:** `my_accounts_manager`

This document records the approved technical baseline and separates confirmed decisions from details that still require design review. It is not permission to silently resolve open product decisions.

## 1. Product constraints
- Offline-first Android application; financial data remains local to the device.
- No login, cloud synchronization, advertisements, or mandatory network access.
- One local user/profile per installation.
- Regular Account finance and MyKhata are separate ledgers and must not affect each other's balances or reports.
- Backups are complete-app archives and always include MyKhata.

## 2. Approved technology baseline
| Concern | Selected technology |
|---|---|
| UI and runtime | Flutter / Dart |
| Local relational storage | SQLite |
| Database access and migrations | Drift |
| State management | Riverpod |
| Navigation | go_router |
| Charts | fl_chart |
| Local notifications | flutter_local_notifications |
| Secure device secrets | flutter_secure_storage backed by Android Keystore |
| Backup archive | Versioned encrypted `.khata` format |

The current source foundation introduces Flutter, Riverpod, and go_router. Drift, notifications, charts, secure storage, and backup dependencies will be added with their respective implementation milestones after package compatibility and security review.

## 3. Architecture style
Use feature-first Clean Architecture. Each feature owns its presentation, application/domain rules, and data access boundaries. Cross-feature reuse belongs in shared/core modules only when it represents genuinely shared behavior.

Proposed source layout:

    lib/
      app/
      core/
        database/
        errors/
        formatting/
        notifications/
        security/
        storage/
        widgets/
      features/
        accounts/ (data, domain, presentation)
        categories/ (data, domain, presentation)
        transactions/ (data, domain, presentation)
        budgets/
        savings_goals/
        recurring/
        my_khata/
        reports/
        backup/
        settings/
        dashboard/
        activity_center/
        trash/
      main.dart
    test/

## 4. Dependency direction
- Presentation depends on application/domain abstractions, not directly on SQLite.
- Domain rules must not depend on Flutter widgets, Drift generated classes, or platform APIs.
- Repositories expose domain-friendly interfaces; data implementations use Drift.
- Riverpod composes and exposes services, repositories, and feature state.
- go_router owns navigation configuration; feature widgets do not create ad-hoc global navigation state.
- Platform-specific work stays behind testable adapters.

## 5. Data and ledger boundaries
### Regular finance
Accounts, categories, transactions, adjustments, budgets, recurring rules, savings goals, and related audit/trash records belong to the regular finance domain. A regular Account balance is derived from its opening balance plus active income, minus active expenses, plus active balance adjustments. Future-dated records do not affect current totals before their effective date.

### MyKhata
MyKhata person profiles, lending/borrowing entries, installment schedules, repayments, repayment allocations, settlement history, and audit records form an independent ledger. MyKhata activity must never mutate regular Account balances, budgets, income, or expense totals.

### Shared supporting data
Payment method definitions and local attachment storage may be shared as infrastructure, but ownership links must preserve each feature's ledger boundary.

## 6. Database design principles

- Use stable UUID identifiers for user-created records and references.
- **Money storage:** store every monetary amount as an integer number of paise in the database and domain calculations. Example: ₹500 is stored as `50000`; ₹500.50 is stored as `50050`. Never use binary floating-point values for financial arithmetic.
- **Money display:** present amounts in Indian rupee format, showing whole rupees without unnecessary decimals (for example, `₹500`) and showing exactly two decimal places when paise are present (for example, `₹500.50`). Use a shared formatter so all screens, reports, and exports follow the same display rule; exports must retain exact monetary precision.
- Convert between rupees entered/displayed and integer paise at the input/presentation boundary using decimal-safe parsing and formatting. Do not round-trip through `double` for persisted money.
- Store timestamps/dates in a documented canonical representation and convert at the presentation boundary.
- Use foreign keys and explicit delete behavior.
- Use database transactions for multi-record operations such as repayment allocation, restore/merge, and bulk cleanup.
- Add versioned Drift migrations for every schema change.
- Preserve approved soft-delete, retention, and audit semantics.
- Do not drop/recreate user tables as a migration shortcut.
- Derived balances and summaries must have one authoritative calculation path and tests.

Exact entity definitions, indexes, date/time representation, and migration policy will be specified in the detailed data model before those features are implemented.
## 7. Security and backup architecture
- Keep local data within application-private storage unless the user explicitly exports/shares a file.
- Store device-held secrets using Android Keystore-backed secure storage.
- Encrypt backup archives with authenticated encryption.
- Validate archive structure, version, integrity, and references before restore.
- Create and validate a recovery snapshot before migrations, restore, and other approved high-risk operations.
- Do not log transaction amounts, notes, attachment contents, passwords, or cryptographic material.

**Security design still required:** final KDF selection and parameters, encryption package selection, nonce/salt handling, key lifecycle, archive manifest, attachment encryption, temporary-file handling, and restore rollback behavior must be reviewed before implementation. AES-256-GCM and Argon2id/PBKDF2 are candidate design choices, not a claim that these protections have already been implemented.

## 8. Current application foundation
Implemented on the project-foundation feature branch:
- Flutter application entry point and Riverpod root scope.
- Material 3 light/dark theme host.
- go_router route for Home and Add Transaction.
- Five-item bottom navigation shell: Home, Accounts, History, MyKhata, More.
- Initial Home presentation scaffold.
- Expense/Income segmented entry-form scaffold.
- Initial widget tests for launch, navigation shell presence, and transaction-form routing.

Not implemented yet:
- Android native platform directory and Gradle wrapper.
- SQLite/Drift schema and repositories.
- Real transaction persistence, validation, Account/category selection, and balance calculation.
- Feature workflows beyond the initial navigation and form scaffolds.
- Backup encryption, notifications, reports, and MyKhata behavior.

## 9. Open design decisions
These must be resolved in the PRD/data design before the affected features are implemented:
- Budget period semantics and total-budget behavior.
- Recurrence editing, overdue reminder dismissal, and custom intervals.
- MyKhata overpayment validation and reopening a settled person-direction ledger.
- Savings-goal transaction links and their treatment in regular budgets/reports.
- Exact backup cryptography and archive format.
- Android minimum SDK, signing, and release distribution configuration.

## 10. Validation policy
Run when the toolchain is available:

    dart format --output=none --set-exit-if-changed .
    flutter analyze
    flutter test
    flutter build apk --debug

Report checks as not run when Flutter tooling is unavailable. Never infer a successful build from source files or a successful workflow configuration alone.
