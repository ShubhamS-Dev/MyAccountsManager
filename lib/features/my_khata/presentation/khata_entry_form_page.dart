import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/privacy_state.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../data/khata_repository.dart';
import '../khata_providers.dart';
import 'khata_widgets.dart';

/// Add Khata Entry, or Edit when [entryId] is supplied.
class KhataEntryFormPage extends ConsumerStatefulWidget {
  const KhataEntryFormPage({
    super.key,
    this.entryId,
    this.initialPersonId,
    this.initialDirection,
  });

  final String? entryId;
  final String? initialPersonId;
  final String? initialDirection;

  @override
  ConsumerState<KhataEntryFormPage> createState() => _KhataEntryFormPageState();
}

class _KhataEntryFormPageState extends ConsumerState<KhataEntryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late String _direction = widget.initialDirection == khataBorrowed
      ? khataBorrowed
      : khataLent;
  late String? _personId = widget.initialPersonId;
  DateTime _date = _today();
  DateTime? _dueDate;
  int _repaidPaise = 0;
  bool _initialized = false;
  bool _saving = false;

  // Unsaved-changes tracking for the back-navigation guard.
  String? _pristine;
  String get _snapshot => [
    _amountController.text,
    _noteController.text,
    _direction,
    _personId,
    _date,
    _dueDate,
  ].join('\u0000');
  bool get _dirty => !_saving && _pristine != null && _snapshot != _pristine;
  String? _error;

  bool get _editing => widget.entryId != null;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _initialized = !_editing;
    if (!_editing) _pristine = _snapshot;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_personId == null) {
      setState(() => _error = 'Select a person.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final amount = parseAmountPaise(_amountController.text)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(khataRepositoryProvider);
    final entryDate = DateOnly.toUtcEpochMilliseconds(_date);
    final dueDate = _dueDate == null
        ? null
        : DateOnly.toUtcEpochMilliseconds(_dueDate!);
    try {
      if (_editing) {
        await repository.updateEntry(
          entryId: widget.entryId!,
          amountPaise: amount,
          entryDate: entryDate,
          dueDate: dueDate,
          note: _noteController.text,
        );
      } else {
        await repository.createEntry(
          personId: _personId!,
          direction: _direction,
          amountPaise: amount,
          entryDate: entryDate,
          dueDate: dueDate,
          note: _noteController.text,
        );
      }
      if (mounted) context.pop();
    } on StateError catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Entry could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      UnsavedChangesGuard(dirty: _dirty, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    if (!_initialized) return _buildLoader();

    final people = ref.watch(khataPeopleSummariesProvider);
    final accent = khataDirectionColor(context, _direction);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit entry' : 'New khata entry')),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          children: [
            if (_editing)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm + 4),
                child: Row(
                  children: [
                    IconBadge(
                      icon: khataDirectionIcon(_direction),
                      color: accent,
                      size: 36,
                      iconSize: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        '${khataDirectionLabel(_direction)} · person and direction are fixed after creation.',
                        style: AppTypography.supporting.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              AppSegmentedControl<String>(
                selected: _direction,
                onChanged: (value) => setState(() => _direction = value),
                options: [
                  SegmentOption(
                    value: khataLent,
                    label: 'You gave',
                    icon: Icons.north_east_rounded,
                    color: scheme.positiveText,
                  ),
                  SegmentOption(
                    value: khataBorrowed,
                    label: 'You got',
                    icon: Icons.south_west_rounded,
                    color: scheme.negativeText,
                  ),
                ],
              ),
            if (!_editing) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _direction == khataLent
                    ? 'They will owe you this amount.'
                    : 'You will owe them this amount.',
                textAlign: TextAlign.center,
                style: AppTypography.metadata.copyWith(color: accent),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (!_editing) ...[
              const FieldHeading(title: 'Person'),
              people.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => const Text('People unavailable.'),
                data: (items) {
                  if (items.isEmpty) {
                    return AppCard(
                      child: EmptyState(
                        title: 'No people yet',
                        message: 'Add a person before recording an entry.',
                        icon: Icons.person_add_alt_1_outlined,
                        actionLabel: 'Add person',
                        onAction: () => context.push('/khata/people/new'),
                      ),
                    );
                  }
                  return SizedBox(
                    height: 50 + MediaQuery.textScalerOf(context).scale(26),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final person = items[index].person;
                        return _PersonChoice(
                          name: person.name,
                          color: personColor(person),
                          selected: person.id == _personId,
                          onTap: () => setState(() {
                            _personId = person.id;
                            _error = null;
                          }),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            DateShortcutField(
              title: 'Date',
              date: _date,
              // Khata entries record money that has already moved.
              lastDate: _today(),
              onChanged: (date) => setState(() {
                _date = date;
                if (_dueDate != null && _dueDate!.isBefore(date)) {
                  _dueDate = null;
                }
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            const FieldHeading(title: 'Note', hint: 'Optional'),
            TextFormField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What was it for?',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FieldHeading(
              title: 'Amount',
              hint: _repaidPaise > 0
                  ? ref.watch(amountsHiddenProvider)
                        ? 'Part already repaid'
                        : 'At least ${MoneyFormatter.formatPaise(_repaidPaise)} already repaid'
                  : null,
            ),
            AmountFormField(
              key: const ValueKey('khata-entry-amount'),
              controller: _amountController,
              accent: accent,
              validator: (value) {
                final amount = parseAmountPaise(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter an amount greater than zero.';
                }
                if (amount <= _repaidPaise) {
                  return ref.read(amountsHiddenProvider)
                      ? 'Amount must be more than what is already repaid.'
                      : 'Amount must be more than the ${MoneyFormatter.formatPaise(_repaidPaise)} already repaid.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            const FieldHeading(title: 'Due date', hint: 'Optional reminder'),
            _DueDateField(
              dueDate: _dueDate,
              firstDate: _date,
              onChanged: (value) => setState(() => _dueDate = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              FormErrorBanner(_error!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        child: PrimaryButton(
          label: _editing ? 'Save changes' : 'Save entry',
          icon: Icons.check_rounded,
          gradient: AppColors.heroGradient,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    final entry = ref.watch(khataEntryProvider(widget.entryId!));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit entry')),
      body: entry.when(
        loading: () => const SkeletonList(rows: 4),
        error: (error, stack) => ScreenErrorState(
          message: 'Entry could not be loaded.',
          onRetry: () => ref.invalidate(khataEntryProvider(widget.entryId!)),
        ),
        data: (item) {
          if (item == null) {
            return const Center(
              child: EmptyState(
                title: 'Entry not found',
                message: 'It may have been deleted.',
                icon: Icons.search_off_rounded,
              ),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _initialized) return;
            final row = item.entry;
            setState(() {
              _direction = row.direction;
              _personId = row.personId;
              _date = localDateFromStored(row.entryDate);
              _dueDate = row.dueDate == null
                  ? null
                  : localDateFromStored(row.dueDate!);
              _noteController.text = row.note ?? '';
              _amountController.text = MoneyFormatter.formatPaise(
                row.amountPaise,
                includeSymbol: false,
              );
              _repaidPaise = item.repaidPaise;
              _initialized = true;
              _pristine = _snapshot;
            });
          });
          return const SkeletonList(rows: 4);
        },
      ),
    );
  }
}

class _PersonChoice extends StatelessWidget {
  const _PersonChoice({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .12) : scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PersonAvatar(name: name, color: color, size: 34),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metadata.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueDateField extends StatelessWidget {
  const _DueDateField({
    required this.dueDate,
    required this.firstDate,
    required this.onChanged,
  });

  final DateTime? dueDate;
  final DateTime firstDate;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final initial = dueDate ?? firstDate.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => _pick(context),
      radius: AppRadius.input,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_outlined,
            size: 18,
            color: dueDate == null ? scheme.onSurfaceVariant : scheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              dueDate == null ? 'No due date' : dateLabel(dueDate!),
              style: AppTypography.fieldValue.copyWith(
                color: dueDate == null
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
              ),
            ),
          ),
          if (dueDate != null)
            IconButton(
              tooltip: 'Clear due date',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close_rounded, size: 18),
            )
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}
