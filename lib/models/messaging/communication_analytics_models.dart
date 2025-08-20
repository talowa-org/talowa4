// Communication Analytics Models for TALOWA In-App Communication System
// Implements Task 16: Implement monitoring and analytics - Data Models

import 'package:cloud_firestore/cloud_firestore.dart';

/// WebSocket connection monitoring metrics
class WebSocketMetrics {
  final String connectionId;
  final String userId;
  final DateTime connectedAt;
  final DateTime? disconnectedAt;
  final Duration? connectionDuration;
  final int messagesReceived;
  final int messagesSent;
  final int reconnectionAttempts;
  final List<ConnectionEvent> events;
  final ConnectionQuality quality;

  WebSocketMetrics({
    required this.connectionId,
    required this.userId,
    required this.connectedAt,
    this.disconnectedAt,
    this.connectionDuration,
    required this.messagesReceived,
    required this.messagesSent,
    required this.reconnectionAttempts,
    required this.events,
    required this.quality,
  });

  Map<String, dynamic> toMap() {
    return {
      'connectionId': connectionId,
      'userId': userId,
      'connectedAt': Timestamp.fromDate(connectedAt),
      'disconnectedAt': disconnectedAt != null ? Timestamp.fromDate(disconnectedAt!) : null,
      'connectionDuration': connectionDuration?.inMilliseconds,
      'messagesReceived': messagesReceived,
      'messagesSent': messagesSent,
      'reconnectionAttempts': reconnectionAttempts,
      'events': events.map((e) => e.toMap()).toList(),
      'quality': quality.toMap(),
    };
  }

  static WebSocketMetrics fromMap(Map<String, dynamic> map) {
    return WebSocketMetrics(
      connectionId: map['connectionId'] ?? '',
      userId: map['userId'] ?? '',
      connectedAt: (map['connectedAt'] as Timestamp).toDate(),
      disconnectedAt: map['disconnectedAt'] != null 
          ? (map['disconnectedAt'] as Timestamp).toDate() 
          : null,
      connectionDuration: map['connectionDuration'] != null 
          ? Duration(milliseconds: map['connectionDuration']) 
          : null,
      messagesReceived: map['messagesReceived'] ?? 0,
      messagesSent: map['messagesSent'] ?? 0,
      reconnectionAttempts: map['reconnectionAttempts'] ?? 0,
      events: (map['events'] as List<dynamic>? ?? [])
          .map((e) => ConnectionEvent.fromMap(e))
          .toList(),
      quality: ConnectionQuality.fromMap(map['quality'] ?? {}),
    );
  }
}

/// Connection event tracking
class ConnectionEvent {
  final String eventType;
  final DateTime timestamp;
  final String? description;
  final Map<String, dynamic>? metadata;

  ConnectionEvent({
    required this.eventType,
    required this.timestamp,
    this.description,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventType': eventType,
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
      'metadata': metadata,
    };
  }

  static ConnectionEvent fromMap(Map<String, dynamic> map) {
    return ConnectionEvent(
      eventType: map['eventType'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      description: map['description'],
      metadata: map['metadata'],
    );
  }
}

/// Connection quality metrics
class ConnectionQuality {
  final double averageLatency;
  final double packetLoss;
  final double jitter;
  final int droppedConnections;
  final String qualityRating; // excellent, good, fair, poor

  ConnectionQuality({
    required this.averageLatency,
    required this.packetLoss,
    required this.jitter,
    required this.droppedConnections,
    required this.qualityRating,
  });

  Map<String, dynamic> toMap() {
    return {
      'averageLatency': averageLatency,
      'packetLoss': packetLoss,
      'jitter': jitter,
      'droppedConnections': droppedConnections,
      'qualityRating': qualityRating,
    };
  }

  static ConnectionQuality fromMap(Map<String, dynamic> map) {
    return ConnectionQuality(
      averageLatency: (map['averageLatency'] ?? 0.0).toDouble(),
      packetLoss: (map['packetLoss'] ?? 0.0).toDouble(),
      jitter: (map['jitter'] ?? 0.0).toDouble(),
      droppedConnections: map['droppedConnections'] ?? 0,
      qualityRating: map['qualityRating'] ?? 'unknown',
    );
  }

  static ConnectionQuality empty() {
    return ConnectionQuality(
      averageLatency: 0.0,
      packetLoss: 0.0,
      jitter: 0.0,
      droppedConnections: 0,
      qualityRating: 'unknown',
    );
  }
}

/// Message delivery analytics
class MessageDeliveryMetrics {
  final String messageId;
  final String senderId;
  final String? recipientId;
  final String? groupId;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final Duration? deliveryTime;
  final MessageDeliveryStatus status;
  final List<DeliveryAttempt> deliveryAttempts;
  final String messageType;
  final int messageSize;
  final bool isEncrypted;

  MessageDeliveryMetrics({
    required this.messageId,
    required this.senderId,
    this.recipientId,
    this.groupId,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.deliveryTime,
    required this.status,
    required this.deliveryAttempts,
    required this.messageType,
    required this.messageSize,
    required this.isEncrypted,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'recipientId': recipientId,
      'groupId': groupId,
      'sentAt': Timestamp.fromDate(sentAt),
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'deliveryTime': deliveryTime?.inMilliseconds,
      'status': status.toString(),
      'deliveryAttempts': deliveryAttempts.map((a) => a.toMap()).toList(),
      'messageType': messageType,
      'messageSize': messageSize,
      'isEncrypted': isEncrypted,
    };
  }

  static MessageDeliveryMetrics fromMap(Map<String, dynamic> map) {
    return MessageDeliveryMetrics(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'],
      groupId: map['groupId'],
      sentAt: (map['sentAt'] as Timestamp).toDate(),
      deliveredAt: map['deliveredAt'] != null 
          ? (map['deliveredAt'] as Timestamp).toDate() 
          : null,
      readAt: map['readAt'] != null 
          ? (map['readAt'] as Timestamp).toDate() 
          : null,
      deliveryTime: map['deliveryTime'] != null 
          ? Duration(milliseconds: map['deliveryTime']) 
          : null,
      status: MessageDeliveryStatus.values.firstWhere(
        (s) => s.toString() == map['status'],
        orElse: () => MessageDeliveryStatus.pending,
      ),
      deliveryAttempts: (map['deliveryAttempts'] as List<dynamic>? ?? [])
          .map((a) => DeliveryAttempt.fromMap(a))
          .toList(),
      messageType: map['messageType'] ?? '',
      messageSize: map['messageSize'] ?? 0,
      isEncrypted: map['isEncrypted'] ?? false,
    );
  }
}

/// Message delivery status
enum MessageDeliveryStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
  expired,
}

/// Delivery attempt tracking
class DeliveryAttempt {
  final int attemptNumber;
  final DateTime timestamp;
  final bool successful;
  final String? errorMessage;
  final Duration responseTime;

  DeliveryAttempt({
    required this.attemptNumber,
    required this.timestamp,
    required this.successful,
    this.errorMessage,
    required this.responseTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'attemptNumber': attemptNumber,
      'timestamp': Timestamp.fromDate(timestamp),
      'successful': successful,
      'errorMessage': errorMessage,
      'responseTime': responseTime.inMilliseconds,
    };
  }

  static DeliveryAttempt fromMap(Map<String, dynamic> map) {
    return DeliveryAttempt(
      attemptNumber: map['attemptNumber'] ?? 0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      successful: map['successful'] ?? false,
      errorMessage: map['errorMessage'],
      responseTime: Duration(milliseconds: map['responseTime'] ?? 0),
    );
  }
}

/// Voice call quality metrics
class VoiceCallMetrics {
  final String callId;
  final String callerId;
  final String recipientId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? callDuration;
  final CallQualityMetrics qualityMetrics;
  final List<CallEvent> events;
  final CallStatus status;
  final String? endReason;

  VoiceCallMetrics({
    required this.callId,
    required this.callerId,
    required this.recipientId,
    required this.startTime,
    this.endTime,
    this.callDuration,
    required this.qualityMetrics,
    required this.events,
    required this.status,
    this.endReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'recipientId': recipientId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'callDuration': callDuration?.inSeconds,
      'qualityMetrics': qualityMetrics.toMap(),
      'events': events.map((e) => e.toMap()).toList(),
      'status': status.toString(),
      'endReason': endReason,
    };
  }

  static VoiceCallMetrics fromMap(Map<String, dynamic> map) {
    return VoiceCallMetrics(
      callId: map['callId'] ?? '',
      callerId: map['callerId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null 
          ? (map['endTime'] as Timestamp).toDate() 
          : null,
      callDuration: map['callDuration'] != null 
          ? Duration(seconds: map['callDuration']) 
          : null,
      qualityMetrics: CallQualityMetrics.fromMap(map['qualityMetrics'] ?? {}),
      events: (map['events'] as List<dynamic>? ?? [])
          .map((e) => CallEvent.fromMap(e))
          .toList(),
      status: CallStatus.values.firstWhere(
        (s) => s.toString() == map['status'],
        orElse: () => CallStatus.unknown,
      ),
      endReason: map['endReason'],
    );
  }
}

/// Call quality metrics
class CallQualityMetrics {
  final double averageLatency;
  final double maxLatency;
  final double minLatency;
  final double packetLoss;
  final double jitter;
  final double audioQuality; // 0-100 score
  final int droppedPackets;
  final String overallRating; // excellent, good, fair, poor

  CallQualityMetrics({
    required this.averageLatency,
    required this.maxLatency,
    required this.minLatency,
    required this.packetLoss,
    required this.jitter,
    required this.audioQuality,
    required this.droppedPackets,
    required this.overallRating,
  });

  Map<String, dynamic> toMap() {
    return {
      'averageLatency': averageLatency,
      'maxLatency': maxLatency,
      'minLatency': minLatency,
      'packetLoss': packetLoss,
      'jitter': jitter,
      'audioQuality': audioQuality,
      'droppedPackets': droppedPackets,
      'overallRating': overallRating,
    };
  }

  static CallQualityMetrics fromMap(Map<String, dynamic> map) {
    return CallQualityMetrics(
      averageLatency: (map['averageLatency'] ?? 0.0).toDouble(),
      maxLatency: (map['maxLatency'] ?? 0.0).toDouble(),
      minLatency: (map['minLatency'] ?? 0.0).toDouble(),
      packetLoss: (map['packetLoss'] ?? 0.0).toDouble(),
      jitter: (map['jitter'] ?? 0.0).toDouble(),
      audioQuality: (map['audioQuality'] ?? 0.0).toDouble(),
      droppedPackets: map['droppedPackets'] ?? 0,
      overallRating: map['overallRating'] ?? 'unknown',
    );
  }

  static CallQualityMetrics empty() {
    return CallQualityMetrics(
      averageLatency: 0.0,
      maxLatency: 0.0,
      minLatency: 0.0,
      packetLoss: 0.0,
      jitter: 0.0,
      audioQuality: 0.0,
      droppedPackets: 0,
      overallRating: 'unknown',
    );
  }
}

/// Call event tracking
class CallEvent {
  final String eventType;
  final DateTime timestamp;
  final String? description;
  final Map<String, dynamic>? metadata;

  CallEvent({
    required this.eventType,
    required this.timestamp,
    this.description,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventType': eventType,
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
      'metadata': metadata,
    };
  }

  static CallEvent fromMap(Map<String, dynamic> map) {
    return CallEvent(
      eventType: map['eventType'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      description: map['description'],
      metadata: map['metadata'],
    );
  }
}

/// Call status
enum CallStatus {
  initiated,
  ringing,
  connected,
  ended,
  failed,
  missed,
  rejected,
  unknown,
}

/// User engagement analytics for messaging
class MessagingEngagementMetrics {
  final String userId;
  final DateTime dateRange;
  final int messagesSent;
  final int messagesReceived;
  final int groupsActive;
  final int callsMade;
  final int callsReceived;
  final Duration totalCallTime;
  final Duration averageResponseTime;
  final double engagementScore;
  final List<String> mostActiveGroups;
  final Map<String, int> messageTypeBreakdown;

  MessagingEngagementMetrics({
    required this.userId,
    required this.dateRange,
    required this.messagesSent,
    required this.messagesReceived,
    required this.groupsActive,
    required this.callsMade,
    required this.callsReceived,
    required this.totalCallTime,
    required this.averageResponseTime,
    required this.engagementScore,
    required this.mostActiveGroups,
    required this.messageTypeBreakdown,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'dateRange': Timestamp.fromDate(dateRange),
      'messagesSent': messagesSent,
      'messagesReceived': messagesReceived,
      'groupsActive': groupsActive,
      'callsMade': callsMade,
      'callsReceived': callsReceived,
      'totalCallTime': totalCallTime.inSeconds,
      'averageResponseTime': averageResponseTime.inMilliseconds,
      'engagementScore': engagementScore,
      'mostActiveGroups': mostActiveGroups,
      'messageTypeBreakdown': messageTypeBreakdown,
    };
  }

  static MessagingEngagementMetrics fromMap(Map<String, dynamic> map) {
    return MessagingEngagementMetrics(
      userId: map['userId'] ?? '',
      dateRange: (map['dateRange'] as Timestamp).toDate(),
      messagesSent: map['messagesSent'] ?? 0,
      messagesReceived: map['messagesReceived'] ?? 0,
      groupsActive: map['groupsActive'] ?? 0,
      callsMade: map['callsMade'] ?? 0,
      callsReceived: map['callsReceived'] ?? 0,
      totalCallTime: Duration(seconds: map['totalCallTime'] ?? 0),
      averageResponseTime: Duration(milliseconds: map['averageResponseTime'] ?? 0),
      engagementScore: (map['engagementScore'] ?? 0.0).toDouble(),
      mostActiveGroups: List<String>.from(map['mostActiveGroups'] ?? []),
      messageTypeBreakdown: Map<String, int>.from(map['messageTypeBreakdown'] ?? {}),
    );
  }
}

/// System health metrics
class SystemHealthMetrics {
  final DateTime timestamp;
  final int activeConnections;
  final int totalUsers;
  final int messagesPerSecond;
  final int activeCalls;
  final double serverCpuUsage;
  final double serverMemoryUsage;
  final double databaseResponseTime;
  final List<SystemAlert> alerts;
  final Map<String, double> serviceHealthScores;

  SystemHealthMetrics({
    required this.timestamp,
    required this.activeConnections,
    required this.totalUsers,
    required this.messagesPerSecond,
    required this.activeCalls,
    required this.serverCpuUsage,
    required this.serverMemoryUsage,
    required this.databaseResponseTime,
    required this.alerts,
    required this.serviceHealthScores,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'activeConnections': activeConnections,
      'totalUsers': totalUsers,
      'messagesPerSecond': messagesPerSecond,
      'activeCalls': activeCalls,
      'serverCpuUsage': serverCpuUsage,
      'serverMemoryUsage': serverMemoryUsage,
      'databaseResponseTime': databaseResponseTime,
      'alerts': alerts.map((a) => a.toMap()).toList(),
      'serviceHealthScores': serviceHealthScores,
    };
  }

  static SystemHealthMetrics fromMap(Map<String, dynamic> map) {
    return SystemHealthMetrics(
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      activeConnections: map['activeConnections'] ?? 0,
      totalUsers: map['totalUsers'] ?? 0,
      messagesPerSecond: map['messagesPerSecond'] ?? 0,
      activeCalls: map['activeCalls'] ?? 0,
      serverCpuUsage: (map['serverCpuUsage'] ?? 0.0).toDouble(),
      serverMemoryUsage: (map['serverMemoryUsage'] ?? 0.0).toDouble(),
      databaseResponseTime: (map['databaseResponseTime'] ?? 0.0).toDouble(),
      alerts: (map['alerts'] as List<dynamic>? ?? [])
          .map((a) => SystemAlert.fromMap(a))
          .toList(),
      serviceHealthScores: Map<String, double>.from(map['serviceHealthScores'] ?? {}),
    );
  }
}

/// System alert
class SystemAlert {
  final String alertId;
  final String alertType;
  final String severity; // low, medium, high, critical
  final String message;
  final DateTime timestamp;
  final bool resolved;
  final Map<String, dynamic>? metadata;

  SystemAlert({
    required this.alertId,
    required this.alertType,
    required this.severity,
    required this.message,
    required this.timestamp,
    required this.resolved,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'alertType': alertType,
      'severity': severity,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'resolved': resolved,
      'metadata': metadata,
    };
  }

  static SystemAlert fromMap(Map<String, dynamic> map) {
    return SystemAlert(
      alertId: map['alertId'] ?? '',
      alertType: map['alertType'] ?? '',
      severity: map['severity'] ?? 'low',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      resolved: map['resolved'] ?? false,
      metadata: map['metadata'],
    );
  }
}

/// Group activity analytics
class GroupActivityMetrics {
  final String groupId;
  final String groupName;
  final DateTime dateRange;
  final int totalMembers;
  final int activeMembers;
  final int messagesSent;
  final int mediaFilesShared;
  final int callsInitiated;
  final Duration averageResponseTime;
  final double engagementRate;
  final List<String> mostActiveMembers;
  final Map<String, int> activityByHour;
  final Map<String, int> messageTypeDistribution;

  GroupActivityMetrics({
    required this.groupId,
    required this.groupName,
    required this.dateRange,
    required this.totalMembers,
    required this.activeMembers,
    required this.messagesSent,
    required this.mediaFilesShared,
    required this.callsInitiated,
    required this.averageResponseTime,
    required this.engagementRate,
    required this.mostActiveMembers,
    required this.activityByHour,
    required this.messageTypeDistribution,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'dateRange': Timestamp.fromDate(dateRange),
      'totalMembers': totalMembers,
      'activeMembers': activeMembers,
      'messagesSent': messagesSent,
      'mediaFilesShared': mediaFilesShared,
      'callsInitiated': callsInitiated,
      'averageResponseTime': averageResponseTime.inMilliseconds,
      'engagementRate': engagementRate,
      'mostActiveMembers': mostActiveMembers,
      'activityByHour': activityByHour,
      'messageTypeDistribution': messageTypeDistribution,
    };
  }

  static GroupActivityMetrics fromMap(Map<String, dynamic> map) {
    return GroupActivityMetrics(
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      dateRange: (map['dateRange'] as Timestamp).toDate(),
      totalMembers: map['totalMembers'] ?? 0,
      activeMembers: map['activeMembers'] ?? 0,
      messagesSent: map['messagesSent'] ?? 0,
      mediaFilesShared: map['mediaFilesShared'] ?? 0,
      callsInitiated: map['callsInitiated'] ?? 0,
      averageResponseTime: Duration(milliseconds: map['averageResponseTime'] ?? 0),
      engagementRate: (map['engagementRate'] ?? 0.0).toDouble(),
      mostActiveMembers: List<String>.from(map['mostActiveMembers'] ?? []),
      activityByHour: Map<String, int>.from(map['activityByHour'] ?? {}),
      messageTypeDistribution: Map<String, int>.from(map['messageTypeDistribution'] ?? {}),
    );
  }
}