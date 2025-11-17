@echo off
echo ========================================
echo TALOWA Performance Test
echo ========================================
echo.

echo Testing Flutter environment...
call flutter doctor -v
if errorlevel 1 (
    echo WARNING: Flutter doctor found issues
)

echo.
echo ========================================
echo Analyzing code performance...
echo ========================================
call flutter analyze --no-fatal-infos
if errorlevel 1 (
    echo WARNING: Code analysis found issues
)

echo.
echo ========================================
echo Building in profile mode for testing...
echo ========================================
call flutter build web --profile --no-tree-shake-icons
if errorlevel 1 (
    echo ERROR: Profile build failed
    exit /b 1
)

echo.
echo ========================================
echo ✅ PERFORMANCE TEST COMPLETE
echo ========================================
echo.
echo Next steps:
echo 1. Run: flutter run -d chrome --profile
echo 2. Open DevTools: http://127.0.0.1:9100/#/timeline
echo 3. Monitor:
echo    - Widget rebuild count
echo    - Frame rendering time (target: 16ms)
echo    - Network latency
echo    - Memory usage
echo.
echo Performance targets:
echo - Frame time: less than 16ms (60 FPS)
echo - Initial load: less than 3 seconds
echo - Firestore reads: 80-90%% reduction
echo - Cache hit rate: greater than 80%%
echo.
pause
