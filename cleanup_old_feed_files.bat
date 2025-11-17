@echo off
echo ========================================
echo FEED FILES CLEANUP SCRIPT
echo ========================================
echo.
echo This script will archive old feed files to prevent conflicts
echo with the new enhanced Instagram feed implementation.
echo.
echo Old files will be moved to: lib/screens/_archived/
echo.
pause

echo.
echo [1/3] Creating archive directories...
if not exist "lib\screens\_archived\feed" mkdir "lib\screens\_archived\feed"
if not exist "lib\screens\_archived\post_creation" mkdir "lib\screens\_archived\post_creation"
echo ✅ Archive directories created
echo.

echo [2/3] Archiving old feed screens...
if exist "lib\screens\feed\instagram_feed_screen.dart" (
    move "lib\screens\feed\instagram_feed_screen.dart" "lib\screens\_archived\feed\"
    echo ✅ Archived instagram_feed_screen.dart
)
if exist "lib\screens\feed\modern_feed_screen.dart" (
    move "lib\screens\feed\modern_feed_screen.dart" "lib\screens\_archived\feed\"
    echo ✅ Archived modern_feed_screen.dart
)
if exist "lib\screens\feed\offline_feed_screen.dart" (
    move "lib\screens\feed\offline_feed_screen.dart" "lib\screens\_archived\feed\"
    echo ✅ Archived offline_feed_screen.dart
)
if exist "lib\screens\feed\robust_feed_screen.dart" (
    move "lib\screens\feed\robust_feed_screen.dart" "lib\screens\_archived\feed\"
    echo ✅ Archived robust_feed_screen.dart
)
if exist "lib\screens\feed\simple_working_feed_screen.dart" (
    move "lib\screens\feed\simple_working_feed_screen.dart" "lib\screens\_archived\feed\"
    echo ✅ Archived simple_working_feed_screen.dart
)
echo.

echo [3/3] Archiving old post creation screens...
if exist "lib\screens\post_creation\instagram_post_creation_screen.dart" (
    move "lib\screens\post_creation\instagram_post_creation_screen.dart" "lib\screens\_archived\post_creation\"
    echo ✅ Archived instagram_post_creation_screen.dart
)
if exist "lib\screens\post_creation\post_creation_screen.dart" (
    move "lib\screens\post_creation\post_creation_screen.dart" "lib\screens\_archived\post_creation\"
    echo ✅ Archived post_creation_screen.dart
)
if exist "lib\screens\post_creation\simple_post_creation_screen.dart" (
    move "lib\screens\post_creation\simple_post_creation_screen.dart" "lib\screens\_archived\post_creation\"
    echo ✅ Archived simple_post_creation_screen.dart
)
echo.

echo ========================================
echo ✅ CLEANUP COMPLETE!
echo ========================================
echo.
echo Active files (still in use):
echo   ✅ lib/screens/feed/enhanced_instagram_feed_screen.dart
echo   ✅ lib/screens/post_creation/enhanced_post_creation_screen.dart
echo   ✅ lib/widgets/feed/enhanced_post_widget.dart
echo.
echo Archived files (moved to _archived):
echo   📦 Old feed screens (5 files)
echo   📦 Old post creation screens (3 files)
echo.
echo Kept files (still useful):
echo   ✅ comments_screen.dart
echo   ✅ post_comments_screen.dart
echo   ✅ stories_screen.dart
echo   ✅ story_creation_screen.dart
echo.
echo You can safely delete the _archived folder if you don't need the old files.
echo.
pause
