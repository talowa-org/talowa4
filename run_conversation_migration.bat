@echo off
echo ========================================
echo TALOWA Conversation Migration
echo ========================================
echo.
echo This will migrate existing conversations to the new field structure.
echo.
echo What it does:
echo - Migrates participants to participantIds
echo - Migrates unreadCount to unreadCounts
echo - Migrates active to isActive
echo - Adds missing fields
echo - Migrates all messages
echo.
echo ========================================
echo.

echo Opening migration tool in browser...
start run_migration.html

echo.
echo ========================================
echo INSTRUCTIONS:
echo ========================================
echo 1. Login with your ADMIN credentials
echo 2. Click "Run Migration" button
echo 3. Wait for completion
echo 4. Clear browser cache (Ctrl+Shift+R)
echo 5. Test messaging at https://talowa.web.app
echo ========================================
echo.
pause
