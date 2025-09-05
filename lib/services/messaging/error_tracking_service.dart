// Error Tracking and Alerting Service for TALOWA In-App Communication System
// Implements Task 16: Implement monitoring and analytics - Error Tracking & Alerting

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/messaging/communication_analytics_models.dart';

/// Error tracking and alerting service for system failures and security issues
class ErrorTrackingService {
  static final ErrorTrackingService _instance = ErrorTrackingService._internal();
  factory ErrorTrackingService() => _instance;
  ErrorTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Error tracking
  final List<SystemError> _errorBuffer = [];
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  
  // Alert management
  final List<SystemAlert> _activeAlerts = [];
  final Map<String, Timer> _alertTimers = {};
  
  // Configuration
  static const int _maxErrorBufferSize = 1000;
  static const Duration _errorAggregationWindow = Duration(minutes: 5);
  static const Duration _alertCooldownPeriod = Duration(minutes: 15);

  /// Initialize error tracking service
  Future<void> initialize() async {
    try {
      debugPrint('Initializing Error Tracking Service...');
      
      // Start periodic error processing
      Timer.periodic(const Duration(minutes: 1), (timer) {
        _processErrorBuffer();
      });
      
      // Start alert cleanup
      Timer.periodic(const Duration(minutes: 5), (timer) {
        _cleanupExpiredAlerts();
      });
      
      debugPrint('Error Tracking Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Error Tracking Service: $e');
      rethrow;
    }
  }

  /// Track a system error
  Future<void> trackError({
    required String errorType,
    required String errorMessage,
    required String severity,
    String? component,
    String? userId,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) async {
    try {
      final error = SystemError(
        errorId: _generateErrorId(),
        errorType: errorType,
        errorMessage: errorMessage,
        severity: severity,
        component: component ?? 'unknown',
        userId: userId,
        context: context ?? {},
        stackTrace: stackTrace?.toString(),
        timestamp: DateTime.now(),
        resolved: false,
      );

      // Add to buffer
      _errorBuffer.add(error);
      
      // Maintain buffer size
      if (_errorBuffer.length > _maxErrorBufferSize) {
        _errorBuffer.removeAt(0);
      }

      // Update error counts
      final errorKey = '${error.errorType}_${error.component}';
      _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
      _lastErrorTimes[errorKey] = error.timestamp;

      // Check for immediate alerting conditions
      await _checkImmediateAlerts(error);
      
      debugPrint('Error tracked: $errorType - $errorMessage');
    } catch (e) {
      debugPrint('Error tracking error: $e');
    }
  }

  /// Track WebSocket connection errors
  Future<void> trackConnectionError({
    required String connectionId,
    required String errorMessage,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    await trackError(
      errorType: 'websocket_connection_error',
      errorMessage: errorMessage,
      severity: 'medium',
      component: 'websocket_service',
      userId: userId,
      context: {
        'connectionId': connectionId,
        ...?metadata,
      },
    );
  }

  /// Track message delivery errors
  Future<void> trackMessageDeliveryError({
    required String messageId,
    required String errorMessage,
    required String senderId,
    String? recipientId,
    String? groupId,
    Map<String, dynamic>? metadata,
  }) async {
    await trackError(
      errorType: 'message_delivery_error',
      errorMessage: errorMessage,
      severity: 'high',
      component: 'messaging_service',
      userId: senderId,
      context: {
        'messageId': messageId,
        'recipientId': recipientId,
        'groupId': groupId,
        ...?metadata,
      },
    );
  }

  /// Track voice call errors
  Future<void> trackVoiceCallError({
    required String callId,
    required String errorMessage,
    required String callerId,
    String? recipientId,
    Map<String, dynamic>? metadata,
  }) async {
    await trackError(
      errorType: 'voice_call_error',
      errorMessage: errorMessage,
      severity: 'medium',
      component: 'voice_service',
      userId: callerId,
      context: {
        'callId': callId,
        'recipientId': recipientId,
        ...?metadata,
      },
    );
  }

  /// Track security-related errors
  Future<void> trackSecurityError({
    required String errorMessage,
    required String userId,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) async {
    await trackError(
      errorType: 'security_error',
      errorMessage: errorMessage,
      severity: 'critical',
      component: 'security_service',
      userId: userId,
      context: {
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        ...?metadata,
      },
    );
  }

  /// Track authentication errors
  Future<void> trackAuthenticationError({
    required String errorMessage,
    String? userId,
    String? phoneNumber,
    String? ipAddress,
    Map<String, dynamic>? metadata,
  }) async {
    await trackError(
      errorType: 'authentication_error',
      errorMessage: errorMessage,
      severity: 'high',
      component: 'auth_service',
      userId: userId,
      context: {
        'phoneNumber': phoneNumber,
        'ipAddress': ipAddress,
        ...?metadata,
      },
    );
  }

  /// Track database errors
  Future<void> trackDatabaseError({
    required String errorMessage,
    required String operation,
    String? collection,
    String? documentId,
    Map<String, dynamic>? metadata,
  }) async {
    await trackError(
      errorType: 'database_error',
      errorMessage: errorMessage,
      severity: 'high',
      component: 'database_service',
      context: {
        'operation': operation,
        'collection': collection,
        'documentId': documentId,
        ...?metadata,
      },
    );
  }

  /// Create a system alert
  Future<SystemAlert> createAlert({
    required String alertType,
    required String severity,
    required String message,
    String? component,
    Map<String, dynamic>? metadata,
    Duration? autoResolveAfter,
  }) async {
    try {
      final alert = SystemAlert(
        alertId: _generateAlertId(),
        alertType: alertType,
        severity: severity,
        message: message,
        timestamp: DateTime.now(),
        resolved: false,
        metadata: {
          'component': component,
          ...?metadata,
        },
      );

      _activeAlerts.add(alert);

      // Store in database
      await _firestore.collection('system_alerts').doc(alert.alertId).set(alert.toMap());

      // Set up auto-resolve timer if specified
      if (autoResolveAfter != null) {
        _alertTimers[alert.alertId] = Timer(autoResolveAfter, () {
          resolveAlert(alert.alertId);
        });
      }

      // Send notifications for critical alerts
      if (severity == 'critical') {
        await _sendCriticalAlertNotification(alert);
      }

      debugPrint('Alert created: ${alert.alertType} - ${alert.message}');
      return alert;
    } catch (e) {
      debugPrint('Error creating alert: $e');
      rethrow;
    }
  }

  /// Resolve a system alert
  Future<void> resolveAlert(String alertId) async {
    try {
      // Update in memory
      final alertIndex = _activeAlerts.indexWhere((a) => a.alertId == alertId);
      if (alertIndex != -1) {
        final alert = _activeAlerts[alertIndex];
        final resolvedAlert = SystemAlert(
          alertId: alert.alertId,
          alertType: alert.alertType,
          severity: alert.severity,
          message: alert.message,
          timestamp: alert.timestamp,
          resolved: true,
          metadata: alert.metadata,
        );
        
        _activeAlerts[alertIndex] = resolvedAlert;
      }

      // Update in database
      await _firestore.collection('system_alerts').doc(alertId).update({
        'resolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // Cancel auto-resolve timer
      _alertTimers[alertId]?.cancel();
      _alertTimers.remove(alertId);

      debugPrint('Alert resolved: $alertId');
    } catch (e) {
      debugPrint('Error resolving alert: $e');
    }
  }

  /// Get active alerts
  List<SystemAlert> getActiveAlerts({String? severity, String? alertType}) {
    var alerts = _activeAlerts.where((a) => !a.resolved);
    
    if (severity != null) {
      alerts = alerts.where((a) => a.severity == severity);
    }
    
    if (alertType != null) {
      alerts = alerts.where((a) => a.alertType == alertType);
    }
    
    return alerts.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get error statistics
  Future<Map<String, dynamic>> getErrorStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _getDateRange(startDate, endDate);
      
      // Query errors from database
      final errorsSnapshot = await _firestore
          .collection('system_errors')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final errors = errorsSnapshot.docs
          .map((doc) => SystemError.fromMap(doc.data()))
          .toList();

      // Calculate statistics
      final totalErrors = errors.length;
      final errorsBySeverity = <String, int>{};
      final errorsByType = <String, int>{};
      final errorsByComponent = <String, int>{};
      final errorTrends = <String, int>{};

      for (final error in errors) {
        // Count by severity
        errorsBySeverity[error.severity] = (errorsBySeverity[error.severity] ?? 0) + 1;
        
        // Count by type
        errorsByType[error.errorType] = (errorsByType[error.errorType] ?? 0) + 1;
        
        // Count by component
        errorsByComponent[error.component] = (errorsByComponent[error.component] ?? 0) + 1;
        
        // Count by day for trends
        final dateKey = '${error.timestamp.year}-${error.timestamp.month.toString().padLeft(2, '0')}-${error.timestamp.day.toString().padLeft(2, '0')}';
        errorTrends[dateKey] = (errorTrends[dateKey] ?? 0) + 1;
      }

      // Calculate error rates
      final durationDays = dateRange.durationInDays > 0 ? dateRange.durationInDays : 1;
      final errorRate = totalErrors / durationDays;
      final criticalErrorRate = (errorsBySeverity['critical'] ?? 0) / durationDays;

      return {
        'dateRange': {
          'start': dateRange.start.toIso8601String(),
          'end': dateRange.end.toIso8601String(),
        },
        'summary': {
          'totalErrors': totalErrors,
          'errorRate': errorRate,
          'criticalErrorRate': criticalErrorRate,
          'resolvedErrors': errors.where((e) => e.resolved).length,
        },
        'errorsBySeverity': errorsBySeverity,
        'errorsByType': errorsByType,
        'errorsByComponent': errorsByComponent,
        'errorTrends': errorTrends,
        'topErrors': _getTopErrors(errors),
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting error statistics: $e');
      rethrow;
    }
  }

  /// Get alert statistics
  Future<Map<String, dynamic>> getAlertStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _getDateRange(startDate, endDate);
      
      // Query alerts from database
      final alertsSnapshot = await _firestore
          .collection('system_alerts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final alerts = alertsSnapshot.docs
          .map((doc) => SystemAlert.fromMap(doc.data()))
          .toList();

      // Calculate statistics
      final totalAlerts = alerts.length;
      final activeAlerts = alerts.where((a) => !a.resolved).length;
      final alertsBySeverity = <String, int>{};
      final alertsByType = <String, int>{};

      for (final alert in alerts) {
        alertsBySeverity[alert.severity] = (alertsBySeverity[alert.severity] ?? 0) + 1;
        alertsByType[alert.alertType] = (alertsByType[alert.alertType] ?? 0) + 1;
      }

      // Calculate resolution metrics
      final resolvedAlerts = alerts.where((a) => a.resolved).toList();
      final averageResolutionTime = resolvedAlerts.isEmpty 
          ? 0.0 
          : resolvedAlerts
              .map((a) => DateTime.now().difference(a.timestamp).inMinutes)
              .reduce((a, b) => a + b) / resolvedAlerts.length;

      return {
        'dateRange': {
          'start': dateRange.start.toIso8601String(),
          'end': dateRange.end.toIso8601String(),
        },
        'summary': {
          'totalAlerts': totalAlerts,
          'activeAlerts': activeAlerts,
          'resolvedAlerts': resolvedAlerts.length,
          'averageResolutionTime': averageResolutionTime,
        },
        'alertsBySeverity': alertsBySeverity,
        'alertsByType': alertsByType,
        'recentAlerts': alerts.take(10).map((a) => a.toMap()).toList(),
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting alert statistics: $e');
      rethrow;
    }
  }

  // Private helper methods

  Future<void> _processErrorBuffer() async {
    if (_errorBuffer.isEmpty) return;

    try {
      // Store errors in database
      final batch = _firestore.batch();
      final errorsToStore = List<SystemError>.from(_errorBuffer);
      _errorBuffer.clear();

      for (final error in errorsToStore) {
        final docRef = _firestore.collection('system_errors').doc(error.errorId);
        batch.set(docRef, error.toMap());
      }

      await batch.commit();
      
      // Check for patterns and create alerts
      await _analyzeErrorPatterns();
      
      debugPrint('Processed ${errorsToStore.length} errors');
    } catch (e) {
      debugPrint('Error processing error buffer: $e');
    }
  }

  Future<void> _analyzeErrorPatterns() async {
    try {
      final now = DateTime.now();
      
      // Check for error spikes
      for (final entry in _errorCounts.entries) {
        final errorKey = entry.key;
        final count = entry.value;
        final lastErrorTime = _lastErrorTimes[errorKey];
        
        if (lastErrorTime != null && 
            now.difference(lastErrorTime) <= _errorAggregationWindow &&
            count >= 10) {
          
          await createAlert(
            alertType: 'error_spike',
            severity: 'high',
            message: 'Error spike detected: $errorKey ($count errors in ${_errorAggregationWindow.inMinutes} minutes)',
            metadata: {
              'errorKey': errorKey,
              'errorCount': count,
              'timeWindow': _errorAggregationWindow.inMinutes,
            },
            autoResolveAfter: const Duration(hours: 1),
          );
          
          // Reset counter after alerting
          _errorCounts[errorKey] = 0;
        }
      }
    } catch (e) {
      debugPrint('Error analyzing error patterns: $e');
    }
  }

  Future<void> _checkImmediateAlerts(SystemError error) async {
    try {
      // Critical errors always create alerts
      if (error.severity == 'critical') {
        await createAlert(
          alertType: 'critical_error',
          severity: 'critical',
          message: 'Critical error: ${error.errorMessage}',
          component: error.component,
          metadata: {
            'errorId': error.errorId,
            'errorType': error.errorType,
            'userId': error.userId,
          },
        );
      }

      // Security errors always create alerts
      if (error.errorType.contains('security')) {
        await createAlert(
          alertType: 'security_incident',
          severity: 'critical',
          message: 'Security incident: ${error.errorMessage}',
          component: error.component,
          metadata: {
            'errorId': error.errorId,
            'userId': error.userId,
          },
        );
      }

      // Database errors create alerts
      if (error.component == 'database_service') {
        await createAlert(
          alertType: 'database_issue',
          severity: 'high',
          message: 'Database issue: ${error.errorMessage}',
          component: error.component,
          metadata: {
            'errorId': error.errorId,
          },
          autoResolveAfter: const Duration(minutes: 30),
        );
      }
    } catch (e) {
      debugPrint('Error checking immediate alerts: $e');
    }
  }

  Future<void> _sendCriticalAlertNotification(SystemAlert alert) async {
    try {
      // In a real implementation, this would send notifications to administrators
      // via email, SMS, push notifications, or integration with monitoring systems
      debugPrint('CRITICAL ALERT: ${alert.message}');
      
      // Store notification record
      await _firestore.collection('alert_notifications').add({
        'alertId': alert.alertId,
        'alertType': alert.alertType,
        'severity': alert.severity,
        'message': alert.message,
        'timestamp': FieldValue.serverTimestamp(),
        'notificationChannels': ['console'], // Would include email, SMS, etc.
      });
    } catch (e) {
      debugPrint('Error sending critical alert notification: $e');
    }
  }

  void _cleanupExpiredAlerts() {
    try {
      final now = DateTime.now();
      final expiredAlerts = _activeAlerts
          .where((a) => a.resolved && now.difference(a.timestamp) > const Duration(hours: 24))
          .toList();

      for (final alert in expiredAlerts) {
        _activeAlerts.remove(alert);
        _alertTimers[alert.alertId]?.cancel();
        _alertTimers.remove(alert.alertId);
      }

      if (expiredAlerts.isNotEmpty) {
        debugPrint('Cleaned up ${expiredAlerts.length} expired alerts');
      }
    } catch (e) {
      debugPrint('Error cleaning up expired alerts: $e');
    }
  }

  DateRange _getDateRange(DateTime? startDate, DateTime? endDate) {
    final end = endDate ?? DateTime.now();
    final start = startDate ?? end.subtract(const Duration(days: 7));
    return DateRange(start: start, end: end);
  }

  List<Map<String, dynamic>> _getTopErrors(List<SystemError> errors) {
    final errorCounts = <String, int>{};
    final errorExamples = <String, SystemError>{};

    for (final error in errors) {
      final key = '${error.errorType}_${error.component}';
      errorCounts[key] = (errorCounts[key] ?? 0) + 1;
      errorExamples[key] = error;
    }

    final sortedErrors = errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedErrors.take(10).map((entry) {
      final error = errorExamples[entry.key]!;
      return {
        'errorType': error.errorType,
        'component': error.component,
        'count': entry.value,
        'lastOccurrence': error.timestamp.toIso8601String(),
        'severity': error.severity,
        'exampleMessage': error.errorMessage,
      };
    }).toList();
  }

  String _generateErrorId() {
    return 'error_${DateTime.now().millisecondsSinceEpoch}_${_errorBuffer.length}';
  }

  String _generateAlertId() {
    return 'alert_${DateTime.now().millisecondsSinceEpoch}_${_activeAlerts.length}';
  }
}

/// System error model
class SystemError {
  final String errorId;
  final String errorType;
  final String errorMessage;
  final String severity;
  final String component;
  final String? userId;
  final Map<String, dynamic> context;
  final String? stackTrace;
  final DateTime timestamp;
  final bool resolved;

  SystemError({
    required this.errorId,
    required this.errorType,
    required this.errorMessage,
    required this.severity,
    required this.component,
    this.userId,
    required this.context,
    this.stackTrace,
    required this.timestamp,
    required this.resolved,
  });

  Map<String, dynamic> toMap() {
    return {
      'errorId': errorId,
      'errorType': errorType,
      'errorMessage': errorMessage,
      'severity': severity,
      'component': component,
      'userId': userId,
      'context': context,
      'stackTrace': stackTrace,
      'timestamp': Timestamp.fromDate(timestamp),
      'resolved': resolved,
    };
  }

  static SystemError fromMap(Map<String, dynamic> map) {
    return SystemError(
      errorId: map['errorId'] ?? '',
      errorType: map['errorType'] ?? '',
      errorMessage: map['errorMessage'] ?? '',
      severity: map['severity'] ?? 'low',
      component: map['component'] ?? 'unknown',
      userId: map['userId'],
      context: Map<String, dynamic>.from(map['context'] ?? {}),
      stackTrace: map['stackTrace'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      resolved: map['resolved'] ?? false,
    );
  }
}

class DateRange {
  final DateTime start;
  final DateTime end;
  
  DateRange({required this.start, required this.end});
  
  int get durationInDays => end.difference(start).inDays;
}
