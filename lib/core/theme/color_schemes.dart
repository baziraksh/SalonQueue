import 'package:flutter/material.dart';

/// Premium Salon Queue color palette.
///
/// Navy (#14243A) + Gold (#C9A45C) + Warm Ivory (#FAF8F5)
/// Designed for a luxury salon marketplace aesthetic.
class AppColorSchemes {
  AppColorSchemes._();

  // ── Brand Colors ─────────────────────────────────────────────────────────
  static const Color navy = Color(0xFF14243A);
  static const Color navyLight = Color(0xFF1E3650);
  static const Color gold = Color(0xFFC9A45C);
  static const Color goldLight = Color(0xFFDDC088);
  static const Color ivory = Color(0xFFFAF8F5);
  static const Color charcoal = Color(0xFF1A1D26);
  static const Color warmGrey = Color(0xFF6B7280);
  static const Color cardWhite = Color(0xFFFFFFFF);

  // ── Status Colors ────────────────────────────────────────────────────────
  static const Color available = Color(0xFF2E7D32);
  static const Color busy = Color(0xFFC62828);
  static const Color moderate = Color(0xFFE65100);

  /// Light color scheme for the app
  static const ColorScheme lightScheme = ColorScheme.light(
    primary: navy,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD6E3F8),
    onPrimaryContainer: Color(0xFF0A1929),
    secondary: gold,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFF3DB),
    onSecondaryContainer: Color(0xFF3D2E00),
    tertiary: Color(0xFF4A6741),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFCCEEBE),
    onTertiaryContainer: Color(0xFF082105),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    outline: Color(0xFFD1D5DB),
    surface: ivory,
    onSurface: charcoal,
    surfaceContainerHighest: Color(0xFFF0EDE8),
    onSurfaceVariant: warmGrey,
  );

  /// Dark color scheme for the app
  static const ColorScheme darkScheme = ColorScheme.dark(
    primary: goldLight,
    onPrimary: Color(0xFF1A1200),
    primaryContainer: Color(0xFF4D3D00),
    onPrimaryContainer: Color(0xFFFFF3DB),
    secondary: Color(0xFF9BB8D8),
    onSecondary: Color(0xFF0A1929),
    secondaryContainer: Color(0xFF1E3650),
    onSecondaryContainer: Color(0xFFD6E3F8),
    tertiary: Color(0xFFB1D3A4),
    onTertiary: Color(0xFF1D361A),
    tertiaryContainer: Color(0xFF334E2F),
    onTertiaryContainer: Color(0xFFCCEEBE),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    outline: Color(0xFF4B5563),
    surface: Color(0xFF111827),
    onSurface: Color(0xFFF3F4F6),
    surfaceContainerHighest: Color(0xFF1F2937),
    onSurfaceVariant: Color(0xFF9CA3AF),
  );
}