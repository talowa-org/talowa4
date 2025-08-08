@echo off
echo Deploying TALOWA Firebase Configuration...
echo.

echo 1. Installing Firebase CLI (if not already installed)...
npm install -g firebase-tools

echo.
echo 2. Logging into Firebase...
firebase login

echo.
echo 3. Initializing Firebase project...
firebase init

echo.
echo 4. Deploying Firestore rules...
firebase deploy --only firestore:rules

echo.
echo 5. Deploying Firestore indexes...
firebase deploy --only firestore:indexes

echo.
echo Firebase deployment completed!
echo.
echo Next steps:
echo - Your Firestore rules are now deployed
echo - Composite indexes will be created automatically
echo - The app should run without index errors
echo.
pause