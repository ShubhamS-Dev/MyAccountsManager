# Accounts Screen

## Structure
1. Shared hero summary card using `GradientCard` and `AppColors.heroGradient`.
2. Summary amount uses `AmountText` and the shared Dashboard privacy preference.
3. `SectionHeader` provides the Accounts title and Add action.
4. Search uses the app-wide themed input decoration.
5. Active Accounts remain in the existing pinned-first, two-column grid. The summary count uses singular/plural wording (`1 active account` / `2 active accounts`).
6. Each Account card uses `GradientCard`, shared typography/radius/spacing, and a metadata-driven icon/color with Dashboard palette fallback.
7. Add Account uses a shared `AppCard` surface.
8. Empty and load-error states use `EmptyState` with a retry or add/clear CTA.

## Account card metadata
- `iconKey` is mapped to supported Material icons (bank, cash/money, card, wallet, savings, investment).
- Unknown or absent icon keys fall back to the wallet icon.
- `colorValue` supplies the card's base color when present; otherwise the Dashboard account gradient palette is selected by visible grid position.
- No Account type field or database/model change is introduced.

## Privacy behaviour
Accounts reads `amountsHiddenProvider`, the same Riverpod presentation state used by Dashboard and Account Details. Toggling visibility here updates those screens too. No screen-local balance privacy state is retained.

## Actions
The three-dot menu opens a premium modal bottom sheet with only existing operations:
- View details
- Edit
- Adjust balance
- Pin / Unpin
- Archive

Archive still uses the existing confirmation dialog and repository method. There is no permanent Delete action. Routes, providers, repository calls, sort order, search semantics, and data model remain unchanged.

## Validation
CI is the Flutter validation authority for this branch (Flutter 3.47.9). Record the exact workflow run and result in the implementation log after the change.
