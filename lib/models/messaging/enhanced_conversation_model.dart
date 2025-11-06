// Enhanced Conversation Model for TALOWA Messaging System
// Requirements: 5.1, 5.2, 5.3, 5.4

import 'package:cloud_firestore/cloud_firestore.dart';

class EnhancedConversationModel {
  final String id;
  final String name;
  final ConversationType type;
  final List<String> participantIds;
  final Map<String, ConversationParticipant> participantDetails;
  final String? groupId;
  final String? groupName;
  final String? groupType;
  final LastMessage lastMessage;
  final Map<String, int> unreadCounts;
  final ConversationSettings settings;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  EnhancedConversationModel({
    required this.id,
    required this.name,
    required this.type,
    required this.participantIds,
    required this.participantDetails,
    this.groupId,
    this.groupName,
    this.groupType,
    required this.lastMessage,
    required this.unreadCounts,
    required this.settings,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  factory EnhancedConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return EnhancedConversationModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: ConversationTypeExtension.fromString(data['type'] ?? 'direct'),
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantDetails: _parseParticipantDetails(data['participantDetails'] ?? {}),
      groupId: data['groupId'],
      groupName: data['groupName'],
      groupType: data['groupType'],
      lastMessage: LastMessage.fromMap(data['lastMessage'] ?? {}),
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      settings: ConversationSettings.fromMap(data['settings'] ?? {}),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.value,
      'participantIds': participantIds,
      'participantDetails': _participantDetailsToMap(),
      'groupId': groupId,
      'groupName': groupName,
      'groupType': groupType,
      'lastMessage': lastMessage.toMap(),
      'unreadCounts': unreadCounts,
      'settings': settings.toMap(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  static Map<String, ConversationParticipant> _parseParticipantDetails(Map<String, dynamic> data) {
    final participants = <String, ConversationParticipant>{};
    data.forEach((key, value) {
      participants[key] = ConversationParticipant.fromMap(value);
    });
    return participants;
  }

  Map<String, dynamic> _participantDetailsToMap() {
    final map = <String, dynamic>{};
    participantDetails.forEach((key, value) {
      map[key] = value.toMap();
    });
    return map;
  }
}

class ConversationParticipant {
  final String name;
  final String role;
  final DateTime joinedAt;
  final DateTime? lastReadAt;

  ConversationParticipant({
    required this.name,
    required this.role,
    required this.joinedAt,
    this.lastReadAt,
  });

  factory ConversationParticipant.fromMap(Map<String, dynamic> map) {
    return ConversationParticipant(
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      joinedAt: map['joinedAt'] is Timestamp 
          ? (map['joinedAt'] as Timestamp).toDate()
          : DateTime.parse(map['joinedAt'] ?? DateTime.now().toIso8601String()),
      lastReadAt: map['lastReadAt'] != null
          ? (map['lastReadAt'] is Timestamp 
              ? (map['lastReadAt'] as Timestamp).toDate()
              : DateTime.parse(map['lastReadAt']))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastReadAt': lastReadAt != null ? Timestamp.fromDate(lastReadAt!) : null,
    };
  }
}

class LastMessage {
  final String id;
  final String content;
  final String senderId;
  final DateTime timestamp;
  final String type;

  LastMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.timestamp,
    required this.type,
  });

  factory LastMessage.fromMap(Map<String, dynamic> map) {
    return LastMessage(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      senderId: map['senderId'] ?? '',
      timestamp: map['timestamp'] is Timestamp 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      type: map['type'] ?? 'text',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'senderId': senderId,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
    };
  }
}

class ConversationSettings {
  final bool encryptionEnabled;
  final int retentionDays;
  final bool allowAnonymous;

  ConversationSettings({
    required this.encryptionEnabled,
    required this.retentionDays,
    required this.allowAnonymous,
  });

  factory ConversationSettings.fromMap(Map<String, dynamic> map) {
    return ConversationSettings(
      encryptionEnabled: map['encryptionEnabled'] ?? false,
      retentionDays: map['retentionDays'] ?? 30,
      allowAnonymous: map['allowAnonymous'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'encryptionEnabled': encryptionEnabled,
      'retentionDays': retentionDays,
      'allowAnonymous': allowAnonymous,
    };
  }
}

enum ConversationType {
  direct,
  group,
  emergency,
  legalCase,
  anonymous,
  broadcast,
}

extension ConversationTypeExtension on ConversationType {
  String get value {
    switch (this) {
      case ConversationType.direct:
        return 'direct';
      case ConversationType.group:
        return 'group';
      case ConversationType.emergency:
        return 'emergency';
      case ConversationType.legalCase:
        return 'legal_case';
      case ConversationType.anonymous:
        return 'anonymous';
      case ConversationType.broadcast:
        return 'broadcast';
    }
  }

  static ConversationType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'group':
        return ConversationType.group;
      case 'emergency':
        return ConversationType.emergency;
      case 'legal_case':
        return ConversationType.legalCase;
      case 'anonymous':
        return ConversationType.anonymous;
      case 'broadcast':
        return ConversationType.broadcast;
      default:
        return ConversationType.direct;
    }
  }
}