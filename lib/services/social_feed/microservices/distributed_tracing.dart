// Distributed Tracing - Microservices Request Tracking
// Tracks requests across multiple services for debugging and monitoring
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Trace context for distributed tracing
class TraceContext {
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final Map<String, String> baggage;
  final DateTime startTime;

  TraceContext({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    this.baggage = const {},
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  /// Create child span
  TraceContext createChild(String operationName) {
    return TraceContext(
      traceId: traceId,
      spanId: _generateSpanId(),
      parentSpanId: spanId,
      baggage: Map.from(baggage),
    );
  }

  /// Add baggage item
  TraceContext withBaggage(String key, String value) {
    final newBaggage = Map<String, String>.from(baggage);
    newBaggage[key] = value;
    
    return TraceContext(
      traceId: traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      baggage: newBaggage,
      startTime: startTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'traceId': traceId,
    'spanId': spanId,
    'parentSpanId': parentSpanId,
    'baggage': baggage,
    'startTime': startTime.toIso8601String(),
  };

  static String _generateSpanId() {
    final random = Random();
    return random.nextInt(0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
  }
}

/// Span represents a single operation in a trace
class Span {
  final TraceContext context;
  final String operationName;
  final String serviceName;
  final DateTime startTime;
  final Map<String, dynamic> tags;
  final List<SpanLog> logs;
  
  DateTime? endTime;
  String? status;
  String? error;

  Span({
    required this.context,
    required this.operationName,
    required this.serviceName,
    DateTime? startTime,
    this.tags = const {},
  }) : startTime = startTime ?? DateTime.now(),
       logs = [];

  /// Duration of the span
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Add tag to span
  void setTag(String key, dynamic value) {
    (tags as Map<String, dynamic>)[key] = value;
  }

  /// Add log entry
  void log(String message, {Map<String, dynamic>? fields}) {
    logs.add(SpanLog(
      timestamp: DateTime.now(),
      message: message,
      fields: fields ?? {},
    ));
  }

  /// Mark span as finished
  void finish({String? status, String? error}) {
    endTime = DateTime.now();
    this.status = status ?? 'ok';
    this.error = error;
  }

  Map<String, dynamic> toJson() => {
    'context': context.toJson(),
    'operationName': operationName,
    'serviceName': serviceName,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'duration': duration.inMicroseconds,
    'status': status,
    'error': error,
    'tags': tags,
    'logs': logs.map((log) => log.toJson()).toList(),
  };
}

/// Log entry within a span
class SpanLog {
  final DateTime timestamp;
  final String message;
  final Map<String, dynamic> fields;

  SpanLog({
    required this.timestamp,
    required this.message,
    required this.fields,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'message': message,
    'fields': fields,
  };
}

/// Distributed tracing system
class DistributedTracing {
  static DistributedTracing? _instance;
  static DistributedTracing get instance => _instance ??= DistributedTracing._internal();
  
  DistributedTracing._internal();

  // Active spans
  final Map<String, Span> _activeSpans = {};
  final List<Span> _completedSpans = [];
  
  // Current trace context (thread-local equivalent)
  TraceContext? _currentContext;
  
  // Configuration
  bool _enabled = true;
  int _maxSpansInMemory = 1000;
  Duration _spanRetentionTime = const Duration(hours: 1);
  
  // Cleanup timer
  Timer? _cleanupTimer;

  /// Initialize distributed tracing
  Future<void> initialize({
    bool enabled = true,
    int maxSpansInMemory = 1000,
    Duration spanRetentionTime = const Duration(hours: 1),
  }) async {
    _enabled = enabled;
    _maxSpansInMemory = maxSpansInMemory;
    _spanRetentionTime = spanRetentionTime;

    if (_enabled) {
      // Start cleanup timer
      _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
        _cleanup();
      });

      debugPrint('✅ Distributed Tracing initialized');
    }
  }

  /// Start a new trace
  TraceContext startTrace(String operationName, {
    String? serviceName,
    Map<String, String>? baggage,
  }) {
    if (!_enabled) {
      return TraceContext(traceId: 'disabled', spanId: 'disabled');
    }

    final traceId = _generateTraceId();
    final spanId = _generateSpanId();
    
    final context = TraceContext(
      traceId: traceId,
      spanId: spanId,
      baggage: baggage ?? {},
    );

    _currentContext = context;
    
    final span = Span(
      context: context,
      operationName: operationName,
      serviceName: serviceName ?? 'unknown',
    );

    _activeSpans[spanId] = span;
    
    debugPrint('🔍 Started trace: $traceId, span: $spanId, operation: $operationName');
    return context;
  }

  /// Start a child span
  TraceContext startSpan(String operationName, {
    TraceContext? parentContext,
    String? serviceName,
  }) {
    if (!_enabled) {
      return TraceContext(traceId: 'disabled', spanId: 'disabled');
    }

    final parent = parentContext ?? _currentContext;
    if (parent == null) {
      return startTrace(operationName, serviceName: serviceName);
    }

    final childContext = parent.createChild(operationName);
    _currentContext = childContext;
    
    final span = Span(
      context: childContext,
      operationName: operationName,
      serviceName: serviceName ?? 'unknown',
    );

    _activeSpans[childContext.spanId] = span;
    
    debugPrint('🔍 Started span: ${childContext.spanId}, operation: $operationName, parent: ${parent.spanId}');
    return childContext;
  }

  /// Finish a span
  void finishSpan(TraceContext context, {
    String? status,
    String? error,
    Map<String, dynamic>? tags,
  }) {
    if (!_enabled) return;

    final span = _activeSpans[context.spanId];
    if (span == null) {
      debugPrint('⚠️ Span not found: ${context.spanId}');
      return;
    }

    // Add tags if provided
    if (tags != null) {
      for (final entry in tags.entries) {
        span.setTag(entry.key, entry.value);
      }
    }

    // Finish the span
    span.finish(status: status, error: error);
    
    // Move to completed spans
    _activeSpans.remove(context.spanId);
    _completedSpans.add(span);
    
    // Restore parent context
    if (span.context.parentSpanId != null) {
      final parentSpan = _activeSpans[span.context.parentSpanId];
      if (parentSpan != null) {
        _currentContext = parentSpan.context;
      }
    } else {
      _currentContext = null;
    }

    debugPrint('🔍 Finished span: ${context.spanId}, duration: ${span.duration.inMilliseconds}ms');
  }

  /// Add tag to current span
  void setTag(String key, dynamic value) {
    if (!_enabled || _currentContext == null) return;

    final span = _activeSpans[_currentContext!.spanId];
    span?.setTag(key, value);
  }

  /// Add log to current span
  void log(String message, {Map<String, dynamic>? fields}) {
    if (!_enabled || _currentContext == null) return;

    final span = _activeSpans[_currentContext!.spanId];
    span?.log(message, fields: fields);
  }

  /// Get current trace context
  TraceContext? getCurrentContext() => _currentContext;

  /// Execute function with tracing
  Future<T> trace<T>(
    String operationName,
    Future<T> Function(TraceContext context) operation, {
    String? serviceName,
    Map<String, dynamic>? tags,
  }) async {
    final context = startSpan(operationName, serviceName: serviceName);
    
    try {
      // Add initial tags
      if (tags != null) {
        for (final entry in tags.entries) {
          setTag(entry.key, entry.value);
        }
      }

      final result = await operation(context);
      finishSpan(context, status: 'ok');
      return result;
      
    } catch (error) {
      log('Error occurred', fields: {'error': error.toString()});
      finishSpan(context, status: 'error', error: error.toString());
      rethrow;
    }
  }

  /// Get trace by ID
  List<Span> getTrace(String traceId) {
    final traceSpans = <Span>[];
    
    // Check active spans
    for (final span in _activeSpans.values) {
      if (span.context.traceId == traceId) {
        traceSpans.add(span);
      }
    }
    
    // Check completed spans
    for (final span in _completedSpans) {
      if (span.context.traceId == traceId) {
        traceSpans.add(span);
      }
    }
    
    // Sort by start time
    traceSpans.sort((a, b) => a.startTime.compareTo(b.startTime));
    return traceSpans;
  }

  /// Get all traces
  Map<String, List<Span>> getAllTraces() {
    final traces = <String, List<Span>>{};
    
    // Collect all spans
    final allSpans = <Span>[];
    allSpans.addAll(_activeSpans.values);
    allSpans.addAll(_completedSpans);
    
    // Group by trace ID
    for (final span in allSpans) {
      traces[span.context.traceId] ??= [];
      traces[span.context.traceId]!.add(span);
    }
    
    // Sort spans within each trace
    for (final spans in traces.values) {
      spans.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    
    return traces;
  }

  /// Get tracing statistics
  Map<String, dynamic> getStatistics() {
    final now = DateTime.now();
    final recentSpans = _completedSpans.where(
      (span) => now.difference(span.startTime) < const Duration(minutes: 5),
    ).toList();

    final averageDuration = recentSpans.isNotEmpty
        ? recentSpans.fold<int>(0, (sum, span) => sum + span.duration.inMicroseconds) / recentSpans.length
        : 0;

    final errorCount = recentSpans.where((span) => span.status == 'error').length;

    return {
      'enabled': _enabled,
      'activeSpans': _activeSpans.length,
      'completedSpans': _completedSpans.length,
      'recentSpans': recentSpans.length,
      'averageDuration': averageDuration,
      'errorRate': recentSpans.isNotEmpty ? errorCount / recentSpans.length : 0.0,
      'memoryUsage': _completedSpans.length,
      'maxMemory': _maxSpansInMemory,
    };
  }

  /// Cleanup old spans
  void _cleanup() {
    final cutoff = DateTime.now().subtract(_spanRetentionTime);
    
    final initialCount = _completedSpans.length;
    _completedSpans.removeWhere((span) => span.startTime.isBefore(cutoff));
    
    // Also enforce memory limit
    if (_completedSpans.length > _maxSpansInMemory) {
      _completedSpans.sort((a, b) => b.startTime.compareTo(a.startTime));
      _completedSpans.removeRange(_maxSpansInMemory, _completedSpans.length);
    }

    final removedCount = initialCount - _completedSpans.length;
    if (removedCount > 0) {
      debugPrint('🧹 Cleaned up $removedCount old spans');
    }
  }

  /// Generate trace ID
  String _generateTraceId() {
    final random = Random();
    final high = random.nextInt(0x7FFFFFFF);
    final low = random.nextInt(0x7FFFFFFF);
    return '${high.toRadixString(16).padLeft(8, '0')}${low.toRadixString(16).padLeft(8, '0')}';
  }

  /// Generate span ID
  String _generateSpanId() {
    final random = Random();
    return random.nextInt(0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _activeSpans.clear();
    _completedSpans.clear();
    _currentContext = null;
  }
}