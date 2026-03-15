/// API configuration with base URL and endpoint definitions
class ApiConfig {
  // Base URL - change to production URL when deploying
  static const String baseUrl = 'http://localhost:8000';

  // Authentication Endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login/json';
  static const String authGoogle = '/auth/google';
  static const String authGoogleCode = '/auth/google/code';  // For desktop OAuth
  static const String authMe = '/auth/me';
  static const String authChangePassword = '/auth/change-password';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authResetPassword = '/auth/reset-password';
  static const String authVerifyEmail = '/auth/verify-email';
  static const String authResendVerificationOtp = '/auth/resend-verification-otp';

  // Media Endpoints
  static const String mediaUpload = '/media/upload';
  static String mediaInfo(String fileId) => '/media/$fileId';
  static String mediaExtractAudio(String fileId) => '/media/$fileId/extract-audio';
  static String mediaDelete(String fileId) => '/media/$fileId';

  // ASR (Transcription) Endpoints
  static String asrTranscribe(String fileId) => '/asr/transcribe/$fileId';
  static String asrResult(String fileId) => '/asr/result/$fileId';
  static String asrResultSrt(String fileId) => '/asr/result/$fileId/srt';
  static const String asrLanguages = '/asr/languages';

  // Transliteration Endpoints
  static const String transliterateText = '/transliterate/text';
  static String transliterateFile(String fileId) => '/transliterate/$fileId/anonymous';
  static String transliterateResult(String fileId) => '/transliterate/result/$fileId';
  static String transliterateResultSrt(String fileId) => '/transliterate/result/$fileId/srt';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // File Upload Limits
  static const int maxFileSizeMB = 500;
  static const List<String> allowedVideoExtensions = [
    'mp4',
    'avi',
    'mkv',
    'mov',
    'webm'
  ];
  static const List<String> allowedAudioExtensions = [
    'mp3',
    'wav',
    'm4a',
    'flac',
    'ogg'
  ];

  static List<String> get allowedExtensions =>
      [...allowedVideoExtensions, ...allowedAudioExtensions];
}
