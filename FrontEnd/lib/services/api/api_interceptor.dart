import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage_service.dart';

/// Dio interceptor that automatically injects JWT token into requests
/// and handles 401 unauthorized errors
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get storage service
    final storageAsync = _ref.read(storageServiceProvider);

    // Wait for storage to be ready
    await storageAsync.when(
      data: (storage) async {
        // Get JWT token
        final token = await storage.getToken();

        // Inject Authorization header if token exists
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      },
      loading: () {},
      error: (_, _) {},
    );

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle 401 Unauthorized - token expired or invalid
    if (err.response?.statusCode == 401) {
      // Token expired - trigger logout
      // This will be handled by AuthNotifier in auth_provider.dart
      _handleTokenExpiration();
    }

    handler.next(err);
  }

  /// Handle token expiration by clearing stored data
  void _handleTokenExpiration() {
    final storageAsync = _ref.read(storageServiceProvider);
    storageAsync.whenData((storage) async {
      await storage.clearAll();
      // Note: AuthNotifier will handle navigation to login screen
    });
  }
}
