// TALOWA Messaging Service - Production Ready
// Simplified, efficient, and scalable messaging implementation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/message_model.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize() async {
    try {
      debugPrint('✅ MessagingService initialized');
    } catch (e) {
      debugPrint('❌ MessagingService initialization error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CONVERSATIONS
  // ============================================================================

  /// Get all conversations for current user
  Stream<List<ConversationModel>> getUserConversations() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    // Simplified query - just get all conversations and filter in memory
    return _firestore
        .collection('conversations')
        .snapshots()
        .map((snapshot) {
      // Filter and sort in memory to avoid Firestore index issues
      final conversations = snapshot.docs
          .map((doc) {
            try {
              final conv = ConversationModel.fromFirestore(doc);
              // Filter: only return conversations where current user is a participant
              if (conv.participantIds.contains(currentUserId)) {
                return conv;
              }
              return null;
            } catch (e) {
              debugPrint('Error parsing conversation ${doc.id}: $e');
              return null;
            }
          })
          .whereType<ConversationModel>()
          .toList();
      
      // Sort by last message time
      conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return conversations;
    });
  }

  /// Get single conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!doc.exists) return null;
      return ConversationModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      return null;
    }
  }

  /// Create new conversation
  Future<String> createConversation({
    required List<String> participantIds,
    required ConversationType type,
    String? name,
    String? description,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    // Add current user to participants if not already included
    if (!participantIds.contains(currentUserId)) {
      participantIds.add(currentUserId!);
    }

    final conversationData = {
      'participantIds': participantIds,
      'type': type.value,
      'name': name ?? _generateConversationName(participantIds, type),
      'description': description,
      'createdBy': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': '',
      'unreadCounts': {for (var id in participantIds) id: 0},
      'isActive': true,
      'metadata': {},
    };

    final docRef = await _firestore.collection('conversations').add(conversationData);
    return docRef.id;
  }

  /// Start direct chat with user
  Future<String> startDirectChat(String otherUserId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    // Check if conversation already exists
    final existingConversation = await _findDirectConversation(otherUserId);
    if (existingConversation != null) {
      return existingConversation;
    }

    // Create new conversation
    return await createConversation(
      participantIds: [currentUserId!, otherUserId],
      type: ConversationType.direct,
    );
  }

  /// Find existing direct conversation between two users
  Future<String?> _findDirectConversation(String otherUserId) async {
    if (currentUserId == null) return null;

    final snapshot = await _firestore
        .collection('conversations')
        .where('type', isEqualTo: 'direct')
        .where('participantIds', arrayContains: currentUserId)
        .get();

    for (var doc in snapshot.docs) {
      final participants = List<String>.from(doc.data()['participantIds'] ?? []);
      if (participants.length == 2 && participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    return null;
  }

  /// Generate conversation name
  String _generateConversationName(List<String> participantIds, ConversationType type) {
    switch (type) {
      case ConversationType.direct:
        return 'Direct Chat';
      case ConversationType.group:
        return 'Group Chat';
      case ConversationType.anonymous:
        return 'Anonymous Report';
      default:
        return 'Conversation';
    }
  }

  // ============================================================================
  // MESSAGES
  // ============================================================================

  /// Get messages for a conversation
  Stream<List<MessageModel>> getMessages(String conversationId, {int limit = 50}) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      // Get all messages and sort in memory to avoid index issues
      final messages = snapshot.docs
          .map((doc) {
            try {
              return MessageModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing message ${doc.id}: $e');
              return null;
            }
          })
          .whereType<MessageModel>()
          .toList();
      
      // Sort by sentAt in memory
      messages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      
      // Limit results
      return messages.take(limit).toList();
    });
  }

  /// Send message
  Future<String> sendMessage({
    required String conversationId,
    required String content,
    required MessageType type,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final messageData = {
      'conversationId': conversationId,
      'senderId': currentUserId,
      'senderName': 'User', // TODO: Get from user profile
      'content': content,
      'messageType': type.value,
      'mediaUrls': mediaUrl != null ? [mediaUrl] : [],
      'sentAt': FieldValue.serverTimestamp(),
      'readBy': [], // Empty array - only add when receiver actually reads the message
      'isEdited': false,
      'isDeleted': false,
      'metadata': metadata ?? {},
    };

    // Add message to conversation
    final messageRef = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(messageData);

    // Update conversation last message
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Increment unread count for other participants
    await _incrementUnreadCount(conversationId);

    return messageRef.id;
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String conversationId, String messageId) async {
    if (currentUserId == null) return;

    // Get the message to check if current user is the sender
    final messageDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .get();

    if (!messageDoc.exists) return;

    final senderId = messageDoc.data()?['senderId'];
    
    // Only mark as read if current user is NOT the sender
    if (senderId != currentUserId) {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readBy': FieldValue.arrayUnion([currentUserId]),
        'readAt': FieldValue.serverTimestamp(), // Set read timestamp
        'status': 'read',
      });
    }
  }

  /// Mark all messages in conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    if (currentUserId == null) return;

    // Get all unread messages in the conversation
    final messagesSnapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId) // Only messages from others
        .get();

    // Mark each message as read
    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      
      // Only update if current user hasn't read it yet
      if (!readBy.contains(currentUserId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([currentUserId]),
          'readAt': FieldValue.serverTimestamp(),
          'status': 'read',
        });
      }
    }
    
    // Commit all updates
    await batch.commit();

    // Reset unread count for current user
    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCounts.$currentUserId': 0,
    });
  }

  /// Increment unread count for participants
  Future<void> _incrementUnreadCount(String conversationId) async {
    if (currentUserId == null) return;

    final conversationDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();

    if (!conversationDoc.exists) return;

    final participants = List<String>.from(conversationDoc.data()?['participantIds'] ?? []);

    // Increment for all participants except sender
    for (var participantId in participants) {
      if (participantId != currentUserId) {
        await _firestore.collection('conversations').doc(conversationId).update({
          'unreadCounts.$participantId': FieldValue.increment(1),
        });
      }
    }
  }

  // ============================================================================
  // GROUP MANAGEMENT
  // ============================================================================

  /// Add participant to group
  Future<void> addParticipant(String conversationId, String userId) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'participantIds': FieldValue.arrayUnion([userId]),
      'unreadCounts.$userId': 0,
    });
  }

  /// Remove participant from group
  Future<void> removeParticipant(String conversationId, String userId) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'participantIds': FieldValue.arrayRemove([userId]),
    });
  }

  /// Update group info
  Future<void> updateGroupInfo({
    required String conversationId,
    String? name,
    String? description,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;

    if (updates.isNotEmpty) {
      await _firestore.collection('conversations').doc(conversationId).update(updates);
    }
  }

  // ============================================================================
  // ANONYMOUS REPORTS
  // ============================================================================

  /// Create anonymous report
  Future<String> createAnonymousReport({
    required String content,
    required String category,
    String? location,
  }) async {
    // Get admin users
    final adminsSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    final adminIds = adminsSnapshot.docs.map((doc) => doc.id).toList();

    if (adminIds.isEmpty) {
      throw Exception('No admins available to receive report');
    }

    // Create anonymous conversation
    final conversationId = await createConversation(
      participantIds: adminIds,
      type: ConversationType.anonymous,
      name: 'Anonymous Report - $category',
      description: 'Anonymous report submitted',
    );

    // Send initial report message
    await sendMessage(
      conversationId: conversationId,
      content: content,
      type: MessageType.text,
      metadata: {
        'category': category,
        'location': location,
        'anonymous': true,
      },
    );

    return conversationId;
  }

  // ============================================================================
  // EMERGENCY BROADCASTS
  // ============================================================================

  /// Send emergency broadcast
  Future<void> sendEmergencyBroadcast({
    required String message,
    required String category,
    List<String>? targetUserIds,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    // Verify user is admin
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final userRole = userDoc.data()?['role'];

    if (userRole != 'admin' && userRole != 'coordinator') {
      throw Exception('Only admins and coordinators can send emergency broadcasts');
    }

    // Get target users (all users if not specified)
    List<String> recipients = targetUserIds ?? [];
    if (recipients.isEmpty) {
      final usersSnapshot = await _firestore.collection('users').get();
      recipients = usersSnapshot.docs.map((doc) => doc.id).toList();
    }

    // Create broadcast conversation
    final conversationId = await createConversation(
      participantIds: recipients,
      type: ConversationType.group,
      name: '🚨 Emergency Alert',
      description: 'Emergency broadcast message',
    );

    // Send broadcast message
    await sendMessage(
      conversationId: conversationId,
      content: message,
      type: MessageType.text,
      metadata: {
        'emergency': true,
        'category': category,
        'broadcastedBy': currentUserId,
      },
    );
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  /// Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    // Delete all messages
    final messagesSnapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .get();

    for (var doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete conversation
    await _firestore.collection('conversations').doc(conversationId).delete();
  }

  /// Archive conversation
  Future<void> archiveConversation(String conversationId) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'archived': true,
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get unread message count
  Future<int> getUnreadCount() async {
    if (currentUserId == null) return 0;

    final snapshot = await _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: currentUserId)
        .get();

    int totalUnread = 0;
    for (var doc in snapshot.docs) {
      final unreadCounts = doc.data()['unreadCounts'] as Map<String, dynamic>?;
      totalUnread += (unreadCounts?[currentUserId] as int?) ?? 0;
    }

    return totalUnread;
  }
}
