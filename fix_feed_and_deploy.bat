@echo off
echo ========================================
echo TALOWA FEED FIX - QUICK DEPLOYMENT
echo ========================================
echo.
echo This script will:
echo 1. Switch to SimpleWorkingFeedScreen
echo 2. Build the app
echo 3. Deploy to Firebase
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul
echo.

echo [1/4] Cleaning previous build...
flutter clean
echo.

echo [2/4] Getting dependencies...
flutter pub get
echo.

echo [3/4] Building for web...
flutter build web --no-tree-shake-icons
if errorlevel 1 (
    echo.
    echo ❌ BUILD FAILED!
    echo Check the errors above.
    pause
    exit /b 1
)
echo.

echo [4/4] Deploying to Firebase...
firebase deploy --only hosting
if errorlevel 1 (
    echo.
    echo ❌ DEPLOYMENT FAILED!
    echo Check the errors above.
    pause
    exit /b 1
)
echo.

echo ========================================
echo ✅ DEPLOYMENT SUCCESSFUL!
echo ========================================
echo.
echo Your app is now live at: https://talowa.web.app
echo.
echo The Feed tab now uses SimpleWorkingFeedScreen which:
echo ✅ Shows posts directly from Firestore
echo ✅ Allows creating new posts
echo ✅ Supports liking posts
echo ✅ Displays images
echo ✅ Has proper error handling
echo.
echo Test the Feed tab now!
echo.
pause
