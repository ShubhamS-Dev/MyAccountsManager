import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_form_widgets.dart';
import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../app/icon_catalog.dart';
import '../../../app/icon_picker_sheet.dart';
import '../../../app/icon_resolvers.dart';
import '../../../core/database/app_database.dart';
import '../categories_providers.dart';

/// Icon keys understood by [resolveCategoryIcon] offered for categories.
const categoryIconChoices = <String>[
  'food',
  'groceries',
  'shopping',
  'transport',
  'vehicle_maintenance',
  'home',
  'household',
  'health',
  'personal_care',
  'education',
  'travel',
  'entertainment',
  'gift',
  'donations',
  'payments',
  'salary',
  'investments',
  'rental_income',
  'refunds',
  'others',
];

Color categoryColor(CategoryRow category) => category.colorValue == null
    ? (category.type == 'income' ? AppColors.positive : AppColors.negative)
    : Color(category.colorValue!);

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  String _type = 'expense';

  Future<void> _toggle(CategoryRow category) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(categoriesRepositoryProvider)
          .setActive(category.id, active: !category.isActive);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            category.isActive
                ? '${category.name} hidden from new transactions'
                : '${category.name} is available again',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Category could not be updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allCategoriesByTypeProvider(_type));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryEditor(context, type: _type),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category', style: AppTypography.button),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          104,
        ),
        children: [
          AppSegmentedControl<String>(
            selected: _type,
            onChanged: (type) => setState(() => _type = type),
            options: [
              SegmentOption(
                value: 'expense',
                label: 'Expense',
                icon: Icons.north_east_rounded,
                color: scheme.negativeText,
              ),
              SegmentOption(
                value: 'income',
                label: 'Income',
                icon: Icons.south_west_rounded,
                color: scheme.positiveText,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          categories.when(
            loading: () => const SkeletonList(padding: EdgeInsets.zero),
            error: (error, stack) => ScreenErrorState(
              message: 'Categories could not be loaded.',
              onRetry: () => ref.invalidate(allCategoriesByTypeProvider(_type)),
            ),
            data: (items) {
              final active = items.where((c) => c.isActive).toList();
              final hidden = items.where((c) => !c.isActive).toList();
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  key: ValueKey(_type),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${active.length} active · hidden categories stay on past transactions',
                      style: AppTypography.supporting.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CategoryGroup(
                      categories: active,
                      onEdit: (c) =>
                          showCategoryEditor(context, type: _type, existing: c),
                      onToggle: _toggle,
                    ),
                    if (hidden.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const SectionHeader(title: 'Hidden'),
                      const SizedBox(height: AppSpacing.sm),
                      _CategoryGroup(
                        categories: hidden,
                        onEdit: (c) => showCategoryEditor(
                          context,
                          type: _type,
                          existing: c,
                        ),
                        onToggle: _toggle,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.categories,
    required this.onEdit,
    required this.onToggle,
  });

  final List<CategoryRow> categories;
  final ValueChanged<CategoryRow> onEdit;
  final ValueChanged<CategoryRow> onToggle;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const AppCard(
        child: EmptyState(
          title: 'No categories',
          message: 'Add a category to organise your transactions.',
          icon: Icons.category_outlined,
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, category) in categories.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 64),
            InkWell(
              onTap: () => onEdit(category),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Opacity(
                      opacity: category.isActive ? 1 : .5,
                      child: IconBadge(
                        icon: resolveCategoryIcon(
                          category.iconKey ?? category.name,
                          income: category.type == 'income',
                        ),
                        color: categoryColor(category),
                        size: 36,
                        iconSize: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: AppTypography.fieldValue.copyWith(
                              fontWeight: FontWeight.w700,
                              color: category.isActive
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            category.isSystem ? 'Built-in' : 'Custom',
                            style: AppTypography.metadata.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      label: 'Show ${category.name}',
                      child: Switch(
                        value: category.isActive,
                        onChanged: (_) => onToggle(category),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showCategoryEditor(
  BuildContext context, {
  required String type,
  CategoryRow? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _CategoryEditor(type: type, existing: existing),
    ),
  );
}

class _CategoryEditor extends ConsumerStatefulWidget {
  const _CategoryEditor({required this.type, this.existing});

  final String type;
  final CategoryRow? existing;

  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late String _iconKey =
      widget.existing?.iconKey ?? (widget.existing == null ? 'others' : '');
  late int? _colorValue = widget.existing?.colorValue;
  bool _saving = false;
  String? _error;

  bool get _builtIn => widget.existing?.isSystem == true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(categoriesRepositoryProvider);
    final iconKey = _iconKey.isEmpty ? null : _iconKey;
    try {
      if (widget.existing == null) {
        await repository.createCategory(
          name: _nameController.text,
          type: widget.type,
          iconKey: iconKey,
          colorValue: _colorValue,
        );
      } else {
        await repository.updateCategory(
          categoryId: widget.existing!.id,
          name: _nameController.text,
          iconKey: iconKey,
          colorValue: _colorValue,
        );
      }
      if (mounted) Navigator.pop(context);
    } on StateError catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Category could not be saved.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final income = widget.type == 'income';
    final preview = _colorValue == null
        ? (income ? AppColors.positive : AppColors.negative)
        : Color(_colorValue!);
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          children: [
            Row(
              children: [
                IconBadge(
                  icon: resolveCategoryIcon(
                    _iconKey.isEmpty ? _nameController.text : _iconKey,
                    income: income,
                  ),
                  color: preview,
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? 'New ${income ? 'income' : 'expense'} category'
                        : 'Edit category',
                    style: AppTypography.sectionTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(title: 'Name'),
            TextFormField(
              controller: _nameController,
              enabled: !_builtIn,
              autofocus: widget.existing == null,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Pets',
                counterText: '',
                helperText: _builtIn
                    ? 'Built-in names are fixed. You can change the icon and colour.'
                    : null,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a category name.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(title: 'Icon'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                // A key picked from the full catalog shows first, selected.
                if (_iconKey.isNotEmpty &&
                    !categoryIconChoices.contains(_iconKey))
                  _IconChoice(
                    label: _iconLabel(_iconKey),
                    icon: resolveCategoryIcon(_iconKey, income: income),
                    selected: true,
                    color: preview,
                    onTap: () {},
                  ),
                for (final key in categoryIconChoices)
                  _IconChoice(
                    label: _iconLabel(key),
                    icon: resolveCategoryIcon(key, income: income),
                    selected: _iconKey == key,
                    color: preview,
                    onTap: () => setState(() => _iconKey = key),
                  ),
                _IconChoice(
                  key: const ValueKey('category-more-icons'),
                  label: 'More icons',
                  icon: Icons.grid_view_rounded,
                  selected: false,
                  color: preview,
                  onTap: () async {
                    final picked = await showIconPickerSheet(
                      context,
                      selected: _iconKey,
                      color: preview,
                    );
                    if (picked != null && mounted) {
                      setState(() => _iconKey = picked);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldHeading(title: 'Colour'),
            ColorChoiceRow(
              selected: _colorValue,
              onChanged: (value) => setState(() => _colorValue = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              FormErrorBanner(_error!),
            ],
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: widget.existing == null ? 'Add category' : 'Save changes',
              icon: Icons.check_rounded,
              gradient: AppColors.heroGradient,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// "personal_care" -> "Personal care icon", for screen readers.
String _iconLabel(String key) {
  final catalogLabel = catalogIconFor(key)?.label;
  if (catalogLabel != null) return '$catalogLabel icon';
  final words = key.replaceAll('_', ' ');
  return '${words[0].toUpperCase()}${words.substring(1)} icon';
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .14) : null,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: selected ? color : scheme.outlineVariant),
          ),
          child: Icon(
            icon,
            size: 19,
            color: selected ? color : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
