import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/upload_response_model.dart';
import '../models/transcription_model.dart';
import '../services/media_service.dart';
import '../services/transcription_service.dart';
import '../services/api/api_exception.dart';

/// Upload state representing the current upload/transcription status
class UploadState {
  final UploadPhase phase;
  final double uploadProgress;
  final String? currentFileName;
  final UploadResponseModel? uploadResponse;
  final TranscriptionModel? transcription;
  final String? error;

  UploadState({
    this.phase = UploadPhase.idle,
    this.uploadProgress = 0.0,
    this.currentFileName,
    this.uploadResponse,
    this.transcription,
    this.error,
  });

  /// Check if currently processing
  bool get isProcessing =>
      phase == UploadPhase.uploading ||
      phase == UploadPhase.transcribing ||
      phase == UploadPhase.extractingAudio;

  /// Get progress percentage as string (0-100)
  String get progressPercent => '${(uploadProgress * 100).toInt()}%';

  /// Get user-friendly phase message
  String get phaseMessage {
    switch (phase) {
      case UploadPhase.idle:
        return 'Ready to upload';
      case UploadPhase.uploading:
        return 'Uploading file... $progressPercent';
      case UploadPhase.extractingAudio:
        return 'Extracting audio...';
      case UploadPhase.transcribing:
        return 'Transcribing audio... This may take a few minutes';
      case UploadPhase.completed:
        return 'Transcription complete!';
      case UploadPhase.error:
        return error ?? 'An error occurred';
    }
  }

  /// Copy with method for immutable state updates
  UploadState copyWith({
    UploadPhase? phase,
    double? uploadProgress,
    String? currentFileName,
    UploadResponseModel? uploadResponse,
    TranscriptionModel? transcription,
    String? error,
  }) {
    return UploadState(
      phase: phase ?? this.phase,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      currentFileName: currentFileName ?? this.currentFileName,
      uploadResponse: uploadResponse ?? this.uploadResponse,
      transcription: transcription ?? this.transcription,
      error: error,
    );
  }

  /// Create initial/reset state
  factory UploadState.initial() => UploadState();
}

/// Upload phases for tracking progress
enum UploadPhase {
  idle,
  uploading,
  extractingAudio,
  transcribing,
  completed,
  error,
}

/// Upload state notifier managing the upload and transcription flow
class UploadNotifier extends StateNotifier<UploadState> {
  final MediaService _mediaService;
  final TranscriptionService _transcriptionService;

  UploadNotifier(
    this._mediaService,
    this._transcriptionService,
  ) : super(UploadState());

  /// Upload and transcribe a file
  ///
  /// [filePath] - Absolute path to the file
  /// [language] - Language code for transcription (default: 'ur')
  ///
  /// Returns true if successful, false otherwise
  Future<bool> uploadAndTranscribe(
    String filePath, {
    String language = 'ur',
  }) async {
    try {
      // Reset state
      state = UploadState.initial();

      // Get filename
      final filename = filePath.split('\\').last.split('/').last;
      state = state.copyWith(
        phase: UploadPhase.uploading,
        currentFileName: filename,
      );

      // Step 1: Upload file with progress tracking
      final uploadResponse = await _mediaService.uploadFile(
        filePath,
        onProgress: (progress) {
          state = state.copyWith(uploadProgress: progress);
        },
      );

      state = state.copyWith(
        uploadResponse: uploadResponse,
        uploadProgress: 1.0,
      );

      // Step 2: Extract audio if it's a video file
      if (uploadResponse.isVideo) {
        state = state.copyWith(phase: UploadPhase.extractingAudio);
        await _mediaService.extractAudio(uploadResponse.fileId);
      }

      // Step 3: Start transcription
      state = state.copyWith(phase: UploadPhase.transcribing);
      await _transcriptionService.transcribe(
        uploadResponse.fileId,
        language: language,
      );

      // Step 4: Poll for transcription result
      final transcription = await _transcriptionService.pollTranscriptionResult(
        uploadResponse.fileId,
      );

      // Completed!
      state = state.copyWith(
        phase: UploadPhase.completed,
        transcription: transcription,
      );

      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        phase: UploadPhase.error,
        error: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        phase: UploadPhase.error,
        error: 'Upload failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Download SRT file content
  ///
  /// Returns SRT content as string if available
  Future<String?> downloadSrt() async {
    if (state.uploadResponse == null) return null;

    try {
      final srtContent = await _transcriptionService.getTranscriptionSrt(
        state.uploadResponse!.fileId,
      );
      return srtContent;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to download SRT: ${e.toString()}',
      );
      return null;
    }
  }

  /// Reset upload state
  void reset() {
    state = UploadState.initial();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Riverpod provider for UploadNotifier
final uploadNotifierProvider =
    StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  final mediaService = ref.watch(mediaServiceProvider);
  final transcriptionService = ref.watch(transcriptionServiceProvider);
  return UploadNotifier(mediaService, transcriptionService);
});
