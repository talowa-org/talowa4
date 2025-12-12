@echo off
echo ========================================
echo TALOWA Messaging System Deployment
echo ========================================
echo.

echo [1/5] Building TypeScript Functions...
cd functions
call npm run build
if %errorlevel% neq 0 (
    echo ERROR: TypeScript build failed
    pause
    exit /b 1
)
cd ..

echo.
echo [2/5] Deploying Firestore Rules...
call firebase deploy --only firestore:rules
if %errorlevel% neq 0 (
    echo ERROR: Firestore rules deployment failed
    pause
    exit /b 1
)

echo.
echo [3/5] Deploying Cloud Functions...
call firebase deploy --only functions:createConversation,functions:sendMessage,functions:markConversationAsRead,functions:createAnonymousReport,functions:sendEmergencyBroadcast,functions:getUserConversations,functions:getUnreadCount,functions:onMessageCreated
if %errorlevel% neq 0 (
    echo ERROR: Functions deployment failed
    pause
    exit /b 1
)

echo.
echo [4/5] Building Flutter Web App...
call flutter clean
call flutter pub get
call flutter build web --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo ERROR: Flutter build failed
    pause
    exit /b 1
)

echo.
echo [5/5] Deploying to Firebase Hosting...
call firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo ERROR: Hosting deployment failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ MESSAGING SYSTEM DEPLOYED SUCCESSFULLY!
echo ========================================
echo.
echo Your messaging system is now live at:
echo https://talowa.web.app
echo.
echo Test the following features:
echo - Direct messaging
echo - Group chats
echo - Anonymous reports
echo - Emergency broadcasts
echo.
pause
