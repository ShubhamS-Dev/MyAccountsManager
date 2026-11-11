import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../settings_providers.dart';
import 'more_page.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          Text(
            'Choose how MyAccountsManager looks. Your choice is saved on this device.',
            style: AppTypography.supporting.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final (index, mode) in const [
                ThemeMode.system,
                ThemeMode.light,
                ThemeMode.dark,
              ].indexed) ...[
                if (index > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ThemeOption(
                    mode: mode,
                    selected: mode == selected,
                    onTap: () => saveThemeMode(ref, mode),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            child: Row(
              children: [
                Icon(
                  Icons.contrast_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Income stays green and expenses stay red in both themes. Amounts always keep their + or - sign.',
                    style: AppTypography.supporting.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: themeModeLabel(mode),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: .78,
                child: switch (mode) {
                  ThemeMode.light => const _MiniPreview(dark: false),
                  ThemeMode.dark => const _MiniPreview(dark: true),
                  ThemeMode.system => const Row(
                    children: [
                      Expanded(child: _MiniPreview(dark: false, half: true)),
                      Expanded(child: _MiniPreview(dark: true, half: true)),
                    ],
                  ),
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      key: ValueKey(selected),
                      size: 16,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      mode == ThemeMode.system
                          ? 'System'
                          : themeModeLabel(mode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.button,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniature app mock-up used to preview each theme.
class _MiniPreview extends StatelessWidget {
  const _MiniPreview({required this.dark, this.half = false});

  final bool dark;
  final bool half;

  @override
  Widget build(BuildContext context) {
    final background = dark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final line = dark ? const Color(0xFF343A49) : const Color(0xFFE1E3EB);
    final radius = BorderRadius.horizontal(
      left: Radius.circular(half && dark ? 0 : AppRadius.sm),
      right: Radius.circular(half && !dark ? 0 : AppRadius.sm),
    );
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: background, borderRadius: radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 22,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.heroGradient),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 5),
          for (final color in const [AppColors.positive, AppColors.negative])
            Container(
              height: 12,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: line, width: .5),
              ),
              child: Row(
                children: [
                  Container(width: 5, height: 5, color: color),
                  const Spacer(),
                  Container(width: 10, height: 3, color: color),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
