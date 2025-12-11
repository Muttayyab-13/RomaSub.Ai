import 'user_model.dart';

/// Authentication response model from login/register endpoints
class AuthResponseModel {
  final String accessToken;
  final String tokenType;
  final UserModel user;

  AuthResponseModel({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  /// Create AuthResponseModel from JSON (API response)
  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }

  @override
  String toString() =>
      'AuthResponseModel(tokenType: $tokenType, user: ${user.fullName})';
}

/// Registration response model (before email verification)
class RegistrationResponse {
  final String message;
  final String email;
  final String userUuid;

  RegistrationResponse({
    required this.message,
    required this.email,
    required this.userUuid,
  });

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationResponse(
      message: json['message'] as String,
      email: json['email'] as String,
      userUuid: json['user_uuid'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'email': email,
      'user_uuid': userUuid,
    };
  }

  @override
  String toString() => 'RegistrationResponse(message: $message, email: $email)';
}

/// Generic message response model for API responses
class MessageResponse {
  final String message;

  MessageResponse({required this.message});

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      message: json['message'] as String? ?? json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'message': message};
  }

  @override
  String toString() => 'MessageResponse(message: $message)';
}
