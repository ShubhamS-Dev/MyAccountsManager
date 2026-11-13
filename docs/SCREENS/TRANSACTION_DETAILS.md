# Transaction Details Screen

## Purpose
Show the selected transaction's amount, note, Account, Category, transaction date, and audit timestamps, with actions to edit or create a copy.

## Layout
- The existing Edit transaction action remains first.
- Duplicate and Copy as new remain side by side.
- The helper text “Duplicate saves a copy dated today. Copy as new lets you change it first.” remains directly below those actions.
- A single full-width, low-emphasis **Delete transaction** text action appears below the helper text with spacing. Its leading trash icon and label use `Theme.of(context).colorScheme.error`. The shared TextButton theme provides a 40px visual face and 48px touch target.
- No delete action is added to the AppBar or beside Edit / Duplicate / Copy as new.

## Delete confirmation
- Tapping Delete transaction opens “Delete this transaction?”.
- The dialog shows the transaction's signed, MoneyFormatter-formatted amount and its note. When no note exists, the Category name is used as the title fallback.
- When Hide amounts is enabled, the amount uses the same `hiddenAmountMask` as the details screen.
- Cancel closes the dialog without changing the transaction. Delete uses the theme error color.

## Trash and Undo flow
- Confirming calls the existing `TransactionsRepository.softDeleteTransaction`; it never permanently deletes the record.
- After a successful soft delete, the details route is popped and the previous screen receives a “Transaction moved to trash” SnackBar with an Undo action.
- Undo calls the existing `TransactionsRepository.restoreTransaction`. Restore failures use the existing “Could not restore transaction.” feedback.
- Delete failures use the existing History error feedback pattern and leave the details screen open.
- Balance, History, Dashboard, and Account updates continue through the existing reactive Drift/Riverpod streams. No manual refresh is added.

## Data and architecture constraints
- No new repository/database method, package, schema field, or migration.
- Existing repository methods, Riverpod providers, amount formatter, privacy preference, theme tokens, and shared button theme are reused.
- Light and dark themes both use the active ColorScheme error token.
