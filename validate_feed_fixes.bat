@echo off
echo 🔍 TALOWA Feed System Validation
echo ================================

echo.
echo ✅ Checking Feed Screen Compilation...
flutter analyze lib/screens/feed/feed_screen.dart
if %errorlevel% neq 0 (
    echo ❌ Feed Screen has compilation errors
    exit /b 1
) else (
    echo ✅ Feed Screen compiles successfully
)

echo.
echo ✅ Checking Clean Feed Service...
flutter analyze lib/services/social_feed/clean_feed_service.dart
if %errorlevel% neq 0 (
    echo ❌ Clean Feed Service has compilation errors
    exit /b 1
) else (
    echo ✅ Clean Feed Service compiles successfully
)

echo.
echo ✅ Checking Post Creation Screen...
flutter analyze lib/screens/post_creation/simple_post_creation_screen.dart
if %errorlevel% neq 0 (
    echo ❌ Post Creation Screen has compilation errors
    exit /b 1
) else (
    echo ✅ Post Creation Screen compiles successfully
)

echo.
echo ✅ Checking Main Navigation...
flutter analyze lib/screens/main/main_navigation_screen.dart
if %errorlevel% neq 0 (
    echo ❌ Main Navigation has compilation errors
    exit /b 1
) else (
    echo ✅ Main Navigation compiles successfully
)

echo.
echo 🎉 All Feed System Components Validated Successfully!
echo.
echo 📋 Next Steps:
echo 1. Run 'flutter clean' to clear build cache
echo 2. Run 'flutter pub get' to ensure dependencies
echo 3. Run 'flutter build web' to test web build
echo 4. Test the feed functionality manually
echo.
echo ✅ Feed System Fix Complete!