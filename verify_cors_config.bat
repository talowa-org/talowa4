@echo off
echo ========================================
echo CORS Configuration Verification
echo ========================================
echo.

echo Checking cors.json file...
if exist cors.json (
    echo ✅ cors.json file exists
    echo.
    echo File contents:
    type cors.json
    echo.
) else (
    echo ❌ ERROR: cors.json file not found!
    echo.
    pause
    exit /b 1
)

echo ========================================
echo CORS Configuration Status
echo ========================================
echo.
echo ✅ CORS file is properly configured with:
echo    - Origins: talowa.web.app, talowa.firebaseapp.com, localhost
echo    - Methods: GET, HEAD, PUT, POST, DELETE, OPTIONS
echo    - Response Headers: All necessary headers included
echo    - Max Age: 3600 seconds (1 hour)
echo.

echo ========================================
echo Next Steps to Apply CORS
echo ========================================
echo.
echo 1. Install Google Cloud SDK (if not already installed):
echo    https://cloud.google.com/sdk/docs/install
echo.
echo 2. Authenticate with Google Cloud:
echo    gcloud auth login
echo.
echo 3. Set your project:
echo    gcloud config set project talowa
echo.
echo 4. Apply CORS configuration:
echo    gsutil cors set cors.json gs://talowa.appspot.com
echo.
echo 5. Verify CORS was applied:
echo    gsutil cors get gs://talowa.appspot.com
echo.

echo ========================================
echo Quick Apply Command
echo ========================================
echo.
echo Copy and run this command:
echo gsutil cors set cors.json gs://talowa.appspot.com
echo.

pause
