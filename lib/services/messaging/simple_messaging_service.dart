// Simplified Messaging Service for TALOWA
// Eliminates complex Firebase index requirements

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/message_model.dart';
import '../auth_service.dart';

class SimpleMessagingService {
  static final SimpleMessagingService _instance = SimpleMessagingService._internal();
  factory SimpleMessagingService() => _instance;
  SimpleMessagingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user conversations without complex indexes
  Stream<List<ConversationModel>> getUserConversations() {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        return Stream.value([]);
      }

      // Simple query - no complex indexes needed
      return _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUser.uid)
          .limit(50) // Reasonable limit
          .snapshots()
          .map((snapshot) {
        final conversations = snapshot.docs
            .map((doc) => ConversationModel.fromFirestore(doc))
            .where((conversation) => conversation.isActive)
            .toList();
        
        // Sort locally by lastMessageAt (no index needed)
        conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        return conversations;
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
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList());
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return Stream.value([]);
    }
  }

  /// Send a message
  Future<bool> sendMessage({
    required String conversationId,
    required String content,
    String? mediaUrl,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return false;

      final message = MessageModel(
        id: '',
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'User',
        content: content,
        messageType: MessageType.text,
        mediaUrls: mediaUrl != null ? [mediaUrl] : [],
        sentAt: DateTime.now(),
        readBy: [],
        isEdited: false,
        isDeleted: false,
        metadata: {},
      );

      // Add message
      await _firestore.collection('messages').add(message.toFirestore());

      // Update conversation (simple update, no complex query)
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': content,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
      });

      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Create a new conversation
  Future<String?> createConversation({
    required List<String> participantIds,
    required String name,
    ConversationType type = ConversationType.group,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return null;

      final conversationId = _firestore.collection('conversations').doc().id;

      final conversation = ConversationModel(
        id: conversationId,
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

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversation.toFirestore());

      return conversationId;
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      return null;
    }
  }

  /// Search conversations (simple local search)
  Future<List<ConversationModel>> searchConversations(String query) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      // Get all user conversations and search locally
      final snapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUser.uid)
          .get();

      return snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .where((conversation) =>
              conversation.isActive &&
              (conversation.name.toLowerCase().contains(query.toLowerCase()) ||
               conversation.lastMessage.toLowerCase().contains(query.toLowerCase())))
          .toList();
    } catch (e) {
      debugPrint('Error searching conversations: $e');
      return [];
    }
  }
}
