import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Performance monitoring service for real-time tracking and alerting
class PerformanceMonitoringService {
  static PerformanceMonitoringService? _instance;
  static PerformanceMonitoringService get instance => _instance ??= PerformanceMonitoringService._();
  
  PerformanceMonitoringService._();
  
  final Map<String, List<double>> _metrics = {};
  final Map<String, DateTime> _lastMetricTime = {};
  final List<PerformanceAlert> _alerts = [];
  Timer? _monitoringTimer;
  
  // Performance thresholds for 10M user scalability
  static const Map<String, double> _thresholds = {
    'api_response_time': 2000.0, // 2 seconds max
    'feed_load_time': 3000.0, // 3 seconds max
    'memory_usage_mb': 512.0, // 512MB max
    'cpu_usage_percent': 80.0, // 80% max
    'network_error_rate': 5.0, // 5% max error rate
    'cache_hit_rate': 70.0, // 70% min cache hit rate
    'frame_drop_rate': 2.0, // 2% max frame drops
  };
  
  /// Initialize performance monitoring
  void initialize() {
    debugPrint('🔍 Initializing PerformanceMonitoringService');
    
    // Start continuous monitoring
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _collectSystemMetrics();
      _checkThresholds();
    });
    
    // Initialize metric collections
    for (final key in _thresholds.keys) {
      _metrics[key] = [];
    }
    
    debugPrint('✅ PerformanceMonitoringService initialized');
  }
  
  /// Start monitoring an operation
  void startOperation(String operationName, {Map<String, dynamic>? metadata}) {
    try {
      final startTime = DateTime.now();
      _lastMetricTime[operationName] = startTime;
      
      debugPrint('🚀 Started operation: $operationName');
      
      if (metadata != null) {
        debugPrint('📊 Operation metadata: $metadata');
      }
    } catch (e) {
      debugPrint('❌ Error starting operation $operationName: $e');
    }
  }
  
  /// Complete monitoring an operation and record its duration
  void completeOperation(String operationName, {bool success = true, Map<String, dynamic>? metadata}) {
    try {
      final endTime = DateTime.now();
      final startTime = _lastMetricTime[operationName];
      
      if (startTime != null) {
        final duration = endTime.difference(startTime).inMilliseconds.toDouble();
        recordMetric('${operationName}_duration', duration, metadata: metadata);
        
        debugPrint('✅ Completed operation: $operationName (${duration}ms)');
        
        // Remove from tracking
        _lastMetricTime.remove(operationName);
      } else {
        debugPrint('⚠️ No start time found for operation: $operationName');
      }
    } catch (e) {
      debugPrint('❌ Error completing operation $operationName: $e');
    }
  }
  
  /// Record a performance metric
  void recordMetric(String metricName, double value, {Map<String, dynamic>? metadata}) {
    try {
      if (!_metrics.containsKey(metricName)) {
        _metrics[metricName] = [];
      }
      
      _metrics[metricName]!.add(value);
      _lastMetricTime[metricName] = DateTime.now();
      
      // Keep only last 100 measurements to prevent memory bloat
      if (_metrics[metricName]!.length > 100) {
        _metrics[metricName]!.removeAt(0);
      }
      
      // Check for immediate threshold violations
      if (_thresholds.containsKey(metricName)) {
        final threshold = _thresholds[metricName]!;
        final isViolation = _isThresholdViolation(metricName, value, threshold);
        
        if (isViolation) {
          _createAlert(metricName, value, threshold, metadata);
        }
      }
      
      debugPrint('📊 Recorded metric $metricName: $value');
    } catch (e) {
      debugPrint('❌ Failed to record metric $metricName: $e');
    }
  }
  
  /// Record API response time
  void recordApiResponseTime(String endpoint, Duration responseTime, {int? statusCode}) {
    final timeMs = responseTime.inMilliseconds.toDouble();
    recordMetric('api_response_time', timeMs, metadata: {
      'endpoint': endpoint,
      'status_code': statusCode,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Track error rates
    if (statusCode != null && statusCode >= 400) {
      recordMetric('network_error_rate', 1.0, metadata: {
        'endpoint': endpoint,
        'status_code': statusCode,
      });
    } else {
      recordMetric('network_error_rate', 0.0);
    }
  }
  
  /// Record feed loading performance
  void recordFeedLoadTime(Duration loadTime, int postCount, {String? feedType}) {
    final timeMs = loadTime.inMilliseconds.toDouble();
    recordMetric('feed_load_time', timeMs, metadata: {
      'post_count': postCount,
      'feed_type': feedType ?? 'general',
      'posts_per_second': postCount / (timeMs / 1000),
    });
  }
  
  /// Record cache performance
  void recordCacheHit(bool isHit, String cacheType) {
    recordMetric('cache_hit_rate', isHit ? 100.0 : 0.0, metadata: {
      'cache_type': cacheType,
      'is_hit': isHit,
    });
  }
  
  /// Record frame performance
  void recordFrameMetrics(double frameTime, bool wasDropped) {
    recordMetric('frame_time', frameTime);
    recordMetric('frame_drop_rate', wasDropped ? 100.0 : 0.0);
  }
  
  /// Get current performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final entry in _metrics.entries) {
      final metricName = entry.key;
      final values = entry.value;
      
      if (values.isNotEmpty) {
        stats[metricName] = {
          'current': values.last,
          'average': values.reduce((a, b) => a + b) / values.length,
          'min': values.reduce((a, b) => a < b ? a : b),
          'max': values.reduce((a, b) => a > b ? a : b),
          'count': values.length,
          'threshold': _thresholds[metricName],
          'last_updated': _lastMetricTime[metricName]?.toIso8601String(),
        };
      }
    }
    
    stats['alerts'] = _alerts.map((alert) => alert.toMap()).toList();
    stats['system_info'] = _getSystemInfo();
    
    return stats;
  }
  
  /// Get performance health score (0-100)
  double getHealthScore() {
    double totalScore = 0.0;
    int metricCount = 0;
    
    for (final entry in _metrics.entries) {
      final metricName = entry.key;
      final values = entry.value;
      final threshold = _thresholds[metricName];
      
      if (values.isNotEmpty && threshold != null) {
        final currentValue = values.last;
        final score = _calculateMetricScore(metricName, currentValue, threshold);
        totalScore += score;
        metricCount++;
      }
    }
    
    return metricCount > 0 ? totalScore / metricCount : 100.0;
  }
  
  /// Export performance data for analysis
  String exportPerformanceData() {
    final data = {
      'export_timestamp': DateTime.now().toIso8601String(),
      'metrics': _metrics,
      'thresholds': _thresholds,
      'alerts': _alerts.map((alert) => alert.toMap()).toList(),
      'health_score': getHealthScore(),
      'system_info': _getSystemInfo(),
    };
    
    return jsonEncode(data);
  }
  
  /// Clear old performance data
  void clearOldData({Duration maxAge = const Duration(hours: 24)}) {
    final cutoffTime = DateTime.now().subtract(maxAge);
    
    // Clear old alerts
    _alerts.removeWhere((alert) => alert.timestamp.isBefore(cutoffTime));
    
    // Clear old metrics (keep recent ones)
    for (final key in _metrics.keys) {
      if (_metrics[key]!.length > 50) {
        _metrics[key] = _metrics[key]!.sublist(_metrics[key]!.length - 50);
      }
    }
    
    debugPrint('🧹 Cleared old performance data');
  }
  
  /// Collect system metrics
  void _collectSystemMetrics() {
    try {
      // Memory usage (approximation)
      if (kDebugMode) {
        // In debug mode, we can estimate memory usage
        recordMetric('memory_usage_mb', _estimateMemoryUsage());
      }
      
      // Calculate cache hit rates
      _calculateCacheHitRates();
      
      // Calculate error rates
      _calculateErrorRates();
      
    } catch (e) {
      debugPrint('❌ Failed to collect system metrics: $e');
    }
  }
  
  /// Estimate memory usage (rough approximation)
  double _estimateMemoryUsage() {
    // This is a rough estimation - in production you'd use platform-specific APIs
    return 128.0; // Placeholder value
  }
  
  /// Calculate cache hit rates from recent metrics
  void _calculateCacheHitRates() {
    final cacheMetrics = _metrics['cache_hit_rate'];
    if (cacheMetrics != null && cacheMetrics.isNotEmpty) {
      final recentMetrics = cacheMetrics.length > 10 
          ? cacheMetrics.sublist(cacheMetrics.length - 10)
          : cacheMetrics;
      
      final hitRate = recentMetrics.reduce((a, b) => a + b) / recentMetrics.length;
      recordMetric('cache_hit_rate', hitRate);
    }
  }
  
  /// Calculate error rates from recent metrics
  void _calculateErrorRates() {
    final errorMetrics = _metrics['network_error_rate'];
    if (errorMetrics != null && errorMetrics.isNotEmpty) {
      final recentMetrics = errorMetrics.length > 20 
          ? errorMetrics.sublist(errorMetrics.length - 20)
          : errorMetrics;
      
      final errorRate = (recentMetrics.where((x) => x > 0).length / recentMetrics.length) * 100;
      recordMetric('network_error_rate', errorRate);
    }
  }
  
  /// Check all thresholds and create alerts
  void _checkThresholds() {
    for (final entry in _metrics.entries) {
      final metricName = entry.key;
      final values = entry.value;
      final threshold = _thresholds[metricName];
      
      if (values.isNotEmpty && threshold != null) {
        final currentValue = values.last;
        if (_isThresholdViolation(metricName, currentValue, threshold)) {
          _createAlert(metricName, currentValue, threshold);
        }
      }
    }
  }
  
  /// Check if a value violates the threshold
  bool _isThresholdViolation(String metricName, double value, double threshold) {
    switch (metricName) {
      case 'cache_hit_rate':
        return value < threshold; // Cache hit rate should be above threshold
      default:
        return value > threshold; // Most metrics should be below threshold
    }
  }
  
  /// Calculate performance score for a metric (0-100)
  double _calculateMetricScore(String metricName, double value, double threshold) {
    switch (metricName) {
      case 'cache_hit_rate':
        return value >= threshold ? 100.0 : (value / threshold) * 100.0;
      default:
        return value <= threshold ? 100.0 : Math.max(0.0, 100.0 - ((value - threshold) / threshold) * 100.0);
    }
  }
  
  /// Create a performance alert
  void _createAlert(String metricName, double value, double threshold, [Map<String, dynamic>? metadata]) {
    final alert = PerformanceAlert(
      metricName: metricName,
      currentValue: value,
      threshold: threshold,
      severity: _getAlertSeverity(metricName, value, threshold),
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    
    _alerts.add(alert);
    
    // Keep only last 100 alerts
    if (_alerts.length > 100) {
      _alerts.removeAt(0);
    }
    
    debugPrint('🚨 Performance alert: ${alert.toString()}');
  }
  
  /// Determine alert severity
  AlertSeverity _getAlertSeverity(String metricName, double value, double threshold) {
    final ratio = value / threshold;
    
    if (metricName == 'cache_hit_rate') {
      // For cache hit rate, lower is worse
      if (value < threshold * 0.5) return AlertSeverity.critical;
      if (value < threshold * 0.7) return AlertSeverity.high;
      return AlertSeverity.medium;
    } else {
      // For other metrics, higher is worse
      if (ratio > 2.0) return AlertSeverity.critical;
      if (ratio > 1.5) return AlertSeverity.high;
      return AlertSeverity.medium;
    }
  }
  
  /// Get system information
  Map<String, dynamic> _getSystemInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'dart_version': Platform.version,
      'is_debug': kDebugMode,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Dispose of the monitoring service
  void dispose() {
    _monitoringTimer?.cancel();
    _metrics.clear();
    _alerts.clear();
    debugPrint('🧹 PerformanceMonitoringService disposed');
  }
}

/// Performance alert class
class PerformanceAlert {
  final String metricName;
  final double currentValue;
  final double threshold;
  final AlertSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  
  PerformanceAlert({
    required this.metricName,
    required this.currentValue,
    required this.threshold,
    required this.severity,
    required this.timestamp,
    this.metadata,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'metric_name': metricName,
      'current_value': currentValue,
      'threshold': threshold,
      'severity': severity.name,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  @override
  String toString() {
    return 'Alert: $metricName = $currentValue (threshold: $threshold) - ${severity.name}';
  }
}

/// Alert severity levels
enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

/// Math utility class
class Math {
  static double max(double a, double b) => a > b ? a : b;
  static double min(double a, double b) => a < b ? a : b;
}

/// Extension to add missing methods to PerformanceMonitoringService
extension PerformanceMonitoringServiceExtensions on PerformanceMonitoringService {
  /// End an operation and record its duration
  void endOperation(String operationId) {
    debugPrint('⏱️ Ending operation: $operationId');
    // TODO: Implement operation tracking logic
  }

  /// Record an error with context
  void recordError(String errorType, String errorMessage, {Map<String, dynamic>? context}) {
    debugPrint('❌ Recording error - Type: $errorType, Message: $errorMessage');
    if (context != null) {
      debugPrint('📋 Error context: $context');
    }
    // TODO: Implement error recording logic
  }

  /// Record a metric with double value
  void recordMetric(String metricName, double value, {Map<String, String>? tags}) {
    debugPrint('📊 Recording metric - $metricName: $value');
    if (tags != null) {
      debugPrint('🏷️ Metric tags: $tags');
    }
    // TODO: Implement metric recording logic
  }
}