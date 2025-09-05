import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class LocalizationPerformanceMonitor {
  static final LocalizationPerformanceMonitor _instance = 
      LocalizationPerformanceMonitor._internal();
  factory LocalizationPerformanceMonitor() => _instance;
  LocalizationPerformanceMonitor._internal();

  final Map<String, DateTime> _startTimes = {};
  final Map<String, List<Duration>> _measurements = {};
  final Map<String, int> _memoryUsage = {};

  /// Start measuring a performance metric
  void startMeasurement(String key) {
    _startTimes[key] = DateTime.now();
  }

  /// End measuring and record the duration
  void endMeasurement(String key) {
    final startTime = _startTimes[key];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _measurements.putIfAbsent(key, () => []).add(duration);
      _startTimes.remove(key);
      
      if (kDebugMode) {
        developer.log('Performance: $key took ${duration.inMilliseconds}ms');
      }
    }
  }

  /// Record memory usage
  void recordMemoryUsage(String key, int bytes) {
    _memoryUsage[key] = bytes;
  }

  /// Get average duration for a metric
  Duration? getAverageDuration(String key) {
    final measurements = _measurements[key];
    if (measurements == null || measurements.isEmpty) return null;
    
    final totalMs = measurements
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs ~/ measurements.length);
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final entry in _measurements.entries) {
      final key = entry.key;
      final measurements = entry.value;
      
      if (measurements.isNotEmpty) {
        final durations = measurements.map((d) => d.inMilliseconds).toList();
        durations.sort();
        
        stats[key] = {
          'count': measurements.length,
          'average_ms': durations.reduce((a, b) => a + b) / durations.length,
          'min_ms': durations.first,
          'max_ms': durations.last,
          'median_ms': durations[durations.length ~/ 2],
        };
      }
    }
    
    stats['memory_usage'] = Map.from(_memoryUsage);
    return stats;
  }

  /// Clear all measurements
  void clearMeasurements() {
    _startTimes.clear();
    _measurements.clear();
    _memoryUsage.clear();
  }

  /// Create performance benchmark for language switching
  Future<Map<String, dynamic>> benchmarkLanguageSwitching({
    required Future<void> Function() switchFunction,
    int iterations = 10,
  }) async {
    final durations = <Duration>[];
    
    for (int i = 0; i < iterations; i++) {
      final stopwatch = Stopwatch()..start();
      await switchFunction();
      stopwatch.stop();
      durations.add(stopwatch.elapsed);
      
      // Small delay between iterations
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    durations.sort();
    final totalMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
    
    return {
      'iterations': iterations,
      'average_ms': totalMs / iterations,
      'min_ms': durations.first.inMilliseconds,
      'max_ms': durations.last.inMilliseconds,
      'median_ms': durations[durations.length ~/ 2].inMilliseconds,
      'total_ms': totalMs,
    };
  }

  /// Benchmark app startup time with different languages
  Future<Map<String, dynamic>> benchmarkStartupTime({
    required Future<void> Function(String languageCode) initFunction,
    required List<String> languageCodes,
  }) async {
    final results = <String, Map<String, dynamic>>{};
    
    for (final languageCode in languageCodes) {
      final durations = <Duration>[];
      
      // Run multiple iterations for each language
      for (int i = 0; i < 5; i++) {
        final stopwatch = Stopwatch()..start();
        await initFunction(languageCode);
        stopwatch.stop();
        durations.add(stopwatch.elapsed);
        
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      durations.sort();
      final totalMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
      
      results[languageCode] = {
        'average_ms': totalMs / durations.length,
        'min_ms': durations.first.inMilliseconds,
        'max_ms': durations.last.inMilliseconds,
        'median_ms': durations[durations.length ~/ 2].inMilliseconds,
      };
    }
    
    return results;
  }

  /// Monitor memory usage during language operations
  void startMemoryMonitoring() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      // In a real implementation, you would measure actual memory usage
      // This is a placeholder for demonstration
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      recordMemoryUsage('memory_$timestamp', 0); // Placeholder value
    });
  }
}
