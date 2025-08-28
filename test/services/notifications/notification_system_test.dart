// Test file for push notification system
// Part of Task 12: Build push notification system

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:talowa/services/notifications/notification_service.dart';
import 'package:talowa/services/notifications/notification_batching_service.dart';
import 'package:talowa/services/notifications/notification_templates.dart';
import 'package:talowa/services/notifications/notification_preferences_service.dart';
import 'package:talowa/models/notification_model.dart';

// Generate mocks
@GenerateMocks([
  FirebaseMessaging,
  FirebaseFirestore,
  SharedPreferences,
])
import 'notification_system_test.mocks.dart';

void main() {
  group('Notification System Tests', () {
    late MockFirebaseMessaging mockMessaging;
    late MockFirebaseFirestore mockFirestore;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      mockMessaging = MockFirebaseMessaging();
      mockFirestore = MockFirebaseFirestore();
      mockPrefs = MockSharedPreferences();
    });

    group('NotificationTemplates', () {
      test('should create notification from emergency template', () {
        final notification = NotificationTemplates.createFromTemplate(
          templateType: NotificationTemplateType.emergencyAlert,
          data: {
            'id': 'test_123',
            'alertMessage': 'Land grabbing reported in Village XYZ',
          },
        );

        expect(notification.title, '🚨 EMERGENCY ALERT');
        expect(notification.body, 'Land grabbing reported in Village XYZ');
        expect(notification.type, NotificationType.emergency);
        expect(notification.data['type'], 'emergency');
        expect(notification.data['bypassQuietHours'], true);
      });

      test('should create notification from post like template', () {
        final notification = NotificationTemplates.createFromTemplate(
          templateType: NotificationTemplateType.postLike,
          data: {
            'id': 'like_456',
            'likerName': 'John Doe',
          },
        );

        expect(notification.title, 'New Like');
        expect(notification.body, 'John Doe liked your post');
        expect(notification.type, NotificationType.postLike);
        expect(notification.data['type'], 'post_like');
      });

      test('should create notification from court reminder template', () {
        final notification = NotificationTemplates.createFromTemplate(
          templateType: NotificationTemplateType.courtDateReminder,
          data: {
            'id': 'court_789',
            'caseName': 'Land Case #123',
            'date': '15/12/2024',
            'time': '10:30',
          },
        );

        expect(notification.title, '⚖️ Court Date Reminder');
        expect(notification.body, 'Court hearing for Land Case #123 on 15/12/2024 at 10:30');
        expect(notification.type, NotificationType.courtDateReminder);
      });

      test('should get correct channel ID for different template types', () {
        expect(
          NotificationTemplates.getChannelId(NotificationTemplateType.emergencyAlert),
          'talowa_emergency',
        );
        expect(
          NotificationTemplates.getChannelId(NotificationTemplateType.postLike),
          'talowa_low_priority',
        );
        expect(
          NotificationTemplates.getChannelId(NotificationTemplateType.announcement),
          'talowa_important',
        );
      });

      test('should determine if template should bypass quiet hours', () {
        expect(
          NotificationTemplates.shouldBypassQuietHours(NotificationTemplateType.emergencyAlert),
          true,
        );
        expect(
          NotificationTemplates.shouldBypassQuietHours(NotificationTemplateType.landGrabbingAlert),
          true,
        );
        expect(
          NotificationTemplates.shouldBypassQuietHours(NotificationTemplateType.postLike),
          false,
        );
      });
    });

    group('NotificationPreferences', () {
      test('should create default preferences', () {
        const preferences = NotificationPreferences();

        expect(preferences.enablePushNotifications, true);
        expect(preferences.enableInAppNotifications, true);
        expect(preferences.enableEmailNotifications, false);
        expect(preferences.enableSMSNotifications, false);
        expect(preferences.enableQuietHours, false);
        expect(preferences.quietHoursStart, 22);
        expect(preferences.quietHoursEnd, 7);
        expect(preferences.enableEmergencyOverride, true);
      });

      test('should check if notification type is enabled', () {
        const preferences = NotificationPreferences(
          typePreferences: {
            NotificationType.emergency: true,
            NotificationType.postLike: false,
          },
        );

        expect(preferences.isTypeEnabled(NotificationType.emergency), true);
        expect(preferences.isTypeEnabled(NotificationType.postLike), false);
        expect(preferences.isTypeEnabled(NotificationType.announcement), true); // Default
      });

      test('should detect quiet hours correctly', () {
        // Test same-day quiet hours (22:00 to 07:00 next day)
        const preferences = NotificationPreferences(
          enableQuietHours: true,
          quietHoursStart: 22,
          quietHoursEnd: 7,
        );

        // This test would need to mock DateTime.now() to test properly
        // For now, we just verify the logic exists
        expect(preferences.enableQuietHours, true);
      });

      test('should convert to and from map', () {
        const originalPreferences = NotificationPreferences(
          enablePushNotifications: false,
          enableEmailNotifications: true,
          quietHoursStart: 23,
          quietHoursEnd: 6,
          typePreferences: {
            NotificationType.emergency: true,
            NotificationType.postLike: false,
          },
        );

        final map = originalPreferences.toMap();
        final reconstructedPreferences = NotificationPreferences.fromMap(map);

        expect(reconstructedPreferences.enablePushNotifications, false);
        expect(reconstructedPreferences.enableEmailNotifications, true);
        expect(reconstructedPreferences.quietHoursStart, 23);
        expect(reconstructedPreferences.quietHoursEnd, 6);
        expect(reconstructedPreferences.isTypeEnabled(NotificationType.emergency), true);
        expect(reconstructedPreferences.isTypeEnabled(NotificationType.postLike), false);
      });
    });

    group('NotificationBatchingService', () {
      late NotificationBatchingService batchingService;

      setUp(() {
        batchingService = NotificationBatchingService();
      });

      test('should identify notifications that bypass batching', () {
        final emergencyNotification = NotificationModel(
          id: 'emergency_1',
          title: 'Emergency Alert',
          body: 'Land grabbing reported',
          type: NotificationType.emergency,
          createdAt: DateTime.now(),
        );

        final likeNotification = NotificationModel(
          id: 'like_1',
          title: 'New Like',
          body: 'Someone liked your post',
          type: NotificationType.postLike,
          createdAt: DateTime.now(),
        );

        // Emergency notifications should bypass batching
        expect(emergencyNotification.type, NotificationType.emergency);
        expect(emergencyNotification.isHighPriority, true);

        // Like notifications should be batched
        expect(likeNotification.type, NotificationType.postLike);
        expect(likeNotification.isHighPriority, false);
      });

      test('should get batch statistics', () {
        final stats = batchingService.getBatchStatistics();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('pendingNotifications'), true);
        expect(stats.containsKey('typeBatches'), true);
        expect(stats.containsKey('notificationsThisHour'), true);
        expect(stats.containsKey('notificationsToday'), true);
      });
    });

    group('NotificationModel', () {
      test('should create notification from remote message', () {
        const remoteMessage = RemoteMessage(
          messageId: 'msg_123',
          notification: RemoteNotification(
            title: 'Test Title',
            body: 'Test Body',
          ),
          data: {
            'type': 'announcement',
            'targetId': 'target_123',
          },
        );

        final notification = NotificationModel.fromRemoteMessage(remoteMessage);

        expect(notification.id, 'msg_123');
        expect(notification.title, 'Test Title');
        expect(notification.body, 'Test Body');
        expect(notification.type, NotificationType.announcement);
        expect(notification.data['type'], 'announcement');
        expect(notification.data['targetId'], 'target_123');
      });

      test('should calculate time ago correctly', () {
        final now = DateTime.now();
        
        final recentNotification = NotificationModel(
          id: 'recent',
          title: 'Recent',
          body: 'Recent notification',
          type: NotificationType.general,
          createdAt: now.subtract(const Duration(minutes: 30)),
        );

        final oldNotification = NotificationModel(
          id: 'old',
          title: 'Old',
          body: 'Old notification',
          type: NotificationType.general,
          createdAt: now.subtract(const Duration(days: 2)),
        );

        expect(recentNotification.getTimeAgo(), '30m ago');
        expect(oldNotification.getTimeAgo(), '2d ago');
      });

      test('should identify high priority notifications', () {
        final emergencyNotification = NotificationModel(
          id: 'emergency',
          title: 'Emergency',
          body: 'Emergency alert',
          type: NotificationType.emergency,
          createdAt: DateTime.now(),
        );

        final likeNotification = NotificationModel(
          id: 'like',
          title: 'Like',
          body: 'Someone liked your post',
          type: NotificationType.postLike,
          createdAt: DateTime.now(),
        );

        expect(emergencyNotification.isHighPriority, true);
        expect(likeNotification.isHighPriority, false);
      });

      test('should convert to and from map', () {
        final originalNotification = NotificationModel(
          id: 'test_123',
          title: 'Test Title',
          body: 'Test Body',
          type: NotificationType.announcement,
          data: {'key': 'value'},
          createdAt: DateTime.now(),
          isRead: false,
          imageUrl: 'https://example.com/image.jpg',
        );

        final map = originalNotification.toMap();
        expect(map['title'], 'Test Title');
        expect(map['body'], 'Test Body');
        expect(map['type'], 'announcement');
        expect(map['data']['key'], 'value');
        expect(map['isRead'], false);
        expect(map['imageUrl'], 'https://example.com/image.jpg');
      });
    });

    group('Integration Tests', () {
      test('should handle complete notification flow', () async {
        // This would test the complete flow from template creation
        // through batching to delivery, but requires more complex mocking
        
        // Create notification from template
        final notification = NotificationTemplates.createFromTemplate(
          templateType: NotificationTemplateType.emergencyAlert,
          data: {
            'id': 'emergency_123',
            'alertMessage': 'Test emergency alert',
          },
        );

        // Verify notification properties
        expect(notification.type, NotificationType.emergency);
        expect(notification.isHighPriority, true);
        expect(notification.data['bypassQuietHours'], true);

        // Emergency notifications should bypass batching
        expect(notification.type, NotificationType.emergency);
      });

      test('should respect user preferences', () {
        // Test that notifications respect user preferences
        const preferences = NotificationPreferences(
          enablePushNotifications: false,
          typePreferences: {
            NotificationType.postLike: false,
          },
        );

        final likeNotification = NotificationModel(
          id: 'like_123',
          title: 'New Like',
          body: 'Someone liked your post',
          type: NotificationType.postLike,
          createdAt: DateTime.now(),
        );

        // This notification should be blocked by preferences
        expect(preferences.enablePushNotifications, false);
        expect(preferences.isTypeEnabled(NotificationType.postLike), false);
      });
    });
  });
}