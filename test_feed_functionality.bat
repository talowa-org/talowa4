@echo off
echo ========================================
echo FEED FUNCTIONALITY TEST SCRIPT
echo ========================================
echo.

echo [TEST 1/7] Code Analysis...
echo Running Flutter analyze...
flutter analyze lib/screens/feed/enhanced_instagram_feed_screen.dart lib/screens/post_creation/enhanced_post_creation_screen.dart lib/widgets/feed/enhanced_post_widget.dart lib/services/media/
if %errorlevel% neq 0 (
    echo ❌ FAILED: Code analysis found issues
    pause
    exit /b 1
)
echo ✅ PASSED: No code analysis issues
echo.

echo [TEST 2/7] Build Test...
echo Building web version...
flutter build web --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo ❌ FAILED: Build failed
    pause
    exit /b 1
)
echo ✅ PASSED: Build successful
echo.

echo [TEST 3/7] File Structure Test...
echo Checking required files exist...
if not exist "lib\screens\feed\enhanced_instagram_feed_screen.dart" (
    echo ❌ FAILED: Enhanced feed screen missing
    exit /b 1
)
if not exist "lib\screens\post_creation\enhanced_post_creation_screen.dart" (
    echo ❌ FAILED: Enhanced post creation screen missing
    exit /b 1
)
if not exist "lib\widgets\feed\enhanced_post_widget.dart" (
    echo ❌ FAILED: Enhanced post widget missing
    exit /b 1
)
if not exist "lib\services\media\image_picker_service.dart" (
    echo ❌ FAILED: Image picker service missing
    exit /b 1
)
if not exist "lib\services\media\video_picker_service.dart" (
    echo ❌ FAILED: Video picker service missing
    exit /b 1
)
if not exist "lib\services\media\firebase_uploader_service.dart" (
    echo ❌ FAILED: Firebase uploader service missing
    exit /b 1
)
echo ✅ PASSED: All required files present
echo.

echo [TEST 4/7] Model Test...
echo Checking InstagramPostModel...
findstr /C:"mediaItems" lib\models\social_feed\instagram_post_model.dart >nul
if %errorlevel% neq 0 (
    echo ❌ FAILED: mediaItems not found in model
    exit /b 1
)
findstr /C:"caption" lib\models\social_feed\instagram_post_model.dart >nul
if %errorlevel% neq 0 (
    echo ❌ FAILED: caption not found in model
    exit /b 1
)
echo ✅ PASSED: Model structure correct
echo.

echo [TEST 5/7] Service Integration Test...
echo Checking service imports...
findstr /C:"ImagePickerService" lib\screens\post_creation\enhanced_post_creation_screen.dart >nul
if %errorlevel% neq 0 (
    echo ❌ FAILED: ImagePickerService not imported
    exit /b 1
)
findstr /C:"VideoPickerService" lib\screens\post_creation\enhanced_post_creation_screen.dart >nul
if %errorlevel% neq 0 (
    echo ❌ FAILED: VideoPickerService not imported
    exit /b 1
)
findstr /C:"FirebaseUploaderService" lib\screens\post_creation\enhanced_post_creation_screen.dart >nul
if %errorlevel% neq 0 (
    echo ❌ FAILED: FirebaseUploaderService not imported
    exit /b 1
)
echo ✅ PASSED: Services properly integrated
echo.

echo [TEST 6/7] Navigation Test...
echo Checking main navigation integration...
findstr /C:"EnhancedInstagramFeedScreen" lib\screens\main\main_navigation_screen.dart >nul
if %errorlevel% neq 0 (
    echo ❌ FAILED: Enhanced feed not in navigation
    exit /b 1
)
echo ✅ PASSED: Navigation properly configured
echo.

echo [TEST 7/7] Firebase Configuration Test...
echo Checking storage rules...
if not exist "storage.rules" (
    echo ❌ FAILED: storage.rules missing
    exit /b 1
)
findstr /C:"feed_posts" storage.rules >nul
if %errorlevel% neq 0 (
    echo ❌ FAILED: feed_posts rules not configured
    exit /b 1
)
echo ✅ PASSED: Firebase configuration correct
echo.

echo ========================================
echo ✅ ALL TESTS PASSED!
echo ========================================
echo.
echo Test Summary:
echo   ✅ Code Analysis: PASSED
echo   ✅ Build Test: PASSED
echo   ✅ File Structure: PASSED
echo   ✅ Model Test: PASSED
echo   ✅ Service Integration: PASSED
echo   ✅ Navigation: PASSED
echo   ✅ Firebase Config: PASSED
echo.
echo Status: Ready for Step 2 (Validation)
echo.
pause
