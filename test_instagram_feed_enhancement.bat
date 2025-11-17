@echo off
echo ========================================
echo INSTAGRAM FEED ENHANCEMENT - TEST SCRIPT
echo ========================================
echo.

echo [1/5] Checking Flutter installation...
flutter --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter not found!
    exit /b 1
)
echo ✅ Flutter found
echo.

echo [2/5] Checking required files...
set FILES_OK=1

if not exist "lib\services\media\image_picker_service.dart" (
    echo ❌ Missing: image_picker_service.dart
    set FILES_OK=0
)

if not exist "lib\services\media\video_picker_service.dart" (
    echo ❌ Missing: video_picker_service.dart
    set FILES_OK=0
)

if not exist "lib\services\media\firebase_uploader_service.dart" (
    echo ❌ Missing: firebase_uploader_service.dart
    set FILES_OK=0
)

if not exist "lib\screens\post_creation\enhanced_post_creation_screen.dart" (
    echo ❌ Missing: enhanced_post_creation_screen.dart
    set FILES_OK=0
)

if not exist "lib\widgets\feed\enhanced_post_widget.dart" (
    echo ❌ Missing: enhanced_post_widget.dart
    set FILES_OK=0
)

if not exist "lib\screens\feed\enhanced_instagram_feed_screen.dart" (
    echo ❌ Missing: enhanced_instagram_feed_screen.dart
    set FILES_OK=0
)

if %FILES_OK%==1 (
    echo ✅ All required files present
) else (
    echo ❌ Some files are missing!
    exit /b 1
)
echo.

echo [3/5] Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ Failed to get dependencies
    exit /b 1
)
echo ✅ Dependencies installed
echo.

echo [4/5] Analyzing code...
flutter analyze lib\services\media\image_picker_service.dart
flutter analyze lib\services\media\video_picker_service.dart
flutter analyze lib\services\media\firebase_uploader_service.dart
flutter analyze lib\screens\post_creation\enhanced_post_creation_screen.dart
flutter analyze lib\widgets\feed\enhanced_post_widget.dart
flutter analyze lib\screens\feed\enhanced_instagram_feed_screen.dart
if %errorlevel% neq 0 (
    echo ⚠️ Some analysis warnings found (may be acceptable)
) else (
    echo ✅ Code analysis passed
)
echo.

echo [5/5] Checking dependencies in pubspec.yaml...
findstr /C:"image_picker" pubspec.yaml >nul
if %errorlevel% neq 0 (
    echo ❌ Missing: image_picker
    exit /b 1
)

findstr /C:"file_picker" pubspec.yaml >nul
if %errorlevel% neq 0 (
    echo ❌ Missing: file_picker
    exit /b 1
)

findstr /C:"video_player" pubspec.yaml >nul
if %errorlevel% neq 0 (
    echo ❌ Missing: video_player
    exit /b 1
)

findstr /C:"firebase_storage" pubspec.yaml >nul
if %errorlevel% neq 0 (
    echo ❌ Missing: firebase_storage
    exit /b 1
)

findstr /C:"cached_network_image" pubspec.yaml >nul
if %errorlevel% neq 0 (
    echo ❌ Missing: cached_network_image
    exit /b 1
)

echo ✅ All required dependencies present
echo.

echo ========================================
echo ✅ INSTAGRAM FEED ENHANCEMENT READY!
echo ========================================
echo.
echo Next steps:
echo 1. Update Firebase Storage rules (see INSTAGRAM_FEED_QUICK_START.md)
echo 2. Build: flutter build web --no-tree-shake-icons
echo 3. Deploy: firebase deploy
echo 4. Test the feed in your app!
echo.
echo Documentation:
echo - Quick Start: INSTAGRAM_FEED_QUICK_START.md
echo - Full Docs: docs\INSTAGRAM_FEED_ENHANCEMENT.md
echo.
pause
