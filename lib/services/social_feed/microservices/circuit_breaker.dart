// Circuit Breaker - Microservices Resilience Pattern
// Prevents cascading failures and provides graceful degradation
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Circuit breaker states
enum CircuitBreakerState {
  closed,    // Normal operation
  open,      // Failing fast
  halfOpen,  // Testing recovery
}

/// Circuit breaker configuration
class CircuitBreakerConfig {
  final int failureThreshold;
  final Duration recoveryTimeout;
  final Duration monitoringWindow;
  final double successThreshold;

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.recoveryTimeout = const Duration(seconds: 30),
    this.monitoringWindow = const Duration(minutes: 2),
    this.successThreshold = 0.5,
  });
}

/// Circuit breaker exception
class CircuitBreakerException implements Exception {
  final String message;
  final CircuitBreakerState state;

  CircuitBreakerException(this.message, this.state);

  @override
  String toString() => 'CircuitBreakerException: $message (State: ${state.name})';
}

/// Circuit breaker for service resilience
class CircuitBreaker {
  final CircuitBreakerConfig _config;
  
  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  int _requestCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _lastStateChange;
  Timer? _recoveryTimer;

  // Metrics tracking
  final List<bool> _recentResults = [];
  final StreamController<CircuitBreakerState> _stateController = 
      StreamController<CircuitBreakerState>.broadcast();

  CircuitBreaker({
    int failureThreshold = 5,
    Duration recoveryTimeout = const Duration(seconds: 30),
    Duration monitoringWindow = const Duration(minutes: 2),
    double successThreshold = 0.5,
  }) : _config = CircuitBreakerConfig(
         failureThreshold: failureThreshold,
         recoveryTimeout: recoveryTimeout,
         monitoringWindow: monitoringWindow,
         successThreshold: successThreshold,
       ) {
    _lastStateChange = DateTime.now();
  }

  /// Current circuit breaker state
  CircuitBreakerState get state => _state;

  /// Stream of state changes
  Stream<CircuitBreakerState> get stateChanges => _stateController.stream;

  /// Execute a function with circuit breaker protection
  Future<T> execute<T>(Future<T> Function() operation) async {
    // Check if circuit is open
    if (_state == CircuitBreakerState.open) {
      if (_shouldAttemptReset()) {
        _transitionToHalfOpen();
      } else {
        throw CircuitBreakerException(
          'Circuit breaker is OPEN - failing fast',
          _state,
        );
      }
    }

    // Execute operation
    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (error) {
      _onFailure();
      rethrow;
    }
  }

  /// Execute with fallback function
  Future<T> executeWithFallback<T>(
    Future<T> Function() operation,
    Future<T> Function() fallback,
  ) async {
    try {
      return await execute(operation);
    } catch (error) {
      if (error is CircuitBreakerException) {
        debugPrint('🔄 Circuit breaker triggered, using fallback');
        return await fallback();
      }
      rethrow;
    }
  }

  /// Execute with timeout
  Future<T> executeWithTimeout<T>(
    Future<T> Function() operation,
    Duration timeout,
  ) async {
    return await execute(() async {
      return await operation().timeout(timeout);
    });
  }

  /// Handle successful operation
  void _onSuccess() {
    _requestCount++;
    _successCount++;
    _recentResults.add(true);
    _cleanupOldResults();

    if (_state == CircuitBreakerState.halfOpen) {
      // Check if we should close the circuit
      final recentSuccessRate = _calculateRecentSuccessRate();
      if (recentSuccessRate >= _config.successThreshold) {
        _transitionToClosed();
      }
    }
  }

  /// Handle failed operation
  void _onFailure() {
    _requestCount++;
    _failureCount++;
    _lastFailureTime = DateTime.now();
    _recentResults.add(false);
    _cleanupOldResults();

    if (_state == CircuitBreakerState.closed) {
      // Check if we should open the circuit
      if (_failureCount >= _config.failureThreshold) {
        _transitionToOpen();
      }
    } else if (_state == CircuitBreakerState.halfOpen) {
      // Any failure in half-open state should open the circuit
      _transitionToOpen();
    }
  }

  /// Check if we should attempt to reset the circuit
  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return false;
    
    final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
    return timeSinceLastFailure >= _config.recoveryTimeout;
  }

  /// Transition to CLOSED state
  void _transitionToClosed() {
    if (_state == CircuitBreakerState.closed) return;

    _state = CircuitBreakerState.closed;
    _lastStateChange = DateTime.now();
    _failureCount = 0;
    _successCount = 0;
    _recoveryTimer?.cancel();
    
    debugPrint('🟢 Circuit breaker CLOSED - normal operation resumed');
    _stateController.add(_state);
  }

  /// Transition to OPEN state
  void _transitionToOpen() {
    if (_state == CircuitBreakerState.open) return;

    _state = CircuitBreakerState.open;
    _lastStateChange = DateTime.now();
    
    // Set recovery timer
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(_config.recoveryTimeout, () {
      if (_state == CircuitBreakerState.open) {
        _transitionToHalfOpen();
      }
    });
    
    debugPrint('🔴 Circuit breaker OPEN - failing fast');
    _stateController.add(_state);
  }

  /// Transition to HALF-OPEN state
  void _transitionToHalfOpen() {
    if (_state == CircuitBreakerState.halfOpen) return;

    _state = CircuitBreakerState.halfOpen;
    _lastStateChange = DateTime.now();
    _successCount = 0;
    _recoveryTimer?.cancel();
    
    debugPrint('🟡 Circuit breaker HALF-OPEN - testing recovery');
    _stateController.add(_state);
  }

  /// Calculate recent success rate
  double _calculateRecentSuccessRate() {
    if (_recentResults.isEmpty) return 0.0;
    
    final successCount = _recentResults.where((result) => result).length;
    return successCount / _recentResults.length;
  }

  /// Clean up old results outside monitoring window
  void _cleanupOldResults() {
    final maxResults = 100; // Keep last 100 results
    if (_recentResults.length > maxResults) {
      _recentResults.removeRange(0, _recentResults.length - maxResults);
    }
  }

  /// Get circuit breaker metrics
  Map<String, dynamic> getMetrics() {
    final now = DateTime.now();
    final uptime = _lastStateChange != null 
        ? now.difference(_lastStateChange!).inSeconds 
        : 0;

    return {
      'state': _state.name,
      'failureCount': _failureCount,
      'successCount': _successCount,
      'requestCount': _requestCount,
      'successRate': _requestCount > 0 ? _successCount / _requestCount : 0.0,
      'recentSuccessRate': _calculateRecentSuccessRate(),
      'uptime': uptime,
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'lastStateChange': _lastStateChange?.toIso8601String(),
      'config': {
        'failureThreshold': _config.failureThreshold,
        'recoveryTimeout': _config.recoveryTimeout.inSeconds,
        'monitoringWindow': _config.monitoringWindow.inSeconds,
        'successThreshold': _config.successThreshold,
      },
    };
  }

  /// Reset circuit breaker to initial state
  void reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _successCount = 0;
    _requestCount = 0;
    _lastFailureTime = null;
    _lastStateChange = DateTime.now();
    _recentResults.clear();
    _recoveryTimer?.cancel();
    
    debugPrint('🔄 Circuit breaker reset');
    _stateController.add(_state);
  }

  /// Manually open the circuit
  void open() {
    _transitionToOpen();
  }

  /// Manually close the circuit
  void close() {
    _transitionToClosed();
  }

  /// Dispose resources
  void dispose() {
    _recoveryTimer?.cancel();
    _stateController.close();
  }
}