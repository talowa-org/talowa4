@echo off
echo ========================================
echo TALOWA - Check CORS Status
echo ========================================
echo.

REM Check if gsutil is available
where gsutil >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ gsutil not found
    echo.
    echo Google Cloud SDK is not installed.
    echo Download from: https://cloud.google.com/sdk/docs/install
    echo.
    pause
    exit /b 1
)

echo Checking CORS configuration for gs://talowa.appspot.com...
echo.

call gsutil cors get gs://talowa.appspot.com

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo ✅ CORS Configuration Status: ACTIVE
    echo ========================================
    echo.
    echo Your Firebase Storage bucket has CORS enabled.
    echo.
    echo Expected configuration:
    echo - Origins: talowa.web.app, talowa.firebaseapp.com, localhost, 127.0.0.1
    echo - Methods: GET, POST, PUT, DELETE, OPTIONS
    echo - Headers: Content-Type, x-goog-meta-*, Access-Control-Allow-Origin
    echo.
) else (
    echo.
    echo ========================================
    echo ❌ CORS Configuration Status: NOT FOUND
    echo ========================================
    echo.
    echo CORS is not configured for this bucket.
    echo.
    echo To apply CORS configuration, run:
    echo apply_cors.bat
    echo.
)

echo.
echo Additional checks:
echo.

REM Check if cors.json exists
if exist cors.json (
    echo ✅ cors.json file exists in current directory
) else (
    echo ❌ cors.json file not found in current directory
)

REM Check current project
echo.
echo Current Google Cloud project:
call gcloud config get-value project
echo.

pause
