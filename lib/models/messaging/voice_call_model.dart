// Voice Call Model for TALOWA Communication System
// Requirements: 3.1, 3.2, 3.3, 3.4, 3.6

import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceCallModel {
  final String id;
  final CallType type;
  final CallStatus status;
  final String callerId;
  final String recipientId;
  final Map<String, CallParticipant> participants;
  final DateTime initiatedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int? duration; // in seconds
  final SignalingInfo signaling;
  final CallQuality? quality;
  final bool isEncrypted;
  final String? encryptionProtocol;
  final String? linkedCaseId;
  final String? linkedCampaignId;
  final DateTime createdAt;
  final DateTime updatedAt;

  VoiceCallModel({
    required this.id,
    required this.type,
    required this.status,
    required this.callerId,
    required this.recipientId,
    required this.participants,
    required this.initiatedAt,
    this.connectedAt,
    this.endedAt,
    this.duration,
    required this.signaling,
    this.quality,
    required this.isEncrypted,
    this.encryptionProtocol,
    this.linkedCaseId,
    this.linkedCampaignId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert from Firestore document
  factory VoiceCallModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VoiceCallModel(
      id: doc.id,
      type: CallTypeExtension.fromString(data['type'] ?? 'voice'),
      status: CallStatusExtension.fromString(data['status'] ?? 'initiated'),
      callerId: data['callerId'] ?? '',
      recipientId: data['recipientId'] ?? '',
      participants: _parseParticipants(data['participants'] ?? {}),
      initiatedAt: (data['initiatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      connectedAt: (data['connectedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      duration: data['duration'],
      signaling: SignalingInfo.fromMap(data['signaling'] ?? {}),
      quality: data['quality'] != null ? CallQuality.fromMap(data['quality']) : null,
      isEncrypted: data['isEncrypted'] ?? false,
      encryptionProtocol: data['encryptionProtocol'],
      linkedCaseId: data['linkedCaseId'],
      linkedCampaignId: data['linkedCampaignId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.value,
      'status': status.value,
      'callerId': callerId,
      'recipientId': recipientId,
      'participants': _participantsToMap(),
      'initiatedAt': Timestamp.fromDate(initiatedAt),
      'connectedAt': connectedAt != null ? Timestamp.fromDate(connectedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'duration': duration,
      'signaling': signaling.toMap(),
      'quality': quality?.toMap(),
      'isEncrypted': isEncrypted,
      'encryptionProtocol': encryptionProtocol,
      'linkedCaseId': linkedCaseId,
      'linkedCampaignId': linkedCampaignId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Copy with method for updates
  VoiceCallModel copyWith({
    String? id,
    CallType? type,
    CallStatus? status,
    String? callerId,
    String? recipientId,
    Map<String, CallParticipant>? participants,
    DateTime? initiatedAt,
    DateTime? connectedAt,
    DateTime? endedAt,
    int? duration,
    SignalingInfo? signaling,
    CallQuality? quality,
    bool? isEncrypted,
    String? encryptionProtocol,
    String? linkedCaseId,
    String? linkedCampaignId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoiceCallModel(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      callerId: callerId ?? this.callerId,
      recipientId: recipientId ?? this.recipientId,
      participants: participants ?? this.participants,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      connectedAt: connectedAt ?? this.connectedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      signaling: signaling ?? this.signaling,
      quality: quality ?? this.quality,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptionProtocol: encryptionProtocol ?? this.encryptionProtocol,
      linkedCaseId: linkedCaseId ?? this.linkedCaseId,
      linkedCampaignId: linkedCampaignId ?? this.linkedCampaignId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  List<String> get participantIds => participants.keys.toList();
  
  bool get isActive => status == CallStatus.connecting || status == CallStatus.connected;
  
  bool get isCompleted => status == CallStatus.ended || status == CallStatus.failed || status == CallStatus.missed;

  // Private helper methods
  static Map<String, CallParticipant> _parseParticipants(Map<String, dynamic> data) {
    final participants = <String, CallParticipant>{};
    data.forEach((key, value) {
      participants[key] = CallParticipant.fromMap(value);
    });
    return participants;
  }

  Map<String, dynamic> _participantsToMap() {
    final map = <String, dynamic>{};
    participants.forEach((key, value) {
      map[key] = value.toMap();
    });
    return map;
  }

  @override
  String toString() {
    return 'VoiceCallModel(id: $id, status: ${status.value}, caller: $callerId, recipient: $recipientId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoiceCallModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Call participant model
class CallParticipant {
  final String userId;
  final String name;
  final String role;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final ConnectionQuality connectionQuality;
  final bool isMuted;
  final bool isSpeakerOn;

  CallParticipant({
    required this.userId,
    required this.name,
    required this.role,
    this.joinedAt,
    this.leftAt,
    required this.connectionQuality,
    required this.isMuted,
    required this.isSpeakerOn,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'role': role,
      'joinedAt': joinedAt?.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'connectionQuality': connectionQuality.value,
      'isMuted': isMuted,
      'isSpeakerOn': isSpeakerOn,
    };
  }

  factory CallParticipant.fromMap(Map<String, dynamic> map) {
    return CallParticipant(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      joinedAt: map['joinedAt'] != null ? DateTime.parse(map['joinedAt']) : null,
      leftAt: map['leftAt'] != null ? DateTime.parse(map['leftAt']) : null,
      connectionQuality: ConnectionQualityExtension.fromString(map['connectionQuality'] ?? 'good'),
      isMuted: map['isMuted'] ?? false,
      isSpeakerOn: map['isSpeakerOn'] ?? false,
    );
  }

  CallParticipant copyWith({
    String? userId,
    String? name,
    String? role,
    DateTime? joinedAt,
    DateTime? leftAt,
    ConnectionQuality? connectionQuality,
    bool? isMuted,
    bool? isSpeakerOn,
  }) {
    return CallParticipant(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
    );
  }
}

// Signaling information model
class SignalingInfo {
  final String serverId;
  final String roomId;
  final List<String> turnServersUsed;

  SignalingInfo({
    required this.serverId,
    required this.roomId,
    required this.turnServersUsed,
  });

  Map<String, dynamic> toMap() {
    return {
      'serverId': serverId,
      'roomId': roomId,
      'turnServersUsed': turnServersUsed,
    };
  }

  factory SignalingInfo.fromMap(Map<String, dynamic> map) {
    return SignalingInfo(
      serverId: map['serverId'] ?? '',
      roomId: map['roomId'] ?? '',
      turnServersUsed: List<String>.from(map['turnServersUsed'] ?? []),
    );
  }
}

// Call quality metrics model
class CallQuality {
  final double averageLatency;
  final double packetLoss;
  final double jitter;
  final AudioQuality audioQuality;

  CallQuality({
    required this.averageLatency,
    required this.packetLoss,
    required this.jitter,
    required this.audioQuality,
  });

  Map<String, dynamic> toMap() {
    return {
      'averageLatency': averageLatency,
      'packetLoss': packetLoss,
      'jitter': jitter,
      'audioQuality': audioQuality.value,
    };
  }

  factory CallQuality.fromMap(Map<String, dynamic> map) {
    return CallQuality(
      averageLatency: (map['averageLatency'] ?? 0.0).toDouble(),
      packetLoss: (map['packetLoss'] ?? 0.0).toDouble(),
      jitter: (map['jitter'] ?? 0.0).toDouble(),
      audioQuality: AudioQualityExtension.fromString(map['audioQuality'] ?? 'good'),
    );
  }
}

// Enums and extensions
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
      default:
        return CallStatus.initiated;
    }
  }
}

enum ConnectionQuality {
  excellent,
  good,
  poor,
  disconnected,
}

extension ConnectionQualityExtension on ConnectionQuality {
  String get value {
    switch (this) {
      case ConnectionQuality.excellent:
        return 'excellent';
      case ConnectionQuality.good:
        return 'good';
      case ConnectionQuality.poor:
        return 'poor';
      case ConnectionQuality.disconnected:
        return 'disconnected';
    }
  }

  static ConnectionQuality fromString(String quality) {
    switch (quality.toLowerCase()) {
      case 'excellent':
        return ConnectionQuality.excellent;
      case 'poor':
        return ConnectionQuality.poor;
      case 'disconnected':
        return ConnectionQuality.disconnected;
      default:
        return ConnectionQuality.good;
    }
  }
}

enum AudioQuality {
  excellent,
  good,
  poor,
}

extension AudioQualityExtension on AudioQuality {
  String get value {
    switch (this) {
      case AudioQuality.excellent:
        return 'excellent';
      case AudioQuality.good:
        return 'good';
      case AudioQuality.poor:
        return 'poor';
    }
  }

  static AudioQuality fromString(String quality) {
    switch (quality.toLowerCase()) {
      case 'excellent':
        return AudioQuality.excellent;
      case 'poor':
        return AudioQuality.poor;
      default:
        return AudioQuality.good;
    }
  }
}