// FrontEnd/test/widgets/dashboard/upload_dropzone_test.dart
//
// Pins the dropzone's copy, its compact toggle (tap hint vs. chip row), and the
// theme-aware "MAX 2GB" emphasize chip — whose wash must switch to the dark
// teal token in dark mode rather than painting a near-white pill.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/constants/app_strings.dart';
import 'package:romasubai_frontend/core/design/app_palette.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/widgets/dashboard/upload_dropzone.dart';

Widget _host({bool isDark = false, bool compact = false}) {
  return MaterialApp(
    theme: buildBaseTheme(isDark),
    home: Scaffold(
      body: UploadDropzone(onTap: () {}, compact: compact),
    ),
  );
}

Finder _containerWithColor(Color c) => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == c,
);

void main() {
  testWidgets('renders the upload title and subtitle', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text(AppStrings.dashUploadTitle), findsOneWidget);
    expect(find.text(AppStrings.dashUploadSubtitle), findsOneWidget);
  });

  testWidgets('full mode shows the format chips including MAX 2GB', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.text(AppStrings.dashMaxSize), findsOneWidget);
    expect(find.text(AppStrings.dashUploadTapHint), findsNothing);
  });

  testWidgets('compact mode drops the chip row for the tap hint', (
    tester,
  ) async {
    await tester.pumpWidget(_host(compact: true));
    expect(find.text(AppStrings.dashUploadTapHint), findsOneWidget);
    expect(find.text(AppStrings.dashMaxSize), findsNothing);
  });

  testWidgets('emphasize chip uses the light teal wash in light mode', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(_containerWithColor(AppPalette.tealSubtle), findsOneWidget);
    expect(_containerWithColor(AppPalette.tealSubtleDark), findsNothing);
  });

  testWidgets('emphasize chip uses the dark teal wash in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isDark: true));
    expect(_containerWithColor(AppPalette.tealSubtleDark), findsOneWidget);
    // The near-white light wash must never appear on the dark surface.
    expect(_containerWithColor(AppPalette.tealSubtle), findsNothing);
  });
}
