@echo off
setlocal enabledelayedexpansion

echo TALOWA Referral System - Simple Test
echo ====================================
echo.

REM Get project ID
set PROJECT_ID=talowa
echo Project ID: %PROJECT_ID%
echo.

echo Step 1: Deploy referral system
echo ==============================
echo.

REM Check if deploy script exists
if exist "deploy_referral_fixes.bat" (
    echo Running deploy_referral_fixes.bat...
    call deploy_referral_fixes.bat
    if !errorlevel! neq 0 (
        echo Deployment failed. Continuing with tests...
    ) else (
        echo Deployment completed successfully!
    )
) else (
    echo deploy_referral_fixes.bat not found. Skipping deployment.
)

echo.
echo Step 2: Test function accessibility
echo ==================================
echo.

REM Test reserveReferralCode
echo Testing reserveReferralCode...
curl -s -w "%%{http_code}" -o nul "https://us-central1-%PROJECT_ID%.cloudfunctions.net/reserveReferralCode" -H "Content-Type: application/json" -d "{}" 2>nul | findstr /C:"401" >nul
if !errorlevel! equ 0 (
    echo [OK] reserveReferralCode - DEPLOYED and requires auth
) else (
    echo [WARN] reserveReferralCode - Check deployment status
)

REM Test applyReferralCode
echo Testing applyReferralCode...
curl -s -w "%%{http_code}" -o nul "https://us-central1-%PROJECT_ID%.cloudfunctions.net/applyReferralCode" -H "Content-Type: application/json" -d "{}" 2>nul | findstr /C:"401" >nul
if !errorlevel! equ 0 (
    echo [OK] applyReferralCode - DEPLOYED and requires auth
) else (
    echo [WARN] applyReferralCode - Check deployment status
)

REM Test getMyReferralStats
echo Testing getMyReferralStats...
curl -s -w "%%{http_code}" -o nul "https://us-central1-%PROJECT_ID%.cloudfunctions.net/getMyReferralStats" -H "Content-Type: application/json" -d "{}" 2>nul | findstr /C:"401" >nul
if !errorlevel! equ 0 (
    echo [OK] getMyReferralStats - DEPLOYED and requires auth
) else (
    echo [WARN] getMyReferralStats - Check deployment status
)

echo.
echo Step 3: Get ID token for authenticated testing
echo =============================================
echo.

echo To test with authentication:
echo 1. Open get_test_token.html in your browser
echo 2. Login with your TALOWA account
echo 3. Copy the ID token
echo 4. Run: test_referral_functions.bat %PROJECT_ID% "YOUR_TOKEN"
echo.

REM Check if token generator exists
if exist "get_test_token.html" (
    echo Opening token generator...
    start get_test_token.html
    echo.
    echo Token generator opened in browser.
    echo After getting your token, you can run:
    echo   test_referral_functions.bat %PROJECT_ID% "YOUR_ID_TOKEN"
) else (
    echo get_test_token.html not found.
    echo You can get an ID token from your Flutter app console:
    echo   firebase.auth().currentUser.getIdToken().then(console.log)
)

echo.
echo Step 4: Summary
echo ==============
echo.
echo Your referral system functions are accessible at:
echo - https://us-central1-%PROJECT_ID%.cloudfunctions.net/reserveReferralCode
echo - https://us-central1-%PROJECT_ID%.cloudfunctions.net/applyReferralCode
echo - https://us-central1-%PROJECT_ID%.cloudfunctions.net/getMyReferralStats
echo.
echo Next steps:
echo 1. Get an ID token using the opened web page
echo 2. Run authenticated tests with your token
echo 3. Test in your Flutter app
echo 4. Monitor function logs: firebase functions:log
echo.
echo Test completed!
pause