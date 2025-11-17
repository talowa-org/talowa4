@echo off
echo ========================================
echo TALOWA FEED DIAGNOSTIC TOOL
echo ========================================
echo.

echo [1/5] Checking Flutter installation...
flutter --version
echo.

echo [2/5] Checking for compilation errors...
flutter analyze lib/screens/feed/robust_feed_screen.dart
echo.

echo [3/5] Checking dependencies...
flutter pub get
echo.

echo [4/5] Checking for missing imports...
flutter analyze lib/services/social_feed/instagram_feed_service.dart
flutter analyze lib/widgets/feed/instagram_post_widget.dart
flutter analyze lib/screens/post_creation/instagram_post_creation_screen.dart
echo.

echo [5/5] Building for web to check for errors...
flutter build web --no-tree-shake-icons
echo.

echo ========================================
echo DIAGNOSTIC COMPLETE
echo ========================================
echo.
echo Check the output above for any errors.
echo Common issues:
echo - Missing dependencies
echo - Import errors
echo - Compilation errors
echo.
pause
