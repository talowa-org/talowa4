// Test for Presence Models
// Requirements: 1.3, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/models/messaging/presence_model.dart';

void main() {
  group('Presence Models Tests', () {

    group('UserPresence Model Tests', () {
      test('should create UserPresence with correct properties', () {
        final presence = UserPresence(
          userId: 'test_user_1',
          isOnline: true,
          lastSeen: DateTime.now(),
          customStatus: PresenceStatus.available,
          statusMessage: 'Working on TALOWA',
          updatedAt: DateTime.now(),
        );

        expect(presence.userId, equals('test_user_1'));
        expect(presence.isOnline, isTrue);
        expect(presence.customStatus, equals(PresenceStatus.available));
        expect(presence.statusMessage, equals('Working on TALOWA'));
        expect(presence.isActive, isTrue);
        expect(presence.isAvailable, isTrue);
      });

      test('should correctly identify offline users', () {
        final presence = UserPresence(
          userId: 'test_user_2',
          isOnline: false,
          lastSeen: DateTime.now().subtract(const Duration(hours: 1)),
          updatedAt: DateTime.now(),
        );

        expect(presence.isOnline, isFalse);
        expect(presence.isActive, isFalse);
        expect(presence.displayStatus, contains('Last seen'));
      });

      test('should handle different presence statuses correctly', () {
        final busyPresence = UserPresence(
          userId: 'test_user_3',
          isOnline: true,
          lastSeen: DateTime.now(),
          customStatus: PresenceStatus.busy,
          updatedAt: DateTime.now(),
        );

        expect(busyPresence.customStatus, equals(PresenceStatus.busy));
        expect(busyPresence.statusEmoji, equals('🔴'));
        expect(busyPresence.displayStatus, equals('Busy'));
        expect(busyPresence.isAvailable, isFalse);
      });

      test('should handle do not disturb status', () {
        final dndPresence = UserPresence(
          userId: 'test_user_4',
          isOnline: true,
          lastSeen: DateTime.now(),
          customStatus: PresenceStatus.doNotDisturb,
          updatedAt: DateTime.now(),
        );

        expect(dndPresence.isDoNotDisturb, isTrue);
        expect(dndPresence.isAvailable, isFalse);
        expect(dndPresence.statusEmoji, equals('⛔'));
      });

      test('should convert to and from Map correctly', () {
        final originalPresence = UserPresence(
          userId: 'test_user_5',
          isOnline: true,
          lastSeen: DateTime.now(),
          customStatus: PresenceStatus.away,
          statusMessage: 'In a meeting',
          updatedAt: DateTime.now(),
        );

        final map = originalPresence.toMap();
        final convertedPresence = UserPresence.fromMap(map);

        expect(convertedPresence.userId, equals(originalPresence.userId));
        expect(convertedPresence.isOnline, equals(originalPresence.isOnline));
        expect(convertedPresence.customStatus, equals(originalPresence.customStatus));
        expect(convertedPresence.statusMessage, equals(originalPresence.statusMessage));
      });
    });

    group('TypingIndicator Model Tests', () {
      test('should create TypingIndicator with correct properties', () {
        final typingIndicator = TypingIndicator(
          userId: 'test_user_1',
          conversationId: 'conversation_1',
          isTyping: true,
          timestamp: DateTime.now(),
        );

        expect(typingIndicator.userId, equals('test_user_1'));
        expect(typingIndicator.conversationId, equals('conversation_1'));
        expect(typingIndicator.isTyping, isTrue);
        expect(typingIndicator.isValid, isTrue);
      });

      test('should identify expired typing indicators', () {
        final expiredIndicator = TypingIndicator(
          userId: 'test_user_2',
          conversationId: 'conversation_1',
          isTyping: true,
          timestamp: DateTime.now().subtract(const Duration(seconds: 15)),
        );

        expect(expiredIndicator.isValid, isFalse);
      });

      test('should convert to and from Map correctly', () {
        final originalIndicator = TypingIndicator(
          userId: 'test_user_3',
          conversationId: 'conversation_2',
          isTyping: false,
          timestamp: DateTime.now(),
        );

        final map = originalIndicator.toMap();
        final convertedIndicator = TypingIndicator.fromMap(map);

        expect(convertedIndicator.userId, equals(originalIndicator.userId));
        expect(convertedIndicator.conversationId, equals(originalIndicator.conversationId));
        expect(convertedIndicator.isTyping, equals(originalIndicator.isTyping));
      });
    });

    group('PresenceStatus Extension Tests', () {
      test('should convert status to correct string values', () {
        expect(PresenceStatus.available.value, equals('available'));
        expect(PresenceStatus.busy.value, equals('busy'));
        expect(PresenceStatus.away.value, equals('away'));
        expect(PresenceStatus.doNotDisturb.value, equals('do_not_disturb'));
        expect(PresenceStatus.invisible.value, equals('invisible'));
      });

      test('should have correct display names', () {
        expect(PresenceStatus.available.displayName, equals('Available'));
        expect(PresenceStatus.busy.displayName, equals('Busy'));
        expect(PresenceStatus.away.displayName, equals('Away'));
        expect(PresenceStatus.doNotDisturb.displayName, equals('Do Not Disturb'));
        expect(PresenceStatus.invisible.displayName, equals('Invisible'));
      });

      test('should have correct emojis', () {
        expect(PresenceStatus.available.emoji, equals('🟢'));
        expect(PresenceStatus.busy.emoji, equals('🔴'));
        expect(PresenceStatus.away.emoji, equals('🟡'));
        expect(PresenceStatus.doNotDisturb.emoji, equals('⛔'));
        expect(PresenceStatus.invisible.emoji, equals('⚫'));
      });

      test('should parse string values correctly', () {
        expect(PresenceStatusExtension.fromString('available'), equals(PresenceStatus.available));
        expect(PresenceStatusExtension.fromString('busy'), equals(PresenceStatus.busy));
        expect(PresenceStatusExtension.fromString('away'), equals(PresenceStatus.away));
        expect(PresenceStatusExtension.fromString('do_not_disturb'), equals(PresenceStatus.doNotDisturb));
        expect(PresenceStatusExtension.fromString('invisible'), equals(PresenceStatus.invisible));
        expect(PresenceStatusExtension.fromString('unknown'), equals(PresenceStatus.available));
      });
    });

    group('PresenceStats Model Tests', () {
      test('should calculate percentages correctly', () {
        final stats = PresenceStats(
          totalUsers: 100,
          onlineUsers: 75,
          activeUsers: 50,
          availableUsers: 60,
          statusCounts: {
            PresenceStatus.available: 40,
            PresenceStatus.busy: 20,
            PresenceStatus.away: 15,
          },
          calculatedAt: DateTime.now(),
        );

        expect(stats.onlinePercentage, equals(75.0));
        expect(stats.activePercentage, equals(50.0));
      });

      test('should handle zero total users', () {
        final stats = PresenceStats(
          totalUsers: 0,
          onlineUsers: 0,
          activeUsers: 0,
          availableUsers: 0,
          statusCounts: {},
          calculatedAt: DateTime.now(),
        );

        expect(stats.onlinePercentage, equals(0.0));
        expect(stats.activePercentage, equals(0.0));
      });

      test('should convert to and from Map correctly', () {
        final originalStats = PresenceStats(
          totalUsers: 200,
          onlineUsers: 150,
          activeUsers: 100,
          availableUsers: 120,
          statusCounts: {
            PresenceStatus.available: 80,
            PresenceStatus.busy: 40,
            PresenceStatus.away: 30,
          },
          calculatedAt: DateTime.now(),
        );

        final map = originalStats.toMap();
        final convertedStats = PresenceStats.fromMap(map);

        expect(convertedStats.totalUsers, equals(originalStats.totalUsers));
        expect(convertedStats.onlineUsers, equals(originalStats.onlineUsers));
        expect(convertedStats.activeUsers, equals(originalStats.activeUsers));
        expect(convertedStats.availableUsers, equals(originalStats.availableUsers));
        expect(convertedStats.statusCounts.length, equals(originalStats.statusCounts.length));
      });
    });

    group('Integration Tests', () {
      test('should handle presence updates correctly', () {
        // Test presence update flow
        final initialPresence = UserPresence(
          userId: 'test_user',
          isOnline: true,
          lastSeen: DateTime.now(),
          customStatus: PresenceStatus.available,
          updatedAt: DateTime.now(),
        );

        final updatedPresence = initialPresence.copyWith(
          customStatus: PresenceStatus.busy,
          statusMessage: 'In a meeting',
        );

        expect(updatedPresence.customStatus, equals(PresenceStatus.busy));
        expect(updatedPresence.statusMessage, equals('In a meeting'));
        expect(updatedPresence.userId, equals(initialPresence.userId));
        expect(updatedPresence.isOnline, equals(initialPresence.isOnline));
      });

      test('should handle typing indicator lifecycle', () {
        final startTyping = TypingIndicator(
          userId: 'test_user',
          conversationId: 'conversation_1',
          isTyping: true,
          timestamp: DateTime.now(),
        );

        final stopTyping = TypingIndicator(
          userId: 'test_user',
          conversationId: 'conversation_1',
          isTyping: false,
          timestamp: DateTime.now(),
        );

        expect(startTyping.isTyping, isTrue);
        expect(stopTyping.isTyping, isFalse);
        expect(startTyping.userId, equals(stopTyping.userId));
        expect(startTyping.conversationId, equals(stopTyping.conversationId));
      });
    });
  });
}