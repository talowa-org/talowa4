// Message Model for TALOWA Messaging System
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType messageType;
  final List<String> mediaUrls;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final List<String> readBy;
  final bool isEdited;
  final bool isDeleted;
  final Map<String, dynamic> metadata;
  // Integration fields
  final String? linkedCaseId;
  final String? linkedLandRecordId;
  final String? linkedCampaignId;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.messageType,
    required this.mediaUrls,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    required this.readBy,
    required this.isEdited,
    required this.isDeleted,
    required this.metadata,
    // Integration fields
    this.linkedCaseId,
    this.linkedLandRecordId,
    this.linkedCampaignId,
  });

  // Convert from Firestore document
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MessageModel(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown User',
      content: data['content'] ?? '',
      messageType: MessageTypeExtension.fromString(data['messageType'] ?? 'text'),
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
      isEdited: data['isEdited'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      // Integration fields
      linkedCaseId: data['linkedCaseId'],
      linkedLandRecordId: data['linkedLandRecordId'],
      linkedCampaignId: data['linkedCampaignId'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'messageType': messageType.value,
      'mediaUrls': mediaUrls,
      'sentAt': Timestamp.fromDate(sentAt),
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'readBy': readBy,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'metadata': metadata,
      // Integration fields
      'linkedCaseId': linkedCaseId,
      'linkedLandRecordId': linkedLandRecordId,
      'linkedCampaignId': linkedCampaignId,
    };
  }

  // Convert to Map for caching
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'messageType': messageType.value,
      'mediaUrls': mediaUrls,
      'sentAt': sentAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'readBy': readBy,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'metadata': metadata,
      'linkedCaseId': linkedCaseId,
      'linkedLandRecordId': linkedLandRecordId,
      'linkedCampaignId': linkedCampaignId,
    };
  }

  // Convert from Map for caching
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown User',
      content: map['content'] ?? '',
      messageType: MessageTypeExtension.fromString(map['messageType'] ?? 'text'),
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      sentAt: DateTime.parse(map['sentAt'] ?? DateTime.now().toIso8601String()),
      deliveredAt: map['deliveredAt'] != null ? DateTime.parse(map['deliveredAt']) : null,
      readAt: map['readAt'] != null ? DateTime.parse(map['readAt']) : null,
      readBy: List<String>.from(map['readBy'] ?? []),
      isEdited: map['isEdited'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      linkedCaseId: map['linkedCaseId'],
      linkedLandRecordId: map['linkedLandRecordId'],
      linkedCampaignId: map['linkedCampaignId'],
    );
  }

  // Copy with method for updates
  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    MessageType? messageType,
    List<String>? mediaUrls,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    List<String>? readBy,
    bool? isEdited,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      readBy: readBy ?? this.readBy,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, senderId: $senderId, content: ${content.substring(0, content.length > 50 ? 50 : content.length)}...)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Message types enum
enum MessageType {
  text,
  image,
  video,
  audio,
  document,
  location,
  system,
  emergency,
}

extension MessageTypeExtension on MessageType {
  String get value {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.audio:
        return 'audio';
      case MessageType.document:
        return 'document';
      case MessageType.location:
        return 'location';
      case MessageType.system:
        return 'system';
      case MessageType.emergency:
        return 'emergency';
    }
  }

  String get displayName {
    switch (this) {
      case MessageType.text:
        return 'Text';
      case MessageType.image:
        return 'Image';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Audio';
      case MessageType.document:
        return 'Document';
      case MessageType.location:
        return 'Location';
      case MessageType.system:
        return 'System';
      case MessageType.emergency:
        return 'Emergency';
    }
  }

  static MessageType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'document':
        return MessageType.document;
      case 'location':
        return MessageType.location;
      case 'system':
        return MessageType.system;
      case 'emergency':
        return MessageType.emergency;
      default:
        return MessageType.text;
    }
  }
}
