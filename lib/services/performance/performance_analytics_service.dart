// Performance Analytics Service for TALOWA
// Tracks and analyzes app performance metrics with real-time monitoring

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Performance alert levels
enum AlertLevel { info, warning, critical }

/// Performance alert model
class PerformanceAlert {
  final String id;
  final String metric;
  final double value;
  final double threshold;
  final AlertLevel level;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  PerformanceAlert({
    required this.id,
    required this.metric,
    required this.value,
    required this.threshold,
    required this.level,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'metric': metric,
    'value': value,
    'threshold': threshold,
    'level': level.toString(),
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
}

/// Real-time performance metrics model
class RealTimeMetrics {
  final double responseTime;
  final double errorRate;
  final int activeUsers;
  final double memoryUsage;
  final double cpuUsage;
  final double networkLatency;
  final double cacheHitRate;
  final DateTime timestamp;

  RealTimeMetrics({
    required this.responseTime,
    required this.errorRate,
    required this.activeUsers,
    required this.memoryUsage,
    required this.cpuUsage,
    required this.networkLatency,
    required this.cacheHitRate,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'responseTime': responseTime,
    'errorRate': errorRate,
    'activeUsers': activeUsers,
    'memoryUsage': memoryUsage,
    'cpuUsage': cpuUsage,
    'networkLatency': networkLatency,
    'cacheHitRate': cacheHitRate,
    'timestamp': timestamp.toIso8601String(),
  };
}

class PerformanceAnalyticsService {
  static final PerformanceAnalyticsService _instance = PerformanceAnalyticsService._internal();
  factory PerformanceAnalyticsService() => _instance;
  PerformanceAnalyticsService._internal();

  static bool _isInitialized = false;
  static final Map<String, dynamic> _performanceMetrics = {};
  static final Map<String, List<double>> _performanceHistory = {};
  static final List<PerformanceAlert> _alerts = [];
  static Timer? _metricsCollectionTimer;
  static Timer? _alertingTimer;
  static Timer? _realTimeMonitoringTimer;
  static DateTime? _appLaunchTime;
  static final StreamController<RealTimeMetrics> _metricsStreamController = StreamController<RealTimeMetrics>.broadcast();
  static final StreamController<PerformanceAlert> _alertStreamController = StreamController<PerformanceAlert>.broadcast();

  // Performance thresholds for 10M user scalability
  static const Map<String, double> _thresholds = {
    'response_time_ms': 2000.0,      // 2 seconds max
    'error_rate_percent': 5.0,       // 5% max error rate
    'memory_usage_mb': 512.0,        // 512MB max
    'cpu_usage_percent': 80.0,       // 80% max
    'network_latency_ms': 1000.0,    // 1 second max
    'cache_hit_rate_percent': 70.0,  // 70% min cache hit rate
    'frame_drop_rate_percent': 2.0,  // 2% max frame drops
    'database_query_ms': 500.0,      // 500ms max query time
  };

  // Metrics collection counters
  static int _totalRequests = 0;
  static int _errorCount = 0;
  static int _cacheHits = 0;
  static int _cacheMisses = 0;
  static final List<double> _responseTimes = [];
  static final List<double> _queryTimes = [];

  /// Get real-time metrics stream
  static Stream<RealTimeMetrics> get metricsStream => _metricsStreamController.stream;

  /// Get alerts stream
  static Stream<PerformanceAlert> get alertStream => _alertStreamController.stream;

  /// Start app launch performance tracking
  static void startAppLaunch() {
    _appLaunchTime = DateTime.now();
    debugPrint('🚀 App launch performance tracking started');
  }

  /// Complete app launch tracking
  static void completeAppLaunch() {
    if (_appLaunchTime != null) {
      final launchDuration = DateTime.now().difference(_appLaunchTime!);
      debugPrint('App launch completed in ${launchDuration.inMilliseconds}ms');
      
      // Record the launch time metric
      recordMetric('app_launch_time', launchDuration.inMilliseconds.toDouble());
      
      _appLaunchTime = null;
    }
  }

  /// Initialize performance analytics with enhanced monitoring
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _appLaunchTime = DateTime.now();
      
      // Start performance monitoring
      _startPerformanceMonitoring();
      
      // Initialize metrics collection
      _initializeMetricsCollection();
      
      // Start real-time monitoring
      _startRealTimeMonitoring();
      
      // Start alerting system
      _startAlertingSystem();
      
      _isInitialized = true;
      debugPrint('🚀 Enhanced PerformanceAnalyticsService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing PerformanceAnalyticsService: $e');
      rethrow;
    }
  }

  /// Start real-time monitoring
  static void _startRealTimeMonitoring() {
    _realTimeMonitoringTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _collectRealTimeMetrics();
    });
  }

  /// Start alerting system
  static void _startAlertingSystem() {
    _alertingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkPerformanceThresholds();
    });
  }

  /// Collect real-time metrics
  static void _collectRealTimeMetrics() {
    try {
      final metrics = RealTimeMetrics(
        responseTime: _calculateAverageResponseTime(),
        errorRate: _calculateErrorRate(),
        activeUsers: _getActiveUserCount(),
        memoryUsage: _getCurrentMemoryUsage(),
        cpuUsage: _getCurrentCpuUsage(),
        networkLatency: _calculateNetworkLatency(),
        cacheHitRate: _calculateCacheHitRate(),
        timestamp: DateTime.now(),
      );

      _metricsStreamController.add(metrics);
      
      // Store metrics for historical analysis
      _storeMetricsHistory(metrics);
      
    } catch (e) {
      debugPrint('Error collecting real-time metrics: $e');
    }
  }

  /// Check performance thresholds and generate alerts
  static void _checkPerformanceThresholds() {
    final currentMetrics = {
      'response_time_ms': _calculateAverageResponseTime(),
      'error_rate_percent': _calculateErrorRate() * 100,
      'memory_usage_mb': _getCurrentMemoryUsage(),
      'cpu_usage_percent': _getCurrentCpuUsage(),
      'network_latency_ms': _calculateNetworkLatency(),
      'cache_hit_rate_percent': _calculateCacheHitRate() * 100,
      'database_query_ms': _calculateAverageQueryTime(),
    };

    for (final entry in currentMetrics.entries) {
      final metric = entry.key;
      final value = entry.value;
      final threshold = _thresholds[metric];

      if (threshold != null) {
        AlertLevel? alertLevel;
        
        // Determine alert level based on metric type and value
        if (metric == 'cache_hit_rate_percent') {
          // For cache hit rate, lower is worse
          if (value < threshold * 0.5) {
            alertLevel = AlertLevel.critical;
          } else if (value < threshold * 0.8) alertLevel = AlertLevel.warning;
        } else {
          // For other metrics, higher is worse
          if (value > threshold * 2) {
            alertLevel = AlertLevel.critical;
          } else if (value > threshold * 1.5) alertLevel = AlertLevel.warning;
          else if (value > threshold) alertLevel = AlertLevel.info;
        }

        if (alertLevel != null) {
          _generateAlert(metric, value, threshold, alertLevel);
        }
      }
    }
  }

  /// Generate performance alert
  static void _generateAlert(String metric, double value, double threshold, AlertLevel level) {
    final alert = PerformanceAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      metric: metric,
      value: value,
      threshold: threshold,
      level: level,
      timestamp: DateTime.now(),
      metadata: {
        'app_version': '1.0.0', // This should come from app config
        'platform': Platform.operatingSystem,
        'user_count': _getActiveUserCount(),
      },
    );

    _alerts.add(alert);
    _alertStreamController.add(alert);

    // Keep only last 100 alerts
    if (_alerts.length > 100) {
      _alerts.removeAt(0);
    }

    // Log critical alerts
    if (level == AlertLevel.critical) {
      debugPrint('🚨 CRITICAL ALERT: $metric = $value (threshold: $threshold)');
    }

    // Store alert in Firestore for persistence
    _storeAlert(alert);
  }

  /// Store alert in Firestore
  static void _storeAlert(PerformanceAlert alert) async {
    try {
      await FirebaseFirestore.instance
          .collection('performance_alerts')
          .add(alert.toMap());
    } catch (e) {
      debugPrint('Error storing alert: $e');
    }
  }

  /// Store metrics history
  static void _storeMetricsHistory(RealTimeMetrics metrics) {
    _performanceHistory['response_time'] ??= [];
    _performanceHistory['error_rate'] ??= [];
    _performanceHistory['memory_usage'] ??= [];
    _performanceHistory['cpu_usage'] ??= [];
    _performanceHistory['network_latency'] ??= [];
    _performanceHistory['cache_hit_rate'] ??= [];

    _performanceHistory['response_time']!.add(metrics.responseTime);
    _performanceHistory['error_rate']!.add(metrics.errorRate);
    _performanceHistory['memory_usage']!.add(metrics.memoryUsage);
    _performanceHistory['cpu_usage']!.add(metrics.cpuUsage);
    _performanceHistory['network_latency']!.add(metrics.networkLatency);
    _performanceHistory['cache_hit_rate']!.add(metrics.cacheHitRate);

    // Keep only last 1000 entries for each metric
    for (final key in _performanceHistory.keys) {
      final history = _performanceHistory[key]!;
      if (history.length > 1000) {
        history.removeRange(0, history.length - 1000);
      }
    }
  }

  /// Record network request performance
  static void recordNetworkRequest({
    required String endpoint,
    required int durationMs,
    required bool success,
    int? statusCode,
  }) {
    _totalRequests++;
    if (!success) _errorCount++;
    
    _responseTimes.add(durationMs.toDouble());
    if (_responseTimes.length > 1000) {
      _responseTimes.removeAt(0);
    }

    _recordMetric('network_${endpoint}_duration', durationMs);
    _recordMetric('network_${endpoint}_success', success);
    if (statusCode != null) {
      _recordMetric('network_${endpoint}_status', statusCode);
    }
    
    _addToHistory('network_requests', durationMs.toDouble());
  }

  /// Record database query performance
  static void recordDatabaseQuery({
    required String collection,
    required String operation,
    required int durationMs,
    required bool success,
  }) {
    _queryTimes.add(durationMs.toDouble());
    if (_queryTimes.length > 1000) {
      _queryTimes.removeAt(0);
    }

    _recordMetric('db_${collection}_${operation}_duration', durationMs);
    _recordMetric('db_${collection}_${operation}_success', success);
    
    _addToHistory('database_queries', durationMs.toDouble());
  }

  /// Record cache performance
  static void recordCacheHit(String key) {
    _cacheHits++;
    _recordMetric('cache_hit_$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Record cache miss
  static void recordCacheMiss(String key) {
    _cacheMisses++;
    _recordMetric('cache_miss_$key', DateTime.now().millisecondsSinceEpoch);
  }

  // Performance calculation methods
  static double _calculateAverageResponseTime() {
    if (_responseTimes.isEmpty) return 0.0;
    return _responseTimes.reduce((a, b) => a + b) / _responseTimes.length;
  }

  static double _calculateErrorRate() {
    if (_totalRequests == 0) return 0.0;
    return _errorCount / _totalRequests;
  }

  static double _calculateCacheHitRate() {
    final total = _cacheHits + _cacheMisses;
    if (total == 0) return 0.0;
    return _cacheHits / total;
  }

  static double _calculateAverageQueryTime() {
    if (_queryTimes.isEmpty) return 0.0;
    return _queryTimes.reduce((a, b) => a + b) / _queryTimes.length;
  }

  static double _calculateNetworkLatency() {
    // This would be implemented with actual network latency measurement
    return _calculateAverageResponseTime() * 0.3; // Estimate
  }

  static int _getActiveUserCount() {
    // This would be implemented with actual user tracking
    return 1; // Placeholder
  }

  static double _getCurrentMemoryUsage() {
    // Platform-specific memory usage would be implemented here
    return _estimateMemoryUsage().toDouble();
  }

  static double _getCurrentCpuUsage() {
    // Platform-specific CPU usage would be implemented here
    return 25.0; // Placeholder
  }

  /// Record a metric internally
  static void _recordMetric(String key, dynamic value) {
    _performanceMetrics[key] = value;
    _performanceMetrics['${key}_timestamp'] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Record a metric (public method)
  static void recordMetric(String key, dynamic value) {
    _recordMetric(key, value);
  }

  /// Start performance monitoring
  static void _startPerformanceMonitoring() {
    debugPrint('🔍 Starting performance monitoring');
    // Initialize monitoring timers and collectors
  }

  /// Initialize metrics collection
  static void _initializeMetricsCollection() {
    debugPrint('📊 Initializing metrics collection');
    // Set up metrics collection infrastructure
  }

  /// Estimate memory usage
  static int _estimateMemoryUsage() {
    // This is a simplified estimation
    // In a real implementation, you would use platform-specific APIs
    return 128; // MB placeholder
  }

  /// Add value to performance history
  static void _addToHistory(String category, double value) {
    final history = _performanceHistory[category] ?? [];
    history.add(value);
    
    // Keep only last 1000 entries
    if (history.length > 1000) {
      history.removeAt(0);
    }
    
    _performanceHistory[category] = history;
  }

  /// Get performance metrics
  static Map<String, dynamic> getPerformanceMetrics() {
    return Map.from(_performanceMetrics);
  }

  /// Get performance history
  static Map<String, List<double>> getPerformanceHistory() {
    return Map.from(_performanceHistory);
  }

  /// Get current alerts
  static List<PerformanceAlert> getCurrentAlerts() {
    return List.from(_alerts);
  }

  /// Get performance summary with enhanced analytics
  static Map<String, dynamic> getPerformanceSummary() {
    final summary = <String, dynamic>{};
    
    for (final category in _performanceHistory.keys) {
      final values = _performanceHistory[category]!;
      if (values.isNotEmpty) {
        summary['${category}_avg'] = values.reduce((a, b) => a + b) / values.length;
        summary['${category}_min'] = values.reduce((a, b) => a < b ? a : b);
        summary['${category}_max'] = values.reduce((a, b) => a > b ? a : b);
        summary['${category}_count'] = values.length;
        summary['${category}_p95'] = _calculatePercentile(values, 0.95);
        summary['${category}_p99'] = _calculatePercentile(values, 0.99);
      }
    }

    // Add real-time metrics
    summary['real_time'] = {
      'response_time': _calculateAverageResponseTime(),
      'error_rate': _calculateErrorRate(),
      'cache_hit_rate': _calculateCacheHitRate(),
      'active_alerts': _alerts.length,
      'total_requests': _totalRequests,
    };
    
    return summary;
  }

  /// Calculate percentile for performance analysis
  static double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    
    final sorted = List<double>.from(values)..sort();
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index];
  }

  /// Export comprehensive performance data
  static Map<String, dynamic> exportPerformanceData() {
    return {
      'metrics': getPerformanceMetrics(),
      'history': getPerformanceHistory(),
      'summary': getPerformanceSummary(),
      'alerts': _alerts.map((alert) => alert.toMap()).toList(),
      'thresholds': _thresholds,
      'export_timestamp': DateTime.now().millisecondsSinceEpoch,
      'app_info': {
        'platform': Platform.operatingSystem,
        'version': '1.0.0', // This should come from app config
        'uptime_ms': _appLaunchTime != null 
            ? DateTime.now().difference(_appLaunchTime!).inMilliseconds 
            : 0,
      },
    };
  }

  /// Dispose resources
  static void dispose() {
    _metricsCollectionTimer?.cancel();
    _alertingTimer?.cancel();
    _realTimeMonitoringTimer?.cancel();
    _metricsStreamController.close();
    _alertStreamController.close();
    _performanceMetrics.clear();
    _performanceHistory.clear();
    _alerts.clear();
    _responseTimes.clear();
    _queryTimes.clear();
    _totalRequests = 0;
    _errorCount = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _isInitialized = false;
    debugPrint('Enhanced PerformanceAnalyticsService disposed');
  }

  /// Track login performance
  static void trackLoginPerformance({
    required int duration,
    String? userId,
    String? method,
    bool? success,
  }) {
    print('🔍 Tracking login performance: ${duration}ms');
    
    // Record the metric
    recordMetric('login_performance', duration.toDouble());
    recordMetric('login_user_id', userId ?? 'unknown');
    recordMetric('login_method', method ?? 'unknown');
    recordMetric('login_success', success ?? false);
    
    // Add to performance history
    _addToHistory('login_performance', duration.toDouble());
  }

  /// Track tab navigation performance
  static void trackTabNavigation({
    required String tabName,
    required int duration,
    String? fromTab,
    bool? success,
  }) {
    print('📱 Tracking tab navigation: $tabName - ${duration}ms');
    
    // Record the metric
    recordMetric('tab_navigation_performance', duration.toDouble());
    recordMetric('tab_navigation_name', tabName);
    recordMetric('tab_navigation_from', fromTab ?? 'unknown');
    recordMetric('tab_navigation_success', success ?? true);
    
    // Add to performance history
    _addToHistory('tab_navigation_performance', duration.toDouble());
  }

  /// Track network tab loading performance
  static void trackNetworkTabLoading({
    required int duration,
    String? section,
    String? networkType,
    bool? success,
  }) {
    print('🌐 Tracking network tab loading: ${duration}ms');
    
    // Record the metric
    recordMetric('network_tab_loading_performance', duration.toDouble());
    recordMetric('network_tab_section', section ?? 'unknown');
    recordMetric('network_tab_type', networkType ?? 'unknown');
    recordMetric('network_tab_success', success ?? true);
    
    // Add to performance history
    _addToHistory('network_tab_loading_performance', duration.toDouble());
  }

  /// Track navigation performance
  static void trackNavigationPerformance({
    required String route,
    required int duration,
    String? fromRoute,
    bool? success,
  }) {
    print('🧭 Tracking navigation performance: $route - ${duration}ms');
    
    // Record the metric
    recordMetric('navigation_performance', duration.toDouble());
    recordMetric('navigation_route', route);
    recordMetric('navigation_from_route', fromRoute ?? 'unknown');
    recordMetric('navigation_success', success ?? true);
    
    // Add to performance history
    _addToHistory('navigation_performance', duration.toDouble());
  }
}