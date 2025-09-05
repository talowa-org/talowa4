import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/services/referral/notification_communication_service.dart';

void main() {
  group('NotificationCommunicationService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      NotificationCommunicationService.setFirestoreInstance(fakeFirestore);
    });

    group('Referral Used Notifications', () {
      test('should send referral used notification', () async {
        await NotificationCommunicationService.sendReferralUsedNotification(
          referrerId: 'referrer1',
          newUserId: 'user1',
          newUserName: 'John Doe',
          referralCode: 'REF123',
        );

        final notifications = await fakeFirestore.collection('notifications').get();
        expect(notifications.docs.length, equals(1));

        final notificationData = notifications.docs.first.data();
        expect(notificationData['userId'], equals('referrer1'));
        expect(notificationData['type'], equals(NotificationType.referralUsed.toString()));
        expect(notificationData['title'], contains('Your referral code was used'));
        expect(notificationData['message'], contains('John Doe'));
        expect(notificationData['message'], contains('REF123'));
      });
    });

    group('Payment Completed Notifications', () {
      test('should send payment completed notifications to both user and referrer', () async {
        await NotificationCommunicationService.sendPaymentCompletedNotification(
          userId: 'user1',
          referrerId: 'referrer1',
          userName: 'John Doe',
          amount: 99.99,
          currency: 'USD',
        );

        final notifications = await fakeFirestore.collection('notifications').get();
        expect(notifications.docs.length, equals(2));

        final userNotification = notifications.docs.firstWhere(
          (doc) => doc.data()['userId'] == 'user1',
        );
        final referrerNotification = notifications.docs.firstWhere(
          (doc) => doc.data()['userId'] == 'referrer1',
        );

        expect(userNotification.data()['type'], equals(NotificationType.paymentCompleted.toString()));
        expect(userNotification.data()['title'], contains('Payment confirmed'));

        expect(referrerNotification.data()['type'], equals(NotificationType.teamGrowth.toString()));
        expect(referrerNotification.data()['title'], contains('Team member activated'));
      });
    });

    group('Role Promotion Notifications', () {
      test('should send role promotion notification', () async {
        await NotificationCommunicationService.sendRolePromotionNotification(
          userId: 'user1',
          oldRole: 'member',
          newRole: 'organizer',
          newBenefits: {'commission': '15%'},
          newResponsibilities: {'team_management': true},
        );

        final notifications = await fakeFirestore.collection('notifications').get();
        expect(notifications.docs.length, equals(1));

        final notificationData = notifications.docs.first.data();
        expect(notificationData['userId'], equals('user1'));
        expect(notificationData['type'], equals(NotificationType.rolePromotion.toString()));
        expect(notificationData['title'], contains('promotion'));
        expect(notificationData['message'], contains('Member'));
        expect(notificationData['message'], contains('Organizer'));
      });
    });

    group('Achievement Notifications', () {
      test('should send achievement notification', () async {
        await NotificationCommunicationService.sendAchievementNotification(
          userId: 'user1',
          achievementId: 'first_referral',
          achievementName: 'First Referral',
          achievementDescription: 'Made your first referral',
          badgeUrl: 'https://example.com/badge.png',
          rewards: {'points': 100},
        );

        final notifications = await fakeFirestore.collection('notifications').get();
        expect(notifications.docs.length, equals(1));

        final notificationData = notifications.docs.first.data();
        expect(notificationData['userId'], equals('user1'));
        expect(notificationData['type'], equals(NotificationType.achievement.toString()));
        expect(notificationData['title'], contains('Achievement unlocked'));
        expect(notificationData['message'], contains('First Referral'));
      });
    });

    group('Milestone Notifications', () {
      test('should send milestone notification', () async {
        await NotificationCommunicationService.sendMilestoneNotification(
          userId: 'user1',
          milestoneType: 'referrals',
          milestoneValue: 10,
          milestoneDescription: 'Reached 10 referrals',
          rewards: {'bonus': 50},
        );

        final notifications = await fakeFirestore.collection('notifications').get();
        expect(notifications.docs.length, equals(1));

        final notificationData = notifications.docs.first.data();
        expect(notificationData['userId'], equals('user1'));
        expect(notificationData['type'], equals(NotificationType.milestone.toString()));
        expect(notificationData['title'], contains('Milestone reached'));
      });
    });

    group('Team Size Milestone Notifications', () {
      test('should send team size milestone notification', () async {
        await NotificationCommunicationService.sendTeamSizeMilestoneNotification(
          userId: 'user1',
          teamSize: 25,
          milestoneSize: 25,
          rewards: {'bonus': 100},
        );

        final notifications = await fakeFirestore.collection('notifications').get();
        expect(notifications.docs.length, equals(1));

        final notificationData = notifications.docs.first.data();
        expect(notificationData['userId'], equals('user1'));
        expect(notificationData['type'], equals(NotificationType.teamSizeMilestone.toString()));
        expect(notificationData['title'], contains('Team milestone'));
        expect(notificationData['message'], contains('25 members'));
      });
    });

    group('Notification Management', () {
      test('should get user notifications', () async {
        // Create test notifications
        await NotificationCommunicationService.sendReferralUsedNotification(
          referrerId: 'user1',
          newUserId: 'user2',
          newUserName: 'John Doe',
          referralCode: 'REF123',
        );

        await NotificationCommunicationService.sendAchievementNotification(
          userId: 'user1',
          achievementId: 'test_achievement',
          achievementName: 'Test Achievement',
          achievementDescription: 'Test description',
          badgeUrl: 'https://example.com/badge.png',
          rewards: {},
        );

        final notifications = await NotificationCommunicationService.getUserNotifications(
          userId: 'user1',
        );

        expect(notifications.length, equals(2));
        expect(notifications.every((n) => n.userId == 'user1'), isTrue);
      });

      test('should get only unread notifications', () async {
        // Create test notification
        await NotificationCommunicationService.sendReferralUsedNotification(
          referrerId: 'user1',
          newUserId: 'user2',
          newUserName: 'John Doe',
          referralCode: 'REF123',
        );

        final allNotifications = await NotificationCommunicationService.getUserNotifications(
          userId: 'user1',
        );
        expect(allNotifications.length, equals(1));

        final unreadNotifications = await NotificationCommunicationService.getUserNotifications(
          userId: 'user1',
          unreadOnly: true,
        );
        expect(unreadNotifications.length, equals(1));
      });

      test('should mark notification as read', () async {
        await NotificationCommunicationService.sendReferralUsedNotification(
          referrerId: 'user1',
          newUserId: 'user2',
          newUserName: 'John Doe',
          referralCode: 'REF123',
        );

        final notifications = await NotificationCommunicationService.getUserNotifications(
          userId: 'user1',
        );
        final notificationId = notifications.first.id;

        await NotificationCommunicationService.markNotificationAsRead(notificationId);

        final notificationDoc = await fakeFirestore
            .collection('notifications')
            .doc(notificationId)
            .get();
        
        expect(notificationDoc.data()!['isRead'], isTrue);
      });

      test('should mark all notifications as read', () async {
        // Create multiple notifications
        await NotificationCommunicationService.sendReferralUsedNotification(
          referrerId: 'user1',
          newUserId: 'user2',
          newUserName: 'John Doe',
          referralCode: 'REF123',
        );

        await NotificationCommunicationService.sendAchievementNotification(
          userId: 'user1',
          achievementId: 'test_achievement',
          achievementName: 'Test Achievement',
          achievementDescription: 'Test description',
          badgeUrl: 'https://example.com/badge.png',
          rewards: {},
        );

        await NotificationCommunicationService.markAllNotificationsAsRead('user1');

        final notifications = await fakeFirestore
            .collection('notifications')
            .where('userId', isEqualTo: 'user1')
            .get();

        for (final doc in notifications.docs) {
          expect(doc.data()['isRead'], isTrue);
        }
      });

      test('should get unread notification count', () async {
        // Create test notifications
        await NotificationCommunicationService.sendReferralUsedNotification(
          referrerId: 'user1',
          newUserId: 'user2',
          newUserName: 'John Doe',
          referralCode: 'REF123',
        );

        await NotificationCommunicationService.sendAchievementNotification(
          userId: 'user1',
          achievementId: 'test_achievement',
          achievementName: 'Test Achievement',
          achievementDescription: 'Test description',
          badgeUrl: 'https://example.com/badge.png',
          rewards: {},
        );

        final unreadCount = await NotificationCommunicationService.getUnreadNotificationCount('user1');
        expect(unreadCount, equals(2));
      });
    });

    group('NotificationData Model', () {
      test('should create NotificationData from map', () async {
        final map = {
          'id': 'test_id',
          'userId': 'user1',
          'type': NotificationType.referralUsed.toString(),
          'title': 'Test Title',
          'message': 'Test Message',
          'data': <String, dynamic>{'key': 'value'},
          'priority': NotificationPriority.high.toString(),
          'channels': [NotificationChannel.inApp.toString()],
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'isRead': false,
          'isDelivered': true,
          'deliveryStatus': <String, dynamic>{},
          'retryCount': 0,
        };

        final notification = NotificationData.fromMap(map);

        expect(notification.id, equals('test_id'));
        expect(notification.userId, equals('user1'));
        expect(notification.type, equals(NotificationType.referralUsed));
        expect(notification.title, equals('Test Title'));
        expect(notification.priority, equals(NotificationPriority.high));
      });

      test('should convert NotificationData to map', () async {
        final notification = NotificationData(
          id: 'test_id',
          userId: 'user1',
          type: NotificationType.referralUsed,
          title: 'Test Title',
          message: 'Test Message',
          data: {'key': 'value'},
          priority: NotificationPriority.high,
          channels: [NotificationChannel.inApp],
          createdAt: DateTime.now(),
          isRead: false,
          isDelivered: true,
          deliveryStatus: {},
          retryCount: 0,
        );

        final map = notification.toMap();

        expect(map['id'], equals('test_id'));
        expect(map['userId'], equals('user1'));
        expect(map['type'], equals(NotificationType.referralUsed.toString()));
        expect(map['title'], equals('Test Title'));
      });
    });

    group('Error Handling', () {
      test('should create NotificationCommunicationException correctly', () {
        const message = 'Test notification error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};

        final exception = NotificationCommunicationException(message, code, context);

        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test notification error';
        const exception = NotificationCommunicationException(message);

        expect(exception.code, equals('NOTIFICATION_COMMUNICATION_FAILED'));
        expect(exception.context, isNull);
      });
    });
  });
}

