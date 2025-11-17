@echo off
echo ========================================
echo TALOWA Flutter & Firebase Upgrade
echo ========================================
echo.

echo Step 1: Cleaning previous build artifacts...
call flutter clean
if errorlevel 1 (
    echo ERROR: Flutter clean failed
    exit /b 1
)

echo.
echo Step 2: Upgrading dependencies to latest versions...
call flutter pub upgrade --major-versions
if errorlevel 1 (
    echo ERROR: Dependency upgrade failed
    exit /b 1
)

echo.
echo Step 3: Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Flutter pub get failed
    exit /b 1
)

echo.
echo Step 4: Running code analysis...
call flutter analyze
if errorlevel 1 (
    echo WARNING: Code analysis found issues - review them
)

echo.
echo Step 5: Testing web build...
call flutter build web --release --no-tree-shake-icons
if errorlevel 1 (
    echo ERROR: Web build failed
    exit /b 1
)

echo.
echo ========================================
echo ✅ UPGRADE COMPLETE!
echo ========================================
echo.
echo Next steps:
echo 1. Review any analyzer warnings
echo 2. Test the app locally: flutter run -d chrome
echo 3. Deploy to Firebase: firebase deploy
echo.
pause
