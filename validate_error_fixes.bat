@echo off
echo ========================================
echo TALOWA - Error Fix Validation Script
echo ========================================
echo.

echo Step 1: Check for infinity.toInt() issues...
findstr /r /n "infinity.*toInt toInt.*infinity" lib\widgets\referral\stats_card_widget.dart >nul 2>&1
if errorlevel 1 (
    echo No infinity.toInt() issues found
) else (
    echo Still has infinity.toInt() issues
)

echo.
echo Step 2: Check memory management platform handling...
findstr /r /n "kIsWeb.*Platform" lib\services\performance\memory_management_service.dart >nul 2>&1
if not errorlevel 1 (
    echo Platform detection found in memory service
) else (
    echo Platform detection missing
)

echo.
echo Step 3: Quick syntax check...
call flutter analyze --no-fatal-infos --no-fatal-warnings > validation_check.txt 2>&1
if errorlevel 1 (
    echo Syntax errors found - check validation_check.txt
    type validation_check.txt
) else (
    echo No critical syntax errors
)

echo.
echo Step 4: Test build (dry run)...
call flutter build web --analyze-size --no-tree-shake-icons > build_test.txt 2>&1
if errorlevel 1 (
    echo Build test failed - check build_test.txt
    echo Last 10 lines of build output:
    powershell "Get-Content build_test.txt | Select-Object -Last 10"
) else (
    echo Build test passed
)

echo.
echo VALIDATION COMPLETE
echo Check the output above for any remaining issues.
echo.
pause