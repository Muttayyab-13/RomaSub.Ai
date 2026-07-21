// FrontEnd/test/core/design/base_theme_test.dart
//
// buildBaseTheme is the shared base every redesigned screen wraps itself in.
// It must carry the AppPalette ColorScheme and AppTypography, and — unlike
// buildEditorTheme — must NOT attach the editor-only EditorTheme extension.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/app_palette.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/core/design/editor_theme.dart';

void main() {
  test(
    'buildBaseTheme uses the AppPalette scheme for the given brightness',
    () {
      expect(buildBaseTheme(false).colorScheme.primary, AppPalette.primary);
      expect(buildBaseTheme(true).colorScheme.primary, AppPalette.primaryDark);
    },
  );

  test('buildBaseTheme does NOT carry the EditorTheme extension', () {
    expect(buildBaseTheme(false).extension<EditorTheme>(), isNull);
  });

  test('buildEditorTheme still carries the EditorTheme extension', () {
    expect(buildEditorTheme(false).extension<EditorTheme>(), isNotNull);
  });
}
