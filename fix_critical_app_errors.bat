@echo off
echo ========================================
echo TALOWA - Critical App Error Fix Script
echo ========================================
echo.

echo 🔧 Step 1: Clean build cache...
call flutter clean
if errorlevel 1 (
    echo ❌ Flutter clean failed
    exit /b 1
)

echo.
echo 🔧 Step 2: Get dependencies...
call flutter pub get
if errorlevel 1 (
    echo ❌ Flutter pub get failed
    exit /b 1
)

echo.
echo 🔧 Step 3: Analyze code for issues...
call flutter analyze > analysis_output.txt 2>&1
if errorlevel 1 (
    echo ⚠️ Analysis found issues - check analysis_output.txt
) else (
    echo ✅ Code analysis passed
)

echo.
echo 🔧 Step 4: Build web version with optimizations...
call flutter build web --no-tree-shake-icons --web-renderer canvaskit --dart-define=FLUTTER_WEB_USE_SKIA=true
if errorlevel 1 (
    echo ❌ Web build failed
    exit /b 1
)

echo.
echo 🔧 Step 5: Deploy to Firebase...
call firebase deploy --only hosting
if errorlevel 1 (
    echo ❌ Firebase deployment failed
    exit /b 1
)

echo.
echo ✅ CRITICAL ERROR FIX COMPLETE!
echo.
echo 🎯 Fixed Issues:
echo   - ✅ Fixed infinity.toInt() error in stats_card_widget.dart
echo   - ✅ Fixed platform memory info error for web
echo   - ✅ Improved error handling in performance services
echo   - ✅ Optimized build configuration
echo.
echo 🌐 App deployed to: https://talowa.web.app
echo.
echo 📊 Test the following:
echo   1. App loads without "Something went wrong" error
echo   2. Navigation works smoothly
echo   3. Referral dashboard displays correctly
echo   4. No console errors in browser
echo.
pause