// Communication Service for TALOWA
// Integrates messaging, encryption, caching, and voice calls
// Requirements: 1.6, 7.2, 7.3

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/voice_call_model.dart';
import '../../models/messaging/anonymous_message_model.dart';
import '../auth_service.dart';
import 'encryption_service.dart';
import 'redis_cache_service.dart';

class CommunicationService {
  static final CommunicationService _instance = CommunicationService._internal();
  factory CommunicationService() => _instance;
  CommunicationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final RedisCacheService _cacheService = RedisCacheService();

  // Collections
  final String _conversationsCollection = 'conversations';
  final String _messagesCollection = 'messages';
  final String _voiceCallsCollection = 'voice_calls';
  final String _anonymousMessagesCollection = 'anonymous_messages';

  /// Initialize the communication service
  Future<void> initialize() async {
    try {
      await _cacheService.initialize();
      await _encryptionService.initializeUserEncryption();
      
      // Set user presence as online
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        await _cacheService.setUserPresence(
          userId: currentUser.uid,
          status: PresenceStatus.online,
        );
      }
      
      debugPrint('Communication service initialized');
    } catch (e) {
      debugPrint('Error initializing communication service: $e');
      rethrow;
    }
  }

  /// Send encrypted message
  Future<String> sendEncryptedMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
    EncryptionLevel encryptionLevel = EncryptionLevel.standard,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get conversation to determine participants
      final conversation = await getConversation(conversationId);
      if (conversation == null) {
        throw Exception('Conversation not found');
      }

      // Get user profile for sender info
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final messageId = _firestore.collection(_messagesCollection).doc().id;

      String encryptedContent = content;
      Map<String, dynamic> encryptionData = {};

      // Encrypt message if required
      if (encryptionLevel != EncryptionLevel.none) {
        if (conversation.type == ConversationType.direct) {
          // Direct message encryption
          final recipientId = conversation.participantIds
              .firstWhere((id) => id != currentUser.uid);
          
          final encrypted = await _encryptionService.encryptMessage(
            content: content,
            recipientUserId: recipientId,
            level: encryptionLevel,
          );
          
          encryptedContent = encrypted.data;
          encryptionData = encrypted.toMap();
        } else {
          // Group message encryption
          final encrypted = await _encryptionService.encryptGroupMessage(
            content: content,
            groupId: conversationId,
            participantIds: conversation.participantIds,
            level: encryptionLevel,
          );
          
          encryptedContent = encrypted.data;
          encryptionData = encrypted.toMap();
        }
      }

      final message = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderName: userData['fullName'] ?? 'Unknown User',
        content: encryptedContent,
        messageType: messageType,
        mediaUrls: mediaUrls ?? [],
        sentAt: DateTime.now(),
        deliveredAt: null,
        readAt: null,
        readBy: [],
        isEdited: false,
        isDeleted: false,
        metadata: {
          ...metadata ?? {},
          'encryptionLevel': encryptionLevel.value,
          'encryptionData': encryptionData,
        },
      );

      // Save message to Firestore
      await _firestore
          .collection(_messagesCollection)
          .doc(messageId)
          .set(message.toFirestore());

      // Cache message for offline access
      await _cacheService.cacheMessage(
        messageId: messageId,
        messageData: message.toFirestore(),
      );

      // Update conversation with last message info
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: messageType == MessageType.text ? content : messageType.displayName,
        lastMessageSenderId: currentUser.uid,
        lastMessageAt: DateTime.now(),
      );

      debugPrint('Encrypted message sent successfully: $messageId');
      return messageId;
    } catch (e) {
      debugPrint('Error sending encrypted message: $e');
      rethrow;
    }
  }

  /// Get decrypted messages for a conversation
  Stream<List<MessageModel>> getDecryptedMessages({
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
          .asyncMap((snapshot) async {
        final messages = <MessageModel>[];
        
        for (final doc in snapshot.docs) {
          final message = MessageModel.fromFirestore(doc);
          
          // Decrypt message if encrypted
          if (message.metadata.containsKey('encryptionData')) {
            try {
              final encryptionData = message.metadata['encryptionData'] as Map<String, dynamic>;
              final encryptedContent = EncryptedContent.fromMap(encryptionData);
              final decryptedContent = await _encryptionService.decryptMessage(encryptedContent);
              
              messages.add(message.copyWith(content: decryptedContent));
            } catch (e) {
              debugPrint('Error decrypting message ${message.id}: $e');
              // Add message with encrypted content if decryption fails
              messages.add(message.copyWith(content: '[Encrypted Message]'));
            }
          } else {
            messages.add(message);
          }
        }
        
        return messages;
      });
    } catch (e) {
      debugPrint('Error getting decrypted messages: $e');
      return Stream.value([]);
    }
  }

  /// Send anonymous message
  Future<String> sendAnonymousMessage({
    required String content,
    required AnonymousMessageType messageType,
    required String coordinatorId,
    required GeographicScope scope,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Encrypt message for anonymous routing
      final encrypted = await _encryptionService.encryptAnonymousMessage(
        content: content,
        coordinatorId: coordinatorId,
      );

      // Generate unique case ID
      final caseId = _generateAnonymousCaseId();
      final messageId = _firestore.collection(_anonymousMessagesCollection).doc().id;

      final anonymousMessage = AnonymousMessageModel(
        id: messageId,
        caseId: caseId,
        coordinatorId: coordinatorId,
        encryptedContent: encrypted.data,
        messageType: messageType,
        status: AnonymousMessageStatus.pending,
        scope: scope,
        mediaUrls: mediaUrls ?? [],
        createdAt: DateTime.now(),
        metadata: {
          ...metadata ?? {},
          'encryptionData': encrypted.toMap(),
        },
      );

      await _firestore
          .collection(_anonymousMessagesCollection)
          .doc(messageId)
          .set(anonymousMessage.toFirestore());

      debugPrint('Anonymous message sent successfully: $messageId (Case: $caseId)');
      return caseId;
    } catch (e) {
      debugPrint('Error sending anonymous message: $e');
      rethrow;
    }
  }

  /// Initiate voice call
  Future<String> initiateVoiceCall({
    required String recipientId,
    CallType type = CallType.voice,
    String? linkedCaseId,
    String? linkedCampaignId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user profiles
      final callerDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();

      if (!callerDoc.exists || !recipientDoc.exists) {
        throw Exception('User profiles not found');
      }

      final callerData = callerDoc.data()!;
      final recipientData = recipientDoc.data()!;

      final callId = _firestore.collection(_voiceCallsCollection).doc().id;
      final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}';

      final voiceCall = VoiceCallModel(
        id: callId,
        type: type,
        status: CallStatus.initiated,
        callerId: currentUser.uid,
        recipientId: recipientId,
        participants: {
          currentUser.uid: CallParticipant(
            userId: currentUser.uid,
            name: callerData['fullName'] ?? 'Unknown',
            role: callerData['role'] ?? 'member',
            connectionQuality: ConnectionQuality.good,
            isMuted: false,
            isSpeakerOn: false,
          ),
          recipientId: CallParticipant(
            userId: recipientId,
            name: recipientData['fullName'] ?? 'Unknown',
            role: recipientData['role'] ?? 'member',
            connectionQuality: ConnectionQuality.good,
            isMuted: false,
            isSpeakerOn: false,
          ),
        },
        initiatedAt: DateTime.now(),
        signaling: SignalingInfo(
          serverId: 'server_1',
          roomId: roomId,
          turnServersUsed: [],
        ),
        isEncrypted: true,
        encryptionProtocol: 'DTLS-SRTP',
        linkedCaseId: linkedCaseId,
        linkedCampaignId: linkedCampaignId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_voiceCallsCollection)
          .doc(callId)
          .set(voiceCall.toFirestore());

      debugPrint('Voice call initiated: $callId');
      return callId;
    } catch (e) {
      debugPrint('Error initiating voice call: $e');
      rethrow;
    }
  }

  /// Update user presence
  Future<void> updatePresence({
    required PresenceStatus status,
    String? customMessage,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      await _cacheService.setUserPresence(
        userId: currentUser.uid,
        status: status,
        customMessage: customMessage,
      );
    } catch (e) {
      debugPrint('Error updating presence: $e');
    }
  }

  /// Get user presence
  Future<UserPresence?> getUserPresence(String userId) async {
    return await _cacheService.getUserPresence(userId);
  }

  /// Subscribe to presence updates
  Stream<PresenceUpdate> subscribeToPresenceUpdates(List<String> userIds) {
    return _cacheService.subscribeToPresenceUpdates(userIds);
  }

  /// Get conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      // Try cache first
      final cachedData = await _cacheService.getCachedConversation(conversationId);
      if (cachedData != null) {
        return ConversationModel.fromFirestore(
          MockDocumentSnapshot(conversationId, cachedData),
        );
      }

      // Fetch from Firestore
      final doc = await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .get();

      if (doc.exists) {
        final conversation = ConversationModel.fromFirestore(doc);
        
        // Cache for future use
        await _cacheService.cacheConversation(
          conversationId: conversationId,
          conversationData: doc.data()!,
        );
        
        return conversation;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      return null;
    }
  }

  /// Set typing indicator
  Future<void> setTypingIndicator({
    required String conversationId,
    required bool isTyping,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      await _cacheService.setTypingIndicator(
        conversationId: conversationId,
        userId: currentUser.uid,
        isTyping: isTyping,
      );
    } catch (e) {
      debugPrint('Error setting typing indicator: $e');
    }
  }

  /// Get typing users in conversation
  Future<List<String>> getTypingUsers(String conversationId) async {
    return await _cacheService.getTypingUsers(conversationId);
  }

  /// Cleanup on logout
  Future<void> cleanup() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        // Set presence to offline
        await _cacheService.setUserPresence(
          userId: currentUser.uid,
          status: PresenceStatus.offline,
        );
      }

      // Clear encryption cache
      _encryptionService.clearCache();
      
      // Clear cache service
      await _cacheService.clearCache();
      
      debugPrint('Communication service cleaned up');
    } catch (e) {
      debugPrint('Error cleaning up communication service: $e');
    }
  }

  /// Private helper methods
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

  String _generateAnonymousCaseId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'ANON-${timestamp.toString().substring(8)}-$random';
  }
}

/// Mock DocumentSnapshot for cache integration
class MockDocumentSnapshot implements DocumentSnapshot {
  final String _id;
  final Map<String, dynamic> _data;

  MockDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data.isNotEmpty;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}