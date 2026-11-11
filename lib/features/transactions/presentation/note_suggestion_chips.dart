import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

/// Horizontal row of tappable past notes shown under a Note field.
/// Renders nothing when [notes] is empty.
class NoteSuggestionChips extends StatelessWidget {
  const NoteSuggestionChips({
    super.key,
    required this.label,
    required this.notes,
    required this.onSelected,
  });

  final String label;
  final List<String> notes;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.metadata.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Chips size to their text; the row scrolls when it overflows.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < notes.length; index++) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.sm),
                  Material(
                    key: ValueKey('note-suggestion-$index'),
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      onTap: () => onSelected(notes[index]),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + AppSpacing.xs,
                          vertical: AppSpacing.xs + 2,
                        ),
                        child: Text(
                          notes[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.fieldValue.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
