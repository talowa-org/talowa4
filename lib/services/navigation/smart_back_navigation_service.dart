import 'package:flutter/material.dart';

/// Service for handling smart back navigation throughout the app
/// Provides consistent back navigation behavior similar to popular apps
class SmartBackNavigationService {
  
  /// Handle back navigation with smart logic
  /// Returns true if navigation was handled, false if default behavior should apply
  static bool handleBackNavigation(BuildContext context, {
    int? currentTabIndex,
    VoidCallback? onNavigateToHome,
    String? screenName,
  }) {
    // Check if there's a screen in the navigation stack
    if (Navigator.of(context).canPop()) {
      // There's a screen to go back to - use natural navigation
      Navigator.of(context).pop();
      debugPrint('🔙 Smart back ($screenName): Navigated back in stack');
      return true;
    }
    
    // No stack - handle based on current context
    if (currentTabIndex != null && currentTabIndex != 0 && onNavigateToHome != null) {
      // Not on home tab - go to home tab
      onNavigateToHome();
      _showNavigationFeedback(context, 'Navigated to Home', Colors.blue);
      debugPrint('🔙 Smart back ($screenName): Switched to Home tab');
      return true;
    }
    
    // On home tab or no tab context - show helpful message
    _showNavigationFeedback(
      context, 
      'You are on the ${screenName ?? 'main'} screen. Use bottom navigation to switch tabs.',
      Colors.green,
      duration: 2,
    );
    debugPrint('🔙 Smart back ($screenName): Already on main screen, showing message');
    return true;
  }
  
  /// Handle back navigation for main navigation screen
  static void handleMainNavigationBack(
    BuildContext context, 
    int currentIndex, 
    Function(int) setCurrentIndex,
    VoidCallback? provideFeedback,
  ) {
    if (Navigator.of(context).canPop()) {
      // There's a screen in the stack, go back naturally
      Navigator.of(context).pop();
      debugPrint('🔙 Main navigation: Navigated back in stack');
    } else if (currentIndex != 0) {
      // Not on home tab, go to home tab
      setCurrentIndex(0);
      provideFeedback?.call();
      _showNavigationFeedback(context, '🏠 Navigated to Home', Colors.blue);
      debugPrint('🔙 Main navigation: Switched to Home tab');
    } else {
      // On home tab with no stack - show helpful message
      _showNavigationFeedback(
        context,
        'You are on the Home screen. Use bottom navigation to switch tabs.',
        Colors.green,
        duration: 2,
      );
      debugPrint('🔙 Main navigation: Already on Home, showing message');
    }
  }
  
  /// Handle back navigation for sub-screens
  static void handleSubScreenBack(
    BuildContext context, {
    String? screenName,
    VoidCallback? onCustomBack,
  }) {
    if (onCustomBack != null) {
      // Custom back behavior provided
      onCustomBack();
      debugPrint('🔙 Sub-screen ($screenName): Custom back behavior executed');
    } else if (Navigator.of(context).canPop()) {
      // Default back navigation
      Navigator.of(context).pop();
      debugPrint('🔙 Sub-screen ($screenName): Navigated back');
    } else {
      // No navigation stack - shouldn't happen in sub-screens
      _showNavigationFeedback(
        context,
        'Cannot go back from ${screenName ?? 'this screen'}',
        Colors.orange,
      );
      debugPrint('🔙 Sub-screen ($screenName): No back navigation available');
    }
  }
  
  /// Show navigation feedback to user
  static void _showNavigationFeedback(
    BuildContext context, 
    String message, 
    Color backgroundColor, {
    int duration = 1,
  }) {
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