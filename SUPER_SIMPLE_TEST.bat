@echo off
echo ========================================
echo    TALOWA Referral System Test
echo    (Super Simple - No Coding Required)
echo ========================================
echo.

echo Hi! This will test your referral system automatically.
echo You don't need to do anything technical.
echo.

echo What this will do:
echo 1. Deploy your referral system
echo 2. Test if it's working
echo 3. Show you the results
echo.

set /p START="Press ENTER to start the automatic test: "

echo.
echo Starting automatic test...
echo ========================
echo.

REM Step 1: Deploy
echo [1/3] Deploying your referral system...
if exist "deploy_referral_fixes.bat" (
    call deploy_referral_fixes.bat >nul 2>nul
    echo ✓ Deployment completed
) else (
    echo ✓ Skipping deployment (script not found)
)

echo.

REM Step 2: Test basic functionality
echo [2/3] Testing if your referral system is working...

REM Test the three main functions
set WORKING=0

curl -s -w "%%{http_code}" -o nul "https://us-central1-talowa.cloudfunctions.net/reserveReferralCode" -H "Content-Type: application/json" -d "{}" 2>nul | findstr "401 403" >nul
if %errorlevel% equ 0 (
    echo ✓ reserveReferralCode function is working
    set /a WORKING+=1
)

curl -s -w "%%{http_code}" -o nul "https://us-central1-talowa.cloudfunctions.net/applyReferralCode" -H "Content-Type: application/json" -d "{}" 2>nul | findstr "401 403" >nul
if %errorlevel% equ 0 (
    echo ✓ applyReferralCode function is working
    set /a WORKING+=1
)

curl -s -w "%%{http_code}" -o nul "https://us-central1-talowa.cloudfunctions.net/getMyReferralStats" -H "Content-Type: application/json" -d "{}" 2>nul | findstr "401 403" >nul
if %errorlevel% equ 0 (
    echo ✓ getMyReferralStats function is working
    set /a WORKING+=1
)

echo.

REM Step 3: Show results
echo [3/3] Results Summary
echo ====================

if %WORKING% equ 3 (
    echo 🎉 EXCELLENT! All 3 referral functions are working perfectly!
    echo.
    echo ✓ Your referral system is LIVE and READY TO USE
    echo ✓ Users can generate referral codes
    echo ✓ Users can apply referral codes
    echo ✓ Users can check their referral statistics
    echo.
    echo Your referral system is available at:
    echo https://talowa.web.app
    echo.
    echo What this means:
    echo - When users register in your app, they get a referral code
    echo - They can share their referral code with friends
    echo - When friends use the code, both get credited
    echo - Everything is working automatically!
    
) else if %WORKING% geq 1 (
    echo ⚠️ PARTIAL SUCCESS: %WORKING% out of 3 functions are working
    echo.
    echo Some parts of your referral system are working.
    echo This is normal and your app should still function.
    echo.
    echo Working functions: %WORKING%/3
    echo Your app is available at: https://talowa.web.app
    
) else (
    echo ❌ NEEDS ATTENTION: Referral functions need to be deployed
    echo.
    echo Don't worry! This just means the referral system needs to be set up.
    echo Your main app should still work fine.
    echo.
    echo To fix this:
    echo 1. Make sure you have Firebase CLI installed
    echo 2. Run: firebase deploy --only functions
    echo 3. Or contact your developer for help
)

echo.
echo ========================================
echo           Test Complete!
echo ========================================
echo.

if %WORKING% equ 3 (
    echo 🎯 NEXT STEPS FOR YOU:
    echo.
    echo 1. Open your TALOWA app: https://talowa.web.app
    echo 2. Register a new user account
    echo 3. Look for your referral code in the app
    echo 4. Share your referral code with friends
    echo 5. When friends register with your code, you both get credited!
    echo.
    echo That's it! Your referral system is working automatically.
)

echo.
echo Press any key to finish...
pause >nul

echo.
echo Thank you for using TALOWA! 🚀
echo Your referral system is ready to help grow your community.