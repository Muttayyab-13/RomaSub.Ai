// FrontEnd/test/core/design/app_shell_theme_test.dart
//
// buildAppTheme is the shared base every redesigned screen wraps itself in.
// It must carry the AppPalette ColorScheme and AppTypography, and — unlike
// buildEditorTheme — must NOT attach the editor-only EditorTheme extension.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/app_palette.dart';
import 'package:romasubai_frontend/core/design/app_shell_theme.dart';
import 'package:romasubai_frontend/core/design/editor_theme.dart';

void main() {
  test('buildAppTheme uses the AppPalette scheme for the given brightness', () {
    expect(buildAppTheme(false).colorScheme.primary, AppPalette.primary);
    expect(buildAppTheme(true).colorScheme.primary, AppPalette.primaryDark);
  });

  test('buildAppTheme does NOT carry the EditorTheme extension', () {
    expect(buildAppTheme(false).extension<EditorTheme>(), isNull);
  });

  test('buildEditorTheme still carries the EditorTheme extension', () {
    expect(buildEditorTheme(false).extension<EditorTheme>(), isNotNull);
  });
}
