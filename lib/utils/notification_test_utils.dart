// Notification Test Utils - Utilities for testing notification system
// Part of Task 12: Build push notification system

import 'package:flutter/foundation.dart';
import '../services/notifications/notification_service.dart';
import '../services/notifications/notification_templates.dart';
import '../models/notification_model.dart';

class NotificationTestUtils {
  /// Send test notification for different scenarios
  static Future<void> sendTestNotification(NotificationTemplateType templateType) async {
    try {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Sending test notification: $templateType');
      }

      Map<String, dynamic> testData;
      
      switch (templateType) {
        case NotificationTemplateType.emergencyAlert:
          testData = {
            'id': 'test_emergency_${DateTime.now().millisecondsSinceEpoch}',
            'alertMessage': 'This is a test emergency alert. Land grabbing reported in Test Village.',
          };
          break;

        case NotificationTemplateType.postLike:
          testData = {
            'id': 'test_like_${DateTime.now().millisecondsSinceEpoch}',
            'likerName': 'Test User',
          };
          break;

        case NotificationTemplateType.courtDateReminder:
          testData = {
            'id': 'test_court_${DateTime.now().millisecondsSinceEpoch}',
            'caseName': 'Test Land Case #123',
            'date': '25/12/2024',
            'time': '10:30',
          };
          break;

        case NotificationTemplateType.campaignUpdate:
          testData = {
            'id': 'test_campaign_${DateTime.now().millisecondsSinceEpoch}',
            'campaignName': 'Test Campaign',
            'updateMessage': 'New updates available for the land rights campaign.',
          };
          break;

        case NotificationTemplateType.newMessage:
          testData = {
            'id': 'test_message_${DateTime.now().millisecondsSinceEpoch}',
            'senderName': 'Test Coordinator',
            'messagePreview': 'Hello! This is a test message from the coordinator.',
          };
          break;

        case NotificationTemplateType.postComment:
          testData = {
            'id': 'test_comment_${DateTime.now().millisecondsSinceEpoch}',
            'commenterName': 'Test User',
            'commentPreview': 'Great post! Thanks for sharing.',
          };
          break;

        case NotificationTemplateType.successStory:
          testData = {
            'id': 'test_success_${DateTime.now().millisecondsSinceEpoch}',
            'title': 'Farmer Receives Patta',
            'summary': 'After 5 years of struggle, farmer in Test Village finally receives land patta.',
          };
          break;

        default:
          testData = {
            'id': 'test_general_${DateTime.now().millisecondsSinceEpoch}',
            'message': 'This is a test notification.',
          };
          break;
      }

      // Create notification from template
      final notification = NotificationTemplates.createFromTemplate(
        templateType: templateType,
        data: testData,
      );

      // Show the notification locally
      await NotificationService.showLocalNotification(notification);

      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Test notification sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Error sending test notification: $e');
      }
      rethrow;
    }
  }

  /// Send multiple test notifications to test batching
  static Future<void> sendBatchTestNotifications() async {
    try {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Sending batch test notifications');
      }

      // Send multiple like notifications to test batching
      for (int i = 0; i < 5; i++) {
        await sendTestNotification(NotificationTemplateType.postLike);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Send multiple comment notifications
      for (int i = 0; i < 3; i++) {
        await sendTestNotification(NotificationTemplateType.postComment);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Batch test notifications sent');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Error sending batch test notifications: $e');
      }
      rethrow;
    }
  }

  /// Test emergency notification (should bypass batching and quiet hours)
  static Future<void> sendEmergencyTest() async {
    try {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Sending emergency test notification');
      }

      await sendTestNotification(NotificationTemplateType.emergencyAlert);

      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Emergency test notification sent');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Error sending emergency test: $e');
      }
      rethrow;
    }
  }

  /// Test quiet hours functionality
  static Future<void> testQuietHours() async {
    try {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Testing quiet hours functionality');
      }

      // Send low priority notification (should be batched during quiet hours)
      await sendTestNotification(NotificationTemplateType.postLike);

      // Send high priority notification (should bypass quiet hours if emergency override is enabled)
      await sendTestNotification(NotificationTemplateType.courtDateReminder);

      // Send emergency notification (should always bypass quiet hours)
      await sendTestNotification(NotificationTemplateType.emergencyAlert);

      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Quiet hours test completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Error testing quiet hours: $e');
      }
      rethrow;
    }
  }

  /// Get notification system statistics
  static Map<String, dynamic> getSystemStatistics() {
    try {
      final batchingStats = NotificationService.getBatchingStatistics();
      final preferences = NotificationService.getNotificationPreferences();
      
      return {
        'batching': batchingStats,
        'preferences': {
          'pushEnabled': preferences?.enablePushNotifications ?? false,
          'inAppEnabled': preferences?.enableInAppNotifications ?? false,
          'quietHoursEnabled': preferences?.enableQuietHours ?? false,
          'emergencyOverride': preferences?.enableEmergencyOverride ?? false,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Error getting system statistics: $e');
      }
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Validate notification system setup
  static Future<Map<String, bool>> validateSystemSetup() async {
    final results = <String, bool>{};

    try {
      // Check if FCM token is available
      final fcmToken = NotificationService.fcmToken;
      results['fcmTokenAvailable'] = fcmToken != null && fcmToken.isNotEmpty;

      // Check if preferences are loaded
      final preferences = NotificationService.getNotificationPreferences();
      results['preferencesLoaded'] = preferences != null;

      // Check if batching service is working
      final batchingStats = NotificationService.getBatchingStatistics();
      results['batchingServiceActive'] = batchingStats.isNotEmpty;

      // Test template creation
      try {
        final testNotification = NotificationTemplates.createFromTemplate(
          templateType: NotificationTemplateType.generalAnnouncement,
          data: {'id': 'validation_test', 'announcementText': 'Test'},
        );
        results['templateSystemWorking'] = testNotification.title.isNotEmpty;
      } catch (e) {
        results['templateSystemWorking'] = false;
      }

      if (kDebugMode) {
        debugPrint('NotificationTestUtils: System validation completed');
        debugPrint('Results: $results');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationTestUtils: Error validating system setup: $e');
      }
      results['validationError'] = true;
    }

    return results;
  }

  /// Create sample notifications for different scenarios
  static List<NotificationModel> createSampleNotifications() {
    return [
      // Emergency notification
      NotificationTemplates.createFromTemplate(
        templateType: NotificationTemplateType.emergencyAlert,
        data: {
          'id': 'sample_emergency',
          'alertMessage': 'Land grabbing reported in Warangal district. Immediate action required.',
        },
      ),

      // Court reminder
      NotificationTemplates.createFromTemplate(
        templateType: NotificationTemplateType.courtDateReminder,
        data: {
          'id': 'sample_court',
          'caseName': 'Land Rights Case #456',
          'date': '28/12/2024',
          'time': '11:00',
        },
      ),

      // Success story
      NotificationTemplates.createFromTemplate(
        templateType: NotificationTemplateType.pattaReceived,
        data: {
          'id': 'sample_success',
          'farmerName': 'Ravi Kumar',
          'landArea': '2.5 acres',
          'village': 'Kondapur',
        },
      ),

      // Campaign update
      NotificationTemplates.createFromTemplate(
        templateType: NotificationTemplateType.campaignUpdate,
        data: {
          'id': 'sample_campaign',
          'campaignName': 'Land Rights Awareness',
          'updateMessage': 'New meeting scheduled for next week in Hyderabad.',
        },
      ),

      // Social engagement
      NotificationTemplates.createFromTemplate(
        templateType: NotificationTemplateType.postLike,
        data: {
          'id': 'sample_like',
          'likerName': 'Priya Sharma',
        },
      ),
    ];
  }
}
