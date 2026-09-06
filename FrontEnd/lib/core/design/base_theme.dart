// FrontEnd/lib/core/design/base_theme.dart
import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_typography.dart';

/// The shared base theme every redesigned screen wraps itself in.
///
/// Deliberately NOT applied app-wide: screens opt in one at a time via a
/// scoped `Theme(data: buildBaseTheme(isDark), ...)`, so the un-redesigned
/// screens keep using AppColors/AppTheme. The editor extends this base with
/// its own [EditorTheme] extension in `editor_theme.dart`.
ThemeData buildBaseTheme(bool isDark) {
  final scheme = AppPalette.scheme(isDark);
  final textTheme = AppTypography.textTheme(
    scheme.onSurface,
    scheme.onSurfaceVariant,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    fontFamily: AppTypography.latinFamily,
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
  );
}
