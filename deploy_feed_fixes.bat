@echo off
echo ========================================
echo TALOWA Feed System - Deployment Script
echo ========================================
echo.

echo Step 1: Deploying Firestore Rules...
call firebase deploy --only firestore:rules
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Firestore rules deployment failed!
    pause
    exit /b 1
)
echo ✅ Firestore rules deployed successfully
echo.

echo Step 2: Deploying Firestore Indexes...
call firebase deploy --only firestore:indexes
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Firestore indexes deployment failed!
    pause
    exit /b 1
)
echo ✅ Firestore indexes deployed successfully
echo.

echo Step 3: Deploying Storage Rules...
call firebase deploy --only storage
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Storage rules deployment failed!
    pause
    exit /b 1
)
echo ✅ Storage rules deployed successfully
echo.

echo Step 4: Applying CORS Configuration...
echo.
echo IMPORTANT: You need Google Cloud SDK installed for this step.
echo If you don't have it, download from: https://cloud.google.com/sdk/docs/install
echo.
echo Run this command manually:
echo gsutil cors set cors.json gs://talowa.appspot.com
echo.
pause

echo Step 5: Building Flutter Web App...
call flutter clean
call flutter pub get
call flutter build web --no-tree-shake-icons
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)
echo ✅ Flutter web app built successfully
echo.

echo Step 6: Deploying to Firebase Hosting...
call firebase deploy --only hosting
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Hosting deployment failed!
    pause
    exit /b 1
)
echo ✅ App deployed to Firebase Hosting successfully
echo.

echo ========================================
echo ✅ DEPLOYMENT COMPLETE!
echo ========================================
echo.
echo Your app is now live at: https://talowa.web.app
echo.
echo NEXT STEPS:
echo 1. Apply CORS configuration (see Step 4 above)
echo 2. Test post creation with images
echo 3. Test feed display
echo 4. Test likes, comments, and shares
echo.
pause
