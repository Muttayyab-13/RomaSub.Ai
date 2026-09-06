import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

/// Service for storing sensitive (tokens) and non-sensitive (user data) information
class StorageService {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // ========== JWT Token Storage (Secure) ==========

  /// Save JWT access token securely
  Future<void> saveToken(String token) async {
    await _secure.write(key: 'access_token', value: token);
  }

  /// Retrieve JWT access token
  Future<String?> getToken() async {
    return await _secure.read(key: 'access_token');
  }

  /// Delete JWT access token (on logout)
  Future<void> deleteToken() async {
    await _secure.delete(key: 'access_token');
  }

  // ========== User Data Storage (Non-sensitive) ==========

  /// Save user data to shared preferences
  Future<void> saveUser(UserModel user) async {
    await _prefs.setString('user_json', jsonEncode(user.toJson()));
  }

  /// Retrieve user data from shared preferences
  Future<UserModel?> getUser() async {
    final json = _prefs.getString('user_json');
    if (json == null) return null;
    return UserModel.fromJson(jsonDecode(json));
  }

  /// Clear user data from shared preferences
  Future<void> clearUser() async {
    await _prefs.remove('user_json');
  }

  // ========== Remember Me (session persistence flag) ==========

  /// Whether the last sign-in asked to be remembered across app restarts.
  /// Defaults to `true` so existing/unset installs keep their session.
  Future<bool> getRememberMe() async {
    return _prefs.getBool('remember_me') ?? true;
  }

  /// Persist the "remember me" choice made at sign-in.
  Future<void> saveRememberMe(bool value) async {
    await _prefs.setBool('remember_me', value);
  }

  // ========== Project Data Storage (Local) ==========

  /// Save projects list to shared preferences
  Future<void> saveProjects(List<Map<String, dynamic>> projects) async {
    await _prefs.setString('projects_list', jsonEncode(projects));
  }

  /// Retrieve projects list from shared preferences
  Future<List<Map<String, dynamic>>> getProjects() async {
    final json = _prefs.getString('projects_list');
    if (json == null) return [];
    final List<dynamic> list = jsonDecode(json);
    return list.cast<Map<String, dynamic>>();
  }

  /// Clear all stored data (on logout)
  Future<void> clearAll() async {
    await deleteToken();
    await clearUser();
    await _prefs.remove('projects_list');
    await _prefs.remove('remember_me');
  }
}

/// Riverpod provider for StorageService
/// Initializes SharedPreferences asynchronously
final storageServiceProvider = FutureProvider<StorageService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return StorageService(prefs);
});
