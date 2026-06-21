import 'package:flutter/material.dart';

/// Single source of truth for all visual constants.
/// Use these instead of hardcoded hex literals anywhere in the app.
class DesignTokens {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const brandPrimary      = Color(0xFF00897B); // Teal 600
  static const brandPrimaryDark  = Color(0xFF005B4F); // Teal 900
  static const brandPrimaryLight = Color(0xFFB2DFDB); // Teal 100

  // Role accents — only for role-specific headers / identity UI
  static const doctorAccent  = Color(0xFF1565C0); // Blue 800
  static const patientAccent = Color(0xFF1976D2); // Blue 700
  static const adminAccent   = Color(0xFF37474F); // Blue Grey 800

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF57F17);
  static const error   = Color(0xFFC62828);
  static const info    = Color(0xFF1565C0);

  static const successLight = Color(0xFFE8F5E9);
  static const warningLight = Color(0xFFFFF8E1);
  static const errorLight   = Color(0xFFFFEBEE);
  static const infoLight    = Color(0xFFE3F2FD);

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const surface0 = Color(0xFFFFFFFF); // cards / modals
  static const surface1 = Color(0xFFF4F6F9); // page background
  static const surface2 = Color(0xFFE9ECF1); // dividers, input fills

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1A2332);
  static const textSecondary = Color(0xFF6B7280);
  static const textDisabled  = Color(0xFFB0BEC5);
  static const textOnBrand   = Color(0xFFFFFFFF);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const borderLight  = Color(0xFFE5E7EB);
  static const borderMedium = Color(0xFFD1D5DB);

  // ── Spacing scale ─────────────────────────────────────────────────────────
  static const sp2  = 2.0;
  static const sp4  = 4.0;
  static const sp8  = 8.0;
  static const sp12 = 12.0;
  static const sp16 = 16.0;
  static const sp20 = 20.0;
  static const sp24 = 24.0;
  static const sp32 = 32.0;
  static const sp48 = 48.0;
  static const sp64 = 64.0;

  // ── Corner radii ──────────────────────────────────────────────────────────
  static const radiusXs = 4.0;
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 24.0;
  static const radiusFull = 999.0;

  // ── Touch targets ─────────────────────────────────────────────────────────
  /// Minimum interactive size per iOS HIG & MD3 (44 × 44 dp).
  static const minTouchTarget = 44.0;

  // ── Elevation shadows ─────────────────────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
    const BoxShadow(
        color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> get shadowMd => [
    const BoxShadow(
        color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> get shadowLg => [
    const BoxShadow(
        color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient doctorHeaderGradient = LinearGradient(
    colors: [Color(0xFF1A3A5C), Color(0xFF2C5F8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient patientHeaderGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF00897B), Color(0xFF004D40)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
