@echo off
echo ========================================
echo TALOWA - Apply CORS Configuration
echo ========================================
echo.

echo Checking prerequisites...
echo.

REM Check if gsutil is available
where gsutil >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ ERROR: gsutil command not found!
    echo.
    echo Google Cloud SDK is not installed or not in PATH.
    echo.
    echo Please install Google Cloud SDK from:
    echo https://cloud.google.com/sdk/docs/install
    echo.
    echo After installation:
    echo 1. Restart your terminal
    echo 2. Run: gcloud init
    echo 3. Run this script again
    echo.
    pause
    exit /b 1
)

echo ✅ gsutil found
echo.

REM Check if cors.json exists
if not exist cors.json (
    echo ❌ ERROR: cors.json file not found!
    echo.
    echo Please ensure cors.json is in the current directory.
    echo.
    pause
    exit /b 1
)

echo ✅ cors.json found
echo.

echo Current CORS configuration:
echo ----------------------------------------
type cors.json
echo ----------------------------------------
echo.

echo Step 1: Authenticating with Google Cloud...
echo.
echo If browser opens, please sign in with your Google account.
echo.
call gcloud auth login
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Authentication failed!
    pause
    exit /b 1
)
echo ✅ Authentication successful
echo.

echo Step 2: Setting project to 'talowa'...
echo.
call gcloud config set project talowa
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to set project!
    pause
    exit /b 1
)
echo ✅ Project set to 'talowa'
echo.

echo Step 3: Applying CORS configuration to Firebase Storage...
echo.
echo Target bucket: gs://talowa.appspot.com
echo.
call gsutil cors set cors.json gs://talowa.appspot.com
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to apply CORS configuration!
    echo.
    echo Common issues:
    echo - Insufficient permissions (need Storage Admin role)
    echo - Wrong bucket name
    echo - Network connectivity issues
    echo.
    pause
    exit /b 1
)
echo ✅ CORS configuration applied successfully!
echo.

echo Step 4: Verifying CORS configuration...
echo.
call gsutil cors get gs://talowa.appspot.com
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️ Warning: Could not verify CORS configuration
    echo.
) else (
    echo.
    echo ✅ CORS configuration verified!
)
echo.

echo ========================================
echo ✅ CORS SETUP COMPLETE!
echo ========================================
echo.
echo Your Firebase Storage bucket now has CORS enabled.
echo.
echo What this means:
echo ✅ Images will load in your web app
echo ✅ Videos will play correctly
echo ✅ File uploads will work
echo ✅ No more CORS errors in browser console
echo.
echo Next steps:
echo 1. Deploy your app: firebase deploy --only hosting
echo 2. Test image upload in Feed tab
echo 3. Verify images load correctly
echo.
echo If you see CORS errors:
echo - Clear browser cache (Ctrl+Shift+Delete)
echo - Try incognito/private browsing mode
echo - Wait 5-10 minutes for CDN cache to clear
echo.
pause
