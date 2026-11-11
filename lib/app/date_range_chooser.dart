import 'package:flutter/material.dart';

import '../core/formatting/date_timestamp.dart';
import '../core/time/day_range.dart';
import 'design_tokens.dart';

/// Preset chips plus a "Custom" chip that opens the date range picker.
/// Shared by History filters and Reports.
class DateRangeChooser extends StatelessWidget {
  const DateRangeChooser({
    required this.value,
    required this.today,
    required this.onChanged,
    this.noneLabel,
    super.key,
  });

  /// The selected range; null selects the [noneLabel] chip.
  final DayRange? value;
  final int today;
  final ValueChanged<DayRange?> onChanged;

  /// Adds a leading chip meaning "no range", e.g. History's month view.
  final String? noneLabel;

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateOnly.fromUtcEpochMilliseconds(today);
    final current = value;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      // Leaves room for Scheduled transactions.
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: current == null
          ? null
          : DateTimeRange(
              start: DateOnly.fromUtcEpochMilliseconds(current.from),
              end: DateOnly.fromUtcEpochMilliseconds(current.through),
            ),
      helpText: 'Select date range',
      saveText: 'Apply',
    );
    if (picked == null) return;
    onChanged(
      DayRange(
        DateOnly.toUtcEpochMilliseconds(picked.start),
        DateOnly.toUtcEpochMilliseconds(picked.end),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = value;
    final preset = current == null
        ? null
        : RangePreset.matching(current, today);
    final custom = current != null && preset == null;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (noneLabel != null)
          ChoiceChip(
            label: Text(noneLabel!),
            selected: current == null,
            onSelected: (_) => onChanged(null),
          ),
        for (final option in RangePreset.values)
          ChoiceChip(
            label: Text(option.label),
            selected: preset == option,
            onSelected: (_) => onChanged(DayRange.preset(option, today)),
          ),
        ChoiceChip(
          avatar: const Icon(Icons.date_range_rounded, size: 18),
          label: Text(custom ? current.label : 'Custom range'),
          selected: custom,
          onSelected: (_) => _pickCustom(context),
        ),
      ],
    );
  }
}
