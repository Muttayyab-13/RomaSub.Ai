import 'dart:convert';

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
        data: {'project_name': ?projectName},
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
        data: {'segments': segments.map((s) => s.toJson()).toList()},
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

  /// Download the project's video with Roman Urdu captions attached.
  ///
  /// [mode] is `hardsub` (burned-in) or `softsub` (toggleable track).
  /// Returns the raw MP4 bytes and a suggested filename.
  Future<({List<int> bytes, String filename})> downloadVideoWithCaptions(
    String subtitleId,
    String mode,
  ) async {
    try {
      final response = await _client.dio.get<List<int>>(
        ApiConfig.subtitleExportVideo(subtitleId),
        queryParameters: {'mode': mode},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: ApiConfig.videoExportTimeout,
          headers: {'Accept': 'video/mp4'},
        ),
      );
      final bytes = response.data ?? <int>[];
      final filename =
          _filenameFromHeaders(response.headers) ?? 'subtitled_video.mp4';
      return (bytes: bytes, filename: filename);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String? _filenameFromHeaders(Headers headers) {
    final disposition = headers.value('content-disposition');
    if (disposition == null) return null;
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    return match?.group(1);
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

      // Binary (ResponseType.bytes) requests deliver error bodies as raw
      // bytes, so decode them to JSON before reading the `detail` message.
      dynamic parsed = data;
      if (parsed is List<int>) {
        try {
          parsed = jsonDecode(utf8.decode(parsed));
        } catch (_) {
          parsed = null;
        }
      }

      final detail = parsed is Map<String, dynamic>
          ? parsed['detail'] as String?
          : null;
      final message = detail ?? 'Operation failed';

      if (statusCode == 400) return ValidationException(message, data);
      if (statusCode == 401) return UnauthorizedException(message);
      // Prefer the server's actionable detail (e.g. "Source video no longer
      // available. Please re-upload.") over a generic label when present.
      if (statusCode == 404)
        return ServerException(detail ?? 'Project not found', 404);
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
