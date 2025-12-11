# Google OAuth Setup Guide for RomaSub.AI Frontend

## Overview
This guide explains how to set up and use Google OAuth authentication in the RomaSub.AI Flutter application.

## Prerequisites
✅ Google Cloud Console project created
✅ OAuth 2.0 Client ID configured
✅ Backend API running with Google OAuth enabled

## Configuration

### 1. Google Cloud Console Setup

Your Google OAuth credentials are already configured:
- **Client ID**: `1095223738206-ibhfm3c31t6spfipk9knb6ekvqh18tnb.apps.googleusercontent.com`
- **Client Secret**: `YGOCSPX-PwyB4JQgi8E8DE3Hbd3JcMAb092y`

### 2. Platform Configuration

#### Web Platform ✅
**File**: `web/index.html`

The Google Client ID is already configured in the HTML meta tag:
```html
<meta name="google-signin-client_id" content="1095223738206-ibhfm3c31t6spfipk9knb6ekvqh18tnb.apps.googleusercontent.com">
```

#### Android Platform ⚠️ (Requires Additional Setup)

**Step 1**: Download OAuth Configuration
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to: APIs & Services → Credentials
3. Find your OAuth 2.0 Client ID
4. Download the JSON configuration file

**Step 2**: Get SHA-1 Certificate Fingerprint
```bash
# Navigate to Android folder
cd FrontEnd/android

# Generate debug SHA-1
./gradlew signingReport

# Look for SHA-1 fingerprint under "Variant: debug"
```

**Step 3**: Add SHA-1 to Google Cloud Console
1. Go to APIs & Services → Credentials
2. Click on your OAuth 2.0 Client ID (Android type)
3. Add the SHA-1 fingerprint
4. Save changes

**Step 4**: Update AndroidManifest.xml (Already Done ✅)
Internet permission has been added:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

#### iOS Platform ⚠️ (If needed in future)

**Step 1**: Update `ios/Runner/Info.plist`
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Add your reversed client ID here -->
            <string>com.googleusercontent.apps.1095223738206-ibhfm3c31t6spfipk9knb6ekvqh18tnb</string>
        </array>
    </dict>
</array>
```

### 3. Flutter Code Configuration

#### Dependencies (Already Installed ✅)
```yaml
dependencies:
  google_sign_in: ^6.2.1
  flutter_riverpod: ^2.5.1
```

#### Auth Provider Configuration
The Google Sign-In is automatically initialized in `lib/providers/auth_provider.dart`:
```dart
GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
);
```

## How It Works

### User Flow
1. User clicks "Continue with Google" button
2. Google Sign-In dialog appears
3. User selects Google account
4. App receives ID token from Google
5. ID token is sent to backend at `/auth/google`
6. Backend verifies token and creates/returns user
7. Frontend stores JWT token and user info
8. User is redirected to Dashboard

### Code References

**Login Screen**: `lib/screens/auth/login_screen.dart:61-77`
```dart
Future<void> _handleGoogleSignIn() async {
  final success = await ref.read(authNotifierProvider.notifier).signInWithGoogle();

  if (success && mounted) {
    AppRoutes.clearAndGo(context, AppRoutes.dashboard);
  }
}
```

**Auth Provider**: `lib/providers/auth_provider.dart:140-189`
- Handles Google Sign-In flow
- Gets ID token
- Sends to backend
- Stores response

**Auth Service**: `lib/services/auth_service.dart:56-68`
- API call to backend `/auth/google`
- Sends ID token
- Receives JWT and user data

## Platform Support

### ✅ Supported Platforms
- **Web** (Chrome, Edge, Firefox)
- **Android** (requires SHA-1 setup)
- **iOS** (requires Info.plist setup)

### ❌ Unsupported Platforms
- **Windows Desktop** - Google Sign-In button will be hidden
- **macOS Desktop** - Google Sign-In button will be hidden
- **Linux Desktop** - Google Sign-In button will be hidden

**Note**: On desktop platforms, the Google Sign-In button is automatically hidden and users must use email/password authentication.

## Testing

### ✅ Test on Web (RECOMMENDED)
```bash
cd FrontEnd
flutter run -d chrome
```
This will open the app in Chrome where Google Sign-In is fully functional.

### ❌ Test on Windows Desktop (Google Sign-In Disabled)
```bash
cd FrontEnd
flutter run -d windows
```
The Google Sign-In button will be hidden. Use email/password login instead.

### ⚠️ Test on Android (Requires SHA-1 setup)
```bash
cd FrontEnd
flutter run -d android
```
Ensure you've added SHA-1 fingerprint to Google Cloud Console first.

## Troubleshooting

### Error: "MissingPluginException(No implementation found for method init)"
**Issue**: You're running on Windows/macOS/Linux desktop
**Solution**:
- Use `flutter run -d chrome` for web instead
- The Google Sign-In button is automatically hidden on desktop platforms
- Use email/password authentication on desktop

### Error: "Google Sign-In is only available on Web, Android, and iOS"
**Issue**: Attempted Google Sign-In on unsupported platform
**Solution**: This is expected behavior. Use email/password login on desktop platforms.

### Error: "Failed to get ID token from Google"
**Solution**:
- Ensure Google Client ID is correct in `web/index.html`
- For Android: Verify SHA-1 fingerprint is added in Google Cloud Console

### Error: "Invalid Google token" (Backend)
**Solution**:
- Verify backend `.env` has correct `GOOGLE_CLIENT_ID`
- Check that backend is running and accessible at `http://localhost:8000`

### Error: "PlatformException(sign_in_failed)"
**Solution**:
- For Web: Check browser console for specific error
- For Android: Verify google-services.json is in android/app/ (if using Firebase)
- Ensure OAuth client type matches platform (Web client for web, Android client for Android)

## Backend Configuration

The backend is already configured with Google OAuth. Verify these settings in `RomaSub.Ai/.env`:

```env
GOOGLE_CLIENT_ID=1095223738206-ibhfm3c31t6spfipk9knb6ekvqh18tnb.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=YGOCSPX-PwyB4JQgi8E8DE3Hbd3JcMAb092y
```

## Security Notes

⚠️ **Important**:
- Never commit `.env` files with production credentials to Git
- The Client ID in `web/index.html` is safe to commit (public)
- Client Secret should NEVER be in frontend code (kept in backend only)
- For production, use environment-specific OAuth credentials

## What's Been Removed

Microsoft and Apple Sign-In buttons have been removed:
- ✅ Login screen: Only Google button remains
- ✅ Signup screen: Only Google button remains
- ✅ App strings: Removed Microsoft and Apple strings

## Summary

✅ **Completed**:
- Google OAuth configured for Web platform
- Android permissions added
- Microsoft/Apple buttons removed
- Frontend code connected to backend API

⚠️ **Pending** (Optional):
- Android SHA-1 fingerprint configuration
- iOS configuration (if deploying to iOS)
- Production OAuth credentials

## Quick Start

1. **Backend**: Ensure backend is running on `http://localhost:8000`
2. **Frontend**: Run `flutter run -d chrome` or `flutter run -d windows`
3. **Test**: Click "Continue with Google" on login/signup screen
4. **Verify**: Check that user is created in database and redirected to dashboard

---

For more information:
- [Google Sign-In Flutter Package](https://pub.dev/packages/google_sign_in)
- [Google OAuth Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Backend API Documentation](../CLAUDE.md)
