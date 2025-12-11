# Quick Start: Testing Google OAuth

## ⚠️ Important: Platform Limitation

**Google Sign-In does NOT work on Windows/macOS/Linux desktop apps.**

The `google_sign_in` package only supports:
- ✅ **Web** (Chrome, Firefox, Edge)
- ✅ **Android** (mobile/emulator)
- ✅ **iOS** (mobile/simulator)

## 🚀 How to Test Google Sign-In

### Option 1: Web (RECOMMENDED - Easiest)

```bash
cd FrontEnd
flutter run -d chrome
```

**What you'll see:**
- Google Sign-In button visible on login/signup screens
- Click it to sign in with your Google account
- Works immediately without additional setup

### Option 2: Windows Desktop (Email/Password Only)

```bash
cd FrontEnd
flutter run -d windows
```

**What you'll see:**
- NO Google Sign-In button (automatically hidden)
- Only email/password login available
- This is expected behavior

## 🎯 Current Status

### ✅ What's Working
- Backend Google OAuth endpoint: `/auth/google`
- Frontend code integrated
- Platform detection (hides button on desktop)
- Error handling

### ✅ What's Configured
- Google Client ID in `.env`
- Google Client ID in `web/index.html`
- Android permissions
- Auto-hide on unsupported platforms

## 📝 Testing Instructions

### Step 1: Start Backend
```bash
# In main project folder
uvicorn app.main:app --reload --port 8000
```

### Step 2: Start Frontend (Web)
```bash
# In FrontEnd folder
flutter run -d chrome
```

### Step 3: Test Google Sign-In
1. Click "Continue with Google" button
2. Select your Google account
3. Grant permissions
4. You should be redirected to Dashboard
5. Check backend logs to see user created

### Step 4: Verify in Database
```sql
SELECT * FROM users WHERE google_id IS NOT NULL;
```

## 🐛 If You See Errors on Windows

**Error**: `MissingPluginException(No implementation found for method init)`

**This is normal!** It means:
- You're on Windows desktop (unsupported platform)
- Google Sign-In tried to initialize but failed
- The fix has been applied - button is now hidden

**Solution**:
- Press 'R' to hot restart the app
- The Google button should now be hidden
- Use email/password login instead
- OR switch to web: `flutter run -d chrome`

## 📚 Full Documentation

See `GOOGLE_AUTH_SETUP.md` for:
- Complete setup guide
- Android configuration
- iOS configuration
- Troubleshooting
- Security notes

## 🎉 Summary

**To test Google Sign-In RIGHT NOW:**
```bash
# Terminal 1 (Backend)
uvicorn app.main:app --reload --port 8000

# Terminal 2 (Frontend)
cd FrontEnd
flutter run -d chrome
```

Then click "Continue with Google" and sign in!

---

**Note**: The Windows desktop version will only show email/password login, which is the expected behavior since Google Sign-In is not supported on desktop platforms.
