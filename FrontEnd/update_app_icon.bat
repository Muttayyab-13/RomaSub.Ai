@echo off
echo ========================================
echo RomaSub.AI - Update Application Icon
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH
    echo Please install Python from https://www.python.org/
    pause
    exit /b 1
)

REM Check if Pillow is installed
python -c "import PIL" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Pillow library not found. Installing...
    pip install pillow
    if errorlevel 1 (
        echo [ERROR] Failed to install Pillow
        pause
        exit /b 1
    )
)

REM Run the conversion script
echo [INFO] Converting logo.png to app_icon.ico...
python convert_logo_to_ico.py

if errorlevel 1 (
    echo.
    echo [ERROR] Icon conversion failed!
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Icon conversion completed!
echo.
echo Next steps:
echo 1. Clean build: flutter clean
echo 2. Rebuild app: flutter build windows
echo.
pause
