import 'package:flutter/material.dart';

enum AppThemeVariant { light, dark }

class AppColors {
  static AppThemeVariant _variant = AppThemeVariant.light;

  static void setVariant(AppThemeVariant variant) {
    _variant = variant;
  }

  static bool get isDark => _variant == AppThemeVariant.dark;

  // ── Background layers
  static const Color backgroundLight = Color(0xFFF7F9FC); // layer 0
  static const Color surfaceLight = Color(0xFFFFFFFF); // layer 1
  static const Color surfaceVariantLight = Color(0xFFF1F4F9); // subtle tint

  // Dark tokens ("black" variant)
  static const Color backgroundDark = Color(0xFF0B0F14);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color surfaceVariantDark = Color(0xFF0F172A);

  static Color get background => isDark ? backgroundDark : backgroundLight;
  static Color get surface => isDark ? surfaceDark : surfaceLight;
  static Color get surfaceVariant =>
      isDark ? surfaceVariantDark : surfaceVariantLight;

  // ── Brand
  static const Color accent        = Color(0xFF387EBC);
  static const Color accentDark    = Color(0xFF286DA0);
  static const Color accentLight   = Color(0xFFE7F1FB); // tint for active bg

  // ── Ink
  static const Color inkLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textMutedLight = Color(0xFF9CA3AF);

  static const Color inkDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textMutedDark = Color(0xFF94A3B8);

  static Color get ink => isDark ? inkDark : inkLight;
  static Color get textSecondary =>
      isDark ? textSecondaryDark : textSecondaryLight;
  static Color get textMuted => isDark ? textMutedDark : textMutedLight;

  // ── Borders
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF1F2937);
  static const Color borderFocusLight = Color(0xFF387EBC);
  static const Color borderFocusDark = Color(0xFF387EBC);

  static Color get border => isDark ? borderDark : borderLight;
  static Color get borderFocus => isDark ? borderFocusDark : borderFocusLight;

  // ── Semantic
  static const Color error         = Color(0xFFE5484D);
  static const Color errorLight    = Color(0xFFFFF0F0);
  static const Color success       = Color(0xFF2FBF71);
  static const Color successLight  = Color(0xFFECFDF5);
  static const Color warning       = Color(0xFFF5A524);
  static const Color warningLight  = Color(0xFFFFFBEB);

  // ── Utility
  static const Color white         = Color(0xFFFFFFFF);
  static const Color black         = Color(0xFF000000);

  // ── Sidebar
  static const Color sidebar          = Color(0xFF1F2937);
  static const Color sidebarActive    = Color(0xFF387EBC);
  static const Color sidebarText      = Color(0xFFFFFFFF);
  static const Color sidebarTextMuted = Color(0xFF9CA3AF);
}
