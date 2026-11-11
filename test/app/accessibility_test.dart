import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_form_widgets.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/app_widgets.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

void main() {
  group('contrast', () {
    final light = buildAppTheme(brightness: Brightness.light).colorScheme;
    final dark = buildAppTheme(brightness: Brightness.dark).colorScheme;

    test('income and expense text tones pass AA on both themes', () {
      for (final background in [
        AppColors.lightSurface,
        AppColors.lightBackground,
        light.tertiaryContainer,
        light.errorContainer,
      ]) {
        expect(contrast(light.positiveText, background), greaterThan(4.5));
        expect(contrast(light.negativeText, background), greaterThan(4.5));
      }
      for (final background in [
        AppColors.darkSurface,
        AppColors.darkBackground,
      ]) {
        expect(contrast(dark.positiveText, background), greaterThan(4.5));
        expect(contrast(dark.negativeText, background), greaterThan(4.5));
      }
      // The theme's own tertiary/error follow the text-safe tones.
      expect(light.tertiary, AppColors.positiveTextLight);
      expect(light.error, AppColors.negativeTextLight);
    });

    test('readableOn passes AA on every picker colour', () {
      for (final color in AppColors.pickerPalette) {
        expect(
          contrast(readableOn(color), color),
          greaterThan(4.5),
          reason: '$color',
        );
      }
      expect(readableOn(const Color(0xFFF59E0B)), AppColors.lightText);
      expect(readableOn(AppColors.primary), Colors.white);
    });
  });

  test('masked amounts are spoken as "amount hidden"', () {
    expect(maskedAmountSemantics(hiddenAmountMask), 'amount hidden');
    expect(maskedAmountSemantics('Due $hiddenAmountMask'), 'Due amount hidden');
    expect(maskedAmountSemantics('₹1,500'), isNull);
  });

  testWidgets('colour swatches are named, 48dp and include Default', (
    tester,
  ) async {
    int? picked = AppColors.pickerPalette.first.toARGB32();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ColorChoiceRow(
              selected: picked,
              onChanged: (value) => setState(() => picked = value),
            ),
          ),
        ),
      ),
    );

    for (final name in ['Default colour', ...AppColors.pickerPaletteNames]) {
      expect(find.bySemanticsLabel(name), findsOneWidget, reason: name);
    }
    expect(
      tester.getSize(find.bySemanticsLabel('Amber')),
      const Size.square(AppSpacing.touchTarget),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Indigo')),
      matchesSemantics(
        label: 'Indigo',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.bySemanticsLabel('Default colour'));
    await tester.pump();
    expect(picked, isNull);
    semantics.dispose();
  });

  testWidgets('AmountText announces a mask as "amount hidden"', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: AmountText(hiddenAmountMask)),
    );
    expect(find.bySemanticsLabel('amount hidden'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('selected segment text stays readable on its accent', (
    tester,
  ) async {
    for (final theme in [
      buildAppTheme(brightness: Brightness.light),
      buildAppTheme(brightness: Brightness.dark),
    ]) {
      final accent = theme.colorScheme.positiveText;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: AppSegmentedControl<bool>(
              selected: true,
              onChanged: (_) {},
              options: [
                SegmentOption(value: true, label: 'Income', color: accent),
                const SegmentOption(value: false, label: 'Expense'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final style = DefaultTextStyle.of(
        tester.element(find.text('Income')),
      ).style;
      expect(contrast(style.color!, accent), greaterThan(4.5));
    }
  });
}
