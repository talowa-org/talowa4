// Integrated Messaging Service for TALOWA
// A simplified, working messaging service that combines all functionality

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/user_model.dart';
import '../auth_service.dart';

class IntegratedMessagingService {
  static final IntegratedMessagingService _instance = IntegratedMessagingService._internal();
  factory IntegratedMessagingService() => _instance;
  IntegratedMessagingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;

  /// Initialize the messaging service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🚀 Initializing Integrated Messaging Service');
      _isInitialized = true;
      debugPrint('✅ Integrated Messaging Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing messaging service: $e');
      rethrow;
    }
  }

  /// Get user conversations stream
  Stream<List<ConversationModel>> getUserConversations() {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        return Stream.value([]);
      }

      return _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('lastMessageAt', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => ConversationModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('Error getting conversations: $e');
      return Stream.value([]);
    }
  }

  /// Get messages for a conversation
  Stream<List<MessageModel>> getConversationMessages(String conversationId) {
    try {
      return _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('sentAt', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return Stream.value([]);
    }
  }

  /// Send a message
  Future<String> sendMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (content.trim().isEmpty && (mediaUrls == null || mediaUrls.isEmpty)) {
        throw Exception('Message content cannot be empty');
      }

      // Create message
      final messageRef = _firestore.collection('messages').doc();
      final message = MessageModel(
        id: messageRef.id,
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'User',
        content: content,
        messageType: messageType,
        mediaUrls: mediaUrls ?? [],
        sentAt: DateTime.now(),
        readBy: [], // Empty - only add when receiver actually reads the message
        isEdited: false,
        isDeleted: false,
        metadata: metadata ?? {},
      );

      // Save message
      await messageRef.set(message.toFirestore());

      // Update conversation
      await _updateConversationLastMessage(conversationId, message);

      debugPrint('✅ Message sent successfully: ${message.id}');
      return message.id;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Create a new conversation
  Future<String> createConversation({
    required List<String> participantIds,
    required String name,
    ConversationType type = ConversationType.direct,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Ensure current user is in participants
      if (!participantIds.contains(currentUser.uid)) {
        participantIds.add(currentUser.uid);
      }

      // For direct messages, check if conversation already exists
      if (type == ConversationType.direct && participantIds.length == 2) {
        final existingConversation = await _findExistingDirectConversation(participantIds);
        if (existingConversation != null) {
          return existingConversation.id;
        }
      }

      // Create new conversation
      final conversationRef = _firestore.collection('conversations').doc();
      final conversation = ConversationModel(
        id: conversationRef.id,
        name: name,
        type: type,
        participantIds: participantIds,
        createdBy: currentUser.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        lastMessage: 'Conversation created',
        lastMessageSenderId: currentUser.uid,
        unreadCounts: {for (String id in participantIds) id: 0},
        isActive: true,
        metadata: {},
      );

      await conversationRef.set(conversation.toFirestore());

      debugPrint('✅ Conversation created: ${conversation.id}');
      return conversation.id;
    } catch (e) {
      debugPrint('❌ Error creating conversation: $e');
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
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Conversation marked as read: $conversationId');
    } catch (e) {
      debugPrint('❌ Error marking conversation as read: $e');
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

      debugPrint('✅ Message edited: $messageId');
    } catch (e) {
      debugPrint('❌ Error editing message: $e');
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

      debugPrint('✅ Message deleted: $messageId');
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      rethrow;
    }
  }

  /// Search users for messaging
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      final snapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .limit(20)
          .get();

      final users = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) =>
              user.fullName.toLowerCase().contains(query.toLowerCase()) ||
              user.phoneNumber.contains(query))
          .toList();

      return users;
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      return [];
    }
  }

  /// Get conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      final doc = await _firestore.collection('conversations').doc(conversationId).get();
      if (doc.exists) {
        return ConversationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting conversation: $e');
      return null;
    }
  }

  /// Start direct chat with user
  Future<String> startDirectChat(String userId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user info
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final user = UserModel.fromFirestore(userDoc);
      final participantIds = [currentUser.uid, userId];

      // Check for existing conversation
      final existingConversation = await _findExistingDirectConversation(participantIds);
      if (existingConversation != null) {
        return existingConversation.id;
      }

      // Create new direct conversation
      return await createConversation(
        participantIds: participantIds,
        name: user.fullName,
        type: ConversationType.direct,
      );
    } catch (e) {
      debugPrint('❌ Error starting direct chat: $e');
      rethrow;
    }
  }

  // Private helper methods

  /// Update conversation with last message info
  Future<void> _updateConversationLastMessage(String conversationId, MessageModel message) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': message.content.isNotEmpty ? message.content : 'Media message',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': message.senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating conversation: $e');
    }
  }

  /// Find existing direct conversation between users
  Future<ConversationModel?> _findExistingDirectConversation(List<String> participantIds) async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .where('type', isEqualTo: 'direct')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final conversation = ConversationModel.fromFirestore(doc);
        if (conversation.participantIds.length == participantIds.length &&
            conversation.participantIds.every((id) => participantIds.contains(id))) {
          return conversation;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error finding existing conversation: $e');
      return null;
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
}