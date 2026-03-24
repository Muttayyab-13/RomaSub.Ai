import 'package:flutter/material.dart';
import '../../screens/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/email_verification_screen.dart';
import '../../screens/auth/forgot_password/forgot_password_email_screen.dart';
import '../../screens/auth/forgot_password/forgot_password_otp_screen.dart';
import '../../screens/auth/forgot_password/forgot_password_reset_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/projects/projects_screen.dart';
import '../../screens/exports/exports_screen.dart';
import '../../screens/feedback/feedback_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/editor/subtitle_editor_screen.dart';
import '../../screens/realtime/realtime_viewer_screen.dart';
import '../../models/transcription_model.dart';

class AppRoutes {
  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String emailVerification = '/email-verification';
  static const String dashboard = '/dashboard';
  static const String projects = '/projects';
  static const String exports = '/exports';
  static const String feedback = '/feedback';
  static const String settings = '/settings';
  static const String editor = '/editor';
  static const String realtimeViewer = '/realtime-viewer';
  static const String forgotPasswordEmail = '/forgot-password';
  static const String forgotPasswordOtp = '/forgot-password/verify';
  static const String forgotPasswordReset = '/forgot-password/reset';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return _buildRoute(SplashScreen());
      case login:
        return _buildRoute(LoginScreen());
      case signup:
        return _buildRoute(SignUpScreen());
      case emailVerification:
        final email = routeSettings.arguments as String;
        return _buildRoute(EmailVerificationScreen(email: email));
      case dashboard:
        return _buildRoute(DashboardScreen());
      case projects:
        return _buildRoute(ProjectsScreen());
      case exports:
        return _buildRoute(const ExportsScreen());
      case feedback:
        return _buildRoute(FeedbackScreen());
      case forgotPasswordEmail:
        return _buildRoute(ForgotPasswordEmailScreen());
      case forgotPasswordOtp:
        return _buildRoute(ForgotPasswordOtpScreen());
      case forgotPasswordReset:
        return _buildRoute(ForgotPasswordResetScreen());
      case settings:
        return _buildRoute(SettingsScreen());
      case editor:
        final args = routeSettings.arguments as Map<String, dynamic>;
        return _buildRoute(SubtitleEditorScreen(
          fileId: args['fileId'] as String,
          transcription: args['transcription'] as TranscriptionModel?,
        ));
      case realtimeViewer:
        final args = routeSettings.arguments as Map<String, dynamic>;
        return _buildRoute(RealtimeViewerScreen(
          fileId: args['fileId'] as String,
          filename: args['filename'] as String,
        ));
      default:
        return _buildRoute(LoginScreen());
    }
  }

  static MaterialPageRoute _buildRoute(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }

  // Navigation helpers
  static void to(BuildContext context, String route, {Object? arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  static void replace(BuildContext context, String route, {Object? arguments}) {
    Navigator.pushReplacementNamed(context, route, arguments: arguments);
  }

  static void clearAndGo(BuildContext context, String route, {Object? arguments}) {
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false, arguments: arguments);
  }

  static void back(BuildContext context) {
    Navigator.pop(context);
  }
}
