// Conversation Model for TALOWA Messaging System
import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String name;
  final ConversationType type;
  final List<String> participantIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String lastMessage;
  final String lastMessageSenderId;
  final Map<String, int> unreadCounts;
  final bool isActive;
  final String? description;
  final String? avatarUrl;
  final Map<String, dynamic> metadata;

  ConversationModel({
    required this.id,
    required this.name,
    required this.type,
    required this.participantIds,
    required this.createdBy,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.unreadCounts,
    required this.isActive,
    this.description,
    this.avatarUrl,
    required this.metadata,
  });

  // Convert from Firestore document
  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ConversationModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: ConversationTypeExtension.fromString(data['type'] ?? 'direct'),
      participantIds: List<String>.from(data['participantIds'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      isActive: data['isActive'] ?? true,
      description: data['description'],
      avatarUrl: data['avatarUrl'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.value,
      'participantIds': participantIds,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCounts': unreadCounts,
      'isActive': isActive,
      'description': description,
      'avatarUrl': avatarUrl,
      'metadata': metadata,
    };
  }

  // Copy with method for updates
  ConversationModel copyWith({
    String? id,
    String? name,
    ConversationType? type,
    List<String>? participantIds,
    String? createdBy,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? lastMessage,
    String? lastMessageSenderId,
    Map<String, int>? unreadCounts,
    bool? isActive,
    String? description,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      participantIds: participantIds ?? this.participantIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  // Get unread count for specific user
  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  // Get total participant count
  int get participantCount => participantIds.length;

  // Check if conversation has unread messages for user
  bool hasUnreadMessages(String userId) {
    return getUnreadCount(userId) > 0;
  }

  @override
  String toString() {
    return 'ConversationModel(id: $id, name: $name, type: ${type.value}, participants: ${participantIds.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Conversation types enum
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

  String get displayName {
    switch (this) {
      case ConversationType.direct:
        return 'Direct Message';
      case ConversationType.group:
        return 'Group Chat';
      case ConversationType.emergency:
        return 'Emergency Alert';
      case ConversationType.legalCase:
        return 'Legal Case';
      case ConversationType.anonymous:
        return 'Anonymous Report';
      case ConversationType.broadcast:
        return 'Broadcast';
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