# Agent Instructions — MyAccountsManager

These instructions are mandatory for any AI agent or contributor making changes in this repository.

## 1. Project identity and purpose

- App name: **MyAccountsManager**
- Platform: Android, built with Flutter and Dart.
- Product: offline-first personal finance manager with an independent **MyKhata** ledger.
- All application data is stored locally on the device. Do not introduce cloud sync, login, analytics, ads, or internet dependency unless the product requirements are explicitly changed and approved.

## 2. Source-code changes are the deliverable

**When the user requests a feature, bug fix, UI change, refactor, or other application change, modify the actual application source code. Updating only a workflow/YAML file is not implementation.**

Before reporting a requested change as complete:

1. Inspect the current repository and relevant source files.
2. Identify the actual feature/module and its dependencies.
3. Implement the change in the appropriate Flutter/Dart source files.
4. Update or add database schema, migrations, repositories, providers, UI, tests, and assets when required by the change.
5. Review all affected call sites and existing behavior.
6. Run the relevant formatter, analyzer, and tests where the environment permits.
7. Build the Android target when possible and report the actual result.
8. Commit and push the source changes to the intended branch when authorized by the task.
9. Update `milestone.md` to reflect verified progress.

Do not mark a task complete merely because a workflow ran, a YAML file changed, a commit was created, or an APK was produced. The requested behavior must exist in the source code and be validated to the extent possible.

## 3. YAML and CI/CD workflow rules

- GitHub Actions workflow files are for automation: checkout, dependency setup, formatting/analyzing/testing, building, signing (where configured), and publishing artifacts.
- Do not replace a requested application implementation with workflow edits.
- Do not modify YAML just to make a change appear complete.
- Change workflow files only when the requested work genuinely requires a CI/CD change or when fixing a workflow defect.
- If both application code and workflow configuration need changes, update both; source implementation remains mandatory.
- Never claim that a workflow update changes app behavior unless the corresponding source code was changed.
- Do not invent signing secrets, credentials, repository settings, release channels, or branch policies. Ask before making a material deployment-policy decision that is not documented.

## 4. Requirements and clarification policy

- Treat approved product requirements and architecture documents in this repository as the source of truth.
- Do not silently guess or fill in unclear requirements.
- Before implementation, ask a concise clarification question when ambiguity could materially affect behavior, architecture, stored data, security, privacy, UI, or deployment.
- Explain technical terms in plain language so the user can make an informed decision.
- If a requirement is not finalized, document it as an open decision; do not present it as approved.
- Do not remove, weaken, or reinterpret an existing approved requirement without explicit approval.

## 5. Approved technical baseline

Use the approved baseline unless the user explicitly approves a change:

- Flutter and Dart
- SQLite with Drift
- Riverpod
- Feature-first Clean Architecture
- go_router
- fl_chart
- flutter_local_notifications
- Secure device storage backed by Android Keystore
- Versioned, encrypted `.khata` backup archives

Keep dependencies purposeful. Do not introduce an alternative state-management, database, routing, or architecture framework without approval.

## 6. Data integrity and product boundaries

- Keep all financial data local and offline.
- Keep regular Account transactions and balances independent from MyKhata lending/borrowing activity.
- MyKhata repayments must not silently affect regular Account balances or income/expense totals.
- Use database transactions for multi-record financial operations.
- Preserve UUID identity, referential integrity, audit history, and approved Trash/retention behavior.
- Add and test Drift migrations for schema changes. Never solve a migration issue by silently deleting or recreating user data.
- Validate backup archives before restore. Follow the approved recovery-snapshot and restore safeguards.
- Never log sensitive financial details such as amounts, notes, attachments, passwords, encryption keys, or backup contents.

## 7. Security and privacy

- Do not store backup passwords or cryptographic keys in plaintext.
- Do not weaken encryption, password handling, Android Keystore use, or restore validation for convenience.
- Do not add network requests or third-party telemetry without explicit approval.
- Diagnostic logs must follow the product requirement to exclude sensitive financial content.
- Treat backup/restore, bulk deletion, migrations, and other destructive operations as high-risk changes requiring safeguards and tests.

## 8. Code quality and testing

- Follow the existing feature-first Clean Architecture and repository conventions.
- Keep business rules out of presentation widgets.
- Prefer small, focused, maintainable changes.
- Add or update unit, widget, and integration tests appropriate to the behavior.
- Test financial calculations, rounding, date boundaries, future-dated records, recurrence idempotency, repayment allocations, and restore/merge logic where affected.
- Run `dart format`, `flutter analyze`, and relevant `flutter test` commands when Flutter tooling is available.
- Do not claim tests or builds passed unless they were actually run successfully.
- If a check cannot be run, state why and identify what remains unverified.

## 9. Change reporting

For each implementation task, report:

- What behavior was requested and implemented.
- Source files added or changed.
- Database/migration impact, if any.
- Tests and checks actually run, including failures or unavailable tooling.
- Build/artifact status, if relevant.
- Commit and branch information when available.
- Any remaining limitations or open decisions.

Update `milestone.md` after meaningful verified progress. Keep statuses honest: `Not Started`, `In Progress`, `Blocked`, or `Done`. A milestone is `Done` only when its acceptance criteria are met and the relevant validation has been performed.

## 10. First action in a new task

Read this file, `README.md`, `milestone.md`, and the relevant approved requirements/architecture documents before changing code. Inspect the current repository state rather than assuming previous work is present.

If the repository does not yet contain application source code, do not pretend a feature has been implemented. First establish the approved requirements and project structure, then implement the source code.
