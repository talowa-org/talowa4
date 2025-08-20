// Communication Monitoring Integration Service for TALOWA In-App Communication System
// Implements Task 16: Implement monitoring and analytics - Integration Layer

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'communication_monitoring_service.dart';
import 'communication_analytics_service.dart';
import 'error_tracking_service.dart';
import '../../models/messaging/communication_analytics_models.dart';

/// Integration service that coordinates all monitoring and analytics components
class CommunicationMonitoringIntegration {
  static final CommunicationMonitoringIntegration _instance = 
      CommunicationMonitoringIntegration._internal();
  factory CommunicationMonitoringIntegration() => _instance;
  CommunicationMonitoringIntegration._internal();

  // Service instances
  final CommunicationMonitoringService _monitoringService = CommunicationMonitoringService();
  final CommunicationAnalyticsService _analyticsService = CommunicationAnalyticsService();
  final ErrorTrackingService _errorService = ErrorTrackingService();

  bool _isInitialized = false;

  /// Initialize all monitoring and analytics services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Communication Monitoring Integration...');

      // Initialize all services
      await Future.wait([
        _monitoringService.initialize(),
        _errorService.initialize(),
      ]);

      _isInitialized = true;
      debugPrint('Communication Monitoring Integration initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Communication Monitoring Integration: $e');
      rethrow;
    }
  }

  /// Dispose all services
  void dispose() {
    _monitoringService.dispose();
    _isInitialized = false;
  }

  // WebSocket Connection Monitoring Integration

  /// Track WebSocket connection with integrated monitoring and error handling
  Future<void> trackWebSocketConnection({
    required String connectionId,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _monitoringService.trackConnectionStart(
        connectionId: connectionId,
        userId: userId,
      );

      debugPrint('WebSocket connection tracking started: $connectionId');
    } catch (e) {
      await _errorService.trackConnectionError(
        connectionId: connectionId,
        errorMessage: 'Failed to start connection tracking: $e',
        userId: userId,
        metadata: metadata,
      );
      rethrow;
    }
  }

  /// Track WebSocket disconnection with analytics
  Future<void> trackWebSocketDisconnection({
    required String connectionId,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _monitoringService.trackConnectionEnd(
        connectionId: connectionId,
        reason: reason,
      );

      debugPrint('WebSocket disconnection tracked: $connectionId');
    } catch (e) {
      await _errorService.trackConnectionError(
        connectionId: connectionId,
        errorMessage: 'Failed to track disconnection: $e',
        metadata: metadata,
      );
    }
  }

  /// Update connection quality with automatic alerting
  Future<void> updateConnectionQuality({
    required String connectionId,
    required double latency,
    required double packetLoss,
    required double jitter,
  }) async {
    try {
      await _monitoringService.updateConnectionQuality(
        connectionId: connectionId,
        latency: latency,
        packetLoss: packetLoss,
        jitter: jitter,
      );

      // Check for quality issues and create alerts if needed
      if (latency > 500 || packetLoss > 0.1) {
        await _errorService.createAlert(
          alertType: 'connection_quality_degraded',
          severity: 'medium',
          message: 'Connection quality degraded for $connectionId (latency: ${latency}ms, packet loss: ${(packetLoss * 100).toStringAsFixed(1)}%)',
          metadata: {
            'connectionId': connectionId,
            'latency': latency,
            'packetLoss': packetLoss,
            'jitter': jitter,
          },
          autoResolveAfter: const Duration(minutes: 10),
        );
      }
    } catch (e) {
      await _errorService.trackError(
        errorType: 'connection_quality_update_error',
        errorMessage: 'Failed to update connection quality: $e',
        severity: 'low',
        component: 'monitoring_integration',
        context: {
          'connectionId': connectionId,
          'latency': latency,
          'packetLoss': packetLoss,
          'jitter': jitter,
        },
      );
    }
  }

  // Message Delivery Monitoring Integration

  /// Track message sending with comprehensive monitoring
  Future<void> trackMessageSent({
    required String messageId,
    required String senderId,
    String? recipientId,
    String? groupId,
    required String messageType,
    required int messageSize,
    required bool isEncrypted,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _monitoringService.trackMessageSent(
        messageId: messageId,
        senderId: senderId,
        recipientId: recipientId,
        groupId: groupId,
        messageType: messageType,
        messageSize: messageSize,
        isEncrypted: isEncrypted,
      );

      // Track large message sizes
      if (messageSize > 10 * 1024 * 1024) { // 10MB
        await _errorService.createAlert(
          alertType: 'large_message_sent',
          severity: 'low',
          message: 'Large message sent: ${(messageSize / 1024 / 1024).toStringAsFixed(1)}MB',
          metadata: {
            'messageId': messageId,
            'messageSize': messageSize,
            'messageType': messageType,
          },
        );
      }

      debugPrint('Message sending tracked: $messageId');
    } catch (e) {
      await _errorService.trackMessageDeliveryError(
        messageId: messageId,
        errorMessage: 'Failed to track message sending: $e',
        senderId: senderId,
        recipientId: recipientId,
        groupId: groupId,
        metadata: metadata,
      );
    }
  }

  /// Track message delivery with performance monitoring
  Future<void> trackMessageDelivered({
    required String messageId,
    String? recipientId,
    Duration? deliveryTime,
  }) async {
    try {
      await _monitoringService.trackMessageDelivered(
        messageId: messageId,
        recipientId: recipientId,
      );

      // Alert on slow delivery
      if (deliveryTime != null && deliveryTime.inSeconds > 10) {
        await _errorService.createAlert(
          alertType: 'slow_message_delivery',
          severity: 'medium',
          message: 'Slow message delivery detected: ${deliveryTime.inSeconds}s',
          metadata: {
            'messageId': messageId,
            'deliveryTime': deliveryTime.inSeconds,
          },
          autoResolveAfter: const Duration(minutes: 5),
        );
      }

      debugPrint('Message delivery tracked: $messageId');
    } catch (e) {
      await _errorService.trackError(
        errorType: 'message_delivery_tracking_error',
        errorMessage: 'Failed to track message delivery: $e',
        severity: 'medium',
        component: 'monitoring_integration',
        context: {
          'messageId': messageId,
          'recipientId': recipientId,
        },
      );
    }
  }

  /// Track message delivery failure with automatic retry logic
  Future<void> trackMessageDeliveryFailure({
    required String messageId,
    required String errorMessage,
    required int attemptNumber,
    String? senderId,
    String? recipientId,
  }) async {
    try {
      await _monitoringService.trackMessageDeliveryFailure(
        messageId: messageId,
        errorMessage: errorMessage,
        attemptNumber: attemptNumber,
      );

      // Create alert for repeated failures
      if (attemptNumber >= 3) {
        await _errorService.createAlert(
          alertType: 'message_delivery_failed',
          severity: 'high',
          message: 'Message delivery failed after $attemptNumber attempts: $errorMessage',
          metadata: {
            'messageId': messageId,
            'attemptNumber': attemptNumber,
            'errorMessage': errorMessage,
            'senderId': senderId,
            'recipientId': recipientId,
          },
        );
      }

      debugPrint('Message delivery failure tracked: $messageId (attempt $attemptNumber)');
    } catch (e) {
      await _errorService.trackError(
        errorType: 'message_failure_tracking_error',
        errorMessage: 'Failed to track message delivery failure: $e',
        severity: 'high',
        component: 'monitoring_integration',
        context: {
          'messageId': messageId,
          'originalError': errorMessage,
          'attemptNumber': attemptNumber,
        },
      );
    }
  }

  // Voice Call Monitoring Integration

  /// Track voice call start with quality monitoring setup
  Future<void> trackVoiceCallStart({
    required String callId,
    required String callerId,
    required String recipientId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _monitoringService.trackCallStart(
        callId: callId,
        callerId: callerId,
        recipientId: recipientId,
      );

      debugPrint('Voice call tracking started: $callId');
    } catch (e) {
      await _errorService.trackVoiceCallError(
        callId: callId,
        errorMessage: 'Failed to start call tracking: $e',
        callerId: callerId,
        recipientId: recipientId,
        metadata: metadata,
      );
    }
  }

  /// Track voice call end with quality analysis
  Future<void> trackVoiceCallEnd({
    required String callId,
    required String endReason,
    Duration? callDuration,
    Map<String, dynamic>? qualityMetrics,
  }) async {
    try {
      await _monitoringService.trackCallEnd(
        callId: callId,
        endReason: endReason,
      );

      // Analyze call quality and create alerts if needed
      if (qualityMetrics != null) {
        final audioQuality = qualityMetrics['audioQuality'] as double? ?? 0.0;
        final latency = qualityMetrics['latency'] as double? ?? 0.0;
        
        if (audioQuality < 40 || latency > 400) {
          await _errorService.createAlert(
            alertType: 'poor_call_quality',
            severity: 'medium',
            message: 'Poor call quality detected for call $callId',
            metadata: {
              'callId': callId,
              'audioQuality': audioQuality,
              'latency': latency,
              'callDuration': callDuration?.inSeconds,
            },
          );
        }
      }

      // Alert on very short calls (potential connection issues)
      if (callDuration != null && callDuration.inSeconds < 10) {
        await _errorService.createAlert(
          alertType: 'short_call_duration',
          severity: 'low',
          message: 'Very short call detected: ${callDuration.inSeconds}s',
          metadata: {
            'callId': callId,
            'duration': callDuration.inSeconds,
            'endReason': endReason,
          },
        );
      }

      debugPrint('Voice call end tracked: $callId');
    } catch (e) {
      await _errorService.trackError(
        errorType: 'call_end_tracking_error',
        errorMessage: 'Failed to track call end: $e',
        severity: 'medium',
        component: 'monitoring_integration',
        context: {
          'callId': callId,
          'endReason': endReason,
        },
      );
    }
  }

  /// Update call quality with real-time monitoring
  Future<void> updateVoiceCallQuality({
    required String callId,
    required double latency,
    required double packetLoss,
    required double jitter,
    required double audioQuality,
  }) async {
    try {
      await _monitoringService.updateCallQuality(
        callId: callId,
        latency: latency,
        packetLoss: packetLoss,
        jitter: jitter,
        audioQuality: audioQuality,
      );

      debugPrint('Call quality updated: $callId');
    } catch (e) {
      await _errorService.trackError(
        errorType: 'call_quality_update_error',
        errorMessage: 'Failed to update call quality: $e',
        severity: 'low',
        component: 'monitoring_integration',
        context: {
          'callId': callId,
          'latency': latency,
          'packetLoss': packetLoss,
          'jitter': jitter,
          'audioQuality': audioQuality,
        },
      );
    }
  }

  // Analytics Integration

  /// Get comprehensive user engagement report
  Future<Map<String, dynamic>> getUserEngagementReport({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final engagement = await _analyticsService.getUserEngagementMetrics(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      return {
        'engagement': engagement.toMap(),
        'generatedAt': DateTime.now().toIso8601String(),
        'status': 'success',
      };
    } catch (e) {
      await _errorService.trackError(
        errorType: 'engagement_report_error',
        errorMessage: 'Failed to generate user engagement report: $e',
        severity: 'medium',
        component: 'analytics_integration',
        userId: userId,
      );
      
      return {
        'error': e.toString(),
        'generatedAt': DateTime.now().toIso8601String(),
        'status': 'error',
      };
    }
  }

  /// Get coordinator usage report with error handling
  Future<Map<String, dynamic>> getCoordinatorUsageReport({
    required String coordinatorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final report = await _analyticsService.getCoordinatorUsageReport(
        coordinatorId: coordinatorId,
        startDate: startDate,
        endDate: endDate,
      );

      return {
        ...report,
        'status': 'success',
      };
    } catch (e) {
      await _errorService.trackError(
        errorType: 'coordinator_report_error',
        errorMessage: 'Failed to generate coordinator usage report: $e',
        severity: 'medium',
        component: 'analytics_integration',
        userId: coordinatorId,
      );
      
      return {
        'error': e.toString(),
        'generatedAt': DateTime.now().toIso8601String(),
        'status': 'error',
      };
    }
  }

  /// Get system health dashboard with integrated monitoring
  Future<Map<String, dynamic>> getSystemHealthDashboard() async {
    try {
      final results = await Future.wait([
        _monitoringService.getSystemHealthMetrics(),
        _analyticsService.getSystemHealthDashboard(),
        _errorService.getErrorStatistics(),
      ]);

      final systemHealth = results[0] as SystemHealthMetrics;
      final healthDashboard = results[1] as Map<String, dynamic>;
      final errorStats = results[2] as Map<String, dynamic>;

      return {
        'systemHealth': systemHealth.toMap(),
        'healthDashboard': healthDashboard,
        'errorStatistics': errorStats,
        'activeAlerts': _errorService.getActiveAlerts().map((a) => a.toMap()).toList(),
        'generatedAt': DateTime.now().toIso8601String(),
        'status': 'success',
      };
    } catch (e) {
      await _errorService.trackError(
        errorType: 'health_dashboard_error',
        errorMessage: 'Failed to generate system health dashboard: $e',
        severity: 'high',
        component: 'monitoring_integration',
      );
      
      return {
        'error': e.toString(),
        'generatedAt': DateTime.now().toIso8601String(),
        'status': 'error',
      };
    }
  }

  /// Get performance dashboard with comprehensive metrics
  Future<Map<String, dynamic>> getPerformanceDashboard({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dashboard = await _analyticsService.getPerformanceDashboard(
        startDate: startDate,
        endDate: endDate,
      );

      return {
        ...dashboard,
        'status': 'success',
      };
    } catch (e) {
      await _errorService.trackError(
        errorType: 'performance_dashboard_error',
        errorMessage: 'Failed to generate performance dashboard: $e',
        severity: 'medium',
        component: 'analytics_integration',
      );
      
      return {
        'error': e.toString(),
        'generatedAt': DateTime.now().toIso8601String(),
        'status': 'error',
      };
    }
  }

  // Error and Alert Management

  /// Get active alerts with filtering
  List<SystemAlert> getActiveAlerts({
    String? severity,
    String? alertType,
    int? limit,
  }) {
    var alerts = _errorService.getActiveAlerts(
      severity: severity,
      alertType: alertType,
    );
    
    if (limit != null && alerts.length > limit) {
      alerts = alerts.take(limit).toList();
    }
    
    return alerts;
  }

  /// Resolve alert with logging
  Future<void> resolveAlert(String alertId) async {
    try {
      await _errorService.resolveAlert(alertId);
      debugPrint('Alert resolved: $alertId');
    } catch (e) {
      await _errorService.trackError(
        errorType: 'alert_resolution_error',
        errorMessage: 'Failed to resolve alert: $e',
        severity: 'medium',
        component: 'monitoring_integration',
        context: {'alertId': alertId},
      );
    }
  }

  /// Create custom alert
  Future<SystemAlert> createCustomAlert({
    required String alertType,
    required String severity,
    required String message,
    String? component,
    Map<String, dynamic>? metadata,
    Duration? autoResolveAfter,
  }) async {
    try {
      return await _errorService.createAlert(
        alertType: alertType,
        severity: severity,
        message: message,
        component: component,
        metadata: metadata,
        autoResolveAfter: autoResolveAfter,
      );
    } catch (e) {
      await _errorService.trackError(
        errorType: 'custom_alert_creation_error',
        errorMessage: 'Failed to create custom alert: $e',
        severity: 'medium',
        component: 'monitoring_integration',
      );
      rethrow;
    }
  }

  // Health Check

  /// Perform comprehensive health check
  Future<Map<String, dynamic>> performHealthCheck() async {
    try {
      final healthMetrics = await _monitoringService.getSystemHealthMetrics();
      final errorStats = await _errorService.getErrorStatistics();
      final activeAlerts = _errorService.getActiveAlerts();

      // Determine overall health status
      String healthStatus = 'healthy';
      final criticalAlerts = activeAlerts.where((a) => a.severity == 'critical').length;
      final highAlerts = activeAlerts.where((a) => a.severity == 'high').length;

      if (criticalAlerts > 0) {
        healthStatus = 'critical';
      } else if (highAlerts > 5) {
        healthStatus = 'degraded';
      } else if (healthMetrics.serverCpuUsage > 80 || healthMetrics.serverMemoryUsage > 90) {
        healthStatus = 'warning';
      }

      return {
        'status': healthStatus,
        'timestamp': DateTime.now().toIso8601String(),
        'metrics': healthMetrics.toMap(),
        'errorSummary': errorStats['summary'],
        'activeAlerts': activeAlerts.length,
        'criticalAlerts': criticalAlerts,
        'highAlerts': highAlerts,
        'services': {
          'monitoring': _isInitialized,
          'analytics': true,
          'errorTracking': true,
        },
      };
    } catch (e) {
      await _errorService.trackError(
        errorType: 'health_check_error',
        errorMessage: 'Failed to perform health check: $e',
        severity: 'high',
        component: 'monitoring_integration',
      );
      
      return {
        'status': 'error',
        'timestamp': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }
}