@echo off
echo 🚀 Deploying TALOWA Referral System Fixes...
echo.

echo 📦 Step 1: Installing Cloud Functions Dependencies...
cd functions
call npm install
if %errorlevel% neq 0 (
    echo ❌ Failed to install Cloud Functions dependencies
    cd ..
    pause
    exit /b 1
)
cd ..
echo ✅ Cloud Functions dependencies installed
echo.

echo ⚡ Step 2: Building Cloud Functions...
cd functions
call npm run build
if %errorlevel% neq 0 (
    echo ❌ Failed to build Cloud Functions
    cd ..
    pause
    exit /b 1
)
cd ..
echo ✅ Cloud Functions built successfully
echo.

echo 🔧 Step 3: Deploying Cloud Functions...
firebase deploy --only functions
if %errorlevel% neq 0 (
    echo ❌ Failed to deploy Cloud Functions
    pause
    exit /b 1
)
echo ✅ Cloud Functions deployed successfully
echo.

echo 📋 Step 4: Deploying Firestore Security Rules...
firebase deploy --only firestore:rules
if %errorlevel% neq 0 (
    echo ❌ Failed to deploy Firestore rules
    pause
    exit /b 1
)
echo ✅ Firestore rules deployed successfully
echo.

echo 📊 Step 5: Deploying Firestore Indexes...
firebase deploy --only firestore:indexes
if %errorlevel% neq 0 (
    echo ❌ Failed to deploy Firestore indexes
    pause
    exit /b 1
)
echo ✅ Firestore indexes deployed successfully
echo.

echo 🎯 Step 6: Building Flutter Web App...
flutter build web --release --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo ❌ Failed to build Flutter web app
    pause
    exit /b 1
)
echo ✅ Flutter web app built successfully
echo.

echo 🌐 Step 7: Deploying to Firebase Hosting...
firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo ❌ Failed to deploy to Firebase Hosting
    pause
    exit /b 1
)
echo ✅ Firebase Hosting deployed successfully
echo.

echo 🎉 All referral system fixes deployed successfully!
echo.
echo 📝 What was fixed:
echo   ✅ Cloud Functions for server-side referral processing
echo   ✅ Firestore rules allow owners to read their own codes
echo   ✅ Client-side referral code generation eliminated
echo   ✅ Atomic referral relationships with transaction safety
echo   ✅ Permission-denied errors resolved
echo   ✅ User registry creation failures fixed
echo   ✅ Self-referral blocking implemented
echo.
echo 🔗 Your app is live at: https://talowa.web.app
echo.
echo 🧪 Test the following scenarios:
echo   1. Register without referral code
echo   2. Register with valid referral code
echo   3. Try to use own referral code (should be blocked)
echo   4. Check console for eliminated error messages
echo.
pause