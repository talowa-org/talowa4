import 'dart:async';
import 'package:flutter/foundation.dart';


/// Advanced widget optimization service for Flutter performance at scale
class WidgetOptimizationService {
  static WidgetOptimizationService? _instance;
  static WidgetOptimizationService get instance => _instance ??= WidgetOptimizationService._();

  WidgetOptimizationService._();



  // Widget performance tracking
  final Map<String, WidgetPerformanceMetrics> _widgetMetrics = {};
  final Map<String, List<RebuildEvent>> _rebuildHistory = {};
  final Set<String> _slowWidgets = {};
  
  // Memory tracking
  final Map<String, int> _widgetInstanceCounts = {};
  final Map<String, DateTime> _widgetCreationTimes = {};
  
  // Optimization recommendations
  final Map<String, List<OptimizationRecommendation>> _recommendations = {};
  
  // Configuration
  static const Duration _slowBuildThreshold = Duration(milliseconds: 16);
  static const int _maxRebuildHistory = 100;
  static const int _excessiveRebuildThreshold = 10;
  
  Timer? _metricsReportTimer;
  Timer? _optimizationAnalysisTimer;

  /// Initialize the widget optimization service
  Future<void> initialize() async {
    try {
      _startPerformanceMonitoring();
      _startOptimizationAnalysis();
      debugPrint('✅ WidgetOptimizationService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize WidgetOptimizationService: $e');
    }
  }

  /// Track widget rebuild with performance metrics
  void trackRebuild(
    String widgetName, {
    String? reason,
    Duration? buildTime,
    Map<String, dynamic>? context,
  }) {
    if (!kDebugMode) return;

    final now = DateTime.now();
    final event = RebuildEvent(
      timestamp: now,
      reason: reason ?? 'unknown',
      buildTime: buildTime,
      context: context ?? {},
    );

    // Update rebuild history
    _rebuildHistory[widgetName] ??= [];
    _rebuildHistory[widgetName]!.add(event);
    
    // Keep history size manageable
    if (_rebuildHistory[widgetName]!.length > _maxRebuildHistory) {
      _rebuildHistory[widgetName]!.removeAt(0);
    }

    // Update widget metrics
    _updateWidgetMetrics(widgetName, event);

    // Check for performance issues
    _analyzeWidgetPerformance(widgetName, event);
  }

  /// Track widget instance creation
  void trackWidgetCreation(String widgetName) {
    _widgetInstanceCounts[widgetName] = (_widgetInstanceCounts[widgetName] ?? 0) + 1;
    _widgetCreationTimes[widgetName] = DateTime.now();
  }

  /// Track widget instance disposal
  void trackWidgetDisposal(String widgetName) {
    final count = _widgetInstanceCounts[widgetName] ?? 0;
    if (count > 0) {
      _widgetInstanceCounts[widgetName] = count - 1;
    }
  }

  /// Update widget performance metrics
  void _updateWidgetMetrics(String widgetName, RebuildEvent event) {
    _widgetMetrics[widgetName] ??= WidgetPerformanceMetrics(widgetName: widgetName);
    final metrics = _widgetMetrics[widgetName]!;

    metrics.totalRebuilds++;
    metrics.lastRebuildTime = event.timestamp;

    if (event.buildTime != null) {
      metrics.buildTimes.add(event.buildTime!.inMicroseconds / 1000.0);
      
      // Keep only recent build times
      if (metrics.buildTimes.length > 50) {
        metrics.buildTimes.removeAt(0);
      }

      // Update average build time
      metrics.averageBuildTime = metrics.buildTimes.reduce((a, b) => a + b) / metrics.buildTimes.length;
      
      // Track slow builds
      if (event.buildTime! > _slowBuildThreshold) {
        metrics.slowBuilds++;
        _slowWidgets.add(widgetName);
      }
    }

    // Track rebuild reasons
    metrics.rebuildReasons[event.reason] = (metrics.rebuildReasons[event.reason] ?? 0) + 1;
  }

  /// Analyze widget performance for issues
  void _analyzeWidgetPerformance(String widgetName, RebuildEvent event) {
    final history = _rebuildHistory[widgetName] ?? [];
    
    // Check for excessive rebuilds in short time
    final recentRebuilds = history.where((e) => 
      DateTime.now().difference(e.timestamp) < const Duration(seconds: 1)
    ).length;

    if (recentRebuilds > _excessiveRebuildThreshold) {
      _addOptimizationRecommendation(
        widgetName,
        OptimizationRecommendation(
          type: OptimizationType.excessiveRebuilds,
          severity: Severity.high,
          description: 'Widget is rebuilding excessively ($recentRebuilds times in 1 second)',
          suggestion: 'Consider using const constructors, memoization, or splitting the widget',
        ),
      );
    }

    // Check for slow builds
    if (event.buildTime != null && event.buildTime! > _slowBuildThreshold) {
      _addOptimizationRecommendation(
        widgetName,
        OptimizationRecommendation(
          type: OptimizationType.slowBuild,
          severity: Severity.medium,
          description: 'Widget build time is slow (${event.buildTime!.inMilliseconds}ms)',
          suggestion: 'Optimize widget build method, reduce complexity, or use lazy loading',
        ),
      );
    }

    // Check for memory leaks (too many instances)
    final instanceCount = _widgetInstanceCounts[widgetName] ?? 0;
    if (instanceCount > 100) {
      _addOptimizationRecommendation(
        widgetName,
        OptimizationRecommendation(
          type: OptimizationType.memoryLeak,
          severity: Severity.critical,
          description: 'Potential memory leak detected ($instanceCount instances)',
          suggestion: 'Check for proper widget disposal and avoid creating unnecessary instances',
        ),
      );
    }
  }

  /// Add optimization recommendation
  void _addOptimizationRecommendation(String widgetName, OptimizationRecommendation recommendation) {
    _recommendations[widgetName] ??= [];
    
    // Avoid duplicate recommendations
    final existing = _recommendations[widgetName]!.where((r) => 
      r.type == recommendation.type && r.description == recommendation.description
    );
    
    if (existing.isEmpty) {
      _recommendations[widgetName]!.add(recommendation);
      
      if (recommendation.severity == Severity.critical) {
        debugPrint('🚨 CRITICAL: ${recommendation.description} in $widgetName');
      } else if (recommendation.severity == Severity.high) {
        debugPrint('⚠️ HIGH: ${recommendation.description} in $widgetName');
      }
    }
  }

  /// Start performance monitoring
  void _startPerformanceMonitoring() {
    _metricsReportTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _reportPerformanceMetrics();
    });
  }

  /// Start optimization analysis
  void _startOptimizationAnalysis() {
    _optimizationAnalysisTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _performOptimizationAnalysis();
    });
  }

  /// Report performance metrics
  void _reportPerformanceMetrics() {
    if (_widgetMetrics.isEmpty) return;

    final slowWidgets = _widgetMetrics.values.where((m) => m.slowBuilds > 0).length;
    final totalRebuilds = _widgetMetrics.values.fold(0, (sum, m) => sum + m.totalRebuilds);
    final averageBuildTime = _widgetMetrics.values
        .where((m) => m.averageBuildTime > 0)
        .fold(0.0, (sum, m) => sum + m.averageBuildTime) / 
        _widgetMetrics.values.where((m) => m.averageBuildTime > 0).length;

    debugPrint('📊 Widget Performance Report:');
    debugPrint('   Total widgets tracked: ${_widgetMetrics.length}');
    debugPrint('   Slow widgets: $slowWidgets');
    debugPrint('   Total rebuilds: $totalRebuilds');
    debugPrint('   Average build time: ${averageBuildTime.toStringAsFixed(2)}ms');
  }

  /// Perform optimization analysis
  void _performOptimizationAnalysis() {
    // Analyze widget patterns
    _analyzeWidgetPatterns();
    
    // Clean up old data
    _cleanupOldData();
    
    // Generate optimization report
    _generateOptimizationReport();
  }

  /// Analyze widget patterns for optimization opportunities
  void _analyzeWidgetPatterns() {
    for (final entry in _widgetMetrics.entries) {
      final widgetName = entry.key;
      final metrics = entry.value;
      
      // Check for widgets that rebuild too frequently
      if (metrics.totalRebuilds > 100) {
        final topReasons = metrics.rebuildReasons.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        if (topReasons.isNotEmpty) {
          _addOptimizationRecommendation(
            widgetName,
            OptimizationRecommendation(
              type: OptimizationType.frequentRebuilds,
              severity: Severity.medium,
              description: 'Widget rebuilds frequently (${metrics.totalRebuilds} times), mainly due to: ${topReasons.first.key}',
              suggestion: 'Consider optimizing the cause of rebuilds or using widget memoization',
            ),
          );
        }
      }
      
      // Check for consistently slow widgets
      if (metrics.averageBuildTime > 10.0) { // 10ms average
        _addOptimizationRecommendation(
          widgetName,
          OptimizationRecommendation(
            type: OptimizationType.consistentlySlow,
            severity: Severity.high,
            description: 'Widget has consistently slow build times (${metrics.averageBuildTime.toStringAsFixed(2)}ms average)',
            suggestion: 'Profile the widget build method and optimize expensive operations',
          ),
        );
      }
    }
  }

  /// Clean up old performance data
  void _cleanupOldData() {
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 1));
    
    // Clean up old rebuild history
    for (final entry in _rebuildHistory.entries) {
      entry.value.removeWhere((event) => event.timestamp.isBefore(cutoffTime));
    }
    
    // Remove empty entries
    _rebuildHistory.removeWhere((key, value) => value.isEmpty);
    
    // Clean up old recommendations (keep only recent ones)
    final recommendationCutoff = DateTime.now().subtract(const Duration(minutes: 30));
    for (final entry in _recommendations.entries) {
      entry.value.removeWhere((rec) => rec.timestamp.isBefore(recommendationCutoff));
    }
    _recommendations.removeWhere((key, value) => value.isEmpty);
  }

  /// Generate optimization report
  void _generateOptimizationReport() {
    final criticalIssues = _recommendations.values
        .expand((list) => list)
        .where((rec) => rec.severity == Severity.critical)
        .length;
    
    final highIssues = _recommendations.values
        .expand((list) => list)
        .where((rec) => rec.severity == Severity.high)
        .length;

    if (criticalIssues > 0) {
      debugPrint('🔍 Widget Optimization Report:');
      debugPrint('   Critical issues: $criticalIssues');
      debugPrint('   High priority issues: $highIssues');
      debugPrint('   Widgets needing attention: ${_recommendations.length}');
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStatistics() {
    final totalRebuilds = _widgetMetrics.values
        .fold(0, (sum, metrics) => sum + metrics.totalRebuilds);
    final slowWidgets = _widgetMetrics.values
        .where((m) => m.averageBuildTime > 16.0)
        .length;

    return {
      'totalWidgets': _widgetMetrics.length,
      'totalRebuilds': totalRebuilds,
      'slowWidgets': slowWidgets,
      'averageBuildTime': _calculateAverageBuildTime(),
      'activeInstances': _widgetInstanceCounts.length,
      'recommendations': _recommendations.length,
      'criticalIssues': _recommendations.values
          .expand((list) => list)
          .where((rec) => rec.severity == Severity.critical)
          .length,
    };
  }

  /// Get optimization recommendations
  List<OptimizationRecommendation> getRecommendations() {
    return _recommendations.values.expand((list) => list).toList();
  }

  /// Get recommendations for specific widget
  List<OptimizationRecommendation> getWidgetRecommendations(String widgetName) {
    return _recommendations[widgetName] ?? [];
  }

  /// Get widget metrics
  WidgetPerformanceMetrics? getWidgetMetrics(String widgetName) {
    return _widgetMetrics[widgetName];
  }

  /// Get all widget metrics
  Map<String, WidgetPerformanceMetrics> getAllMetrics() {
    return Map.from(_widgetMetrics);
  }

  /// Clear all performance data
  void clearAll() {
    _widgetMetrics.clear();
    _rebuildHistory.clear();
    _slowWidgets.clear();
    _widgetInstanceCounts.clear();
    _widgetCreationTimes.clear();
    _recommendations.clear();
    
    debugPrint('🗑️ Cleared all widget optimization data');
  }

  /// Dispose resources
  Future<void> dispose() async {
    _metricsReportTimer?.cancel();
    _optimizationAnalysisTimer?.cancel();
    clearAll();
    
    debugPrint('🔄 WidgetOptimizationService disposed');
  }

  /// Calculate average build time
  double _calculateAverageBuildTime() {
    final allTimes = _widgetMetrics.values
        .where((m) => m.averageBuildTime > 0)
        .map((m) => m.averageBuildTime)
        .toList();
    
    if (allTimes.isEmpty) return 0.0;
    return allTimes.reduce((a, b) => a + b) / allTimes.length;
  }
}

/// Widget performance metrics
class WidgetPerformanceMetrics {
  final String widgetName;
  int totalRebuilds = 0;
  int slowBuilds = 0;
  DateTime? lastRebuildTime;
  double averageBuildTime = 0.0;
  final List<double> buildTimes = [];
  final Map<String, int> rebuildReasons = {};

  WidgetPerformanceMetrics({required this.widgetName});

  Map<String, dynamic> toMap() {
    return {
      'widgetName': widgetName,
      'totalRebuilds': totalRebuilds,
      'slowBuilds': slowBuilds,
      'lastRebuildTime': lastRebuildTime?.toIso8601String(),
      'averageBuildTime': averageBuildTime,
      'rebuildReasons': rebuildReasons,
    };
  }
}

/// Rebuild event
class RebuildEvent {
  final DateTime timestamp;
  final String reason;
  final Duration? buildTime;
  final Map<String, dynamic>? context;

  const RebuildEvent({
    required this.timestamp,
    required this.reason,
    this.buildTime,
    this.context,
  });
}

/// Optimization recommendation
class OptimizationRecommendation {
  final OptimizationType type;
  final Severity severity;
  final String description;
  final String suggestion;
  final DateTime timestamp;

  OptimizationRecommendation({
    required this.type,
    required this.severity,
    required this.description,
    required this.suggestion,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'severity': severity.name,
      'description': description,
      'suggestion': suggestion,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Optimization types
enum OptimizationType {
  excessiveRebuilds,
  slowBuild,
  memoryLeak,
  frequentRebuilds,
  consistentlySlow,
}

/// Severity levels
enum Severity {
  low,
  medium,
  high,
  critical,
}