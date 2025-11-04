// Request Deduplication Service - Prevents redundant API calls
// Comprehensive request management for TALOWA platform performance optimization

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

/// Service for deduplicating concurrent identical requests
class RequestDeduplicationService {
  static RequestDeduplicationService? _instance;
  static RequestDeduplicationService get instance => _instance ??= RequestDeduplicationService._internal();
  
  RequestDeduplicationService._internal();
  
  // Active request tracking
  final Map<String, Completer<dynamic>> _activeRequests = {};
  final Map<String, DateTime> _requestTimestamps = {};
  final Map<String, dynamic> _requestCache = {};
  
  // Configuration
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration cacheValidityDuration = Duration(minutes: 5);
  static const int maxConcurrentRequests = 50;
  
  /// Execute a request with deduplication
  Future<T> executeRequest<T>({
    required String requestId,
    required Future<T> Function() requestFunction,
    Duration? cacheValidity,
    bool useCache = true,
  }) async {
    try {
      final requestKey = _generateRequestKey(requestId);
      
      // Check cache first if enabled
      if (useCache) {
        final cachedResult = _getCachedResult<T>(requestKey);
        if (cachedResult != null) {
          debugPrint('🎯 Request cache hit: $requestId');
          return cachedResult;
        }
      }
      
      // Check if request is already in progress
      if (_activeRequests.containsKey(requestKey)) {
        debugPrint('🔄 Request deduplication: $requestId');
        return await _activeRequests[requestKey]!.future as T;
      }
      
      // Check concurrent request limit
      if (_activeRequests.length >= maxConcurrentRequests) {
        await _waitForRequestSlot();
      }
      
      // Create new request
      final completer = Completer<T>();
      _activeRequests[requestKey] = completer;
      _requestTimestamps[requestKey] = DateTime.now();
      
      debugPrint('🚀 Executing new request: $requestId');
      
      // Set up timeout
      final timeoutTimer = Timer(requestTimeout, () {
        if (!completer.isCompleted) {
          _cleanupRequest(requestKey);
          completer.completeError(TimeoutException('Request timeout', requestTimeout));
        }
      });
      
      try {
        // Execute the actual request
        final result = await requestFunction();
        
        // Cache the result if successful
        if (useCache) {
          _cacheResult(requestKey, result, cacheValidity ?? cacheValidityDuration);
        }
        
        // Complete the request
        if (!completer.isCompleted) {
          completer.complete(result);
        }
        
        debugPrint('✅ Request completed: $requestId');
        return result;
        
      } catch (error) {
        // Handle error
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        
        debugPrint('❌ Request failed: $requestId - $error');
        rethrow;
        
      } finally {
        // Cleanup
        timeoutTimer.cancel();
        _cleanupRequest(requestKey);
      }
      
    } catch (e) {
      debugPrint('💥 Request execution error: $requestId - $e');
      rethrow;
    }
  }
  
  /// Execute multiple requests with deduplication
  Future<List<T>> executeMultipleRequests<T>(
    List<RequestDefinition<T>> requests,
  ) async {
    try {
      debugPrint('🔀 Executing ${requests.length} requests with deduplication');
      
      final futures = requests.map((request) => executeRequest<T>(
        requestId: request.id,
        requestFunction: request.function,
        cacheValidity: request.cacheValidity,
        useCache: request.useCache,
      ));
      
      return await Future.wait(futures);
      
    } catch (e) {
      debugPrint('💥 Multiple request execution error: $e');
      rethrow;
    }
  }
  
  /// Cancel a specific request
  void cancelRequest(String requestId) {
    final requestKey = _generateRequestKey(requestId);
    
    if (_activeRequests.containsKey(requestKey)) {
      final completer = _activeRequests[requestKey]!;
      
      if (!completer.isCompleted) {
        completer.completeError(Exception('Request cancelled'));
      }
      
      _cleanupRequest(requestKey);
      debugPrint('🚫 Request cancelled: $requestId');
    }
  }
  
  /// Cancel all active requests
  void cancelAllRequests() {
    debugPrint('🚫 Cancelling all active requests: ${_activeRequests.length}');
    
    for (final entry in _activeRequests.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(Exception('All requests cancelled'));
      }
    }
    
    _activeRequests.clear();
    _requestTimestamps.clear();
  }
  
  /// Clear request cache
  void clearCache() {
    _requestCache.clear();
    debugPrint('🧹 Request cache cleared');
  }
  
  /// Get request statistics
  Map<String, dynamic> getStatistics() {
    final now = DateTime.now();
    final activeCount = _activeRequests.length;
    final cacheCount = _requestCache.length;
    
    // Calculate average request age
    double averageRequestAge = 0;
    if (_requestTimestamps.isNotEmpty) {
      final totalAge = _requestTimestamps.values
          .map((timestamp) => now.difference(timestamp).inMilliseconds)
          .reduce((a, b) => a + b);
      averageRequestAge = totalAge / _requestTimestamps.length;
    }
    
    return {
      'activeRequests': activeCount,
      'cachedResults': cacheCount,
      'averageRequestAgeMs': averageRequestAge.round(),
      'maxConcurrentRequests': maxConcurrentRequests,
      'requestTimeoutMs': requestTimeout.inMilliseconds,
    };
  }
  
  /// Generate unique request key
  String _generateRequestKey(String requestId) {
    final bytes = utf8.encode(requestId);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
  
  /// Get cached result if valid
  T? _getCachedResult<T>(String requestKey) {
    final cacheEntry = _requestCache[requestKey];
    if (cacheEntry == null) return null;
    
    final cachedAt = cacheEntry['timestamp'] as DateTime;
    final validUntil = cacheEntry['validUntil'] as DateTime;
    final now = DateTime.now();
    
    if (now.isAfter(validUntil)) {
      _requestCache.remove(requestKey);
      return null;
    }
    
    return cacheEntry['data'] as T;
  }
  
  /// Cache request result
  void _cacheResult<T>(String requestKey, T result, Duration validity) {
    final now = DateTime.now();
    
    _requestCache[requestKey] = {
      'data': result,
      'timestamp': now,
      'validUntil': now.add(validity),
    };
    
    // Cleanup old cache entries
    _cleanupExpiredCache();
  }
  
  /// Cleanup expired cache entries
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _requestCache.entries) {
      final validUntil = entry.value['validUntil'] as DateTime;
      if (now.isAfter(validUntil)) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _requestCache.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${keysToRemove.length} expired cache entries');
    }
  }
  
  /// Cleanup request tracking
  void _cleanupRequest(String requestKey) {
    _activeRequests.remove(requestKey);
    _requestTimestamps.remove(requestKey);
  }
  
  /// Wait for a request slot to become available
  Future<void> _waitForRequestSlot() async {
    while (_activeRequests.length >= maxConcurrentRequests) {
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Cleanup timed out requests
      final now = DateTime.now();
      final timedOutKeys = <String>[];
      
      for (final entry in _requestTimestamps.entries) {
        if (now.difference(entry.value) > requestTimeout) {
          timedOutKeys.add(entry.key);
        }
      }
      
      for (final key in timedOutKeys) {
        _cleanupRequest(key);
      }
    }
  }
  
  /// Dispose service resources
  void dispose() {
    cancelAllRequests();
    clearCache();
    debugPrint('🧹 RequestDeduplicationService disposed');
  }
}

/// Request definition for batch execution
class RequestDefinition<T> {
  final String id;
  final Future<T> Function() function;
  final Duration? cacheValidity;
  final bool useCache;
  
  const RequestDefinition({
    required this.id,
    required this.function,
    this.cacheValidity,
    this.useCache = true,
  });
}

/// Exception for request timeout
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;
  
  const TimeoutException(this.message, this.timeout);
  
  @override
  String toString() => 'TimeoutException: $message (${timeout.inSeconds}s)';
}