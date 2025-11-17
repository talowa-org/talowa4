@echo off
echo ========================================
echo FEED FIX VERIFICATION
echo ========================================
echo.

echo [1/3] Checking if SimpleWorkingFeedScreen exists...
if exist "lib\screens\feed\simple_working_feed_screen.dart" (
    echo ✅ SimpleWorkingFeedScreen found
) else (
    echo ❌ SimpleWorkingFeedScreen NOT found
    echo Please create the file first!
    pause
    exit /b 1
)
echo.

echo [2/3] Checking if MainNavigationScreen is updated...
findstr /C:"SimpleWorkingFeedScreen" "lib\screens\main\main_navigation_screen.dart" >nul
if errorlevel 1 (
    echo ❌ MainNavigationScreen NOT updated
    echo Please update the import and screen list!
    pause
    exit /b 1
) else (
    echo ✅ MainNavigationScreen updated
)
echo.

echo [3/3] Running Flutter analyze...
flutter analyze lib/screens/feed/simple_working_feed_screen.dart
if errorlevel 1 (
    echo ❌ Code has errors
    echo Please fix the errors above before deploying!
    pause
    exit /b 1
) else (
    echo ✅ No errors found
)
echo.

echo ========================================
echo ✅ VERIFICATION PASSED!
echo ========================================
echo.
echo All checks passed! You're ready to deploy.
echo.
echo Run: fix_feed_and_deploy.bat
echo.
pause
