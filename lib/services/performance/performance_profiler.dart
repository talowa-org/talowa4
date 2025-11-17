// Performance Profiler Service
// Monitors and reports performance metrics

import 'package:flutter/foundation.dart';
import 'dart:async';

class PerformanceProfiler {
  static final PerformanceProfiler _instance = PerformanceProfiler._internal();
  factory PerformanceProfiler() => _instance;
  PerformanceProfiler._internal();

  static PerformanceProfiler get instance => _instance;

  final Map<String, List<int>> _operationTimes = {};
  final Map<String, int> _operationCounts = {};

  /// Start timing an operation
  Stopwatch startOperation(String operationName) {
    final stopwatch = Stopwatch()..start();
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
    return stopwatch;
  }

  /// End timing an operation and record the duration
  void endOperation(String operationName, Stopwatch stopwatch) {
    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds;

    if (!_operationTimes.containsKey(operationName)) {
      _operationTimes[operationName] = [];
    }
    _operationTimes[operationName]!.add(duration);

    // Log slow operations
    if (duration > 1000) {
      debugPrint('⚠️ SLOW OPERATION: $operationName took ${duration}ms');
    } else if (kDebugMode && duration > 500) {
      debugPrint('⚡ $operationName took ${duration}ms');
    }
  }

  /// Measure an async operation
  Future<T> measureAsync<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = startOperation(operationName);
    try {
      final result = await operation();
      endOperation(operationName, stopwatch);
      return result;
    } catch (e) {
      endOperation(operationName, stopwatch);
      rethrow;
    }
  }

  /// Measure a synchronous operation
  T measureSync<T>(
    String operationName,
    T Function() operation,
  ) {
    final stopwatch = startOperation(operationName);
    try {
      final result = operation();
      endOperation(operationName, stopwatch);
      return result;
    } catch (e) {
      endOperation(operationName, stopwatch);
      rethrow;
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{};

    for (final entry in _operationTimes.entries) {
      final times = entry.value;
      if (times.isEmpty) continue;

      final avg = times.reduce((a, b) => a + b) / times.length;
      final min = times.reduce((a, b) => a < b ? a : b);
      final max = times.reduce((a, b) => a > b ? a : b);
      final count = _operationCounts[entry.key] ?? 0;

      stats[entry.key] = {
        'count': count,
        'avgMs': avg.toStringAsFixed(2),
        'minMs': min,
        'maxMs': max,
        'totalMs': times.reduce((a, b) => a + b),
      };
    }

    return stats;
  }

  /// Print performance report
  void printReport() {
    if (!kDebugMode) return;

    debugPrint('\n========================================');
    debugPrint('📊 PERFORMANCE REPORT');
    debugPrint('========================================');

    final stats = getStatistics();
    if (stats.isEmpty) {
      debugPrint('No operations recorded');
      return;
    }

    for (final entry in stats.entries) {
      final data = entry.value as Map<String, dynamic>;
      debugPrint('\n${entry.key}:');
      debugPrint('  Count: ${data['count']}');
      debugPrint('  Avg: ${data['avgMs']}ms');
      debugPrint('  Min: ${data['minMs']}ms');
      debugPrint('  Max: ${data['maxMs']}ms');
      debugPrint('  Total: ${data['totalMs']}ms');
    }

    debugPrint('\n========================================\n');
  }

  /// Clear all statistics
  void clear() {
    _operationTimes.clear();
    _operationCounts.clear();
  }

  /// Get slow operations (> 1 second)
  List<String> getSlowOperations() {
    final slow = <String>[];
    
    for (final entry in _operationTimes.entries) {
      final times = entry.value;
      final avg = times.reduce((a, b) => a + b) / times.length;
      if (avg > 1000) {
        slow.add('${entry.key} (avg: ${avg.toStringAsFixed(0)}ms)');
      }
    }

    return slow;
  }

  /// Check if performance is healthy
  bool isPerformanceHealthy() {
    return getSlowOperations().isEmpty;
  }
}

/// Extension for easy performance measurement
extension PerformanceMeasurement on Future {
  Future<T> measure<T>(String operationName) async {
    return PerformanceProfiler.instance.measureAsync(
      operationName,
      () => this as Future<T>,
    );
  }
}
