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
  final double transcriptionProgress;
  final String? currentFileName;
  final UploadResponseModel? uploadResponse;
  final TranscriptionModel? transcription;
  final String? error;

  UploadState({
    this.phase = UploadPhase.idle,
    this.uploadProgress = 0.0,
    this.transcriptionProgress = 0.0,
    this.currentFileName,
    this.uploadResponse,
    this.transcription,
    this.error,
  });

  /// Check if currently processing
  bool get isProcessing =>
      phase == UploadPhase.uploading ||
      phase == UploadPhase.transcribing ||
      phase == UploadPhase.extractingAudio ||
      phase == UploadPhase.transliterating;

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
        final percent = (transcriptionProgress * 100).toInt();
        return 'Transcribing audio... $percent%';
      case UploadPhase.transliterating:
        return 'Transliterating to Roman Urdu...';
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
    double? transcriptionProgress,
    String? currentFileName,
    UploadResponseModel? uploadResponse,
    TranscriptionModel? transcription,
    String? error,
  }) {
    return UploadState(
      phase: phase ?? this.phase,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      transcriptionProgress:
          transcriptionProgress ?? this.transcriptionProgress,
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
  transliterating,
  completed,
  error,
}

/// Upload state notifier managing the upload and transcription flow
class UploadNotifier extends StateNotifier<UploadState> {
  final MediaService _mediaService;
  final TranscriptionService _transcriptionService;

  UploadNotifier(this._mediaService, this._transcriptionService)
    : super(UploadState());

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

      // Step 3: Start transcription with simulated progress
      state = state.copyWith(
        phase: UploadPhase.transcribing,
        transcriptionProgress: 0.0,
      );

      // Start progress simulation DURING transcription
      // Estimate ~30 seconds for typical video, increment smoothly
      bool isComplete = false;
      double currentProgress = 0.0;

      final progressTimer =
          Stream.periodic(
            const Duration(milliseconds: 300),
            (count) => count,
          ).listen((count) {
            if (!isComplete) {
              // Gradually increase from 0 to 95% over ~30 seconds
              // Uses logarithmic curve for natural feel (fast start, slow end)
              currentProgress = (1 - (1 / (1 + count * 0.08))) * 0.95;
              state = state.copyWith(transcriptionProgress: currentProgress);
            }
          });

      try {
        // This call blocks until transcription is complete
        await _transcriptionService.transcribe(
          uploadResponse.fileId,
          language: language,
        );

        // Step 4: Get transcription result
        final transcription = await _transcriptionService
            .pollTranscriptionResult(uploadResponse.fileId);

        isComplete = true;
        await progressTimer.cancel();

        // Show transliterating phase (backend already did it, this is for UX)
        if (transcription.hasRomanUrdu) {
          state = state.copyWith(
            phase: UploadPhase.transliterating,
            transcriptionProgress: 1.0,
          );
          await Future.delayed(const Duration(milliseconds: 800));
        }

        // Completed!
        state = state.copyWith(
          phase: UploadPhase.completed,
          transcription: transcription,
          transcriptionProgress: 1.0,
        );

        return true;
      } finally {
        await progressTimer.cancel();
      }
    } on ApiException catch (e) {
      state = state.copyWith(phase: UploadPhase.error, error: e.message);
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
      state = state.copyWith(error: 'Failed to download SRT: ${e.toString()}');
      return null;
    }
  }

  /// Download Roman Urdu SRT file content
  ///
  /// Returns Roman Urdu SRT content as string if available
  Future<String?> downloadRomanUrduSrt() async {
    if (state.uploadResponse == null) return null;

    try {
      final srtContent = await _transcriptionService.getTransliterationSrt(
        state.uploadResponse!.fileId,
      );
      return srtContent;
    } catch (e) {
      // Fallback: generate client-side from cached segments
      if (state.transcription?.hasRomanUrdu == true) {
        return state.transcription!.toRomanUrduSrtContent();
      }
      state = state.copyWith(error: 'Failed to download Roman Urdu SRT: ${e.toString()}');
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
