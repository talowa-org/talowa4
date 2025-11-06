import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'performance_monitoring_service.dart';

/// Performance Monitoring Service for Talowa
/// Collects and analyzes real-time performance metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();
  
  // Metrics storage
  final Map<String, Queue<PerformanceMetric>> _metrics = {};
  final Map<String, Timer> _activeTimers = {};
  final Map<String, DateTime> _operationStartTimes = {};
  
  // Performance monitoring service instance
  late final PerformanceMonitoringService _performanceService;
  
  // Configuration
  static const int MAX_METRICS_PER_TYPE = 1000;
  static const Duration METRICS_RETENTION = Duration(hours: 24);
  static const Duration REPORTING_INTERVAL = Duration(minutes: 5);
  
  Timer? _reportingTimer;
  bool _isEnabled = true;
  
  /// Initialize the performance monitor
  static void initialize() {
    final instance = PerformanceMonitor();
    if (!instance._isEnabled) return;
    
    print('🔍 Initializing Performance Monitor');
    
    // Initialize performance monitoring service
    instance._performanceService = PerformanceMonitoringService.instance;
    
    // Initialize CDN and load testing metrics
    instance._initializeCDNMetrics();
    instance._initializeLoadTestingMetrics();
    
    // Start periodic reporting
    instance._reportingTimer = Timer.periodic(REPORTING_INTERVAL, (_) {
      instance._generatePerformanceReport();
    });
    
    // Clean up old metrics periodically
    Timer.periodic(const Duration(hours: 1), (_) {
      instance._cleanupOldMetrics();
    });
  }
  
  /// Initialize CDN-specific metrics tracking
  void _initializeCDNMetrics() {
    _metrics['cdn_upload_time'] = Queue<PerformanceMetric>();
    _metrics['cdn_download_time'] = Queue<PerformanceMetric>();
    _metrics['cdn_cache_hit_rate'] = Queue<PerformanceMetric>();
    _metrics['cdn_bandwidth_usage'] = Queue<PerformanceMetric>();
    _metrics['asset_optimization_ratio'] = Queue<PerformanceMetric>();
  }
  
  /// Initialize load testing metrics tracking
  void _initializeLoadTestingMetrics() {
    _metrics['concurrent_users'] = Queue<PerformanceMetric>();
    _metrics['request_throughput'] = Queue<PerformanceMetric>();
    _metrics['response_time_p95'] = Queue<PerformanceMetric>();
    _metrics['error_rate'] = Queue<PerformanceMetric>();
    _metrics['memory_under_load'] = Queue<PerformanceMetric>();
    _metrics['cpu_usage_under_load'] = Queue<PerformanceMetric>();
  }
  
  /// Track CDN upload performance
  void trackCDNUpload(String assetId, int fileSizeBytes, Duration uploadTime) {
    final uploadSpeedMBps = (fileSizeBytes / (1024 * 1024)) / uploadTime.inSeconds;
    
    _performanceService.recordMetric('cdn_upload_time', uploadTime.inMilliseconds.toDouble(), metadata: {
      'asset_id': assetId,
      'file_size_bytes': fileSizeBytes,
      'upload_speed_mbps': uploadSpeedMBps,
    });
    
    _performanceService.recordMetric('cdn_bandwidth_usage', fileSizeBytes.toDouble(), metadata: {
      'operation': 'upload',
      'asset_id': assetId,
    });
  }
  
  /// Track CDN download performance
  void trackCDNDownload(String assetId, int fileSizeBytes, Duration downloadTime, bool cacheHit) {
    final downloadSpeedMBps = (fileSizeBytes / (1024 * 1024)) / downloadTime.inSeconds;
    
    _performanceService.recordMetric('cdn_download_time', downloadTime.inMilliseconds.toDouble(), metadata: {
      'asset_id': assetId,
      'file_size_bytes': fileSizeBytes,
      'download_speed_mbps': downloadSpeedMBps,
      'cache_hit': cacheHit,
    });
    
    _performanceService.recordMetric('cdn_cache_hit_rate', cacheHit ? 1.0 : 0.0, metadata: {
      'asset_id': assetId,
    });
    
    _performanceService.recordMetric('cdn_bandwidth_usage', fileSizeBytes.toDouble(), metadata: {
      'operation': 'download',
      'asset_id': assetId,
      'cache_hit': cacheHit,
    });
  }
  
  /// Track asset optimization performance
  void trackAssetOptimization(String assetId, int originalSize, int optimizedSize, Duration optimizationTime) {
    final compressionRatio = 1.0 - (optimizedSize / originalSize);
    final sizeSavedBytes = originalSize - optimizedSize;
    
    _performanceService.recordMetric('asset_optimization_ratio', compressionRatio, metadata: {
      'asset_id': assetId,
      'original_size_bytes': originalSize,
      'optimized_size_bytes': optimizedSize,
      'size_saved_bytes': sizeSavedBytes,
      'optimization_time_ms': optimizationTime.inMilliseconds,
    });
  }
  
  /// Track load testing metrics
  void trackLoadTestMetrics({
    required int concurrentUsers,
    required double requestThroughput,
    required double responseTimeP95,
    required double errorRate,
    required double memoryUsageMB,
    required double cpuUsagePercent,
  }) {
    _performanceService.recordMetric('concurrent_users', concurrentUsers.toDouble());
    _performanceService.recordMetric('request_throughput', requestThroughput);
    _performanceService.recordMetric('response_time_p95', responseTimeP95);
    _performanceService.recordMetric('error_rate', errorRate);
    _performanceService.recordMetric('memory_under_load', memoryUsageMB);
    _performanceService.recordMetric('cpu_usage_under_load', cpuUsagePercent);
  }
  
  /// Start load test monitoring
  void startLoadTest(String testName, int targetUsers) {
    startOperation('load_test_$testName');
    
    _performanceService.recordMetric('load_test_started', 1.0, metadata: {
      'test_name': testName,
      'target_users': targetUsers,
      'start_time': DateTime.now().toIso8601String(),
    });
    
    print('🚀 Load test started: $testName with $targetUsers users');
  }
  
  /// End load test monitoring
  void endLoadTest(String testName, Map<String, dynamic> results) {
    final duration = endOperation('load_test_$testName');
    
    _performanceService.recordMetric('load_test_completed', 1.0, metadata: {
      'test_name': testName,
      'duration_ms': duration?.inMilliseconds ?? 0,
      'end_time': DateTime.now().toIso8601String(),
      ...results,
    });
    
    print('✅ Load test completed: $testName in ${duration?.inMilliseconds}ms');
  }
  
  /// Generate comprehensive performance report including CDN and load testing
  Future<Map<String, dynamic>> generateComprehensiveReport() async {
    final report = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'metrics_summary': _generateMetricsSummary(),
    };
    
    // Add CDN performance analysis
    final cdnMetrics = _analyzeCDNPerformance();
    report['cdn_performance'] = cdnMetrics;
    
    // Add load testing analysis
    final loadTestMetrics = _analyzeLoadTestPerformance();
    report['load_test_performance'] = loadTestMetrics;
    
    // Generate recommendations
    final recommendations = _generatePerformanceRecommendations(report);
    report['recommendations'] = recommendations;
    
    return report;
  }
  
  /// Generate metrics summary
  Map<String, dynamic> _generateMetricsSummary() {
    final summary = <String, dynamic>{};
    
    _metrics.forEach((metricName, queue) {
      if (queue.isNotEmpty) {
        final values = queue.map((m) => m.duration.inMilliseconds.toDouble()).toList();
        summary[metricName] = {
          'count': values.length,
          'average': values.reduce((a, b) => a + b) / values.length,
          'min': values.reduce((a, b) => a < b ? a : b),
          'max': values.reduce((a, b) => a > b ? a : b),
        };
      }
    });
    
    return summary;
  }
  
  /// Analyze CDN performance metrics
  Map<String, dynamic> _analyzeCDNPerformance() {
    final uploadTimes = _getMetricValues('cdn_upload_time');
    final downloadTimes = _getMetricValues('cdn_download_time');
    final cacheHitRates = _getMetricValues('cdn_cache_hit_rate');
    final bandwidthUsage = _getMetricValues('cdn_bandwidth_usage');
    
    return {
      'average_upload_time_ms': uploadTimes.isNotEmpty ? uploadTimes.reduce((a, b) => a + b) / uploadTimes.length : 0,
      'average_download_time_ms': downloadTimes.isNotEmpty ? downloadTimes.reduce((a, b) => a + b) / downloadTimes.length : 0,
      'cache_hit_rate': cacheHitRates.isNotEmpty ? cacheHitRates.reduce((a, b) => a + b) / cacheHitRates.length : 0,
      'total_bandwidth_usage_bytes': bandwidthUsage.isNotEmpty ? bandwidthUsage.reduce((a, b) => a + b) : 0,
      'upload_count': uploadTimes.length,
      'download_count': downloadTimes.length,
    };
  }
  
  /// Analyze load test performance metrics
  Map<String, dynamic> _analyzeLoadTestPerformance() {
    final concurrentUsers = _getMetricValues('concurrent_users');
    final throughput = _getMetricValues('request_throughput');
    final responseTimeP95 = _getMetricValues('response_time_p95');
    final errorRates = _getMetricValues('error_rate');
    final memoryUsage = _getMetricValues('memory_under_load');
    final cpuUsage = _getMetricValues('cpu_usage_under_load');
    
    return {
      'max_concurrent_users': concurrentUsers.isNotEmpty ? concurrentUsers.reduce((a, b) => a > b ? a : b) : 0,
      'average_throughput_rps': throughput.isNotEmpty ? throughput.reduce((a, b) => a + b) / throughput.length : 0,
      'average_response_time_p95_ms': responseTimeP95.isNotEmpty ? responseTimeP95.reduce((a, b) => a + b) / responseTimeP95.length : 0,
      'average_error_rate': errorRates.isNotEmpty ? errorRates.reduce((a, b) => a + b) / errorRates.length : 0,
      'peak_memory_usage_mb': memoryUsage.isNotEmpty ? memoryUsage.reduce((a, b) => a > b ? a : b) : 0,
      'peak_cpu_usage_percent': cpuUsage.isNotEmpty ? cpuUsage.reduce((a, b) => a > b ? a : b) : 0,
      'test_count': concurrentUsers.length,
    };
  }
  
  /// Generate performance recommendations
  List<String> _generatePerformanceRecommendations(Map<String, dynamic> report) {
    final recommendations = <String>[];
    
    // CDN recommendations
    final cdnMetrics = report['cdn_performance'] as Map<String, dynamic>;
    if (cdnMetrics['cache_hit_rate'] < 0.8) {
      recommendations.add('CDN cache hit rate is below 80%. Consider optimizing cache headers and TTL settings.');
    }
    if (cdnMetrics['average_upload_time_ms'] > 5000) {
      recommendations.add('CDN upload times are high. Consider implementing file compression and chunked uploads.');
    }
    
    // Load test recommendations
    final loadMetrics = report['load_test_performance'] as Map<String, dynamic>;
    if (loadMetrics['average_error_rate'] > 0.05) {
      recommendations.add('Error rate is above 5% under load. Investigate and fix failing requests.');
    }
    if (loadMetrics['average_response_time_p95_ms'] > 2000) {
      recommendations.add('95th percentile response time is above 2 seconds. Optimize database queries and API endpoints.');
    }
    if (loadMetrics['peak_memory_usage_mb'] > 500) {
      recommendations.add('Memory usage peaks above 500MB under load. Check for memory leaks and optimize data structures.');
    }
    
    // General recommendations
    if (recommendations.isEmpty) {
      recommendations.add('Performance metrics are within acceptable ranges. Continue monitoring.');
    }
    
    return recommendations;
  }
  
  /// Get metric values for analysis
  List<double> _getMetricValues(String metricName) {
    final queue = _metrics[metricName];
    if (queue == null) return [];
    
    return queue.map((metric) => metric.duration.inMilliseconds.toDouble()).toList();
  }
  
  /// Dispose of the performance monitor
  void dispose() {
    _reportingTimer?.cancel();
    for (var timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _metrics.clear();
  }
  
  /// Start timing an operation
  void startOperation(String operationName, {Map<String, dynamic>? metadata}) {
    if (!_isEnabled) return;
    
    final operationId = '${operationName}_${DateTime.now().millisecondsSinceEpoch}';
    _operationStartTimes[operationId] = DateTime.now();
    
    if (kDebugMode) {
      print('⏱️  Started operation: $operationName');
    }
  }
  
  /// End timing an operation and record the metric
  Duration? endOperation(String operationName, {
    Map<String, dynamic>? metadata,
    bool success = true,
    String? errorMessage,
  }) {
    if (!_isEnabled) return null;
    
    final operationId = _operationStartTimes.keys
        .where((key) => key.startsWith(operationName))
        .lastOrNull;
    
    if (operationId == null) {
      print('⚠️  No start time found for operation: $operationName');
      return null;
    }
    
    final startTime = _operationStartTimes.remove(operationId)!;
    final duration = DateTime.now().difference(startTime);
    
    recordMetric(PerformanceMetric(
      operationName: operationName,
      duration: duration,
      timestamp: DateTime.now(),
      success: success,
      errorMessage: errorMessage,
      metadata: metadata ?? {},
    ));
    
    if (kDebugMode) {
      print('✅ Completed operation: $operationName (${duration.inMilliseconds}ms)');
    }
    
    return duration;
  }
  
  /// Record a performance metric
  void recordMetric(PerformanceMetric metric) {
    if (!_isEnabled) return;
    
    _metrics.putIfAbsent(metric.operationName, () => Queue<PerformanceMetric>());
    final queue = _metrics[metric.operationName]!;
    
    queue.add(metric);
    
    // Maintain queue size limit
    while (queue.length > MAX_METRICS_PER_TYPE) {
      queue.removeFirst();
    }
  }
  
  /// Record memory usage
  void recordMemoryUsage() {
    if (!_isEnabled) return;
    
    // This would typically use platform-specific memory APIs
    // For now, we'll simulate memory metrics
    final memoryMetric = PerformanceMetric(
      operationName: 'memory_usage',
      duration: Duration.zero,
      timestamp: DateTime.now(),
      success: true,
      metadata: {
        'heap_usage_mb': _getSimulatedMemoryUsage(),
        'cache_size_mb': _getSimulatedCacheSize(),
      },
    );
    
    recordMetric(memoryMetric);
  }
  
  /// Record network performance
  void recordNetworkMetric({
    required String endpoint,
    required Duration responseTime,
    required int statusCode,
    required int bytesTransferred,
  }) {
    if (!_isEnabled) return;
    
    final networkMetric = PerformanceMetric(
      operationName: 'network_request',
      duration: responseTime,
      timestamp: DateTime.now(),
      success: statusCode >= 200 && statusCode < 300,
      metadata: {
        'endpoint': endpoint,
        'status_code': statusCode,
        'bytes_transferred': bytesTransferred,
        'response_time_ms': responseTime.inMilliseconds,
      },
    );
    
    recordMetric(networkMetric);
  }
  
  /// Record database operation performance
  void recordDatabaseMetric({
    required String operation,
    required Duration duration,
    required bool success,
    String? collection,
    int? documentsAffected,
    String? errorMessage,
  }) {
    if (!_isEnabled) return;
    
    final dbMetric = PerformanceMetric(
      operationName: 'database_$operation',
      duration: duration,
      timestamp: DateTime.now(),
      success: success,
      errorMessage: errorMessage,
      metadata: {
        'collection': collection,
        'documents_affected': documentsAffected,
        'operation_type': operation,
      },
    );
    
    recordMetric(dbMetric);
  }
  
  /// Record UI performance metrics
  void recordUIMetric({
    required String screenName,
    required Duration renderTime,
    required int frameDrops,
    double? fps,
  }) {
    if (!_isEnabled) return;
    
    final uiMetric = PerformanceMetric(
      operationName: 'ui_render',
      duration: renderTime,
      timestamp: DateTime.now(),
      success: frameDrops < 5, // Consider success if less than 5 frame drops
      metadata: {
        'screen_name': screenName,
        'frame_drops': frameDrops,
        'fps': fps,
        'render_time_ms': renderTime.inMilliseconds,
      },
    );
    
    recordMetric(uiMetric);
  }
  
  /// Get performance statistics for an operation
  PerformanceStats? getStats(String operationName) {
    final metrics = _metrics[operationName];
    if (metrics == null || metrics.isEmpty) return null;
    
    final durations = metrics.map((m) => m.duration.inMilliseconds).toList();
    durations.sort();
    
    final successCount = metrics.where((m) => m.success).length;
    final errorCount = metrics.length - successCount;
    
    return PerformanceStats(
      operationName: operationName,
      totalOperations: metrics.length,
      successCount: successCount,
      errorCount: errorCount,
      averageResponseTime: durations.isEmpty ? 0 : durations.reduce((a, b) => a + b) / durations.length,
      p50ResponseTime: durations.isEmpty ? 0 : durations[(durations.length * 0.5).floor()].toDouble(),
      p95ResponseTime: durations.isEmpty ? 0 : durations[(durations.length * 0.95).floor()].toDouble(),
      p99ResponseTime: durations.isEmpty ? 0 : durations[(durations.length * 0.99).floor()].toDouble(),
      minResponseTime: durations.isEmpty ? 0 : durations.first.toDouble(),
      maxResponseTime: durations.isEmpty ? 0 : durations.last.toDouble(),
      errorRate: metrics.isEmpty ? 0 : errorCount / metrics.length,
      throughput: _calculateThroughput(metrics),
    );
  }
  
  /// Get all performance statistics
  Map<String, PerformanceStats> getAllStats() {
    final stats = <String, PerformanceStats>{};
    
    for (var operationName in _metrics.keys) {
      final operationStats = getStats(operationName);
      if (operationStats != null) {
        stats[operationName] = operationStats;
      }
    }
    
    return stats;
  }
  
  /// Generate a comprehensive performance report
  PerformanceReport _generatePerformanceReport() {
    final allStats = getAllStats();
    final report = PerformanceReport(
      timestamp: DateTime.now(),
      stats: allStats,
      systemMetrics: _getSystemMetrics(),
    );
    
    if (kDebugMode) {
      print('📊 Performance Report Generated:');
      print(report.generateSummary());
    }
    
    // Save report to database for historical analysis
    _saveReportToDatabase(report);
    
    return report;
  }
  
  /// Calculate throughput (operations per second)
  double _calculateThroughput(Queue<PerformanceMetric> metrics) {
    if (metrics.isEmpty) return 0;
    
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    
    final recentMetrics = metrics.where((m) => m.timestamp.isAfter(oneMinuteAgo));
    return recentMetrics.length / 60.0; // operations per second
  }
  
  /// Clean up old metrics to prevent memory leaks
  void _cleanupOldMetrics() {
    final cutoffTime = DateTime.now().subtract(METRICS_RETENTION);
    
    _metrics.forEach((operationName, queue) {
      queue.removeWhere((metric) => metric.timestamp.isBefore(cutoffTime));
    });
    
    // Remove empty queues
    _metrics.removeWhere((key, queue) => queue.isEmpty);
  }
  
  /// Get simulated memory usage (in production, use platform-specific APIs)
  double _getSimulatedMemoryUsage() {
    // Simulate memory usage between 50-200 MB
    return 50 + (DateTime.now().millisecondsSinceEpoch % 150);
  }
  
  /// Get simulated cache size
  double _getSimulatedCacheSize() {
    // Simulate cache size between 10-50 MB
    return 10 + (DateTime.now().millisecondsSinceEpoch % 40);
  }
  
  /// Get system metrics
  SystemMetrics _getSystemMetrics() {
    return SystemMetrics(
      memoryUsageMB: _getSimulatedMemoryUsage(),
      cacheUsageMB: _getSimulatedCacheSize(),
      activeConnections: _getActiveConnectionCount(),
      cpuUsagePercent: _getSimulatedCPUUsage(),
    );
  }
  
  /// Get active connection count
  int _getActiveConnectionCount() {
    // Simulate active connections
    return 5 + (DateTime.now().millisecondsSinceEpoch % 20);
  }
  
  /// Get simulated CPU usage
  double _getSimulatedCPUUsage() {
    // Simulate CPU usage between 10-80%
    return 10 + (DateTime.now().millisecondsSinceEpoch % 70);
  }
  
  /// Save performance report to database
  Future<void> _saveReportToDatabase(PerformanceReport report) async {
    try {
      final db = FirebaseFirestore.instance;
      await db.collection('performance_reports').add({
        'timestamp': report.timestamp,
        'stats': report.stats.map((key, value) => MapEntry(key, value.toMap())),
        'system_metrics': report.systemMetrics.toMap(),
      });
    } catch (e) {
      print('❌ Failed to save performance report: $e');
    }
  }
  
  /// Enable or disable performance monitoring
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      dispose();
    } else if (_reportingTimer == null) {
      initialize();
    }
  }
}

/// Performance metric data class
class PerformanceMetric {
  final String operationName;
  final Duration duration;
  final DateTime timestamp;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic> metadata;
  
  PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.timestamp,
    required this.success,
    this.errorMessage,
    required this.metadata,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'operation_name': operationName,
      'duration_ms': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'success': success,
      'error_message': errorMessage,
      'metadata': metadata,
    };
  }
}

/// Performance statistics for an operation
class PerformanceStats {
  final String operationName;
  final int totalOperations;
  final int successCount;
  final int errorCount;
  final double averageResponseTime;
  final double p50ResponseTime;
  final double p95ResponseTime;
  final double p99ResponseTime;
  final double minResponseTime;
  final double maxResponseTime;
  final double errorRate;
  final double throughput;
  
  PerformanceStats({
    required this.operationName,
    required this.totalOperations,
    required this.successCount,
    required this.errorCount,
    required this.averageResponseTime,
    required this.p50ResponseTime,
    required this.p95ResponseTime,
    required this.p99ResponseTime,
    required this.minResponseTime,
    required this.maxResponseTime,
    required this.errorRate,
    required this.throughput,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'operation_name': operationName,
      'total_operations': totalOperations,
      'success_count': successCount,
      'error_count': errorCount,
      'average_response_time': averageResponseTime,
      'p50_response_time': p50ResponseTime,
      'p95_response_time': p95ResponseTime,
      'p99_response_time': p99ResponseTime,
      'min_response_time': minResponseTime,
      'max_response_time': maxResponseTime,
      'error_rate': errorRate,
      'throughput': throughput,
    };
  }
}

/// System metrics
class SystemMetrics {
  final double memoryUsageMB;
  final double cacheUsageMB;
  final int activeConnections;
  final double cpuUsagePercent;
  
  SystemMetrics({
    required this.memoryUsageMB,
    required this.cacheUsageMB,
    required this.activeConnections,
    required this.cpuUsagePercent,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'memory_usage_mb': memoryUsageMB,
      'cache_usage_mb': cacheUsageMB,
      'active_connections': activeConnections,
      'cpu_usage_percent': cpuUsagePercent,
    };
  }
}

/// Performance report
class PerformanceReport {
  final DateTime timestamp;
  final Map<String, PerformanceStats> stats;
  final SystemMetrics systemMetrics;
  
  PerformanceReport({
    required this.timestamp,
    required this.stats,
    required this.systemMetrics,
  });
  
  String generateSummary() {
    final buffer = StringBuffer();
    buffer.writeln('📊 PERFORMANCE REPORT - ${timestamp.toIso8601String()}');
    buffer.writeln('=' * 60);
    
    buffer.writeln('🖥️  SYSTEM METRICS:');
    buffer.writeln('  Memory Usage: ${systemMetrics.memoryUsageMB.toStringAsFixed(1)} MB');
    buffer.writeln('  Cache Usage: ${systemMetrics.cacheUsageMB.toStringAsFixed(1)} MB');
    buffer.writeln('  Active Connections: ${systemMetrics.activeConnections}');
    buffer.writeln('  CPU Usage: ${systemMetrics.cpuUsagePercent.toStringAsFixed(1)}%');
    buffer.writeln();
    
    buffer.writeln('⚡ OPERATION PERFORMANCE:');
    stats.forEach((operation, stat) {
      buffer.writeln('  $operation:');
      buffer.writeln('    Total Operations: ${stat.totalOperations}');
      buffer.writeln('    Success Rate: ${((1 - stat.errorRate) * 100).toStringAsFixed(1)}%');
      buffer.writeln('    Avg Response: ${stat.averageResponseTime.toStringAsFixed(1)}ms');
      buffer.writeln('    P95 Response: ${stat.p95ResponseTime.toStringAsFixed(1)}ms');
      buffer.writeln('    Throughput: ${stat.throughput.toStringAsFixed(2)} ops/sec');
      buffer.writeln();
    });
    
    return buffer.toString();
  }
}