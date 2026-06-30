import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import '../core/config/oauth_config.dart';

/// Google OAuth service for Windows desktop application
/// Uses authorization code flow with local HTTP server
class GoogleOAuthDesktopService {
  /// Pulled from `OAuthConfig.googleClientId` so it stays in lockstep with
  /// the backend's `GOOGLE_CLIENT_ID` env value (the auth code is exchanged
  /// server-side and Google requires the same client on both ends).
  static const String clientId = OAuthConfig.googleClientId;

  static const String redirectUri = 'http://localhost:8080/auth/callback';
  static const String scope = 'email profile openid';
  static const int serverPort = 8080;

  /// Sign in with Google and return authorization code
  /// Returns null if user cancels or error occurs
  Future<String?> signIn() async {
    final completer = Completer<String?>();
    HttpServer? server;

    try {
      // 1. Start local HTTP server to capture callback
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, serverPort);
      debugPrint('📡 OAuth server started on $redirectUri');

      // 2. Build Google OAuth URL
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scope,
        'access_type': 'offline',
        'prompt': 'select_account',
      });

      debugPrint('🌐 Opening browser for Google authentication...');

      // 3. Open browser for authentication
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch browser for authentication');
      }

      // 4. Listen for OAuth callback
      server.listen((HttpRequest request) async {
        try {
          if (request.uri.path == '/auth/callback') {
            final code = request.uri.queryParameters['code'];
            final error = request.uri.queryParameters['error'];

            // Send HTML response to browser
            final htmlResponse = _buildHtmlResponse(error == null);
            request.response
              ..statusCode = 200
              ..headers.set('Content-Type', 'text/html; charset=utf-8')
              ..write(htmlResponse);
            await request.response.close();

            // Complete with result
            if (error != null) {
              debugPrint('❌ Google OAuth error: $error');
              completer.complete(null);
            } else if (code != null) {
              debugPrint('✅ Authorization code received');

              // Bring the Flutter app window to foreground
              try {
                await windowManager.show();
                await windowManager.focus();
                debugPrint('🎯 App brought to foreground');
              } catch (e) {
                debugPrint('⚠️  Could not bring window to foreground: $e');
              }

              completer.complete(code);
            } else {
              debugPrint('❌ No code or error in response');
              completer.complete(null);
            }

            // Close server after handling callback
            await server?.close();
          }
        } catch (e) {
          debugPrint('❌ Error handling callback: $e');
          completer.complete(null);
          await server?.close();
        }
      });

      // 5. Set timeout for OAuth flow (2 minutes)
      Timer(const Duration(minutes: 2), () {
        if (!completer.isCompleted) {
          debugPrint('⏱️  OAuth timeout');
          completer.complete(null);
          server?.close();
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('❌ OAuth error: $e');
      await server?.close();
      return null;
    }
  }

  /// Build HTML response for OAuth callback page - Black & White theme
  String _buildHtmlResponse(bool success) {
    if (success) {
      return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Authentication Successful - RomaSub.AI</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 48px;
            border-radius: 16px;
            box-shadow: 0 4px 24px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 420px;
            border: 1px solid #e0e0e0;
        }
        .icon {
            width: 72px;
            height: 72px;
            background: black;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            animation: pop 0.4s ease-out;
        }
        @keyframes pop {
            0% { transform: scale(0); }
            70% { transform: scale(1.1); }
            100% { transform: scale(1); }
        }
        .checkmark { font-size: 36px; color: white; }
        h1 { color: #1a1a1a; font-size: 24px; margin-bottom: 8px; font-weight: 700; }
        p { color: #666; font-size: 15px; margin-bottom: 24px; line-height: 1.5; }
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: #f0f0f0;
            padding: 12px 20px;
            border-radius: 24px;
            font-weight: 600;
            color: #333;
            font-size: 14px;
        }
        .countdown { margin-top: 20px; color: #999; font-size: 13px; }
    </style>
    <script>
        let countdown = 3;
        setInterval(() => {
            countdown--;
            const el = document.getElementById('countdown');
            if (el) el.textContent = countdown;
            if (countdown <= 0) {
                window.close();
                document.getElementById('badge').innerHTML = '👈 Return to RomaSub.AI app';
            }
        }, 1000);
    </script>
</head>
<body>
    <div class="container">
        <div class="icon"><span class="checkmark">✓</span></div>
        <h1>Authentication Successful!</h1>
        <p>You've signed in with Google successfully.</p>
        <div class="badge" id="badge">🚀 Return to the app to continue</div>
        <p class="countdown">Closing in <span id="countdown">3</span>s...</p>
    </div>
</body>
</html>
''';
    } else {
      return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Authentication Failed - RomaSub.AI</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 48px;
            border-radius: 16px;
            box-shadow: 0 4px 24px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 420px;
            border: 1px solid #e0e0e0;
        }
        .icon {
            width: 72px;
            height: 72px;
            background: #333;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            animation: shake 0.4s ease-out;
        }
        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            25% { transform: translateX(-8px); }
            75% { transform: translateX(8px); }
        }
        .x-mark { font-size: 36px; color: white; }
        h1 { color: #1a1a1a; font-size: 24px; margin-bottom: 8px; font-weight: 700; }
        p { color: #666; font-size: 15px; margin-bottom: 24px; line-height: 1.5; }
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: #f0f0f0;
            padding: 12px 20px;
            border-radius: 24px;
            font-weight: 600;
            color: #333;
            font-size: 14px;
        }
        .countdown { margin-top: 20px; color: #999; font-size: 13px; }
    </style>
    <script>
        let countdown = 5;
        setInterval(() => {
            countdown--;
            const el = document.getElementById('countdown');
            if (el) el.textContent = countdown;
            if (countdown <= 0) {
                window.close();
                document.getElementById('badge').innerHTML = '👈 Return to RomaSub.AI to try again';
            }
        }, 1000);
    </script>
</head>
<body>
    <div class="container">
        <div class="icon"><span class="x-mark">✕</span></div>
        <h1>Authentication Failed</h1>
        <p>Something went wrong. Please try again or use email login.</p>
        <div class="badge" id="badge">👈 Return to the app to try again</div>
        <p class="countdown">Closing in <span id="countdown">5</span>s...</p>
    </div>
</body>
</html>
''';
    }
  }

  /// Get redirect URI (useful for backend communication)
  String getRedirectUri() => redirectUri;
}
