// import 'dart:html' as html;  // Disabled for WebAssembly compatibility
import 'package:flutter/foundation.dart';

/// Service for handling referral links on web platform
class WebReferralRouter {
  static String? _pendingReferralCode;
  static Function(String)? _onReferralCodeReceived;
  static Function(String)? _onRouteError;
  
  /// Initialize web referral routing
  static void initialize({
    Function(String)? onReferralCodeReceived,
    Function(String)? onRouteError,
  }) {
    if (!kIsWeb) return;
    
    _onReferralCodeReceived = onReferralCodeReceived;
    _onRouteError = onRouteError;
    
    // Check current URL for referral code
    _checkCurrentUrl();
    
    // URL change listening disabled for WebAssembly compatibility
    // html.window.addEventListener('popstate', _handlePopState);
  }
  
  /// Dispose of web router
  static void dispose() {
    if (!kIsWeb) return;
    // html.window.removeEventListener('popstate', _handlePopState);
  }
  
  /// Check current URL for referral parameters
  static void _checkCurrentUrl() {
    if (!kIsWeb) return;
    
    try {
      // Web URL parsing disabled for WebAssembly compatibility
      // final uri = Uri.parse(html.window.location.href);
      // _handleWebUrl(uri);
    } catch (e) {
      _onRouteError?.call('Failed to parse current URL: $e');
    }
  }
  
  /// Handle popstate events (back/forward navigation)
  // Disabled for WebAssembly compatibility
  /*
  static void _handlePopState(html.Event event) {
    _checkCurrentUrl();
  }
  */
  
  /// Handle web URL and extract referral code
  static void _handleWebUrl(Uri uri) {
    try {
      // Track the page visit
      _trackWebVisit(uri);
      
      // Extract referral code
      final referralCode = _extractReferralCode(uri);
      if (referralCode != null) {
        _handleReferralCode(referralCode);
      }
      
      // Handle specific routes
      if (uri.path == '/join' || uri.path.startsWith('/join/')) {
        _handleJoinRoute(uri);
      }
      
    } catch (e) {
      _onRouteError?.call('Failed to handle web URL: $e');
    }
  }
  
  /// Extract referral code from URI
  static String? _extractReferralCode(Uri uri) {
    // Check query parameters
    final referralCode = uri.queryParameters['ref'];
    if (referralCode != null && referralCode.isNotEmpty) {
      return referralCode.toUpperCase();
    }
    
    // Check path segments
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'join') {
      return uri.pathSegments[1].toUpperCase();
    }
    
    return null;
  }
  
  /// Handle referral code from web URL
  static void _handleReferralCode(String referralCode) {
    _pendingReferralCode = referralCode;
    _onReferralCodeReceived?.call(referralCode);
    
    // Update URL to clean version (remove referral parameter)
    _updateUrlWithoutReferral();
  }
  
  /// Handle join route specifically
  static void _handleJoinRoute(Uri uri) {
    // This could trigger specific UI changes for the join flow
    // For example, showing a welcome message or highlighting the registration form
  }
  
  /// Update URL to remove referral parameter while preserving other parameters
  static void _updateUrlWithoutReferral() {
    if (!kIsWeb) return;
    
    try {
      // URL manipulation disabled for WebAssembly compatibility
      /*
      final currentUri = Uri.parse(html.window.location.href);
      final cleanParams = Map<String, String>.from(currentUri.queryParameters);
      cleanParams.remove('ref');
      
      final cleanUri = currentUri.replace(queryParameters: cleanParams.isEmpty ? null : cleanParams);
      
      // Update URL without triggering navigation
      html.window.history.replaceState(null, '', cleanUri.toString());
      */
    } catch (e) {
      // Fail silently for URL updates
    }
  }
  
  /// Track web visit for analytics
  static void _trackWebVisit(Uri uri) {
    try {
      // This would integrate with your analytics service
      // For now, just log to console in debug mode
      if (kDebugMode) {
        print('Web visit tracked: ${uri.toString()}');
      }
      
      // You could send this to Firebase Analytics or other services
      _sendWebAnalytics({
        'page': uri.path,
        // Web API access disabled for WebAssembly compatibility
        // 'referrer': html.document.referrer,
        // 'userAgent': html.window.navigator.userAgent,
        'timestamp': DateTime.now().toIso8601String(),
        'hasReferralCode': _extractReferralCode(uri) != null,
      });
    } catch (e) {
      // Fail silently for analytics
    }
  }
  
  /// Send web analytics data
  static void _sendWebAnalytics(Map<String, dynamic> data) {
    // Implementation would depend on your analytics setup
    // This could send to Firebase Analytics, Google Analytics, etc.
  }
  
  /// Get pending referral code from web URL
  static String? getPendingReferralCode() {
    return _pendingReferralCode;
  }
  
  /// Clear pending referral code
  static void clearPendingReferralCode() {
    _pendingReferralCode = null;
  }
  
  /// Navigate to registration with referral code
  static void navigateToRegistration([String? referralCode]) {
    if (!kIsWeb) return;
    
    // Navigation disabled for WebAssembly compatibility
    /*
    final code = referralCode ?? _pendingReferralCode;
    if (code != null) {
      final uri = Uri(path: '/register', queryParameters: {'ref': code});
      html.window.history.pushState(null, '', uri.toString());
    } else {
      html.window.history.pushState(null, '', '/register');
    }
    */
  }
  
  /// Navigate to home page
  static void navigateToHome() {
    if (!kIsWeb) return;
    // html.window.history.pushState(null, '', '/');
  }
  
  /// Get current web URL
  static String getCurrentUrl() {
    if (!kIsWeb) return '';
    // return html.window.location.href;
    return '';
  }
  
  /// Check if current page is a referral landing page
  static bool isReferralLandingPage() {
    if (!kIsWeb) return false;
    
    try {
      // Web URL parsing disabled for WebAssembly compatibility
      // final uri = Uri.parse(html.window.location.href);
      return false;
      */
    } catch (e) {
      return false;
    }
  }
  
  /// Generate shareable web URL with referral code
  static String generateWebReferralUrl(String referralCode) {
    // return '${html.window.location.origin}/join?ref=$referralCode';
    return 'https://talowa.web.app/join?ref=$referralCode';  // Fallback URL
  }
  
  /// Handle browser back button for referral flow
  static void handleBackNavigation() {
    if (!kIsWeb) return;
    
    // If user is on a referral landing page and goes back,
    // we might want to preserve the referral code
    if (isReferralLandingPage() && _pendingReferralCode != null) {
      // Session storage disabled for WebAssembly compatibility
      // html.window.sessionStorage['pendingReferralCode'] = _pendingReferralCode!;
    }
  }
  
  /// Restore referral code from session storage
  static String? restoreReferralCodeFromSession() {
    if (!kIsWeb) return null;
    
    try {
      // Session storage disabled for WebAssembly compatibility
      /*
      final code = html.window.sessionStorage['pendingReferralCode'];
      if (code != null && code.isNotEmpty) {
        html.window.sessionStorage.remove('pendingReferralCode');
        return code;
      }
      */
    } catch (e) {
      // Fail silently
    }
    
    return null;
  }
  
  /// Set page title for referral pages
  static void setReferralPageTitle(String? referrerName) {
    if (!kIsWeb) return;
    
    try {
      // Document title manipulation disabled for WebAssembly compatibility
      /*
      if (referrerName != null) {
        html.document.title = 'Join TALOWA - Invited by $referrerName';
      } else {
        html.document.title = 'Join TALOWA - Land Rights Movement';
      }
      */
    } catch (e) {
      // Fail silently
    }
  }
  
  /// Set meta description for referral pages
  static void setReferralPageMeta(String? referrerName) {
    if (!kIsWeb) return;
    
    try {
      // Meta tag manipulation disabled for WebAssembly compatibility
      /*
      final metaDesc = html.document.querySelector('meta[name="description"]') as html.MetaElement?;
      if (metaDesc != null) {
        if (referrerName != null) {
          metaDesc.content = 'Join $referrerName and thousands of others in TALOWA - India\'s land rights movement. Secure land rights for all!';
        } else {
          metaDesc.content = 'Join TALOWA - India\'s land rights movement. Secure land rights for all!';
        }
      }
      
      // Update Open Graph tags for social sharing
      _updateOpenGraphTags(referrerName);
      */
    } catch (e) {
      // Fail silently
    }
  }
  
  /// Update Open Graph meta tags for social sharing
  static void _updateOpenGraphTags(String? referrerName) {
    try {
      // Open Graph tag manipulation disabled for WebAssembly compatibility
      /*
      final ogTitle = html.document.querySelector('meta[property="og:title"]') as html.MetaElement?;
      final ogDesc = html.document.querySelector('meta[property="og:description"]') as html.MetaElement?;
      
      if (ogTitle != null) {
        ogTitle.content = referrerName != null 
            ? 'Join $referrerName in TALOWA'
            : 'Join TALOWA - Land Rights Movement';
      }
      
      if (ogDesc != null) {
        ogDesc.content = 'Join India\'s land rights movement and help secure land rights for all!';
      */
      }
    } catch (e) {
      // Fail silently
    }
  }
}

