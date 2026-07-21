// test/providers/remember_me_test.dart
//
// "Remember me" controls whether a stored session survives a cold app start.
// The token is always persisted so in-session API calls work; on the next
// AuthNotifier.initialize() the session is dropped when the flag is false and
// restored (validated) when it is true.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/models/user_model.dart';
import 'package:romasubai_frontend/providers/auth_provider.dart';
import 'package:romasubai_frontend/services/auth_service.dart';
import 'package:romasubai_frontend/services/storage_service.dart';
import 'package:romasubai_frontend/services/user_service.dart';

UserModel _user() => UserModel(
  uuid: 'u1',
  firstName: 'Ayesha',
  lastName: 'Khan',
  email: 'ayesha@example.com',
  isVerified: true,
);

/// Records the calls initialize() makes so tests can assert on the branch taken.
class _FakeStorage implements StorageService {
  bool remember;
  UserModel? storedUser;
  int clearAllCount = 0;

  _FakeStorage({required this.remember, this.storedUser});

  @override
  Future<bool> getRememberMe() async => remember;

  @override
  Future<UserModel?> getUser() async => storedUser;

  @override
  Future<void> clearAll() async => clearAllCount++;

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> saveUser(UserModel user) async {}

  @override
  Future<void> saveRememberMe(bool value) async => remember = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAuthService implements AuthService {
  final UserModel current;
  int getCurrentUserCount = 0;

  _FakeAuthService(this.current);

  @override
  Future<UserModel> getCurrentUser() async {
    getCurrentUserCount++;
    return current;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeUserService implements UserService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('initialize() drops the stored session when remember me is false', () async {
    final storage = _FakeStorage(remember: false, storedUser: _user());
    final auth = _FakeAuthService(_user());

    final notifier = AuthNotifier(auth, _FakeUserService(), storage, null, null);
    await pumpEventQueue();

    expect(storage.clearAllCount, greaterThanOrEqualTo(1));
    expect(auth.getCurrentUserCount, 0); // never validated — session was cleared
    expect(notifier.state.user, isNull);
  });

  test('initialize() restores and validates the session when remember me is true', () async {
    final storage = _FakeStorage(remember: true, storedUser: _user());
    final auth = _FakeAuthService(_user());

    final notifier = AuthNotifier(auth, _FakeUserService(), storage, null, null);
    await pumpEventQueue();

    expect(storage.clearAllCount, 0);
    expect(auth.getCurrentUserCount, greaterThanOrEqualTo(1));
    expect(notifier.state.user, isNotNull);
    expect(notifier.state.user!.email, 'ayesha@example.com');
  });
}
