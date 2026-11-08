# Initial Local Database Schema — MyAccountsManager

**Status:** Initial schema proposal / implementation baseline  
**Database:** SQLite through Drift  
**Initial schema:** version 1; **current implementation:** version 2  
**Date recorded:** 2026-11-08

This document defines the first persistence boundary. It intentionally covers Accounts, Categories, and regular Income/Expense Transactions only. Later feature milestones will add their own tables through versioned migrations.

## 1. Global storage conventions

| Concern | Storage |
|---|---|
| Primary keys | UUID string (TEXT) |
| Monetary values | Integer paise (INTEGER) |
| Date-only business fields | UTC midnight epoch milliseconds (INTEGER) |
| Actual event/audit timestamps | UTC epoch milliseconds (INTEGER) |
| Booleans | SQLite integer 0/1 |
| Free-form text | TEXT |
| Optional values | Nullable column |

- Never persist monetary values as REAL, double, or formatted currency strings.
- UUIDs are generated in the application layer before insert, so IDs are stable across repositories and backup/restore.
- Date-only values must be decoded as UTC calendar components and must not be converted to device local time.
- Audit timestamps represent actual instants. Convert to local time only when presenting a time to the user.
- Use parameterized Drift queries; do not concatenate user input into SQL.
- Enable SQLite foreign-key enforcement for every database connection.

## 2. Version 1 tables

### accounts

| Column | Type | Required | Meaning |
|---|---|---:|---|
| id | TEXT | Yes | UUID primary key |
| name | TEXT | Yes | Account display name |
| description | TEXT | No | Optional description |
| icon_key | TEXT | No | Stable icon identifier |
| color_value | INTEGER | No | ARGB color value |
| opening_balance_paise | INTEGER | Yes | Signed opening balance; default 0 |
| is_pinned | INTEGER | Yes | Pinned state; default false |
| sort_order | INTEGER | Yes | User-defined ordering |
| archived_at | INTEGER | No | UTC audit instant when archived |
| created_at | INTEGER | Yes | UTC audit instant |
| updated_at | INTEGER | Yes | UTC audit instant |

Indexes:
- accounts_archived_sort_idx(archived_at, sort_order)
- accounts_pinned_sort_idx(is_pinned, sort_order)

Rules:
- Name is required and must not be blank after trimming.
- Opening balance may be positive, zero, or negative.
- Opening balance is editable until the Account has at least one transaction or balance adjustment. After that, corrections use balance adjustments.
- Archiving retains all financial history.
- Permanent deletion is an explicit user-confirmed operation and removes dependent regular-finance records according to the approved deletion behavior. It must be performed in a database transaction.
- No Account-to-Account transfer table is introduced.

### categories

| Column | Type | Required | Meaning |
|---|---|---:|---|
| id | TEXT | Yes | UUID primary key |
| name | TEXT | Yes | Category display name |
| type | TEXT | Yes | expense or income |
| icon_key | TEXT | No | Stable icon identifier |
| color_value | INTEGER | No | ARGB color value |
| is_system | INTEGER | Yes | Built-in category flag |
| sort_order | INTEGER | Yes | Display order |
| is_active | INTEGER | Yes | Active category flag |
| created_at | INTEGER | Yes | UTC audit instant |
| updated_at | INTEGER | Yes | UTC audit instant |

Indexes:
- categories_type_active_sort_idx(type, is_active, sort_order)
- Unique active category name per type, using normalized lowercase name in application validation initially. A database-enforced normalized-name column can be added if needed after collation behavior is finalized.

Rules:
- Category type is restricted to expense or income.
- Expense and income categories are separate.
- System categories are seeded idempotently on first database creation.
- Renaming a category changes the current name/icon/color shown for linked historical transactions; it does not change transaction amounts or dates.
- A category referenced by a transaction cannot be hard-deleted directly. Reassignment must happen in a transaction before removal/deactivation.
- No subcategory hierarchy is part of version 1.

### transactions

| Column | Type | Required | Meaning |
|---|---|---:|---|
| id | TEXT | Yes | UUID primary key |
| account_id | TEXT | Yes | Foreign key to accounts.id |
| category_id | TEXT | Yes | Foreign key to categories.id |
| type | TEXT | Yes | expense or income |
| amount_paise | INTEGER | Yes | Positive amount in paise |
| note | TEXT | No | Optional note |
| transaction_date | INTEGER | Yes | UTC-midnight date-only timestamp |
| created_at | INTEGER | Yes | UTC audit instant |
| updated_at | INTEGER | Yes | UTC audit instant |
| deleted_at | INTEGER | No | UTC audit instant; soft-delete marker |

Indexes:
- transactions_account_date_idx(account_id, transaction_date)
- transactions_category_date_idx(category_id, transaction_date)
- transactions_date_idx(transaction_date)
- transactions_deleted_date_idx(deleted_at, transaction_date)

Rules:
- Amount must be greater than zero.
- Type must be expense or income and must match the selected category's type. Enforce in domain/repository validation and add database checks where practical.
- Account and category references must exist.
- A soft-deleted transaction is excluded from balances, budgets, and normal history queries.
- Permanent deletion is separate from soft deletion and follows the approved Trash retention flow.
- Future-dated transactions remain stored as normal transactions; whether they are Upcoming or effective is derived from their date relative to the current date. Future transactions do not affect current balances before their date.
- Duplicate detection is a warning in the application layer, not a unique database constraint.
- Attachments, payment methods, recurring-rule links, and audit-detail tables will be added in later migrations rather than prematurely coupling version 1 to unfinished modules.

## 3. Database-level integrity

- accounts.id, categories.id, and transactions.id are primary keys.
- transactions.account_id references accounts.id.
- transactions.category_id references categories.id.
- Account deletion uses an explicit transactional repository operation; the foreign-key action must not silently remove data outside that operation.
- Category references use restrictive deletion behavior until reassignment has completed.
- Add SQL checks for non-negative/positive amount and valid enum strings where supported by the selected Drift table definitions.
- All multi-row operations use a single SQLite transaction.
- All writes update updated_at using an actual UTC audit timestamp.

## 4. Initial category seed

Seed the approved built-in Expense and Income categories from the product requirements. Seed operation must be idempotent: reopening the database must not duplicate or reset user-customized categories.

System category identifiers should be deterministic stable IDs derived from a documented constant key, or stored as fixed UUID constants. Do not generate new system category IDs on every launch.

## 5. Migration policy

- schemaVersion starts at 1.
- Fresh install: create the version 1 schema and seed built-in categories inside the initial creation transaction.
- Every future schema change increments schemaVersion and adds an explicit onUpgrade migration step.
- Migrations must be transactional and preserve existing rows and UUIDs.
- Before a destructive/high-risk migration, create and validate a recovery snapshot as required by the backup/recovery design.
- Never use dropAll() or delete the database as an automatic migration fallback.
- Unknown newer schema versions must fail safely with a recoverable error; do not attempt downgrade.
- Add migration tests for fresh creation, each supported old-to-new path, and preservation of representative financial records.

## 6. Query and calculation ownership

- Repositories own persistence operations and expose domain-friendly records.
- Domain services own validation and balance calculations.
- Account current balance is calculated from opening balance plus active income, minus active expenses, plus active balance adjustments. Balance adjustments are introduced in a later migration.
- Queries that calculate totals must exclude soft-deleted records and include only records effective on the selected as-of date.
- Do not maintain a second independently mutable balance total in the Account row. If summary caching is later needed, it must be rebuildable and verified against source transactions.

## 7. Version 2 addition — balance_adjustments

Version 2 adds a dedicated `balance_adjustments` table through a non-destructive Drift migration. Existing version-1 Accounts, Categories, and Transactions rows are preserved.

| Column | Type | Required | Meaning |
|---|---|---:|---|
| id | TEXT | Yes | UUID primary key |
| account_id | TEXT | Yes | Foreign key to accounts.id |
| amount_paise | INTEGER | Yes | Signed non-zero balance delta in paise |
| reason | TEXT | Yes | Required explanation, maximum 500 characters |
| adjustment_date | INTEGER | Yes | UTC-midnight date-only timestamp |
| created_at | INTEGER | Yes | UTC audit instant |
| updated_at | INTEGER | Yes | UTC audit instant |
| deleted_at | INTEGER | No | Reserved soft-delete marker |

Indexes: `balance_adjustments_account_date_idx(account_id, adjustment_date)` and `balance_adjustments_deleted_date_idx(deleted_at, adjustment_date)`.

Rules: positive adjustments increase the Account balance; negative adjustments decrease it. Adjustments are independent of Expense/Income categories and do not create regular transactions. Only active Accounts can receive new adjustments. Balance calculations include non-deleted adjustments dated on or before the requested as-of date. Each adjustment keeps its reason and creation/update timestamps as its audit record. The current UI supports creating and viewing adjustments; edit/Trash actions are deferred.

## 8. Deliberately deferred tables

These are not omitted accidentally; they belong to later milestones:
- payment_methods
- attachments and attachment-owner links
- transaction_audit
- trash metadata, if a generic Trash table is required beyond per-entity deletion timestamps
- budgets, budget_categories
- recurring_rules, recurring_occurrences
- savings_goals, goal_contributions
- MyKhata people, ledgers, entries, schedules, repayments, allocations, and audit records
- settings, notification preferences, activity-center events
- backup catalog and recovery-snapshot metadata

MyKhata must use its own tables and repository boundary. No MyKhata record references a regular Account or regular transaction.

## 9. Open implementation checks before database code is considered complete

- Confirm chosen Drift and sqlite3 package versions against the repository's Dart/Flutter SDK constraints.
- Generate Drift code with build_runner; commit generated source when required by the repository workflow.
- Run formatter, analyzer, unit tests, migration tests, and Android build in a Flutter-enabled environment.
- Verify foreign-key enforcement, date-only timezone behavior, and integer-paise round trips on an Android device/emulator.
