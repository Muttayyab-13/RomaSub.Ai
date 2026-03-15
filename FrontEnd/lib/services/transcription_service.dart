import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';
import '../models/transcription_model.dart';

/// Transcription service for handling ASR operations
class TranscriptionService {
  final ApiClient _client;

  TranscriptionService(this._client);

  /// Transcribe a file using Whisper ASR
  ///
  /// [fileId] - The file_id from upload response
  /// [language] - Language code (default: 'ur' for Urdu)
  ///
  /// Returns [TranscriptionModel] with segments and full text
  Future<TranscriptionModel> transcribe(
    String fileId, {
    String language = 'ur',
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.asrTranscribe(fileId),
        queryParameters: {
          'language': language,
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10), // Allow up to 10 minutes for transcription
        ),
      );
      return TranscriptionModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get transcription result by file_id
  ///
  /// Use this to check if transcription is complete and get results
  Future<TranscriptionModel> getTranscriptionResult(String fileId) async {
    try {
      final response = await _client.dio.get(ApiConfig.asrResult(fileId));
      return TranscriptionModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get transcription result as SRT file content
  ///
  /// Returns the SRT file content as a string
  Future<String> getTranscriptionSrt(String fileId) async {
    try {
      final response = await _client.dio.get(
        ApiConfig.asrResultSrt(fileId),
        options: Options(
          responseType: ResponseType.plain, // Get as string
        ),
      );
      return response.data as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get list of supported languages
  Future<List<Map<String, String>>> getSupportedLanguages() async {
    try {
      final response = await _client.dio.get(ApiConfig.asrLanguages);
      final data = response.data as Map<String, dynamic>;
      final languages = data['languages'] as List<dynamic>;
      return languages
          .map((lang) => {
                'code': lang['code'] as String,
                'name': lang['name'] as String,
              })
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Transliterate raw Urdu text to Roman Urdu
  ///
  /// [urduText] - Urdu text to transliterate
  ///
  /// Returns a map with urdu_text, roman_urdu_text, processing_time_seconds
  Future<Map<String, dynamic>> transliterateText(String urduText) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.transliterateText,
        data: {'text': urduText},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get Roman Urdu SRT subtitle content
  ///
  /// Returns the Roman Urdu SRT file content as a string
  Future<String> getTransliterationSrt(String fileId) async {
    try {
      final response = await _client.dio.get(
        ApiConfig.transliterateResultSrt(fileId),
      );
      final data = response.data as Map<String, dynamic>;
      return data['srt_content'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Poll for transcription completion
  ///
  /// Polls the server every [pollInterval] until transcription is complete or timeout
  ///
  /// [fileId] - The file_id to check
  /// [pollInterval] - Time between checks (default: 3 seconds)
  /// [timeout] - Maximum wait time (default: 5 minutes)
  ///
  /// Returns [TranscriptionModel] when complete
  /// Throws [ServerException] on timeout
  Future<TranscriptionModel> pollTranscriptionResult(
    String fileId, {
    Duration pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final startTime = DateTime.now();

    while (true) {
      try {
        // Try to get result
        final result = await getTranscriptionResult(fileId);
        return result;
      } on ApiException catch (e) {
        // If 404, transcription not ready yet
        if (e.statusCode == 404) {
          // Check timeout
          if (DateTime.now().difference(startTime) > timeout) {
            throw ServerException(
              'Transcription timeout after ${timeout.inMinutes} minutes',
            );
          }

          // Wait before next poll
          await Future.delayed(pollInterval);
          continue;
        }

        // Other errors, rethrow
        rethrow;
      }
    }
  }

  /// Handle Dio errors and convert to custom exceptions
  ApiException _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkException('Transcription timeout. Please try again.');
    } else if (e.type == DioExceptionType.connectionError) {
      return NetworkException('No internet connection');
    } else if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      String message = 'Transcription failed';
      if (data is Map<String, dynamic>) {
        message = data['detail'] as String? ?? message;
      }

      if (statusCode == 400) {
        return ValidationException(message, data);
      } else if (statusCode == 401) {
        return UnauthorizedException(message);
      } else if (statusCode == 404) {
        return ServerException('Transcription not found or not ready yet', 404);
      } else if (statusCode != null && statusCode >= 500) {
        return ServerException('Server error. Please try again later.', statusCode);
      } else {
        return ServerException(message, statusCode);
      }
    } else {
      return NetworkException('Network error during transcription');
    }
  }
}

/// Riverpod provider for TranscriptionService
final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  final client = ref.watch(apiClientProvider);
  return TranscriptionService(client);
});
