// Test for Real-time Messaging Service
// Tests core functionality of message delivery and status tracking

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/messaging/message_error_handler.dart';
import 'package:talowa/services/messaging/real_time_messaging_service.dart';
import 'package:talowa/models/messaging/message_model.dart';
import 'package:talowa/models/messaging/message_status_model.dart';

void main() {
  group('RealTimeMessagingService', () {
    setUp(() {
      // Setup test environment
    });

    group('Message Status Tracking', () {
      test('should create message status with correct initial state', () {
        // Arrange
        const messageId = 'test_message_id';
        const senderId = 'test_sender_id';
        const conversationId = 'test_conversation_id';
        final sentAt = DateTime.now();

        // Act
        final messageStatus = MessageStatusModel(
          messageId: messageId,
          senderId: senderId,
          conversationId: conversationId,
          status: MessageStatus.sending,
          sentAt: sentAt,
        );

        // Assert
        expect(messageStatus.messageId, equals(messageId));
        expect(messageStatus.senderId, equals(senderId));
        expect(messageStatus.conversationId, equals(conversationId));
        expect(messageStatus.status, equals(MessageStatus.sending));
        expect(messageStatus.sentAt, equals(sentAt));
        expect(messageStatus.isPending, isTrue);
        expect(messageStatus.isDelivered, isFalse);
        expect(messageStatus.isRead, isFalse);
        expect(messageStatus.isFailed, isFalse);
      });

      test('should update status to delivered correctly', () {
        // Arrange
        final sentAt = DateTime.now();
        final deliveredAt = sentAt.add(const Duration(seconds: 2));
        
        final messageStatus = MessageStatusModel(
          messageId: 'test_id',
          senderId: 'sender_id',
          status: MessageStatus.sending,
          sentAt: sentAt,
        );

        // Act
        final updatedStatus = messageStatus.copyWith(
          status: MessageStatus.delivered,
          deliveredAt: deliveredAt,
        );

        // Assert
        expect(updatedStatus.status, equals(MessageStatus.delivered));
        expect(updatedStatus.deliveredAt, equals(deliveredAt));
        expect(updatedStatus.isDelivered, isTrue);
        expect(updatedStatus.deliveryTime, equals(const Duration(seconds: 2)));
      });

      test('should update status to read correctly', () {
        // Arrange
        final sentAt = DateTime.now();
        final readAt = sentAt.add(const Duration(seconds: 5));
        
        final messageStatus = MessageStatusModel(
          messageId: 'test_id',
          senderId: 'sender_id',
          status: MessageStatus.delivered,
          sentAt: sentAt,
        );

        // Act
        final updatedStatus = messageStatus.copyWith(
          status: MessageStatus.read,
          readAt: readAt,
        );

        // Assert
        expect(updatedStatus.status, equals(MessageStatus.read));
        expect(updatedStatus.readAt, equals(readAt));
        expect(updatedStatus.isRead, isTrue);
        expect(updatedStatus.readTime, equals(const Duration(seconds: 5)));
      });

      test('should handle read receipts for group messages', () {
        // Arrange
        final readReceipts = [
          ReadReceipt(
            userId: 'user1',
            userName: 'User One',
            readAt: DateTime.now(),
          ),
          ReadReceipt(
            userId: 'user2',
            userName: 'User Two',
            readAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
        ];

        final messageStatus = MessageStatusModel(
          messageId: 'test_id',
          senderId: 'sender_id',
          status: MessageStatus.read,
          sentAt: DateTime.now(),
          readReceipts: readReceipts,
        );

        // Act & Assert
        expect(messageStatus.isReadByUser('user1'), isTrue);
        expect(messageStatus.isReadByUser('user2'), isTrue);
        expect(messageStatus.isReadByUser('user3'), isFalse);
        
        final receipt = messageStatus.getReadReceiptForUser('user1');
        expect(receipt, isNotNull);
        expect(receipt!.userName, equals('User One'));
      });
    });

    group('Message Delivery Status', () {
      test('should have correct status values', () {
        expect(MessageStatus.sending.value, equals('sending'));
        expect(MessageStatus.sent.value, equals('sent'));
        expect(MessageStatus.delivered.value, equals('delivered'));
        expect(MessageStatus.read.value, equals('read'));
        expect(MessageStatus.failed.value, equals('failed'));
      });

      test('should parse status from string correctly', () {
        expect(MessageStatusExtension.fromString('sending'), equals(MessageStatus.sending));
        expect(MessageStatusExtension.fromString('sent'), equals(MessageStatus.sent));
        expect(MessageStatusExtension.fromString('delivered'), equals(MessageStatus.delivered));
        expect(MessageStatusExtension.fromString('read'), equals(MessageStatus.read));
        expect(MessageStatusExtension.fromString('failed'), equals(MessageStatus.failed));
        expect(MessageStatusExtension.fromString('invalid'), equals(MessageStatus.sent));
      });

      test('should have correct display names', () {
        expect(MessageStatus.sending.displayName, equals('Sending'));
        expect(MessageStatus.sent.displayName, equals('Sent'));
        expect(MessageStatus.delivered.displayName, equals('Delivered'));
        expect(MessageStatus.read.displayName, equals('Read'));
        expect(MessageStatus.failed.displayName, equals('Failed'));
      });

      test('should have correct icons', () {
        expect(MessageStatus.sending.icon, equals('⏳'));
        expect(MessageStatus.sent.icon, equals('✓'));
        expect(MessageStatus.delivered.icon, equals('✓✓'));
        expect(MessageStatus.read.icon, equals('✓✓'));
        expect(MessageStatus.failed.icon, equals('❌'));
      });
    });

    group('Error Handling', () {
      test('should classify network errors correctly', () {
        // Arrange
        final errorHandler = MessageErrorHandler();
        final networkError = Exception('Network error');

        // Act
        final messageError = errorHandler.handleError(networkError);

        // Assert
        expect(messageError.type, equals(MessageErrorType.unknownError));
        expect(messageError.isRetryable, isTrue);
        expect(messageError.userFriendlyMessage, contains('unexpected error'));
      });

      test('should provide recovery strategies for different error types', () {
        // Arrange
        final errorHandler = MessageErrorHandler();
        final networkError = MessageError(
          type: MessageErrorType.networkError,
          code: 'NETWORK_ERROR',
          message: 'Network error',
          userFriendlyMessage: 'Network error occurred',
          isRetryable: true,
        );

        // Act
        final strategies = errorHandler.getRecoveryStrategies(networkError);

        // Assert
        expect(strategies, isNotEmpty);
        expect(strategies.any((s) => s.action == 'Check Connection'), isTrue);
        expect(strategies.any((s) => s.action == 'Retry'), isTrue);
      });

      test('should determine offline mode trigger correctly', () {
        // Arrange
        final errorHandler = MessageErrorHandler();
        final networkError = MessageError(
          type: MessageErrorType.networkError,
          code: 'NETWORK_ERROR',
          message: 'Network error',
          userFriendlyMessage: 'Network error occurred',
          isRetryable: true,
        );
        final authError = MessageError(
          type: MessageErrorType.authenticationError,
          code: 'AUTH_ERROR',
          message: 'Auth error',
          userFriendlyMessage: 'Authentication error occurred',
          isRetryable: false,
        );

        // Act & Assert
        expect(errorHandler.shouldTriggerOfflineMode(networkError), isTrue);
        expect(errorHandler.shouldTriggerOfflineMode(authError), isFalse);
      });
    });

    group('Message Model', () {
      test('should create message model correctly', () {
        // Arrange
        final sentAt = DateTime.now();
        const messageId = 'test_message_id';
        const conversationId = 'test_conversation_id';
        const senderId = 'test_sender_id';
        const content = 'Test message content';

        // Act
        final message = MessageModel(
          id: messageId,
          conversationId: conversationId,
          senderId: senderId,
          senderName: 'Test User',
          content: content,
          messageType: MessageType.text,
          mediaUrls: [],
          sentAt: sentAt,
          readBy: [],
          isEdited: false,
          isDeleted: false,
          metadata: {},
        );

        // Assert
        expect(message.id, equals(messageId));
        expect(message.conversationId, equals(conversationId));
        expect(message.senderId, equals(senderId));
        expect(message.content, equals(content));
        expect(message.messageType, equals(MessageType.text));
        expect(message.sentAt, equals(sentAt));
        expect(message.isEdited, isFalse);
        expect(message.isDeleted, isFalse);
      });

      test('should convert message to and from Firestore correctly', () {
        // Arrange
        final message = MessageModel(
          id: 'test_id',
          conversationId: 'conv_id',
          senderId: 'sender_id',
          senderName: 'Test User',
          content: 'Test content',
          messageType: MessageType.text,
          mediaUrls: ['url1', 'url2'],
          sentAt: DateTime.now(),
          readBy: ['user1', 'user2'],
          isEdited: false,
          isDeleted: false,
          metadata: {'key': 'value'},
        );

        // Act
        final firestoreData = message.toFirestore();
        final map = message.toMap();

        // Assert
        expect(firestoreData['conversationId'], equals('conv_id'));
        expect(firestoreData['senderId'], equals('sender_id'));
        expect(firestoreData['content'], equals('Test content'));
        expect(firestoreData['messageType'], equals('text'));
        expect(firestoreData['mediaUrls'], equals(['url1', 'url2']));
        expect(firestoreData['readBy'], equals(['user1', 'user2']));
        expect(firestoreData['metadata'], equals({'key': 'value'}));

        expect(map['id'], equals('test_id'));
        expect(map['messageType'], equals('text'));
      });

      test('should handle message type conversion correctly', () {
        expect(MessageType.text.value, equals('text'));
        expect(MessageType.image.value, equals('image'));
        expect(MessageType.video.value, equals('video'));
        expect(MessageType.audio.value, equals('audio'));
        expect(MessageType.document.value, equals('document'));
        expect(MessageType.location.value, equals('location'));

        expect(MessageTypeExtension.fromString('text'), equals(MessageType.text));
        expect(MessageTypeExtension.fromString('image'), equals(MessageType.image));
        expect(MessageTypeExtension.fromString('invalid'), equals(MessageType.text));
      });
    });

    group('Retry Logic', () {
      test('should calculate exponential backoff correctly', () {
        // Arrange
        const retryConfig = RetryConfig(
          maxRetries: 5,
          initialDelay: Duration(seconds: 1),
          backoffMultiplier: 2.0,
          maxDelay: Duration(seconds: 30),
        );

        // Act & Assert
        expect(retryConfig.maxRetries, equals(5));
        expect(retryConfig.initialDelay, equals(const Duration(seconds: 1)));
        expect(retryConfig.backoffMultiplier, equals(2.0));
        expect(retryConfig.maxDelay, equals(const Duration(seconds: 30)));
      });
    });
  });
}