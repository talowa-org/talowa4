@echo off
REM TALOWA App Deployment Script for Windows
REM This script builds and deploys the TALOWA Flutter app to Firebase

echo 🚀 TALOWA App Deployment Script
echo ================================

REM Check if we're in the right directory
if not exist "pubspec.yaml" (
    echo ❌ Error: pubspec.yaml not found. Please run this script from the project root.
    exit /b 1
)

REM Check if Firebase CLI is installed
firebase --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Firebase CLI not found. Please install it first:
    echo    npm install -g firebase-tools
    exit /b 1
)

REM Check if user is logged in to Firebase
firebase projects:list >nul 2>&1
if errorlevel 1 (
    echo ❌ Not logged in to Firebase. Please login first:
    echo    firebase login
    exit /b 1
)

echo ✅ Prerequisites check passed

REM Step 1: Clean and build Flutter web app
echo.
echo 📱 Step 1: Building Flutter web app...
call flutter clean
call flutter pub get
call flutter build web --release --no-tree-shake-icons

if errorlevel 1 (
    echo ❌ Flutter build failed
    exit /b 1
)

echo ✅ Flutter web build completed

REM Step 2: Build Cloud Functions (if Node.js is available)
echo.
echo ⚡ Step 2: Building Cloud Functions...

npm --version >nul 2>&1
if errorlevel 1 (
    echo ⚠️  Node.js not found. Using pre-compiled functions.
    if not exist "functions\lib" (
        echo ❌ No compiled functions found. Please install Node.js and run:
        echo    cd functions ^&^& npm install ^&^& npm run build
        exit /b 1
    )
    echo ✅ Using existing compiled functions
) else (
    cd functions
    call npm install
    call npm run build
    cd ..
    echo ✅ Cloud Functions build completed
)

REM Step 3: Deploy to Firebase
echo.
echo 🚀 Step 3: Deploying to Firebase...

REM Deploy everything
call firebase deploy

if errorlevel 1 (
    echo ❌ Deployment failed
    exit /b 1
) else (
    echo.
    echo 🎉 Deployment successful!
    echo.
    echo 📱 Your app is now live at:
    echo    https://talowa.web.app
    echo.
    echo 🔧 Firebase Console:
    echo    https://console.firebase.google.com/project/talowa
    echo.
    echo ✅ Deployment completed successfully!
)