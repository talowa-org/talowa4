// Feed Error Handler Service
// Centralized error handling for social feed system
import 'package:flutter/foundation.dart';

class FeedErrorHandler {
  static final FeedErrorHandler _instance = FeedErrorHandler._internal();
  factory FeedErrorHandler() => _instance;
  FeedErrorHandler._internal();

  // Error tracking
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  
  // Error thresholds
  static const int maxErrorsPerMinute = 10;
  static const int maxConsecutiveErrors = 3;

  /// Handle feed loading error with intelligent recovery
  String handleFeedLoadError(dynamic error, {String? context}) {
    final errorKey = 'feed_load_${context ?? 'general'}';
    _trackError(errorKey);

    debugPrint('❌ Feed Load Error [$context]: $error');

    // Determine user-friendly message based on error type
    if (error.toString().contains('permission-denied')) {
      return 'You don\'t have permission to view this content. Please check your account status.';
    } else if (error.toString().contains('network')) {
      return 'Network connection issue. Please check your internet and try again.';
    } else if (error.toString().contains('not-found')) {
      return 'Content not found. It may have been removed.';
    } else if (error.toString().contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again in a moment.';
    } else if (_isRateLimited(errorKey)) {
      return 'Too many requests. Please wait a moment before trying again.';
    } else {
      return 'Unable to load feed. Please try again.';
    }
  }

  /// Handle post creation error
  String handlePostCreationError(dynamic error) {
    debugPrint('❌ Post Creation Error: $error');

    if (error.toString().contains('permission-denied')) {
      return 'You don\'t have permission to create posts.';
    } else if (error.toString().contains('invalid-argument')) {
      return 'Invalid post content. Please check your input.';
    } else if (error.toString().contains('quota-exceeded')) {
      return 'You\'ve reached your post limit. Please try again later.';
    } else {
      return 'Failed to create post. Please try again.';
    }
  }

  /// Handle engagement error (like, comment, share)
  String handleEngagementError(dynamic error, String action) {
    debugPrint('❌ Engagement Error [$action]: $error');

    if (error.toString().contains('permission-denied')) {
      return 'You don\'t have permission to $action this post.';
    } else if (error.toString().contains('not-found')) {
      return 'Post not found. It may have been deleted.';
    } else {
      return 'Failed to $action. Please try again.';
    }
  }

  /// Handle service initialization error
  String handleInitializationError(dynamic error, String serviceName) {
    debugPrint('❌ Service Initialization Error [$serviceName]: $error');

    if (error.toString().contains('firebase')) {
      return 'Failed to connect to server. Please check your internet connection.';
    } else {
      return 'Failed to initialize $serviceName. Please restart the app.';
    }
  }

  /// Track error occurrence
  void _trackError(String errorKey) {
    final now = DateTime.now();
    
    // Reset count if last error was more than 1 minute ago
    if (_lastErrorTimes.containsKey(errorKey)) {
      final lastError = _lastErrorTimes[errorKey]!;
      if (now.difference(lastError).inMinutes >= 1) {
        _errorCounts[errorKey] = 0;
      }
    }

    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
    _lastErrorTimes[errorKey] = now;
  }

  /// Check if error rate limit is exceeded
  bool _isRateLimited(String errorKey) {
    final count = _errorCounts[errorKey] ?? 0;
    return count >= maxErrorsPerMinute;
  }

  /// Check if should show error to user
  bool shouldShowError(String errorKey) {
    final count = _errorCounts[errorKey] ?? 0;
    return count <= maxConsecutiveErrors;
  }

  /// Reset error tracking for a specific key
  void resetErrors(String errorKey) {
    _errorCounts.remove(errorKey);
    _lastErrorTimes.remove(errorKey);
  }

  /// Reset all error tracking
  void resetAllErrors() {
    _errorCounts.clear();
    _lastErrorTimes.clear();
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStats() {
    return {
      'error_counts': Map.from(_errorCounts),
      'last_error_times': _lastErrorTimes.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    };
  }
}
