@echo off
echo ========================================
echo TALOWA Feed System - Live App Testing
echo ========================================
echo.

echo App URL: https://talowa.web.app
echo.

echo ========================================
echo Pre-Test Verification
echo ========================================
echo.

echo 1. Checking CORS Configuration...
gcloud storage buckets describe gs://talowa.firebasestorage.app --format="value(cors_config)" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ CORS is configured
) else (
    echo ❌ CORS verification failed
)
echo.

echo 2. Checking Firestore Rules...
firebase firestore:rules:get >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ Firestore rules are deployed
) else (
    echo ❌ Firestore rules check failed
)
echo.

echo 3. Checking Storage Rules...
firebase storage:rules:get >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ Storage rules are deployed
) else (
    echo ❌ Storage rules check failed
)
echo.

echo 4. Checking App Deployment...
firebase hosting:list >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ App is deployed to hosting
) else (
    echo ❌ Hosting check failed
)
echo.

echo ========================================
echo Manual Testing Checklist
echo ========================================
echo.
echo Please test the following manually:
echo.
echo BASIC FUNCTIONALITY:
echo [ ] 1. App loads at https://talowa.web.app
echo [ ] 2. Can login/access main screen
echo [ ] 3. Can navigate to Feed tab
echo [ ] 4. Feed screen displays correctly
echo.
echo POST CREATION:
echo [ ] 5. Click "+" button opens post creation
echo [ ] 6. Can type caption
echo [ ] 7. Can add image from gallery
echo [ ] 8. Image appears in preview
echo [ ] 9. Click "Share" uploads post
echo [ ] 10. Success message appears
echo.
echo FEED DISPLAY:
echo [ ] 11. Post appears in feed
echo [ ] 12. Image loads correctly (not broken)
echo [ ] 13. Caption displays correctly
echo [ ] 14. Author name visible
echo [ ] 15. Timestamp visible
echo.
echo ENGAGEMENT:
echo [ ] 16. Can like post (heart icon)
echo [ ] 17. Like count increases
echo [ ] 18. Can unlike post
echo [ ] 19. Can click comment icon
echo [ ] 20. Can add comment
echo.
echo CONSOLE VERIFICATION:
echo [ ] 21. NO CORS errors in console (F12)
echo [ ] 22. NO "blocked by CORS policy" errors
echo [ ] 23. Image requests show 200 status
echo.
echo FIREBASE CONSOLE:
echo [ ] 24. Post appears in Firestore 'posts' collection
echo [ ] 25. Image appears in Storage 'feed_posts/' folder
echo.

echo ========================================
echo Testing Instructions
echo ========================================
echo.
echo 1. Open https://talowa.web.app in your browser
echo 2. Open DevTools (Press F12)
echo 3. Go to Console tab
echo 4. Follow the checklist above
echo 5. Mark each item as you test
echo.
echo 6. If you see CORS errors:
echo    - They will appear in red in Console
echo    - Look for "blocked by CORS policy"
echo    - Check Network tab for failed requests
echo.
echo 7. To verify in Firebase Console:
echo    - Go to: https://console.firebase.google.com/project/talowa
echo    - Check Firestore Database for posts
echo    - Check Storage for uploaded images
echo.

echo ========================================
echo Quick Test Commands
echo ========================================
echo.
echo Open app in browser:
echo start https://talowa.web.app
echo.
echo Open Firebase Console:
echo start https://console.firebase.google.com/project/talowa
echo.

echo ========================================
echo Would you like to open the app now?
echo ========================================
echo.
set /p OPEN_APP="Open https://talowa.web.app? (Y/N): "

if /i "%OPEN_APP%"=="Y" (
    echo.
    echo Opening app in browser...
    start https://talowa.web.app
    echo.
    echo Opening Firebase Console...
    start https://console.firebase.google.com/project/talowa
    echo.
    echo ✅ Opened in browser!
    echo.
    echo Now follow the testing checklist above.
    echo Press F12 to open DevTools and monitor for errors.
    echo.
)

echo ========================================
echo Testing Tips
echo ========================================
echo.
echo 1. Keep DevTools open (F12) during testing
echo 2. Watch Console tab for errors
echo 3. Check Network tab for failed requests
echo 4. Take screenshots of any issues
echo 5. Document error messages
echo.
echo If you encounter issues:
echo - Check TESTING_GUIDE.md for detailed troubleshooting
echo - Review DEPLOYMENT_COMPLETE.md for solutions
echo - Verify CORS: gcloud storage buckets describe gs://talowa.firebasestorage.app
echo.

pause
