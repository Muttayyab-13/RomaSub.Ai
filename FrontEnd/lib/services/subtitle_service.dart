import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';
import '../models/subtitle_project_model.dart';

/// Service for subtitle project CRUD, editing, and export
class SubtitleService {
  final ApiClient _client;

  SubtitleService(this._client);

  /// Create a subtitle project from transcription results
  Future<SubtitleProject> createProject(
    String fileId, {
    String? projectName,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.subtitleCreate(fileId),
        data: {
          if (projectName != null) 'project_name': projectName,
        },
      );
      return SubtitleProject.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get a subtitle project by ID
  Future<SubtitleProject> getProject(String subtitleId) async {
    try {
      final response = await _client.dio.get(
        ApiConfig.subtitleProject(subtitleId),
      );
      return SubtitleProject.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update a single segment
  Future<EditableSegment> updateSegment(
    String subtitleId,
    int segmentId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _client.dio.put(
        ApiConfig.subtitleSegment(subtitleId, segmentId),
        data: updates,
      );
      final data = response.data as Map<String, dynamic>;
      return EditableSegment.fromJson(data['segment']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Add a new segment
  Future<EditableSegment> addSegment(
    String subtitleId, {
    required int afterSegmentId,
    required double start,
    required double end,
    String romanUrduText = '',
    String urduText = '',
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.subtitleAddSegment(subtitleId),
        data: {
          'after_segment_id': afterSegmentId,
          'start': start,
          'end': end,
          'roman_urdu_text': romanUrduText,
          'urdu_text': urduText,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return EditableSegment.fromJson(data['segment']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a segment
  Future<void> deleteSegment(String subtitleId, int segmentId) async {
    try {
      await _client.dio.delete(
        ApiConfig.subtitleSegment(subtitleId, segmentId),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Bulk update all segments (auto-save)
  Future<SubtitleProject> bulkUpdate(
    String subtitleId,
    List<EditableSegment> segments,
  ) async {
    try {
      final response = await _client.dio.put(
        ApiConfig.subtitleBulkUpdate(subtitleId),
        data: {
          'segments': segments.map((s) => s.toJson()).toList(),
        },
      );
      return SubtitleProject.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Auto-fix timing overlaps
  Future<List<EditableSegment>> fixOverlaps(String subtitleId) async {
    try {
      final response = await _client.dio.post(
        ApiConfig.subtitleFixOverlaps(subtitleId),
      );
      final data = response.data as Map<String, dynamic>;
      final segments = data['segments'] as List<dynamic>;
      return segments
          .map((s) => EditableSegment.fromJson(s as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Export subtitles in specified format
  ///
  /// Returns map with 'content' (String) and 'filename' (String)
  Future<Map<String, String>> exportSubtitles(
    String subtitleId,
    String format,
  ) async {
    try {
      final response = await _client.dio.get(
        ApiConfig.subtitleExport(subtitleId),
        queryParameters: {'format': format},
      );
      final data = response.data as Map<String, dynamic>;
      return {
        'content': data['content'] as String,
        'filename': data['filename'] as String,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ApiException _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkException('Request timeout. Please try again.');
    } else if (e.type == DioExceptionType.connectionError) {
      return NetworkException('No internet connection');
    } else if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      String message = 'Operation failed';
      if (data is Map<String, dynamic>) {
        message = data['detail'] as String? ?? message;
      }

      if (statusCode == 400) return ValidationException(message, data);
      if (statusCode == 401) return UnauthorizedException(message);
      if (statusCode == 404) return ServerException('Project not found', 404);
      if (statusCode != null && statusCode >= 500) {
        return ServerException('Server error', statusCode);
      }
      return ServerException(message, statusCode);
    }
    return NetworkException('Network error');
  }
}

/// Riverpod provider for SubtitleService
final subtitleServiceProvider = Provider<SubtitleService>((ref) {
  final client = ref.watch(apiClientProvider);
  return SubtitleService(client);
});
