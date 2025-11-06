// Error Handler Utility for TALOWA
// Provides comprehensive error handling and recovery mechanisms

import 'package:flutter/foundation.dart';

class ErrorHandler {
  static const String _tag = 'ErrorHandler';

  /// Handle errors gracefully with logging and user-friendly messages
  static String handleError(dynamic error, {String? context}) {
    final errorMessage = _extractErrorMessage(error);
    
    // Log error for debugging
    debugPrint('❌ [$_tag] ${context ?? 'Error'}: $errorMessage');
    
    // Return user-friendly message
    return _getUserFriendlyMessage(error);
  }

  /// Extract meaningful error message from various error types
  static String _extractErrorMessage(dynamic error) {
    if (error == null) return 'Unknown error occurred';
    
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    
    if (error is Error) {
      return error.toString();
    }
    
    return error.toString();
  }

  /// Convert technical errors to user-friendly messages
  static String _getUserFriendlyMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    // Network related errors
    if (errorStr.contains('network') || 
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('socket')) {
      return 'Network connection issue. Please check your internet connection.';
    }
    
    // Permission errors
    if (errorStr.contains('permission') || errorStr.contains('unauthorized')) {
      return 'Permission denied. Please check your account permissions.';
    }
    
    // Data parsing errors
    if (errorStr.contains('parsing') || 
        errorStr.contains('format') ||
        errorStr.contains('json') ||
        errorStr.contains('null')) {
      return 'Data format error. Please try refreshing the content.';
    }
    
    // Firebase/Firestore errors
    if (errorStr.contains('firestore') || errorStr.contains('firebase')) {
      return 'Database connection issue. Please try again later.';
    }
    
    // Authentication errors
    if (errorStr.contains('auth') || errorStr.contains('login')) {
      return 'Authentication issue. Please log in again.';
    }
    
    // Generic fallback
    return 'Something went wrong. Please try again.';
  }

  /// Check if error is recoverable (user can retry)
  static bool isRecoverable(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    // Non-recoverable errors
    if (errorStr.contains('permission') || 
        errorStr.contains('unauthorized') ||
        errorStr.contains('forbidden')) {
      return false;
    }
    
    // Most other errors are recoverable
    return true;
  }

  /// Check if error should be shown to user
  static bool shouldShowToUser(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    // Don't show technical/internal errors
    if (errorStr.contains('minified') || 
        errorStr.contains('internal') ||
        errorStr.contains('debug')) {
      return false;
    }
    
    return true;
  }

  /// Safe execution wrapper that handles errors gracefully
  static Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    String? context,
    T? fallbackValue,
    bool logError = true,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (logError) {
        handleError(e, context: context);
      }
      return fallbackValue;
    }
  }

  /// Safe synchronous execution wrapper
  static T? safeExecuteSync<T>(
    T Function() operation, {
    String? context,
    T? fallbackValue,
    bool logError = true,
  }) {
    try {
      return operation();
    } catch (e) {
      if (logError) {
        handleError(e, context: context);
      }
      return fallbackValue;
    }
  }
}