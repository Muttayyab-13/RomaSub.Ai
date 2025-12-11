import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/api/api_exception.dart';

/// Forgot password flow steps
enum ForgotPasswordStep {
  enterEmail,
  verifyOtp,
  resetPassword,
}

/// State for forgot password flow
class ForgotPasswordState {
  final String? email;
  final String? otp;
  final ForgotPasswordStep step;
  final bool isLoading;
  final String? error;

  ForgotPasswordState({
    this.email,
    this.otp,
    this.step = ForgotPasswordStep.enterEmail,
    this.isLoading = false,
    this.error,
  });

  /// Copy with method for immutable state updates
  ForgotPasswordState copyWith({
    String? email,
    String? otp,
    ForgotPasswordStep? step,
    bool? isLoading,
    String? error,
  }) {
    return ForgotPasswordState(
      email: email ?? this.email,
      otp: otp ?? this.otp,
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Create initial state
  factory ForgotPasswordState.initial() => ForgotPasswordState();
}

/// Notifier for managing forgot password flow
class ForgotPasswordNotifier extends StateNotifier<ForgotPasswordState> {
  final AuthService _authService;

  ForgotPasswordNotifier(this._authService) : super(ForgotPasswordState.initial());

  /// Step 1: Request OTP via email
  Future<bool> requestOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.forgotPassword(email);
      state = state.copyWith(
        email: email,
        step: ForgotPasswordStep.verifyOtp,
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to send reset code. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }

  /// Step 2: Verify OTP code
  Future<bool> verifyOtp(String otp) async {
    if (state.email == null) {
      state = state.copyWith(error: 'Email is required');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.verifyOtp(state.email!, otp);
      state = state.copyWith(
        otp: otp,
        step: ForgotPasswordStep.resetPassword,
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Invalid or expired OTP code. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }

  /// Step 3: Reset password with OTP
  Future<bool> resetPassword(String newPassword) async {
    if (state.email == null || state.otp == null) {
      state = state.copyWith(error: 'Email and OTP are required');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.resetPassword(
        email: state.email!,
        otp: state.otp!,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to reset password. Please try again.',
        isLoading: false,
      );
      return false;
    }
  }

  /// Reset the entire flow
  void reset() {
    state = ForgotPasswordState.initial();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Go to previous step
  void goToPreviousStep() {
    switch (state.step) {
      case ForgotPasswordStep.verifyOtp:
        state = state.copyWith(step: ForgotPasswordStep.enterEmail, otp: null);
        break;
      case ForgotPasswordStep.resetPassword:
        state = state.copyWith(step: ForgotPasswordStep.verifyOtp);
        break;
      default:
        break;
    }
  }
}

/// Riverpod provider for ForgotPasswordNotifier
final forgotPasswordProvider =
    StateNotifierProvider<ForgotPasswordNotifier, ForgotPasswordState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ForgotPasswordNotifier(authService);
});
