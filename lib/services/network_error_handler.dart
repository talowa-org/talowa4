// Network Error Handler Service
// Handles CORS, Firebase, and network connectivity issues

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NetworkErrorHandler {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Handle Firestore operations with retry logic
  static Future<T> handleFirestoreOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        lastException = e is Exception ? e : Exception(e.toString());
        
        if (kDebugMode) {
          debugPrint('Firestore operation failed (attempt $attempts/$maxRetries): $e');
        }

        // Check if it's a retryable error
        if (!_isRetryableError(e) || attempts >= maxRetries) {
          break;
        }

        // Wait before retrying
        await Future.delayed(retryDelay * attempts);
      }
    }

    // All retries failed, throw the last exception
    throw NetworkException(
      'Operation failed after $maxRetries attempts: ${lastException.toString()}',
      originalException: lastException,
      operationName: operationName,
    );
  }

  /// Check if an error is retryable
  static bool _isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network-related errors that can be retried
    final retryableErrors = [
      'network error',
      'connection failed',
      'timeout',
      'unavailable',
      'cors',
      'access-control-allow-origin',
      'failed to fetch',
      'network request failed',
    ];

    return retryableErrors.any((retryableError) => 
      errorString.contains(retryableError));
  }

  /// Handle Firebase Auth operations
  static Future<T> handleAuthOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    try {
      return await operation();
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _getAuthErrorMessage(e.code),
        code: e.code,
        operationName: operationName,
      );
    } catch (e) {
      throw NetworkException(
        'Authentication operation failed: ${e.toString()}',
        originalException: e is Exception ? e : Exception(e.toString()),
        operationName: operationName,
      );
    }
  }

  /// Get user-friendly auth error messages
  static String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this phone number.';
      case 'wrong-password':
        return 'Incorrect PIN. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Handle CORS errors specifically
  static Future<T> handleCorsOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    try {
      return await operation();
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('cors') || 
          errorString.contains('access-control-allow-origin')) {
        throw CorsException(
          'CORS error detected. This is a browser security restriction.',
          operationName: operationName,
        );
      }
      
      rethrow;
    }
  }

  /// Check network connectivity
  static Future<bool> isNetworkAvailable() async {
    try {
      // Try to access Firestore to check connectivity
      await FirebaseFirestore.instance
          .collection('_connectivity_test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Network connectivity check failed: $e');
      }
      return false;
    }
  }

  /// Get error message for UI display
  static String getDisplayMessage(dynamic error) {
    if (error is NetworkException) {
      return error.message;
    } else if (error is AuthException) {
      return error.message;
    } else if (error is CorsException) {
      return 'Browser security restriction. Please refresh the page.';
    } else if (error is FirebaseException) {
      return 'Firebase service error. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Log error for debugging
  static void logError(dynamic error, {String? context}) {
    if (kDebugMode) {
      debugPrint('=== Network Error ===');
      debugPrint('Context: ${context ?? 'Unknown'}');
      debugPrint('Error: $error');
      debugPrint('Type: ${error.runtimeType}');
      debugPrint('====================');
    }
  }
}

/// Custom exception for network-related errors
class NetworkException implements Exception {
  final String message;
  final Exception? originalException;
  final String? operationName;

  const NetworkException(
    this.message, {
    this.originalException,
    this.operationName,
  });

  @override
  String toString() {
    return 'NetworkException: $message';
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  final String? code;
  final String? operationName;

  const AuthException(
    this.message, {
    this.code,
    this.operationName,
  });

  @override
  String toString() {
    return 'AuthException: $message';
  }
}

/// Custom exception for CORS errors
class CorsException implements Exception {
  final String message;
  final String? operationName;

  const CorsException(
    this.message, {
    this.operationName,
  });

  @override
  String toString() {
    return 'CorsException: $message';
  }
}
