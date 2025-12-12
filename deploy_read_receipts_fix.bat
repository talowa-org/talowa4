@echo off
echo ========================================
echo TALOWA - Read Receipts Fix Deployment
echo ========================================
echo.

echo [1/4] Cleaning build cache...
call flutter clean
if errorlevel 1 (
    echo ERROR: Flutter clean failed
    pause
    exit /b 1
)

echo.
echo [2/4] Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Flutter pub get failed
    pause
    exit /b 1
)

echo.
echo [3/4] Building web app...
call flutter build web --no-tree-shake-icons
if errorlevel 1 (
    echo ERROR: Flutter build failed
    pause
    exit /b 1
)

echo.
echo [4/4] Deploying to Firebase...
call firebase deploy --only hosting
if errorlevel 1 (
    echo ERROR: Firebase deploy failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ READ RECEIPTS FIX DEPLOYED!
echo ========================================
echo.
echo Changes deployed:
echo - Messages no longer show blue ticks until receiver reads them
echo - WhatsApp-style read receipts implemented
echo - Single grey tick: Sent
echo - Double grey ticks: Delivered
echo - Double blue ticks: Read by receiver
echo.
echo Test the fix at: https://talowa.web.app
echo.
pause
