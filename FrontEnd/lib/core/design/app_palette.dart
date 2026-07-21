// FrontEnd/lib/core/design/app_palette.dart
import 'package:flutter/material.dart';

/// Colour roles for the redesigned surfaces.
///
/// Light values come from the Stitch design
/// (`Documentation/design/html/subtitle-editor.html`).
///
/// Dark values are DERIVED, not designed — Stitch produced a light palette
/// only. They follow Material 3 tonal conventions from the same teal and are
/// a starting point pending design review.
class AppPalette {
  const AppPalette._();

  // ---- Light (from Stitch) ----
  static const Color primary = Color(0xFF00685F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF008378);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFF89F5E7);
  static const Color primaryFixedDim = Color(0xFF6BD8CB);
  static const Color tealSubtle = Color(0xFFF0FDFA);

  static const Color secondary = Color(0xFF565E74);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFDAE2FD);
  static const Color onSecondaryContainer = Color(0xFF131C2B);

  static const Color background = Color(0xFFF8F9FF);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);
  static const Color surfaceDim = Color(0xFFCBDBF5);
  static const Color surfaceBright = Color(0xFFF8F9FF);

  static const Color onSurface = Color(0xFF191C20);
  static const Color onSurfaceVariant = Color(0xFF43474E);
  static const Color outline = Color(0xFF73777F);
  static const Color outlineVariant = Color(0xFFC3C7CF);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  /// The video stage — always dark, in both themes. Video is watched against
  /// black regardless of app theme.
  static const Color videoStage = Color(0xFF0B1C30);

  // ---- Dark (derived) ----
  static const Color primaryDark = Color(0xFF6BD8CB);
  static const Color onPrimaryDark = Color(0xFF00382F);
  static const Color primaryContainerDark = Color(0xFF005048);
  static const Color onPrimaryContainerDark = Color(0xFF89F5E7);
  static const Color tealSubtleDark = Color(0xFF10302C);

  static const Color secondaryDark = Color(0xFFBEC6E0);
  static const Color onSecondaryDark = Color(0xFF283141);
  static const Color secondaryContainerDark = Color(0xFF3E4759);
  static const Color onSecondaryContainerDark = Color(0xFFDAE2FD);

  static const Color backgroundDark = Color(0xFF0E1417);
  static const Color surfaceDarkColor = Color(0xFF0E1417);
  static const Color surfaceContainerLowestDark = Color(0xFF090F11);
  static const Color surfaceContainerLowDark = Color(0xFF161C1F);
  static const Color surfaceContainerDark = Color(0xFF1A2023);
  static const Color surfaceContainerHighDark = Color(0xFF242B2E);
  static const Color surfaceContainerHighestDark = Color(0xFF2F3639);
  static const Color surfaceDimDark = Color(0xFF0E1417);
  static const Color surfaceBrightDark = Color(0xFF343A3D);

  static const Color onSurfaceDark = Color(0xFFE1E3E5);
  static const Color onSurfaceVariantDark = Color(0xFFC0C8CC);
  static const Color outlineDark = Color(0xFF8A9296);
  static const Color outlineVariantDark = Color(0xFF40484C);

  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color onErrorDark = Color(0xFF690005);
  static const Color errorContainerDark = Color(0xFF93000A);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color successDark = Color(0xFF34D399);

  static ColorScheme scheme(bool isDark) => isDark ? _darkScheme : _lightScheme;

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: Color(0xFF410002),
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryDark,
    onPrimary: onPrimaryDark,
    primaryContainer: primaryContainerDark,
    onPrimaryContainer: onPrimaryContainerDark,
    secondary: secondaryDark,
    onSecondary: onSecondaryDark,
    secondaryContainer: secondaryContainerDark,
    onSecondaryContainer: onSecondaryContainerDark,
    error: errorDark,
    onError: onErrorDark,
    errorContainer: errorContainerDark,
    onErrorContainer: Color(0xFFFFDAD6),
    surface: surfaceDarkColor,
    onSurface: onSurfaceDark,
    onSurfaceVariant: onSurfaceVariantDark,
    outline: outlineDark,
    outlineVariant: outlineVariantDark,
  );
}
