import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';
import '../models/user_model.dart';
import '../models/auth_response_model.dart';

/// Authentication service for handling all auth-related API calls
class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  /// Login with email and password
  Future<AuthResponseModel> login(String email, String password) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.authLogin,
        data: {
          'email': email,
          'password': password,
        },
      );
      return AuthResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Register new user
  Future<AuthResponseModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.authRegister,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
          'confirm_password': password,
        },
      );
      return AuthResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Login with Google OAuth
  Future<AuthResponseModel> googleLogin(String idToken) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.authGoogle,
        data: {
          'id_token': idToken,
        },
      );
      return AuthResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get current authenticated user
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _client.dio.get(ApiConfig.authMe);
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Change password (requires authentication)
  Future<MessageResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.authChangePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': newPassword,
        },
      );
      return MessageResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Request OTP for password reset
  Future<MessageResponse> forgotPassword(String email) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.authForgotPassword,
        data: {'email': email},
      );
      return MessageResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Verify OTP code
  Future<MessageResponse> verifyOtp(String email, String otp) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.authVerifyOtp,
        data: {
          'email': email,
          'otp': otp,
        },
      );
      return MessageResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reset password with OTP
  Future<MessageResponse> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.authResetPassword,
        data: {
          'email': email,
          'otp': otp,
          'new_password': newPassword,
          'confirm_password': newPassword,
        },
      );
      return MessageResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors and convert to custom exceptions
  ApiException _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkException('Connection timeout. Please check your internet.');
    } else if (e.type == DioExceptionType.connectionError) {
      return NetworkException('No internet connection');
    } else if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      String message = 'An error occurred';
      if (data is Map<String, dynamic>) {
        message = data['detail'] as String? ?? message;
      }

      if (statusCode == 400) {
        return ValidationException(message, data);
      } else if (statusCode == 401) {
        return UnauthorizedException(message);
      } else if (statusCode == 404) {
        return ServerException('Resource not found', statusCode);
      } else if (statusCode != null && statusCode >= 500) {
        return ServerException('Server error. Please try again later.', statusCode);
      } else {
        return ServerException(message, statusCode);
      }
    } else {
      return NetworkException('Network error. Please try again.');
    }
  }
}

/// Riverpod provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthService(client);
});
