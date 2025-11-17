import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'advanced_cache_service.dart';
import 'cache_partition_service.dart';

/// Cache performance alert types
enum CacheAlertType {
  lowHitRate,
  highMemoryUsage,
  slowResponseTime,
  highEvictionRate,
  partitionOverload,
  compressionIssue,
}

/// Cache performance alert
class CacheAlert {
  final CacheAlertType type;
  final String message;
  final double severity; // 0.0 to 1.0
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  CacheAlert({
    required this.type,
    required this.message,
    required this.severity,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Cache performance metrics
class CachePerformanceMetrics {
  final double hitRate;
  final double missRate;
  final double evictionRate;
  final double compressionRatio;
  final double averageResponseTime;
  final int totalRequests;
  final int totalHits;
  final int totalMisses;
  final int totalEvictions;
  final double memoryUsage;
  final double diskUsage;
  final DateTime timestamp;

  CachePerformanceMetrics({
    required this.hitRate,
    required this.missRate,
    required this.evictionRate,
    required this.compressionRatio,
    required this.averageResponseTime,
    required this.totalRequests,
    required this.totalHits,
    required this.totalMisses,
    required this.totalEvictions,
    required this.memoryUsage,
    required this.diskUsage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Cache monitoring and performance tracking service
class CacheMonitoringService {
  static CacheMonitoringService? _instance;
  static CacheMonitoringService get instance => _instance ??= CacheMonitoringService._();

  CacheMonitoringService._();

  final AdvancedCacheService _cacheService = AdvancedCacheService.instance;
  final CachePartitionService _partitionService = CachePartitionService.instance;

  // Performance tracking
  final List<CachePerformanceMetrics> _metricsHistory = [];
  final List<CacheAlert> _alerts = [];
  final Map<String, List<double>> _responseTimeHistory = {};
  
  // Monitoring configuration
  double _hitRateThreshold = 0.7; // Alert if hit rate below 70%
  double _memoryUsageThreshold = 0.8; // Alert if memory usage above 80%
  double _responseTimeThreshold = 100.0; // Alert if response time above 100ms
  int _maxHistorySize = 1000;
  int _maxAlertsSize = 100;
  
  // Monitoring timers
  Timer? _metricsTimer;
  Timer? _alertTimer;
  Timer? _cleanupTimer;
  
  // Performance counters
  int _totalRequests = 0;
  int _totalHits = 0;
  int _totalMisses = 0;
  int _totalEvictions = 0;
  double _totalResponseTime = 0.0;
  int _compressionCount = 0;
  int _decompressionCount = 0;
  
  bool _isInitialized = false;

  /// Initialize the cache monitoring service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _cacheService.initialize();
      await _partitionService.initialize();
      
      _startMetricsCollection();
      _startAlertMonitoring();
      _startPeriodicCleanup();
      
      _isInitialized = true;
      debugPrint('✅ Cache Monitoring Service initialized');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize Cache Monitoring Service: $e');
    }
  }

  /// Configure monitoring thresholds
  void configure({
    double? hitRateThreshold,
    double? memoryUsageThreshold,
    double? responseTimeThreshold,
    int? maxHistorySize,
    int? maxAlertsSize,
  }) {
    _hitRateThreshold = hitRateThreshold ?? _hitRateThreshold;
    _memoryUsageThreshold = memoryUsageThreshold ?? _memoryUsageThreshold;
    _responseTimeThreshold = responseTimeThreshold ?? _responseTimeThreshold;
    _maxHistorySize = maxHistorySize ?? _maxHistorySize;
    _maxAlertsSize = maxAlertsSize ?? _maxAlertsSize;
    
    debugPrint('🔧 Cache monitoring configured:');
    debugPrint('   Hit rate threshold: ${(_hitRateThreshold * 100).toStringAsFixed(1)}%');
    debugPrint('   Memory usage threshold: ${(_memoryUsageThreshold * 100).toStringAsFixed(1)}%');
    debugPrint('   Response time threshold: ${_responseTimeThreshold}ms');
  }

  /// Record cache operation metrics
  void recordCacheOperation({
    required String operation,
    required bool isHit,
    required double responseTime,
    String? partition,
    bool? wasCompressed,
  }) {
    _totalRequests++;
    _totalResponseTime += responseTime;
    
    if (isHit) {
      _totalHits++;
    } else {
      _totalMisses++;
    }
    
    if (wasCompressed == true) {
      _compressionCount++;
    }
    
    // Track response time history
    final key = partition ?? 'global';
    _responseTimeHistory[key] ??= [];
    _responseTimeHistory[key]!.add(responseTime);
    
    // Keep only recent response times
    if (_responseTimeHistory[key]!.length > 100) {
      _responseTimeHistory[key]!.removeAt(0);
    }
    
    // Check for immediate alerts
    _checkImmediateAlerts(responseTime, partition);
  }

  /// Record cache eviction
  void recordEviction(String key, String? partition) {
    _totalEvictions++;
    
    // Check eviction rate
    final evictionRate = _totalEvictions / max(1, _totalRequests);
    if (evictionRate > 0.1) { // Alert if eviction rate above 10%
      _addAlert(CacheAlert(
        type: CacheAlertType.highEvictionRate,
        message: 'High eviction rate detected: ${(evictionRate * 100).toStringAsFixed(1)}%',
        severity: min(1.0, evictionRate * 2),
        metadata: {'partition': partition, 'evictionRate': evictionRate},
      ));
    }
  }

  /// Get current performance metrics
  CachePerformanceMetrics getCurrentMetrics() {
    final hitRate = _totalRequests > 0 ? _totalHits / _totalRequests : 0.0;
    final missRate = 1.0 - hitRate;
    final evictionRate = _totalRequests > 0 ? _totalEvictions / _totalRequests : 0.0;
    final compressionRatio = _compressionCount > 0 ? _decompressionCount / _compressionCount : 0.0;
    final averageResponseTime = _totalRequests > 0 ? _totalResponseTime / _totalRequests : 0.0;
    
    // Get cache stats for memory/disk usage
    final cacheStats = _cacheService.getStats();
    final memoryUsage = _calculateMemoryUsage(cacheStats);
    final diskUsage = _calculateDiskUsage(cacheStats);
    
    return CachePerformanceMetrics(
      hitRate: hitRate,
      missRate: missRate,
      evictionRate: evictionRate,
      compressionRatio: compressionRatio,
      averageResponseTime: averageResponseTime,
      totalRequests: _totalRequests,
      totalHits: _totalHits,
      totalMisses: _totalMisses,
      totalEvictions: _totalEvictions,
      memoryUsage: memoryUsage,
      diskUsage: diskUsage,
    );
  }

  /// Get metrics history
  List<CachePerformanceMetrics> getMetricsHistory({int? limit}) {
    final historyLimit = limit ?? _metricsHistory.length;
    return _metricsHistory.take(historyLimit).toList();
  }

  /// Get recent alerts
  List<CacheAlert> getRecentAlerts({int? limit}) {
    final alertLimit = limit ?? _alerts.length;
    return _alerts.take(alertLimit).toList();
  }

  /// Get partition performance breakdown
  Map<String, dynamic> getPartitionPerformance() {
    final partitionStats = _partitionService.getPartitionStats();
    final performance = <String, dynamic>{};
    
    for (final entry in partitionStats.entries) {
      final partitionName = entry.key;
      final stats = entry.value as Map<String, dynamic>;
      
      performance[partitionName] = {
        'hitRate': stats['hitRate'],
        'totalRequests': stats['hits'] + stats['misses'],
        'averageResponseTime': _getAverageResponseTime(partitionName),
        'memoryEfficiency': _calculateMemoryEfficiency(stats),
        'performance_score': _calculatePerformanceScore(stats),
      };
    }
    
    return performance;
  }

  /// Get comprehensive performance report
  Map<String, dynamic> getPerformanceReport() {
    final currentMetrics = getCurrentMetrics();
    final partitionPerformance = getPartitionPerformance();
    final recentAlerts = getRecentAlerts(limit: 10);
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'overall_performance': {
        'hit_rate': currentMetrics.hitRate,
        'average_response_time': currentMetrics.averageResponseTime,
        'memory_usage': currentMetrics.memoryUsage,
        'disk_usage': currentMetrics.diskUsage,
        'total_requests': currentMetrics.totalRequests,
        'performance_grade': _calculateOverallGrade(currentMetrics),
      },
      'partition_performance': partitionPerformance,
      'recent_alerts': recentAlerts.map((alert) => {
        'type': alert.type.name,
        'message': alert.message,
        'severity': alert.severity,
        'timestamp': alert.timestamp.toIso8601String(),
      }).toList(),
      'recommendations': _generateRecommendations(currentMetrics, partitionPerformance),
    };
  }

  /// Clear performance history
  void clearHistory() {
    _metricsHistory.clear();
    _alerts.clear();
    _responseTimeHistory.clear();
    
    // Reset counters
    _totalRequests = 0;
    _totalHits = 0;
    _totalMisses = 0;
    _totalEvictions = 0;
    _totalResponseTime = 0.0;
    _compressionCount = 0;
    _decompressionCount = 0;
    
    debugPrint('🗑️ Cache monitoring history cleared');
  }

  /// Dispose monitoring service
  void dispose() {
    _metricsTimer?.cancel();
    _alertTimer?.cancel();
    _cleanupTimer?.cancel();
    
    debugPrint('🔌 Cache Monitoring Service disposed');
  }

  // Private helper methods

  void _startMetricsCollection() {
    _metricsTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      try {
        final metrics = getCurrentMetrics();
        _metricsHistory.insert(0, metrics);
        
        // Keep history size manageable
        if (_metricsHistory.length > _maxHistorySize) {
          _metricsHistory.removeRange(_maxHistorySize, _metricsHistory.length);
        }
        
        if (kDebugMode) {
          debugPrint('📊 Cache Metrics: '
              'Hit Rate: ${(metrics.hitRate * 100).toStringAsFixed(1)}%, '
              'Avg Response: ${metrics.averageResponseTime.toStringAsFixed(1)}ms, '
              'Memory: ${(metrics.memoryUsage * 100).toStringAsFixed(1)}%');
        }
        
      } catch (e) {
        debugPrint('❌ Error collecting cache metrics: $e');
      }
    });
  }

  void _startAlertMonitoring() {
    _alertTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      try {
        _checkPerformanceAlerts();
      } catch (e) {
        debugPrint('❌ Error checking cache alerts: $e');
      }
    });
  }

  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      try {
        _performCleanup();
      } catch (e) {
        debugPrint('❌ Error during cache monitoring cleanup: $e');
      }
    });
  }

  void _checkImmediateAlerts(double responseTime, String? partition) {
    // Check response time
    if (responseTime > _responseTimeThreshold) {
      _addAlert(CacheAlert(
        type: CacheAlertType.slowResponseTime,
        message: 'Slow cache response time: ${responseTime.toStringAsFixed(1)}ms',
        severity: min(1.0, responseTime / (_responseTimeThreshold * 2)),
        metadata: {'responseTime': responseTime, 'partition': partition},
      ));
    }
  }

  void _checkPerformanceAlerts() {
    final metrics = getCurrentMetrics();
    
    // Check hit rate
    if (metrics.hitRate < _hitRateThreshold) {
      _addAlert(CacheAlert(
        type: CacheAlertType.lowHitRate,
        message: 'Low cache hit rate: ${(metrics.hitRate * 100).toStringAsFixed(1)}%',
        severity: 1.0 - metrics.hitRate,
        metadata: {'hitRate': metrics.hitRate},
      ));
    }
    
    // Check memory usage
    if (metrics.memoryUsage > _memoryUsageThreshold) {
      _addAlert(CacheAlert(
        type: CacheAlertType.highMemoryUsage,
        message: 'High memory usage: ${(metrics.memoryUsage * 100).toStringAsFixed(1)}%',
        severity: metrics.memoryUsage,
        metadata: {'memoryUsage': metrics.memoryUsage},
      ));
    }
    
    // Check partition performance
    _checkPartitionAlerts();
  }

  void _checkPartitionAlerts() {
    final partitionStats = _partitionService.getPartitionStats();
    
    for (final entry in partitionStats.entries) {
      final partitionName = entry.key;
      final stats = entry.value as Map<String, dynamic>;
      final hitRate = stats['hitRate'] as double;
      
      if (hitRate < 0.5 && (stats['hits'] + stats['misses']) > 50) {
        _addAlert(CacheAlert(
          type: CacheAlertType.partitionOverload,
          message: 'Poor performance in partition $partitionName: ${(hitRate * 100).toStringAsFixed(1)}% hit rate',
          severity: 1.0 - hitRate,
          metadata: {'partition': partitionName, 'hitRate': hitRate},
        ));
      }
    }
  }

  void _addAlert(CacheAlert alert) {
    _alerts.insert(0, alert);
    
    // Keep alerts size manageable
    if (_alerts.length > _maxAlertsSize) {
      _alerts.removeRange(_maxAlertsSize, _alerts.length);
    }
    
    if (kDebugMode) {
      debugPrint('🚨 Cache Alert [${alert.type.name}]: ${alert.message}');
    }
  }

  double _calculateMemoryUsage(Map<String, dynamic> cacheStats) {
    // Calculate memory usage based on cache stats
    double totalSize = 0.0;
    double maxSize = 100 * 1024 * 1024; // 100MB default
    
    for (final tierStats in cacheStats.values) {
      if (tierStats is Map<String, dynamic>) {
        totalSize += (tierStats['totalSize'] as double? ?? 0.0);
      }
    }
    
    return totalSize / maxSize;
  }

  double _calculateDiskUsage(Map<String, dynamic> cacheStats) {
    // Calculate disk usage for persistent cache
    final l2Stats = cacheStats['l2Persistent'] as Map<String, dynamic>?;
    if (l2Stats != null) {
      final totalSize = l2Stats['totalSize'] as double? ?? 0.0;
      const maxSize = 500 * 1024 * 1024; // 500MB default
      return totalSize / maxSize;
    }
    return 0.0;
  }

  double _getAverageResponseTime(String partition) {
    final responseTimes = _responseTimeHistory[partition];
    if (responseTimes == null || responseTimes.isEmpty) return 0.0;
    
    return responseTimes.reduce((a, b) => a + b) / responseTimes.length;
  }

  double _calculateMemoryEfficiency(Map<String, dynamic> stats) {
    final hitRate = stats['hitRate'] as double;
    final entries = stats['entries'] as int;
    final maxEntries = stats['config']['maxEntries'] as int;
    
    final utilizationRate = entries / maxEntries;
    return hitRate * utilizationRate;
  }

  double _calculatePerformanceScore(Map<String, dynamic> stats) {
    final hitRate = stats['hitRate'] as double;
    final efficiency = _calculateMemoryEfficiency(stats);
    
    return (hitRate * 0.7) + (efficiency * 0.3);
  }

  String _calculateOverallGrade(CachePerformanceMetrics metrics) {
    final score = (metrics.hitRate * 0.4) + 
                  ((200 - metrics.averageResponseTime) / 200 * 0.3) +
                  ((1.0 - metrics.memoryUsage) * 0.3);
    
    if (score >= 0.9) return 'A+';
    if (score >= 0.8) return 'A';
    if (score >= 0.7) return 'B';
    if (score >= 0.6) return 'C';
    if (score >= 0.5) return 'D';
    return 'F';
  }

  List<String> _generateRecommendations(
    CachePerformanceMetrics metrics,
    Map<String, dynamic> partitionPerformance,
  ) {
    final recommendations = <String>[];
    
    if (metrics.hitRate < 0.7) {
      recommendations.add('Consider increasing cache size or adjusting TTL values');
    }
    
    if (metrics.averageResponseTime > 50) {
      recommendations.add('Optimize cache tier placement for frequently accessed data');
    }
    
    if (metrics.memoryUsage > 0.8) {
      recommendations.add('Enable compression or increase memory limits');
    }
    
    if (metrics.evictionRate > 0.1) {
      recommendations.add('Increase cache capacity or implement better eviction policies');
    }
    
    // Check partition-specific recommendations
    for (final entry in partitionPerformance.entries) {
      final partitionName = entry.key;
      final performance = entry.value as Map<String, dynamic>;
      final hitRate = performance['hitRate'] as double;
      
      if (hitRate < 0.5) {
        recommendations.add('Optimize $partitionName partition: consider cache warming or TTL adjustment');
      }
    }
    
    return recommendations;
  }

  void _performCleanup() {
    // Clean up old response time history
    for (final key in _responseTimeHistory.keys.toList()) {
      final history = _responseTimeHistory[key]!;
      if (history.length > 100) {
        _responseTimeHistory[key] = history.sublist(history.length - 100);
      }
    }
    
    debugPrint('🧹 Cache monitoring cleanup completed');
  }
}