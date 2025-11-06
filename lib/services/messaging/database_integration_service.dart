// Database Integration Service for TALOWA Messaging System
// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/voice_call_model.dart';

class DatabaseIntegrationService {
  static final DatabaseIntegrationService _instance = DatabaseIntegrationService._internal();
  factory DatabaseIntegrationService() => _instance;
  DatabaseIntegrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize database integration service
  Future<void> initialize() async {
    try {
      debugPrint('DatabaseIntegrationService: Initializing');
      await _setupCollections();
      debugPrint('DatabaseIntegrationService: Initialized successfully');
    } catch (e) {
      debugPrint('DatabaseIntegrationService: Error initializing: $e');
    }
  }

  /// Store message in database
  Future<String> storeMessage(MessageModel message) async {
    try {
      final docRef = await _firestore
          .collection('messages')
          .add(message.toFirestore());

      debugPrint('DatabaseIntegrationService: Message stored with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('DatabaseIntegrationService: Error storing message: $e');
      rethrow;
    }
  }

  /// Get message history with pagination
  Future<List<MessageModel>> getMessageHistory({
    required String conversationId,
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .get();

      final messages = querySnapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      debugPrint('DatabaseIntegrationService: Retrieved ${messages.length} messages');
      return messages;
    } catch (e) {
      debugPrint('DatabaseIntegrationService: Error getting message history: $e');
      return [];
    }
  }

  /// Stream message updates
  Stream<List<MessageModel>> getMessageStream({
    required String conversationId,
    int limit = 50,
  }) {
    try {
      return _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => MessageModel.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      debugPrint('DatabaseIntegrationService: Error creating message stream: $e');
      return Stream.value([]);
    }
  }

  /// Store conversation
  Future<String> storeConversation(ConversationModel conversation) async {
    try {
      final docRef = await _firestore
          .collection('conversations')
          .add(conversation.toFirestore());

      debugPrint('DatabaseIntegrationService: Conversation stored with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('DatabaseIntegrationService: Error storing conversation: $e');
      rethrow;
    }
  }

  /// Get user conversations
  Future<List<ConversationModel>> getUserConversations({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('lastMessageAt', descending: true)
          .limit(limit)
          .get();

      final conversations = querySnapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();

      debugPrint('DatabaseIntegrationService: Retrieved ${conversations.length} conversations');
      return conversations;
    } catch (e) {
      debugPrint('DatabaseIntegrationService: Error getting conversations: $e');
      return [];
    }
  }

  /// Store voice call record
  Future<String> storeVoiceCall(VoiceCallModel voiceCall) async {
    try {
      final docRef = await _firestore
          .collection('voice_calls')
          .add(voiceCall.toFirestore());

      debugPrint('DatabaseIntegrationService: Voice call stored with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('DatabaseIntegrationService: Error storing voice call: $e');
      rethrow;
    }
  }

  /// Setup required collections
  Future<void> _setupCollections() async {
    try {
      await _createMessagesCollection();
      await _createConversationsCollection();
      await _createVoiceCallsCollection();
    } catch (e) {
      debugPrint('DatabaseIntegrationService: Error setting up collections: $e');
    }
  }

  /// Create messages collection
  Future<void> _createMessagesCollection() async {
    try {
      final existing = await _firestore.collection('messages').limit(1).get();
      if (existing.docs.isNotEmpty) return;

      await _firestore.collection('messages').doc('sample').set({
        'conversationId': 'sample',
        'senderId': 'system',
        'senderName': 'System',
        'content': 'Welcome to TALOWA messaging!',
        'messageType': 'system',
        'mediaUrls': [],
        'sentAt': FieldValue.serverTimestamp(),
        'readBy': [],
        'isEdited': false,
        'isDeleted': false,
        'metadata': {},
      });
    } catch (e) {
      debugPrint('Error creating messages collection: $e');
    }
  }

  /// Create conversations collection
  Future<void> _createConversationsCollection() async {
    try {
      final existing = await _firestore.collection('conversations').limit(1).get();
      if (existing.docs.isNotEmpty) return;

      await _firestore.collection('conversations').doc('sample').set({
        'name': 'System',
        'type': 'direct',
        'participantIds': ['system'],
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Welcome!',
        'lastMessageSenderId': 'system',
        'unreadCounts': {},
        'isActive': true,
        'metadata': {},
      });
    } catch (e) {
      debugPrint('Error creating conversations collection: $e');
    }
  }

  /// Create voice calls collection
  Future<void> _createVoiceCallsCollection() async {
    try {
      final existing = await _firestore.collection('voice_calls').limit(1).get();
      if (existing.docs.isNotEmpty) return;

      await _firestore.collection('voice_calls').doc('sample').set({
        'type': 'voice',
        'status': 'ended',
        'callerId': 'system',
        'recipientId': 'sample',
        'participants': {},
        'initiatedAt': FieldValue.serverTimestamp(),
        'signaling': {
          'serverId': 'sample',
          'roomId': 'sample',
          'turnServersUsed': [],
        },
        'isEncrypted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating voice calls collection: $e');
    }
  }
}