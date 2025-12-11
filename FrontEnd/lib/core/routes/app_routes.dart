import 'package:flutter/material.dart';
import '../../screens/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/forgot_password/forgot_password_email_screen.dart';
import '../../screens/auth/forgot_password/forgot_password_otp_screen.dart';
import '../../screens/auth/forgot_password/forgot_password_reset_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/projects/projects_screen.dart';
import '../../screens/exports/exports_screen.dart';
import '../../screens/feedback/feedback_screen.dart';
import '../../screens/settings/settings_screen.dart';

class AppRoutes {
  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String projects = '/projects';
  static const String exports = '/exports';
  static const String feedback = '/feedback';
  static const String settings = '/settings';
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
      default:
        return _buildRoute(LoginScreen());
    }
  }

  static MaterialPageRoute _buildRoute(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }

  // Navigation helpers
  static void to(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  static void replace(BuildContext context, String route) {
    Navigator.pushReplacementNamed(context, route);
  }

  static void clearAndGo(BuildContext context, String route) {
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  static void back(BuildContext context) {
    Navigator.pop(context);
  }
}
