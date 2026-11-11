import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF4F46E5);
  static const navy = Color(0xFF1E1B4B);
  static const violet = Color(0xFF7C3AED);
  static const positive = Color(0xFF10B981);
  static const negative = Color(0xFFF43F5E);

  /// Light-theme text tones for [positive] and [negative]. The bright tones
  /// fail WCAG AA as text on light surfaces, so they stay for fills and icons.
  static const positiveTextLight = Color(0xFF047857);
  static const negativeTextLight = Color(0xFFBE123C);
  static const lightBackground = Color(0xFFF8F9FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF171923);
  static const darkBackground = Color(0xFF0B0D14);
  static const darkSurface = Color(0xFF151925);
  static const darkText = Color(0xFFF4F5FA);

  static const heroGradient = [primary, violet];
  static const accountGradients = [
    [Color(0xFF3730A3), Color(0xFF6D5CE8)],
    [Color(0xFF047857), Color(0xFF10B981)],
    [Color(0xFF9D174D), Color(0xFFEC4899)],
    [Color(0xFF1E40AF), Color(0xFF38BDF8)],
  ];

  /// User-selectable accent colours for people and custom categories.
  static const pickerPalette = [
    primary,
    violet,
    positive,
    negative,
    Color(0xFFF59E0B),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  /// Spoken names for [pickerPalette], in the same order.
  static const pickerPaletteNames = [
    'Indigo',
    'Violet',
    'Emerald',
    'Rose',
    'Amber',
    'Sky',
    'Pink',
    'Teal',
  ];
}

/// Text-safe income/expense colours for the current theme.
extension SemanticTextColors on ColorScheme {
  Color get positiveText => brightness == Brightness.dark
      ? AppColors.positive
      : AppColors.positiveTextLight;

  Color get negativeText => brightness == Brightness.dark
      ? AppColors.negative
      : AppColors.negativeTextLight;
}

/// Black or white, whichever reads better on [background].
Color readableOn(Color background) =>
    background.computeLuminance() > 0.18 ? AppColors.lightText : Colors.white;

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
  static const buttonHeight = 40.0;
  static const touchTarget = 48.0;
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const button = 12.0;
  static const input = 16.0;
  static const card = 22.0;
  static const hero = 26.0;
  static const pill = 100.0;
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0D15172A), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

/// Material 3 type scale. Sizes are logical pixels before the device's
/// font-scale setting, which the app always honours.
abstract final class AppTypography {
  /// App-bar and page titles (M3 titleLarge).
  static const screenTitle = TextStyle(
    fontSize: 22,
    height: 1.27,
    fontWeight: FontWeight.w600,
  );

  /// Section headings (M3 titleMedium).
  static const sectionTitle = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
  );
  static const balance = TextStyle(
    fontSize: 36,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Add Transaction's amount input (M3 headlineMedium).
  static const amountInput = TextStyle(
    fontSize: 28,
    height: 1.29,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Amounts in lists and detail rows (M3 titleMedium).
  static const transactionAmount = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Field labels (M3 labelMedium).
  static const fieldLabel = TextStyle(
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  /// Values, list titles and input text (M3 bodyMedium).
  static const fieldValue = TextStyle(
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.25,
  );

  /// Secondary lines and captions (M3 bodySmall).
  static const supporting = TextStyle(
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  /// Dates, chips and badges (M3 labelMedium).
  static const metadata = TextStyle(
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  /// Button labels (M3 labelLarge).
  static const button = TextStyle(
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Running text (M3 bodyMedium).
  static const body = TextStyle(
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );
}
