// Message Status Model for TALOWA Messaging System
// Tracks message delivery and read status with timestamps

import 'package:cloud_firestore/cloud_firestore.dart';

/// Message status tracking model
class MessageStatusModel {
  final String messageId;
  final String senderId;
  final String? recipientId;
  final String? conversationId;
  final MessageStatus status;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final List<ReadReceipt> readReceipts;
  final int retryCount;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  MessageStatusModel({
    required this.messageId,
    required this.senderId,
    this.recipientId,
    this.conversationId,
    required this.status,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.readReceipts = const [],
    this.retryCount = 0,
    this.errorMessage,
    this.metadata = const {},
  });

  /// Create from Firestore document
  factory MessageStatusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MessageStatusModel(
      messageId: doc.id,
      senderId: data['senderId'] ?? '',
      recipientId: data['recipientId'],
      conversationId: data['conversationId'],
      status: MessageStatusExtension.fromString(data['status'] ?? 'sent'),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      readReceipts: (data['readReceipts'] as List<dynamic>?)
          ?.map((receipt) => ReadReceipt.fromMap(receipt as Map<String, dynamic>))
          .toList() ?? [],
      retryCount: data['retryCount'] ?? 0,
      errorMessage: data['errorMessage'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'recipientId': recipientId,
      'conversationId': conversationId,
      'status': status.value,
      'sentAt': Timestamp.fromDate(sentAt),
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'readReceipts': readReceipts.map((receipt) => receipt.toMap()).toList(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }

  /// Convert to Map for caching
  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'recipientId': recipientId,
      'conversationId': conversationId,
      'status': status.value,
      'sentAt': sentAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'readReceipts': readReceipts.map((receipt) => receipt.toMap()).toList(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }

  /// Create from Map for caching
  factory MessageStatusModel.fromMap(Map<String, dynamic> map) {
    return MessageStatusModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'],
      conversationId: map['conversationId'],
      status: MessageStatusExtension.fromString(map['status'] ?? 'sent'),
      sentAt: DateTime.parse(map['sentAt'] ?? DateTime.now().toIso8601String()),
      deliveredAt: map['deliveredAt'] != null ? DateTime.parse(map['deliveredAt']) : null,
      readAt: map['readAt'] != null ? DateTime.parse(map['readAt']) : null,
      readReceipts: (map['readReceipts'] as List<dynamic>?)
          ?.map((receipt) => ReadReceipt.fromMap(receipt as Map<String, dynamic>))
          .toList() ?? [],
      retryCount: map['retryCount'] ?? 0,
      errorMessage: map['errorMessage'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  /// Copy with method for updates
  MessageStatusModel copyWith({
    String? messageId,
    String? senderId,
    String? recipientId,
    String? conversationId,
    MessageStatus? status,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    List<ReadReceipt>? readReceipts,
    int? retryCount,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return MessageStatusModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      conversationId: conversationId ?? this.conversationId,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      readReceipts: readReceipts ?? this.readReceipts,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if message is delivered
  bool get isDelivered => status == MessageStatus.delivered || status == MessageStatus.read;

  /// Check if message is read
  bool get isRead => status == MessageStatus.read;

  /// Check if message failed
  bool get isFailed => status == MessageStatus.failed;

  /// Check if message is pending
  bool get isPending => status == MessageStatus.sending || status == MessageStatus.sent;

  /// Get delivery time (time from sent to delivered)
  Duration? get deliveryTime {
    if (deliveredAt == null) return null;
    return deliveredAt!.difference(sentAt);
  }

  /// Get read time (time from sent to read)
  Duration? get readTime {
    if (readAt == null) return null;
    return readAt!.difference(sentAt);
  }

  /// Check if message was read by specific user
  bool isReadByUser(String userId) {
    return readReceipts.any((receipt) => receipt.userId == userId);
  }

  /// Get read receipt for specific user
  ReadReceipt? getReadReceiptForUser(String userId) {
    try {
      return readReceipts.firstWhere((receipt) => receipt.userId == userId);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'MessageStatusModel(messageId: $messageId, status: ${status.value}, deliveredAt: $deliveredAt, readAt: $readAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageStatusModel && other.messageId == messageId;
  }

  @override
  int get hashCode => messageId.hashCode;
}

/// Read receipt model for group messages
class ReadReceipt {
  final String userId;
  final String userName;
  final DateTime readAt;
  final Map<String, dynamic> metadata;

  ReadReceipt({
    required this.userId,
    required this.userName,
    required this.readAt,
    this.metadata = const {},
  });

  /// Create from Map
  factory ReadReceipt.fromMap(Map<String, dynamic> map) {
    return ReadReceipt(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Unknown User',
      readAt: map['readAt'] is Timestamp 
          ? (map['readAt'] as Timestamp).toDate()
          : DateTime.parse(map['readAt'] ?? DateTime.now().toIso8601String()),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'readAt': readAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'ReadReceipt(userId: $userId, userName: $userName, readAt: $readAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadReceipt && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}

/// Message status enum
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// Extension for MessageStatus enum
extension MessageStatusExtension on MessageStatus {
  String get value {
    switch (this) {
      case MessageStatus.sending:
        return 'sending';
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.read:
        return 'read';
      case MessageStatus.failed:
        return 'failed';
    }
  }

  String get displayName {
    switch (this) {
      case MessageStatus.sending:
        return 'Sending';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.read:
        return 'Read';
      case MessageStatus.failed:
        return 'Failed';
    }
  }

  /// Get status from string
  static MessageStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  /// Get icon for status
  String get icon {
    switch (this) {
      case MessageStatus.sending:
        return '⏳';
      case MessageStatus.sent:
        return '✓';
      case MessageStatus.delivered:
        return '✓✓';
      case MessageStatus.read:
        return '✓✓';
      case MessageStatus.failed:
        return '❌';
    }
  }

  /// Get color for status (as hex string)
  String get colorHex {
    switch (this) {
      case MessageStatus.sending:
        return '#FFA500'; // Orange
      case MessageStatus.sent:
        return '#808080'; // Gray
      case MessageStatus.delivered:
        return '#808080'; // Gray
      case MessageStatus.read:
        return '#4CAF50'; // Green
      case MessageStatus.failed:
        return '#F44336'; // Red
    }
  }
}