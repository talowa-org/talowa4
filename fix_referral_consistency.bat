@echo off
echo.
echo ========================================
echo TALOWA Referral Code Consistency Fix
echo ========================================
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Check if service account key exists
if not exist "serviceAccountKey.json" (
    echo ❌ Service account key not found
    echo.
    echo Please download your Firebase service account key:
    echo 1. Go to Firebase Console ^> Project Settings ^> Service Accounts
    echo 2. Click "Generate new private key"
    echo 3. Save as "serviceAccountKey.json" in this directory
    echo.
    pause
    exit /b 1
)

echo ✅ Prerequisites check passed
echo.

REM Install dependencies if needed
if not exist "node_modules" (
    echo 📦 Installing dependencies...
    npm install firebase-admin
    echo.
)

echo 🚀 Running referral code consistency fix...
echo.

REM Run the fix script
node fix_referral_data_consistency.js

if %errorlevel% equ 0 (
    echo.
    echo ✅ Consistency fix completed successfully!
    echo.
    echo 📋 What was fixed:
    echo • Synchronized referral codes between users and user_registry collections
    echo • Used users collection as source of truth
    echo • Reserved all codes in referralCodes collection
    echo • Generated new codes where both existing codes were invalid
    echo.
    echo 🔧 Next steps:
    echo 1. Test the app to ensure referral system works correctly
    echo 2. Deploy updated registration flow to prevent future issues
    echo 3. Monitor for any new inconsistencies
) else (
    echo.
    echo ❌ Consistency fix encountered errors
    echo Please review the output above and try again
)

echo.
pause