// Retry Mechanism Service for TALOWA Messaging System
// Implements Task 8: Build comprehensive error handling and loading states
// Requirements: 7.3, 7.6, 10.4

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Service for handling retry mechanisms with smart backoff
class RetryMechanismService {
  static final RetryMechanismService _instance = RetryMechanismService._internal();
  factory RetryMechanismService() => _instance;
  RetryMechanismService._internal();

  final Map<String, RetryState> _activeRetries = {};
  final StreamController<RetryEvent> _retryEventController = StreamController<RetryEvent>.broadcast();

  Stream<RetryEvent> get retryEventStream => _retryEventController.stream;

  /// Execute operation with retry mechanism
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    required String operationId,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(minutes: 1),
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    final retryState = RetryState(
      operationId: operationId,
      maxRetries: maxRetries,
      currentAttempt: 0,
      startTime: DateTime.now(),
    );

    _activeRetries[operationId] = retryState;

    try {
      return await _attemptOperation(
        operation,
        retryState,
        initialDelay,
        backoffMultiplier,
        maxDelay,
        shouldRetry,
        onRetry,
      );
    } finally {
      _activeRetries.remove(operationId);
    }
  }

  Future<T> _attemptOperation<T>(
    Future<T> Function() operation,
    RetryState retryState,
    Duration initialDelay,
    double backoffMultiplier,
    Duration maxDelay,
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, dynamic error)? onRetry,
  ) async {
    while (retryState.currentAttempt <= retryState.maxRetries) {
      try {
        retryState.currentAttempt++;
        retryState.lastAttemptTime = DateTime.now();

        final result = await operation();
        
        // Success
        _retryEventController.add(RetryEvent(
          operationId: retryState.operationId,
          type: RetryEventType.success,
          attempt: retryState.currentAttempt,
          totalAttempts: retryState.maxRetries + 1,
        ));

        return result;
      } catch (error) {
        retryState.lastError = error;

        // Check if we should retry
        final shouldRetryOperation = shouldRetry?.call(error) ?? _defaultShouldRetry(error);
        
        if (!shouldRetryOperation || retryState.currentAttempt > retryState.maxRetries) {
          // Final failure
          _retryEventController.add(RetryEvent(
            operationId: retryState.operationId,
            type: RetryEventType.failed,
            attempt: retryState.currentAttempt,
            totalAttempts: retryState.maxRetries + 1,
            error: error,
          ));
          rethrow;
        }

        // Calculate delay for next retry
        final delay = _calculateDelay(
          retryState.currentAttempt - 1,
          initialDelay,
          backoffMultiplier,
          maxDelay,
        );

        // Notify about retry
        onRetry?.call(retryState.currentAttempt, error);
        
        _retryEventController.add(RetryEvent(
          operationId: retryState.operationId,
          type: RetryEventType.retrying,
          attempt: retryState.currentAttempt,
          totalAttempts: retryState.maxRetries + 1,
          error: error,
          retryDelay: delay,
        ));

        debugPrint('Retrying operation ${retryState.operationId} (attempt ${retryState.currentAttempt}/${retryState.maxRetries + 1}) after ${delay.inSeconds}s');

        // Wait before retry
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but just in case
    throw Exception('Retry mechanism failed unexpectedly');
  }

  /// Calculate delay with exponential backoff and jitter
  Duration _calculateDelay(
    int attemptNumber,
    Duration initialDelay,
    double backoffMultiplier,
    Duration maxDelay,
  ) {
    // Exponential backoff
    final exponentialDelay = initialDelay.inMilliseconds * pow(backoffMultiplier, attemptNumber);
    
    // Add jitter (±25%)
    final jitter = Random().nextDouble() * 0.5 - 0.25; // -0.25 to +0.25
    final delayWithJitter = exponentialDelay * (1 + jitter);
    
    // Clamp to max delay
    final finalDelay = Duration(milliseconds: delayWithJitter.round().clamp(
      initialDelay.inMilliseconds,
      maxDelay.inMilliseconds,
    ));

    return finalDelay;
  }

  /// Default retry logic
  bool _defaultShouldRetry(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Retry on network-related errors
    final retryableErrors = [
      'network',
      'timeout',
      'connection',
      'unavailable',
      'server error',
      'internal error',
      'service unavailable',
      'too many requests',
    ];

    return retryableErrors.any((retryableError) => errorString.contains(retryableError));
  }

  /// Get active retry operations
  List<RetryState> getActiveRetries() {
    return _activeRetries.values.toList();
  }

  /// Cancel retry operation
  void cancelRetry(String operationId) {
    _activeRetries.remove(operationId);
    
    _retryEventController.add(RetryEvent(
      operationId: operationId,
      type: RetryEventType.cancelled,
      attempt: 0,
      totalAttempts: 0,
    ));
  }

  /// Get retry statistics
  Map<String, dynamic> getRetryStatistics() {
    final activeRetries = _activeRetries.values.toList();
    
    return {
      'activeRetries': activeRetries.length,
      'operations': activeRetries.map((retry) => {
        'operationId': retry.operationId,
        'currentAttempt': retry.currentAttempt,
        'maxRetries': retry.maxRetries,
        'startTime': retry.startTime.toIso8601String(),
        'lastAttemptTime': retry.lastAttemptTime?.toIso8601String(),
        'lastError': retry.lastError?.toString(),
      }).toList(),
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    _activeRetries.clear();
    await _retryEventController.close();
  }
}

/// Retry state model
class RetryState {
  final String operationId;
  final int maxRetries;
  final DateTime startTime;
  
  int currentAttempt;
  DateTime? lastAttemptTime;
  dynamic lastError;

  RetryState({
    required this.operationId,
    required this.maxRetries,
    required this.startTime,
    this.currentAttempt = 0,
    this.lastAttemptTime,
    this.lastError,
  });
}

/// Retry event model
class RetryEvent {
  final String operationId;
  final RetryEventType type;
  final int attempt;
  final int totalAttempts;
  final dynamic error;
  final Duration? retryDelay;

  RetryEvent({
    required this.operationId,
    required this.type,
    required this.attempt,
    required this.totalAttempts,
    this.error,
    this.retryDelay,
  });
}

/// Retry event types
enum RetryEventType {
  retrying,
  success,
  failed,
  cancelled,
}

/// Specialized retry configurations
class RetryConfigurations {
  
  /// Configuration for message sending
  static const messageSending = RetryConfiguration(
    maxRetries: 3,
    initialDelay: Duration(seconds: 1),
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 30),
  );

  /// Configuration for voice calls
  static const voiceCalls = RetryConfiguration(
    maxRetries: 2,
    initialDelay: Duration(seconds: 2),
    backoffMultiplier: 1.5,
    maxDelay: Duration(seconds: 10),
  );

  /// Configuration for file uploads
  static const fileUploads = RetryConfiguration(
    maxRetries: 5,
    initialDelay: Duration(seconds: 2),
    backoffMultiplier: 2.0,
    maxDelay: Duration(minutes: 2),
  );

  /// Configuration for database operations
  static const databaseOperations = RetryConfiguration(
    maxRetries: 3,
    initialDelay: Duration(milliseconds: 500),
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 15),
  );

  /// Configuration for search operations
  static const searchOperations = RetryConfiguration(
    maxRetries: 2,
    initialDelay: Duration(seconds: 1),
    backoffMultiplier: 1.5,
    maxDelay: Duration(seconds: 5),
  );
}

/// Retry configuration model
class RetryConfiguration {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfiguration({
    required this.maxRetries,
    required this.initialDelay,
    required this.backoffMultiplier,
    required this.maxDelay,
  });
}