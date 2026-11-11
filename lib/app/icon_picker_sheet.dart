import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'icon_catalog.dart';

/// Opens the searchable icon catalog as a bottom sheet (about three quarters
/// of the screen, never full screen). Resolves to the picked key, or null.
Future<String?> showIconPickerSheet(
  BuildContext context, {
  required String? selected,
  required Color color,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
  ),
  builder: (sheetContext) => SizedBox(
    height: MediaQuery.sizeOf(sheetContext).height * .76,
    child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _IconPicker(selected: canonicalIconKey(selected), color: color),
    ),
  ),
);

class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.selected, required this.color});

  final String? selected;
  final Color color;

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  String _query = '';

  /// Null means every group.
  String? _group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _query.trim();
    final groups = _group == null
        ? iconCatalog
        : iconCatalog.where((group) => group.label == _group).toList();
    final List<Widget> slivers;
    if (query.isNotEmpty) {
      final matches = [
        for (final group in groups)
          ...group.icons.where((icon) => icon.matches(query)),
      ];
      slivers = matches.isEmpty
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No icons match "$query".',
                    style: AppTypography.supporting.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ]
          : [_grid(matches)];
    } else {
      slivers = [
        for (final group in groups) ...[
          if (_group == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.sm,
                ),
                child: Text(
                  group.label.toUpperCase(),
                  style: AppTypography.metadata.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ),
          _grid(group.icons),
        ],
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('Choose an icon', style: AppTypography.sectionTitle),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextField(
            key: const ValueKey('icon-picker-search'),
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search icons, e.g. pets, fuel, rent',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide(color: scheme.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _GroupChip(
                label: 'All',
                selected: _group == null,
                onTap: () => setState(() => _group = null),
              ),
              for (final group in iconCatalog)
                _GroupChip(
                  label: group.label,
                  selected: _group == group.label,
                  onTap: () => setState(() => _group = group.label),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                ...slivers,
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _grid(List<AppIconOption> icons) => SliverGrid(
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 84,
      mainAxisExtent: 82,
      crossAxisSpacing: AppSpacing.xs,
      mainAxisSpacing: AppSpacing.xs,
    ),
    delegate: SliverChildBuilderDelegate(
      (context, index) => _IconTile(
        option: icons[index],
        selected: icons[index].key == widget.selected,
        color: widget.color,
      ),
      childCount: icons.length,
    ),
  );
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.xs),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    ),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.option,
    required this.selected,
    required this.color,
  });

  final AppIconOption option;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} icon',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('icon-option-${option.key}'),
        onTap: () => Navigator.of(context).pop(option.key),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.button + 2),
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, Color.lerp(color, Colors.white, .25)!],
                      )
                    : null,
                color: selected ? null : scheme.surfaceContainerHighest,
              ),
              child: Icon(
                option.icon,
                size: 24,
                color: selected ? Colors.white : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.metadata.copyWith(
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
