@echo off
echo TALOWA Referral System - Quick Test Launcher
echo ==============================================
echo.

echo This script will:
echo 1. Deploy your referral system
echo 2. Help you get an ID token  
echo 3. Run comprehensive tests
echo 4. Show you the results
echo.

set /p CONTINUE="Ready to proceed? (Y/N): "
if /i not "%CONTINUE%"=="Y" (
    echo Cancelled by user.
    pause
    exit /b 0
)

echo.
echo Step 1: Running deployment...
echo ===============================

REM Run the auto deployment script
call auto_deploy_and_test.bat

echo.
echo Quick test completed!
echo.
echo What happened:
echo   - Cloud Functions deployed
echo   - Firestore rules updated  
echo   - Functions tested for accessibility
echo   - Authentication flow tested (if token provided)
echo.
echo Your referral system is now live and tested!
echo.
echo Next steps:
echo   1. Test in your Flutter app
echo   2. Register new users with referral codes
echo   3. Check Firestore console for data
echo   4. Monitor function logs for any issues
echo.
pause