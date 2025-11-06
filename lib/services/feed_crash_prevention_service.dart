// Feed Crash Prevention Service for TALOWA
// Comprehensive crash prevention and memory management for feed scrolling
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class FeedCrashPreventionService {
  static final FeedCrashPreventionService _instance = FeedCrashPreventionService._internal();
  factory FeedCrashPreventionService() => _instance;
  FeedCrashPreventionService._internal();

  // Memory management
  static const int _maxCachedPosts = 50;
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  
  // Scroll management
  Timer? _scrollDebounceTimer;
  Timer? _memoryCleanupTimer;
  bool _isLoadingMore = false;
  int _consecutiveErrors = 0;
  DateTime? _lastScrollEvent;
  
  // Error tracking
  final Map<String, int> _errorCounts = {};
  final List<String> _recentErrors = [];
  
  bool _isInitialized = false;

  /// Initialize the crash prevention service
  void initialize() {
    if (_isInitialized) return;
    
    _setupMemoryMonitoring();
    _setupErrorTracking();
    _isInitialized = true;
    
    debugPrint('✅ Feed Crash Prevention Service initialized');
  }

  /// Setup memory monitoring and cleanup
  void _setupMemoryMonitoring() {
    _memoryCleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _performMemoryCleanup();
    });
  }

  /// Setup error tracking and recovery
  void _setupErrorTracking() {
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };
  }

  /// Handle scroll events with debouncing and safety checks
  bool handleScrollEvent({
    required double pixels,
    required double maxScrollExtent,
    required VoidCallback onLoadMore,
    double threshold = 200.0,
  }) {
    try {
      // Prevent rapid successive calls
      final now = DateTime.now();
      if (_lastScrollEvent != null && 
          now.difference(_lastScrollEvent!).inMilliseconds < 100) {
        return false;
      }
      _lastScrollEvent = now;

      // Check if already loading
      if (_isLoadingMore) {
        return false;
      }

      // Check scroll position safely
      if (pixels >= maxScrollExtent - threshold) {
        _debounceLoadMore(onLoadMore);
        return true;
      }

      return false;
    } catch (e) {
      _handleError('scroll_event_error', e);
      return false;
    }
  }

  /// Debounced load more to prevent rapid calls
  void _debounceLoadMore(VoidCallback onLoadMore) {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(_debounceDelay, () {
      if (!_isLoadingMore) {
        _isLoadingMore = true;
        try {
          onLoadMore();
        } catch (e) {
          _handleError('load_more_error', e);
        } finally {
          // Reset loading state after delay
          Timer(const Duration(seconds: 2), () {
            _isLoadingMore = false;
          });
        }
      }
    });
  }

  /// Safe list management with memory limits
  List<T> manageFeedList<T>(List<T> currentList, List<T> newItems) {
    try {
      final combinedList = [...currentList, ...newItems];
      
      // Limit list size to prevent memory issues
      if (combinedList.length > _maxCachedPosts) {
        final startIndex = combinedList.length - _maxCachedPosts;
        return combinedList.sublist(startIndex);
      }
      
      return combinedList;
    } catch (e) {
      _handleError('list_management_error', e);
      // Return safe fallback
      return newItems.take(_maxCachedPosts ~/ 2).toList();
    }
  }

  /// Safe widget building with error boundaries
  Widget buildSafeWidget({
    required Widget Function() builder,
    Widget? fallback,
  }) {
    try {
      return builder();
    } catch (e) {
      _handleError('widget_build_error', e);
      return fallback ?? _buildErrorFallback();
    }
  }

  /// Safe async operation wrapper
  Future<T?> safeAsyncOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? fallbackValue,
  }) async {
    try {
      return await operation();
    } catch (e) {
      _handleError(operationName ?? 'async_operation_error', e);
      return fallbackValue;
    }
  }

  /// Memory cleanup and optimization
  void _performMemoryCleanup() {
    try {
      // Force garbage collection if available
      if (kDebugMode) {
        debugPrint('🧹 Performing memory cleanup...');
      }
      
      // Clear error history if too large
      if (_recentErrors.length > 100) {
        _recentErrors.removeRange(0, _recentErrors.length - 50);
      }
      
      // Reset error counts periodically
      if (_errorCounts.length > 50) {
        _errorCounts.clear();
      }
      
      // Reset consecutive errors if no recent errors
      if (_consecutiveErrors > 0) {
        _consecutiveErrors = max(0, _consecutiveErrors - 1);
      }
      
    } catch (e) {
      debugPrint('❌ Error during memory cleanup: $e');
    }
  }

  /// Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    final errorString = details.toString();
    _handleError('flutter_framework_error', errorString);
    
    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('🚨 Flutter Error: $errorString');
    }
  }

  /// Centralized error handling
  void _handleError(String errorType, dynamic error) {
    try {
      final errorString = error.toString();
      
      // Track error frequency
      _errorCounts[errorType] = (_errorCounts[errorType] ?? 0) + 1;
      _recentErrors.add('${DateTime.now()}: $errorType - $errorString');
      _consecutiveErrors++;
      
      // Log error
      debugPrint('❌ Feed Error [$errorType]: $errorString');
      
      // Trigger recovery if too many consecutive errors
      if (_consecutiveErrors > 5) {
        _triggerErrorRecovery();
      }
      
    } catch (e) {
      // Fallback error handling
      debugPrint('❌ Critical error in error handler: $e');
    }
  }

  /// Trigger error recovery mechanisms
  void _triggerErrorRecovery() {
    try {
      debugPrint('🔄 Triggering error recovery...');
      
      // Reset state
      _isLoadingMore = false;
      _consecutiveErrors = 0;
      
      // Cancel timers
      _scrollDebounceTimer?.cancel();
      
      // Clear some cached data
      _errorCounts.clear();
      
      // Force haptic feedback to indicate recovery
      HapticFeedback.lightImpact();
      
    } catch (e) {
      debugPrint('❌ Error during recovery: $e');
    }
  }

  /// Build error fallback widget
  Widget _buildErrorFallback() {
    return Container(
      height: 100,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey, size: 24),
            SizedBox(height: 8),
            Text(
              'Content temporarily unavailable',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if system is in a healthy state
  bool get isHealthy => _consecutiveErrors < 3;

  /// Get error statistics
  Map<String, dynamic> getErrorStats() {
    return {
      'consecutive_errors': _consecutiveErrors,
      'total_error_types': _errorCounts.length,
      'recent_errors_count': _recentErrors.length,
      'is_loading_more': _isLoadingMore,
      'is_healthy': isHealthy,
    };
  }

  /// Reset all error tracking
  void resetErrorTracking() {
    _consecutiveErrors = 0;
    _errorCounts.clear();
    _recentErrors.clear();
    _isLoadingMore = false;
  }

  /// Dispose resources
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _memoryCleanupTimer?.cancel();
    _isInitialized = false;
  }
}