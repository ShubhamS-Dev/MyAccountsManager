# MyKhata Screens

Independent lending and borrowing ledger. Nothing on these screens reads or changes Accounts, Account balances or income/expense totals.

## Terms
- You gave (`lent`): the person owes you. Emerald, shown as "You'll get".
- You got (`borrowed`): you owe the person. Rose, shown as "You'll give".
- Outstanding: entry amount minus repayments. Settled when it reaches zero.

## MyKhata tab
- Hero: net position (signed), You'll get and You'll give totals, shared amount privacy toggle.
- People list with avatar initials, open/settled summary and net label. Search by name or phone; All / Open / Settled filter.
- Empty state with Add person; no-results state with Show everyone.
- The shell FAB on this tab opens Add Khata Entry (tooltip "Add khata entry").

## Person Details (`/khata/people/:id`)
- Coloured hero with net position and, when both directions exist, the split.
- "You gave" and "You got" actions open Add Khata Entry pre-filled.
- Ledger grouped into open and settled entries, with repayment progress and Overdue pills.
- Menu: Edit person; Remove person (enabled only when there are no entries).

## Add/Edit Person (`/khata/people/new`, `/khata/people/:id/edit`)
Name (required), phone, note, colour, with a live avatar preview.

## Add/Edit Khata Entry (`/khata/entries/new`, `/khata/entries/:id/edit`)
Order: direction selector, Person, Date, Note, Amount, optional Due date. In edit mode, person and direction are fixed, and the amount must stay above what has been repaid.

## Entry Details (`/khata/entries/:id`)
Outstanding amount, repayment progress, details, and repayment history. Open entries offer Record repayment, Edit, and Delete (only when no repayments exist). Repayments on open entries can be removed; settled entries are locked.

## Record Repayment (`/khata/entries/:id/repay`)
Amount with Full and Half shortcuts, a date that cannot be before the entry date, and a note. Amounts above the outstanding amount are rejected in the form and in the repository.

## Deferred
Installment schedules, reopening settled entries, a MyKhata Trash UI, attachments, and reports.
