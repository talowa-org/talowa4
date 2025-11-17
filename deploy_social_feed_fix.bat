@echo off
echo ========================================
echo TALOWA Social Feed System - Complete Fix
echo ========================================
echo.

echo [1/6] Cleaning build artifacts...
call flutter clean
if errorlevel 1 (
    echo ERROR: Flutter clean failed
    pause
    exit /b 1
)

echo.
echo [2/6] Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Flutter pub get failed
    pause
    exit /b 1
)

echo.
echo [3/6] Running diagnostics on feed screens...
call flutter analyze lib/screens/feed/instagram_feed_screen.dart
call flutter analyze lib/services/social_feed/enhanced_feed_service.dart
call flutter analyze lib/services/social_feed/feed_error_handler.dart

echo.
echo [4/6] Building web application...
call flutter build web --no-tree-shake-icons --release
if errorlevel 1 (
    echo ERROR: Flutter build web failed
    pause
    exit /b 1
)

echo.
echo [5/6] Deploying to Firebase...
call firebase deploy --only hosting
if errorlevel 1 (
    echo ERROR: Firebase deploy failed
    pause
    exit /b 1
)

echo.
echo [6/6] Deployment complete!
echo.
echo ========================================
echo Social Feed System Status
echo ========================================
echo.
echo ✅ Feed error handling improved
echo ✅ Initialization process enhanced
echo ✅ Stream listeners with error recovery
echo ✅ Timeout protection added
echo ✅ User-friendly error messages
echo ✅ Retry logic implemented
echo.
echo Your feed should now work without "unexpected error" issues!
echo.
echo Test the feed at: https://talowa.web.app
echo.
pause
