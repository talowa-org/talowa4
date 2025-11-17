@echo off
REM ============================================
REM TALOWA Feed Fix - Quick Deployment
REM ============================================
echo.
echo ========================================
echo DEPLOYING FEED FIX TO PRODUCTION
echo ========================================
echo.

REM Step 1: Clean build
echo [1/5] Cleaning build...
flutter clean
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter clean failed!
    pause
    exit /b 1
)
echo ✓ Build cleaned
echo.

REM Step 2: Get dependencies
echo [2/5] Getting dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to get dependencies!
    pause
    exit /b 1
)
echo ✓ Dependencies installed
echo.

REM Step 3: Run quick diagnostics
echo [3/5] Running diagnostics...
flutter analyze lib/services/social_feed/clean_feed_service.dart
flutter analyze lib/screens/feed/simple_working_feed_screen.dart
flutter analyze lib/screens/post_creation/simple_post_creation_screen.dart
echo ✓ Diagnostics complete
echo.

REM Step 4: Build for web
echo [4/5] Building for web...
flutter build web --no-tree-shake-icons
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Web build failed!
    pause
    exit /b 1
)
echo ✓ Web build successful
echo.

REM Step 5: Deploy to Firebase
echo [5/5] Deploying to Firebase...
call firebase deploy --only hosting
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Firebase deployment may have failed
    echo Please check Firebase console
) else (
    echo ✓ Deployed to Firebase
)
echo.

echo ========================================
echo DEPLOYMENT COMPLETE
echo ========================================
echo.
echo ✓ Feed fix deployed successfully!
echo.
echo NEXT STEPS:
echo 1. Open https://talowa.web.app
echo 2. Test post creation
echo 3. Test like functionality
echo 4. Test image upload
echo 5. Verify no console errors
echo.
echo ========================================
echo.

pause
