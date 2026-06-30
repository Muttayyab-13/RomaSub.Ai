/// Custom API exception classes for handling different types of errors
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Network connectivity errors (timeout, no internet, etc.)
class NetworkException extends ApiException {
  NetworkException(super.message);
}

/// 401 Unauthorized - Invalid credentials or expired token
class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message, 401);
}

/// 400 Bad Request - Validation errors
class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;

  ValidationException(String message, [this.errors]) : super(message, 400);
}

/// Server errors (5xx) or other unexpected errors
class ServerException extends ApiException {
  ServerException(super.message, [super.statusCode]);
}
