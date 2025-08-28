@echo off
echo.
echo ========================================
echo TALOWA Quick Consistency Check
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

echo 🔍 Running quick consistency check...
echo.

REM Run the check script
node quick_consistency_check.js

echo.
echo 💡 This was a read-only check. No data was modified.
echo    To fix any inconsistencies found, run: fix_referral_consistency.bat
echo.
pause