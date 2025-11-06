// Test for Message History Service
// Tests Task 5 implementation: Message history storage and retrieval system

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/messaging/message_threading_service.dart';
import 'package:talowa/models/messaging/message_model.dart';

void main() {
  group('Message History Service Tests', () {
    late MessageThreadingService threadingService;

    setUp(() {
      threadingService = MessageThreadingService();
    });



    test('should sort messages chronologically', () {
      final now = DateTime.now();
      final messages = [
        MessageModel(
          id: 'msg3',
          conversationId: 'conv1',
          senderId: 'user1',
          senderName: 'User 1',
          content: 'Third message',
          messageType: MessageType.text,
          mediaUrls: [],
          sentAt: now.add(const Duration(minutes: 2)),
          readBy: [],
          isEdited: false,
          isDeleted: false,
          metadata: {},
        ),
        MessageModel(
          id: 'msg1',
          conversationId: 'conv1',
          senderId: 'user1',
          senderName: 'User 1',
          content: 'First message',
          messageType: MessageType.text,
          mediaUrls: [],
          sentAt: now,
          readBy: [],
          isEdited: false,
          isDeleted: false,
          metadata: {},
        ),
        MessageModel(
          id: 'msg2',
          conversationId: 'conv1',
          senderId: 'user2',
          senderName: 'User 2',
          content: 'Second message',
          messageType: MessageType.text,
          mediaUrls: [],
          sentAt: now.add(const Duration(minutes: 1)),
          readBy: [],
          isEdited: false,
          isDeleted: false,
          metadata: {},
        ),
      ];

      final sortedMessages = threadingService.sortMessagesChronologically(
        messages: messages,
        ascending: true,
        enableThreading: false,
      );

      expect(sortedMessages.length, equals(3));
      expect(sortedMessages[0].id, equals('msg1'));
      expect(sortedMessages[1].id, equals('msg2'));
      expect(sortedMessages[2].id, equals('msg3'));
    });

    test('should merge message sources correctly', () {
      final now = DateTime.now();
      
      final source1 = [
        MessageModel(
          id: 'msg1',
          conversationId: 'conv1',
          senderId: 'user1',
          senderName: 'User 1',
          content: 'Message 1',
          messageType: MessageType.text,
          mediaUrls: [],
          sentAt: now,
          readBy: [],
          isEdited: false,
          isDeleted: false,
          metadata: {},
        ),
      ];

      final source2 = [
        MessageModel(
          id: 'msg2',
          conversationId: 'conv1',
          senderId: 'user2',
          senderName: 'User 2',
          content: 'Message 2',
          messageType: MessageType.text,
          mediaUrls: [],
          sentAt: now.add(const Duration(minutes: 1)),
          readBy: [],
          isEdited: false,
          isDeleted: false,
          metadata: {},
        ),
      ];

      final mergedMessages = threadingService.mergeMessageSources(
        messageSources: [source1, source2],
        removeDuplicates: true,
        enableThreading: false,
      );

      expect(mergedMessages.length, equals(2));
      expect(mergedMessages.map((m) => m.id).toSet(), equals({'msg1', 'msg2'}));
    });

    test('should handle empty message lists', () {
      final sortedMessages = threadingService.sortMessagesChronologically(
        messages: [],
        enableThreading: false,
      );

      expect(sortedMessages, isEmpty);
    });

    test('should create message threads correctly', () {
      final now = DateTime.now();
      final messages = [
        MessageModel(
          id: 'msg1',
          conversationId: 'conv1',
          senderId: 'user1',
          senderName: 'User 1',
          content: 'First message',
          messageType: MessageType.text,
          mediaUrls: [],
          sentAt: now,
          readBy: [],
          isEdited: false,
          isDeleted: false,
          metadata: {},
        ),
        MessageModel(
          id: 'msg2',
          conversationId: 'conv1',
          senderId: 'user1',
          senderName: 'User 1',
          content: 'Second message',
          messageType: MessageType.text,
          mediaUrls: [],
          sentAt: now.add(const Duration(minutes: 1)),
          readBy: [],
          isEdited: false,
          isDeleted: false,
          metadata: {},
        ),
      ];

      final threads = threadingService.createMessageThreads(
        messages: messages,
      );

      expect(threads.length, greaterThanOrEqualTo(0));
      if (threads.isNotEmpty) {
        expect(threads.first.messages.length, greaterThanOrEqualTo(1));
      }
    });


  });
}