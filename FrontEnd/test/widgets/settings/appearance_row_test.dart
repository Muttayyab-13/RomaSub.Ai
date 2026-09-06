// test/widgets/settings/appearance_row_test.dart
//
// The Dark Mode row reflects the current value and reports toggles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/widgets/settings/appearance_row.dart';

void main() {
  testWidgets('reflects value and reports toggle', (tester) async {
    bool? toggled;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBaseTheme(false),
        home: Scaffold(
          body: AppearanceRow(isDark: false, onChanged: (v) => toggled = v),
        ),
      ),
    );
    expect(find.byType(Switch), findsOneWidget);
    await tester.tap(find.byType(Switch));
    expect(toggled, true);
  });
}
