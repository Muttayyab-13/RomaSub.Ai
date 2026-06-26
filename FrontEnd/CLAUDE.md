# RomaSub.AI Frontend

## Project Overview
RomaSub.AI is a Roman Urdu Caption Generator application built with Flutter. It allows users to upload video/audio files and generate accurate Roman Urdu subtitles using AI technology.

## Tech Stack
- **Framework:** Flutter 3.8.1+
- **Language:** Dart
- **State Management:** Simple InheritedWidget pattern
- **Architecture:** Feature-based folder structure with layered separation

## Project Structure

```
lib/
├── main.dart                    # App entry point with AppProvider wrapper
├── core/                        # App-wide configurations
│   ├── constants/
│   │   ├── app_assets.dart      # Asset paths (logos, images)
│   │   ├── app_colors.dart      # Color palette (light theme)
│   │   ├── app_sizes.dart       # Spacing, sizing, radius constants
│   │   └── app_strings.dart     # All UI text strings (centralized)
│   ├── routes/
│   │   └── app_routes.dart      # Route names & navigation helpers
│   ├── theme/
│   │   └── app_theme.dart       # Material 3 light theme configuration
│   └── utils/
│       └── validators.dart      # Form validation (email, password, name)
├── models/
│   ├── project_model.dart       # Project data model with JSON serialization
│   └── export_model.dart        # Export data model
├── providers/                   # Simple state management
│   ├── app_provider.dart        # Main InheritedWidget wrapper
│   ├── auth_provider.dart       # Authentication state (login, signup, logout)
│   └── project_provider.dart    # Projects state (CRUD, search)
├── screens/                     # Page-level widgets
│   ├── splash_screen.dart       # Initial loading screen (2s)
│   ├── auth/
│   │   ├── login_screen.dart    # Email/password login with validation
│   │   └── signup_screen.dart   # Registration with terms acceptance
│   ├── dashboard/
│   │   └── dashboard_screen.dart # Main dashboard with upload section
│   ├── projects/
│   │   └── projects_screen.dart  # Project grid with search
│   ├── exports/
│   │   └── exports_screen.dart   # Export history list
│   └── feedback/
│       └── feedback_screen.dart  # Star rating & feedback form
└── widgets/                     # Reusable UI components
    ├── common/
    │   ├── app_logo.dart        # Logo widget with fallback
    │   ├── app_text_field.dart  # Custom text field with error handling
    │   └── social_button.dart   # Social login button (Google, Microsoft, Apple)
    ├── cards/
    │   ├── project_card.dart    # Project display card
    │   └── export_card.dart     # Export item with download/delete actions
    └── sidebar/
        └── sidebar.dart         # Navigation sidebar with user profile
```

## Key Files Reference

### Entry Point
- `main.dart` - Wraps app with `AppProvider`, sets theme and initial route

### Navigation
- `core/routes/app_routes.dart` - All route constants and navigation methods:
  - `AppRoutes.to(context, route)` - Push named route
  - `AppRoutes.replace(context, route)` - Replace current route
  - `AppRoutes.clearAndGo(context, route)` - Clear stack and navigate
  - `AppRoutes.back(context)` - Pop current route

### State Management
- `providers/app_provider.dart` - Access via `AppProvider.of(context)`
  - `.auth` - AuthProvider instance
  - `.projects` - ProjectProvider instance

### Styling
- `core/constants/app_colors.dart` - All color definitions
- `core/constants/app_sizes.dart` - Spacing, radius, font sizes
- `core/theme/app_theme.dart` - Complete ThemeData configuration

### Validation
- `core/utils/validators.dart` - Returns `null` if valid, error string if invalid
  - `Validators.email(value)`
  - `Validators.password(value)`
  - `Validators.name(value)`

## App Flow

```
SplashScreen (2s)
    ↓
LoginScreen ←→ SignUpScreen
    ↓ (on success)
DashboardScreen
    ↓ (sidebar navigation)
├── DashboardScreen (home)
├── ProjectsScreen (grid view)
├── ExportsScreen (list view)
├── FeedbackScreen (rating form)
└── Settings (not implemented)
    ↓ (logout)
LoginScreen
```

## Commands

```bash
# Install dependencies
flutter pub get

# Run on Windows
flutter run -d windows

# Run on Chrome
flutter run -d chrome

# Run on connected device
flutter run

# Build APK
flutter build apk

# Build for web
flutter build web

# Analyze code
flutter analyze

# Clean build
flutter clean && flutter pub get
```

## Design Decisions

### Theme
- **Light theme** used consistently across all screens
- Primary color: Black (#000000)
- Accent color: Blue (#2563EB)
- Background: Light gray (#F8F9FA)
- Sidebar: Dark gray (#1F2937)

### State Management
- Simple `InheritedWidget` pattern chosen over Provider/Riverpod/Bloc for simplicity
- Suitable for current app size; can be migrated to Riverpod if app grows

### Validation
- Email accepts any valid email format (not restricted to Gmail)
- Password requires minimum 6 characters
- Names must contain at least one letter

### Navigation
- Named routes with centralized route management
- Helper methods for common navigation patterns

## TODO / Future Improvements

- [ ] Implement actual file upload with `file_picker` package
- [ ] Connect to backend API for authentication
- [ ] Add video/audio processing integration
- [ ] Implement Settings screen
- [ ] Add loading states and error handling
- [ ] Implement social login (Google, Microsoft, Apple)
- [ ] Add responsive design for mobile
- [ ] Persist auth state with `shared_preferences`
- [ ] Add unit and widget tests

## Dependencies

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^5.0.0
```

## Assets

```
assets/
└── images/
    └── logos/
        ├── logo.png      # Main logo
        └── logoo.png     # Alternative logo (splash)
```

## Code Conventions

- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variables/Methods:** `camelCase`
- **Constants:** `camelCase` (in constant classes)
- **Private:** Prefix with `_`

## Common Patterns

### Accessing State
```dart
final auth = AppProvider.of(context).auth;
final projects = AppProvider.of(context).projects;
```

### Navigation
```dart
AppRoutes.to(context, AppRoutes.dashboard);
AppRoutes.replace(context, AppRoutes.login);
AppRoutes.clearAndGo(context, AppRoutes.dashboard);
AppRoutes.back(context);
```

### Form Validation
```dart
String? error = Validators.email(value);
if (error != null) {
  // Show error
}
```

### Using Constants
```dart
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';

Container(
  padding: EdgeInsets.all(AppSizes.md),
  color: AppColors.surface,
  child: Text(AppStrings.dashboard),
)
```
