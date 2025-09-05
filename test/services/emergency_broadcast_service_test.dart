// Emergency Broadcast Service Tests
// Task 9: Build emergency broadcast system - Testing
// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/messaging/emergency_broadcast_service.dart';

void main() {
  group('EmergencyBroadcastService Data Models', () {

    group('EmergencyBroadcastScope', () {
      test('should create scope with correct geographic level', () {
        // Arrange & Act
        final scope = EmergencyBroadcastScope(
          level: GeographicLevel.village,
          state: 'Telangana',
          district: 'Hyderabad',
          mandal: 'Test Mandal',
          village: 'Test Village',
          targetRoles: ['village_coordinator'],
        );

        // Assert
        expect(scope.level, equals(GeographicLevel.village));
        expect(scope.state, equals('Telangana'));
        expect(scope.district, equals('Hyderabad'));
        expect(scope.mandal, equals('Test Mandal'));
        expect(scope.village, equals('Test Village'));
        expect(scope.targetRoles, contains('village_coordinator'));
      });

      test('should serialize and deserialize correctly', () {
        // Arrange
        final originalScope = EmergencyBroadcastScope(
          level: GeographicLevel.mandal,
          state: 'Telangana',
          district: 'Warangal',
          mandal: 'Test Mandal',
          targetRoles: ['mandal_coordinator', 'village_coordinator'],
        );

        // Act
        final map = originalScope.toMap();
        final deserializedScope = EmergencyBroadcastScope.fromMap(map);

        // Assert
        expect(deserializedScope.level, equals(originalScope.level));
        expect(deserializedScope.state, equals(originalScope.state));
        expect(deserializedScope.district, equals(originalScope.district));
        expect(deserializedScope.mandal, equals(originalScope.mandal));
        expect(deserializedScope.targetRoles, equals(originalScope.targetRoles));
      });
    });

    group('EmergencyBroadcast', () {
      test('should create broadcast with all required fields', () {
        // Arrange & Act
        final broadcast = EmergencyBroadcast(
          id: 'test-id',
          senderId: 'sender-id',
          title: 'Test Broadcast',
          message: 'Test message',
          scope: EmergencyBroadcastScope(level: GeographicLevel.district),
          priority: EmergencyPriority.critical,
          mediaUrls: ['url1', 'url2'],
          customData: {'key': 'value'},
          status: BroadcastStatus.pending,
          createdAt: DateTime.now(),
          scheduledAt: DateTime.now(),
        );

        // Assert
        expect(broadcast.id, equals('test-id'));
        expect(broadcast.senderId, equals('sender-id'));
        expect(broadcast.title, equals('Test Broadcast'));
        expect(broadcast.message, equals('Test message'));
        expect(broadcast.priority, equals(EmergencyPriority.critical));
        expect(broadcast.status, equals(BroadcastStatus.pending));
        expect(broadcast.mediaUrls, hasLength(2));
        expect(broadcast.customData['key'], equals('value'));
      });

      test('should serialize to map correctly', () {
        // Arrange
        final now = DateTime.now();
        final broadcast = EmergencyBroadcast(
          id: 'test-id',
          senderId: 'sender-id',
          title: 'Test Broadcast',
          message: 'Test message',
          scope: EmergencyBroadcastScope(level: GeographicLevel.district),
          priority: EmergencyPriority.high,
          mediaUrls: [],
          customData: {},
          status: BroadcastStatus.pending,
          createdAt: now,
          scheduledAt: now,
        );

        // Act
        final map = broadcast.toMap();

        // Assert
        expect(map['senderId'], equals('sender-id'));
        expect(map['title'], equals('Test Broadcast'));
        expect(map['message'], equals('Test message'));
        expect(map['priority'], equals('EmergencyPriority.high'));
        expect(map['status'], equals('BroadcastStatus.pending'));
        expect(map['mediaUrls'], isEmpty);
        expect(map['customData'], isEmpty);
      });
    });

    group('BroadcastDeliveryTracking', () {
      test('should calculate delivery rate correctly', () {
        // Arrange
        final tracking = BroadcastDeliveryTracking(
          broadcastId: 'test-id',
          totalTargets: 100,
          deliveredCount: 75,
          failedCount: 15,
          pendingCount: 10,
          deliveryStarted: DateTime.now(),
          channels: [DeliveryChannel.push, DeliveryChannel.sms],
        );

        // Act & Assert
        expect(tracking.deliveryRate, equals(0.75));
        expect(tracking.isCompleted, isFalse);
      });

      test('should identify completed delivery', () {
        // Arrange
        final tracking = BroadcastDeliveryTracking(
          broadcastId: 'test-id',
          totalTargets: 100,
          deliveredCount: 85,
          failedCount: 15,
          pendingCount: 0,
          deliveryStarted: DateTime.now(),
          channels: [DeliveryChannel.push],
        );

        // Act & Assert
        expect(tracking.isCompleted, isTrue);
      });

      test('should handle zero targets gracefully', () {
        // Arrange
        final tracking = BroadcastDeliveryTracking(
          broadcastId: 'test-id',
          totalTargets: 0,
          deliveredCount: 0,
          failedCount: 0,
          pendingCount: 0,
          deliveryStarted: DateTime.now(),
          channels: [],
        );

        // Act & Assert
        expect(tracking.deliveryRate, equals(0.0));
        expect(tracking.isCompleted, isTrue);
      });
    });

    group('EmergencyTemplate', () {
      test('should create template with all fields', () {
        // Arrange & Act
        final template = EmergencyTemplate(
          id: 'template-id',
          name: 'Test Template',
          title: 'Template Title',
          message: 'Template message',
          priority: EmergencyPriority.medium,
          applicableRoles: ['coordinator'],
          customFields: {'category': 'test'},
          createdBy: 'creator-id',
          createdAt: DateTime.now(),
          isActive: true,
        );

        // Assert
        expect(template.id, equals('template-id'));
        expect(template.name, equals('Test Template'));
        expect(template.title, equals('Template Title'));
        expect(template.message, equals('Template message'));
        expect(template.priority, equals(EmergencyPriority.medium));
        expect(template.applicableRoles, contains('coordinator'));
        expect(template.customFields['category'], equals('test'));
        expect(template.isActive, isTrue);
      });

      test('should serialize to map correctly', () {
        // Arrange
        final now = DateTime.now();
        final template = EmergencyTemplate(
          id: 'template-id',
          name: 'Test Template',
          title: 'Template Title',
          message: 'Template message',
          priority: EmergencyPriority.low,
          applicableRoles: ['role1', 'role2'],
          customFields: {'key': 'value'},
          createdBy: 'creator-id',
          createdAt: now,
          isActive: true,
        );

        // Act
        final map = template.toMap();

        // Assert
        expect(map['name'], equals('Test Template'));
        expect(map['title'], equals('Template Title'));
        expect(map['message'], equals('Template message'));
        expect(map['priority'], equals('EmergencyPriority.low'));
        expect(map['applicableRoles'], equals(['role1', 'role2']));
        expect(map['customFields'], equals({'key': 'value'}));
        expect(map['createdBy'], equals('creator-id'));
        expect(map['isActive'], isTrue);
      });
    });

    group('Priority and Geographic Level Enums', () {
      test('should have correct emergency priority values', () {
        expect(EmergencyPriority.values, hasLength(4));
        expect(EmergencyPriority.values, contains(EmergencyPriority.low));
        expect(EmergencyPriority.values, contains(EmergencyPriority.medium));
        expect(EmergencyPriority.values, contains(EmergencyPriority.high));
        expect(EmergencyPriority.values, contains(EmergencyPriority.critical));
      });

      test('should have correct geographic level values', () {
        expect(GeographicLevel.values, hasLength(5));
        expect(GeographicLevel.values, contains(GeographicLevel.village));
        expect(GeographicLevel.values, contains(GeographicLevel.mandal));
        expect(GeographicLevel.values, contains(GeographicLevel.district));
        expect(GeographicLevel.values, contains(GeographicLevel.state));
        expect(GeographicLevel.values, contains(GeographicLevel.national));
      });

      test('should have correct broadcast status values', () {
        expect(BroadcastStatus.values, hasLength(5));
        expect(BroadcastStatus.values, contains(BroadcastStatus.pending));
        expect(BroadcastStatus.values, contains(BroadcastStatus.processing));
        expect(BroadcastStatus.values, contains(BroadcastStatus.completed));
        expect(BroadcastStatus.values, contains(BroadcastStatus.failed));
        expect(BroadcastStatus.values, contains(BroadcastStatus.cancelled));
      });

      test('should have correct delivery channel values', () {
        expect(DeliveryChannel.values, hasLength(3));
        expect(DeliveryChannel.values, contains(DeliveryChannel.push));
        expect(DeliveryChannel.values, contains(DeliveryChannel.sms));
        expect(DeliveryChannel.values, contains(DeliveryChannel.email));
      });
    });
  });
}
