// test/widgets/settings/security_section_test.dart
//
// Email accounts get the password-change form; Google accounts (no password)
// get an honest "Signed in with Google" state instead of dead fields. The
// form validates client-side (mirroring the pre-redesign screen) and only
// calls back — and clears itself — once the callback reports success.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/widgets/settings/security_section.dart';

Widget _host({
  required bool isGoogle,
  Future<bool> Function(String, String)? onChangePassword,
}) => MaterialApp(
  theme: buildBaseTheme(false),
  home: Scaffold(
    body: SecuritySection(
      isGoogleAccount: isGoogle,
      isBusy: false,
      onChangePassword: onChangePassword ?? (_, _) async => true,
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

  testWidgets(
    'invalid submission shows validation errors and does not call back',
    (tester) async {
      var called = false;
      await tester.pumpWidget(
        _host(
          isGoogle: false,
          onChangePassword: (_, _) async {
            called = true;
            return true;
          },
        ),
      );

      // All three fields empty/mismatched → tapping Update must not call back.
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your current password'), findsOneWidget);
      expect(called, isFalse);
    },
  );

  testWidgets('valid submission calls back and clears the form on success', (
    tester,
  ) async {
    String? gotCurrent;
    String? gotNext;
    await tester.pumpWidget(
      _host(
        isGoogle: false,
        onChangePassword: (current, next) async {
          gotCurrent = current;
          gotNext = next;
          return true;
        },
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'oldpassword1!');
    await tester.enterText(fields.at(1), 'NewPass1!');
    await tester.enterText(fields.at(2), 'NewPass1!');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(gotCurrent, 'oldpassword1!');
    expect(gotNext, 'NewPass1!');

    // Fields are cleared after a successful change.
    for (final field in tester.widgetList<TextFormField>(fields)) {
      expect(field.controller!.text, isEmpty);
    }
  });

  testWidgets('failed submission keeps the entered values in the form', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(isGoogle: false, onChangePassword: (_, _) async => false),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'oldpassword1!');
    await tester.enterText(fields.at(1), 'NewPass1!');
    await tester.enterText(fields.at(2), 'NewPass1!');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    // The change failed (e.g. wrong current password) → the form must not
    // be wiped, so the user doesn't have to retype everything.
    final values = tester
        .widgetList<TextFormField>(fields)
        .map((f) => f.controller!.text)
        .toList();
    expect(values, ['oldpassword1!', 'NewPass1!', 'NewPass1!']);
  });
}
