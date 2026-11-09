import 'package:flutter/material.dart';

/// Shared visual tokens for the MyAccountsManager premium-minimal UI.
abstract final class AppColors {
  static const primary = Color(0xFF2563EB);
  static const navy = Color(0xFF172554);
  static const positive = Color(0xFF15803D);
  static const negative = Color(0xFFDC2626);
  static const lightBackground = Color(0xFFF5F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE2E8F0);
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
}

abstract final class AppTypography {
  static const screenTitle = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const sectionTitle = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const transactionAmount = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const supporting = TextStyle(
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );
  static const button = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
}

/// All standard Material action buttons have a 40 logical-pixel visual height.
ButtonStyle _actionButtonStyle(Color foreground, Color background) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
    maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 40)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
    textStyle: const WidgetStatePropertyAll(AppTypography.button),
    foregroundColor: WidgetStatePropertyAll(foreground),
    backgroundColor: WidgetStatePropertyAll(background),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final seeded = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  );
  final scheme = seeded.copyWith(
    primary: AppColors.primary,
    secondary: AppColors.navy,
    tertiary: AppColors.positive,
    error: AppColors.negative,
    surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
  );
  final foreground = scheme.onSurface;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTypography.screenTitle.copyWith(color: foreground),
      iconTheme: IconThemeData(color: foreground, size: 20),
    ),
    textTheme: ThemeData(brightness: brightness).textTheme.copyWith(
      headlineLarge: AppTypography.screenTitle.copyWith(
        fontSize: 16,
        color: foreground,
      ),
      headlineMedium: AppTypography.screenTitle.copyWith(color: foreground),
      headlineSmall: AppTypography.screenTitle.copyWith(color: foreground),
      titleLarge: AppTypography.screenTitle.copyWith(color: foreground),
      titleMedium: AppTypography.sectionTitle.copyWith(color: foreground),
      titleSmall: AppTypography.supporting.copyWith(
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      bodyLarge: AppTypography.supporting.copyWith(
        fontSize: 12,
        color: foreground,
      ),
      bodyMedium: AppTypography.supporting.copyWith(color: foreground),
      bodySmall: AppTypography.supporting.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: AppTypography.button.copyWith(color: foreground),
      labelMedium: AppTypography.supporting.copyWith(color: foreground),
      labelSmall: AppTypography.supporting.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _actionButtonStyle(scheme.onPrimary, scheme.primary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _actionButtonStyle(scheme.onPrimary, scheme.primary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _actionButtonStyle(scheme.primary, Colors.transparent).copyWith(
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _actionButtonStyle(scheme.primary, Colors.transparent),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: AppTypography.supporting.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      hintStyle: AppTypography.supporting.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        AppTypography.supporting.copyWith(fontWeight: FontWeight.w600),
      ),
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.7),
      thickness: 1,
      space: 1,
    ),
  );
}
