import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/storage_service.dart';
import '../services/api/api_exception.dart';

/// Auth state class representing the current authentication status
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  /// Check if user is authenticated
  bool get isAuthenticated => user != null;

  /// Get user's full name
  String get userName => user?.fullName ?? 'User';

  /// Get user's email
  String get userEmail => user?.email ?? 'user@email.com';

  /// Get user's initial (first letter of first name)
  String get userInitial => user?.initial ?? 'U';

  /// Copy with method for immutable state updates
  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Create a clean state (for logout)
  factory AuthState.initial() => AuthState();
}

/// Auth state notifier using Riverpod for state management
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final UserService _userService;
  final StorageService _storage;
  final GoogleSignIn? _googleSignIn;

  AuthNotifier(
    this._authService,
    this._userService,
    this._storage,
    this._googleSignIn,
  ) : super(AuthState()) {
    // Initialize auth state on creation
    initialize();
  }

  /// Initialize - check for existing token and validate
  Future<void> initialize() async {
    try {
      final user = await _storage.getUser();
      if (user != null) {
        // Validate token by fetching current user from API
        try {
          final currentUser = await _authService.getCurrentUser();
          state = state.copyWith(user: currentUser);
        } catch (e) {
          // Token expired or invalid - clear storage
          await logout();
        }
      }
    } catch (e) {
      // Error during initialization - clear everything
      await _storage.clearAll();
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.login(email, password);
      await _storage.saveToken(response.accessToken);
      await _storage.saveUser(response.user);

      state = state.copyWith(user: response.user, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Login failed. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }

  /// Register new user (returns email for verification, not logged in)
  Future<String?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false);
      return response.email; // Return email for email verification screen
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return null;
    } catch (e) {
      state = state.copyWith(
        error: 'Registration failed. Please try again.',
        isLoading: false,
      );
      return null;
    }
  }

  /// Verify email with OTP
  Future<bool> verifyEmail(String email, String otp) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.verifyEmail(email, otp);
      await _storage.saveToken(response.accessToken);
      await _storage.saveUser(response.user);

      state = state.copyWith(user: response.user, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Email verification failed. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }

  /// Resend verification OTP
  Future<bool> resendVerificationOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.resendVerificationOtp(email);
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to resend OTP. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    // Check if Google Sign-In is configured
    if (_googleSignIn == null) {
      state = state.copyWith(
        error: 'Google Sign-In is only available on Web, Android, and iOS. Please use email/password login on desktop.',
        isLoading: false,
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Trigger Google Sign-In flow
      final googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        state = state.copyWith(isLoading: false);
        return false;
      }

      // Get Google authentication
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google');
      }

      // Send ID token to backend
      final response = await _authService.googleLogin(idToken);
      await _storage.saveToken(response.accessToken);
      await _storage.saveUser(response.user);

      state = state.copyWith(user: response.user, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      await _googleSignIn!.signOut();
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Google sign-in failed. Please try again.',
        isLoading: false,
      );
      await _googleSignIn!.signOut();
      return false;
    }
  }

  /// Logout - clear all stored data
  Future<void> logout() async {
    await _storage.clearAll();
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
    state = AuthState.initial();
  }

  /// Refresh user data from API
  Future<void> refreshUser() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      await _storage.saveUser(currentUser);
      state = state.copyWith(user: currentUser);
    } catch (e) {
      // If refresh fails, user might need to re-login
      await logout();
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Change password (requires current password)
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to change password. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }

  /// Update user profile (first name and last name)
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedUser = await _userService.updateProfile(
        firstName: firstName,
        lastName: lastName,
      );
      await _storage.saveUser(updatedUser);
      state = state.copyWith(user: updatedUser, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to update profile. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }

  /// Upload profile picture
  Future<bool> uploadProfilePicture(String imagePath) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _userService.uploadProfilePicture(imagePath);

      // Refresh user data to get updated profile picture URL
      final updatedUser = await _authService.getCurrentUser();
      await _storage.saveUser(updatedUser);
      state = state.copyWith(user: updatedUser, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to upload profile picture. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }

  /// Delete profile picture
  Future<bool> deleteProfilePicture() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _userService.deleteProfilePicture();

      // Refresh user data
      final updatedUser = await _authService.getCurrentUser();
      await _storage.saveUser(updatedUser);
      state = state.copyWith(user: updatedUser, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to delete profile picture. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }
}

/// Riverpod provider for AuthNotifier
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userService = ref.watch(userServiceProvider);
  final storageAsync = ref.watch(storageServiceProvider);

  // Wait for storage to be ready before creating AuthNotifier
  return storageAsync.maybeWhen(
    data: (storage) {
      // Only initialize Google Sign-In on supported platforms (Web, Android, iOS)
      GoogleSignIn? googleSignIn;
      final isSupported = kIsWeb ||
                         Platform.isAndroid ||
                         Platform.isIOS;

      if (isSupported) {
        try {
          googleSignIn = GoogleSignIn(
            scopes: ['email', 'profile'],
            // Client ID can be set here or via meta tag in index.html
          );
        } catch (e) {
          // Google Sign-In initialization failed - that's okay, we'll disable it
          googleSignIn = null;
        }
      } else {
        // Desktop platforms (Windows, macOS, Linux) are not supported
        googleSignIn = null;
      }

      return AuthNotifier(authService, userService, storage, googleSignIn);
    },
    orElse: () {
      // Return a temporary notifier while storage is loading/errored
      // This prevents the "Storage not ready" exception
      return _LoadingAuthNotifier();
    },
  );
});

/// Temporary auth notifier used while storage is initializing
class _LoadingAuthNotifier extends AuthNotifier {
  _LoadingAuthNotifier()
      : super(
          _DummyAuthService(),
          _DummyUserService(),
          _DummyStorageService(),
          null, // No Google Sign-In during loading
        );

  @override
  Future<void> initialize() async {
    // Do nothing while loading
  }

  @override
  Future<bool> login(String email, String password) async {
    state = state.copyWith(
      error: 'Please wait, app is initializing...',
      isLoading: false,
    );
    return false;
  }

  @override
  Future<String?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      error: 'Please wait, app is initializing...',
      isLoading: false,
    );
    return null;
  }

  @override
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(
      error: 'Please wait, app is initializing...',
      isLoading: false,
    );
    return false;
  }
}

/// Dummy services for loading state
class _DummyAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DummyUserService implements UserService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DummyStorageService implements StorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
