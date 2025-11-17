@echo off
echo ========================================
echo TALOWA Social Feed System - Testing
echo ========================================
echo.

echo [1/4] Running unit tests...
call flutter test test/services/social_feed/ --reporter expanded
if errorlevel 1 (
    echo WARNING: Some unit tests failed
)

echo.
echo [2/4] Running widget tests...
call flutter test test/screens/feed/ --reporter expanded
if errorlevel 1 (
    echo WARNING: Some widget tests failed
)

echo.
echo [3/4] Checking for diagnostics...
call flutter analyze lib/screens/feed/
call flutter analyze lib/services/social_feed/

echo.
echo [4/4] Running in debug mode for manual testing...
echo.
echo Please test the following:
echo   1. Open the Feed tab
echo   2. Pull to refresh
echo   3. Scroll to load more posts
echo   4. Like/comment on posts
echo   5. Create a new post
echo   6. Check error handling (turn off internet)
echo.
echo Press Ctrl+C to stop the app when done testing
echo.
call flutter run -d chrome --web-port=8080

pause
