// test/widgets/settings/security_section_test.dart
//
// Email accounts get the password-change form; Google accounts (no password)
// get an honest "Signed in with Google" state instead of dead fields.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/widgets/settings/security_section.dart';

Widget _host({required bool isGoogle}) => MaterialApp(
  theme: buildBaseTheme(false),
  home: Scaffold(
    body: SecuritySection(
      isGoogleAccount: isGoogle,
      isBusy: false,
      onChangePassword: (_, _) {},
    ),
  ),
);

void main() {
  testWidgets('email account shows the password form', (tester) async {
    await tester.pumpWidget(_host(isGoogle: false));
    expect(find.byType(TextField), findsNWidgets(3)); // current/new/confirm
    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets('google account shows the signed-in-with-Google state', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isGoogle: true));
    expect(find.textContaining('Google'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
