@echo off
REM Configure CORS for Firebase Storage
REM This script applies CORS configuration to allow video playback from web browsers

echo 🔧 Configuring Firebase Storage CORS...

REM Check if gsutil is installed
where gsutil >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ gsutil is not installed. Please install Google Cloud SDK first.
    echo Visit: https://cloud.google.com/sdk/docs/install
    pause
    exit /b 1
)

REM Get the Firebase project ID (assuming it's "talowa" based on the config)
set PROJECT_ID=talowa

echo 📋 Project ID: %PROJECT_ID%

REM Apply CORS configuration to Firebase Storage bucket
echo 🌐 Applying CORS configuration to gs://%PROJECT_ID%.appspot.com...

gsutil cors set cors.json gs://%PROJECT_ID%.appspot.com

if %ERRORLEVEL% EQU 0 (
    echo ✅ CORS configuration applied successfully!
    echo 🎬 Video playback should now work on web browsers.
) else (
    echo ❌ Failed to apply CORS configuration.
    echo Please make sure you're authenticated with Google Cloud:
    echo   gcloud auth login
    echo   gcloud config set project %PROJECT_ID%
)

echo.
echo 📝 To verify CORS configuration:
echo   gsutil cors get gs://%PROJECT_ID%.appspot.com

pause
