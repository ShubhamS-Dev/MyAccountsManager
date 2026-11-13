# Changelog

## Unreleased

### Category icons on all transaction rows (2026-11-13)
- Added the `Rental Income` resolver alias for seeded categories whose icon key is null.
- Added shared `CategoryIconBadge` and applied it to History, Home Recent, Activity Center scheduled transactions, Reports Largest expenses/income, and the Transaction Details header. Details shows no fallback icon while categories load and keeps theme-aware income/expense colours.
- Added resolver coverage for all 16 seeded expense and 8 seeded income category names, badge colour/name-fallback coverage, and Home, Reports and Activity Center row coverage.
- UI-only: no package, schema, migration, repository or database changes.
- CI fix: the Reports widget test waited for "Largest expenses" before scrolling, but Reports is a lazy ListView and that section is below the fold, so it was never built. The test now waits for the page and scrolls first.

### Transaction Details — delete to Trash (2026-11-13)
- Added one full-width, low-emphasis Delete transaction action below the Duplicate / Copy as new helper text.
- Confirmation shows the signed, formatted amount and transaction note (or category title); the existing hidden-amount preference is preserved.
- Confirming uses the existing soft-delete operation, returns to the previous screen (or Home when opened from a notification or deep link with nothing to pop), and offers Undo through the existing restore operation. No schema, dependency, or repository API change.
- Widget tests cover confirm, return, Trash persistence, Undo restore, and the deep-link fallback.


### Contrast, export and MyKhata reminders (2026-11-11)
- Contrast: income and expense text now uses darker tones in light theme (#047857, #BE123C; 5.2 to 6.3:1 on light surfaces). The bright tones stay for icons, chart slices and category colours. Dark theme is unchanged. Selected segments pick black or white text by luminance.
- Person Details hero and person avatars choose dark or white text by luminance. Light person colours (amber, sky, teal, emerald, rose, pink) previously had white text at 2.2 to 3.7:1.
- Account card balances on gradients are white instead of green or red. A deficit keeps its minus sign.
- Screen readers: colour swatches are named (Indigo, Amber and so on) and a new Default swatch resets the colour. Category icon choices are labelled. The category visibility switch reads "Show <name>". The History type selector announces its selected state. Account cards and khata rows read as one item. Masked amounts are announced as "amount hidden".
- Tap targets: colour swatches, category icons and the History type selector are now 48dp.
- Hide amounts now covers History (summary cards, bars and rows), Transaction Details, the Edit Account preview, Record Repayment, the khata entry form hints and the remove-repayment dialog. All screens use one mask, ₹ ••••.
- Account cards on Home and Accounts show a tap ripple. Long-press on an Accounts card opens its actions.
- Expense and income arrows are now the same on every screen: north-east for money out, south-west for money in. Add Transaction, Edit Transaction and Categories used up and down arrows.
- New More > Export data: shares transactions_YYYYMMDD.csv (all dates, Trash excluded, Scheduled marked) and mykhata_YYYYMMDD.csv (entries numbered, repayments linked by entry number) through the Android share sheet. Both are on by default and either can be switched off. Dates are ISO, amounts are rupee decimals, files carry a UTF-8 BOM, and cells starting with = + - @ are escaped so spreadsheets can't run them as formulas.
- MyKhata Person Details: the phone number opens Call or WhatsApp (numbers without a country code assume +91). Send reminder (shown only when the person owes you) prefills WhatsApp or any app with the amount and earliest due date. Statement shares a plain-text ledger with open and settled entries, repayments and the net position.
- MyKhata tab: the hero shows how many entries are overdue and opens a new Overdue filter.
- Dependencies (approved): share_plus 13.3.1, url_launcher 6.3.3. The Android manifest gains tel and https intent queries for url_launcher. No schema change.

### Reminders, notifications and Activity center (2026-11-11)
- Added local Android reminders (flutter_local_notifications): MyKhata entries the day before and on the due date, a daily summary while any entry is overdue, and Scheduled transactions on the day they start counting. All fire at one reminder time (default 9:00 AM).
- Reminders are derived from the database and rescheduled whenever entries, repayments, transactions or preferences change, on app resume and at midnight. Settled, deleted and edited items update or drop their reminders. They survive reboots and app updates.
- Timing is on the minute when Alarms & reminders access is granted, otherwise within a few minutes (inexact alarms, no extra permission needed).
- Notifications hide amounts by default; "Show amounts" in More > Notifications turns them on. Reminder text is never logged.
- The app bar bell opens a new Activity center (overdue, due in the next 7 days, scheduled transactions) and shows a badge for overdue and due-today entries. Tapping a notification opens the matching entry, transaction or the Activity center.
- New More > Notifications page: master switch, reminder time, per-type switches, Show amounts, permission and timing status with fixes, and a test notification.
- The app asks for the Android 13+ notification permission once, on first launch.
- No schema change: preferences live in app_settings under `notifications.`.
- Android: POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED and SCHEDULE_EXACT_ALARM permissions, plugin receivers, core library desugaring and a monochrome status-bar icon.

### UX audit fixes, system typography and Scheduled transactions (2026-11-11)
- Typography now follows the Material 3 type scale (body 14px, captions 12px, buttons 14px, titles 22px) and honours the device font size. Fixed-height cards and pickers scale with text; buttons keep a 40px face and gain a 48px tap area.
- Future-dated transactions are Scheduled: badged in History, Details and Account Details, excluded from balances and month totals until their date, and summarised in a Home Upcoming card. Balances roll over at local midnight.
- Fixed: tapping a History row showed "page not found"; Transaction Details is now routed and reachable from History, Home and Account Details.
- Fixed: a MyKhata person could never be removed after their entries were deleted.
- Settling a khata entry asks for confirmation and offers Undo; removing the latest repayment reopens a settled entry. Khata entry dates are capped at today.
- All forms ask "Discard changes?" before back navigation loses edits. Android back on a non-Home tab returns to Home.
- Hide amounts is saved on the device. Hero amounts on gradient cards stay white in light theme. Details shows hidden category names and local audit dates.
- Fixed the Currency & Format crore example.

### Smart notes and category suggestions (2026-11-11)
- Add Transaction shows recent notes as chips while the Note field is empty, and matching past notes as the user types. Tapping a chip fills the note.
- Add Transaction auto-selects a Category from the note, labelled "Suggested from note". The match uses the user's own history first (same or similar notes, recent use weighted higher), then built-in keywords for the seeded categories; custom categories match on their name. A Category the user picks by hand is never overridden.
- Edit Transaction shows the same note chips and suggests a Category with a "Use" button. It never changes the saved Category on its own.
- Suggestions consider only non-deleted transactions of the same type and only active categories. No schema change; logic lives in `lib/features/transactions/data/note_suggestions.dart`.
- Added `test/features/note_suggestions_test.dart` (14 tests: ranking, Trash and type separation, hidden categories, auto-select, manual override, Edit "Use").

### MyKhata, More and remaining screen refresh (2026-11-11)
- Added MyKhata: People list with net position, Add/Edit Person, Person Details, Add/Edit Khata Entry, Entry Details and Record Repayment. It is an independent ledger that never touches Account balances.
- Schema version 3 (additive migration): khata_people, khata_entries, khata_repayments, app_settings. Overpayment is blocked, settled entries cannot be reopened, and installment schedules are deferred.
- Added the More hub with Appearance (System/Light/Dark, saved on the device), Global Categories management (add, edit, hide, restore), Currency & Format, About App, and designed coming-soon states for Budget Alerts and Backup & Restore.
- Home shows a separate MyKhata summary card. The MyKhata tab FAB adds a khata entry.
- Refreshed Create Account (live card preview, icon, colour, signed opening balance), Edit Account (icon and colour editing), Archived Accounts, Balance Adjustments (Increase/Decrease selector, date shortcuts) and Transaction Trash (category icons, action sheet).
- Extracted shared form widgets (`lib/app/app_form_widgets.dart`) and moved the Indian amount input formatter to `lib/core/formatting/`.
- Fixed the Add Transaction screenshot test hang by running image encoding outside FakeAsync.

### Accounts screen — premium UI refresh
- Reused shared Dashboard gradients, cards, typography, amount and empty-state widgets.
- Connected Accounts amount visibility to the shared Dashboard privacy preference.
- Refreshed Account cards, summary, search section, add-account affordance and action bottom sheet.
- Corrected the active Account count label for singular and plural counts; updated the Accounts widget test to use the shared amount-visibility tooltips.
- Used existing account icon/color metadata with a safe palette fallback.
- UI-only change: Account data, provider/repository logic, navigation, search, ordering, pinning and archive behaviour are unchanged.

### History screen — premium UI refresh
- Added month pill, monthly summary cards, animated type selector, filter bottom sheet, removable filter chips, and filtered-result count.
- Added pinned date-group headers, category icon/colour presentation, swipe-to-trash with Undo, shimmer loading, and separate first-run/no-results empty states.
- Monthly totals continue to represent the full selected month regardless of active filters.
- Expanded History widget coverage for month navigation, search, type selection, Account/Category filters, removable chips, Trash access, and empty state.
- Corrected empty-state selection so active search/filters show the no-results state even when there are no stored transactions.
- Reused shared design tokens/widgets; no new package, schema migration, or navigation change.

- Refined History category icon mapping, selected-segment contrast, and shared gradient FAB; added metadata-projection and swipe/Undo regression coverage. History color usage remains token/theme-driven for future Light-theme support.


### Add Transaction — premium form refresh
- Rebuilt the Add Transaction experience with animated Expense/Income selection, pinned-first Account chips, date shortcuts, expandable Note, prominent Indian-formatted paise-safe Amount input, quick-add chips, and Category chips.
- Added the dedicated 28px `AppTypography.amountInput` exception; all standard transaction amount typography remains 16px.
- Added opt-in gradient support to `PrimaryButton`; the default appearance for all existing callers remains solid.
- Added shared Account and Category icon resolvers without changing Accounts or History presentation.
- Preserved UTC date-only storage, category-type filtering, repository validation/save flow, and Home Income shortcut.
- No schema migration, package, Edit Transaction change, or shared shadow change.


### Add Transaction — review refinements
- Kept the three quick-add amounts in one compact horizontal row and removed the nested TextField fill from the Note pill.
- Aligned the rupee symbol, amount and hint to the dedicated 28px amount typography; added a CI-captured screenshot while an amount is entered.
- Applied per-category icon tints and distinct Transportation / Vehicle Maintenance / Others icon mappings through the shared resolver used by History.
- Reduced the horizontal Account card selector height from 76px to 68px.
