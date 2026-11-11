# More and Settings Screens

## More tab
Grouped hub: Manage (Categories, Archived Accounts, Transaction Trash), Preferences (Appearance, Currency & Format, Budget Alerts), Data (Backup & Restore, About App). No FAB on this tab.

## Appearance (`/more/appearance`)
System / Light / Dark cards with mini previews. The choice persists in `app_settings` (`appearance.theme_mode`) and applies immediately through `themeModeProvider`. The default is System.

## Categories (`/more/categories`)
Expense / Income selector. Active and hidden groups. A switch hides or restores a category; hidden categories stay on past transactions but are not offered for new ones. The add/edit sheet has name, icon and colour. Built-in names are fixed, custom names are unique per type (case-insensitive), and nothing is ever deleted.

## Currency & Format (`/more/currency`)
Read-only. Examples are rendered live by `MoneyFormatter` and `dateLabel`, so they always match the app. INR is the only currency.

## Budget Alerts and Backup & Restore (`/more/budgets`, `/more/backup`)
Designed coming-soon states. Neither feature is implemented, because the budget semantics and backup cryptography are still open decisions. The Backup screen says plainly that no backup exists yet.

## About App (`/more/about`)
Version, product principles, and the Flutter licence page. The version label is the constant `appVersionLabel` in `more_page.dart`; keep it in step with `pubspec.yaml`.
