# MyAccountsManager

An offline-first Flutter personal finance manager with an independent **MyKhata** ledger for tracking money lent and borrowed.

## Project status

Requirements and the baseline technical architecture are being finalized. Implementation has not started.

## Product principles

- Fully offline; no login, cloud sync, or ads.
- Local financial data stored on the device.
- Separate Account-based income, expense, budgets, and savings tracking.
- Independent MyKhata ledgers for lending, borrowing, repayments, installments, and settlement history.
- Encrypted, password-protected complete backups and validated restore/merge.
- Data integrity through UUIDs, database transactions, migrations, audit history, and recovery snapshots.

## Approved technical baseline

- Flutter and Dart
- SQLite with Drift
- Riverpod
- Feature-first Clean Architecture
- go_router
- fl_chart
- flutter_local_notifications
- Secure device storage backed by Android Keystore
- Encrypted versioned `.khata` backups

## Navigation

Home | Accounts | History | MyKhata | More

The Add Transaction action is a floating action button.

## Important project constraints

- All data remains local to the device.
- MyKhata activity never changes regular Account balances or income/expense totals.
- Complete backups always include MyKhata data and attachments.
- Backup passwords are required; the default password can be securely stored on-device for scheduled backups.
- Database migrations create and validate a recovery snapshot before applying changes.
- Deleted records remain in Trash for 30 days before permanent cleanup, subject to the approved audit and retention rules.

## Branching strategy

- `master`: production/release.
- `development/YYYYMMDD`: daily development integration branch.
- `feature/YYYYMMDD/<short-description>`: feature/task branch created from the active development branch.

Feature work is implemented on feature branches, reviewed into the matching development branch, and promoted to `master` only for an explicitly approved release. See `agent.md` for the full workflow.

## Development workflow

Implementation must follow the approved requirements and architecture. Do not silently assume behavior where a requirement is unclear. Clarify material decisions before changing product behavior, data models, security, or deployment.

## License

Not yet selected.
