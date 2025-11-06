// Call History Model for TALOWA Messaging System
// Requirements: 3.4, 3.5, 3.6, 5.1, 5.2

import 'package:cloud_firestore/cloud_firestore.dart';

class CallHistoryModel {
  final String id;
  final String callId;
  final CallType type;
  final CallStatus status;
  final String callerId;
  final String callerName;
  final String callerRole;
  final String recipientId;
  final String recipientName;
  final String recipientRole;
  final DateTime initiatedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int duration; // in seconds
  final bool isIncoming;
  final bool isEncrypted;
  final CallQualityMetrics? qualityMetrics;
  final String? linkedCaseId;
  final String? linkedCampaignId;
  final DateTime createdAt;

  CallHistoryModel({
    required this.id,
    required this.callId,
    required this.type,
    required this.status,
    required this.callerId,
    required this.callerName,
    required this.callerRole,
    required this.recipientId,
    required this.recipientName,
    required this.recipientRole,
    required this.initiatedAt,
    this.connectedAt,
    this.endedAt,
    required this.duration,
    required this.isIncoming,
    required this.isEncrypted,
    this.qualityMetrics,
    this.linkedCaseId,
    this.linkedCampaignId,
    required this.createdAt,
  });

  factory CallHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CallHistoryModel(
      id: doc.id,
      callId: data['callId'] ?? '',
      type: CallTypeExtension.fromString(data['type'] ?? 'voice'),
      status: CallStatusExtension.fromString(data['status'] ?? 'ended'),
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? '',
      callerRole: data['callerRole'] ?? '',
      recipientId: data['recipientId'] ?? '',
      recipientName: data['recipientName'] ?? '',
      recipientRole: data['recipientRole'] ?? '',
      initiatedAt: (data['initiatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      connectedAt: (data['connectedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      duration: data['duration'] ?? 0,
      isIncoming: data['isIncoming'] ?? false,
      isEncrypted: data['isEncrypted'] ?? false,
      qualityMetrics: data['qualityMetrics'] != null 
          ? CallQualityMetrics.fromMap(data['qualityMetrics'])
          : null,
      linkedCaseId: data['linkedCaseId'],
      linkedCampaignId: data['linkedCampaignId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'callId': callId,
      'type': type.value,
      'status': status.value,
      'callerId': callerId,
      'callerName': callerName,
      'callerRole': callerRole,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientRole': recipientRole,
      'initiatedAt': Timestamp.fromDate(initiatedAt),
      'connectedAt': connectedAt != null ? Timestamp.fromDate(connectedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'duration': duration,
      'isIncoming': isIncoming,
      'isEncrypted': isEncrypted,
      'qualityMetrics': qualityMetrics?.toMap(),
      'linkedCaseId': linkedCaseId,
      'linkedCampaignId': linkedCampaignId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Get formatted duration string
  String get formattedDuration {
    if (duration < 60) {
      return '${duration}s';
    } else if (duration < 3600) {
      final minutes = duration ~/ 60;
      final seconds = duration % 60;
      return '${minutes}m ${seconds}s';
    } else {
      final hours = duration ~/ 3600;
      final minutes = (duration % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  /// Get formatted time display
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(initiatedAt);

    if (difference.inDays == 0) {
      return '${initiatedAt.hour.toString().padLeft(2, '0')}:${initiatedAt.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[initiatedAt.weekday - 1];
    } else {
      return '${initiatedAt.day}/${initiatedAt.month}/${initiatedAt.year}';
    }
  }

  /// Check if call was successful
  bool get wasSuccessful => status == CallStatus.ended && duration > 0;

  /// Check if call was missed
  bool get wasMissed => status == CallStatus.missed;

  /// Get other participant name
  String getOtherParticipantName(String currentUserId) {
    return currentUserId == callerId ? recipientName : callerName;
  }

  /// Get other participant role
  String getOtherParticipantRole(String currentUserId) {
    return currentUserId == callerId ? recipientRole : callerRole;
  }

  /// Create from VoiceCallModel
  factory CallHistoryModel.fromVoiceCall({
    required String voiceCallId,
    required String callerId,
    required String callerName,
    required String callerRole,
    required String recipientId,
    required String recipientName,
    required String recipientRole,
    required CallType type,
    required CallStatus status,
    required DateTime initiatedAt,
    DateTime? connectedAt,
    DateTime? endedAt,
    required int duration,
    required bool isIncoming,
    required bool isEncrypted,
    CallQualityMetrics? qualityMetrics,
    String? linkedCaseId,
    String? linkedCampaignId,
  }) {
    return CallHistoryModel(
      id: '', // Will be set by Firestore
      callId: voiceCallId,
      type: type,
      status: status,
      callerId: callerId,
      callerName: callerName,
      callerRole: callerRole,
      recipientId: recipientId,
      recipientName: recipientName,
      recipientRole: recipientRole,
      initiatedAt: initiatedAt,
      connectedAt: connectedAt,
      endedAt: endedAt,
      duration: duration,
      isIncoming: isIncoming,
      isEncrypted: isEncrypted,
      qualityMetrics: qualityMetrics,
      linkedCaseId: linkedCaseId,
      linkedCampaignId: linkedCampaignId,
      createdAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'CallHistoryModel(id: $id, type: ${type.value}, status: ${status.value}, duration: ${formattedDuration})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallHistoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class CallQualityMetrics {
  final double averageLatency;
  final double packetLoss;
  final double jitter;
  final String audioQuality;

  CallQualityMetrics({
    required this.averageLatency,
    required this.packetLoss,
    required this.jitter,
    required this.audioQuality,
  });

  factory CallQualityMetrics.fromMap(Map<String, dynamic> map) {
    return CallQualityMetrics(
      averageLatency: (map['averageLatency'] ?? 0.0).toDouble(),
      packetLoss: (map['packetLoss'] ?? 0.0).toDouble(),
      jitter: (map['jitter'] ?? 0.0).toDouble(),
      audioQuality: map['audioQuality'] ?? 'good',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'averageLatency': averageLatency,
      'packetLoss': packetLoss,
      'jitter': jitter,
      'audioQuality': audioQuality,
    };
  }

  /// Get overall quality score (0-100)
  int get qualityScore {
    double score = 100.0;
    
    // Penalize high latency (>200ms is poor)
    if (averageLatency > 200) {
      score -= (averageLatency - 200) / 10;
    }
    
    // Penalize packet loss (>5% is poor)
    if (packetLoss > 5) {
      score -= (packetLoss - 5) * 10;
    }
    
    // Penalize high jitter (>50ms is poor)
    if (jitter > 50) {
      score -= (jitter - 50) / 5;
    }
    
    return score.clamp(0, 100).round();
  }

  /// Get quality description
  String get qualityDescription {
    final score = qualityScore;
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Poor';
  }
}

enum CallType {
  voice,
  video,
}

extension CallTypeExtension on CallType {
  String get value {
    switch (this) {
      case CallType.voice:
        return 'voice';
      case CallType.video:
        return 'video';
    }
  }

  String get displayName {
    switch (this) {
      case CallType.voice:
        return 'Voice Call';
      case CallType.video:
        return 'Video Call';
    }
  }

  static CallType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return CallType.video;
      default:
        return CallType.voice;
    }
  }
}

enum CallStatus {
  initiated,
  ringing,
  connecting,
  connected,
  ended,
  failed,
  missed,
  rejected,
}

extension CallStatusExtension on CallStatus {
  String get value {
    switch (this) {
      case CallStatus.initiated:
        return 'initiated';
      case CallStatus.ringing:
        return 'ringing';
      case CallStatus.connecting:
        return 'connecting';
      case CallStatus.connected:
        return 'connected';
      case CallStatus.ended:
        return 'ended';
      case CallStatus.failed:
        return 'failed';
      case CallStatus.missed:
        return 'missed';
      case CallStatus.rejected:
        return 'rejected';
    }
  }

  String get displayName {
    switch (this) {
      case CallStatus.initiated:
        return 'Initiating';
      case CallStatus.ringing:
        return 'Ringing';
      case CallStatus.connecting:
        return 'Connecting';
      case CallStatus.connected:
        return 'Connected';
      case CallStatus.ended:
        return 'Completed';
      case CallStatus.failed:
        return 'Failed';
      case CallStatus.missed:
        return 'Missed';
      case CallStatus.rejected:
        return 'Rejected';
    }
  }

  static CallStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'ringing':
        return CallStatus.ringing;
      case 'connecting':
        return CallStatus.connecting;
      case 'connected':
        return CallStatus.connected;
      case 'ended':
        return CallStatus.ended;
      case 'failed':
        return CallStatus.failed;
      case 'missed':
        return CallStatus.missed;
      case 'rejected':
        return CallStatus.rejected;
      default:
        return CallStatus.initiated;
    }
  }
}