// Communication Monitoring Service for TALOWA In-App Communication System
// Implements Task 16: Implement monitoring and analytics - Real-time Monitoring

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/messaging/communication_analytics_models.dart';

/// Real-time monitoring service for WebSocket connections and message delivery
class CommunicationMonitoringService {
  static final CommunicationMonitoringService _instance = 
      CommunicationMonitoringService._internal();
  factory CommunicationMonitoringService() => _instance;
  CommunicationMonitoringService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // In-memory tracking for real-time metrics
  final Map<String, WebSocketMetrics> _activeConnections = {};
  final Map<String, MessageDeliveryMetrics> _pendingMessages = {};
  final Map<String, VoiceCallMetrics> _activeCalls = {};
  final List<SystemAlert> _activeAlerts = [];
  
  // Performance tracking
  final Map<String, List<double>> _latencyHistory = {};
  final Map<String, int> _messageCounters = {};
  
  // Timers for periodic tasks
  Timer? _metricsUploadTimer;
  Timer? _healthCheckTimer;
  Timer? _alertCheckTimer;

  /// Initialize monitoring service
  Future<void> initialize() async {
    try {
      debugPrint('Initializing Communication Monitoring Service...');
      
      // Start periodic tasks
      _startMetricsUpload();
      _startHealthChecks();
      _startAlertMonitoring();
      
      debugPrint('Communication Monitoring Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Communication Monitoring Service: $e');
      rethrow;
    }
  }

  /// Dispose monitoring service
  void dispose() {
    _metricsUploadTimer?.cancel();
    _healthCheckTimer?.cancel();
    _alertCheckTimer?.cancel();
    
    _activeConnections.clear();
    _pendingMessages.clear();
    _activeCalls.clear();
    _activeAlerts.clear();
  }

  // WebSocket Connection Monitoring

  /// Track new WebSocket connection
  Future<void> trackConnectionStart({
    required String connectionId,
    required String userId,
  }) async {
    try {
      final metrics = WebSocketMetrics(
        connectionId: connectionId,
        userId: userId,
        connectedAt: DateTime.now(),
        messagesReceived: 0,
        messagesSent: 0,
        reconnectionAttempts: 0,
        events: [
          ConnectionEvent(
            eventType: 'connection_established',
            timestamp: DateTime.now(),
            description: 'WebSocket connection established',
          ),
        ],
        quality: ConnectionQuality.empty(),
      );

      _activeConnections[connectionId] = metrics;
      
      debugPrint('Tracking WebSocket connection: $connectionId for user: $userId');
    } catch (e) {
      debugPrint('Error tracking connection start: $e');
    }
  }

  /// Track WebSocket connection end
  Future<void> trackConnectionEnd({
    required String connectionId,
    String? reason,
  }) async {
    try {
      final metrics = _activeConnections[connectionId];
      if (metrics == null) return;

      final now = DateTime.now();
      final updatedMetrics = WebSocketMetrics(
        connectionId: metrics.connectionId,
        userId: metrics.userId,
        connectedAt: metrics.connectedAt,
        disconnectedAt: now,
        connectionDuration: now.difference(metrics.connectedAt),
        messagesReceived: metrics.messagesReceived,
        messagesSent: metrics.messagesSent,
        reconnectionAttempts: metrics.reconnectionAttempts,
        events: [
          ...metrics.events,
          ConnectionEvent(
            eventType: 'connection_closed',
            timestamp: now,
            description: reason ?? 'Connection closed',
          ),
        ],
        quality: metrics.quality,
      );

      // Store final metrics
      await _storeConnectionMetrics(updatedMetrics);
      
      // Remove from active tracking
      _activeConnections.remove(connectionId);
      
      debugPrint('Connection ended: $connectionId, Duration: ${updatedMetrics.connectionDuration}');
    } catch (e) {
      debugPrint('Error tracking connection end: $e');
    }
  }

  /// Track WebSocket reconnection attempt
  Future<void> trackReconnectionAttempt({
    required String connectionId,
    required bool successful,
  }) async {
    try {
      final metrics = _activeConnections[connectionId];
      if (metrics == null) return;

      final updatedMetrics = WebSocketMetrics(
        connectionId: metrics.connectionId,
        userId: metrics.userId,
        connectedAt: metrics.connectedAt,
        disconnectedAt: metrics.disconnectedAt,
        connectionDuration: metrics.connectionDuration,
        messagesReceived: metrics.messagesReceived,
        messagesSent: metrics.messagesSent,
        reconnectionAttempts: metrics.reconnectionAttempts + 1,
        events: [
          ...metrics.events,
          ConnectionEvent(
            eventType: successful ? 'reconnection_success' : 'reconnection_failed',
            timestamp: DateTime.now(),
            description: successful 
                ? 'Reconnection successful' 
                : 'Reconnection failed',
          ),
        ],
        quality: metrics.quality,
      );

      _activeConnections[connectionId] = updatedMetrics;
      
      // Alert on multiple failed reconnections
      if (!successful && updatedMetrics.reconnectionAttempts >= 3) {
        await _createAlert(
          alertType: 'connection_instability',
          severity: 'medium',
          message: 'Multiple reconnection failures for connection $connectionId',
          metadata: {'connectionId': connectionId, 'attempts': updatedMetrics.reconnectionAttempts},
        );
      }
    } catch (e) {
      debugPrint('Error tracking reconnection attempt: $e');
    }
  }

  /// Update connection quality metrics
  Future<void> updateConnectionQuality({
    required String connectionId,
    required double latency,
    required double packetLoss,
    required double jitter,
  }) async {
    try {
      final metrics = _activeConnections[connectionId];
      if (metrics == null) return;

      // Update latency history
      _latencyHistory[connectionId] ??= [];
      _latencyHistory[connectionId]!.add(latency);
      
      // Keep only last 100 measurements
      if (_latencyHistory[connectionId]!.length > 100) {
        _latencyHistory[connectionId]!.removeAt(0);
      }

      final latencies = _latencyHistory[connectionId]!;
      final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
      
      // Determine quality rating
      String qualityRating;
      if (avgLatency < 50 && packetLoss < 0.01) {
        qualityRating = 'excellent';
      } else if (avgLatency < 150 && packetLoss < 0.05) {
        qualityRating = 'good';
      } else if (avgLatency < 300 && packetLoss < 0.1) {
        qualityRating = 'fair';
      } else {
        qualityRating = 'poor';
      }

      final quality = ConnectionQuality(
        averageLatency: avgLatency,
        packetLoss: packetLoss,
        jitter: jitter,
        droppedConnections: 0,
        qualityRating: qualityRating,
      );

      final updatedMetrics = WebSocketMetrics(
        connectionId: metrics.connectionId,
        userId: metrics.userId,
        connectedAt: metrics.connectedAt,
        disconnectedAt: metrics.disconnectedAt,
        connectionDuration: metrics.connectionDuration,
        messagesReceived: metrics.messagesReceived,
        messagesSent: metrics.messagesSent,
        reconnectionAttempts: metrics.reconnectionAttempts,
        events: metrics.events,
        quality: quality,
      );

      _activeConnections[connectionId] = updatedMetrics;

      // Alert on poor connection quality
      if (qualityRating == 'poor') {
        await _createAlert(
          alertType: 'poor_connection_quality',
          severity: 'medium',
          message: 'Poor connection quality detected for $connectionId',
          metadata: {
            'connectionId': connectionId,
            'latency': avgLatency,
            'packetLoss': packetLoss,
            'jitter': jitter,
          },
        );
      }
    } catch (e) {
      debugPrint('Error updating connection quality: $e');
    }
  }

  // Message Delivery Monitoring

  /// Track message sending
  Future<void> trackMessageSent({
    required String messageId,
    required String senderId,
    String? recipientId,
    String? groupId,
    required String messageType,
    required int messageSize,
    required bool isEncrypted,
  }) async {
    try {
      final metrics = MessageDeliveryMetrics(
        messageId: messageId,
        senderId: senderId,
        recipientId: recipientId,
        groupId: groupId,
        sentAt: DateTime.now(),
        status: MessageDeliveryStatus.sent,
        deliveryAttempts: [
          DeliveryAttempt(
            attemptNumber: 1,
            timestamp: DateTime.now(),
            successful: true,
            responseTime: Duration.zero,
          ),
        ],
        messageType: messageType,
        messageSize: messageSize,
        isEncrypted: isEncrypted,
      );

      _pendingMessages[messageId] = metrics;
      
      // Update connection message counter
      final connectionId = _getConnectionIdForUser(senderId);
      if (connectionId != null) {
        await _incrementMessageCounter(connectionId, sent: true);
      }
      
      debugPrint('Tracking message sent: $messageId');
    } catch (e) {
      debugPrint('Error tracking message sent: $e');
    }
  }

  /// Track message delivery
  Future<void> trackMessageDelivered({
    required String messageId,
    String? recipientId,
  }) async {
    try {
      final metrics = _pendingMessages[messageId];
      if (metrics == null) return;

      final now = DateTime.now();
      final deliveryTime = now.difference(metrics.sentAt);

      final updatedMetrics = MessageDeliveryMetrics(
        messageId: metrics.messageId,
        senderId: metrics.senderId,
        recipientId: recipientId ?? metrics.recipientId,
        groupId: metrics.groupId,
        sentAt: metrics.sentAt,
        deliveredAt: now,
        readAt: metrics.readAt,
        deliveryTime: deliveryTime,
        status: MessageDeliveryStatus.delivered,
        deliveryAttempts: metrics.deliveryAttempts,
        messageType: metrics.messageType,
        messageSize: metrics.messageSize,
        isEncrypted: metrics.isEncrypted,
      );

      _pendingMessages[messageId] = updatedMetrics;
      
      // Update connection message counter
      if (recipientId != null) {
        final connectionId = _getConnectionIdForUser(recipientId);
        if (connectionId != null) {
          await _incrementMessageCounter(connectionId, received: true);
        }
      }

      // Alert on slow delivery (>5 seconds)
      if (deliveryTime.inSeconds > 5) {
        await _createAlert(
          alertType: 'slow_message_delivery',
          severity: 'low',
          message: 'Slow message delivery detected: ${deliveryTime.inSeconds}s',
          metadata: {
            'messageId': messageId,
            'deliveryTime': deliveryTime.inSeconds,
          },
        );
      }
      
      debugPrint('Message delivered: $messageId in ${deliveryTime.inMilliseconds}ms');
    } catch (e) {
      debugPrint('Error tracking message delivered: $e');
    }
  }

  /// Track message read
  Future<void> trackMessageRead({
    required String messageId,
    required String readerId,
  }) async {
    try {
      final metrics = _pendingMessages[messageId];
      if (metrics == null) return;

      final now = DateTime.now();
      final updatedMetrics = MessageDeliveryMetrics(
        messageId: metrics.messageId,
        senderId: metrics.senderId,
        recipientId: metrics.recipientId,
        groupId: metrics.groupId,
        sentAt: metrics.sentAt,
        deliveredAt: metrics.deliveredAt,
        readAt: now,
        deliveryTime: metrics.deliveryTime,
        status: MessageDeliveryStatus.read,
        deliveryAttempts: metrics.deliveryAttempts,
        messageType: metrics.messageType,
        messageSize: metrics.messageSize,
        isEncrypted: metrics.isEncrypted,
      );

      // Store final metrics and remove from pending
      await _storeMessageMetrics(updatedMetrics);
      _pendingMessages.remove(messageId);
      
      debugPrint('Message read: $messageId');
    } catch (e) {
      debugPrint('Error tracking message read: $e');
    }
  }

  /// Track message delivery failure
  Future<void> trackMessageDeliveryFailure({
    required String messageId,
    required String errorMessage,
    required int attemptNumber,
  }) async {
    try {
      final metrics = _pendingMessages[messageId];
      if (metrics == null) return;

      final failedAttempt = DeliveryAttempt(
        attemptNumber: attemptNumber,
        timestamp: DateTime.now(),
        successful: false,
        errorMessage: errorMessage,
        responseTime: Duration.zero,
      );

      final updatedMetrics = MessageDeliveryMetrics(
        messageId: metrics.messageId,
        senderId: metrics.senderId,
        recipientId: metrics.recipientId,
        groupId: metrics.groupId,
        sentAt: metrics.sentAt,
        deliveredAt: metrics.deliveredAt,
        readAt: metrics.readAt,
        deliveryTime: metrics.deliveryTime,
        status: attemptNumber >= 3 ? MessageDeliveryStatus.failed : MessageDeliveryStatus.pending,
        deliveryAttempts: [...metrics.deliveryAttempts, failedAttempt],
        messageType: metrics.messageType,
        messageSize: metrics.messageSize,
        isEncrypted: metrics.isEncrypted,
      );

      _pendingMessages[messageId] = updatedMetrics;

      // Create alert for failed delivery
      await _createAlert(
        alertType: 'message_delivery_failure',
        severity: attemptNumber >= 3 ? 'high' : 'medium',
        message: 'Message delivery failed: $errorMessage',
        metadata: {
          'messageId': messageId,
          'attemptNumber': attemptNumber,
          'errorMessage': errorMessage,
        },
      );
      
      debugPrint('Message delivery failed: $messageId, Attempt: $attemptNumber');
    } catch (e) {
      debugPrint('Error tracking message delivery failure: $e');
    }
  }

  // Voice Call Monitoring

  /// Track voice call start
  Future<void> trackCallStart({
    required String callId,
    required String callerId,
    required String recipientId,
  }) async {
    try {
      final metrics = VoiceCallMetrics(
        callId: callId,
        callerId: callerId,
        recipientId: recipientId,
        startTime: DateTime.now(),
        qualityMetrics: CallQualityMetrics.empty(),
        events: [
          CallEvent(
            eventType: 'call_initiated',
            timestamp: DateTime.now(),
            description: 'Voice call initiated',
          ),
        ],
        status: CallStatus.initiated,
      );

      _activeCalls[callId] = metrics;
      
      debugPrint('Tracking voice call start: $callId');
    } catch (e) {
      debugPrint('Error tracking call start: $e');
    }
  }

  /// Track voice call end
  Future<void> trackCallEnd({
    required String callId,
    required String endReason,
  }) async {
    try {
      final metrics = _activeCalls[callId];
      if (metrics == null) return;

      final now = DateTime.now();
      final callDuration = now.difference(metrics.startTime);

      final updatedMetrics = VoiceCallMetrics(
        callId: metrics.callId,
        callerId: metrics.callerId,
        recipientId: metrics.recipientId,
        startTime: metrics.startTime,
        endTime: now,
        callDuration: callDuration,
        qualityMetrics: metrics.qualityMetrics,
        events: [
          ...metrics.events,
          CallEvent(
            eventType: 'call_ended',
            timestamp: now,
            description: 'Call ended: $endReason',
          ),
        ],
        status: CallStatus.ended,
        endReason: endReason,
      );

      // Store final metrics
      await _storeCallMetrics(updatedMetrics);
      
      // Remove from active tracking
      _activeCalls.remove(callId);
      
      debugPrint('Call ended: $callId, Duration: ${callDuration.inSeconds}s');
    } catch (e) {
      debugPrint('Error tracking call end: $e');
    }
  }

  /// Update call quality metrics
  Future<void> updateCallQuality({
    required String callId,
    required double latency,
    required double packetLoss,
    required double jitter,
    required double audioQuality,
  }) async {
    try {
      final metrics = _activeCalls[callId];
      if (metrics == null) return;

      // Determine overall rating
      String overallRating;
      if (latency < 100 && packetLoss < 0.01 && audioQuality > 80) {
        overallRating = 'excellent';
      } else if (latency < 200 && packetLoss < 0.05 && audioQuality > 60) {
        overallRating = 'good';
      } else if (latency < 400 && packetLoss < 0.1 && audioQuality > 40) {
        overallRating = 'fair';
      } else {
        overallRating = 'poor';
      }

      final qualityMetrics = CallQualityMetrics(
        averageLatency: latency,
        maxLatency: latency * 1.5,
        minLatency: latency * 0.5,
        packetLoss: packetLoss,
        jitter: jitter,
        audioQuality: audioQuality,
        droppedPackets: 0,
        overallRating: overallRating,
      );

      final updatedMetrics = VoiceCallMetrics(
        callId: metrics.callId,
        callerId: metrics.callerId,
        recipientId: metrics.recipientId,
        startTime: metrics.startTime,
        endTime: metrics.endTime,
        callDuration: metrics.callDuration,
        qualityMetrics: qualityMetrics,
        events: metrics.events,
        status: metrics.status,
        endReason: metrics.endReason,
      );

      _activeCalls[callId] = updatedMetrics;

      // Alert on poor call quality
      if (overallRating == 'poor') {
        await _createAlert(
          alertType: 'poor_call_quality',
          severity: 'medium',
          message: 'Poor call quality detected for call $callId',
          metadata: {
            'callId': callId,
            'latency': latency,
            'packetLoss': packetLoss,
            'audioQuality': audioQuality,
          },
        );
      }
    } catch (e) {
      debugPrint('Error updating call quality: $e');
    }
  }

  // System Health Monitoring

  /// Get current system health metrics
  Future<SystemHealthMetrics> getSystemHealthMetrics() async {
    try {
      final now = DateTime.now();
      
      // Calculate real-time metrics
      final activeConnections = _activeConnections.length;
      final activeCalls = _activeCalls.length;
      final messagesPerSecond = _calculateMessagesPerSecond();
      
      // Mock server metrics (in real implementation, these would come from server monitoring)
      final serverCpuUsage = _mockServerMetric(20, 80);
      final serverMemoryUsage = _mockServerMetric(30, 90);
      final databaseResponseTime = _mockServerMetric(10, 200);
      
      // Service health scores
      final serviceHealthScores = <String, double>{
        'websocket_service': _calculateServiceHealth('websocket'),
        'messaging_service': _calculateServiceHealth('messaging'),
        'voice_service': _calculateServiceHealth('voice'),
        'database_service': _calculateServiceHealth('database'),
      };

      return SystemHealthMetrics(
        timestamp: now,
        activeConnections: activeConnections,
        totalUsers: activeConnections, // Simplified
        messagesPerSecond: messagesPerSecond,
        activeCalls: activeCalls,
        serverCpuUsage: serverCpuUsage,
        serverMemoryUsage: serverMemoryUsage,
        databaseResponseTime: databaseResponseTime,
        alerts: List.from(_activeAlerts),
        serviceHealthScores: serviceHealthScores,
      );
    } catch (e) {
      debugPrint('Error getting system health metrics: $e');
      rethrow;
    }
  }

  // Private helper methods

  void _startMetricsUpload() {
    _metricsUploadTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _uploadPendingMetrics();
    });
  }

  void _startHealthChecks() {
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _performHealthCheck();
    });
  }

  void _startAlertMonitoring() {
    _alertCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkForAlerts();
    });
  }

  Future<void> _uploadPendingMetrics() async {
    try {
      // Upload connection metrics
      for (final metrics in _activeConnections.values) {
        await _storeConnectionMetrics(metrics);
      }
      
      // Upload message metrics for completed messages
      final completedMessages = _pendingMessages.values
          .where((m) => m.status == MessageDeliveryStatus.read || 
                       m.status == MessageDeliveryStatus.failed)
          .toList();
      
      for (final metrics in completedMessages) {
        await _storeMessageMetrics(metrics);
        _pendingMessages.remove(metrics.messageId);
      }
      
      debugPrint('Uploaded ${completedMessages.length} message metrics');
    } catch (e) {
      debugPrint('Error uploading metrics: $e');
    }
  }

  Future<void> _performHealthCheck() async {
    try {
      final healthMetrics = await getSystemHealthMetrics();
      
      // Store health metrics
      await _firestore.collection('system_health').add(healthMetrics.toMap());
      
      // Check for critical issues
      if (healthMetrics.serverCpuUsage > 90) {
        await _createAlert(
          alertType: 'high_cpu_usage',
          severity: 'critical',
          message: 'Server CPU usage is critically high: ${healthMetrics.serverCpuUsage}%',
        );
      }
      
      if (healthMetrics.serverMemoryUsage > 95) {
        await _createAlert(
          alertType: 'high_memory_usage',
          severity: 'critical',
          message: 'Server memory usage is critically high: ${healthMetrics.serverMemoryUsage}%',
        );
      }
      
      if (healthMetrics.databaseResponseTime > 1000) {
        await _createAlert(
          alertType: 'slow_database',
          severity: 'high',
          message: 'Database response time is slow: ${healthMetrics.databaseResponseTime}ms',
        );
      }
    } catch (e) {
      debugPrint('Error performing health check: $e');
    }
  }

  Future<void> _checkForAlerts() async {
    try {
      // Check for connection issues
      final poorConnections = _activeConnections.values
          .where((c) => c.quality.qualityRating == 'poor')
          .length;
      
      if (poorConnections > _activeConnections.length * 0.2) {
        await _createAlert(
          alertType: 'widespread_connection_issues',
          severity: 'high',
          message: 'Multiple users experiencing poor connection quality',
          metadata: {'affectedConnections': poorConnections},
        );
      }
      
      // Check for message delivery issues
      final failedMessages = _pendingMessages.values
          .where((m) => m.status == MessageDeliveryStatus.failed)
          .length;
      
      if (failedMessages > 10) {
        await _createAlert(
          alertType: 'high_message_failure_rate',
          severity: 'high',
          message: 'High number of failed message deliveries: $failedMessages',
        );
      }
    } catch (e) {
      debugPrint('Error checking for alerts: $e');
    }
  }

  Future<void> _createAlert({
    required String alertType,
    required String severity,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final alert = SystemAlert(
        alertId: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        alertType: alertType,
        severity: severity,
        message: message,
        timestamp: DateTime.now(),
        resolved: false,
        metadata: metadata,
      );

      _activeAlerts.add(alert);
      
      // Store alert in database
      await _firestore.collection('system_alerts').add(alert.toMap());
      
      debugPrint('Alert created: $alertType - $message');
    } catch (e) {
      debugPrint('Error creating alert: $e');
    }
  }

  Future<void> _storeConnectionMetrics(WebSocketMetrics metrics) async {
    try {
      await _firestore.collection('websocket_metrics').add(metrics.toMap());
    } catch (e) {
      debugPrint('Error storing connection metrics: $e');
    }
  }

  Future<void> _storeMessageMetrics(MessageDeliveryMetrics metrics) async {
    try {
      await _firestore.collection('message_delivery_metrics').add(metrics.toMap());
    } catch (e) {
      debugPrint('Error storing message metrics: $e');
    }
  }

  Future<void> _storeCallMetrics(VoiceCallMetrics metrics) async {
    try {
      await _firestore.collection('voice_call_metrics').add(metrics.toMap());
    } catch (e) {
      debugPrint('Error storing call metrics: $e');
    }
  }

  String? _getConnectionIdForUser(String userId) {
    for (final entry in _activeConnections.entries) {
      if (entry.value.userId == userId) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _incrementMessageCounter(String connectionId, {bool sent = false, bool received = false}) async {
    final metrics = _activeConnections[connectionId];
    if (metrics == null) return;

    final updatedMetrics = WebSocketMetrics(
      connectionId: metrics.connectionId,
      userId: metrics.userId,
      connectedAt: metrics.connectedAt,
      disconnectedAt: metrics.disconnectedAt,
      connectionDuration: metrics.connectionDuration,
      messagesReceived: metrics.messagesReceived + (received ? 1 : 0),
      messagesSent: metrics.messagesSent + (sent ? 1 : 0),
      reconnectionAttempts: metrics.reconnectionAttempts,
      events: metrics.events,
      quality: metrics.quality,
    );

    _activeConnections[connectionId] = updatedMetrics;
  }

  int _calculateMessagesPerSecond() {
    final now = DateTime.now();
    final oneSecondAgo = now.subtract(const Duration(seconds: 1));
    
    return _pendingMessages.values
        .where((m) => m.sentAt.isAfter(oneSecondAgo))
        .length;
  }

  double _mockServerMetric(double min, double max) {
    final random = Random();
    return min + (random.nextDouble() * (max - min));
  }

  double _calculateServiceHealth(String serviceName) {
    // Simplified health calculation based on recent metrics
    switch (serviceName) {
      case 'websocket':
        final goodConnections = _activeConnections.values
            .where((c) => c.quality.qualityRating == 'excellent' || c.quality.qualityRating == 'good')
            .length;
        return _activeConnections.isEmpty ? 100.0 : (goodConnections / _activeConnections.length) * 100;
      
      case 'messaging':
        final successfulMessages = _pendingMessages.values
            .where((m) => m.status == MessageDeliveryStatus.delivered || m.status == MessageDeliveryStatus.read)
            .length;
        return _pendingMessages.isEmpty ? 100.0 : (successfulMessages / _pendingMessages.length) * 100;
      
      case 'voice':
        final goodCalls = _activeCalls.values
            .where((c) => c.qualityMetrics.overallRating == 'excellent' || c.qualityMetrics.overallRating == 'good')
            .length;
        return _activeCalls.isEmpty ? 100.0 : (goodCalls / _activeCalls.length) * 100;
      
      default:
        return 95.0; // Default good health
    }
  }
}