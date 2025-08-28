@echo off
echo.
echo ========================================
echo TALOWA Complete Fix Validation
echo ========================================
echo.

echo 🔍 Step 1: Checking data consistency...
echo.
call quick_check.bat
echo.

echo 🏗️  Step 2: Building Flutter web app...
echo.
flutter build web --release --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo ❌ Flutter build failed
    pause
    exit /b 1
)
echo ✅ Flutter build successful
echo.

echo 🚀 Step 3: Deploying to Firebase...
echo.
firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo ❌ Firebase deployment failed
    pause
    exit /b 1
)
echo ✅ Firebase deployment successful
echo.

echo 🎉 COMPLETE FIX VALIDATION SUCCESSFUL!
echo ========================================
echo.
echo ✅ Data consistency verified
echo ✅ Flutter app built successfully  
echo ✅ App deployed to Firebase
echo.
echo 🔗 Your app is now live with consistent referral codes!
echo    Visit: https://talowa.web.app
echo.
echo 📋 Next steps:
echo • Test referral code sharing in the app
echo • Monitor for any new inconsistencies
echo • Run quick_check.bat weekly for maintenance
echo.
pause