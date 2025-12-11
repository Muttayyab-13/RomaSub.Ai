import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';
import '../models/user_model.dart';
import 'dart:io';

/// User profile service for handling profile-related API calls
class UserService {
  final ApiClient _client;

  UserService(this._client);

  /// Update user profile (first name and last name)
  Future<UserModel> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await _client.dio.put(
        '${ApiConfig.baseUrl}/users/profile',
        data: {
          'first_name': firstName,
          'last_name': lastName,
        },
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload profile picture
  Future<void> uploadProfilePicture(String imagePath) async {
    try {
      final fileName = imagePath.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imagePath,
          filename: fileName,
        ),
      });

      await _client.dio.post(
        '${ApiConfig.baseUrl}/users/profile-picture',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete profile picture
  Future<void> deleteProfilePicture() async {
    try {
      await _client.dio.delete('${ApiConfig.baseUrl}/users/profile-picture');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get extended user details
  Future<UserModel> getUserDetails() async {
    try {
      final response = await _client.dio.get('${ApiConfig.baseUrl}/users/me/details');
      return UserModel.fromJson(response.data);
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
        message = data['detail'] as String? ?? data['message'] as String? ?? message;
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

/// Riverpod provider for UserService
final userServiceProvider = Provider<UserService>((ref) {
  final client = ref.watch(apiClientProvider);
  return UserService(client);
});
