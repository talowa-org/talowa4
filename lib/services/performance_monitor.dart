import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Performance monitoring service for scalability insights
class PerformanceMonitor {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, List<double>> _responseTimeCache = {};
  static final Map<String, int> _operationCounts = {};
  
  /// Track operation performance
  static Future<T> trackOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      stopwatch.stop();
      
      _recordPerformance(operationName, stopwatch.elapsedMilliseconds.toDouble(), true);
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordPerformance(operationName, stopwatch.elapsedMilliseconds.toDouble(), false);
      rethrow;
    }
  }
  
  /// Record performance metrics
  static void _recordPerformance(String operation, double responseTime, bool success) {
    // Cache response times
    _responseTimeCache[operation] ??= [];
    _responseTimeCache[operation]!.add(responseTime);
    
    // Keep only last 100 measurements
    if (_responseTimeCache[operation]!.length > 100) {
      _responseTimeCache[operation]!.removeAt(0);
    }
    
    // Count operations
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
    
    // Log slow operations
    if (responseTime > 2000) { // 2 seconds
      debugPrint('SLOW OPERATION: $operation took ${responseTime}ms');
    }
    
    // Batch upload metrics every 100 operations
    if (_operationCounts[operation]! % 100 == 0) {
      _uploadMetrics(operation);
    }
  }
  
  /// Upload metrics to Firestore for analysis
  static Future<void> _uploadMetrics(String operation) async {
    try {
      final times = _responseTimeCache[operation] ?? [];
      if (times.isEmpty) return;
      
      final avgTime = times.reduce((a, b) => a + b) / times.length;
      final maxTime = times.reduce((a, b) => a > b ? a : b);
      final minTime = times.reduce((a, b) => a < b ? a : b);
      
      await _firestore.collection('performance_metrics').add({
        'operation': operation,
        'timestamp': FieldValue.serverTimestamp(),
        'avgResponseTime': avgTime,
        'maxResponseTime': maxTime,
        'minResponseTime': minTime,
        'sampleSize': times.length,
        'platform': kIsWeb ? 'web' : 'mobile',
      });
      
      debugPrint('Uploaded metrics for $operation: avg=${avgTime.toInt()}ms');
    } catch (e) {
      debugPrint('Error uploading metrics: $e');
    }
  }
  
  /// Get current performance stats
  static Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final operation in _responseTimeCache.keys) {
      final times = _responseTimeCache[operation]!;
      if (times.isNotEmpty) {
        stats[operation] = {
          'avgTime': times.reduce((a, b) => a + b) / times.length,
          'maxTime': times.reduce((a, b) => a > b ? a : b),
          'minTime': times.reduce((a, b) => a < b ? a : b),
          'count': _operationCounts[operation] ?? 0,
        };
      }
    }
    
    return stats;
  }
  
  /// Monitor memory usage
  static void logMemoryUsage(String context) {
    // This would integrate with platform-specific memory monitoring
    debugPrint('Memory check at $context: ${DateTime.now()}');
  }
  
  /// Check system health
  static Map<String, dynamic> getSystemHealth() {
    return {
      'cacheSize': _responseTimeCache.length,
      'totalOperations': _operationCounts.values.fold(0, (a, b) => a + b),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}