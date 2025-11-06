// Comprehensive Error Handler for TALOWA Messaging System
// Implements Task 8: Build comprehensive error handling and loading states
// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 10.4, 10.6

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_error_handler.dart';
import 'error_tracking_service.dart';

/// Comprehensive error handler with retry mechanisms and offline detection
class ComprehensiveErrorHandler {
  static final ComprehensiveErrorHandler _instance = ComprehensiveErrorHandler._internal();
  factory ComprehensiveErrorHandler() => _instance;
  ComprehensiveErrorHandler._internal();

  final MessageErrorHandler _messageErrorHandler = MessageErrorHandler();
  final ErrorTrackingService _errorTrackingService = ErrorTrackingService();
  
  // Network monitoring
  final StreamController<bool> _networkStatusController = StreamController<bool>.broadcast();
  final StreamController<NetworkQuality> _networkQualityController = StreamController<NetworkQuality>.broadcast();
  
  bool _isOnline = true;
  NetworkQuality _currentNetworkQuality = NetworkQuality.good;
  Timer? _networkCheckTimer;
  
  // Retry mechanisms
  final Map<String, RetryOperation> _retryOperations = {};
  final Map<String, Timer> _retryTimers = {};
  
  // Error statistics
  final Map<String, int> _errorCounts = {};
  final List<ErrorEvent> _recentErrors = [];
  
  // Getters
  Stream<bool> get networkStatusStream => _networkStatusController.stream;
  Stream<NetworkQuality> get networkQualityStream => _networkQualityController.stream;
  bool get isOnline => _isOnline;
  NetworkQuality get networkQuality => _currentNetworkQuality;

  /// Initialize comprehensive error handling
  Future<void> initialize() async {
    try {
      debugPrint('Initializing Comprehensive Error Handler...');
      
      // Initialize error tracking service
      await _errorTrackingService.initialize();
      
      // Start network monitoring
      await _startNetworkMonitoring();
      
      // Start periodic network quality checks
      _startNetworkQualityMonitoring();
      
      debugPrint('Comprehensive Error Handler initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Comprehensive Error Handler: $e');
      rethrow;
    }
  }

  /// Handle any error with comprehensive retry and recovery
  Future<T> handleOperation<T>(
    Future<T> Function() operation, {
    required String operationName,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    bool exponentialBackoff = true,
    bool requiresNetwork = true,
    Map<String, dynamic>? context,
  }) async {
    final operationId = '${operationName}_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      // Check network requirement
      if (requiresNetwork && !_isOnline) {
        throw NetworkException('Operation requires network connection but device is offline');
      }
      
      // Check network quality for critical operations
      if (requiresNetwork && _currentNetworkQuality == NetworkQuality.poor) {
        debugPrint('Warning: Attempting $operationName with poor network quality');
      }
      
      // Execute operation
      final result = await operation();
      
      // Track successful operation
      await _trackSuccessfulOperation(operationName, context);
      
      return result;
    } catch (error) {
      // Handle and classify error
      final messageError = _messageErrorHandler.handleError(error, context: context);
      
      // Track error
      await _trackError(operationName, messageError, context);
      
      // Determine if retry is appropriate
      if (messageError.isRetryable && maxRetries > 0) {
        return await _retryOperation(
          operation,
          operationId: operationId,
          operationName: operationName,
          error: messageError,
          maxRetries: maxRetries,
          currentAttempt: 1,
          initialDelay: initialDelay,
          exponentialBackoff: exponentialBackoff,
          requiresNetwork: requiresNetwork,
          context: context,
        );
      }
      
      // No retry possible, rethrow error
      rethrow;
    }
  }

  /// Retry operation with smart backoff
  Future<T> _retryOperation<T>(
    Future<T> Function() operation, {
    required String operationId,
    required String operationName,
    required MessageError error,
    required int maxRetries,
    required int currentAttempt,
    required Duration initialDelay,
    required bool exponentialBackoff,
    required bool requiresNetwork,
    Map<String, dynamic>? context,
  }) async {
    // Calculate delay
    Duration delay = initialDelay;
    if (exponentialBackoff) {
      delay = Duration(milliseconds: (initialDelay.inMilliseconds * (currentAttempt * currentAttempt)).clamp(1000, 30000));
    }
    
    // Use error-specific retry delay if available
    if (error.retryAfter != null) {
      delay = error.retryAfter!;
    }
    
    debugPrint('Retrying $operationName (attempt $currentAttempt/$maxRetries) after ${delay.inSeconds}s');
    
    // Store retry operation
    _retryOperations[operationId] = RetryOperation(
      operationName: operationName,
      currentAttempt: currentAttempt,
      maxRetries: maxRetries,
      nextRetryAt: DateTime.now().add(delay),
    );
    
    // Wait for retry delay
    await Future.delayed(delay);
    
    try {
      // Check network requirement again
      if (requiresNetwork && !_isOnline) {
        if (currentAttempt < maxRetries) {
          return await _retryOperation(
            operation,
            operationId: operationId,
            operationName: operationName,
            error: error,
            maxRetries: maxRetries,
            currentAttempt: currentAttempt + 1,
            initialDelay: initialDelay,
            exponentialBackoff: exponentialBackoff,
            requiresNetwork: requiresNetwork,
            context: context,
          );
        } else {
          throw NetworkException('Max retries exceeded while offline');
        }
      }
      
      // Execute operation
      final result = await operation();
      
      // Remove from retry operations
      _retryOperations.remove(operationId);
      
      // Track successful retry
      await _trackSuccessfulRetry(operationName, currentAttempt, context);
      
      return result;
    } catch (retryError) {
      final retryMessageError = _messageErrorHandler.handleError(retryError, context: context);
      
      // Track retry error
      await _trackRetryError(operationName, currentAttempt, retryMessageError, context);
      
      // Check if we should continue retrying
      if (retryMessageError.isRetryable && currentAttempt < maxRetries) {
        return await _retryOperation(
          operation,
          operationId: operationId,
          operationName: operationName,
          error: retryMessageError,
          maxRetries: maxRetries,
          currentAttempt: currentAttempt + 1,
          initialDelay: initialDelay,
          exponentialBackoff: exponentialBackoff,
          requiresNetwork: requiresNetwork,
          context: context,
        );
      }
      
      // Max retries exceeded
      _retryOperations.remove(operationId);
      throw MaxRetriesExceededException(
        'Operation $operationName failed after $currentAttempt attempts',
        originalError: retryError,
        attempts: currentAttempt,
      );
    }
  }

  /// Start network monitoring
  Future<void> _startNetworkMonitoring() async {
    // Check initial connectivity
    final initialResults = await Connectivity().checkConnectivity();
    _isOnline = initialResults.isNotEmpty && !initialResults.every((result) => result == ConnectivityResult.none);
    _networkStatusController.add(_isOnline);
    
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _isOnline = results.isNotEmpty && !results.every((result) => result == ConnectivityResult.none);
      
      if (wasOnline != _isOnline) {
        _networkStatusController.add(_isOnline);
        
        if (_isOnline) {
          debugPrint('Network connection restored');
          _onNetworkRestored();
        } else {
          debugPrint('Network connection lost');
          _onNetworkLost();
        }
      }
    });
  }

  /// Start network quality monitoring
  void _startNetworkQualityMonitoring() {
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkNetworkQuality();
    });
    
    // Initial quality check
    _checkNetworkQuality();
  }

  /// Check network quality
  Future<void> _checkNetworkQuality() async {
    if (!_isOnline) {
      _currentNetworkQuality = NetworkQuality.offline;
      _networkQualityController.add(_currentNetworkQuality);
      return;
    }
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Test with a small Firestore operation
      await FirebaseFirestore.instance
          .collection('_network_test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;
      
      // Classify network quality based on latency
      NetworkQuality newQuality;
      if (latency < 500) {
        newQuality = NetworkQuality.excellent;
      } else if (latency < 1000) {
        newQuality = NetworkQuality.good;
      } else if (latency < 2000) {
        newQuality = NetworkQuality.fair;
      } else {
        newQuality = NetworkQuality.poor;
      }
      
      if (newQuality != _currentNetworkQuality) {
        _currentNetworkQuality = newQuality;
        _networkQualityController.add(_currentNetworkQuality);
        debugPrint('Network quality changed to: $newQuality (${latency}ms)');
      }
    } catch (e) {
      _currentNetworkQuality = NetworkQuality.poor;
      _networkQualityController.add(_currentNetworkQuality);
      debugPrint('Network quality check failed: $e');
    }
  }

  /// Handle network restoration
  void _onNetworkRestored() {
    // Retry failed operations that are waiting
    final waitingOperations = _retryOperations.values
        .where((op) => DateTime.now().isAfter(op.nextRetryAt))
        .toList();
    
    debugPrint('Network restored, ${waitingOperations.length} operations waiting to retry');
    
    // Trigger immediate quality check
    _checkNetworkQuality();
  }

  /// Handle network loss
  void _onNetworkLost() {
    _currentNetworkQuality = NetworkQuality.offline;
    _networkQualityController.add(_currentNetworkQuality);
  }

  /// Track successful operation
  Future<void> _trackSuccessfulOperation(String operationName, Map<String, dynamic>? context) async {
    try {
      // Reset error count for this operation
      _errorCounts.remove(operationName);
      
      debugPrint('✅ Operation succeeded: $operationName');
    } catch (e) {
      debugPrint('Error tracking successful operation: $e');
    }
  }

  /// Track error
  Future<void> _trackError(String operationName, MessageError error, Map<String, dynamic>? context) async {
    try {
      // Update error count
      _errorCounts[operationName] = (_errorCounts[operationName] ?? 0) + 1;
      
      // Add to recent errors
      final errorEvent = ErrorEvent(
        operationName: operationName,
        error: error,
        timestamp: DateTime.now(),
        context: context,
      );
      
      _recentErrors.add(errorEvent);
      if (_recentErrors.length > 100) {
        _recentErrors.removeAt(0);
      }
      
      // Track in error tracking service
      await _errorTrackingService.trackError(
        errorType: error.type.toString(),
        errorMessage: error.message,
        severity: _getSeverityFromErrorType(error.type),
        component: 'messaging_system',
        context: {
          'operationName': operationName,
          'errorCode': error.code,
          'isRetryable': error.isRetryable,
          ...?context,
        },
      );
      
      debugPrint('❌ Operation failed: $operationName - ${error.userFriendlyMessage}');
    } catch (e) {
      debugPrint('Error tracking error: $e');
    }
  }

  /// Track successful retry
  Future<void> _trackSuccessfulRetry(String operationName, int attempt, Map<String, dynamic>? context) async {
    try {
      debugPrint('✅ Retry succeeded: $operationName (attempt $attempt)');
    } catch (e) {
      debugPrint('Error tracking successful retry: $e');
    }
  }

  /// Track retry error
  Future<void> _trackRetryError(String operationName, int attempt, MessageError error, Map<String, dynamic>? context) async {
    try {
      debugPrint('❌ Retry failed: $operationName (attempt $attempt) - ${error.userFriendlyMessage}');
    } catch (e) {
      debugPrint('Error tracking retry error: $e');
    }
  }

  /// Get severity from error type
  String _getSeverityFromErrorType(MessageErrorType type) {
    switch (type) {
      case MessageErrorType.networkError:
        return 'medium';
      case MessageErrorType.authenticationError:
        return 'high';
      case MessageErrorType.permissionError:
        return 'high';
      case MessageErrorType.rateLimitError:
        return 'medium';
      case MessageErrorType.serverError:
        return 'high';
      case MessageErrorType.validationError:
        return 'low';
      case MessageErrorType.storageError:
        return 'medium';
      case MessageErrorType.unknownError:
        return 'medium';
    }
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStatistics() {
    return {
      'totalErrors': _recentErrors.length,
      'errorsByOperation': Map.from(_errorCounts),
      'recentErrors': _recentErrors.take(10).map((e) => {
        'operation': e.operationName,
        'error': e.error.userFriendlyMessage,
        'timestamp': e.timestamp.toIso8601String(),
      }).toList(),
      'activeRetries': _retryOperations.length,
      'networkStatus': _isOnline ? 'online' : 'offline',
      'networkQuality': _currentNetworkQuality.toString(),
    };
  }

  /// Get retry operations status
  List<Map<String, dynamic>> getRetryOperationsStatus() {
    return _retryOperations.entries.map((entry) {
      final operation = entry.value;
      return {
        'id': entry.key,
        'operationName': operation.operationName,
        'currentAttempt': operation.currentAttempt,
        'maxRetries': operation.maxRetries,
        'nextRetryAt': operation.nextRetryAt.toIso8601String(),
        'timeUntilRetry': operation.nextRetryAt.difference(DateTime.now()).inSeconds,
      };
    }).toList();
  }

  /// Cancel retry operation
  void cancelRetryOperation(String operationId) {
    _retryOperations.remove(operationId);
    _retryTimers[operationId]?.cancel();
    _retryTimers.remove(operationId);
  }

  /// Dispose resources
  Future<void> dispose() async {
    _networkCheckTimer?.cancel();
    
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryOperations.clear();
    
    await _networkStatusController.close();
    await _networkQualityController.close();
  }
}

/// Network quality levels
enum NetworkQuality {
  offline,
  poor,
  fair,
  good,
  excellent,
}

/// Retry operation model
class RetryOperation {
  final String operationName;
  final int currentAttempt;
  final int maxRetries;
  final DateTime nextRetryAt;

  RetryOperation({
    required this.operationName,
    required this.currentAttempt,
    required this.maxRetries,
    required this.nextRetryAt,
  });
}

/// Error event model
class ErrorEvent {
  final String operationName;
  final MessageError error;
  final DateTime timestamp;
  final Map<String, dynamic>? context;

  ErrorEvent({
    required this.operationName,
    required this.error,
    required this.timestamp,
    this.context,
  });
}

/// Max retries exceeded exception
class MaxRetriesExceededException implements Exception {
  final String message;
  final dynamic originalError;
  final int attempts;

  MaxRetriesExceededException(
    this.message, {
    this.originalError,
    required this.attempts,
  });

  @override
  String toString() => 'MaxRetriesExceededException: $message (after $attempts attempts)';
}

/// Network exception
class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}