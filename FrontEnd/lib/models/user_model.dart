/// User model representing authenticated user data
class UserModel {
  final String uuid;
  final String firstName;
  final String lastName;
  final String email;
  final String? profilePictureUrl;
  final bool isVerified;
  final String? googleId;
  final DateTime? createdAt;

  UserModel({
    required this.uuid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.profilePictureUrl,
    required this.isVerified,
    this.googleId,
    this.createdAt,
  });

  /// Create UserModel from JSON (API response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uuid: json['uuid'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      isVerified: json['is_verified'] ?? false,
      googleId: json['google_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert UserModel to JSON (for storage)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'profile_picture_url': profilePictureUrl,
      'is_verified': isVerified,
      'google_id': googleId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Get full name
  String get fullName => '$firstName $lastName';

  /// Get user initial (first letter of first name)
  String get initial => firstName.isNotEmpty ? firstName[0].toUpperCase() : '';

  /// Check if user signed in with Google
  bool get isGoogleUser => googleId != null && googleId!.isNotEmpty;

  /// Copy with method for updating user data
  UserModel copyWith({
    String? uuid,
    String? firstName,
    String? lastName,
    String? email,
    String? profilePictureUrl,
    bool? isVerified,
    String? googleId,
    DateTime? createdAt,
  }) {
    return UserModel(
      uuid: uuid ?? this.uuid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      isVerified: isVerified ?? this.isVerified,
      googleId: googleId ?? this.googleId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'UserModel(name: $fullName, email: $email)';
}
