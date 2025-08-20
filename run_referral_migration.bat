@echo off
echo.
echo ========================================
echo TALOWA Referral System Migration
echo ========================================
echo.
echo This will migrate from two-step to simplified one-step referral system.
echo.
echo WARNING: This action cannot be undone!
echo.
set /p confirm="Are you sure you want to proceed? (y/N): "
if /i "%confirm%" neq "y" (
    echo Migration cancelled.
    pause
    exit /b 1
)

echo.
echo Starting migration...
echo.

dart scripts/migrate_referral_system.dart --confirm

echo.
echo Migration completed!
echo.
pause