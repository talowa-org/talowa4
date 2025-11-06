// Message Error Handler for TALOWA Messaging System
// Provides user-friendly error messages and error recovery strategies
// Requirements: 7.1, 7.3

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Error types for messaging system
enum MessageErrorType {
  networkError,
  authenticationError,
  permissionError,
  rateLimitError,
  serverError,
  validationError,
  storageError,
  unknownError,
}

/// Message error model
class MessageError {
  final MessageErrorType type;
  final String code;
  final String message;
  final String userFriendlyMessage;
  final bool isRetryable;
  final Duration? retryAfter;
  final Map<String, dynamic> metadata;

  MessageError({
    required this.type,
    required this.code,
    required this.message,
    required this.userFriendlyMessage,
    required this.isRetryable,
    this.retryAfter,
    this.metadata = const {},
  });

  @override
  String toString() {
    return 'MessageError(type: $type, code: $code, message: $message)';
  }
}

/// Error recovery strategy
class ErrorRecoveryStrategy {
  final String action;
  final String description;
  final Future<bool> Function() execute;

  ErrorRecoveryStrategy({
    required this.action,
    required this.description,
    required this.execute,
  });
}

/// Message error handler service
class MessageErrorHandler {
  static final MessageErrorHandler _instance = MessageErrorHandler._internal();
  factory MessageErrorHandler() => _instance;
  MessageErrorHandler._internal();

  // Stream controller for error notifications
  final StreamController<MessageError> _errorStreamController = 
      StreamController<MessageError>.broadcast();

  // Error statistics
  final Map<MessageErrorType, int> _errorCounts = {};
  final List<MessageError> _recentErrors = [];

  // Getters
  Stream<MessageError> get errorStream => _errorStreamController.stream;
  Map<MessageErrorType, int> get errorCounts => Map.unmodifiable(_errorCounts);
  List<MessageError> get recentErrors => List.unmodifiable(_recentErrors);

  /// Handle and classify errors
  MessageError handleError(dynamic error, {Map<String, dynamic>? context}) {
    final messageError = _classifyError(error, context);
    
    // Update statistics
    _updateErrorStatistics(messageError);
    
    // Add to recent errors (keep last 50)
    _recentErrors.add(messageError);
    if (_recentErrors.length > 50) {
      _recentErrors.removeAt(0);
    }
    
    // Emit error to stream
    _errorStreamController.add(messageError);
    
    // Log error for debugging
    _logError(messageError, error);
    
    return messageError;
  }

  /// Classify error type and create MessageError
  MessageError _classifyError(dynamic error, Map<String, dynamic>? context) {
    if (error is SocketException) {
      return _createNetworkError(error);
    } else if (error is FirebaseException) {
      return _createFirebaseError(error);
    } else if (error is TimeoutException) {
      return _createTimeoutError(error);
    } else if (error is FormatException) {
      return _createValidationError(error);
    } else if (error.toString().contains('permission')) {
      return _createPermissionError(error);
    } else if (error.toString().contains('rate limit')) {
      return _createRateLimitError(error);
    } else if (error.toString().contains('authentication') || 
               error.toString().contains('unauthorized')) {
      return _createAuthenticationError(error);
    } else {
      return _createUnknownError(error);
    }
  }

  /// Create network error
  MessageError _createNetworkError(SocketException error) {
    return MessageError(
      type: MessageErrorType.networkError,
      code: 'NETWORK_ERROR',
      message: error.message,
      userFriendlyMessage: 'Unable to connect to the server. Please check your internet connection and try again.',
      isRetryable: true,
      retryAfter: const Duration(seconds: 5),
      metadata: {
        'osError': error.osError?.toString(),
        'address': error.address?.toString(),
        'port': error.port,
      },
    );
  }

  /// Create Firebase error
  MessageError _createFirebaseError(FirebaseException error) {
    String userMessage;
    bool isRetryable = true;
    Duration? retryAfter;

    switch (error.code) {
      case 'permission-denied':
        userMessage = 'You don\'t have permission to perform this action.';
        isRetryable = false;
        break;
      case 'unavailable':
        userMessage = 'Service is temporarily unavailable. Please try again in a moment.';
        retryAfter = const Duration(seconds: 10);
        break;
      case 'deadline-exceeded':
        userMessage = 'Request timed out. Please try again.';
        retryAfter = const Duration(seconds: 3);
        break;
      case 'resource-exhausted':
        userMessage = 'Too many requests. Please wait a moment before trying again.';
        retryAfter = const Duration(minutes: 1);
        break;
      case 'unauthenticated':
        userMessage = 'Please log in again to continue.';
        isRetryable = false;
        break;
      default:
        userMessage = 'A server error occurred. Please try again.';
        retryAfter = const Duration(seconds: 5);
    }

    return MessageError(
      type: MessageErrorType.serverError,
      code: 'FIREBASE_${error.code.toUpperCase()}',
      message: error.message ?? 'Firebase error',
      userFriendlyMessage: userMessage,
      isRetryable: isRetryable,
      retryAfter: retryAfter,
      metadata: {
        'firebaseCode': error.code,
        'plugin': error.plugin,
      },
    );
  }

  /// Create timeout error
  MessageError _createTimeoutError(TimeoutException error) {
    return MessageError(
      type: MessageErrorType.networkError,
      code: 'TIMEOUT_ERROR',
      message: error.message ?? 'Request timed out',
      userFriendlyMessage: 'The request took too long to complete. Please check your connection and try again.',
      isRetryable: true,
      retryAfter: const Duration(seconds: 3),
      metadata: {
        'duration': error.duration?.toString(),
      },
    );
  }

  /// Create validation error
  MessageError _createValidationError(FormatException error) {
    return MessageError(
      type: MessageErrorType.validationError,
      code: 'VALIDATION_ERROR',
      message: error.message,
      userFriendlyMessage: 'Invalid message format. Please check your input and try again.',
      isRetryable: false,
      metadata: {
        'source': error.source,
        'offset': error.offset,
      },
    );
  }

  /// Create permission error
  MessageError _createPermissionError(dynamic error) {
    return MessageError(
      type: MessageErrorType.permissionError,
      code: 'PERMISSION_ERROR',
      message: error.toString(),
      userFriendlyMessage: 'You don\'t have permission to send messages in this conversation.',
      isRetryable: false,
    );
  }

  /// Create rate limit error
  MessageError _createRateLimitError(dynamic error) {
    return MessageError(
      type: MessageErrorType.rateLimitError,
      code: 'RATE_LIMIT_ERROR',
      message: error.toString(),
      userFriendlyMessage: 'You\'re sending messages too quickly. Please wait a moment before trying again.',
      isRetryable: true,
      retryAfter: const Duration(seconds: 30),
    );
  }

  /// Create authentication error
  MessageError _createAuthenticationError(dynamic error) {
    return MessageError(
      type: MessageErrorType.authenticationError,
      code: 'AUTH_ERROR',
      message: error.toString(),
      userFriendlyMessage: 'Your session has expired. Please log in again to continue messaging.',
      isRetryable: false,
    );
  }

  /// Create unknown error
  MessageError _createUnknownError(dynamic error) {
    return MessageError(
      type: MessageErrorType.unknownError,
      code: 'UNKNOWN_ERROR',
      message: error.toString(),
      userFriendlyMessage: 'An unexpected error occurred. Please try again.',
      isRetryable: true,
      retryAfter: const Duration(seconds: 5),
    );
  }

  /// Update error statistics
  void _updateErrorStatistics(MessageError error) {
    _errorCounts[error.type] = (_errorCounts[error.type] ?? 0) + 1;
  }

  /// Log error for debugging
  void _logError(MessageError messageError, dynamic originalError) {
    if (kDebugMode) {
      debugPrint('🚨 MessageError: ${messageError.type} - ${messageError.code}');
      debugPrint('   Message: ${messageError.message}');
      debugPrint('   User Message: ${messageError.userFriendlyMessage}');
      debugPrint('   Retryable: ${messageError.isRetryable}');
      debugPrint('   Original Error: $originalError');
      if (messageError.metadata.isNotEmpty) {
        debugPrint('   Metadata: ${messageError.metadata}');
      }
    }
  }

  /// Get error recovery strategies
  List<ErrorRecoveryStrategy> getRecoveryStrategies(MessageError error) {
    final strategies = <ErrorRecoveryStrategy>[];

    switch (error.type) {
      case MessageErrorType.networkError:
        strategies.addAll([
          ErrorRecoveryStrategy(
            action: 'Check Connection',
            description: 'Verify your internet connection',
            execute: () async {
              // Implement connection check
              return true;
            },
          ),
          ErrorRecoveryStrategy(
            action: 'Retry',
            description: 'Try sending the message again',
            execute: () async {
              // Implement retry logic
              return true;
            },
          ),
        ]);
        break;

      case MessageErrorType.authenticationError:
        strategies.add(
          ErrorRecoveryStrategy(
            action: 'Re-authenticate',
            description: 'Log in again to continue',
            execute: () async {
              // Implement re-authentication
              return true;
            },
          ),
        );
        break;

      case MessageErrorType.rateLimitError:
        strategies.add(
          ErrorRecoveryStrategy(
            action: 'Wait and Retry',
            description: 'Wait for the rate limit to reset',
            execute: () async {
              await Future.delayed(error.retryAfter ?? const Duration(seconds: 30));
              return true;
            },
          ),
        );
        break;

      case MessageErrorType.serverError:
        strategies.add(
          ErrorRecoveryStrategy(
            action: 'Retry Later',
            description: 'Try again in a few moments',
            execute: () async {
              await Future.delayed(error.retryAfter ?? const Duration(seconds: 10));
              return true;
            },
          ),
        );
        break;

      default:
        strategies.add(
          ErrorRecoveryStrategy(
            action: 'Retry',
            description: 'Try the operation again',
            execute: () async {
              return true;
            },
          ),
        );
    }

    return strategies;
  }

  /// Check if error should trigger offline mode
  bool shouldTriggerOfflineMode(MessageError error) {
    return error.type == MessageErrorType.networkError ||
           (error.type == MessageErrorType.serverError && 
            error.code.contains('UNAVAILABLE'));
  }

  /// Get user-friendly error message with context
  String getContextualErrorMessage(MessageError error, {String? context}) {
    String baseMessage = error.userFriendlyMessage;
    
    if (context != null) {
      switch (context) {
        case 'sending_message':
          baseMessage = 'Failed to send message: ${error.userFriendlyMessage}';
          break;
        case 'loading_messages':
          baseMessage = 'Failed to load messages: ${error.userFriendlyMessage}';
          break;
        case 'joining_conversation':
          baseMessage = 'Failed to join conversation: ${error.userFriendlyMessage}';
          break;
      }
    }

    if (error.isRetryable && error.retryAfter != null) {
      final seconds = error.retryAfter!.inSeconds;
      baseMessage += ' You can try again in $seconds seconds.';
    } else if (error.isRetryable) {
      baseMessage += ' Please try again.';
    }

    return baseMessage;
  }

  /// Clear error history
  void clearErrorHistory() {
    _recentErrors.clear();
    _errorCounts.clear();
  }

  /// Get error summary for analytics
  Map<String, dynamic> getErrorSummary() {
    return {
      'totalErrors': _recentErrors.length,
      'errorCounts': _errorCounts,
      'mostRecentError': _recentErrors.isNotEmpty ? _recentErrors.last.toString() : null,
      'retryableErrors': _recentErrors.where((e) => e.isRetryable).length,
      'networkErrors': _errorCounts[MessageErrorType.networkError] ?? 0,
      'serverErrors': _errorCounts[MessageErrorType.serverError] ?? 0,
    };
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _errorStreamController.close();
    _recentErrors.clear();
    _errorCounts.clear();
  }
}