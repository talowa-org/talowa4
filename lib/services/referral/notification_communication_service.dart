import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Exception thrown when notification and communication operations fail
class NotificationCommunicationException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const NotificationCommunicationException(this.message, [this.code = 'NOTIFICATION_COMMUNICATION_FAILED', this.context]);
  
  @override
  String toString() => 'NotificationCommunicationException: $message';
}

/// Notification types
enum NotificationType {
  referralUsed,
  paymentCompleted,
  teamGrowth,
  rolePromotion,
  achievement,
  milestone,
  teamSizeMilestone,
  welcome,
  reminder,
  system,
}

/// Notification priority levels
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

/// Notification delivery channels
enum NotificationChannel {
  inApp,
  push,
  email,
  sms,
}

/// Notification data model
class NotificationData {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final NotificationPriority priority;
  final List<NotificationChannel> channels;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final bool isRead;
  final bool isDelivered;
  final Map<NotificationChannel, bool> deliveryStatus;
  final int retryCount;
  final DateTime? lastRetryAt;

  const NotificationData({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.priority,
    required this.channels,
    required this.createdAt,
    this.scheduledAt,
    required this.isRead,
    required this.isDelivered,
    required this.deliveryStatus,
    required this.retryCount,
    this.lastRetryAt,
  });

  factory NotificationData.fromMap(Map<String, dynamic> map) {
    return NotificationData(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => NotificationType.system,
      ),
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      data: (map['data'] as Map<String, dynamic>?) ?? {},
      priority: NotificationPriority.values.firstWhere(
        (e) => e.toString() == map['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      channels: (map['channels'] as List<dynamic>?)
          ?.map((e) => NotificationChannel.values.firstWhere(
                (channel) => channel.toString() == e,
                orElse: () => NotificationChannel.inApp,
              ))
          .toList() ?? [NotificationChannel.inApp],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      scheduledAt: map['scheduledAt'] != null 
          ? (map['scheduledAt'] as Timestamp).toDate() 
          : null,
      isRead: map['isRead'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      deliveryStatus: () {
        final statusMap = map['deliveryStatus'] as Map<String, dynamic>?;
        if (statusMap == null) return <NotificationChannel, bool>{};

        final result = <NotificationChannel, bool>{};
        for (final entry in statusMap.entries) {
          final channel = NotificationChannel.values.firstWhere(
            (e) => e.toString() == entry.key,
            orElse: () => NotificationChannel.inApp,
          );
          result[channel] = entry.value as bool;
        }
        return result;
      }(),
      retryCount: map['retryCount'] ?? 0,
      lastRetryAt: map['lastRetryAt'] != null 
          ? (map['lastRetryAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString(),
      'title': title,
      'message': message,
      'data': data,
      'priority': priority.toString(),
      'channels': channels.map((e) => e.toString()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'deliveryStatus': deliveryStatus.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'retryCount': retryCount,
      'lastRetryAt': lastRetryAt != null ? Timestamp.fromDate(lastRetryAt!) : null,
    };
  }

  NotificationData copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    NotificationPriority? priority,
    List<NotificationChannel>? channels,
    DateTime? createdAt,
    DateTime? scheduledAt,
    bool? isRead,
    bool? isDelivered,
    Map<NotificationChannel, bool>? deliveryStatus,
    int? retryCount,
    DateTime? lastRetryAt,
  }) {
    return NotificationData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      channels: channels ?? this.channels,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      retryCount: retryCount ?? this.retryCount,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
    );
  }
}

/// Service for notification and communication functionality
class NotificationCommunicationService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(minutes: 5);
  static const Duration notificationExpiry = Duration(days: 30);
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Send notification for referral code usage
  static Future<void> sendReferralUsedNotification({
    required String referrerId,
    required String newUserId,
    required String newUserName,
    required String referralCode,
  }) async {
    try {
      final notification = NotificationData(
        id: _generateNotificationId(),
        userId: referrerId,
        type: NotificationType.referralUsed,
        title: 'Your referral code was used! 🎉',
        message: '$newUserName just joined using your referral code $referralCode',
        data: {
          'newUserId': newUserId,
          'newUserName': newUserName,
          'referralCode': referralCode,
          'action': 'view_team',
        },
        priority: NotificationPriority.high,
        channels: [NotificationChannel.inApp, NotificationChannel.push],
        createdAt: DateTime.now(),
        isRead: false,
        isDelivered: false,
        deliveryStatus: {},
        retryCount: 0,
      );
      
      await _saveNotification(notification);
      await _deliverNotification(notification);
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to send referral used notification: $e',
        'REFERRAL_USED_NOTIFICATION_FAILED',
        {'referrerId': referrerId, 'newUserId': newUserId}
      );
    }
  }
  
  /// Send notification for payment completion
  static Future<void> sendPaymentCompletedNotification({
    required String userId,
    required String referrerId,
    required String userName,
    required double amount,
    required String currency,
  }) async {
    try {
      // Notification for the user who paid
      final userNotification = NotificationData(
        id: _generateNotificationId(),
        userId: userId,
        type: NotificationType.paymentCompleted,
        title: 'Payment confirmed! ✅',
        message: 'Your membership payment of $amount $currency has been processed successfully',
        data: {
          'amount': amount,
          'currency': currency,
          'action': 'view_membership',
        },
        priority: NotificationPriority.high,
        channels: [NotificationChannel.inApp, NotificationChannel.push, NotificationChannel.email],
        createdAt: DateTime.now(),
        isRead: false,
        isDelivered: false,
        deliveryStatus: {},
        retryCount: 0,
      );
      
      // Small delay to ensure unique IDs
      await Future.delayed(Duration(milliseconds: 1));

      // Notification for the referrer
      final referrerNotification = NotificationData(
        id: _generateNotificationId(),
        userId: referrerId,
        type: NotificationType.teamGrowth,
        title: 'Team member activated! 🚀',
        message: '$userName completed their membership payment and is now active in your team',
        data: {
          'activatedUserId': userId,
          'activatedUserName': userName,
          'amount': amount,
          'currency': currency,
          'action': 'view_team',
        },
        priority: NotificationPriority.high,
        channels: [NotificationChannel.inApp, NotificationChannel.push],
        createdAt: DateTime.now(),
        isRead: false,
        isDelivered: false,
        deliveryStatus: {},
        retryCount: 0,
      );
      
      await Future.wait([
        _saveNotification(userNotification),
        _saveNotification(referrerNotification),
      ]);
      
      await Future.wait([
        _deliverNotification(userNotification),
        _deliverNotification(referrerNotification),
      ]);
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to send payment completed notification: $e',
        'PAYMENT_COMPLETED_NOTIFICATION_FAILED',
        {'userId': userId, 'referrerId': referrerId}
      );
    }
  }
  
  /// Send role promotion notification
  static Future<void> sendRolePromotionNotification({
    required String userId,
    required String oldRole,
    required String newRole,
    required Map<String, dynamic> newBenefits,
    required Map<String, dynamic> newResponsibilities,
  }) async {
    try {
      final notification = NotificationData(
        id: _generateNotificationId(),
        userId: userId,
        type: NotificationType.rolePromotion,
        title: 'Congratulations on your promotion! 🎊',
        message: 'You\'ve been promoted from ${_formatRoleName(oldRole)} to ${_formatRoleName(newRole)}',
        data: {
          'oldRole': oldRole,
          'newRole': newRole,
          'newBenefits': newBenefits,
          'newResponsibilities': newResponsibilities,
          'action': 'view_role_details',
        },
        priority: NotificationPriority.urgent,
        channels: [NotificationChannel.inApp, NotificationChannel.push, NotificationChannel.email],
        createdAt: DateTime.now(),
        isRead: false,
        isDelivered: false,
        deliveryStatus: {},
        retryCount: 0,
      );
      
      await _saveNotification(notification);
      await _deliverNotification(notification);
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to send role promotion notification: $e',
        'ROLE_PROMOTION_NOTIFICATION_FAILED',
        {'userId': userId, 'oldRole': oldRole, 'newRole': newRole}
      );
    }
  }
  
  /// Send achievement notification
  static Future<void> sendAchievementNotification({
    required String userId,
    required String achievementId,
    required String achievementName,
    required String achievementDescription,
    required String badgeUrl,
    required Map<String, dynamic> rewards,
  }) async {
    try {
      final notification = NotificationData(
        id: _generateNotificationId(),
        userId: userId,
        type: NotificationType.achievement,
        title: 'Achievement unlocked! 🏆',
        message: 'You\'ve earned the "$achievementName" achievement',
        data: {
          'achievementId': achievementId,
          'achievementName': achievementName,
          'achievementDescription': achievementDescription,
          'badgeUrl': badgeUrl,
          'rewards': rewards,
          'action': 'view_achievements',
        },
        priority: NotificationPriority.high,
        channels: [NotificationChannel.inApp, NotificationChannel.push],
        createdAt: DateTime.now(),
        isRead: false,
        isDelivered: false,
        deliveryStatus: {},
        retryCount: 0,
      );
      
      await _saveNotification(notification);
      await _deliverNotification(notification);
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to send achievement notification: $e',
        'ACHIEVEMENT_NOTIFICATION_FAILED',
        {'userId': userId, 'achievementId': achievementId}
      );
    }
  }
  
  /// Send milestone notification
  static Future<void> sendMilestoneNotification({
    required String userId,
    required String milestoneType,
    required int milestoneValue,
    required String milestoneDescription,
    required Map<String, dynamic> rewards,
  }) async {
    try {
      final notification = NotificationData(
        id: _generateNotificationId(),
        userId: userId,
        type: NotificationType.milestone,
        title: 'Milestone reached! 🎯',
        message: milestoneDescription,
        data: {
          'milestoneType': milestoneType,
          'milestoneValue': milestoneValue,
          'milestoneDescription': milestoneDescription,
          'rewards': rewards,
          'action': 'view_milestones',
        },
        priority: NotificationPriority.high,
        channels: [NotificationChannel.inApp, NotificationChannel.push],
        createdAt: DateTime.now(),
        isRead: false,
        isDelivered: false,
        deliveryStatus: {},
        retryCount: 0,
      );
      
      await _saveNotification(notification);
      await _deliverNotification(notification);
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to send milestone notification: $e',
        'MILESTONE_NOTIFICATION_FAILED',
        {'userId': userId, 'milestoneType': milestoneType}
      );
    }
  }
  
  /// Send team size milestone notification
  static Future<void> sendTeamSizeMilestoneNotification({
    required String userId,
    required int teamSize,
    required int milestoneSize,
    required Map<String, dynamic> rewards,
  }) async {
    try {
      final notification = NotificationData(
        id: _generateNotificationId(),
        userId: userId,
        type: NotificationType.teamSizeMilestone,
        title: 'Team milestone achieved! 👥',
        message: 'Your team has reached $milestoneSize members! Current team size: $teamSize',
        data: {
          'teamSize': teamSize,
          'milestoneSize': milestoneSize,
          'rewards': rewards,
          'action': 'view_team',
        },
        priority: NotificationPriority.high,
        channels: [NotificationChannel.inApp, NotificationChannel.push],
        createdAt: DateTime.now(),
        isRead: false,
        isDelivered: false,
        deliveryStatus: {},
        retryCount: 0,
      );
      
      await _saveNotification(notification);
      await _deliverNotification(notification);
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to send team size milestone notification: $e',
        'TEAM_SIZE_MILESTONE_NOTIFICATION_FAILED',
        {'userId': userId, 'teamSize': teamSize}
      );
    }
  }
  
  /// Get user notifications
  static Future<List<NotificationData>> getUserNotifications({
    required String userId,
    int limit = 50,
    bool unreadOnly = false,
    NotificationType? type,
  }) async {
    try {
      Query query = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);
      
      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }
      
      if (type != null) {
        query = query.where('type', isEqualTo: type.toString());
      }
      
      query = query.limit(limit);
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => NotificationData.fromMap({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to get user notifications: $e',
        'GET_USER_NOTIFICATIONS_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to mark notification as read: $e',
        'MARK_NOTIFICATION_READ_FAILED',
        {'notificationId': notificationId}
      );
    }
  }
  
  /// Mark all notifications as read for a user
  static Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to mark all notifications as read: $e',
        'MARK_ALL_NOTIFICATIONS_READ_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get unread notification count
  static Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      throw NotificationCommunicationException(
        'Failed to get unread notification count: $e',
        'GET_UNREAD_COUNT_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Retry failed notification deliveries
  static Future<void> retryFailedNotifications() async {
    try {
      final cutoffTime = DateTime.now().subtract(retryDelay);

      final failedNotifications = await _firestore
          .collection('notifications')
          .where('isDelivered', isEqualTo: false)
          .where('retryCount', isLessThan: maxRetryAttempts)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(notificationExpiry)
          ))
          .get();
      
      for (final doc in failedNotifications.docs) {
        final notification = NotificationData.fromMap({
          'id': doc.id,
          ...doc.data(),
        });
        
        // Check if enough time has passed since last retry
        if (notification.lastRetryAt == null || 
            notification.lastRetryAt!.isBefore(cutoffTime)) {
          
          final updatedNotification = notification.copyWith(
            retryCount: notification.retryCount + 1,
            lastRetryAt: DateTime.now(),
          );
          
          await _updateNotification(updatedNotification);
          await _deliverNotification(updatedNotification);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Failed to retry notifications: $e');
      }
    }
  }
  
  /// Clean up old notifications
  static Future<void> cleanupOldNotifications() async {
    try {
      final cutoffDate = DateTime.now().subtract(notificationExpiry);
      
      final oldNotifications = await _firestore
          .collection('notifications')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Failed to cleanup old notifications: $e');
      }
    }
  }
  
  /// Private helper methods
  
  static String _generateNotificationId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
  
  static String _formatRoleName(String role) {
    return role.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
  
  static Future<void> _saveNotification(NotificationData notification) async {
    await _firestore
        .collection('notifications')
        .doc(notification.id)
        .set(notification.toMap());
  }
  
  static Future<void> _updateNotification(NotificationData notification) async {
    await _firestore
        .collection('notifications')
        .doc(notification.id)
        .update(notification.toMap());
  }
  
  static Future<void> _deliverNotification(NotificationData notification) async {
    final deliveryStatus = <NotificationChannel, bool>{};
    
    for (final channel in notification.channels) {
      try {
        switch (channel) {
          case NotificationChannel.inApp:
            deliveryStatus[channel] = true; // Always successful for in-app
            break;
          case NotificationChannel.push:
            deliveryStatus[channel] = await _deliverPushNotification(notification);
            break;
          case NotificationChannel.email:
            deliveryStatus[channel] = await _deliverEmailNotification(notification);
            break;
          case NotificationChannel.sms:
            deliveryStatus[channel] = await _deliverSmsNotification(notification);
            break;
        }
      } catch (e) {
        deliveryStatus[channel] = false;
        if (kDebugMode) {
          print('Failed to deliver notification via $channel: $e');
        }
      }
    }
    
    final isDelivered = deliveryStatus.values.any((delivered) => delivered);
    
    await _firestore
        .collection('notifications')
        .doc(notification.id)
        .update({
          'isDelivered': isDelivered,
          'deliveryStatus': deliveryStatus.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
          'deliveredAt': isDelivered ? FieldValue.serverTimestamp() : null,
        });
  }
  
  static Future<bool> _deliverPushNotification(NotificationData notification) async {
    // In a real implementation, this would integrate with FCM or similar
    // For now, we'll simulate delivery
    await Future.delayed(Duration(milliseconds: 100));
    return true;
  }
  
  static Future<bool> _deliverEmailNotification(NotificationData notification) async {
    // In a real implementation, this would integrate with an email service
    // For now, we'll simulate delivery
    await Future.delayed(Duration(milliseconds: 200));
    return true;
  }
  
  static Future<bool> _deliverSmsNotification(NotificationData notification) async {
    // In a real implementation, this would integrate with an SMS service
    // For now, we'll simulate delivery
    await Future.delayed(Duration(milliseconds: 150));
    return true;
  }
}
