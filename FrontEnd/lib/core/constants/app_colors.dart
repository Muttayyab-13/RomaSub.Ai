import 'package:flutter/material.dart';

/// App color palette with Light and Dark theme support
class AppColors {
  // ============================================================================
  // LIGHT THEME COLORS
  // ============================================================================

  // Primary Colors
  static const Color primary = Color(0xFF000000);
  static const Color primaryLight = Color(0xFF333333);

  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F5);

  // Accent Colors
  static const Color accent = Color(0xFF333333);
  static const Color accentLight = Color(0xFFE5E5E5);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Status Colors (same for both themes)
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Border & Divider
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Sidebar
  static const Color sidebarBg = Color(0xFF1F2937);
  static const Color sidebarText = Color(0xFFE5E7EB);
  static const Color sidebarActive = Color(0xFF374151);

  // ============================================================================
  // DARK THEME COLORS (Inverted)
  // ============================================================================

  // Primary Colors
  static const Color primaryDark = Color(0xFFFFFFFF);
  static const Color primaryLightDark = Color(0xFFCCCCCC);

  // Background Colors
  static const Color backgroundDark = Color(0xFF0F0F0F);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceVariantDark = Color(0xFF2A2A2A);

  // Accent Colors
  static const Color accentDark = Color(0xFFCCCCCC);
  static const Color accentLightDark = Color(0xFF3A3A3A);

  // Text Colors
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textHintDark = Color(0xFF6B7280);

  // Border & Divider
  static const Color borderDark = Color(0xFF374151);
  static const Color dividerDark = Color(0xFF2A2A2A);

  // Sidebar (stays dark, but slightly lighter in dark mode)
  static const Color sidebarBgDark = Color(0xFF111111);
  static const Color sidebarTextDark = Color(0xFFE5E7EB);
  static const Color sidebarActiveDark = Color(0xFF2A2A2A);

  // ============================================================================
  // BRAND ACCENT (teal) — used sparingly for primary CTAs, active states,
  // links, and focus rings. Distinct from the legacy grey `accent` above.
  // ============================================================================

  /// Teal-500. Borders, active indicators, links, focus rings, icon tints.
  static const Color accentColor = Color(0xFF14B8A6);

  /// Teal-400. Brighter variant for better legibility on dark surfaces.
  static const Color accentColorDark = Color(0xFF2DD4BF);

  /// Teal-700. Filled CTA backgrounds that carry white text (meets contrast).
  static const Color accentStrong = Color(0xFF0F766E);

  /// Foreground color on accent-filled surfaces.
  static const Color onAccent = Color(0xFFFFFFFF);

  // ============================================================================
  // HELPER METHODS for dynamic theming
  // ============================================================================

  static Color getBackground(bool isDark) =>
      isDark ? backgroundDark : background;
  static Color getSurface(bool isDark) => isDark ? surfaceDark : surface;
  static Color getSurfaceVariant(bool isDark) =>
      isDark ? surfaceVariantDark : surfaceVariant;
  static Color getTextPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimary;
  static Color getTextSecondary(bool isDark) =>
      isDark ? textSecondaryDark : textSecondary;
  static Color getBorder(bool isDark) => isDark ? borderDark : border;
  static Color getPrimary(bool isDark) => isDark ? primaryDark : primary;
  static Color getTextHint(bool isDark) => isDark ? textHintDark : textHint;
  static Color getDivider(bool isDark) => isDark ? dividerDark : divider;

  /// Elevated card/panel surface: white in light mode, the slightly-raised
  /// `surfaceVariantDark` (#2A2A2A) in dark mode. This is the surface the
  /// screens actually use for cards (distinct from the deeper `surfaceDark`
  /// #1A1A1A that backs dialogs/menus in the theme).
  static Color getCard(bool isDark) => isDark ? surfaceVariantDark : surface;

  /// Brand accent for FOREGROUND uses (links, icons, active indicators, focus).
  /// Contrast-safe in each mode: teal-700 on light (~5.5:1 on white), teal-400
  /// on dark (~10:1 on near-black). Use `accentColor` (teal-500) only for fills
  /// where text contrast is not a concern (switch tracks, low-alpha tints).
  static Color getAccent(bool isDark) => isDark ? accentColorDark : accentStrong;
}
