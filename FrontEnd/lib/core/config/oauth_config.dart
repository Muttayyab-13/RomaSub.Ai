/// OAuth client configuration.
///
/// The Google OAuth client ID is sourced at build time from the
/// `GOOGLE_CLIENT_ID` compile-time variable (`--dart-define=GOOGLE_CLIENT_ID=…`),
/// matching the value the backend reads from its `.env` file. The default
/// mirrors the current backend `.env` so a plain `flutter run` keeps working
/// without extra flags.
///
/// Pattern is identical to how `BASE_URL` is handled in
/// `lib/services/api/api_config.dart`.
class OAuthConfig {
  /// Google OAuth 2.0 client ID — same value as backend `GOOGLE_CLIENT_ID`.
  ///
  /// Override at build time:
  /// `flutter run --dart-define=GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com`
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '482012006439-vq9vj5n89nue6ans6n4301msppv42jnh.apps.googleusercontent.com',
  );
}
