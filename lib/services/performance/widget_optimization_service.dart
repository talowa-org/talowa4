// Widget Optimization Service - UI performance optimization and rebuild management
// Comprehensive widget performance optimization for TALOWA platform

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Service for optimizing widget performance and managing rebuilds
class WidgetOptimizationService {
  static WidgetOptimizationService? _instance;
  static WidgetOptimizationService get instance => _instance ??= WidgetOptimizationService._internal();
  
  WidgetOptimizationService._internal();
  
  // Performance tracking
  final Map<String, WidgetPerformanceMetrics> _widgetMetrics = {};
  final Queue<RebuildEvent> _rebuildHistory = Queue<RebuildEvent>();
  final Set<String> _optimizedWidgets = {};
  
  // Frame monitoring
  Timer? _frameMonitoringTimer;
  int _droppedFrames = 0;
  int _totalFrames = 0;
  double _averageFrameTime = 0.0;
  
  // Configuration
  static const Duration monitoringInterval = Duration(seconds: 5);
  static const int maxRebuildHistorySize = 100;
  static const double targetFrameTime = 16.67; // 60 FPS
  static const int frameDropThreshold = 3;
  
  /// Initialize widget optimization service
  static Future<void> initialize() async {
    try {
      debugPrint('🎨 Initializing Widget Optimization Service...');
      
      final service = instance;
      
      // Start frame monitoring
      service._startFrameMonitoring();
      
      // Setup rebuild tracking
      service._setupRebuildTracking();
      
      // Initialize performance observers
      service._initializePerformanceObservers();
      
      debugPrint('✅ Widget Optimization Service initialized');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize widget optimization: $e');
    }
  }
  
  /// Track widget rebuild
  void trackRebuild(String widgetName, {
    String? reason,
    Duration? buildTime,
    Map<String, dynamic>? context,
  }) {
    final event = RebuildEvent(
      widgetName: widgetName,
      timestamp: DateTime.now(),
      reason: reason,
      buildTime: buildTime,
      context: context,
    );
    
    // Add to history
    _rebuildHistory.addLast(event);
    if (_rebuildHistory.length > maxRebuildHistorySize) {
      _rebuildHistory.removeFirst();
    }
    
    // Update metrics
    _updateWidgetMetrics(widgetName, event);
    
    // Check for excessive rebuilds
    _checkExcessiveRebuilds(widgetName);
    
    if (kDebugMode) {
      debugPrint('🔄 Widget rebuild: $widgetName${reason != null ? ' ($reason)' : ''}');
    }
  }
  
  /// Mark widget as optimized
  void markWidgetOptimized(String widgetName, List<String> optimizations) {
    _optimizedWidgets.add(widgetName);
    
    debugPrint('✅ Widget optimized: $widgetName');
    debugPrint('   Optimizations: ${optimizations.join(', ')}');
  }
  
  /// Get widget performance metrics
  WidgetPerformanceMetrics? getWidgetMetrics(String widgetName) {
    return _widgetMetrics[widgetName];
  }
  
  /// Get all widget metrics
  Map<String, WidgetPerformanceMetrics> getAllWidgetMetrics() {
    return Map.unmodifiable(_widgetMetrics);
  }
  
  /// Get rebuild history
  List<RebuildEvent> getRebuildHistory({String? widgetName, int? limit}) {
    var history = _rebuildHistory.toList();
    
    if (widgetName != null) {
      history = history.where((event) => event.widgetName == widgetName).toList();
    }
    
    if (limit != null && limit > 0) {
      history = history.take(limit).toList();
    }
    
    return history.reversed.toList(); // Most recent first
  }
  
  /// Get performance statistics
  Map<String, dynamic> getPerformanceStatistics() {
    final excessiveRebuildWidgets = _widgetMetrics.entries
        .where((entry) => entry.value.isExcessiveRebuilding)
        .map((entry) => entry.key)
        .toList();
    
    final slowBuildWidgets = _widgetMetrics.entries
        .where((entry) => entry.value.averageBuildTime > 10.0)
        .map((entry) => entry.key)
        .toList();
    
    return {
      'totalTrackedWidgets': _widgetMetrics.length,
      'optimizedWidgets': _optimizedWidgets.length,
      'totalRebuilds': _rebuildHistory.length,
      'droppedFrames': _droppedFrames,
      'totalFrames': _totalFrames,
      'averageFrameTime': _averageFrameTime,
      'frameDropRate': _totalFrames > 0 ? (_droppedFrames / _totalFrames) * 100 : 0.0,
      'excessiveRebuildWidgets': excessiveRebuildWidgets,
      'slowBuildWidgets': slowBuildWidgets,
      'performanceScore': _calculatePerformanceScore(),
    };
  }
  
  /// Generate optimization recommendations
  List<OptimizationRecommendation> generateRecommendations() {
    final recommendations = <OptimizationRecommendation>[];
    
    // Check for excessive rebuilds
    for (final entry in _widgetMetrics.entries) {
      final widgetName = entry.key;
      final metrics = entry.value;
      
      if (metrics.isExcessiveRebuilding && !_optimizedWidgets.contains(widgetName)) {
        recommendations.add(OptimizationRecommendation(
          widgetName: widgetName,
          type: OptimizationType.excessiveRebuilds,
          priority: RecommendationPriority.high,
          description: 'Widget rebuilds ${metrics.rebuildCount} times (${metrics.rebuildsPerMinute.toStringAsFixed(1)}/min)',
          suggestions: [
            'Use const constructors where possible',
            'Implement shouldRebuild logic',
            'Split widget into smaller components',
            'Use ValueListenableBuilder or similar for targeted updates',
            'Check for unnecessary setState calls',
          ],
          metrics: metrics,
        ));
      }
      
      if (metrics.averageBuildTime > 10.0 && !_optimizedWidgets.contains(widgetName)) {
        recommendations.add(OptimizationRecommendation(
          widgetName: widgetName,
          type: OptimizationType.slowBuild,
          priority: RecommendationPriority.medium,
          description: 'Average build time: ${metrics.averageBuildTime.toStringAsFixed(2)}ms',
          suggestions: [
            'Optimize expensive operations in build method',
            'Move heavy computations to initState or didChangeDependencies',
            'Use FutureBuilder or StreamBuilder for async operations',
            'Consider lazy loading for complex widgets',
            'Profile widget tree depth and complexity',
          ],
          metrics: metrics,
        ));
      }
    }
    
    // Check frame performance
    if (_droppedFrames > frameDropThreshold) {
      recommendations.add(OptimizationRecommendation(
        widgetName: 'Global',
        type: OptimizationType.frameDrops,
        priority: RecommendationPriority.critical,
        description: 'Dropped ${_droppedFrames} frames (${((_droppedFrames / _totalFrames) * 100).toStringAsFixed(1)}%)',
        suggestions: [
          'Reduce widget tree complexity',
          'Optimize image loading and caching',
          'Use RepaintBoundary for expensive widgets',
          'Implement proper list virtualization',
          'Profile and optimize animation performance',
        ],
      ));
    }
    
    return recommendations..sort((a, b) => b.priority.index.compareTo(a.priority.index));
  }
  
  /// Start frame monitoring
  void _startFrameMonitoring() {
    if (kDebugMode) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    }
    
    _frameMonitoringTimer = Timer.periodic(monitoringInterval, (timer) {
      _analyzeFramePerformance();
    });
    
    debugPrint('📊 Frame monitoring started');
  }
  
  /// Handle frame timings
  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _totalFrames++;
      
      final frameTime = timing.totalSpan.inMicroseconds / 1000.0; // Convert to milliseconds
      _averageFrameTime = ((_averageFrameTime * (_totalFrames - 1)) + frameTime) / _totalFrames;
      
      if (frameTime > targetFrameTime) {
        _droppedFrames++;
      }
    }
  }
  
  /// Analyze frame performance
  void _analyzeFramePerformance() {
    if (_totalFrames == 0) return;
    
    final frameDropRate = (_droppedFrames / _totalFrames) * 100;
    
    if (frameDropRate > 5.0) {
      debugPrint('⚠️ High frame drop rate: ${frameDropRate.toStringAsFixed(1)}%');
    }
    
    if (_averageFrameTime > targetFrameTime * 1.5) {
      debugPrint('⚠️ High average frame time: ${_averageFrameTime.toStringAsFixed(2)}ms');
    }
  }
  
  /// Setup rebuild tracking
  void _setupRebuildTracking() {
    // This would typically integrate with Flutter's widget inspector
    // For now, we rely on manual tracking calls
    debugPrint('🔍 Rebuild tracking setup completed');
  }
  
  /// Initialize performance observers
  void _initializePerformanceObservers() {
    if (kDebugMode) {
      // Setup additional performance observers
      WidgetsBinding.instance.addObserver(_WidgetLifecycleObserver(this));
    }
  }
  
  /// Update widget metrics
  void _updateWidgetMetrics(String widgetName, RebuildEvent event) {
    final metrics = _widgetMetrics.putIfAbsent(
      widgetName,
      () => WidgetPerformanceMetrics(widgetName: widgetName),
    );
    
    metrics.recordRebuild(event);
  }
  
  /// Check for excessive rebuilds
  void _checkExcessiveRebuilds(String widgetName) {
    final metrics = _widgetMetrics[widgetName];
    if (metrics != null && metrics.isExcessiveRebuilding) {
      debugPrint('⚠️ Excessive rebuilds detected for: $widgetName (${metrics.rebuildCount} rebuilds)');
    }
  }
  
  /// Calculate overall performance score
  double _calculatePerformanceScore() {
    double score = 100.0;
    
    // Penalize frame drops
    final frameDropRate = _totalFrames > 0 ? (_droppedFrames / _totalFrames) * 100 : 0.0;
    score -= frameDropRate * 2; // 2 points per percent of dropped frames
    
    // Penalize excessive rebuilds
    final excessiveRebuildCount = _widgetMetrics.values
        .where((metrics) => metrics.isExcessiveRebuilding)
        .length;
    score -= excessiveRebuildCount * 5; // 5 points per widget with excessive rebuilds
    
    // Penalize slow builds
    final slowBuildCount = _widgetMetrics.values
        .where((metrics) => metrics.averageBuildTime > 10.0)
        .length;
    score -= slowBuildCount * 3; // 3 points per slow widget
    
    return score.clamp(0.0, 100.0);
  }
  
  /// Dispose widget optimization service
  Future<void> dispose() async {
    debugPrint('🧹 Disposing Widget Optimization Service...');
    
    _frameMonitoringTimer?.cancel();
    _widgetMetrics.clear();
    _rebuildHistory.clear();
    _optimizedWidgets.clear();
    
    debugPrint('✅ Widget Optimization Service disposed');
  }
}

/// Widget performance metrics
class WidgetPerformanceMetrics {
  final String widgetName;
  final DateTime createdAt;
  
  int rebuildCount = 0;
  double totalBuildTime = 0.0;
  DateTime? lastRebuildTime;
  final List<String> rebuildReasons = [];
  
  WidgetPerformanceMetrics({required this.widgetName}) : createdAt = DateTime.now();
  
  /// Record a rebuild event
  void recordRebuild(RebuildEvent event) {
    rebuildCount++;
    lastRebuildTime = event.timestamp;
    
    if (event.buildTime != null) {
      totalBuildTime += event.buildTime!.inMicroseconds / 1000.0; // Convert to milliseconds
    }
    
    if (event.reason != null && !rebuildReasons.contains(event.reason!)) {
      rebuildReasons.add(event.reason!);
    }
  }
  
  /// Average build time in milliseconds
  double get averageBuildTime {
    return rebuildCount > 0 ? totalBuildTime / rebuildCount : 0.0;
  }
  
  /// Rebuilds per minute
  double get rebuildsPerMinute {
    final duration = DateTime.now().difference(createdAt);
    final minutes = duration.inMilliseconds / 60000.0;
    return minutes > 0 ? rebuildCount / minutes : 0.0;
  }
  
  /// Check if widget has excessive rebuilds
  bool get isExcessiveRebuilding {
    return rebuildsPerMinute > 10.0 || rebuildCount > 50;
  }
  
  Map<String, dynamic> toMap() {
    return {
      'widgetName': widgetName,
      'rebuildCount': rebuildCount,
      'averageBuildTime': averageBuildTime,
      'rebuildsPerMinute': rebuildsPerMinute,
      'lastRebuildTime': lastRebuildTime?.toIso8601String(),
      'rebuildReasons': rebuildReasons,
      'isExcessiveRebuilding': isExcessiveRebuilding,
    };
  }
}

/// Rebuild event
class RebuildEvent {
  final String widgetName;
  final DateTime timestamp;
  final String? reason;
  final Duration? buildTime;
  final Map<String, dynamic>? context;
  
  RebuildEvent({
    required this.widgetName,
    required this.timestamp,
    this.reason,
    this.buildTime,
    this.context,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'widgetName': widgetName,
      'timestamp': timestamp.toIso8601String(),
      'reason': reason,
      'buildTimeMs': buildTime?.inMicroseconds != null ? buildTime!.inMicroseconds / 1000.0 : null,
      'context': context,
    };
  }
}

/// Optimization recommendation
class OptimizationRecommendation {
  final String widgetName;
  final OptimizationType type;
  final RecommendationPriority priority;
  final String description;
  final List<String> suggestions;
  final WidgetPerformanceMetrics? metrics;
  
  OptimizationRecommendation({
    required this.widgetName,
    required this.type,
    required this.priority,
    required this.description,
    required this.suggestions,
    this.metrics,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'widgetName': widgetName,
      'type': type.toString(),
      'priority': priority.toString(),
      'description': description,
      'suggestions': suggestions,
      'metrics': metrics?.toMap(),
    };
  }
}

/// Optimization types
enum OptimizationType {
  excessiveRebuilds,
  slowBuild,
  frameDrops,
  memoryLeak,
  inefficientLayout,
}

/// Recommendation priorities
enum RecommendationPriority {
  low,
  medium,
  high,
  critical,
}

/// Widget lifecycle observer
class _WidgetLifecycleObserver extends WidgetsBindingObserver {
  final WidgetOptimizationService _service;
  
  _WidgetLifecycleObserver(this._service);
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // App is paused, good time to analyze performance
      final stats = _service.getPerformanceStatistics();
      debugPrint('📊 Performance stats on pause: $stats');
    }
  }
}