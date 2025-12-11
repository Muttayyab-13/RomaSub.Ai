import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

/// Google OAuth service for Windows desktop application
/// Uses authorization code flow with local HTTP server
class GoogleOAuthDesktopService {
  static const String clientId = '1095223738206-39barm48obffu8tpfo919bg3be2aa4o5.apps.googleusercontent.com';

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
      print('📡 OAuth server started on $redirectUri');

      // 2. Build Google OAuth URL
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scope,
        'access_type': 'offline',
        'prompt': 'select_account',
      });

      print('🌐 Opening browser for Google authentication...');

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
              print('❌ Google OAuth error: $error');
              completer.complete(null);
            } else if (code != null) {
              print('✅ Authorization code received');

              // Bring the Flutter app window to foreground
              try {
                await windowManager.show();
                await windowManager.focus();
                print('🎯 App brought to foreground');
              } catch (e) {
                print('⚠️  Could not bring window to foreground: $e');
              }

              completer.complete(code);
            } else {
              print('❌ No code or error in response');
              completer.complete(null);
            }

            // Close server after handling callback
            await server?.close();
          }
        } catch (e) {
          print('❌ Error handling callback: $e');
          completer.complete(null);
          await server?.close();
        }
      });

      // 5. Set timeout for OAuth flow (2 minutes)
      Timer(const Duration(minutes: 2), () {
        if (!completer.isCompleted) {
          print('⏱️  OAuth timeout');
          completer.complete(null);
          server?.close();
        }
      });

      return await completer.future;
    } catch (e) {
      print('❌ OAuth error: $e');
      await server?.close();
      return null;
    }
  }

  /// Build HTML response for OAuth callback page
  String _buildHtmlResponse(bool success) {
    if (success) {
      return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Authentication Successful</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            background: white;
            padding: 3rem;
            border-radius: 1rem;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 450px;
        }
        .success-icon {
            font-size: 4rem;
            margin-bottom: 1rem;
            animation: checkmark 0.5s ease-in-out;
        }
        @keyframes checkmark {
            0% { transform: scale(0); }
            50% { transform: scale(1.2); }
            100% { transform: scale(1); }
        }
        h1 {
            color: #2d3748;
            margin-bottom: 0.5rem;
            font-size: 1.75rem;
        }
        p {
            color: #718096;
            font-size: 1rem;
            margin-bottom: 1rem;
        }
        .app-instruction {
            background: #f0f4ff;
            border-left: 4px solid #667eea;
            padding: 1rem;
            margin: 1.5rem 0;
            border-radius: 0.5rem;
            font-weight: 600;
            color: #4a5568;
        }
        .countdown {
            color: #667eea;
            font-size: 0.9rem;
            margin-top: 1rem;
            font-style: italic;
        }
    </style>
    <script>
        // Try to close the window (works in some browsers)
        let countdown = 3;
        const countdownEl = document.getElementById('countdown');

        const timer = setInterval(() => {
            countdown--;
            if (countdownEl) {
                countdownEl.textContent = countdown;
            }
            if (countdown <= 0) {
                clearInterval(timer);
                // Attempt to close (may not work in all browsers)
                window.close();
                // If still open after 500ms, show alternative message
                setTimeout(() => {
                    const instruction = document.getElementById('instruction');
                    if (instruction) {
                        instruction.innerHTML = '👈 Return to RomaSub.AI app to continue';
                    }
                }, 500);
            }
        }, 1000);
    </script>
</head>
<body>
    <div class="container">
        <div class="success-icon">✅</div>
        <h1>Authentication Successful!</h1>
        <p>You have successfully signed in with Google.</p>
        <div class="app-instruction" id="instruction">
            👈 Return to the RomaSub.AI app to continue
        </div>
        <p class="countdown">Attempting to close in <span id="countdown">3</span> seconds...</p>
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
    <title>Authentication Failed</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        }
        .container {
            background: white;
            padding: 3rem;
            border-radius: 1rem;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 450px;
        }
        .error-icon {
            font-size: 4rem;
            margin-bottom: 1rem;
            animation: shake 0.5s ease-in-out;
        }
        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            25% { transform: translateX(-10px); }
            75% { transform: translateX(10px); }
        }
        h1 {
            color: #2d3748;
            margin-bottom: 0.5rem;
            font-size: 1.75rem;
        }
        p {
            color: #718096;
            font-size: 1rem;
            margin-bottom: 1rem;
        }
        .app-instruction {
            background: #fff5f5;
            border-left: 4px solid #f5576c;
            padding: 1rem;
            margin: 1.5rem 0;
            border-radius: 0.5rem;
            font-weight: 600;
            color: #4a5568;
        }
        .countdown {
            color: #f5576c;
            font-size: 0.9rem;
            margin-top: 1rem;
            font-style: italic;
        }
    </style>
    <script>
        let countdown = 5;
        const countdownEl = document.getElementById('countdown');

        const timer = setInterval(() => {
            countdown--;
            if (countdownEl) {
                countdownEl.textContent = countdown;
            }
            if (countdown <= 0) {
                clearInterval(timer);
                window.close();
                setTimeout(() => {
                    const instruction = document.getElementById('instruction');
                    if (instruction) {
                        instruction.innerHTML = '👈 Return to RomaSub.AI app to try again';
                    }
                }, 500);
            }
        }, 1000);
    </script>
</head>
<body>
    <div class="container">
        <div class="error-icon">❌</div>
        <h1>Authentication Failed</h1>
        <p>There was an error signing in with Google. Please try again or use email/password login.</p>
        <div class="app-instruction" id="instruction">
            👈 Return to the RomaSub.AI app to try again
        </div>
        <p class="countdown">Attempting to close in <span id="countdown">5</span> seconds...</p>
    </div>
</body>
</html>
''';
    }
  }

  /// Get redirect URI (useful for backend communication)
  String getRedirectUri() => redirectUri;
}
