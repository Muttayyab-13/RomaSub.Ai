/// API configuration with base URL and endpoint definitions
class ApiConfig {
  // Base URL - set via --dart-define=BASE_URL=http://<IP>:8000
  // Defaults to localhost for local development
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  // Root / health
  static const String health = '/health';

  // Authentication Endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login/json';
  static const String authGoogle = '/auth/google';
  static const String authGoogleCode = '/auth/google/code'; // For desktop OAuth
  static const String authMe = '/auth/me';
  static const String authChangePassword = '/auth/change-password';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authResetPassword = '/auth/reset-password';
  static const String authVerifyEmail = '/auth/verify-email';
  static const String authResendVerificationOtp =
      '/auth/resend-verification-otp';

  // Media Endpoints
  static const String mediaUpload = '/media/upload';
  static String mediaInfo(String fileId) => '/media/$fileId';
  static String mediaExtractAudio(String fileId) =>
      '/media/$fileId/extract-audio';
  static String mediaDelete(String fileId) => '/media/$fileId';

  // ASR (Transcription) Endpoints
  static String asrTranscribe(String fileId) => '/asr/transcribe/$fileId';
  static String asrResult(String fileId) => '/asr/result/$fileId';
  static String asrResultSrt(String fileId) => '/asr/result/$fileId/srt';
  static const String asrLanguages = '/asr/languages';

  // Transliteration Endpoints
  static const String transliterateText = '/transliterate/text';
  static String transliterateFile(String fileId) =>
      '/transliterate/$fileId/anonymous';
  static String transliterateResult(String fileId) =>
      '/transliterate/result/$fileId';
  static String transliterateResultSrt(String fileId) =>
      '/transliterate/result/$fileId/srt';

  // Subtitle Endpoints
  static String subtitleCreate(String fileId) => '/subtitles/create/$fileId';
  static String subtitleProject(String subtitleId) => '/subtitles/$subtitleId';
  static String subtitleSegment(String subtitleId, int segmentId) =>
      '/subtitles/$subtitleId/segments/$segmentId';
  static String subtitleAddSegment(String subtitleId) =>
      '/subtitles/$subtitleId/segments';
  static String subtitleBulkUpdate(String subtitleId) =>
      '/subtitles/$subtitleId/bulk-update';
  static String subtitleFixOverlaps(String subtitleId) =>
      '/subtitles/$subtitleId/fix-overlaps';
  static String subtitleExport(String subtitleId) =>
      '/subtitles/$subtitleId/export';
  static String subtitleExportVideo(String subtitleId) =>
      '/subtitles/$subtitleId/export-video';

  // Media Streaming
  static String mediaStream(String fileId) => '/media/$fileId/stream';

  /// Full URL for video streaming (used by media_kit player)
  static String mediaStreamUrl(String fileId) =>
      '$baseUrl/media/$fileId/stream';

  // Realtime Streaming Endpoints
  static String realtimeStream(String fileId) => '/realtime/stream/$fileId';
  static String realtimeSeek(String fileId) => '/realtime/seek/$fileId';
  static String realtimeStatus(String fileId) => '/realtime/status/$fileId';

  /// Full URL for SSE stream (used by Dio stream client)
  static String realtimeStreamUrl(String fileId) =>
      '$baseUrl/realtime/stream/$fileId';

  // Projects & Exports listing
  static const String projectsList = '/subtitles/list/projects';
  static const String exportsList = '/subtitles/list/exports';

  // Feedback
  static const String feedbackSubmit = '/feedback/submit';
  static const String feedbackList = '/feedback/list';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  // Video render can take minutes; use a much longer receive timeout.
  static const Duration videoExportTimeout = Duration(minutes: 10);

  // File Upload Limits
  static const int maxFileSizeMB = 2048;
  static const List<String> allowedVideoExtensions = [
    'mp4',
    'avi',
    'mkv',
    'mov',
    'webm',
  ];
  static const List<String> allowedAudioExtensions = [
    'mp3',
    'wav',
    'm4a',
    'flac',
    'ogg',
  ];

  static List<String> get allowedExtensions => [
    ...allowedVideoExtensions,
    ...allowedAudioExtensions,
  ];
}
