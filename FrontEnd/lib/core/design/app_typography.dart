// FrontEnd/lib/core/design/app_typography.dart
import 'package:flutter/material.dart';

/// Typography for the redesigned surfaces.
///
/// Three families, each with a distinct job:
/// - [latin] (Inter)          — all UI chrome and Roman Urdu caption text
/// - [mono] (JetBrains Mono)  — timecodes, where digit alignment matters
/// - [urdu] (Noto Nastaliq)   — native Urdu script
///
/// Urdu is not Latin with a different alphabet. Nastaliq cascades downward,
/// so it needs roughly double the line height, and at an equal nominal size
/// it reads smaller than Latin — hence [urduScale].
class AppTypography {
  const AppTypography._();

  static const String latinFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';
  static const String urduFamily = 'NotoNastaliqUrdu';

  /// Comfortable Latin line height for UI text.
  static const double latinHeight = 1.45;

  /// Nastaliq needs room for descending kerns. Below ~1.8 the script clips.
  static const double urduHeight = 2.0;

  /// Urdu renders optically smaller than Latin at the same point size.
  static const double urduScale = 1.25;

  static TextStyle latin({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: latinFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? latinHeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.3,
    );
  }

  /// [size] is the *nominal* size — the Latin size this Urdu should sit
  /// beside. The returned style is scaled up by [urduScale] so the two read
  /// as equals rather than as text and footnote.
  static TextStyle urdu({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: urduFamily,
      fontSize: size * urduScale,
      fontWeight: weight,
      color: color,
      height: urduHeight,
    );
  }

  /// Material [TextTheme] for the redesigned surfaces, built from [latin].
  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: latin(size: 32, weight: FontWeight.w700, color: primary),
      headlineMedium: latin(size: 24, weight: FontWeight.w600, color: primary),
      titleLarge: latin(size: 18, weight: FontWeight.w600, color: primary),
      titleMedium: latin(size: 16, weight: FontWeight.w600, color: primary),
      bodyLarge: latin(size: 16, color: primary),
      bodyMedium: latin(size: 14, color: primary),
      bodySmall: latin(size: 12, color: secondary),
      labelLarge: latin(size: 14, weight: FontWeight.w600, color: primary),
      labelMedium: latin(size: 12, weight: FontWeight.w500, color: secondary),
      labelSmall: latin(size: 11, weight: FontWeight.w500, color: secondary),
    );
  }
}
