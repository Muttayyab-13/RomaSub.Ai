import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';
import '../models/upload_response_model.dart';

/// Media service for handling file upload operations
class MediaService {
  final ApiClient _client;

  MediaService(this._client);

  /// Upload a file (video or audio) to the server
  ///
  /// [filePath] - Absolute path to the file
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  ///
  /// Returns [UploadResponseModel] with file_id and metadata
  Future<UploadResponseModel> uploadFile(
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = File(filePath);

      // Validate file exists
      if (!await file.exists()) {
        throw ValidationException('File not found: $filePath');
      }

      // Validate file size
      final fileSize = await file.length();
      final maxSizeBytes = ApiConfig.maxFileSizeMB * 1024 * 1024;
      if (fileSize > maxSizeBytes) {
        throw ValidationException(
          'File size exceeds ${ApiConfig.maxFileSizeMB}MB limit',
        );
      }

      // Get filename
      final filename = file.path.split(Platform.pathSeparator).last;

      // Determine MIME type
      final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';

      // Create FormData for multipart upload
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filename,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      // Upload with progress tracking
      final response = await _client.dio.post(
        ApiConfig.mediaUpload,
        data: formData,
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            final progress = sent / total;
            onProgress(progress);
          }
        },
      );

      return UploadResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw ServerException('Upload failed: ${e.toString()}');
    }
  }

  /// Get file information by file_id
  Future<Map<String, dynamic>> getFileInfo(String fileId) async {
    try {
      final response = await _client.dio.get(ApiConfig.mediaInfo(fileId));
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a file by file_id
  Future<void> deleteFile(String fileId) async {
    try {
      await _client.dio.delete(ApiConfig.mediaDelete(fileId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Extract audio from video file
  ///
  /// [fileId] - The file_id from upload response
  ///
  /// Returns extracted audio file information
  Future<Map<String, dynamic>> extractAudio(String fileId) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.mediaExtractAudio(fileId),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors and convert to custom exceptions
  ApiException _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkException('Upload timeout. Please check your internet connection.');
    } else if (e.type == DioExceptionType.connectionError) {
      return NetworkException('No internet connection');
    } else if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      String message = 'Upload failed';
      if (data is Map<String, dynamic>) {
        message = data['detail'] as String? ?? message;
      }

      if (statusCode == 400) {
        return ValidationException(message, data);
      } else if (statusCode == 401) {
        return UnauthorizedException(message);
      } else if (statusCode == 413) {
        return ValidationException('File too large. Maximum size is ${ApiConfig.maxFileSizeMB}MB');
      } else if (statusCode != null && statusCode >= 500) {
        return ServerException('Server error. Please try again later.', statusCode);
      } else {
        return ServerException(message, statusCode);
      }
    } else {
      return NetworkException('Network error during upload');
    }
  }
}

/// Riverpod provider for MediaService
final mediaServiceProvider = Provider<MediaService>((ref) {
  final client = ref.watch(apiClientProvider);
  return MediaService(client);
});
