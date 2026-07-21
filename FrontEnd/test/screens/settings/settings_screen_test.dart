// FrontEnd/test/screens/settings/settings_screen_test.dart
//
// Composition test for the redesigned SettingsScreen. Seeds
// `authNotifierProvider` directly with a real `UserModel` (bypassing the
// network/storage seam) via a notifier subclass that mirrors
// `_LoadingAuthNotifier` in auth_provider.dart — dummy services + a no-op
// `initialize()`, but with the state set to a real user. This lets us
// exercise both account branches without a backend: a Google user (no
// name-edit / password form) and an email user (both editable).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:romasubai_frontend/core/constants/app_strings.dart';
import 'package:romasubai_frontend/models/user_model.dart';
import 'package:romasubai_frontend/providers/auth_provider.dart';
import 'package:romasubai_frontend/screens/settings/settings_screen.dart';
import 'package:romasubai_frontend/services/auth_service.dart';
import 'package:romasubai_frontend/services/storage_service.dart';
import 'package:romasubai_frontend/services/user_service.dart';

final _googleUser = UserModel(
  uuid: 'u1',
  firstName: 'Amina',
  lastName: 'Khan',
  email: 'amina@example.com',
  isVerified: true,
  googleId: 'g-123',
  createdAt: DateTime(2025, 3, 10),
);

final _emailUser = UserModel(
  uuid: 'u2',
  firstName: 'Bilal',
  lastName: 'Ahmed',
  email: 'bilal@example.com',
  isVerified: false,
  createdAt: DateTime(2025, 6, 1),
);

Future<void> _pump(WidgetTester tester, UserModel user) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith((ref) => _SeededAuthNotifier(user)),
      ],
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'email account: sections render with editable name + password form',
    (tester) async {
      await _pump(tester, _emailUser);

      expect(find.text(AppStrings.profileSettings), findsOneWidget);
      expect(find.text('Bilal'), findsOneWidget);
      expect(find.text('Ahmed'), findsOneWidget);
      expect(find.text('bilal@example.com'), findsOneWidget);
      // Email account → editable name (Edit Profile button) + real password form.
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3)); // current/new/confirm
      expect(find.text('Pending'), findsOneWidget);
    },
  );

  testWidgets('google account: no name-edit button or password fields', (
    tester,
  ) async {
    await _pump(tester, _googleUser);

    expect(find.text(AppStrings.profileSettings), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    // Google account → no edit button, no password TextFields.
    expect(find.text('Edit Profile'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Google'), findsWidgets);
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('honest UI: no billing/delete/Translation copy', (tester) async {
    await _pump(tester, _emailUser);

    expect(find.textContaining('Translation'), findsNothing);
    expect(find.textContaining('Delete Account'), findsNothing);
    expect(find.textContaining('Billing'), findsNothing);
    expect(find.textContaining('Danger'), findsNothing);
    expect(find.textContaining('Upgrade'), findsNothing);
  });
}

/// Mirrors `_LoadingAuthNotifier` in auth_provider.dart: dummy services + a
/// no-op `initialize()` so no real network/storage call happens, but with
/// `state` seeded to a real user instead of staying empty.
class _SeededAuthNotifier extends AuthNotifier {
  _SeededAuthNotifier(UserModel user)
    : super(
        _FakeAuthService(),
        _FakeUserService(),
        _FakeStorageService(),
        null,
        null,
      ) {
    state = AuthState(user: user);
  }

  @override
  Future<void> initialize() async {}
}

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeUserService implements UserService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeStorageService implements StorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
