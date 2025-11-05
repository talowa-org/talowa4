import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Advanced scalability monitoring service for 10M DAU support
class ScalabilityMonitor {
  static ScalabilityMonitor? _instance;
  static ScalabilityMonitor get instance => _instance ??= ScalabilityMonitor._();

  ScalabilityMonitor._();

  // Performance tracking
  final Map<String, List<PerformanceMetric>> _metrics = {};
  final Map<String, ScalabilityAlert> _activeAlerts = {};
  Timer? _monitoringTimer;
  Timer? _alertTimer;

  // Scalability thresholds for 10M DAU
  static const Map<String, ScalabilityThreshold> _thresholds = {
    'concurrent_users': ScalabilityThreshold(
      warning: 300000,
      critical: 380000,
      maximum: 400000,
    ),
    'api_response_time_ms': ScalabilityThreshold(
      warning: 1500,
      critical: 2000,
      maximum: 3000,
    ),
    'database_query_time_ms': ScalabilityThreshold(
      warning: 400,
      critical: 500,
      maximum: 1000,
    ),
    'memory_usage_mb': ScalabilityThreshold(
      warning: 400,
      critical: 500,
      maximum: 600,
    ),
    'error_rate_percent': ScalabilityThreshold(
      warning: 0.5,
      critical: 1.0,
      maximum: 2.0,
    ),
    'cache_hit_rate_percent': ScalabilityThreshold(
      warning: 70,
      critical: 60,
      maximum: 50,
    ),
  };

  /// Initialize scalability monitoring
  Future<void> initialize() async {
    try {
      debugPrint('🔍 Initializing ScalabilityMonitor for 10M DAU support');
      
      // Start continuous monitoring every 10 seconds
      _monitoringTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _collectScalabilityMetrics();
      });
      
      // Start alert checking every 30 seconds
      _alertTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _checkScalabilityAlerts();
      });
      
      // Initialize metric collections
      for (final key in _thresholds.keys) {
        _metrics[key] = [];
      }
      
      debugPrint('✅ ScalabilityMonitor initialized for 10M DAU capacity');
    } catch (e) {
      debugPrint('❌ Failed to initialize ScalabilityMonitor: $e');
      rethrow;
    }
  }

  /// Record scalability metric
  void recordMetric(String metricName, double value, {Map<String, dynamic>? context}) {
    try {
      final metric = PerformanceMetric(
        name: metricName,
        value: value,
        timestamp: DateTime.now(),
        context: context ?? {},
      );

      if (!_metrics.containsKey(metricName)) {
        _metrics[metricName] = [];
      }

      _metrics[metricName]!.add(metric);

      // Keep only last 1000 measurements to prevent memory bloat
      if (_metrics[metricName]!.length > 1000) {
        _metrics[metricName]!.removeAt(0);
      }

      // Check for immediate threshold violations
      _checkThresholdViolation(metricName, value, context);

      if (kDebugMode && value > (_thresholds[metricName]?.warning ?? double.infinity)) {
        debugPrint('⚠️ Scalability warning: $metricName = $value');
      }
    } catch (e) {
      debugPrint('❌ Failed to record scalability metric $metricName: $e');
    }
  }

  /// Record concurrent user count
  void recordConcurrentUsers(int userCount) {
    recordMetric('concurrent_users', userCount.toDouble(), context: {
      'timestamp': DateTime.now().toIso8601String(),
      'capacity_utilization': (userCount / 400000) * 100, // 400K max capacity
    });
  }

  /// Record API performance
  void recordApiPerformance(String endpoint, Duration responseTime, {int? statusCode}) {
    final timeMs = responseTime.inMilliseconds.toDouble();
    recordMetric('api_response_time_ms', timeMs, context: {
      'endpoint': endpoint,
      'status_code': statusCode,
      'is_slow': timeMs > 1000,
    });

    // Track error rates
    if (statusCode != null && statusCode >= 400) {
      recordMetric('error_rate_percent', 100.0, context: {
        'endpoint': endpoint,
        'status_code': statusCode,
        'error_type': _getErrorType(statusCode),
      });
    } else {
      recordMetric('error_rate_percent', 0.0);
    }
  }

  /// Record database query performance
  void recordDatabaseQuery(String queryType, Duration queryTime, {int? resultCount}) {
    final timeMs = queryTime.inMilliseconds.toDouble();
    recordMetric('database_query_time_ms', timeMs, context: {
      'query_type': queryType,
      'result_count': resultCount,
      'is_slow': timeMs > 500,
      'efficiency_score': _calculateQueryEfficiency(timeMs, resultCount),
    });
  }

  /// Record memory usage
  void recordMemoryUsage(double memoryMb) {
    recordMetric('memory_usage_mb', memoryMb, context: {
      'memory_pressure': _getMemoryPressure(memoryMb),
      'gc_recommended': memoryMb > 400,
    });
  }

  /// Record cache performance
  void recordCachePerformance(bool isHit, String cacheType, {Duration? accessTime}) {
    recordMetric('cache_hit_rate_percent', isHit ? 100.0 : 0.0, context: {
      'cache_type': cacheType,
      'access_time_ms': accessTime?.inMilliseconds,
      'is_hit': isHit,
    });
  }

  /// Get current scalability status
  ScalabilityStatus getScalabilityStatus() {
    final status = ScalabilityStatus();
    
    for (final entry in _metrics.entries) {
      final metricName = entry.key;
      final metrics = entry.value;
      final threshold = _thresholds[metricName];
      
      if (metrics.isNotEmpty && threshold != null) {
        final currentValue = metrics.last.value;
        final avgValue = metrics.map((m) => m.value).reduce((a, b) => a + b) / metrics.length;
        
        status.metrics[metricName] = ScalabilityMetricStatus(
          current: currentValue,
          average: avgValue,
          threshold: threshold,
          status: _getMetricStatus(metricName, currentValue, threshold),
          trend: _calculateTrend(metrics),
        );
      }
    }
    
    status.overallHealth = _calculateOverallHealth(status.metrics);
    status.activeAlerts = _activeAlerts.values.toList();
    status.capacityUtilization = _calculateCapacityUtilization();
    
    return status;
  }

  /// Get performance recommendations for scaling
  List<ScalabilityRecommendation> getScalabilityRecommendations() {
    final recommendations = <ScalabilityRecommendation>[];
    final status = getScalabilityStatus();
    
    // Check concurrent users
    final userMetric = status.metrics['concurrent_users'];
    if (userMetric != null && userMetric.current > 300000) {
      recommendations.add(ScalabilityRecommendation(
        type: RecommendationType.scaling,
        priority: RecommendationPriority.high,
        title: 'High Concurrent User Load',
        description: 'Approaching maximum capacity of 400K concurrent users',
        action: 'Consider implementing horizontal scaling or load balancing',
        impact: 'Prevents system overload and maintains performance',
      ));
    }
    
    // Check API response times
    final apiMetric = status.metrics['api_response_time_ms'];
    if (apiMetric != null && apiMetric.average > 1000) {
      recommendations.add(ScalabilityRecommendation(
        type: RecommendationType.optimization,
        priority: RecommendationPriority.medium,
        title: 'Slow API Response Times',
        description: 'Average API response time is ${apiMetric.average.toInt()}ms',
        action: 'Optimize database queries and implement better caching',
        impact: 'Improves user experience and reduces server load',
      ));
    }
    
    // Check cache hit rates
    final cacheMetric = status.metrics['cache_hit_rate_percent'];
    if (cacheMetric != null && cacheMetric.average < 70) {
      recommendations.add(ScalabilityRecommendation(
        type: RecommendationType.caching,
        priority: RecommendationPriority.medium,
        title: 'Low Cache Hit Rate',
        description: 'Cache hit rate is ${cacheMetric.average.toInt()}%',
        action: 'Review caching strategy and increase cache size',
        impact: 'Reduces database load and improves response times',
      ));
    }
    
    // Check memory usage
    final memoryMetric = status.metrics['memory_usage_mb'];
    if (memoryMetric != null && memoryMetric.current > 400) {
      recommendations.add(ScalabilityRecommendation(
        type: RecommendationType.memory,
        priority: RecommendationPriority.high,
        title: 'High Memory Usage',
        description: 'Memory usage is ${memoryMetric.current.toInt()}MB',
        action: 'Implement memory optimization and garbage collection',
        impact: 'Prevents memory leaks and improves stability',
      ));
    }
    
    return recommendations;
  }

  /// Export scalability report
  Map<String, dynamic> exportScalabilityReport() {
    final status = getScalabilityStatus();
    final recommendations = getScalabilityRecommendations();
    
    return {
      'report_timestamp': DateTime.now().toIso8601String(),
      'scalability_target': '10M DAU (400K concurrent users)',
      'current_status': {
        'overall_health': status.overallHealth,
        'capacity_utilization': status.capacityUtilization,
        'active_alerts': status.activeAlerts.length,
      },
      'metrics': status.metrics.map((key, value) => MapEntry(key, {
        'current': value.current,
        'average': value.average,
        'status': value.status.toString(),
        'trend': value.trend.toString(),
        'threshold_warning': value.threshold.warning,
        'threshold_critical': value.threshold.critical,
      })),
      'recommendations': recommendations.map((r) => {
        'type': r.type.toString(),
        'priority': r.priority.toString(),
        'title': r.title,
        'description': r.description,
        'action': r.action,
        'impact': r.impact,
      }).toList(),
      'performance_summary': {
        'can_handle_10m_dau': status.overallHealth > 0.8,
        'estimated_max_concurrent_users': _estimateMaxConcurrentUsers(),
        'bottlenecks': _identifyBottlenecks(status),
        'optimization_priority': _getOptimizationPriority(recommendations),
      },
    };
  }

  /// Collect scalability metrics
  void _collectScalabilityMetrics() {
    try {
      // Simulate metric collection (in production, these would be real metrics)
      final random = math.Random();
      
      // Simulate concurrent users (gradually increasing)
      final baseUsers = 50000 + (DateTime.now().millisecondsSinceEpoch % 300000);
      recordConcurrentUsers(baseUsers);
      
      // Simulate API response times
      final apiTime = 800 + random.nextInt(1200); // 800-2000ms
      recordApiPerformance('/api/feed', Duration(milliseconds: apiTime));
      
      // Simulate database query times
      final dbTime = 200 + random.nextInt(600); // 200-800ms
      recordDatabaseQuery('feed_query', Duration(milliseconds: dbTime), resultCount: 20);
      
      // Simulate memory usage
      final memoryUsage = 200 + random.nextInt(300); // 200-500MB
      recordMemoryUsage(memoryUsage.toDouble());
      
      // Simulate cache performance
      final cacheHit = random.nextBool();
      recordCachePerformance(cacheHit, 'feed_cache');
      
    } catch (e) {
      debugPrint('❌ Failed to collect scalability metrics: $e');
    }
  }

  /// Check for scalability alerts
  void _checkScalabilityAlerts() {
    for (final entry in _metrics.entries) {
      final metricName = entry.key;
      final metrics = entry.value;
      final threshold = _thresholds[metricName];
      
      if (metrics.isNotEmpty && threshold != null) {
        final currentValue = metrics.last.value;
        _checkThresholdViolation(metricName, currentValue, {});
      }
    }
  }

  /// Check threshold violation and create alerts
  void _checkThresholdViolation(String metricName, double value, Map<String, dynamic>? context) {
    final threshold = _thresholds[metricName];
    if (threshold == null) return;
    
    AlertLevel? alertLevel;
    
    if (_isThresholdViolation(metricName, value, threshold.critical)) {
      alertLevel = AlertLevel.critical;
    } else if (_isThresholdViolation(metricName, value, threshold.warning)) {
      alertLevel = AlertLevel.warning;
    }
    
    if (alertLevel != null) {
      final alertKey = '${metricName}_${alertLevel.name}';
      
      if (!_activeAlerts.containsKey(alertKey)) {
        _activeAlerts[alertKey] = ScalabilityAlert(
          metricName: metricName,
          currentValue: value,
          threshold: alertLevel == AlertLevel.critical ? threshold.critical : threshold.warning,
          level: alertLevel,
          timestamp: DateTime.now(),
          context: context ?? {},
        );
        
        debugPrint('🚨 Scalability alert: $metricName = $value (${alertLevel.name})');
      }
    } else {
      // Remove resolved alerts
      _activeAlerts.removeWhere((key, alert) => 
          alert.metricName == metricName && 
          !_isThresholdViolation(metricName, value, alert.threshold));
    }
  }

  /// Check if value violates threshold
  bool _isThresholdViolation(String metricName, double value, double threshold) {
    switch (metricName) {
      case 'cache_hit_rate_percent':
        return value < threshold; // Cache hit rate should be above threshold
      default:
        return value > threshold; // Most metrics should be below threshold
    }
  }

  /// Calculate overall health score (0.0 to 1.0)
  double _calculateOverallHealth(Map<String, ScalabilityMetricStatus> metrics) {
    if (metrics.isEmpty) return 1.0;
    
    double totalScore = 0.0;
    int metricCount = 0;
    
    for (final metric in metrics.values) {
      totalScore += _getMetricHealthScore(metric);
      metricCount++;
    }
    
    return metricCount > 0 ? totalScore / metricCount : 1.0;
  }

  /// Get health score for individual metric
  double _getMetricHealthScore(ScalabilityMetricStatus metric) {
    switch (metric.status) {
      case MetricStatus.healthy:
        return 1.0;
      case MetricStatus.warning:
        return 0.6;
      case MetricStatus.critical:
        return 0.2;
    }
  }

  /// Calculate capacity utilization
  double _calculateCapacityUtilization() {
    final userMetrics = _metrics['concurrent_users'];
    if (userMetrics == null || userMetrics.isEmpty) return 0.0;
    
    final currentUsers = userMetrics.last.value;
    return (currentUsers / 400000) * 100; // 400K max capacity
  }

  /// Calculate trend for metrics
  MetricTrend _calculateTrend(List<PerformanceMetric> metrics) {
    if (metrics.length < 10) return MetricTrend.stable;
    
    final recent = metrics.sublist(metrics.length - 10);
    final older = metrics.sublist(metrics.length - 20, metrics.length - 10);
    
    final recentAvg = recent.map((m) => m.value).reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.map((m) => m.value).reduce((a, b) => a + b) / older.length;
    
    final change = (recentAvg - olderAvg) / olderAvg;
    
    if (change > 0.1) return MetricTrend.increasing;
    if (change < -0.1) return MetricTrend.decreasing;
    return MetricTrend.stable;
  }

  /// Get metric status based on thresholds
  MetricStatus _getMetricStatus(String metricName, double value, ScalabilityThreshold threshold) {
    if (_isThresholdViolation(metricName, value, threshold.critical)) {
      return MetricStatus.critical;
    } else if (_isThresholdViolation(metricName, value, threshold.warning)) {
      return MetricStatus.warning;
    }
    return MetricStatus.healthy;
  }

  /// Helper methods
  String _getErrorType(int statusCode) {
    if (statusCode >= 500) return 'server_error';
    if (statusCode >= 400) return 'client_error';
    return 'unknown';
  }

  double _calculateQueryEfficiency(double timeMs, int? resultCount) {
    if (resultCount == null || resultCount == 0) return 0.0;
    return resultCount / (timeMs / 1000); // Results per second
  }

  String _getMemoryPressure(double memoryMb) {
    if (memoryMb > 500) return 'high';
    if (memoryMb > 300) return 'medium';
    return 'low';
  }

  int _estimateMaxConcurrentUsers() {
    final status = getScalabilityStatus();
    final health = status.overallHealth;
    
    if (health > 0.9) return 400000; // Full capacity
    if (health > 0.8) return 350000;
    if (health > 0.6) return 250000;
    return 150000; // Needs optimization
  }

  List<String> _identifyBottlenecks(ScalabilityStatus status) {
    final bottlenecks = <String>[];
    
    for (final entry in status.metrics.entries) {
      if (entry.value.status == MetricStatus.critical) {
        bottlenecks.add(entry.key);
      }
    }
    
    return bottlenecks;
  }

  String _getOptimizationPriority(List<ScalabilityRecommendation> recommendations) {
    final highPriority = recommendations.where((r) => r.priority == RecommendationPriority.high).length;
    
    if (highPriority > 2) return 'urgent';
    if (highPriority > 0) return 'high';
    return 'medium';
  }

  /// Dispose resources
  void dispose() {
    _monitoringTimer?.cancel();
    _alertTimer?.cancel();
    _metrics.clear();
    _activeAlerts.clear();
    debugPrint('🔄 ScalabilityMonitor disposed');
  }
}

/// Data classes for scalability monitoring

class PerformanceMetric {
  final String name;
  final double value;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  PerformanceMetric({
    required this.name,
    required this.value,
    required this.timestamp,
    required this.context,
  });
}

class ScalabilityThreshold {
  final double warning;
  final double critical;
  final double maximum;

  const ScalabilityThreshold({
    required this.warning,
    required this.critical,
    required this.maximum,
  });
}

class ScalabilityStatus {
  Map<String, ScalabilityMetricStatus> metrics = {};
  double overallHealth = 1.0;
  double capacityUtilization = 0.0;
  List<ScalabilityAlert> activeAlerts = [];
}

class ScalabilityMetricStatus {
  final double current;
  final double average;
  final ScalabilityThreshold threshold;
  final MetricStatus status;
  final MetricTrend trend;

  ScalabilityMetricStatus({
    required this.current,
    required this.average,
    required this.threshold,
    required this.status,
    required this.trend,
  });
}

class ScalabilityAlert {
  final String metricName;
  final double currentValue;
  final double threshold;
  final AlertLevel level;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  ScalabilityAlert({
    required this.metricName,
    required this.currentValue,
    required this.threshold,
    required this.level,
    required this.timestamp,
    required this.context,
  });
}

class ScalabilityRecommendation {
  final RecommendationType type;
  final RecommendationPriority priority;
  final String title;
  final String description;
  final String action;
  final String impact;

  ScalabilityRecommendation({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.action,
    required this.impact,
  });
}

enum MetricStatus { healthy, warning, critical }
enum MetricTrend { increasing, stable, decreasing }
enum AlertLevel { warning, critical }
enum RecommendationType { scaling, optimization, caching, memory }
enum RecommendationPriority { low, medium, high, urgent }