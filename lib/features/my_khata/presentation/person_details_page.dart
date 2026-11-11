import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../../core/platform/external_apps.dart';
import '../../../core/time/today_provider.dart';
import '../data/khata_messages.dart';
import '../data/khata_repository.dart';
import '../khata_providers.dart';
import 'khata_widgets.dart';

class PersonDetailsPage extends ConsumerWidget {
  const PersonDetailsPage({required this.personId, super.key});

  final String personId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    KhataPersonRow person,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Remove ${person.name}?',
      message:
          'This person has no open or settled entries. They will be removed '
          'along with any entries you deleted earlier.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(khataRepositoryProvider).deletePerson(person.id);
      router.pop();
    } on StateError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showMenu(
    BuildContext context,
    WidgetRef ref,
    KhataPersonRow person,
    bool hasEntries,
  ) {
    showActionSheet(
      context,
      title: person.name,
      actions: (sheetContext) => [
        ActionSheetTile(
          icon: Icons.edit_outlined,
          label: 'Edit person',
          onTap: () {
            Navigator.pop(sheetContext);
            context.push('/khata/people/${person.id}/edit');
          },
        ),
        ActionSheetTile(
          icon: Icons.person_remove_outlined,
          label: 'Remove person',
          subtitle: hasEntries
              ? 'Only people without entries can be removed'
              : null,
          destructive: true,
          enabled: !hasEntries,
          onTap: () {
            Navigator.pop(sheetContext);
            _delete(context, ref, person);
          },
        ),
      ],
    );
  }

  Future<void> _launch(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
    String failure,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await ref.read(externalLauncherProvider)(uri);
    } catch (_) {}
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(failure)));
  }

  void _showContact(
    BuildContext context,
    WidgetRef ref,
    KhataPersonRow person,
    String? reminder,
  ) {
    final phone = person.phone!;
    final whatsApp = KhataMessages.whatsAppNumber(phone);
    showActionSheet(
      context,
      title: phone,
      actions: (sheetContext) => [
        ActionSheetTile(
          icon: Icons.call_outlined,
          label: 'Call',
          onTap: () {
            Navigator.pop(sheetContext);
            _launch(
              context,
              ref,
              KhataMessages.callUri(phone),
              'No app on this phone can make calls.',
            );
          },
        ),
        ActionSheetTile(
          icon: Icons.chat_outlined,
          label: 'WhatsApp',
          subtitle: whatsApp == null ? 'Not a valid mobile number' : null,
          enabled: whatsApp != null,
          onTap: () {
            Navigator.pop(sheetContext);
            _launch(
              context,
              ref,
              KhataMessages.whatsAppUri(whatsApp!),
              'WhatsApp could not be opened.',
            );
          },
        ),
        if (reminder != null && whatsApp != null)
          ActionSheetTile(
            icon: Icons.notifications_active_outlined,
            label: 'Send reminder on WhatsApp',
            onTap: () {
              Navigator.pop(sheetContext);
              _launch(
                context,
                ref,
                KhataMessages.whatsAppUri(whatsApp, text: reminder),
                'WhatsApp could not be opened.',
              );
            },
          ),
      ],
    );
  }

  void _sendReminder(
    BuildContext context,
    WidgetRef ref,
    KhataPersonRow person,
    String reminder,
  ) {
    final whatsApp = person.phone == null
        ? null
        : KhataMessages.whatsAppNumber(person.phone!);
    if (whatsApp == null) {
      ref.read(textSharerProvider)(reminder);
      return;
    }
    showActionSheet(
      context,
      title: 'Send reminder',
      actions: (sheetContext) => [
        ActionSheetTile(
          icon: Icons.chat_outlined,
          label: 'WhatsApp',
          subtitle: person.phone,
          onTap: () {
            Navigator.pop(sheetContext);
            _launch(
              context,
              ref,
              KhataMessages.whatsAppUri(whatsApp, text: reminder),
              'WhatsApp could not be opened.',
            );
          },
        ),
        ActionSheetTile(
          icon: Icons.share_outlined,
          label: 'Other apps',
          subtitle: 'SMS, email and more',
          onTap: () {
            Navigator.pop(sheetContext);
            ref.read(textSharerProvider)(reminder);
          },
        ),
      ],
    );
  }

  Future<void> _shareStatement(
    BuildContext context,
    WidgetRef ref,
    KhataPersonRow person,
    List<KhataEntryItem> entries,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repayments = await ref
          .read(khataRepositoryProvider)
          .activeRepayments(personId: person.id);
      await ref.read(textSharerProvider)(
        KhataMessages.statement(
          name: person.name,
          entries: entries,
          repayments: repayments,
          today: ref.read(todayProvider),
        ),
        subject: 'MyKhata statement: ${person.name}',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Statement could not be shared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(khataPersonProvider(personId));
    final entries = ref.watch(khataEntriesProvider(personId));
    final summaries = ref.watch(khataPeopleSummariesProvider);
    final hidden = ref.watch(amountsHiddenProvider);
    final scheme = Theme.of(context).colorScheme;
    final summary = summaries.valueOrNull
        ?.where((s) => s.person.id == personId)
        .firstOrNull;
    final row = person.valueOrNull;
    final entryItems = entries.valueOrNull ?? const <KhataEntryItem>[];
    final owedPaise = summary?.receivablePaise ?? 0;
    final reminder = row == null || owedPaise <= 0
        ? null
        : KhataMessages.reminder(
            name: row.name,
            owedPaise: owedPaise,
            dueDate: KhataMessages.earliestDueDate(entryItems),
            today: ref.watch(todayProvider),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(row?.name ?? 'Person'),
        actions: [
          if (row != null)
            IconButton(
              tooltip: 'Person actions',
              onPressed: () => _showMenu(
                context,
                ref,
                row,
                (entries.valueOrNull ?? const []).isNotEmpty,
              ),
              icon: const Icon(Icons.more_vert_rounded),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: person.when(
        loading: () => const SkeletonList(rows: 5),
        error: (error, stack) => ScreenErrorState(
          message: 'Person could not be loaded.',
          onRetry: () => ref.invalidate(khataPersonProvider(personId)),
        ),
        data: (row) {
          if (row == null) {
            return const Center(
              child: EmptyState(
                title: 'Person not found',
                message: 'They may have been removed.',
                icon: Icons.person_off_outlined,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              _PersonHero(
                person: row,
                summary: summary,
                hidden: hidden,
                onPhoneTap: row.phone == null
                    ? null
                    : () => _showContact(context, ref, row, reminder),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _EntryAction(
                      label: 'You gave',
                      caption: 'Lent money',
                      icon: Icons.north_east_rounded,
                      color: scheme.positiveText,
                      onTap: () => context.push(
                        '/khata/entries/new?personId=$personId&direction=$khataLent',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _EntryAction(
                      label: 'You got',
                      caption: 'Borrowed money',
                      icon: Icons.south_west_rounded,
                      color: scheme.negativeText,
                      onTap: () => context.push(
                        '/khata/entries/new?personId=$personId&direction=$khataBorrowed',
                      ),
                    ),
                  ),
                ],
              ),
              if (reminder != null || entryItems.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (reminder != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _sendReminder(context, ref, row, reminder),
                          icon: const Icon(
                            Icons.notifications_active_outlined,
                            size: 18,
                          ),
                          label: const Text('Send reminder'),
                        ),
                      ),
                    if (reminder != null && entryItems.isNotEmpty)
                      const SizedBox(width: AppSpacing.sm),
                    if (entryItems.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _shareStatement(context, ref, row, entryItems),
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('Statement'),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Ledger'),
              const SizedBox(height: AppSpacing.sm),
              entries.when(
                loading: () =>
                    const SkeletonList(rows: 3, padding: EdgeInsets.zero),
                error: (error, stack) => ScreenErrorState(
                  message: 'Entries could not be loaded.',
                  onRetry: () => ref.invalidate(khataEntriesProvider(personId)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return AppCard(
                      child: EmptyState(
                        title: 'No entries yet',
                        message:
                            'Record money you gave to or got from ${row.name}.',
                        icon: Icons.receipt_long_outlined,
                      ),
                    );
                  }
                  final open = items.where((item) => !item.isSettled).toList();
                  final settled = items
                      .where((item) => item.isSettled)
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (open.isNotEmpty)
                        _EntryGroup(items: open, hidden: hidden),
                      if (settled.isNotEmpty) ...[
                        if (open.isNotEmpty)
                          const SizedBox(height: AppSpacing.md),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.xs,
                            bottom: AppSpacing.sm,
                          ),
                          child: Text(
                            'SETTLED',
                            style: AppTypography.metadata.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _EntryGroup(items: settled, hidden: hidden),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonHero extends StatelessWidget {
  const _PersonHero({
    required this.person,
    required this.summary,
    required this.hidden,
    this.onPhoneTap,
  });

  final KhataPersonRow person;
  final KhataPersonSummary? summary;
  final bool hidden;

  /// Opens Call / WhatsApp for the phone number.
  final VoidCallback? onPhoneTap;

  @override
  Widget build(BuildContext context) {
    final net = summary?.netPaise ?? 0;
    final base = personColor(person);
    // Light person colours get dark text and a lighter gradient so both ends
    // keep AA contrast; dark ones keep white text on a darker gradient.
    final fg = readableOn(base);
    final light = fg != Colors.white;
    return GradientCard(
      colors: light
          ? [base, Color.lerp(base, Colors.white, .15)!]
          : [Color.lerp(base, Colors.black, .18)!, base],
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: fg, width: 2),
                ),
                child: PersonAvatar(
                  name: person.name,
                  color: fg.withValues(alpha: .22),
                  size: 48,
                  foreground: fg,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionTitle.copyWith(color: fg),
                    ),
                    if (person.phone != null)
                      Semantics(
                        button: true,
                        label: 'Call or WhatsApp ${person.phone}',
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: onPhoneTap,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppSpacing.touchTarget - 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.call_outlined,
                                  size: 15,
                                  color: fg.withValues(alpha: .9),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  person.phone!,
                                  style: AppTypography.supporting.copyWith(
                                    color: fg.withValues(alpha: .9),
                                    decoration: TextDecoration.underline,
                                    decorationColor: fg.withValues(alpha: .6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            net == 0
                ? 'ALL SETTLED'
                : net > 0
                ? "YOU'LL GET"
                : "YOU'LL GIVE",
            style: AppTypography.metadata.copyWith(
              color: fg.withValues(alpha: .9),
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AmountText(
            hidden ? hiddenAmountMask : MoneyFormatter.formatPaise(net.abs()),
            style: AppTypography.balance.copyWith(color: fg, fontSize: 30),
          ),
          if (summary != null &&
              summary!.receivablePaise > 0 &&
              summary!.payablePaise > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              hidden
                  ? 'Owes you $hiddenAmountMask · You owe $hiddenAmountMask'
                  : 'Owes you ${MoneyFormatter.formatPaise(summary!.receivablePaise)} · You owe ${MoneyFormatter.formatPaise(summary!.payablePaise)}',
              semanticsLabel: hidden
                  ? 'Owes you amount hidden, you owe amount hidden'
                  : null,
              style: AppTypography.supporting.copyWith(
                color: fg.withValues(alpha: .9),
              ),
            ),
          ],
          if (person.note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              person.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.supporting.copyWith(
                color: fg.withValues(alpha: .9),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryAction extends StatelessWidget {
  const _EntryAction({
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.all(AppSpacing.sm + 4),
    child: Row(
      children: [
        IconBadge(icon: icon, color: color, size: 36, iconSize: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.fieldValue.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.metadata.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EntryGroup extends StatelessWidget {
  const _EntryGroup({required this.items, required this.hidden});

  final List<KhataEntryItem> items;
  final bool hidden;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const Divider(height: 1, indent: 68),
          KhataEntryTile(
            item: item,
            hidden: hidden,
            onTap: () => context.push('/khata/entries/${item.entry.id}'),
          ),
        ],
      ],
    ),
  );
}
