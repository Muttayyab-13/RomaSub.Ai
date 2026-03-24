import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subtitle_project_model.dart';
import '../services/realtime_stream_service.dart';
import '../services/subtitle_service.dart';

/// Phases of the realtime streaming session
enum RealtimePhase { idle, connecting, buffering, streaming, complete, error }

/// State for the realtime subtitle streaming session
class RealtimeState {
  final RealtimePhase phase;
  final List<EditableSegment> segments; // Grows as chunks arrive
  final double processedThrough; // Highest processed timestamp (seconds)
  final double totalDuration;
  final int chunksReady;
  final int chunksTotal;
  final String? error;
  final String? fileId;

  RealtimeState({
    this.phase = RealtimePhase.idle,
    this.segments = const [],
    this.processedThrough = 0.0,
    this.totalDuration = 0.0,
    this.chunksReady = 0,
    this.chunksTotal = 0,
    this.error,
    this.fileId,
  });

  /// Binary search for the segment at a given playback time
  int? getSegmentAtTime(double seconds) {
    if (segments.isEmpty) return null;

    int low = 0;
    int high = segments.length - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final seg = segments[mid];

      if (seconds >= seg.start && seconds <= seg.end) {
        return mid;
      } else if (seconds < seg.start) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return null;
  }

  /// Whether the user can start watching (buffer ready or complete)
  bool get canPlay =>
      phase == RealtimePhase.streaming || phase == RealtimePhase.complete;

  /// Progress as a fraction 0.0-1.0
  double get progress =>
      chunksTotal > 0 ? chunksReady / chunksTotal : 0.0;

  RealtimeState copyWith({
    RealtimePhase? phase,
    List<EditableSegment>? segments,
    double? processedThrough,
    double? totalDuration,
    int? chunksReady,
    int? chunksTotal,
    String? Function()? error,
    String? fileId,
  }) {
    return RealtimeState(
      phase: phase ?? this.phase,
      segments: segments ?? this.segments,
      processedThrough: processedThrough ?? this.processedThrough,
      totalDuration: totalDuration ?? this.totalDuration,
      chunksReady: chunksReady ?? this.chunksReady,
      chunksTotal: chunksTotal ?? this.chunksTotal,
      error: error != null ? error() : this.error,
      fileId: fileId ?? this.fileId,
    );
  }

  factory RealtimeState.initial() => RealtimeState();
}

/// Manages the realtime subtitle streaming session
class RealtimeNotifier extends StateNotifier<RealtimeState> {
  final RealtimeStreamService _streamService;
  final SubtitleService _subtitleService;
  StreamSubscription? _subscription;
  Timer? _seekDebounce;

  RealtimeNotifier(this._streamService, this._subtitleService)
      : super(RealtimeState.initial());

  /// Start streaming subtitles for a file
  Future<void> startStreaming(String fileId, {String language = 'ur'}) async {
    state = state.copyWith(
      phase: RealtimePhase.connecting,
      fileId: fileId,
      segments: [],
      processedThrough: 0.0,
      chunksReady: 0,
      error: () => null,
    );

    try {
      final stream = _streamService.connectToStream(fileId, language: language);

      state = state.copyWith(phase: RealtimePhase.buffering);

      _subscription = stream.listen(
        _handleEvent,
        onError: (e) {
          if (mounted) {
            state = state.copyWith(
              phase: RealtimePhase.error,
              error: () => 'Stream error: $e',
            );
          }
        },
        onDone: () {
          // Stream closed normally (after stream_complete or error event)
        },
      );
    } catch (e) {
      state = state.copyWith(
        phase: RealtimePhase.error,
        error: () => 'Failed to connect: $e',
      );
    }
  }

  void _handleEvent(RealtimeEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case 'chunk_ready':
        // Append new segments, maintaining sorted order
        final newSegments = event.segments;
        final allSegments = [...state.segments, ...newSegments];
        allSegments.sort((a, b) => a.start.compareTo(b.start));

        // Re-sequence IDs
        for (int i = 0; i < allSegments.length; i++) {
          allSegments[i].id = i;
        }

        state = state.copyWith(
          segments: allSegments,
          processedThrough: event.processedThrough,
          chunksReady: event.chunksDone,
          chunksTotal: event.chunksTotal,
        );
        break;

      case 'buffer_ready':
        state = state.copyWith(
          phase: RealtimePhase.streaming,
          totalDuration: event.totalDuration,
          chunksReady: event.data['chunks_ready'] as int? ?? state.chunksReady,
          chunksTotal: event.data['total_chunks'] as int? ?? state.chunksTotal,
        );
        break;

      case 'stream_complete':
        state = state.copyWith(
          phase: RealtimePhase.complete,
          totalDuration: event.totalDuration,
          chunksReady: state.chunksTotal,
        );
        break;

      case 'error':
        state = state.copyWith(
          phase: RealtimePhase.error,
          error: () => event.data['message'] as String? ?? 'Unknown error',
        );
        break;
    }
  }

  /// Notify backend of a seek to an unprocessed region (debounced 300ms)
  void notifySeek(double targetSeconds) {
    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 300), () {
      if (state.fileId != null &&
          targetSeconds > state.processedThrough &&
          state.phase == RealtimePhase.streaming) {
        _streamService.seekTo(state.fileId!, targetSeconds);
      }
    });
  }

  /// Create a SubtitleProject from accumulated segments for editor handoff.
  /// Calls the existing POST /subtitles/create/{file_id} endpoint.
  Future<SubtitleProject?> createProjectForEditor(String originalFilename) async {
    if (state.fileId == null || state.segments.isEmpty) return null;

    try {
      // The existing endpoint accepts segments in the request body
      final project = await _subtitleService.createProject(
        state.fileId!,
        projectName: originalFilename,
      );
      return project;
    } catch (e) {
      state = state.copyWith(error: () => 'Failed to create project: $e');
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(error: () => null);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _seekDebounce?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for RealtimeNotifier
final realtimeNotifierProvider =
    StateNotifierProvider.autoDispose<RealtimeNotifier, RealtimeState>((ref) {
  final streamService = ref.watch(realtimeStreamServiceProvider);
  final subtitleService = ref.watch(subtitleServiceProvider);
  return RealtimeNotifier(streamService, subtitleService);
});
