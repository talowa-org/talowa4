// Communication Analytics Service for TALOWA In-App Communication System
// Implements Task 16: Implement monitoring and analytics - Performance Dashboards & User Engagement Analytics

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/messaging/communication_analytics_models.dart';

/// Analytics service for messaging and calling features
class CommunicationAnalyticsService {
  static final CommunicationAnalyticsService _instance = 
      CommunicationAnalyticsService._internal();
  factory CommunicationAnalyticsService() => _instance;
  CommunicationAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user engagement analytics for messaging features
  Future<MessagingEngagementMetrics> getUserEngagementMetrics({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _getDateRange(startDate, endDate);
      
      // Query message metrics
      final messageMetrics = await _getUserMessageMetrics(userId, dateRange);
      
      // Query call metrics
      final callMetrics = await _getUserCallMetrics(userId, dateRange);
      
      // Query group activity
      final groupActivity = await _getUserGroupActivity(userId, dateRange);
      
      // Calculate engagement score
      final engagementScore = _calculateEngagementScore(
        messagesSent: messageMetrics['sent'] ?? 0,
        messagesReceived: messageMetrics['received'] ?? 0,
        callsMade: callMetrics['made'] ?? 0,
        callsReceived: callMetrics['received'] ?? 0,
        groupsActive: groupActivity['activeGroups'] ?? 0,
      );

      return MessagingEngagementMetrics(
        userId: userId,
        dateRange: dateRange.start,
        messagesSent: messageMetrics['sent'] ?? 0,
        messagesReceived: messageMetrics['received'] ?? 0,
        groupsActive: groupActivity['activeGroups'] ?? 0,
        callsMade: callMetrics['made'] ?? 0,
        callsReceived: callMetrics['received'] ?? 0,
        totalCallTime: Duration(seconds: callMetrics['totalTime'] ?? 0),
        averageResponseTime: Duration(milliseconds: messageMetrics['avgResponseTime'] ?? 0),
        engagementScore: engagementScore,
        mostActiveGroups: List<String>.from(groupActivity['topGroups'] ?? []),
        messageTypeBreakdown: Map<String, int>.from(messageMetrics['typeBreakdown'] ?? {}),
      );
    } catch (e) {
      debugPrint('Error getting user engagement metrics: $e');
      rethrow;
    }
  }

  /// Get group activity analytics
  Future<GroupActivityMetrics> getGroupActivityMetrics({
    required String groupId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _getDateRange(startDate, endDate);
      
      // Get group information
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupData = groupDoc.data() ?? {};
      final groupName = groupData['name'] ?? 'Unknown Group';
      
      // Query group message activity
      final messageActivity = await _getGroupMessageActivity(groupId, dateRange);
      
      // Query group member activity
      final memberActivity = await _getGroupMemberActivity(groupId, dateRange);
      
      // Query group call activity
      final callActivity = await _getGroupCallActivity(groupId, dateRange);
      
      // Calculate engagement rate
      final totalMembers = memberActivity['totalMembers'] ?? 0;
      final activeMembers = memberActivity['activeMembers'] ?? 0;
      final engagementRate = totalMembers > 0 ? (activeMembers / totalMembers) : 0.0;

      return GroupActivityMetrics(
        groupId: groupId,
        groupName: groupName,
        dateRange: dateRange.start,
        totalMembers: totalMembers,
        activeMembers: activeMembers,
        messagesSent: messageActivity['totalMessages'] ?? 0,
        mediaFilesShared: messageActivity['mediaFiles'] ?? 0,
        callsInitiated: callActivity['totalCalls'] ?? 0,
        averageResponseTime: Duration(milliseconds: messageActivity['avgResponseTime'] ?? 0),
        engagementRate: engagementRate,
        mostActiveMembers: List<String>.from(memberActivity['topMembers'] ?? []),
        activityByHour: Map<String, int>.from(messageActivity['hourlyActivity'] ?? {}),
        messageTypeDistribution: Map<String, int>.from(messageActivity['typeDistribution'] ?? {}),
      );
    } catch (e) {
      debugPrint('Error getting group activity metrics: $e');
      rethrow;
    }
  }

  /// Get performance dashboard data
  Future<Map<String, dynamic>> getPerformanceDashboard({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _getDateRange(startDate, endDate);
      
      // Get various performance metrics
      final results = await Future.wait([
        _getConnectionPerformanceMetrics(dateRange),
        _getMessageDeliveryPerformanceMetrics(dateRange),
        _getCallQualityPerformanceMetrics(dateRange),
        _getSystemPerformanceMetrics(dateRange),
      ]);

      return {
        'connectionMetrics': results[0],
        'messageDeliveryMetrics': results[1],
        'callQualityMetrics': results[2],
        'systemMetrics': results[3],
        'dateRange': {
          'start': dateRange.start.toIso8601String(),
          'end': dateRange.end.toIso8601String(),
        },
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting performance dashboard: $e');
      rethrow;
    }
  }

  /// Get real-time system health dashboard
  Future<Map<String, dynamic>> getSystemHealthDashboard() async {
    try {
      // Get latest system health metrics
      final healthSnapshot = await _firestore
          .collection('system_health')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      Map<String, dynamic> latestHealth = {};
      if (healthSnapshot.docs.isNotEmpty) {
        latestHealth = healthSnapshot.docs.first.data();
      }

      // Get active alerts
      final alertsSnapshot = await _firestore
          .collection('system_alerts')
          .where('resolved', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final activeAlerts = alertsSnapshot.docs
          .map((doc) => SystemAlert.fromMap(doc.data()))
          .toList();

      // Get recent performance trends
      final performanceTrends = await _getPerformanceTrends();

      return {
        'currentHealth': latestHealth,
        'activeAlerts': activeAlerts.map((a) => a.toMap()).toList(),
        'performanceTrends': performanceTrends,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting system health dashboard: $e');
      rethrow;
    }
  }

  /// Get usage reports for coordinators
  Future<Map<String, dynamic>> getCoordinatorUsageReport({
    required String coordinatorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _getDateRange(startDate, endDate);
      
      // Get coordinator's groups
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('coordinatorId', isEqualTo: coordinatorId)
          .get();

      final groupIds = groupsSnapshot.docs.map((doc) => doc.id).toList();
      
      // Get activity metrics for each group
      final groupMetrics = <String, dynamic>{};
      for (final groupId in groupIds) {
        final metrics = await getGroupActivityMetrics(
          groupId: groupId,
          startDate: dateRange.start,
          endDate: dateRange.end,
        );
        groupMetrics[groupId] = metrics.toMap();
      }

      // Calculate summary statistics
      final totalMembers = groupMetrics.values
          .map((g) => g['totalMembers'] as int? ?? 0)
          .fold(0, (a, b) => a + b);
      
      final totalMessages = groupMetrics.values
          .map((g) => g['messagesSent'] as int? ?? 0)
          .fold(0, (a, b) => a + b);
      
      final averageEngagement = groupMetrics.values
          .map((g) => g['engagementRate'] as double? ?? 0.0)
          .fold(0.0, (a, b) => a + b) / (groupMetrics.isNotEmpty ? groupMetrics.length : 1);

      return {
        'coordinatorId': coordinatorId,
        'dateRange': {
          'start': dateRange.start.toIso8601String(),
          'end': dateRange.end.toIso8601String(),
        },
        'summary': {
          'totalGroups': groupIds.length,
          'totalMembers': totalMembers,
          'totalMessages': totalMessages,
          'averageEngagement': averageEngagement,
        },
        'groupMetrics': groupMetrics,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting coordinator usage report: $e');
      rethrow;
    }
  }

  /// Get error tracking and alerting data
  Future<Map<String, dynamic>> getErrorTrackingData({
    DateTime? startDate,
    DateTime? endDate,
    String? severity,
  }) async {
    try {
      final dateRange = _getDateRange(startDate, endDate);
      
      // Build query for alerts
      Query query = _firestore.collection('system_alerts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
      
      if (severity != null) {
        query = query.where('severity', isEqualTo: severity);
      }
      
      final alertsSnapshot = await query
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final alerts = alertsSnapshot.docs
          .map((doc) => SystemAlert.fromMap(doc.data()))
          .toList();

      // Group alerts by type and severity
      final alertsByType = <String, int>{};
      final alertsBySeverity = <String, int>{};
      final alertTrends = <String, List<Map<String, dynamic>>>{};

      for (final alert in alerts) {
        // Count by type
        alertsByType[alert.alertType] = (alertsByType[alert.alertType] ?? 0) + 1;
        
        // Count by severity
        alertsBySeverity[alert.severity] = (alertsBySeverity[alert.severity] ?? 0) + 1;
        
        // Track trends
        final dateKey = '${alert.timestamp.year}-${alert.timestamp.month.toString().padLeft(2, '0')}-${alert.timestamp.day.toString().padLeft(2, '0')}';
        alertTrends[dateKey] ??= [];
        alertTrends[dateKey]!.add({
          'type': alert.alertType,
          'severity': alert.severity,
          'timestamp': alert.timestamp.toIso8601String(),
        });
      }

      // Calculate error rates
      final totalAlerts = alerts.length;
      final criticalAlerts = alertsBySeverity['critical'] ?? 0;
      final highAlerts = alertsBySeverity['high'] ?? 0;
      
      final errorRate = totalAlerts / dateRange.durationInDays;
      final criticalErrorRate = criticalAlerts / dateRange.durationInDays;

      return {
        'dateRange': {
          'start': dateRange.start.toIso8601String(),
          'end': dateRange.end.toIso8601String(),
        },
        'summary': {
          'totalAlerts': totalAlerts,
          'criticalAlerts': criticalAlerts,
          'highAlerts': highAlerts,
          'errorRate': errorRate,
          'criticalErrorRate': criticalErrorRate,
        },
        'alertsByType': alertsByType,
        'alertsBySeverity': alertsBySeverity,
        'alertTrends': alertTrends,
        'recentAlerts': alerts.take(20).map((a) => a.toMap()).toList(),
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting error tracking data: $e');
      rethrow;
    }
  }

  // Private helper methods

  DateRange _getDateRange(DateTime? startDate, DateTime? endDate) {
    final end = endDate ?? DateTime.now();
    final start = startDate ?? end.subtract(const Duration(days: 7));
    return DateRange(start: start, end: end);
  }

  Future<Map<String, dynamic>> _getUserMessageMetrics(String userId, DateRange dateRange) async {
    try {
      final sentSnapshot = await _firestore
          .collection('message_delivery_metrics')
          .where('senderId', isEqualTo: userId)
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final receivedSnapshot = await _firestore
          .collection('message_delivery_metrics')
          .where('recipientId', isEqualTo: userId)
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final sentMessages = sentSnapshot.docs.map((doc) => MessageDeliveryMetrics.fromMap(doc.data())).toList();
      final receivedMessages = receivedSnapshot.docs.map((doc) => MessageDeliveryMetrics.fromMap(doc.data())).toList();

      // Calculate response times
      final responseTimes = <int>[];
      for (final message in receivedMessages) {
        if (message.readAt != null) {
          responseTimes.add(message.readAt!.difference(message.sentAt).inMilliseconds);
        }
      }
      
      final avgResponseTime = responseTimes.isEmpty 
          ? 0 
          : responseTimes.reduce((a, b) => a + b) ~/ responseTimes.length;

      // Message type breakdown
      final typeBreakdown = <String, int>{};
      for (final message in [...sentMessages, ...receivedMessages]) {
        typeBreakdown[message.messageType] = (typeBreakdown[message.messageType] ?? 0) + 1;
      }

      return {
        'sent': sentMessages.length,
        'received': receivedMessages.length,
        'avgResponseTime': avgResponseTime,
        'typeBreakdown': typeBreakdown,
      };
    } catch (e) {
      debugPrint('Error getting user message metrics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getUserCallMetrics(String userId, DateRange dateRange) async {
    try {
      final callsSnapshot = await _firestore
          .collection('voice_call_metrics')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final allCalls = callsSnapshot.docs.map((doc) => VoiceCallMetrics.fromMap(doc.data())).toList();
      
      final callsMade = allCalls.where((c) => c.callerId == userId).length;
      final callsReceived = allCalls.where((c) => c.recipientId == userId).length;
      
      final totalTime = allCalls
          .where((c) => c.callerId == userId || c.recipientId == userId)
          .where((c) => c.callDuration != null)
          .map((c) => c.callDuration!.inSeconds)
          .fold(0, (a, b) => a + b);

      return {
        'made': callsMade,
        'received': callsReceived,
        'totalTime': totalTime,
      };
    } catch (e) {
      debugPrint('Error getting user call metrics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getUserGroupActivity(String userId, DateRange dateRange) async {
    try {
      // Get user's groups
      final groupsSnapshot = await _firestore
          .collection('group_members')
          .where('userId', isEqualTo: userId)
          .get();

      final groupIds = groupsSnapshot.docs.map((doc) => doc.data()['groupId'] as String).toList();
      
      // Get activity in each group
      final groupActivity = <String, int>{};
      for (final groupId in groupIds) {
        final messagesSnapshot = await _firestore
            .collection('message_delivery_metrics')
            .where('groupId', isEqualTo: groupId)
            .where('senderId', isEqualTo: userId)
            .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
            .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
            .get();
        
        groupActivity[groupId] = messagesSnapshot.docs.length;
      }

      // Sort groups by activity
      final sortedGroups = groupActivity.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'activeGroups': groupActivity.keys.where((k) => groupActivity[k]! > 0).length,
        'topGroups': sortedGroups.take(5).map((e) => e.key).toList(),
      };
    } catch (e) {
      debugPrint('Error getting user group activity: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getGroupMessageActivity(String groupId, DateRange dateRange) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('message_delivery_metrics')
          .where('groupId', isEqualTo: groupId)
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final messages = messagesSnapshot.docs.map((doc) => MessageDeliveryMetrics.fromMap(doc.data())).toList();
      
      // Calculate metrics
      final totalMessages = messages.length;
      final mediaFiles = messages.where((m) => m.messageType != 'text').length;
      
      // Response time calculation
      final responseTimes = messages
          .where((m) => m.readAt != null)
          .map((m) => m.readAt!.difference(m.sentAt).inMilliseconds)
          .toList();
      
      final avgResponseTime = responseTimes.isEmpty 
          ? 0 
          : responseTimes.reduce((a, b) => a + b) ~/ responseTimes.length;

      // Activity by hour
      final activityByHour = <String, int>{};
      for (final message in messages) {
        final hour = message.sentAt.hour.toString().padLeft(2, '0');
        activityByHour[hour] = (activityByHour[hour] ?? 0) + 1;
      }

      // Message type distribution
      final typeDistribution = <String, int>{};
      for (final message in messages) {
        typeDistribution[message.messageType] = (typeDistribution[message.messageType] ?? 0) + 1;
      }

      return {
        'totalMessages': totalMessages,
        'mediaFiles': mediaFiles,
        'avgResponseTime': avgResponseTime,
        'hourlyActivity': activityByHour,
        'typeDistribution': typeDistribution,
      };
    } catch (e) {
      debugPrint('Error getting group message activity: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getGroupMemberActivity(String groupId, DateRange dateRange) async {
    try {
      // Get group members
      final membersSnapshot = await _firestore
          .collection('group_members')
          .where('groupId', isEqualTo: groupId)
          .get();

      final memberIds = membersSnapshot.docs.map((doc) => doc.data()['userId'] as String).toList();
      
      // Get activity for each member
      final memberActivity = <String, int>{};
      for (final memberId in memberIds) {
        final messagesSnapshot = await _firestore
            .collection('message_delivery_metrics')
            .where('groupId', isEqualTo: groupId)
            .where('senderId', isEqualTo: memberId)
            .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
            .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
            .get();
        
        memberActivity[memberId] = messagesSnapshot.docs.length;
      }

      // Sort members by activity
      final sortedMembers = memberActivity.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final activeMembers = memberActivity.values.where((count) => count > 0).length;

      return {
        'totalMembers': memberIds.length,
        'activeMembers': activeMembers,
        'topMembers': sortedMembers.take(10).map((e) => e.key).toList(),
      };
    } catch (e) {
      debugPrint('Error getting group member activity: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getGroupCallActivity(String groupId, DateRange dateRange) async {
    try {
      // For group calls, we'd need to track them differently
      // This is a simplified implementation
      return {
        'totalCalls': 0, // Would be implemented based on group call tracking
      };
    } catch (e) {
      debugPrint('Error getting group call activity: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getConnectionPerformanceMetrics(DateRange dateRange) async {
    try {
      final connectionsSnapshot = await _firestore
          .collection('websocket_metrics')
          .where('connectedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('connectedAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final connections = connectionsSnapshot.docs.map((doc) => WebSocketMetrics.fromMap(doc.data())).toList();
      
      if (connections.isEmpty) {
        return {
          'totalConnections': 0,
          'averageLatency': 0.0,
          'connectionSuccessRate': 0.0,
          'averageConnectionDuration': 0,
        };
      }

      final totalConnections = connections.length;
      final successfulConnections = connections.where((c) => c.connectionDuration != null).length;
      final averageLatency = connections
          .map((c) => c.quality.averageLatency)
          .reduce((a, b) => a + b) / connections.length;
      
      final connectionDurations = connections
          .where((c) => c.connectionDuration != null)
          .map((c) => c.connectionDuration!.inSeconds)
          .toList();
      
      final averageConnectionDuration = connectionDurations.isEmpty 
          ? 0 
          : connectionDurations.reduce((a, b) => a + b) ~/ connectionDurations.length;

      return {
        'totalConnections': totalConnections,
        'averageLatency': averageLatency,
        'connectionSuccessRate': successfulConnections / totalConnections,
        'averageConnectionDuration': averageConnectionDuration,
      };
    } catch (e) {
      debugPrint('Error getting connection performance metrics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getMessageDeliveryPerformanceMetrics(DateRange dateRange) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('message_delivery_metrics')
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final messages = messagesSnapshot.docs.map((doc) => MessageDeliveryMetrics.fromMap(doc.data())).toList();
      
      if (messages.isEmpty) {
        return {
          'totalMessages': 0,
          'deliverySuccessRate': 0.0,
          'averageDeliveryTime': 0,
          'readRate': 0.0,
        };
      }

      final totalMessages = messages.length;
      final deliveredMessages = messages.where((m) => m.status == MessageDeliveryStatus.delivered || m.status == MessageDeliveryStatus.read).length;
      final readMessages = messages.where((m) => m.status == MessageDeliveryStatus.read).length;
      
      final deliveryTimes = messages
          .where((m) => m.deliveryTime != null)
          .map((m) => m.deliveryTime!.inMilliseconds)
          .toList();
      
      final averageDeliveryTime = deliveryTimes.isEmpty 
          ? 0 
          : deliveryTimes.reduce((a, b) => a + b) ~/ deliveryTimes.length;

      return {
        'totalMessages': totalMessages,
        'deliverySuccessRate': deliveredMessages / totalMessages,
        'averageDeliveryTime': averageDeliveryTime,
        'readRate': readMessages / totalMessages,
      };
    } catch (e) {
      debugPrint('Error getting message delivery performance metrics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getCallQualityPerformanceMetrics(DateRange dateRange) async {
    try {
      final callsSnapshot = await _firestore
          .collection('voice_call_metrics')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final calls = callsSnapshot.docs.map((doc) => VoiceCallMetrics.fromMap(doc.data())).toList();
      
      if (calls.isEmpty) {
        return {
          'totalCalls': 0,
          'callSuccessRate': 0.0,
          'averageCallDuration': 0,
          'averageAudioQuality': 0.0,
        };
      }

      final totalCalls = calls.length;
      final successfulCalls = calls.where((c) => c.status == CallStatus.ended && c.callDuration != null).length;
      
      final callDurations = calls
          .where((c) => c.callDuration != null)
          .map((c) => c.callDuration!.inSeconds)
          .toList();
      
      final averageCallDuration = callDurations.isEmpty 
          ? 0 
          : callDurations.reduce((a, b) => a + b) ~/ callDurations.length;

      final audioQualities = calls.map((c) => c.qualityMetrics.audioQuality).toList();
      final averageAudioQuality = audioQualities.isEmpty 
          ? 0.0 
          : audioQualities.reduce((a, b) => a + b) / audioQualities.length;

      return {
        'totalCalls': totalCalls,
        'callSuccessRate': successfulCalls / totalCalls,
        'averageCallDuration': averageCallDuration,
        'averageAudioQuality': averageAudioQuality,
      };
    } catch (e) {
      debugPrint('Error getting call quality performance metrics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getSystemPerformanceMetrics(DateRange dateRange) async {
    try {
      final healthSnapshot = await _firestore
          .collection('system_health')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final healthMetrics = healthSnapshot.docs.map((doc) => SystemHealthMetrics.fromMap(doc.data())).toList();
      
      if (healthMetrics.isEmpty) {
        return {
          'averageCpuUsage': 0.0,
          'averageMemoryUsage': 0.0,
          'averageDatabaseResponseTime': 0.0,
          'peakActiveConnections': 0,
        };
      }

      final averageCpuUsage = healthMetrics.map((h) => h.serverCpuUsage).reduce((a, b) => a + b) / healthMetrics.length;
      final averageMemoryUsage = healthMetrics.map((h) => h.serverMemoryUsage).reduce((a, b) => a + b) / healthMetrics.length;
      final averageDatabaseResponseTime = healthMetrics.map((h) => h.databaseResponseTime).reduce((a, b) => a + b) / healthMetrics.length;
      final peakActiveConnections = healthMetrics.map((h) => h.activeConnections).reduce(max);

      return {
        'averageCpuUsage': averageCpuUsage,
        'averageMemoryUsage': averageMemoryUsage,
        'averageDatabaseResponseTime': averageDatabaseResponseTime,
        'peakActiveConnections': peakActiveConnections,
      };
    } catch (e) {
      debugPrint('Error getting system performance metrics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getPerformanceTrends() async {
    try {
      final last24Hours = DateTime.now().subtract(const Duration(hours: 24));
      
      final healthSnapshot = await _firestore
          .collection('system_health')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(last24Hours))
          .orderBy('timestamp')
          .get();

      final healthMetrics = healthSnapshot.docs.map((doc) => SystemHealthMetrics.fromMap(doc.data())).toList();
      
      final trends = <String, List<Map<String, dynamic>>>{
        'cpuUsage': [],
        'memoryUsage': [],
        'activeConnections': [],
        'messagesPerSecond': [],
      };

      for (final metric in healthMetrics) {
        final timestamp = metric.timestamp.toIso8601String();
        
        trends['cpuUsage']!.add({
          'timestamp': timestamp,
          'value': metric.serverCpuUsage,
        });
        
        trends['memoryUsage']!.add({
          'timestamp': timestamp,
          'value': metric.serverMemoryUsage,
        });
        
        trends['activeConnections']!.add({
          'timestamp': timestamp,
          'value': metric.activeConnections,
        });
        
        trends['messagesPerSecond']!.add({
          'timestamp': timestamp,
          'value': metric.messagesPerSecond,
        });
      }

      return trends;
    } catch (e) {
      debugPrint('Error getting performance trends: $e');
      return {};
    }
  }

  double _calculateEngagementScore({
    required int messagesSent,
    required int messagesReceived,
    required int callsMade,
    required int callsReceived,
    required int groupsActive,
  }) {
    // Simple engagement score calculation
    double score = 0.0;
    
    score += messagesSent * 1.0;
    score += messagesReceived * 0.5;
    score += callsMade * 5.0;
    score += callsReceived * 2.5;
    score += groupsActive * 10.0;
    
    // Normalize to 0-100 scale
    return min(score / 10, 100.0);
  }
}

class DateRange {
  final DateTime start;
  final DateTime end;
  
  DateRange({required this.start, required this.end});
  
  int get durationInDays => end.difference(start).inDays;
}
