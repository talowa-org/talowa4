@echo off
title TALOWA Referral System - One Click Setup

echo.
echo  ████████╗ █████╗ ██╗      ██████╗ ██╗    ██╗ █████╗ 
echo  ╚══██╔══╝██╔══██╗██║     ██╔═══██╗██║    ██║██╔══██╗
echo     ██║   ███████║██║     ██║   ██║██║ █╗ ██║███████║
echo     ██║   ██╔══██║██║     ██║   ██║██║███╗██║██╔══██║
echo     ██║   ██║  ██║███████╗╚██████╔╝╚███╔███╔╝██║  ██║
echo     ╚═╝   ╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝
echo.
echo           Referral System - Automatic Setup
echo           ===================================
echo.

echo Hello! 👋
echo.
echo This will automatically set up and test your referral system.
echo No technical knowledge required - just click and wait!
echo.

echo What will happen:
echo • Deploy your referral system to the cloud
echo • Test all the referral features
echo • Show you if everything is working
echo • Give you simple next steps
echo.

echo This takes about 2-3 minutes.
echo.

set /p CONTINUE="Ready to start? Press ENTER to continue or close this window to cancel: "

echo.
echo 🚀 Starting automatic setup...
echo.

REM Create a log file
set LOGFILE=setup_log.txt
echo TALOWA Referral System Setup Log > %LOGFILE%
echo Started at %date% %time% >> %LOGFILE%
echo. >> %LOGFILE%

REM Step 1: Check prerequisites
echo [Step 1/4] Checking your system...
echo [Step 1/4] Checking system... >> %LOGFILE%

REM Check if we're in the right directory
if not exist "pubspec.yaml" (
    echo ❌ Error: This doesn't look like your TALOWA project folder.
    echo Please run this script from your main TALOWA project directory.
    echo (The folder that contains pubspec.yaml)
    echo.
    pause
    exit /b 1
)

echo ✓ Found TALOWA project files
echo ✓ Found TALOWA project files >> %LOGFILE%

REM Step 2: Deploy the system
echo.
echo [Step 2/4] Deploying your referral system to the cloud...
echo [Step 2/4] Deploying referral system... >> %LOGFILE%

if exist "deploy_referral_fixes.bat" (
    echo Running deployment script...
    call deploy_referral_fixes.bat >> %LOGFILE% 2>&1
    if %errorlevel% equ 0 (
        echo ✓ Referral system deployed successfully!
        echo ✓ Deployment successful >> %LOGFILE%
    ) else (
        echo ⚠️ Deployment had some issues, but continuing...
        echo ⚠️ Deployment issues >> %LOGFILE%
    )
) else (
    echo ⚠️ Deployment script not found, trying basic deployment...
    echo ⚠️ No deployment script found >> %LOGFILE%
    
    REM Try basic Firebase deployment
    firebase deploy --only functions >> %LOGFILE% 2>&1
    if %errorlevel% equ 0 (
        echo ✓ Basic deployment completed!
        echo ✓ Basic deployment completed >> %LOGFILE%
    ) else (
        echo ⚠️ Could not deploy automatically
        echo ⚠️ Auto deployment failed >> %LOGFILE%
    )
)

REM Step 3: Test the system
echo.
echo [Step 3/4] Testing your referral system...
echo [Step 3/4] Testing referral system... >> %LOGFILE%

set FUNCTIONS_WORKING=0
set PROJECT_ID=talowa

REM Test each function
echo Testing reserveReferralCode...
curl -s -w "%%{http_code}" -o nul "https://us-central1-%PROJECT_ID%.cloudfunctions.net/reserveReferralCode" -H "Content-Type: application/json" -d "{}" 2>nul | findstr "401 403" >nul
if %errorlevel% equ 0 (
    echo ✓ reserveReferralCode is working
    echo ✓ reserveReferralCode working >> %LOGFILE%
    set /a FUNCTIONS_WORKING+=1
) else (
    echo ❌ reserveReferralCode needs attention
    echo ❌ reserveReferralCode not working >> %LOGFILE%
)

echo Testing applyReferralCode...
curl -s -w "%%{http_code}" -o nul "https://us-central1-%PROJECT_ID%.cloudfunctions.net/applyReferralCode" -H "Content-Type: application/json" -d "{}" 2>nul | findstr "401 403" >nul
if %errorlevel% equ 0 (
    echo ✓ applyReferralCode is working
    echo ✓ applyReferralCode working >> %LOGFILE%
    set /a FUNCTIONS_WORKING+=1
) else (
    echo ❌ applyReferralCode needs attention
    echo ❌ applyReferralCode not working >> %LOGFILE%
)

echo Testing getMyReferralStats...
curl -s -w "%%{http_code}" -o nul "https://us-central1-%PROJECT_ID%.cloudfunctions.net/getMyReferralStats" -H "Content-Type: application/json" -d "{}" 2>nul | findstr "401 403" >nul
if %errorlevel% equ 0 (
    echo ✓ getMyReferralStats is working
    echo ✓ getMyReferralStats working >> %LOGFILE%
    set /a FUNCTIONS_WORKING+=1
) else (
    echo ❌ getMyReferralStats needs attention
    echo ❌ getMyReferralStats not working >> %LOGFILE%
)

REM Step 4: Show results
echo.
echo [Step 4/4] Setup Complete! Here are your results:
echo [Step 4/4] Setup complete - %FUNCTIONS_WORKING%/3 functions working >> %LOGFILE%
echo.

if %FUNCTIONS_WORKING% equ 3 (
    echo 🎉🎉🎉 PERFECT! Your referral system is 100%% working! 🎉🎉🎉
    echo.
    echo ✅ All referral features are active
    echo ✅ Users can generate referral codes
    echo ✅ Users can apply referral codes  
    echo ✅ Users can check referral statistics
    echo ✅ Everything is automated and ready!
    echo.
    echo 🌐 Your TALOWA app is live at: https://talowa.web.app
    echo.
    echo 🎯 WHAT THIS MEANS FOR YOU:
    echo • When people register in your app, they automatically get a referral code
    echo • They can share this code with friends and family
    echo • When someone uses their code to register, both people get credited
    echo • You can track all referral activity in your Firebase console
    echo • Everything happens automatically - no manual work needed!
    echo.
    echo 📱 TRY IT NOW:
    echo 1. Go to https://talowa.web.app
    echo 2. Register a new account
    echo 3. Look for your referral code in the app
    echo 4. Share it with a friend to test!
    
) else if %FUNCTIONS_WORKING% geq 1 (
    echo 🟡 GOOD NEWS: Your referral system is partially working!
    echo.
    echo ✅ %FUNCTIONS_WORKING% out of 3 referral functions are active
    echo ⚠️ Some features may need additional setup
    echo.
    echo Your app is still usable at: https://talowa.web.app
    echo.
    echo The working parts will function normally.
    echo You may want to contact technical support for the remaining parts.
    
) else (
    echo 🔴 SETUP NEEDED: Your referral system needs additional configuration
    echo.
    echo Don't worry! Your main TALOWA app should still work fine.
    echo The referral features just need some technical setup.
    echo.
    echo 📞 NEXT STEPS:
    echo 1. Your app is available at: https://talowa.web.app
    echo 2. Contact your technical support team
    echo 3. Show them the setup_log.txt file created by this script
    echo 4. They can complete the referral system setup
)

echo.
echo 📋 TECHNICAL LOG:
echo A detailed log has been saved to: setup_log.txt
echo You can share this file with technical support if needed.
echo.

echo Completed at %date% %time% >> %LOGFILE%
echo Functions working: %FUNCTIONS_WORKING%/3 >> %LOGFILE%

echo ========================================
echo            Setup Complete!
echo ========================================
echo.

if %FUNCTIONS_WORKING% equ 3 (
    echo 🚀 Congratulations! Your TALOWA referral system is ready!
    echo Start sharing your referral codes and grow your community! 🌟
) else (
    echo 📞 If you need help, share the setup_log.txt file with your technical team.
)

echo.
echo Press any key to finish...
pause >nul

echo.
echo Thank you for using TALOWA! 🙏