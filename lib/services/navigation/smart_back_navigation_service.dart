import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'navigation_safety_service.dart';

/// Service for handling smart back navigation throughout the app
/// Provides consistent back navigation behavior similar to popular apps
/// Enhanced with safety checks to prevent accidental logout     
class SmartBackNavigationService {
  
  /// STRICT RULE: Handle back navigation - NEVER allow logout   
  /// Always returns true to prevent any default behavior that could cause logout
  static bool handleBackNavigation(BuildContext context, {       
    int? currentTabIndex,
    VoidCallback? onNavigateToHome,
    String? screenName,
  }) {
    try {
      debugPrint('ðŸ”™ Smart back ($screenName): STRICT LOGOUT PREVENTION MODE');
      
      // STRICT RULE: Always validate context before any navigation
      if (!NavigationSafetyService.isNavigationSafe(context)) {  
        debugPrint('ðŸš¨ Smart back ($screenName): Navigation context unsafe - preventing logout');
        _showSafetyMessage(context, 'ðŸš« Navigation blocked for safety');
        return true; // ALWAYS prevent default back action       
      }

      // Check if there's a safe screen in the navigation stack  
      if (Navigator.of(context).canPop()) {
        // There's a screen to go back to - use natural navigation (SAFE)
        Navigator.of(context).pop();
        debugPrint('ðŸ”™ Smart back ($screenName): Safe navigation back in stack');
        return true; // Handled safely
      }

      // No stack - handle based on current context (SAFE OPERATIONS ONLY)
      if (currentTabIndex != null && currentTabIndex != 0 && onNavigateToHome != null) {
        // Not on home tab - go to home tab (SAFE OPERATION)     
        onNavigateToHome();
        _showNavigationFeedback(context, 'ðŸ  Navigated to Home tab', AppTheme.legalBlue);
        debugPrint('ðŸ”™ Smart back ($screenName): Safe switch to Home tab');
        return true; // Handled safely
      }

      // On home tab or no tab context - show message (SAFE OPERATION)
      _showNavigationFeedback(
        context,
        'ðŸ  You are on the ${screenName ?? 'main'} screen. Use bottom navigation or logout button.',
        AppTheme.talowaGreen,
        duration: 3,
      );
      debugPrint('ðŸ”™ Smart back ($screenName): On main screen, showed safe message');
      return true; // ALWAYS handled to prevent logout
    } catch (e) {
      // CRITICAL SAFETY: Any error MUST prevent logout
      debugPrint('ðŸš¨ Smart back ($screenName): Error - PREVENTING LOGOUT: $e');
      _showSafetyMessage(context, 'ðŸš« Navigation error. Use bottom tabs or logout button.');
      return true; // ALWAYS prevent default back action on error
    }
  }
  
  /// STRICT RULE: Handle main navigation back - NEVER logout
  static void handleMainNavigationBack(
    BuildContext context, 
    int currentIndex,
    Function(int) setCurrentIndex,
    VoidCallback? provideFeedback,
  ) {
    try {
      debugPrint('ðŸ”™ Main navigation: STRICT LOGOUT PREVENTION MODE');
      
      // STRICT RULE: Always validate context first
      if (!context.mounted) {
        debugPrint('ðŸš¨ Main navigation: Context not mounted - preventing logout');
        return;
      }

      // Check if there's a safe screen in the stack
      if (Navigator.of(context).canPop()) {
        // There's a screen in the stack, go back naturally (SAFE)
        Navigator.of(context).pop();
        debugPrint('ðŸ”™ Main navigation: Safe navigation back in stack');
      } else if (currentIndex != 0) {
        // Not on home tab, go to home tab (SAFE OPERATION)      
        setCurrentIndex(0);
        provideFeedback?.call();
        _showNavigationFeedback(context, 'ðŸ  Navigated to Home tab', AppTheme.legalBlue);
        debugPrint('ðŸ”™ Main navigation: Safe switch to Home tab');
      } else {
        // On home tab with no stack - show message (SAFE OPERATION)
        _showNavigationFeedback(
          context,
          'ðŸ  You are on the Home screen. Use bottom navigation or logout button.',
          AppTheme.talowaGreen,
          duration: 3,
        );
        debugPrint('ðŸ”™ Main navigation: On Home, showed safe message');
      }
    } catch (e) {
      // CRITICAL SAFETY: If anything goes wrong, show message - NEVER logout
      debugPrint('ðŸš¨ Main navigation: Error - PREVENTING LOGOUT: $e');
      try {
        if (context.mounted) {
          _showNavigationFeedback(
            context,
            'ðŸš« Navigation error. Use bottom tabs or logout button.',
            AppTheme.emergencyRed,
            duration: 4,
          );
        }
      } catch (fallbackError) {
        debugPrint('ðŸš¨ Main navigation: Even fallback failed - LOGOUT PREVENTED: $fallbackError');
        // CRITICAL: Do absolutely nothing rather than risk logout
      }
    }
  }
  
  /// Handle back navigation for sub-screens
  static void handleSubScreenBack(
    BuildContext context, {
    String? screenName,
    VoidCallback? onCustomBack,
  }) {
    try {
      // SAFETY CHECK: Validate navigation context
      if (!NavigationSafetyService.isNavigationSafe(context)) {  
        debugPrint('ðŸš¨ Sub-screen ($screenName): Navigation context unsafe');
        _showSafetyMessage(context, 'Navigation temporarily unavailable');
        return;
      }

      if (onCustomBack != null) {
        // Custom back behavior provided
        onCustomBack();
        debugPrint('ðŸ”™ Sub-screen ($screenName): Custom back behavior executed');
      } else if (Navigator.of(context).canPop()) {
        // Default back navigation
        Navigator.of(context).pop();
        debugPrint('ðŸ”™ Sub-screen ($screenName): Navigated back');
      } else {
        // No navigation stack - shouldn't happen in sub-screens 
        _showNavigationFeedback(
          context,
          'Cannot go back from ${screenName ?? 'this screen'}',  
          AppTheme.warningOrange,
        );
        debugPrint('ðŸ”™ Sub-screen ($screenName): No back navigation available');
      }
    } catch (e) {
      // SAFETY: Handle any navigation errors gracefully
      debugPrint('ðŸš¨ Sub-screen ($screenName): Error in back navigation: $e');
      _showSafetyMessage(context, 'Navigation error. Please try again.');
    }
  }
  
  /// Show navigation feedback to user
  static void _showNavigationFeedback(
    BuildContext context,
    String message,
    Color backgroundColor, {
    int duration = 1,
  }) {
    try {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: duration),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      debugPrint('ðŸš¨ Failed to show navigation feedback: $e');   
    }
  }

  /// Show safety message with warning icon
  static void _showSafetyMessage(BuildContext context, String message) {
    try {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppTheme.warningOrange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      debugPrint('ðŸš¨ Failed to show safety message: $e');        
    }
  }
  
  /// Check if back navigation is available
  static bool canNavigateBack(BuildContext context) {
    return Navigator.of(context).canPop();
  }
  
  /// Get navigation context information for debugging
  static Map<String, dynamic> getNavigationContext(BuildContext context) {
    return {
      'canPop': Navigator.of(context).canPop(),
      'routeHistory': Navigator.of(context).toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Navigation behavior modes
enum BackNavigationMode {
  /// Conservative - never exits app, always provides alternative
  conservative,
  
  /// Standard - follows common app patterns (Instagram, WhatsApp style)
  standard,
  
  /// Custom - allows custom behavior per screen
  custom,
}

/// Configuration for smart back navigation
class SmartBackNavigationConfig {
  final BackNavigationMode mode;
  final bool showFeedbackMessages;
  final bool enableDebugLogging;
  final Duration feedbackDuration;
  
  const SmartBackNavigationConfig({
    this.mode = BackNavigationMode.conservative,
    this.showFeedbackMessages = true,
    this.enableDebugLogging = true,
    this.feedbackDuration = const Duration(seconds: 1),
  });
  
  /// Default configuration for TALOWA app
  static const SmartBackNavigationConfig defaultConfig = SmartBackNavigationConfig(
    mode: BackNavigationMode.conservative,
    showFeedbackMessages: true,
    enableDebugLogging: true,
    feedbackDuration: Duration(seconds: 1),
  );
}
