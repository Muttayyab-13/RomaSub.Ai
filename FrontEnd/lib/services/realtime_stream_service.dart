import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';
import '../models/subtitle_project_model.dart';

/// Parsed SSE event from the realtime stream
class RealtimeEvent {
  final String type; // chunk_ready, buffer_ready, stream_complete, error
  final Map<String, dynamic> data;

  RealtimeEvent({required this.type, required this.data});

  /// Parse segments from a chunk_ready event
  List<EditableSegment> get segments {
    final list = data['segments'] as List<dynamic>? ?? [];
    return list
        .map((s) => EditableSegment.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  double get processedThrough =>
      (data['processed_through'] as num?)?.toDouble() ?? 0.0;

  int get chunksDone => data['chunks_done'] as int? ?? 0;
  int get chunksTotal => data['chunks_total'] as int? ?? 0;
  double get totalDuration =>
      (data['total_duration'] as num?)?.toDouble() ?? 0.0;
  double get processedSeconds =>
      (data['processed_seconds'] as num?)?.toDouble() ?? 0.0;
  int get totalSegments => data['total_segments'] as int? ?? 0;
  double get processingTime =>
      (data['processing_time_seconds'] as num?)?.toDouble() ?? 0.0;
}

/// Service for connecting to the SSE subtitle stream and sending seek requests
class RealtimeStreamService {
  final ApiClient _client;

  RealtimeStreamService(this._client);

  /// Connect to the SSE endpoint and yield parsed events.
  ///
  /// Uses Dio with ResponseType.stream to get a raw byte stream,
  /// then parses the SSE text format (event: ...\ndata: ...\n\n).
  Stream<RealtimeEvent> connectToStream(
    String fileId, {
    String language = 'ur',
  }) async* {
    try {
      final response = await _client.dio.get(
        ApiConfig.realtimeStream(fileId),
        queryParameters: {'language': language},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero, // No timeout for SSE
        ),
      );

      final stream = (response.data as ResponseBody).stream;
      String buffer = '';

      await for (final bytes in stream) {
        buffer += utf8.decode(bytes);

        // Parse complete SSE messages (separated by \n\n)
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final rawEvent = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);

          // Skip keepalive comments
          if (rawEvent.startsWith(':')) continue;

          final parsed = _parseSSEMessage(rawEvent);
          if (parsed != null) yield parsed;
        }
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Send a seek request to reprioritize chunk processing.
  Future<void> seekTo(String fileId, double targetSeconds) async {
    try {
      await _client.dio.post(
        ApiConfig.realtimeSeek(fileId),
        data: {'target_seconds': targetSeconds},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get current session status (polling fallback).
  Future<Map<String, dynamic>> getStatus(String fileId) async {
    try {
      final response = await _client.dio.get(
        ApiConfig.realtimeStatus(fileId),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Parse a raw SSE message string into a RealtimeEvent.
  ///
  /// Format: `event: {type}\ndata: {json}`
  RealtimeEvent? _parseSSEMessage(String raw) {
    String? eventType;
    String? dataStr;

    for (final line in raw.split('\n')) {
      if (line.startsWith('event: ')) {
        eventType = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        dataStr = line.substring(6).trim();
      }
    }

    if (eventType == null || dataStr == null) return null;

    try {
      final data = json.decode(dataStr) as Map<String, dynamic>;
      return RealtimeEvent(type: eventType, data: data);
    } catch (e) {
      return null;
    }
  }

  ApiException _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkException('Stream connection timeout');
    } else if (e.type == DioExceptionType.connectionError) {
      return NetworkException('No internet connection');
    } else if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;
      String message = 'Streaming failed';
      if (data is Map<String, dynamic>) {
        message = data['detail'] as String? ?? message;
      }
      if (statusCode == 404) return ServerException('File not found', 404);
      return ServerException(message, statusCode);
    }
    return NetworkException('Network error during streaming');
  }
}

/// Riverpod provider for RealtimeStreamService
final realtimeStreamServiceProvider = Provider<RealtimeStreamService>((ref) {
  final client = ref.watch(apiClientProvider);
  return RealtimeStreamService(client);
});
