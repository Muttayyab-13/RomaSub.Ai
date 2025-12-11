import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform utility functions
class PlatformUtils {
  /// Check if Google Sign-In is supported on current platform
  /// Supported: Web, Android, iOS
  /// Not supported: Windows, macOS, Linux
  static bool get isGoogleSignInSupported {
    return kIsWeb || Platform.isAndroid || Platform.isIOS;
  }

  /// Get current platform name for display
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
