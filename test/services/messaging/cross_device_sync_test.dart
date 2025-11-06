// Cross-Device Sync Test for TALOWA
// Tests Task 9: Cross-device compatibility and data synchronization

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/messaging/device_session_manager.dart';
import '../../../lib/services/messaging/cross_device_sync_service.dart';
import '../../../lib/services/messaging/cross_device_integration_service.dart';

void main() {
  group('Cross-Device Sync Tests', () {
    group('Data Models', () {
      test('should handle conversation state sync data', () {
        // Test conversation state sync data model
        final readStatus = ReadStatusSync(
          messageIds: ['msg1', 'msg2'],
          readAt: DateTime.now(),
          lastReadMessageId: 'msg2',
        );

        final unreadCount = UnreadCountSync(
          count: 5,
          messageIds: ['msg3', 'msg4', 'msg5'],
          lastUpdated: DateTime.now(),
        );

        final scrollPosition = ScrollPositionSync(
          position: 0.5,
          lastVisibleMessageId: 'msg4',
          visibleMessageCount: 10,
          timestamp: DateTime.now(),
        );

        final stateData = ConversationStateSyncData(
          readStatus: readStatus,
          unreadCount: unreadCount,
          scrollPosition: scrollPosition,
        );

        expect(stateData.readStatus, equals(readStatus));
        expect(stateData.unreadCount, equals(unreadCount));
        expect(stateData.scrollPosition, equals(scrollPosition));

        // Test serialization
        final map = stateData.toMap();
        expect(map['readStatus'], isNotNull);
        expect(map['unreadCount'], isNotNull);
        expect(map['scrollPosition'], isNotNull);

        // Test deserialization
        final deserializedData = ConversationStateSyncData.fromMap(map);
        expect(deserializedData.readStatus?.messageIds, equals(['msg1', 'msg2']));
        expect(deserializedData.unreadCount?.count, equals(5));
        expect(deserializedData.scrollPosition?.position, equals(0.5));
      });

      test('should handle conflict resolution strategies', () {
        // Test conflict resolution result
        final result = ConflictResolutionResult(
          isResolved: true,
          strategy: 'automatic',
          resolvedData: {'test': 'data'},
        );

        expect(result.isResolved, isTrue);
        expect(result.strategy, equals('automatic'));
        expect(result.resolvedData?['test'], equals('data'));
      });

      test('should handle integration events', () {
        // Test integration event creation
        final event = CrossDeviceIntegrationEvent(
          type: IntegrationEventType.initialized,
          timestamp: DateTime.now(),
          data: {'success': true},
        );

        expect(event.type, equals(IntegrationEventType.initialized));
        expect(event.data?['success'], isTrue);
      });
    });

    group('Device Session Model', () {
      test('should create device session with correct properties', () {
        final session = DeviceSession(
          id: 'session_123',
          userId: 'user_456',
          deviceId: 'device_789',
          deviceName: 'iPhone 12',
          deviceType: DeviceType.mobile,
          platform: 'ios',
          appVersion: '1.0.0',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          lastActiveAt: DateTime.now().subtract(const Duration(minutes: 2)),
          isActive: true,
          metadata: {'brand': 'Apple', 'model': 'iPhone12,1'},
        );

        expect(session.id, equals('session_123'));
        expect(session.deviceType, equals(DeviceType.mobile));
        expect(session.displayName, equals('iPhone 12 (ios)'));
        expect(session.isCurrentDevice, isFalse); // More than 5 minutes ago
        expect(session.isRecentlyActive, isTrue); // Less than 24 hours ago
      });

      test('should handle device session serialization', () {
        final session = DeviceSession(
          id: 'session_123',
          userId: 'user_456',
          deviceId: 'device_789',
          deviceName: 'Test Device',
          deviceType: DeviceType.web,
          platform: 'web',
          appVersion: '1.0.0',
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
          isActive: true,
          metadata: {'browser': 'Chrome'},
        );

        final firestoreData = session.toFirestore();
        expect(firestoreData['deviceName'], equals('Test Device'));
        expect(firestoreData['deviceType'], equals('web'));
        expect(firestoreData['platform'], equals('web'));
        expect(firestoreData['isActive'], isTrue);
        expect(firestoreData['metadata']['browser'], equals('Chrome'));
      });
    });

    group('Sync Event Types', () {
      test('should handle all sync event types', () {
        final eventTypes = SyncEventType.values;
        expect(eventTypes.contains(SyncEventType.stateUpdated), isTrue);
        expect(eventTypes.contains(SyncEventType.conflictDetected), isTrue);
        expect(eventTypes.contains(SyncEventType.conflictResolved), isTrue);
        expect(eventTypes.contains(SyncEventType.syncCompleted), isTrue);
        expect(eventTypes.contains(SyncEventType.syncFailed), isTrue);
      });

      test('should handle all conflict types', () {
        final conflictTypes = ConflictType.values;
        expect(conflictTypes.contains(ConflictType.readStatus), isTrue);
        expect(conflictTypes.contains(ConflictType.unreadCount), isTrue);
        expect(conflictTypes.contains(ConflictType.scrollPosition), isTrue);
        expect(conflictTypes.contains(ConflictType.stateUpdate), isTrue);
        expect(conflictTypes.contains(ConflictType.messageDelivery), isTrue);
      });

      test('should handle all resolution strategies', () {
        final strategies = ConflictResolutionStrategy.values;
        expect(strategies.contains(ConflictResolutionStrategy.automatic), isTrue);
        expect(strategies.contains(ConflictResolutionStrategy.localWins), isTrue);
        expect(strategies.contains(ConflictResolutionStrategy.remoteWins), isTrue);
        expect(strategies.contains(ConflictResolutionStrategy.merge), isTrue);
        expect(strategies.contains(ConflictResolutionStrategy.manual), isTrue);
      });
    });

    group('Statistics and Status', () {
      test('should calculate sync statistics correctly', () {
        final stats = CrossDeviceSyncStatistics(
          totalConversations: 20,
          syncedConversations: 18,
          unresolvedConflicts: 2,
          totalConflicts: 5,
          lastSyncTime: DateTime.now(),
          activeSessions: 3,
        );

        expect(stats.syncRatio, equals(0.9)); // 18/20
        expect(stats.conflictRatio, equals(0.4)); // 2/5
        expect(stats.hasUnresolvedConflicts, isTrue);
        expect(stats.isHealthy, isFalse); // Conflict ratio > 0.1
      });
    });
  });
}