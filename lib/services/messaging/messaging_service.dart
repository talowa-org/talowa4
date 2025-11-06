// Main Messaging Service for TALOWA
// Combines simple and advanced messaging features with real-time delivery confirmation

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/message_status_model.dart';
import '../auth_service.dart';
import 'simple_messaging_service.dart';
import 'advanced_messaging_service.dart';
import 'real_time_messaging_service.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SimpleMessagingService _simpleMessaging = SimpleMessagingService();
  final AdvancedMessagingService _advancedMessaging = AdvancedMessagingService();
  final RealTimeMessagingService _realTimeMessaging = RealTimeMessagingService();

  // Stream controllers for message status updates
  final StreamController<MessageStatusModel> _messageStatusController = 
      StreamController<MessageStatusModel>.broadcast();
  final StreamController<Map<String, dynamic>> _typingIndicatorController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for real-time streams
  Stream<MessageModel> get messageStream => _realTimeMessaging.messageStream;
  Stream<MessageDeliveryStatus> get deliveryStatusStream => _realTimeMessaging.deliveryStatusStream;
  Stream<MessageStatusModel> get messageStatusStream => _messageStatusController.stream;
  Stream<Map<String, dynamic>> get typingIndicatorStream => _realTimeMessaging.typingIndicatorStream;
  Stream<String> get connectionStatusStream => _realTimeMessaging.connectionStatusStream;

  bool get isRealTimeConnected => _realTimeMessaging.isConnected;

  /// Initialize messaging service
  Future<void> initialize() async {
    try {
      // Initialize real-time messaging first
      await _realTimeMessaging.initialize();
      
      // Initialize advanced messaging
      await _advancedMessaging.initialize();
      
      // Set up message status tracking
      _setupMessageStatusTracking();
      
      debugPrint('✅ Messaging Service initialized with real-time support');
    } catch (e) {
      debugPrint('❌ Error initializing messaging service: $e');
      rethrow;
    }
  }

  /// Set up message status tracking
  void _setupMessageStatusTracking() {
    // Listen to delivery status updates
    _realTimeMessaging.deliveryStatusStream.listen((status) {
      debugPrint('📊 Message delivery status: ${status.toString()}');
    });

    // Listen to typing indicators
    _realTimeMessaging.typingIndicatorStream.listen((data) {
      _typingIndicatorController.add(data);
    });

    // Listen to connection status
    _realTimeMessaging.connectionStatusStream.listen((status) {
      debugPrint('🔗 Connection status: $status');
    });
  }

  /// Get conversation messages stream
  Stream<List<MessageModel>> getConversationMessages({required String conversationId}) {
    return _simpleMessaging.getConversationMessages(conversationId);
  }

  /// Send a message with real-time delivery confirmation
  Future<String> sendMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Use real-time messaging service for enhanced delivery
      final messageId = await _realTimeMessaging.sendMessage(
        conversationId: conversationId,
        content: content,
        messageType: messageType,
        mediaUrls: mediaUrls,
        metadata: metadata,
      );

      // Create message status tracking
      await _createMessageStatus(messageId, conversationId);

      return messageId;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Create message status tracking record
  Future<void> _createMessageStatus(String messageId, String conversationId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      final messageStatus = MessageStatusModel(
        messageId: messageId,
        senderId: currentUser.uid,
        conversationId: conversationId,
        status: MessageStatus.sending,
        sentAt: DateTime.now(),
      );

      await _firestore
          .collection('message_status')
          .doc(messageId)
          .set(messageStatus.toFirestore());

      _messageStatusController.add(messageStatus);
    } catch (e) {
      debugPrint('❌ Error creating message status: $e');
    }
  }

  /// Edit a message
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'content': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error editing message: $e');
      rethrow;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  /// Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCounts.${currentUser.uid}': 0,
      });
    } catch (e) {
      debugPrint('❌ Error marking conversation as read: $e');
    }
  }

  /// Mark specific message as read with real-time confirmation
  Future<void> markMessageAsRead(String messageId) async {
    try {
      // Use real-time service for immediate read receipt
      await _realTimeMessaging.markMessageAsRead(messageId);

      // Update message status
      await _updateMessageStatus(messageId, MessageStatus.read);
    } catch (e) {
      debugPrint('❌ Error marking message as read: $e');
    }
  }

  /// Update message status
  Future<void> _updateMessageStatus(String messageId, MessageStatus status) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.value,
      };

      if (status == MessageStatus.delivered) {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      } else if (status == MessageStatus.read) {
        updateData['readAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('message_status')
          .doc(messageId)
          .update(updateData);

      // Get updated status and emit to stream
      final doc = await _firestore
          .collection('message_status')
          .doc(messageId)
          .get();
      
      if (doc.exists) {
        final messageStatus = MessageStatusModel.fromFirestore(doc);
        _messageStatusController.add(messageStatus);
      }
    } catch (e) {
      debugPrint('❌ Error updating message status: $e');
    }
  }

  /// Send typing indicator
  void sendTypingIndicator(String conversationId, bool isTyping) {
    _realTimeMessaging.sendTypingIndicator(conversationId, isTyping);
  }

  /// Join conversation room for real-time updates
  void joinConversationRoom(String conversationId) {
    _realTimeMessaging.joinConversationRoom(conversationId);
  }

  /// Leave conversation room
  void leaveConversationRoom(String conversationId) {
    _realTimeMessaging.leaveConversationRoom(conversationId);
  }

  /// Get message status
  Future<MessageStatusModel?> getMessageStatus(String messageId) async {
    try {
      final doc = await _firestore
          .collection('message_status')
          .doc(messageId)
          .get();
      
      if (doc.exists) {
        return MessageStatusModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting message status: $e');
      return null;
    }
  }

  /// Get message status stream for specific message
  Stream<MessageStatusModel?> getMessageStatusStream(String messageId) {
    return _firestore
        .collection('message_status')
        .doc(messageId)
        .snapshots()
        .map((doc) => doc.exists ? MessageStatusModel.fromFirestore(doc) : null);
  }

  /// Create a new conversation
  Future<String?> createConversation({
    required List<String> participantIds,
    required String name,
    ConversationType type = ConversationType.group,
  }) async {
    return await _simpleMessaging.createConversation(
      participantIds: participantIds,
      name: name,
      type: type,
    );
  }

  /// Search conversations
  Future<List<ConversationModel>> searchConversations(String query) async {
    return await _simpleMessaging.searchConversations(query);
  }

  /// Advanced search messages
  Future<List<MessageModel>> searchMessages({
    required String query,
    List<String>? conversationIds,
    List<MessageType>? messageTypes,
    DateTime? startDate,
    DateTime? endDate,
    String? senderId,
    bool includeDeleted = false,
  }) async {
    return await _advancedMessaging.searchMessages(
      query: query,
      conversationIds: conversationIds,
      messageTypes: messageTypes,
      startDate: startDate,
      endDate: endDate,
      senderId: senderId,
      includeDeleted: includeDeleted,
    );
  }

  /// Smart search with AI
  Future<List<MessageModel>> smartSearch(String query) async {
    return await _advancedMessaging.smartSearch(query);
  }

  /// Translate message
  Future<String> translateMessage(String content, String targetLanguage) async {
    return await _advancedMessaging.translateMessage(content, targetLanguage);
  }

  /// Generate smart replies
  Future<List<String>> generateSmartReplies(String messageContent, {String? conversationContext}) async {
    return await _advancedMessaging.generateSmartReplies(messageContent, conversationContext: conversationContext);
  }

  /// Schedule a message
  Future<String?> scheduleMessage({
    required String conversationId,
    required String content,
    required DateTime scheduledAt,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
  }) async {
    return await _advancedMessaging.scheduleMessage(
      conversationId: conversationId,
      content: content,
      scheduledAt: scheduledAt,
      messageType: messageType,
      mediaUrls: mediaUrls,
    );
  }

  /// Get user conversations stream
  Stream<List<ConversationModel>> getUserConversations() {
    return _simpleMessaging.getUserConversations();
  }

  /// Get user messaging statistics
  Future<UserMessagingStats> getUserMessagingStats() async {
    return await _advancedMessaging.getUserMessagingStats();
  }

  /// Get conversation analytics
  Future<ConversationAnalytics> getConversationAnalytics(String conversationId) async {
    return await _advancedMessaging.getConversationAnalytics(conversationId);
  }

  /// Dispose of messaging service resources
  Future<void> dispose() async {
    try {
      // Dispose real-time messaging service
      await _realTimeMessaging.dispose();

      // Close stream controllers
      await _messageStatusController.close();
      await _typingIndicatorController.close();

      debugPrint('✅ MessagingService: Disposed successfully');
    } catch (e) {
      debugPrint('❌ Error disposing messaging service: $e');
    }
  }

  /// Initiate voice call
  Future<CallSession?> initiateVoiceCall(String conversationId, List<String> participantIds) async {
    return await _advancedMessaging.initiateVoiceCall(conversationId, participantIds);
  }

  /// Initiate video call
  Future<CallSession?> initiateVideoCall(String conversationId, List<String> participantIds) async {
    return await _advancedMessaging.initiateVideoCall(conversationId, participantIds);
  }

  /// Answer call
  Future<bool> answerCall(String callId) async {
    return await _advancedMessaging.answerCall(callId);
  }

  /// End call
  Future<bool> endCall(String callId) async {
    return await _advancedMessaging.endCall(callId);
  }
}