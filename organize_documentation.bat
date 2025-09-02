@echo off
echo 📚 TALOWA Documentation Organization Script
echo ==========================================

echo Creating archive directory for old documentation...
if not exist "archive\old_docs" mkdir "archive\old_docs"

echo Moving scattered .md files to archive...

REM Authentication related files
echo Moving authentication files...
move "AUTHENTICATION_*.md" "archive\old_docs\" 2>nul
move "REAL_AUTH_*.md" "archive\old_docs\" 2>nul
move "COMPLETE_AUTH_*.md" "archive\old_docs\" 2>nul
move "CRITICAL_REGISTRATION_*.md" "archive\old_docs\" 2>nul
move "REGISTRATION_*.md" "archive\old_docs\" 2>nul
move "PERMANENT_AUTH_*.md" "archive\old_docs\" 2>nul
move "REAL_OTP_*.md" "archive\old_docs\" 2>nul
move "WORKING_OTP_*.md" "archive\old_docs\" 2>nul
move "PRODUCTION_SAFE_AUTH_*.md" "archive\old_docs\" 2>nul

REM Referral system files
echo Moving referral system files...
move "REFERRAL_*.md" "archive\old_docs\" 2>nul
move "BULLETPROOF_REFERRAL_*.md" "archive\old_docs\" 2>nul
move "ENHANCED_REFERRAL_*.md" "archive\old_docs\" 2>nul
move "ROBUST_REFERRAL_*.md" "archive\old_docs\" 2>nul
move "SIMPLIFIED_REFERRAL_*.md" "archive\old_docs\" 2>nul
move "DUPLICATE_REFERRAL_*.md" "archive\old_docs\" 2>nul
move "ADMIN_REFERRAL_*.md" "archive\old_docs\" 2>nul

REM Home tab files
echo Moving home tab files...
move "HOME_*.md" "archive\old_docs\" 2>nul

REM Navigation files
echo Moving navigation files...
move "NAVIGATION_*.md" "archive\old_docs\" 2>nul
move "BACK_NAVIGATION_*.md" "archive\old_docs\" 2>nul
move "BACK_ARROW_*.md" "archive\old_docs\" 2>nul
move "CONSOLE_ERRORS_AND_SMART_NAVIGATION_*.md" "archive\old_docs\" 2>nul
move "SHARING_AND_NAVIGATION_*.md" "archive\old_docs\" 2>nul

REM Feed system files
echo Moving feed system files...
move "FEED_*.md" "archive\old_docs\" 2>nul

REM Network/Community files
echo Moving network system files...
move "MY_NETWORK_*.md" "archive\old_docs\" 2>nul
move "NETWORK_SCREEN_*.md" "archive\old_docs\" 2>nul

REM Messages files
echo Moving messages system files...
move "MESSAGES_*.md" "archive\old_docs\" 2>nul
move "CUSTOM_MESSAGE_*.md" "archive\old_docs\" 2>nul

REM Payment files
echo Moving payment system files...
move "PAYMENT_*.md" "archive\old_docs\" 2>nul
move "MEMBERSHIP_PAYMENT_*.md" "archive\old_docs\" 2>nul

REM Deployment files
echo Moving deployment files...
move "DEPLOYMENT_*.md" "archive\old_docs\" 2>nul
move "BUILD_AND_DEPLOYMENT_*.md" "archive\old_docs\" 2>nul
move "FIREBASE_DEPLOYMENT_*.md" "archive\old_docs\" 2>nul
move "FINAL_DEPLOYMENT_*.md" "archive\old_docs\" 2>nul
move "QUICK_DEPLOYMENT_*.md" "archive\old_docs\" 2>nul
move "FLUTTER_WEB_*.md" "archive\old_docs\" 2>nul
move "PWA_*.md" "archive\old_docs\" 2>nul

REM Firebase files
echo Moving Firebase files...
move "FIREBASE_*.md" "archive\old_docs\" 2>nul
move "CLOUD_FUNCTIONS_*.md" "archive\old_docs\" 2>nul

REM AI Assistant files
echo Moving AI assistant files...
move "AI_ASSISTANT_*.md" "archive\old_docs\" 2>nul

REM Admin system files
echo Moving admin system files...
move "ADMIN_*.md" "archive\old_docs\" 2>nul
move "COMPLETE_TALOWA_ROLE_*.md" "archive\old_docs\" 2>nul

REM Security files
echo Moving security files...
move "SECURITY_*.md" "archive\old_docs\" 2>nul

REM Testing files
echo Moving testing files...
move "MANUAL_REGISTRATION_TEST_*.md" "archive\old_docs\" 2>nul
move "README_AUTOMATED_TESTING.md" "archive\old_docs\" 2>nul

REM Troubleshooting files
echo Moving troubleshooting files...
move "PROBLEM_ANALYSIS_*.md" "archive\old_docs\" 2>nul
move "FINAL_PROBLEM_*.md" "archive\old_docs\" 2>nul
move "COMPREHENSIVE_FIXES_*.md" "archive\old_docs\" 2>nul
move "ALL_ISSUES_*.md" "archive\old_docs\" 2>nul
move "FIXES_COMPLETED_*.md" "archive\old_docs\" 2>nul
move "PERMISSION_DENIED_*.md" "archive\old_docs\" 2>nul
move "ORPHANED_VERIFICATION_*.md" "archive\old_docs\" 2>nul
move "PIN_HASH_*.md" "archive\old_docs\" 2>nul
move "POST_CREATION_*.md" "archive\old_docs\" 2>nul

REM Checkpoint and backup files
echo Moving checkpoint files...
move "CHECKPOINT_*.md" "archive\old_docs\" 2>nul
move "REVERT_TO_CHECKPOINT_*.md" "archive\old_docs\" 2>nul

REM Status and summary files
echo Moving status files...
move "FINAL_STATUS_*.md" "archive\old_docs\" 2>nul
move "COMPREHENSIVE_ANALYSIS_*.md" "archive\old_docs\" 2>nul
move "COMPLETE_IMPLEMENTATION_*.md" "archive\old_docs\" 2>nul
move "TASK_*_*.md" "archive\old_docs\" 2>nul
move "SPEC_UPDATES_*.md" "archive\old_docs\" 2>nul

REM Archiving files
echo Moving archiving files...
move "ARCHIVING_*.md" "archive\old_docs\" 2>nul

REM Debug and validation files
echo Moving debug files...
move "DEBUG_*.md" "archive\old_docs\" 2>nul
move "validation_*.md" "archive\old_docs\" 2>nul
move "verify_*.md" "archive\old_docs\" 2>nul

REM Miscellaneous implementation files
echo Moving miscellaneous files...
move "AUTOMATED_FIX_*.md" "archive\old_docs\" 2>nul
move "ONBOARDING_HELP_*.md" "archive\old_docs\" 2>nul
move "RETURNING_USER_*.md" "archive\old_docs\" 2>nul
move "SHARE_*.md" "archive\old_docs\" 2>nul
move "TEAM_SIZE_*.md" "archive\old_docs\" 2>nul
move "COMPREHENSIVE_STATS_*.md" "archive\old_docs\" 2>nul
move "EXACT_TEMPLATE_*.md" "archive\old_docs\" 2>nul
move "GITHUB_SETUP_*.md" "archive\old_docs\" 2>nul

echo Creating archive index...
echo # Old Documentation Archive > "archive\old_docs\ARCHIVE_INDEX.md"
echo. >> "archive\old_docs\ARCHIVE_INDEX.md"
echo This directory contains the old scattered .md files that have been >> "archive\old_docs\ARCHIVE_INDEX.md"
echo consolidated into the new organized documentation structure in the docs/ directory. >> "archive\old_docs\ARCHIVE_INDEX.md"
echo. >> "archive\old_docs\ARCHIVE_INDEX.md"
echo **New Documentation Location**: `/docs/` >> "archive\old_docs\ARCHIVE_INDEX.md"
echo. >> "archive\old_docs\ARCHIVE_INDEX.md"
echo ## Migration Date >> "archive\old_docs\ARCHIVE_INDEX.md"
echo %date% %time% >> "archive\old_docs\ARCHIVE_INDEX.md"
echo. >> "archive\old_docs\ARCHIVE_INDEX.md"
echo ## New Documentation Structure >> "archive\old_docs\ARCHIVE_INDEX.md"
echo - Authentication System: `/docs/AUTHENTICATION_SYSTEM.md` >> "archive\old_docs\ARCHIVE_INDEX.md"
echo - Referral System: `/docs/REFERRAL_SYSTEM.md` >> "archive\old_docs\ARCHIVE_INDEX.md"
echo - Home Tab System: `/docs/HOME_TAB_SYSTEM.md` >> "archive\old_docs\ARCHIVE_INDEX.md"
echo - Deployment Guide: `/docs/DEPLOYMENT_GUIDE.md` >> "archive\old_docs\ARCHIVE_INDEX.md"
echo - And more organized documentation files... >> "archive\old_docs\ARCHIVE_INDEX.md"

echo.
echo ✅ Documentation organization completed!
echo.
echo 📁 Old files archived to: archive\old_docs\
echo 📚 New documentation available in: docs\
echo.
echo Next steps:
echo 1. Review the new consolidated documentation in docs/
echo 2. Update any references to old .md files
echo 3. Use the new organized structure for future updates
echo.
pause