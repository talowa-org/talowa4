// Moderation Action Model for TALOWA Messaging System
import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationActionModel {
  final String id;
  final String targetUserId;
  final String targetUserName;
  final String moderatorId;
  final String moderatorName;
  final ModerationActionType actionType;
  final String reason;
  final String? description;
  final DateTime actionTaken;
  final DateTime? expiresAt;
  final bool isActive;
  final String? relatedReportId;
  final String? relatedMessageId;
  final Map<String, dynamic> metadata;

  ModerationActionModel({
    required this.id,
    required this.targetUserId,
    required this.targetUserName,
    required this.moderatorId,
    required this.moderatorName,
    required this.actionType,
    required this.reason,
    this.description,
    required this.actionTaken,
    this.expiresAt,
    required this.isActive,
    this.relatedReportId,
    this.relatedMessageId,
    required this.metadata,
  });

  // Convert from Firestore document
  factory ModerationActionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ModerationActionModel(
      id: doc.id,
      targetUserId: data['targetUserId'] ?? '',
      targetUserName: data['targetUserName'] ?? 'Unknown User',
      moderatorId: data['moderatorId'] ?? '',
      moderatorName: data['moderatorName'] ?? 'System',
      actionType: ModerationActionTypeExtension.fromString(data['actionType'] ?? 'warning'),
      reason: data['reason'] ?? '',
      description: data['description'],
      actionTaken: (data['actionTaken'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      relatedReportId: data['relatedReportId'],
      relatedMessageId: data['relatedMessageId'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
      'moderatorId': moderatorId,
      'moderatorName': moderatorName,
      'actionType': actionType.value,
      'reason': reason,
      'description': description,
      'actionTaken': Timestamp.fromDate(actionTaken),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'relatedReportId': relatedReportId,
      'relatedMessageId': relatedMessageId,
      'metadata': metadata,
    };
  }

  // Copy with method for updates
  ModerationActionModel copyWith({
    String? id,
    String? targetUserId,
    String? targetUserName,
    String? moderatorId,
    String? moderatorName,
    ModerationActionType? actionType,
    String? reason,
    String? description,
    DateTime? actionTaken,
    DateTime? expiresAt,
    bool? isActive,
    String? relatedReportId,
    String? relatedMessageId,
    Map<String, dynamic>? metadata,
  }) {
    return ModerationActionModel(
      id: id ?? this.id,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      moderatorId: moderatorId ?? this.moderatorId,
      moderatorName: moderatorName ?? this.moderatorName,
      actionType: actionType ?? this.actionType,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      actionTaken: actionTaken ?? this.actionTaken,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      relatedReportId: relatedReportId ?? this.relatedReportId,
      relatedMessageId: relatedMessageId ?? this.relatedMessageId,
      metadata: metadata ?? this.metadata,
    );
  }

  // Check if action is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Get remaining time for temporary actions
  Duration? get remainingTime {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  @override
  String toString() {
    return 'ModerationActionModel(id: $id, actionType: ${actionType.value}, targetUser: $targetUserName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModerationActionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Moderation action types enum
enum ModerationActionType {
  warning,
  temporaryRestriction,
  permanentBan,
  messageRemoval,
  conversationMute,
}

extension ModerationActionTypeExtension on ModerationActionType {
  String get value {
    switch (this) {
      case ModerationActionType.warning:
        return 'warning';
      case ModerationActionType.temporaryRestriction:
        return 'temporary_restriction';
      case ModerationActionType.permanentBan:
        return 'permanent_ban';
      case ModerationActionType.messageRemoval:
        return 'message_removal';
      case ModerationActionType.conversationMute:
        return 'conversation_mute';
    }
  }

  String get displayName {
    switch (this) {
      case ModerationActionType.warning:
        return 'Warning';
      case ModerationActionType.temporaryRestriction:
        return 'Temporary Restriction';
      case ModerationActionType.permanentBan:
        return 'Permanent Ban';
      case ModerationActionType.messageRemoval:
        return 'Message Removal';
      case ModerationActionType.conversationMute:
        return 'Conversation Mute';
    }
  }

  String get description {
    switch (this) {
      case ModerationActionType.warning:
        return 'User receives a warning notification';
      case ModerationActionType.temporaryRestriction:
        return 'User messaging capabilities are temporarily limited';
      case ModerationActionType.permanentBan:
        return 'User is permanently banned from messaging';
      case ModerationActionType.messageRemoval:
        return 'Specific message is removed from conversation';
      case ModerationActionType.conversationMute:
        return 'User is muted in specific conversation';
    }
  }

  static ModerationActionType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'temporary_restriction':
        return ModerationActionType.temporaryRestriction;
      case 'permanent_ban':
        return ModerationActionType.permanentBan;
      case 'message_removal':
        return ModerationActionType.messageRemoval;
      case 'conversation_mute':
        return ModerationActionType.conversationMute;
      default:
        return ModerationActionType.warning;
    }
  }
}
