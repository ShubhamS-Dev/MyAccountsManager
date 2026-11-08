# UI/UX Requirements — MyAccountsManager

**Status:** Approved baseline requirements, implementation pending

This document captures the UI/UX requirements confirmed from the user's review of the current Android screens. Apply them consistently to existing and future modules. These are requirements, not a claim that the current UI already meets them.

## 1. Premium product experience
- Create a cohesive, polished finance-app design system for color, typography, spacing, elevation, borders, corner radii, icons, and component states.
- Improve visual hierarchy and balance whitespace; avoid oversized controls, excessive empty space, and unnecessarily large cards.
- Use restrained, purposeful animation for navigation, screen transitions, dialogs, bottom sheets, selection changes, and feedback.
- Animations must be smooth, brief, accessible, and must not delay or block financial actions.
- Design loading, skeleton, empty, error, retry, and success states intentionally.
- Preserve legibility, accessibility, and comfortable touch targets while keeping controls visually compact.
- Apply the same design language across Home, Accounts, History, transaction forms, MyKhata, More, and future modules.

## 2. Compact input controls
- Dropdown fields and popup menus must be more compact than the current oversized controls.
- Date-picker dialogs/calendars must use space efficiently and avoid oversized layouts.
- Keep touch targets usable; compactness must not make controls difficult to tap.
- Align field heights, labels, internal padding, corner radii, and typography across forms.
- Use menus and bottom sheets only where they improve the task.

## 3. Add Transaction form order
Keep transaction inputs together in one coherent form, in this exact top-to-bottom order:
1. **Account** — select the Account first.
2. **Transaction date** — select the date second.
3. **Note** — optional note third.
4. **Amount** — enter the amount fourth.
5. **Other transaction details** — Category and any additional applicable fields after Amount.

The Expense/Income type selector remains a transaction-type control and may be positioned as a compact selector above the ordered fields. Do not interleave unrelated content or large decorative sections between these inputs. Preserve validation, focus order, and keyboard behavior in the same visual sequence.

## 4. Transaction date label
- When the selected transaction date is the device's current local calendar date, show **Today** in the form.
- When the selected date is not today, show the selected calendar date in **DD MMM YYYY** format, for example **08 Nov 2026**.
- Update the label immediately when the user changes the date, including changing from Today to another date and back.
- This is presentation-only. Preserve UTC-normalized calendar-date storage; selected business dates must not shift because of device timezone conversion.
- Compare calendar-date components with the device's current local calendar date, not elapsed hours or a UTC instant comparison.

## 5. Financial amount presentation
- Use one shared formatter for all monetary values throughout the app.
- Use Indian digit grouping (3 digits at the right, then groups of 2), for example ₹1,000, ₹1,00,000, and ₹10,00,000.
- Preserve the existing precision rule: whole-rupee values do not show unnecessary decimals; values containing paise show exactly two decimal places, for example ₹500.50.
- Negative values must retain a clear minus sign, for example -₹1,000; do not hide the sign or rely on color alone.
- Apply formatting consistently to balances, transactions, adjustments, totals, reports, and MyKhata amounts.

## 6. Semantic amount colors
- Positive amounts and income use the semantic positive/success color.
- Negative amounts and expenses use the semantic negative/error color.
- Neutral amounts, labels, and unrelated monetary values use neutral foreground color.
- Maintain accessible contrast in light and dark themes.
- Color reinforces the sign/type; it never replaces the explicit sign or transaction label.

## 7. Reactive data refresh
- Use reactive Drift queries/streams exposed through Riverpod providers for data that can change while a screen is mounted.
- Ensure dependent views refresh after create, edit, soft-delete, restore, permanent-delete, archive, unarchive, pin, balance adjustment, and other relevant mutations.
- A mutation must update all affected summaries and lists, including Home totals, Account balances, History, and relevant detail screens.
- Avoid stale cached snapshots and scattered manual refresh calls as the primary synchronization strategy.
- Make dependencies explicit when derived values depend on multiple tables, or query authoritative derived data through a reactive query.
- Returning to a screen must show the latest persisted state without requiring an app restart.
- Add tests proving mutations propagate to dependent providers/widgets. Manual pull-to-refresh is not a substitute for correct reactive updates.

## 8. Acceptance checklist
- [ ] Cohesive premium design system across screens.
- [ ] Purposeful, smooth, non-blocking animations.
- [ ] Compact dropdowns and date pickers with accessible touch targets.
- [ ] Add Transaction order: Account → Date → Note → Amount → Category/other details.
- [ ] Current transaction date is labeled **Today**.
- [ ] Other dates display as **DD MMM YYYY** (example: **08 Nov 2026**).
- [ ] Indian digit grouping is used for every displayed amount.
- [ ] Positive and negative amounts use consistent semantic colors and retain explicit signs.
- [ ] Database mutations reactively update every affected screen and summary.
- [ ] Light and dark themes preserve contrast and semantic color meaning.
