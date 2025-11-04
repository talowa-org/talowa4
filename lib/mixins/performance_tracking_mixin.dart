// Performance Tracking Mixin - Automatic widget performance monitoring
// Mixin for tracking widget rebuilds and performance metrics in TALOWA platform

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/performance/widget_optimization_service.dart';

/// Mixin for automatic performance tracking in widgets
mixin PerformanceTrackingMixin<T extends StatefulWidget> on State<T> {
  // Performance tracking
  DateTime? _buildStartTime;
  int _buildCount = 0;
  String? _lastRebuildReason;
  Timer? _rebuildThrottleTimer;
  
  // Configuration
  static const Duration rebuildThrottleDuration = Duration(milliseconds: 100);
  static const bool enablePerformanceTracking = kDebugMode;
  
  /// Widget name for tracking (override in implementing widgets)
  String get performanceWidgetName => widget.runtimeType.toString();
  
  /// Whether to enable performance tracking for this widget
  bool get enableTracking => enablePerformanceTracking;
  
  /// Additional context for performance tracking
  Map<String, dynamic>? get performanceContext => null;
  
  @override
  void initState() {
    super.initState();
    
    if (enableTracking) {
      _trackWidgetLifecycle('initState');
      
      // Schedule post-frame callback to track initial build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trackRebuild('initial_build');
      });
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (enableTracking) {
      _trackRebuild('dependencies_changed');
    }
  }
  
  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (enableTracking) {
      _trackRebuild('widget_updated');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (enableTracking) {
      _buildStartTime = DateTime.now();
      _buildCount++;
    }
    
    // Call the actual build method
    final widget = performanceBuild(context);
    
    if (enableTracking) {
      // Schedule post-frame callback to measure build time
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureBuildTime();
      });
    }
    
    return widget;
  }
  
  /// Override this method instead of build() when using the mixin
  Widget performanceBuild(BuildContext context);
  
  @override
  void dispose() {
    if (enableTracking) {
      _trackWidgetLifecycle('dispose');
      _rebuildThrottleTimer?.cancel();
    }
    
    super.dispose();
  }
  
  /// Manually track a rebuild with a specific reason
  void trackRebuild(String reason, {Map<String, dynamic>? context}) {
    if (enableTracking) {
      _trackRebuild(reason, context: context);
    }
  }
  
  /// Track setState calls
  @override
  void setState(VoidCallback fn) {
    if (enableTracking) {
      _trackRebuild('setState_called');
    }
    
    super.setState(fn);
  }
  
  /// Internal method to track rebuilds
  void _trackRebuild(String reason, {Map<String, dynamic>? context}) {
    // Throttle rebuild tracking to avoid spam
    _rebuildThrottleTimer?.cancel();
    _rebuildThrottleTimer = Timer(rebuildThrottleDuration, () {
      _lastRebuildReason = reason;
      
      final combinedContext = <String, dynamic>{
        'buildCount': _buildCount,
        'widgetHashCode': widget.hashCode,
        'stateHashCode': hashCode,
        ...?performanceContext,
        ...?context,
      };
      
      WidgetOptimizationService.instance.trackRebuild(
        performanceWidgetName,
        reason: reason,
        context: combinedContext,
      );
    });
  }
  
  /// Track widget lifecycle events
  void _trackWidgetLifecycle(String event) {
    debugPrint('🔄 Widget lifecycle: $performanceWidgetName.$event');
  }
  
  /// Measure build time after frame is rendered
  void _measureBuildTime() {
    if (_buildStartTime != null) {
      final buildTime = DateTime.now().difference(_buildStartTime!);
      
      WidgetOptimizationService.instance.trackRebuild(
        performanceWidgetName,
        reason: _lastRebuildReason ?? 'build_completed',
        buildTime: buildTime,
        context: {
          'buildCount': _buildCount,
          'buildTimeMs': buildTime.inMicroseconds / 1000.0,
          ...?performanceContext,
        },
      );
      
      // Log slow builds
      if (buildTime.inMilliseconds > 16) {
        debugPrint('⚠️ Slow build detected: $performanceWidgetName (${buildTime.inMilliseconds}ms)');
      }
      
      _buildStartTime = null;
    }
  }
}

/// Mixin for performance tracking in StatelessWidgets (via wrapper)
mixin StatelessPerformanceTrackingMixin on StatelessWidget {
  /// Widget name for tracking
  String get performanceWidgetName => runtimeType.toString();
  
  /// Whether to enable performance tracking
  bool get enableTracking => kDebugMode;
  
  /// Additional context for performance tracking
  Map<String, dynamic>? get performanceContext => null;
  
  @override
  Widget build(BuildContext context) {
    if (enableTracking) {
      return _PerformanceTrackingWrapper(
        widgetName: performanceWidgetName,
        context: performanceContext,
        child: performanceBuild(context),
      );
    }
    
    return performanceBuild(context);
  }
  
  /// Override this method instead of build() when using the mixin
  Widget performanceBuild(BuildContext context);
}

/// Wrapper widget for tracking StatelessWidget performance
class _PerformanceTrackingWrapper extends StatefulWidget {
  final String widgetName;
  final Map<String, dynamic>? context;
  final Widget child;
  
  const _PerformanceTrackingWrapper({
    required this.widgetName,
    required this.child,
    this.context,
  });
  
  @override
  State<_PerformanceTrackingWrapper> createState() => _PerformanceTrackingWrapperState();
}

class _PerformanceTrackingWrapperState extends State<_PerformanceTrackingWrapper> {
  DateTime? _buildStartTime;
  int _buildCount = 0;
  
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetOptimizationService.instance.trackRebuild(
        widget.widgetName,
        reason: 'initial_build',
        context: widget.context,
      );
    });
  }
  
  @override
  void didUpdateWidget(_PerformanceTrackingWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    WidgetOptimizationService.instance.trackRebuild(
      widget.widgetName,
      reason: 'widget_updated',
      context: widget.context,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    _buildStartTime = DateTime.now();
    _buildCount++;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_buildStartTime != null) {
        final buildTime = DateTime.now().difference(_buildStartTime!);
        
        WidgetOptimizationService.instance.trackRebuild(
          widget.widgetName,
          reason: 'build_completed',
          buildTime: buildTime,
          context: {
            'buildCount': _buildCount,
            'buildTimeMs': buildTime.inMicroseconds / 1000.0,
            ...?widget.context,
          },
        );
        
        _buildStartTime = null;
      }
    });
    
    return widget.child;
  }
}

/// Mixin for tracking expensive operations in widgets
mixin ExpensiveOperationTrackingMixin<T extends StatefulWidget> on State<T> {
  final Map<String, DateTime> _operationStartTimes = {};
  
  /// Track the start of an expensive operation
  void startExpensiveOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
    debugPrint('🚀 Started expensive operation: $operationName in ${widget.runtimeType}');
  }
  
  /// Track the end of an expensive operation
  void endExpensiveOperation(String operationName) {
    final startTime = _operationStartTimes.remove(operationName);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      
      debugPrint('✅ Completed expensive operation: $operationName in ${widget.runtimeType} (${duration.inMilliseconds}ms)');
      
      // Log slow operations
      if (duration.inMilliseconds > 100) {
        debugPrint('⚠️ Slow operation detected: $operationName (${duration.inMilliseconds}ms)');
      }
      
      // Track with widget optimization service
      WidgetOptimizationService.instance.trackRebuild(
        widget.runtimeType.toString(),
        reason: 'expensive_operation_completed',
        buildTime: duration,
        context: {
          'operationName': operationName,
          'operationTimeMs': duration.inMilliseconds,
        },
      );
    }
  }
  
  /// Execute an expensive operation with automatic tracking
  Future<T> trackExpensiveOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    startExpensiveOperation(operationName);
    
    try {
      final result = await operation();
      endExpensiveOperation(operationName);
      return result;
    } catch (e) {
      endExpensiveOperation(operationName);
      debugPrint('❌ Expensive operation failed: $operationName - $e');
      rethrow;
    }
  }
  
  @override
  void dispose() {
    // Clean up any pending operations
    for (final operationName in _operationStartTimes.keys) {
      debugPrint('⚠️ Disposing widget with pending operation: $operationName');
    }
    _operationStartTimes.clear();
    
    super.dispose();
  }
}

/// Mixin for tracking memory usage in widgets
mixin MemoryTrackingMixin<T extends StatefulWidget> on State<T> {
  final List<Object> _trackedObjects = [];
  
  /// Track an object for memory monitoring
  void trackObject(Object object, {String? description}) {
    _trackedObjects.add(object);
    
    if (kDebugMode) {
      debugPrint('📝 Tracking object in ${widget.runtimeType}: ${description ?? object.runtimeType}');
    }
  }
  
  /// Untrack an object
  void untrackObject(Object object) {
    _trackedObjects.remove(object);
  }
  
  /// Get current tracked object count
  int get trackedObjectCount => _trackedObjects.length;
  
  @override
  void dispose() {
    if (_trackedObjects.isNotEmpty) {
      debugPrint('⚠️ Disposing widget with ${_trackedObjects.length} tracked objects: ${widget.runtimeType}');
    }
    
    _trackedObjects.clear();
    super.dispose();
  }
}

/// Extension for easy performance tracking on any widget
extension PerformanceTrackingExtension on Widget {
  /// Wrap widget with performance tracking
  Widget withPerformanceTracking({
    String? name,
    Map<String, dynamic>? context,
  }) {
    if (!kDebugMode) return this;
    
    return _PerformanceTrackingWrapper(
      widgetName: name ?? runtimeType.toString(),
      context: context,
      child: this,
    );
  }
}