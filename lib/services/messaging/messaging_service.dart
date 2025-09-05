// Messaging Service for TALOWA
// Fully functional real-time messaging with Firebase
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../auth_service.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _conversationsCollection = 'conversations';
  final String _messagesCollection = 'messages';

  // Create a new conversation
  Future<String> createConversation({
    required String name,
    required ConversationType type,
    required List<String> participantIds,
    String? description,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final conversationId = _firestore.collection(_conversationsCollection).doc().id;

      final conversation = ConversationModel(
        id: conversationId,
        name: name,
        type: type,
        participantIds: [currentUser.uid, ...participantIds],
        createdBy: currentUser.uid,
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        lastMessage: 'Conversation created',
        lastMessageSenderId: currentUser.uid,
        unreadCounts: {for (String id in [currentUser.uid, ...participantIds]) id: 0},
        isActive: true,
        description: description,
        metadata: {},
      );

      await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .set(conversation.toFirestore());

      // Send initial system message
      await sendMessage(
        conversationId: conversationId,
        content: 'Conversation created',
        messageType: MessageType.system,
      );

      debugPrint('Conversation created successfully: $conversationId');
      return conversationId;
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      rethrow;
    }
  }

  // Send a message
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

      // Get user profile for sender info
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final messageId = _firestore.collection(_messagesCollection).doc().id;

      final message = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderName: userData['fullName'] ?? 'Unknown User',
        content: content,
        messageType: messageType,
        mediaUrls: mediaUrls ?? [],
        sentAt: DateTime.now(),
        deliveredAt: null,
        readAt: null,
        readBy: [],
        isEdited: false,
        isDeleted: false,
        metadata: metadata ?? {},
      );

      // Save message
      await _firestore
          .collection(_messagesCollection)
          .doc(messageId)
          .set(message.toFirestore());

      // Update conversation with last message info
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: content,
        lastMessageSenderId: currentUser.uid,
        lastMessageAt: DateTime.now(),
      );

      debugPrint('Message sent successfully: $messageId');
      return messageId;
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  // Get conversations for current user
  Stream<List<ConversationModel>> getUserConversations() {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        return Stream.value([]);
      }

      // Simple query without orderBy to avoid index requirement
      return _firestore
          .collection(_conversationsCollection)
          .where('participantIds', arrayContains: currentUser.uid)
          .snapshots()
          .map((snapshot) {
        final conversations = snapshot.docs
            .map((doc) => ConversationModel.fromFirestore(doc))
            .where((conversation) => conversation.isActive)
            .toList();
        
        // Sort locally by lastMessageAt
        conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        return conversations;
      });
    } catch (e) {
      debugPrint('Error getting user conversations: $e');
      return Stream.value([]);
    }
  }

  // Get messages for a conversation
  Stream<List<MessageModel>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  }) {
    try {
      return _firestore
          .collection(_messagesCollection)
          .where('conversationId', isEqualTo: conversationId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return MessageModel.fromFirestore(doc);
        }).toList();
      });
    } catch (e) {
      debugPrint('Error getting conversation messages: $e');
      return Stream.value([]);
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead({
    required String messageId,
    required String conversationId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Update message read status
      await _firestore.collection(_messagesCollection).doc(messageId).update({
        'readBy': FieldValue.arrayUnion([currentUser.uid]),
        'readAt': FieldValue.serverTimestamp(),
      });

      // Update conversation unread count
      await _firestore.collection(_conversationsCollection).doc(conversationId).update({
        'unreadCounts.${currentUser.uid}': 0,
      });
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  // Mark all messages in conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Get all unread messages in conversation
      final unreadMessages = await _firestore
          .collection(_messagesCollection)
          .where('conversationId', isEqualTo: conversationId)
          .where('senderId', isNotEqualTo: currentUser.uid)
          .get();

      // Batch update all unread messages
      final batch = _firestore.batch();
      
      for (final doc in unreadMessages.docs) {
        final data = doc.data();
        final readBy = List<String>.from(data['readBy'] ?? []);
        
        if (!readBy.contains(currentUser.uid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([currentUser.uid]),
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Update conversation unread count
      batch.update(
        _firestore.collection(_conversationsCollection).doc(conversationId),
        {'unreadCounts.${currentUser.uid}': 0},
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Check if user owns the message
      final messageDoc = await _firestore.collection(_messagesCollection).doc(messageId).get();
      if (!messageDoc.exists) return;

      final messageData = messageDoc.data()!;
      if (messageData['senderId'] != currentUser.uid) {
        throw Exception('Not authorized to delete this message');
      }

      // Soft delete the message
      await _firestore.collection(_messagesCollection).doc(messageId).update({
        'isDeleted': true,
        'content': 'This message was deleted',
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  // Edit message
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Check if user owns the message
      final messageDoc = await _firestore.collection(_messagesCollection).doc(messageId).get();
      if (!messageDoc.exists) return;

      final messageData = messageDoc.data()!;
      if (messageData['senderId'] != currentUser.uid) {
        throw Exception('Not authorized to edit this message');
      }

      // Update the message
      await _firestore.collection(_messagesCollection).doc(messageId).update({
        'content': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error editing message: $e');
      rethrow;
    }
  }

  // Add participant to conversation
  Future<void> addParticipant({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Check if current user is in the conversation
      final conversationDoc = await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) return;

      final conversationData = conversationDoc.data()!;
      final participantIds = List<String>.from(conversationData['participantIds'] ?? []);

      if (!participantIds.contains(currentUser.uid)) {
        throw Exception('Not authorized to add participants');
      }

      if (participantIds.contains(userId)) {
        return; // User already in conversation
      }

      // Add participant
      await _firestore.collection(_conversationsCollection).doc(conversationId).update({
        'participantIds': FieldValue.arrayUnion([userId]),
        'unreadCounts.$userId': 0,
      });

      // Send system message
      await sendMessage(
        conversationId: conversationId,
        content: 'User added to conversation',
        messageType: MessageType.system,
        metadata: {'addedUserId': userId},
      );
    } catch (e) {
      debugPrint('Error adding participant: $e');
      rethrow;
    }
  }

  // Remove participant from conversation
  Future<void> removeParticipant({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Remove participant
      await _firestore.collection(_conversationsCollection).doc(conversationId).update({
        'participantIds': FieldValue.arrayRemove([userId]),
        'unreadCounts.$userId': FieldValue.delete(),
      });

      // Send system message
      await sendMessage(
        conversationId: conversationId,
        content: 'User removed from conversation',
        messageType: MessageType.system,
        metadata: {'removedUserId': userId},
      );
    } catch (e) {
      debugPrint('Error removing participant: $e');
      rethrow;
    }
  }

  // Search conversations
  Future<List<ConversationModel>> searchConversations(String query) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection(_conversationsCollection)
          .where('participantIds', arrayContains: currentUser.uid)
          .get();

      final conversations = snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .where((conversation) =>
              conversation.name.toLowerCase().contains(query.toLowerCase()) ||
              conversation.lastMessage.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return conversations;
    } catch (e) {
      debugPrint('Error searching conversations: $e');
      return [];
    }
  }

  // Get conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      final doc = await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .get();

      if (doc.exists) {
        return ConversationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      return null;
    }
  }

  // Private helper methods
  Future<void> _updateConversationLastMessage({
    required String conversationId,
    required String lastMessage,
    required String lastMessageSenderId,
    required DateTime lastMessageAt,
  }) async {
    try {
      // Get conversation to update unread counts
      final conversationDoc = await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) return;

      final conversationData = conversationDoc.data()!;
      final participantIds = List<String>.from(conversationData['participantIds'] ?? []);
      final currentUnreadCounts = Map<String, int>.from(conversationData['unreadCounts'] ?? {});

      // Increment unread count for all participants except sender
      for (final participantId in participantIds) {
        if (participantId != lastMessageSenderId) {
          currentUnreadCounts[participantId] = (currentUnreadCounts[participantId] ?? 0) + 1;
        }
      }

      await _firestore.collection(_conversationsCollection).doc(conversationId).update({
        'lastMessage': lastMessage,
        'lastMessageSenderId': lastMessageSenderId,
        'lastMessageAt': Timestamp.fromDate(lastMessageAt),
        'unreadCounts': currentUnreadCounts,
      });
    } catch (e) {
      debugPrint('Error updating conversation last message: $e');
    }
  }

  // Create direct conversation between two users
  Future<String> createDirectConversation(String otherUserId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if conversation already exists
      final existingConversations = await _firestore
          .collection(_conversationsCollection)
          .where('type', isEqualTo: ConversationType.direct.value)
          .where('participantIds', arrayContains: currentUser.uid)
          .get();

      for (final doc in existingConversations.docs) {
        final data = doc.data();
        final participantIds = List<String>.from(data['participantIds'] ?? []);
        if (participantIds.contains(otherUserId) && participantIds.length == 2) {
          return doc.id; // Return existing conversation
        }
      }

      // Get other user's name
      final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
      final otherUserName = otherUserDoc.exists 
          ? otherUserDoc.data()!['fullName'] ?? 'Unknown User'
          : 'Unknown User';

      // Create new direct conversation
      return await createConversation(
        name: otherUserName,
        type: ConversationType.direct,
        participantIds: [otherUserId],
      );
    } catch (e) {
      debugPrint('Error creating direct conversation: $e');
      rethrow;
    }
  }
}
