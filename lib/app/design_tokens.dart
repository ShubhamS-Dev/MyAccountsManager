import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF4F46E5);
  static const navy = Color(0xFF1E1B4B);
  static const violet = Color(0xFF7C3AED);
  static const positive = Color(0xFF10B981);
  static const negative = Color(0xFFF43F5E);
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
}

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
    BoxShadow(
      color: Color(0x0D15172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

abstract final class AppTypography {
  static const screenTitle = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static const sectionTitle = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
  static const balance = TextStyle(
    fontSize: 38,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const transactionAmount = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const fieldLabel = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const fieldValue = TextStyle(
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );
  static const supporting = TextStyle(
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );
  static const metadata = TextStyle(
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );
  static const button = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );
}
