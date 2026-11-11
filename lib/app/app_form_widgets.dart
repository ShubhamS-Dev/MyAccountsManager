import 'package:flutter/material.dart';

import '../core/formatting/date_timestamp.dart';
import '../core/formatting/indian_amount_input_formatter.dart';
import '../core/formatting/money_formatter.dart';
import 'app_theme.dart';
import 'app_widgets.dart';

/// Shared form and feedback building blocks used by forms outside
/// Add Transaction. All values come from the design tokens.

/// `Today` for the device's current local calendar date, else DD MMM YYYY.
String dateLabel(DateTime date) {
  final now = DateTime.now();
  final today =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return today
      ? 'Today'
      : DateOnly.format(DateOnly.toUtcEpochMilliseconds(date));
}

/// Converts a stored UTC-midnight date into a local calendar DateTime for
/// pickers, without timezone shifting.
DateTime localDateFromStored(int timestamp) {
  final utc = DateOnly.fromUtcEpochMilliseconds(timestamp);
  return DateTime(utc.year, utc.month, utc.day);
}

class FieldHeading extends StatelessWidget {
  const FieldHeading({required this.title, super.key, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.fieldLabel.copyWith(color: scheme.onSurface),
          ),
          if (hint != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.metadata.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({
    required this.icon,
    required this.color,
    super.key,
    this.size = 40,
    this.iconSize = 19,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(AppRadius.sm + 4),
    ),
    child: Icon(icon, color: color, size: iconSize),
  );
}

class SegmentOption<T> {
  const SegmentOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Semantic accent for the selected state; defaults to the primary colour.
  final Color? color;
}

/// Animated pill selector matching the Add Transaction type control.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final index = options.indexWhere((option) => option.value == selected);
    final accent = options[index].color ?? scheme.primary;
    return Container(
      height: AppSpacing.touchTarget,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: width * index,
                top: 0,
                bottom: 0,
                width: width,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: .28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: option.value == selected,
                        child: InkWell(
                          onTap: () => onChanged(option.value),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Center(
                            child: _SegmentLabel(
                              option: option,
                              selected: option.value == selected,
                              accent: accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({
    required this.option,
    required this.selected,
    required this.accent,
  });

  final SegmentOption<T> option;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? readableOn(accent) : scheme.onSurfaceVariant;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 160),
      style: AppTypography.button.copyWith(color: color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (option.icon != null) ...[
            Icon(option.icon, size: 15, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Today / Yesterday / Pick date shortcuts with the shared date label.
class DateShortcutField extends StatelessWidget {
  const DateShortcutField({
    required this.title,
    required this.date,
    required this.onChanged,
    super.key,
    this.firstDate,
    this.lastDate,
  });

  final String title;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pick(BuildContext context) async {
    final first = firstDate ?? DateTime(2000);
    final last = lastDate ?? DateTime(2100);
    var initial = DateTime(date.year, date.month, date.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final isToday = _same(date, today);
    final isYesterday = _same(date, yesterday);
    final first = firstDate;
    bool allowed(DateTime value) => first == null || !value.isBefore(first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldHeading(title: title),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (allowed(today))
              _DateChoice(
                label: 'Today',
                selected: isToday,
                onTap: () => onChanged(today),
              ),
            if (allowed(yesterday))
              _DateChoice(
                label: 'Yesterday',
                selected: isYesterday,
                onTap: () => onChanged(yesterday),
              ),
            _DateChoice(
              label: 'Pick date',
              icon: Icons.calendar_month_rounded,
              selected: !isToday && !isYesterday,
              onTap: () => _pick(context),
            ),
          ],
        ),
        if (!isToday) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateLabel(date),
            style: AppTypography.metadata.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: AppTypography.button.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parses an amount field into integer paise, or null when invalid.
int? parseAmountPaise(String text, {bool allowSign = false}) {
  final value = text.trim();
  if (value.isEmpty || value == '-' || value == '+') return null;
  if (!allowSign && (value.startsWith('-') || value.startsWith('+'))) {
    return null;
  }
  try {
    return MoneyFormatter.parseRupeesToPaise(value);
  } on FormatException {
    return null;
  }
}

/// Rupee amount field with live Indian grouping and 16px amount typography.
class AmountFormField extends StatelessWidget {
  const AmountFormField({
    required this.controller,
    super.key,
    this.hint = '0',
    this.allowSign = false,
    this.accent,
    this.validator,
    this.helper,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool allowSign;
  final Color? accent;
  final FormFieldValidator<String>? validator;
  final String? helper;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.onSurface;
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: allowSign,
      ),
      inputFormatters: [IndianAmountInputFormatter(allowSign: allowSign)],
      style: AppTypography.transactionAmount.copyWith(color: color),
      decoration: InputDecoration(
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        errorMaxLines: 2,
        hintStyle: AppTypography.transactionAmount.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: .6),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md, right: 6),
          child: Text(
            '₹',
            style: AppTypography.transactionAmount.copyWith(color: color),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
      ),
      validator: validator,
    );
  }
}

/// Inline error banner for failed saves.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: scheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.supporting.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom save action that stays above the keyboard.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: child,
        ),
      ),
    );
  }
}

class ColorChoiceRow extends StatelessWidget {
  const ColorChoiceRow({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// Selected ARGB value, or null for the default colour.
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _Swatch(
          label: 'Default colour',
          selected: selected == null,
          onTap: () => onChanged(null),
          fill: scheme.surfaceContainerHighest,
          icon: Icons.format_color_reset_outlined,
          iconColor: scheme.onSurfaceVariant,
        ),
        for (final (index, color) in AppColors.pickerPalette.indexed)
          _Swatch(
            label: AppColors.pickerPaletteNames[index],
            selected: selected == color.toARGB32(),
            onTap: () => onChanged(color.toARGB32()),
            fill: color,
            icon: selected == color.toARGB32() ? Icons.check_rounded : null,
            iconColor: readableOn(color),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.fill,
    required this.iconColor,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color fill;
  final IconData? icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: AppSpacing.touchTarget,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 2,
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: icon == null
                  ? null
                  : Icon(icon, size: 16, color: iconColor),
            ),
          ),
        ),
      ),
    ),
  );
}

class ActionSheetTile extends StatelessWidget {
  const ActionSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
    this.destructive = false,
    this.enabled = true,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = !enabled
        ? scheme.onSurfaceVariant
        : destructive
        ? scheme.error
        : scheme.onSurface;
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      minTileHeight: AppSpacing.touchTarget,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: AppTypography.fieldValue.copyWith(color: color),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.metadata.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}

/// Premium modal action sheet with a title and action tiles.
Future<void> showActionSheet(
  BuildContext context, {
  required String title,
  required List<Widget> Function(BuildContext sheetContext) actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sectionTitle,
              ),
            ),
            ...actions(sheetContext),
          ],
        ),
      ),
    ),
  );
}

/// Confirmation dialog for destructive or significant actions.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(title, style: AppTypography.screenTitle),
      content: Text(message, style: AppTypography.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Full-screen error state with retry.
class ScreenErrorState extends StatelessWidget {
  const ScreenErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        child: EmptyState(
          title: 'Something went wrong',
          message: message,
          icon: Icons.cloud_off_rounded,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ),
    ),
  );
}

/// Pulsing placeholder rows for list loading states.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 4, this.padding});

  final int rows;
  final EdgeInsetsGeometry? padding;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.md),
      child: FadeTransition(
        opacity: Tween<double>(begin: .45, end: 1).animate(_controller),
        child: Column(
          children: [
            for (var i = 0; i < widget.rows; i++)
              Container(
                height: 64,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks before back navigation discards unsaved form input.
///
/// Pass `dirty: false` while saving so the post-save pop is not blocked.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    required this.dirty,
    required this.child,
    super.key,
  });

  final bool dirty;
  final Widget child;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _discarded = false;

  Future<void> _confirmDiscard() async {
    final discard = await confirmAction(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes. They will be lost if you leave.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!discard || !mounted) return;
    // Let the PopScope rebuild with canPop: true before popping.
    setState(() => _discarded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _discarded || !widget.dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmDiscard();
    },
    child: widget.child,
  );
}
