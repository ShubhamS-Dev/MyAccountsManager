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
          SizedBox(
            height: AppSpacing.touchTarget,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: notes.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final note = notes[index];
                return Material(
                  key: ValueKey('note-suggestion-$index'),
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: InkWell(
                    onTap: () => onSelected(note),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.supporting.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
