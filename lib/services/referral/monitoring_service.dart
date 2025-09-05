import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Exception thrown when monitoring operations fail
class MonitoringException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const MonitoringException(this.message, [this.code = 'MONITORING_FAILED', this.context]);
  
  @override
  String toString() => 'MonitoringException: $message';
}

/// Monitoring levels
enum MonitoringLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Performance metrics data model
class PerformanceMetrics {
  final String id;
  final String operation;
  final DateTime timestamp;
  final Duration duration;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic> metadata;
  final String userId;
  final String sessionId;

  const PerformanceMetrics({
    required this.id,
    required this.operation,
    required this.timestamp,
    required this.duration,
    required this.success,
    this.errorMessage,
    required this.metadata,
    required this.userId,
    required this.sessionId,
  });

  factory PerformanceMetrics.fromMap(Map<String, dynamic> map) {
    return PerformanceMetrics(
      id: map['id'] ?? '',
      operation: map['operation'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      duration: Duration(milliseconds: map['durationMs'] ?? 0),
      success: map['success'] ?? false,
      errorMessage: map['errorMessage'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      userId: map['userId'] ?? '',
      sessionId: map['sessionId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operation': operation,
      'timestamp': Timestamp.fromDate(timestamp),
      'durationMs': duration.inMilliseconds,
      'success': success,
      'errorMessage': errorMessage,
      'metadata': metadata,
      'userId': userId,
      'sessionId': sessionId,
    };
  }
}

/// Error tracking data model
class ErrorEvent {
  final String id;
  final String errorType;
  final String message;
  final String? stackTrace;
  final DateTime timestamp;
  final MonitoringLevel level;
  final String operation;
  final String userId;
  final String sessionId;
  final Map<String, dynamic> context;
  final bool isResolved;
  final DateTime? resolvedAt;

  const ErrorEvent({
    required this.id,
    required this.errorType,
    required this.message,
    this.stackTrace,
    required this.timestamp,
    required this.level,
    required this.operation,
    required this.userId,
    required this.sessionId,
    required this.context,
    required this.isResolved,
    this.resolvedAt,
  });

  factory ErrorEvent.fromMap(Map<String, dynamic> map) {
    return ErrorEvent(
      id: map['id'] ?? '',
      errorType: map['errorType'] ?? '',
      message: map['message'] ?? '',
      stackTrace: map['stackTrace'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      level: MonitoringLevel.values.firstWhere(
        (e) => e.toString() == map['level'],
        orElse: () => MonitoringLevel.error,
      ),
      operation: map['operation'] ?? '',
      userId: map['userId'] ?? '',
      sessionId: map['sessionId'] ?? '',
      context: Map<String, dynamic>.from(map['context'] ?? {}),
      isResolved: map['isResolved'] ?? false,
      resolvedAt: map['resolvedAt'] != null 
          ? (map['resolvedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'errorType': errorType,
      'message': message,
      'stackTrace': stackTrace,
      'timestamp': Timestamp.fromDate(timestamp),
      'level': level.toString(),
      'operation': operation,
      'userId': userId,
      'sessionId': sessionId,
      'context': context,
      'isResolved': isResolved,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }
}

/// Service for monitoring and error handling
class MonitoringService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, Stopwatch> _activeOperations = {};
  static final String _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Start monitoring an operation
  static void startOperation(String operationId, String operation, String userId) {
    final stopwatch = Stopwatch()..start();
    _activeOperations[operationId] = stopwatch;
    
    if (kDebugMode) {
      print('Started monitoring operation: $operation for user: $userId');
    }
  }
  
  /// End monitoring an operation and record metrics
  static Future<void> endOperation(
    String operationId,
    String operation,
    String userId, {
    bool success = true,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final stopwatch = _activeOperations.remove(operationId);
      if (stopwatch == null) {
        if (kDebugMode) {
          print('Warning: No active operation found for ID: $operationId');
        }
        return;
      }
      
      stopwatch.stop();
      
      final metrics = PerformanceMetrics(
        id: _generateMetricsId(),
        operation: operation,
        timestamp: DateTime.now(),
        duration: stopwatch.elapsed,
        success: success,
        errorMessage: errorMessage,
        metadata: metadata ?? {},
        userId: userId,
        sessionId: _currentSessionId,
      );
      
      await _recordMetrics(metrics);
      
      // Log slow operations
      if (stopwatch.elapsedMilliseconds > 5000) {
        await logWarning(
          'Slow operation detected',
          operation: operation,
          userId: userId,
          context: {
            'duration': stopwatch.elapsedMilliseconds,
            'operationId': operationId,
          },
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error ending operation monitoring: $e');
      }
    }
  }
  
  /// Log an error event
  static Future<void> logError(
    String message, {
    required String operation,
    required String userId,
    String? errorType,
    String? stackTrace,
    Map<String, dynamic>? context,
    MonitoringLevel level = MonitoringLevel.error,
  }) async {
    try {
      final errorEvent = ErrorEvent(
        id: _generateErrorId(),
        errorType: errorType ?? 'UnknownError',
        message: message,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
        level: level,
        operation: operation,
        userId: userId,
        sessionId: _currentSessionId,
        context: context ?? {},
        isResolved: false,
      );
      
      await _recordError(errorEvent);
      
      // Send alerts for critical errors
      if (level == MonitoringLevel.critical) {
        await _sendCriticalAlert(errorEvent);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error logging error event: $e');
      }
    }
  }
  
  /// Log a warning event
  static Future<void> logWarning(
    String message, {
    required String operation,
    required String userId,
    Map<String, dynamic>? context,
  }) async {
    await logError(
      message,
      operation: operation,
      userId: userId,
      errorType: 'Warning',
      context: context,
      level: MonitoringLevel.warning,
    );
  }
  
  /// Log an info event
  static Future<void> logInfo(
    String message, {
    required String operation,
    required String userId,
    Map<String, dynamic>? context,
  }) async {
    await logError(
      message,
      operation: operation,
      userId: userId,
      errorType: 'Info',
      context: context,
      level: MonitoringLevel.info,
    );
  }
  
  /// Get performance metrics for analysis
  static Future<List<PerformanceMetrics>> getPerformanceMetrics({
    String? operation,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection('performance_metrics');
      
      if (operation != null) {
        query = query.where('operation', isEqualTo: operation);
      }
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      query = query.orderBy('timestamp', descending: true).limit(limit);
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => PerformanceMetrics.fromMap({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();
    } catch (e) {
      throw MonitoringException(
        'Failed to get performance metrics: $e',
        'GET_METRICS_FAILED',
        {'operation': operation, 'userId': userId}
      );
    }
  }
  
  /// Get error events for analysis
  static Future<List<ErrorEvent>> getErrorEvents({
    MonitoringLevel? level,
    String? operation,
    String? userId,
    bool? isResolved,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection('error_events');
      
      if (level != null) {
        query = query.where('level', isEqualTo: level.toString());
      }
      
      if (operation != null) {
        query = query.where('operation', isEqualTo: operation);
      }
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      if (isResolved != null) {
        query = query.where('isResolved', isEqualTo: isResolved);
      }
      
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      query = query.orderBy('timestamp', descending: true).limit(limit);
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => ErrorEvent.fromMap({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();
    } catch (e) {
      throw MonitoringException(
        'Failed to get error events: $e',
        'GET_ERRORS_FAILED',
        {'level': level?.toString(), 'operation': operation}
      );
    }
  }
  
  /// Generate system health report
  static Future<Map<String, dynamic>> generateHealthReport() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      
      // Get recent metrics
      final recentMetrics = await getPerformanceMetrics(
        startDate: last24Hours,
        limit: 1000,
      );
      
      // Get recent errors
      final recentErrors = await getErrorEvents(
        startDate: last24Hours,
        limit: 1000,
      );
      
      // Calculate success rate
      final totalOperations = recentMetrics.length;
      final successfulOperations = recentMetrics.where((m) => m.success).length;
      final successRate = totalOperations > 0 
          ? (successfulOperations / totalOperations) * 100 
          : 0.0;
      
      // Calculate average response time
      final avgResponseTime = recentMetrics.isNotEmpty
          ? recentMetrics
              .map((m) => m.duration.inMilliseconds)
              .reduce((a, b) => a + b) / recentMetrics.length
          : 0.0;
      
      // Error breakdown
      final errorsByLevel = <String, int>{};
      for (final error in recentErrors) {
        final level = error.level.toString();
        errorsByLevel[level] = (errorsByLevel[level] ?? 0) + 1;
      }
      
      // Operation performance
      final operationStats = <String, Map<String, dynamic>>{};
      for (final metric in recentMetrics) {
        final op = metric.operation;
        if (!operationStats.containsKey(op)) {
          operationStats[op] = {
            'count': 0,
            'successCount': 0,
            'totalDuration': 0,
            'avgDuration': 0.0,
            'successRate': 0.0,
          };
        }
        
        operationStats[op]!['count'] = operationStats[op]!['count'] + 1;
        if (metric.success) {
          operationStats[op]!['successCount'] = operationStats[op]!['successCount'] + 1;
        }
        operationStats[op]!['totalDuration'] = 
            operationStats[op]!['totalDuration'] + metric.duration.inMilliseconds;
      }
      
      // Calculate averages
      for (final stats in operationStats.values) {
        final count = stats['count'] as int;
        if (count > 0) {
          stats['avgDuration'] = (stats['totalDuration'] as int) / count;
          stats['successRate'] = ((stats['successCount'] as int) / count) * 100;
        }
      }
      
      return {
        'timestamp': now.toIso8601String(),
        'period': '24 hours',
        'overall': {
          'totalOperations': totalOperations,
          'successfulOperations': successfulOperations,
          'successRate': successRate,
          'avgResponseTime': avgResponseTime,
          'totalErrors': recentErrors.length,
        },
        'errorsByLevel': errorsByLevel,
        'operationStats': operationStats,
        'systemStatus': _determineSystemStatus(successRate, recentErrors),
        'recommendations': _generateRecommendations(successRate, avgResponseTime, recentErrors),
      };
    } catch (e) {
      throw MonitoringException(
        'Failed to generate health report: $e',
        'HEALTH_REPORT_FAILED'
      );
    }
  }
  
  /// Resolve an error event
  static Future<void> resolveError(String errorId) async {
    try {
      await _firestore
          .collection('error_events')
          .doc(errorId)
          .update({
            'isResolved': true,
            'resolvedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw MonitoringException(
        'Failed to resolve error: $e',
        'RESOLVE_ERROR_FAILED',
        {'errorId': errorId}
      );
    }
  }
  
  /// Clean up old monitoring data
  static Future<void> cleanupOldData({Duration retentionPeriod = const Duration(days: 90)}) async {
    try {
      final cutoffDate = DateTime.now().subtract(retentionPeriod);
      
      // Clean up old metrics
      final oldMetrics = await _firestore
          .collection('performance_metrics')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      final metricsBatch = _firestore.batch();
      for (final doc in oldMetrics.docs) {
        metricsBatch.delete(doc.reference);
      }
      await metricsBatch.commit();
      
      // Clean up old resolved errors
      final oldErrors = await _firestore
          .collection('error_events')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .where('isResolved', isEqualTo: true)
          .get();
      
      final errorsBatch = _firestore.batch();
      for (final doc in oldErrors.docs) {
        errorsBatch.delete(doc.reference);
      }
      await errorsBatch.commit();
      
      if (kDebugMode) {
        print('Cleaned up ${oldMetrics.docs.length} old metrics and ${oldErrors.docs.length} old errors');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up old data: $e');
      }
    }
  }
  
  /// Private helper methods
  
  static String _generateMetricsId() {
    return 'metrics_${DateTime.now().microsecondsSinceEpoch}';
  }
  
  static String _generateErrorId() {
    return 'error_${DateTime.now().microsecondsSinceEpoch}';
  }
  
  static Future<void> _recordMetrics(PerformanceMetrics metrics) async {
    await _firestore
        .collection('performance_metrics')
        .doc(metrics.id)
        .set(metrics.toMap());
  }
  
  static Future<void> _recordError(ErrorEvent error) async {
    await _firestore
        .collection('error_events')
        .doc(error.id)
        .set(error.toMap());
  }
  
  static Future<void> _sendCriticalAlert(ErrorEvent error) async {
    // In a real implementation, this would send alerts via email, Slack, etc.
    if (kDebugMode) {
      print('CRITICAL ALERT: ${error.message} in ${error.operation}');
    }
    
    // Log the alert
    await _firestore.collection('critical_alerts').add({
      'errorId': error.id,
      'message': error.message,
      'operation': error.operation,
      'userId': error.userId,
      'timestamp': FieldValue.serverTimestamp(),
      'acknowledged': false,
    });
  }
  
  static String _determineSystemStatus(double successRate, List<ErrorEvent> recentErrors) {
    final criticalErrors = recentErrors.where((e) => e.level == MonitoringLevel.critical).length;
    
    if (criticalErrors > 0) return 'critical';
    if (successRate < 95.0) return 'degraded';
    if (successRate < 99.0) return 'warning';
    return 'healthy';
  }
  
  static List<String> _generateRecommendations(
    double successRate,
    double avgResponseTime,
    List<ErrorEvent> recentErrors,
  ) {
    final recommendations = <String>[];
    
    if (successRate < 95.0) {
      recommendations.add('Success rate is below 95%. Investigate recent errors and failures.');
    }
    
    if (avgResponseTime > 2000) {
      recommendations.add('Average response time is above 2 seconds. Consider performance optimization.');
    }
    
    final criticalErrors = recentErrors.where((e) => e.level == MonitoringLevel.critical).length;
    if (criticalErrors > 0) {
      recommendations.add('$criticalErrors critical errors detected. Immediate attention required.');
    }
    
    final errorErrors = recentErrors.where((e) => e.level == MonitoringLevel.error).length;
    if (errorErrors > 10) {
      recommendations.add('High error count ($errorErrors). Review error patterns and root causes.');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('System is operating within normal parameters.');
    }
    
    return recommendations;
  }
}

