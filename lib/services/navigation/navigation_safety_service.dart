// Navigation Safety Service
// Prevents accidental logout from navigation actions

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NavigationSafetyService {
  static const String _tag = 'NavigationSafety';

  /// Safely handle back navigation without risking logout       
  static bool handleBackNavigation(BuildContext context, {       
    String screenName = 'Unknown',
    VoidCallback? onBackPressed,
    String? customMessage,
  }) {
    try {
      debugPrint('$_tag: Handling back navigation for $screenName');
      
      // Safety check: Ensure context is valid
      if (!context.mounted) {
        debugPrint('$_tag: Context not mounted, aborting navigation');
        return false;
      }

      // Check if we can safely pop
      if (Navigator.of(context).canPop()) {
        // Safe to go back
        Navigator.of(context).pop();
        debugPrint('$_tag: Successfully navigated back from $screenName');
        return true;
      } else {
        // Cannot pop - show message instead of risking logout   
        final message = customMessage ??
          'Use bottom navigation to switch between tabs';        

        _showSafetyMessage(context, message);
        debugPrint('$_tag: Cannot pop from $screenName, showed safety message');
        
        // Execute custom callback if provided
        onBackPressed?.call();

        return false; // Prevent default back action
      }
    } catch (e) {
      debugPrint('$_tag: Error in back navigation for $screenName: $e');

      // Critical safety: Show message instead of risking logout 
      try {
        if (context.mounted) {
          _showSafetyMessage(
            context,
            'Navigation error. Please use bottom tabs.',
            isError: true,
          );
        }
      } catch (fallbackError) {
        debugPrint('$_tag: Even safety message failed: $fallbackError');
      }

      return false; // Always prevent default action on error    
    }
  }

  /// Show safety message to user
  static void _showSafetyMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.warning : Icons.info,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),   
                ),
              ),
            ],
          ),
          backgroundColor: isError ? AppTheme.warningOrange : AppTheme.legalBlue,
          duration: Duration(seconds: isError ? 4 : 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('$_tag: Failed to show safety message: $e');    
    }
  }

  /// Create a safe PopScope widget
  static Widget createSafePopScope({
    required Widget child,
    required String screenName,
    VoidCallback? onBackPressed,
    String? customMessage,
  }) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Use our safe navigation handler
          handleBackNavigation(
            NavigationService.navigatorKey.currentContext!,      
            screenName: screenName,
            onBackPressed: onBackPressed,
            customMessage: customMessage,
          );
        }
      },
      child: child,
    );
  }

  /// Validate navigation context before performing navigation   
  static bool isNavigationSafe(BuildContext context) {
    try {
      return context.mounted &&
             Navigator.of(context).mounted;
    } catch (e) {
      debugPrint('$_tag: Navigation context validation failed: $e');
      return false;
    }
  }

  /// Safe navigation to named route
  static Future<T?> safeNavigateTo<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    try {
      if (!isNavigationSafe(context)) {
        debugPrint('$_tag: Navigation context unsafe for route: $routeName');
        return null;
      }

      return await Navigator.of(context).pushNamed(
        routeName,
        arguments: arguments,
      );
    } catch (e) {
      debugPrint('$_tag: Safe navigation to $routeName failed: $e');
      return null;
    }
  }

  /// Safe navigation replacement
  static Future<T?> safeNavigateAndReplace<T extends Object?>(   
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    try {
      if (!isNavigationSafe(context)) {
        debugPrint('$_tag: Navigation context unsafe for replacement: $routeName');
        return null;
      }

      return await Navigator.of(context).pushReplacementNamed(   
        routeName,
        arguments: arguments,
      );
    } catch (e) {
      debugPrint('$_tag: Safe navigation replacement to $routeName failed: $e');
      return null;
    }
  }
}

/// Global navigation service for safe navigation
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;

  /// Get current context safely
  static BuildContext? get currentContext => navigatorKey.currentContext;
  
  /// Check if navigation is available
  static bool get isNavigationAvailable =>
      navigator != null && currentContext != null;
}