import 'package:flutter/material.dart';

import 'design_tokens.dart';

export 'design_tokens.dart';

ButtonStyle _actionButtonStyle(Color foreground, Color background) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, AppSpacing.buttonHeight)),
    maximumSize: const WidgetStatePropertyAll(
      Size(double.infinity, AppSpacing.buttonHeight),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.md),
    ),
    textStyle: const WidgetStatePropertyAll(AppTypography.button),
    foregroundColor: WidgetStatePropertyAll(foreground),
    backgroundColor: WidgetStatePropertyAll(background),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
      ),
    ),
  );
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: dark ? const Color(0xFF30256D) : const Color(0xFFE9E7FF),
    onPrimaryContainer: dark
        ? const Color(0xFFE9E7FF)
        : const Color(0xFF27205D),
    secondary: AppColors.violet,
    onSecondary: Colors.white,
    secondaryContainer: dark
        ? const Color(0xFF39245F)
        : const Color(0xFFF0E8FF),
    onSecondaryContainer: dark
        ? const Color(0xFFEEDFFF)
        : const Color(0xFF342052),
    tertiary: AppColors.positive,
    onTertiary: Colors.white,
    tertiaryContainer: dark ? const Color(0xFF123D32) : const Color(0xFFD8F7EA),
    onTertiaryContainer: dark
        ? const Color(0xFFB9F3DC)
        : const Color(0xFF064E3B),
    error: AppColors.negative,
    onError: Colors.white,
    errorContainer: dark ? const Color(0xFF5B1E2B) : const Color(0xFFFFE4E8),
    onErrorContainer: dark ? const Color(0xFFFFD9DF) : const Color(0xFF881337),
    surface: dark ? AppColors.darkSurface : AppColors.lightSurface,
    onSurface: dark ? AppColors.darkText : AppColors.lightText,
    surfaceContainerHighest: dark
        ? const Color(0xFF252936)
        : const Color(0xFFF0F1F6),
    onSurfaceVariant: dark ? const Color(0xFFB5BAC8) : const Color(0xFF626779),
    outline: dark ? const Color(0xFF555B6D) : const Color(0xFFBFC3CE),
    outlineVariant: dark ? const Color(0xFF343A49) : const Color(0xFFE1E3EB),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: dark ? const Color(0xFFE9EAF0) : const Color(0xFF252936),
    onInverseSurface: dark ? const Color(0xFF252936) : Colors.white,
    inversePrimary: const Color(0xFFB9B4FF),
  );
  final baseText = ThemeData(brightness: brightness).textTheme;
  final textTheme = baseText.copyWith(
    headlineLarge: AppTypography.balance.copyWith(color: scheme.onSurface),
    headlineMedium: AppTypography.screenTitle.copyWith(color: scheme.onSurface),
    headlineSmall: AppTypography.screenTitle.copyWith(color: scheme.onSurface),
    titleLarge: AppTypography.screenTitle.copyWith(color: scheme.onSurface),
    titleMedium: AppTypography.sectionTitle.copyWith(color: scheme.onSurface),
    titleSmall: AppTypography.fieldValue.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: AppTypography.body.copyWith(color: scheme.onSurface),
    bodyMedium: AppTypography.fieldValue.copyWith(color: scheme.onSurface),
    bodySmall: AppTypography.supporting.copyWith(
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: AppTypography.button.copyWith(color: scheme.onSurface),
    labelMedium: AppTypography.fieldLabel.copyWith(color: scheme.onSurface),
    labelSmall: AppTypography.metadata.copyWith(color: scheme.onSurfaceVariant),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? AppColors.darkBackground
        : AppColors.lightBackground,
    canvasColor: dark ? AppColors.darkBackground : AppColors.lightBackground,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: dark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTypography.screenTitle.copyWith(
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 20),
    ),
    textTheme: textTheme,
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      labelStyle: AppTypography.fieldLabel.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      hintStyle: AppTypography.fieldValue.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        AppTypography.metadata.copyWith(fontWeight: FontWeight.w600),
      ),
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  );
}
