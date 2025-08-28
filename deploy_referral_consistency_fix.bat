@echo off
echo 🚀 TALOWA Referral Code Consistency Fix Deployment
echo ================================================

echo.
echo 📋 Step 1: Deploy updated Cloud Functions...
cd functions
call npm run deploy
if %ERRORLEVEL% neq 0 (
    echo ❌ Cloud Functions deployment failed!
    pause
    exit /b 1
)
cd ..

echo.
echo 📋 Step 2: Build and deploy Flutter web app...
call flutter build web --release --no-tree-shake-icons
if %ERRORLEVEL% neq 0 (
    echo ❌ Flutter build failed!
    pause
    exit /b 1
)

call firebase deploy --only hosting
if %ERRORLEVEL% neq 0 (
    echo ❌ Hosting deployment failed!
    pause
    exit /b 1
)

echo.
echo 📋 Step 3: Run referral code consistency fix...
node fix_referral_consistency.js
if %ERRORLEVEL% neq 0 (
    echo ❌ Consistency fix failed!
    pause
    exit /b 1
)

echo.
echo ✅ ALL FIXES DEPLOYED SUCCESSFULLY!
echo.
echo 🔍 What was fixed:
echo   • Unified referral code generation to use only Cloud Functions
echo   • Fixed function names (ensureReferralCode, processReferral)
echo   • Added consistency checks and automatic fixes
echo   • Updated both users and user_registry collections
echo.
echo 🧪 Next steps:
echo   1. Test registration at https://talowa.web.app
echo   2. Check Firebase Console for consistent referral codes
echo   3. Verify no more mismatches between collections
echo.
pause