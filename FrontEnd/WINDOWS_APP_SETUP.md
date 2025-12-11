# Windows Application Setup - RomaSub.AI

This guide explains the changes made to set up the Windows application with the correct name and icon.

## Changes Made

### 1. Application Name
The application now displays as **"RomaSub.AI"** in Windows:
- Window title: `RomaSub.AI`
- Executable name: `RomaSub.AI.exe`
- Product name: `RomaSub.AI`

### 2. Files Updated

#### `windows/runner/main.cpp`
- Changed window title from `romasubai_frontend` to `RomaSub.AI`

#### `windows/runner/Runner.rc`
- Updated Company Name: `COMSATS University Islamabad`
- Updated Product Name: `RomaSub.AI`
- Updated File Description: `RomaSub.AI - Roman Urdu Captions Generator`
- Updated Copyright: `Copyright (C) 2025 COMSATS University Islamabad`

#### `windows/CMakeLists.txt`
- Changed project name to `RomaSub.AI`
- Changed binary name to `RomaSub.AI`

### 3. Application Icon

The application icon needs to be converted from PNG to ICO format.

## How to Update the Icon

### Option 1: Automatic (Recommended)

Simply run the batch script:

```bash
cd FrontEnd
update_app_icon.bat
```

This will:
1. Check if Python is installed
2. Install Pillow if needed
3. Convert `assets/images/logos/logo.png` to `windows/runner/resources/app_icon.ico`

### Option 2: Manual

If you prefer manual conversion:

1. **Install Python and Pillow:**
   ```bash
   pip install pillow
   ```

2. **Run the Python script:**
   ```bash
   python convert_logo_to_ico.py
   ```

3. **Or use an online converter:**
   - Go to https://convertio.co/png-ico/
   - Upload `assets/images/logos/logo.png`
   - Download the ICO file
   - Replace `windows/runner/resources/app_icon.ico`

## Building the Application

After making these changes, rebuild the application:

```bash
# Clean previous builds
flutter clean

# Rebuild the Windows app
flutter build windows

# Run the app
flutter run -d windows
```

## Output

The built executable will be located at:
```
build/windows/x64/runner/Release/RomaSub.AI.exe
```

## Verification

To verify the changes:

1. **Check Window Title:** The application window should show "RomaSub.AI" in the title bar
2. **Check Executable:** The exe file should be named `RomaSub.AI.exe`
3. **Check Icon:** Right-click the exe → Properties → Details tab to see:
   - Product name: RomaSub.AI
   - File description: RomaSub.AI - Roman Urdu Captions Generator
   - Copyright: Copyright (C) 2025 COMSATS University Islamabad
4. **Check Icon:** The taskbar and window should display the custom icon

## Troubleshooting

### Icon not showing?
- Make sure `app_icon.ico` is in `windows/runner/resources/`
- Run `flutter clean` and rebuild
- Check that the ICO file contains multiple sizes (16x16, 32x32, 48x48, 256x256)

### Build errors?
- Delete the `build` folder
- Run `flutter clean`
- Run `flutter pub get`
- Rebuild with `flutter build windows`

### Wrong executable name?
- Check `windows/CMakeLists.txt` → `BINARY_NAME` should be "RomaSub.AI"
- Clean and rebuild

## Notes

- The icon should be 256x256 pixels or larger for best quality
- Windows ICO files can contain multiple resolutions
- Changes require a clean rebuild to take effect
- The logo.png used is at `assets/images/logos/logo.png`
