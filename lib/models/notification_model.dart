// Notification Model - Represents app notifications
// Part of Task 14: Build notification system

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final String? imageUrl;
  final String? actionUrl;
  
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    required this.createdAt,
    this.isRead = false,
    this.readAt,
    this.imageUrl,
    this.actionUrl,
  });
  
  /// Create NotificationModel from Firebase Remote Message
  factory NotificationModel.fromRemoteMessage(RemoteMessage message) {
    return NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? 'TALOWA',
      body: message.notification?.body ?? '',
      type: _parseNotificationType(message.data['type']),
      data: message.data,
      createdAt: DateTime.now(),
      isRead: false,
      imageUrl: message.notification?.android?.imageUrl ?? 
                message.notification?.apple?.imageUrl,
      actionUrl: message.data['actionUrl'],
    );
  }
  
  /// Create NotificationModel from Firestore document
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: _parseNotificationType(data['type']),
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      imageUrl: data['imageUrl'],
      actionUrl: data['actionUrl'],
    );
  }

  /// Create NotificationModel from Map
  factory NotificationModel.fromMap(Map<String, dynamic> data) {
    return NotificationModel(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: _parseNotificationType(data['type']),
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      readAt: data['readAt'] != null && data['readAt'] is Timestamp
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      imageUrl: data['imageUrl'],
      actionUrl: data['actionUrl'],
    );
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
    };
  }
  
  /// Create a copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    String? imageUrl,
    String? actionUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }
  
  /// Get formatted time ago string
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
  
  /// Get notification icon based on type
  String getIconPath() {
    switch (type) {
      case NotificationType.postLike:
        return 'assets/icons/heart.png';
      case NotificationType.postComment:
        return 'assets/icons/comment.png';
      case NotificationType.postShare:
        return 'assets/icons/share.png';
      case NotificationType.emergency:
        return 'assets/icons/emergency.png';
      case NotificationType.announcement:
        return 'assets/icons/announcement.png';
      case NotificationType.legalUpdate:
        return 'assets/icons/legal.png';
      case NotificationType.successStory:
        return 'assets/icons/success.png';
      case NotificationType.networkUpdate:
        return 'assets/icons/network.png';
      case NotificationType.systemUpdate:
        return 'assets/icons/system.png';
      default:
        return 'assets/icons/notification.png';
    }
  }
  
  /// Get notification color based on type
  String getColorHex() {
    switch (type) {
      case NotificationType.postLike:
        return '#FF4444';
      case NotificationType.postComment:
        return '#4444FF';
      case NotificationType.postShare:
        return '#44FF44';
      case NotificationType.emergency:
        return '#FF0000';
      case NotificationType.announcement:
        return '#FF8800';
      case NotificationType.legalUpdate:
        return '#8800FF';
      case NotificationType.successStory:
        return '#00FF88';
      case NotificationType.networkUpdate:
        return '#0088FF';
      case NotificationType.systemUpdate:
        return '#888888';
      default:
        return '#4CAF50';
    }
  }
  
  /// Check if notification is high priority
  bool get isHighPriority {
    return type == NotificationType.emergency ||
           type == NotificationType.announcement;
  }
  
  /// Parse notification type from string
  static NotificationType _parseNotificationType(String? typeString) {
    if (typeString == null) return NotificationType.general;
    
    try {
      return NotificationType.values.firstWhere(
        (type) => type.toString().split('.').last == typeString,
        orElse: () => NotificationType.general,
      );
    } catch (e) {
      return NotificationType.general;
    }
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'NotificationModel{id: $id, title: $title, type: $type, isRead: $isRead}';
  }
}

/// Notification type enumeration
enum NotificationType {
  general,
  postLike,
  postComment,
  postShare,
  emergency,
  announcement,
  legalUpdate,
  successStory,
  networkUpdate,
  systemUpdate,
  newFollower,
  mentionInPost,
  mentionInComment,
  campaignUpdate,
  landRightsAlert,
  courtDateReminder,
  documentExpiry,
  meetingReminder,
  campaign,
  social,
  engagement,
  referral,
}

/// Extension for NotificationType localization
extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.general:
        return 'General';
      case NotificationType.postLike:
        return 'Post Liked';
      case NotificationType.postComment:
        return 'New Comment';
      case NotificationType.postShare:
        return 'Post Shared';
      case NotificationType.emergency:
        return 'Emergency Alert';
      case NotificationType.announcement:
        return 'Announcement';
      case NotificationType.legalUpdate:
        return 'Legal Update';
      case NotificationType.successStory:
        return 'Success Story';
      case NotificationType.networkUpdate:
        return 'Network Update';
      case NotificationType.systemUpdate:
        return 'System Update';
      case NotificationType.newFollower:
        return 'New Follower';
      case NotificationType.mentionInPost:
        return 'Mentioned in Post';
      case NotificationType.mentionInComment:
        return 'Mentioned in Comment';
      case NotificationType.campaignUpdate:
        return 'Campaign Update';
      case NotificationType.landRightsAlert:
        return 'Land Rights Alert';
      case NotificationType.courtDateReminder:
        return 'Court Date Reminder';
      case NotificationType.documentExpiry:
        return 'Document Expiry';
      case NotificationType.meetingReminder:
        return 'Meeting Reminder';
      case NotificationType.campaign:
        return 'Campaign';
      case NotificationType.social:
        return 'Social';
      case NotificationType.engagement:
        return 'Engagement';
      case NotificationType.referral:
        return 'Referral';
    }
  }
  
  String get description {
    switch (this) {
      case NotificationType.general:
        return 'General app notifications';
      case NotificationType.postLike:
        return 'Someone liked your post';
      case NotificationType.postComment:
        return 'Someone commented on your post';
      case NotificationType.postShare:
        return 'Someone shared your post';
      case NotificationType.emergency:
        return 'Critical emergency alert';
      case NotificationType.announcement:
        return 'Important announcement';
      case NotificationType.legalUpdate:
        return 'Legal case or law update';
      case NotificationType.successStory:
        return 'Community success story';
      case NotificationType.networkUpdate:
        return 'Network or team update';
      case NotificationType.systemUpdate:
        return 'App or system update';
      case NotificationType.newFollower:
        return 'Someone started following you';
      case NotificationType.mentionInPost:
        return 'You were mentioned in a post';
      case NotificationType.mentionInComment:
        return 'You were mentioned in a comment';
      case NotificationType.campaignUpdate:
        return 'Campaign or movement update';
      case NotificationType.landRightsAlert:
        return 'Land rights related alert';
      case NotificationType.courtDateReminder:
        return 'Upcoming court date reminder';
      case NotificationType.documentExpiry:
        return 'Document expiring soon';
      case NotificationType.meetingReminder:
        return 'Upcoming meeting reminder';
      case NotificationType.campaign:
        return 'Campaign related notification';
      case NotificationType.social:
        return 'Social interaction notification';
      case NotificationType.engagement:
        return 'User engagement notification';
      case NotificationType.referral:
        return 'Referral program notification';
    }
  }
}

/// Notification preferences model
class NotificationPreferences {
  final bool enablePushNotifications;
  final bool enableInAppNotifications;
  final bool enableEmailNotifications;
  final bool enableSMSNotifications;
  final Map<NotificationType, bool> typePreferences;
  final bool enableQuietHours;
  final int quietHoursStart; // Hour in 24-hour format
  final int quietHoursEnd; // Hour in 24-hour format
  final bool enableLocationBasedNotifications;
  final bool enableEmergencyOverride;
  
  const NotificationPreferences({
    this.enablePushNotifications = true,
    this.enableInAppNotifications = true,
    this.enableEmailNotifications = false,
    this.enableSMSNotifications = false,
    this.typePreferences = const {},
    this.enableQuietHours = false,
    this.quietHoursStart = 22, // 10 PM
    this.quietHoursEnd = 7, // 7 AM
    this.enableLocationBasedNotifications = true,
    this.enableEmergencyOverride = true,
  });
  
  /// Create from Firestore document
  factory NotificationPreferences.fromMap(Map<String, dynamic> data) {
    final typePrefs = <NotificationType, bool>{};
    final typePrefsData = data['typePreferences'] as Map<String, dynamic>?;
    
    if (typePrefsData != null) {
      for (final entry in typePrefsData.entries) {
        final type = NotificationType.values.firstWhere(
          (t) => t.toString().split('.').last == entry.key,
          orElse: () => NotificationType.general,
        );
        typePrefs[type] = entry.value as bool;
      }
    }
    
    return NotificationPreferences(
      enablePushNotifications: data['enablePushNotifications'] ?? true,
      enableInAppNotifications: data['enableInAppNotifications'] ?? true,
      enableEmailNotifications: data['enableEmailNotifications'] ?? false,
      enableSMSNotifications: data['enableSMSNotifications'] ?? false,
      typePreferences: typePrefs,
      enableQuietHours: data['enableQuietHours'] ?? false,
      quietHoursStart: data['quietHoursStart'] ?? 22,
      quietHoursEnd: data['quietHoursEnd'] ?? 7,
      enableLocationBasedNotifications: data['enableLocationBasedNotifications'] ?? true,
      enableEmergencyOverride: data['enableEmergencyOverride'] ?? true,
    );
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    final typePrefsMap = <String, bool>{};
    for (final entry in typePreferences.entries) {
      typePrefsMap[entry.key.toString().split('.').last] = entry.value;
    }
    
    return {
      'enablePushNotifications': enablePushNotifications,
      'enableInAppNotifications': enableInAppNotifications,
      'enableEmailNotifications': enableEmailNotifications,
      'enableSMSNotifications': enableSMSNotifications,
      'typePreferences': typePrefsMap,
      'enableQuietHours': enableQuietHours,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'enableLocationBasedNotifications': enableLocationBasedNotifications,
      'enableEmergencyOverride': enableEmergencyOverride,
    };
  }
  
  /// Check if notification type is enabled
  bool isTypeEnabled(NotificationType type) {
    return typePreferences[type] ?? true;
  }
  
  /// Check if currently in quiet hours
  bool get isInQuietHours {
    if (!enableQuietHours) return false;
    
    final now = DateTime.now();
    final currentHour = now.hour;
    
    if (quietHoursStart < quietHoursEnd) {
      // Same day quiet hours (e.g., 22:00 to 07:00 next day)
      return currentHour >= quietHoursStart || currentHour < quietHoursEnd;
    } else {
      // Cross-day quiet hours (e.g., 10:00 to 18:00)
      return currentHour >= quietHoursStart && currentHour < quietHoursEnd;
    }
  }
}
