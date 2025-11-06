// Advanced Messaging Service - Premium Features for TALOWA
// Implements top-tier communication features for professional use

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../../models/messaging/message_model.dart';
import '../auth_service.dart';
import 'simple_messaging_service.dart';

class AdvancedMessagingService {
  static final AdvancedMessagingService _instance = AdvancedMessagingService._internal();
  factory AdvancedMessagingService() => _instance;
  AdvancedMessagingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SimpleMessagingService _simpleMessaging = SimpleMessagingService();
  
  // Encryption setup
  late final encrypt.Encrypter _encrypter;
  late final encrypt.Key _encryptionKey;
  
  // AI Translation cache
  final Map<String, String> _translationCache = {};
  
  // Smart replies cache
  final Map<String, List<String>> _smartRepliesCache = {};

  /// Initialize advanced messaging features
  Future<void> initialize() async {
    try {
      // Initialize encryption
      _encryptionKey = encrypt.Key.fromSecureRandom(32);
      _encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      
      debugPrint('Advanced Messaging Service initialized');
    } catch (e) {
      debugPrint('Error initializing advanced messaging: $e');
    }
  }

  // ==================== ADVANCED SEARCH ====================

  /// Advanced message search with filters
  Future<List<MessageModel>> searchMessages({
    required String query,
    List<String>? conversationIds,
    List<MessageType>? messageTypes,
    DateTime? startDate,
    DateTime? endDate,
    String? senderId,
    bool includeDeleted = false,
  }) async {
    try {
      Query messagesQuery = _firestore.collection('messages');

      // Apply filters
      if (conversationIds != null && conversationIds.isNotEmpty) {
        messagesQuery = messagesQuery.where('conversationId', whereIn: conversationIds);
      }

      if (messageTypes != null && messageTypes.isNotEmpty) {
        final typeStrings = messageTypes.map((type) => type.value).toList();
        messagesQuery = messagesQuery.where('messageType', whereIn: typeStrings);
      }

      if (senderId != null) {
        messagesQuery = messagesQuery.where('senderId', isEqualTo: senderId);
      }

      if (startDate != null) {
        messagesQuery = messagesQuery.where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        messagesQuery = messagesQuery.where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      if (!includeDeleted) {
        messagesQuery = messagesQuery.where('isDeleted', isEqualTo: false);
      }

      final snapshot = await messagesQuery.limit(100).get();
      final messages = snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      // Perform local text search
      if (query.isNotEmpty) {
        return messages.where((message) =>
            message.content.toLowerCase().contains(query.toLowerCase()) ||
            message.senderName.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }

      return messages;
    } catch (e) {
      debugPrint('Error searching messages: $e');
      return [];
    }
  }

  /// Smart search with AI-powered content understanding
  Future<List<MessageModel>> smartSearch(String query) async {
    try {
      // Extract search intent and entities
      final searchIntent = await _analyzeSearchIntent(query);
      
      // Perform targeted search based on intent
      switch (searchIntent.type) {
        case SearchIntentType.dateRange:
          return await searchMessages(
            query: searchIntent.keywords.join(' '),
            startDate: searchIntent.startDate,
            endDate: searchIntent.endDate,
          );
        
        case SearchIntentType.person:
          return await searchMessages(
            query: searchIntent.keywords.join(' '),
            senderId: searchIntent.personId,
          );
        
        case SearchIntentType.mediaType:
          return await searchMessages(
            query: searchIntent.keywords.join(' '),
            messageTypes: searchIntent.messageTypes,
          );
        
        default:
          return await searchMessages(query: query);
      }
    } catch (e) {
      debugPrint('Error in smart search: $e');
      return await searchMessages(query: query);
    }
  }

  /// Get search suggestions based on query
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      if (query.length < 2) return [];

      // Get recent conversations for suggestions
      final conversations = await _simpleMessaging.searchConversations(query);
      final suggestions = <String>[];

      // Add conversation names
      for (final conversation in conversations.take(5)) {
        suggestions.add(conversation.name);
      }

      // Add common search patterns
      suggestions.addAll([
        'messages from $query',
        'images from $query',
        'documents from $query',
        'messages today',
        'messages this week',
      ]);

      return suggestions.take(10).toList();
    } catch (e) {
      debugPrint('Error getting search suggestions: $e');
      return [];
    }
  }

  // ==================== AI FEATURES ====================

  /// Translate message to target language
  Future<String> translateMessage(String content, String targetLanguage) async {
    try {
      final cacheKey = '${content.hashCode}_$targetLanguage';
      
      // Check cache first
      if (_translationCache.containsKey(cacheKey)) {
        return _translationCache[cacheKey]!;
      }

      // Simulate AI translation (replace with actual AI service)
      final translatedContent = await _performTranslation(content, targetLanguage);
      
      // Cache the result
      _translationCache[cacheKey] = translatedContent;
      
      return translatedContent;
    } catch (e) {
      debugPrint('Error translating message: $e');
      return content; // Return original content on error
    }
  }

  /// Generate smart reply suggestions
  Future<List<String>> generateSmartReplies(String messageContent, {String? conversationContext}) async {
    try {
      final cacheKey = messageContent.hashCode.toString();
      
      // Check cache first
      if (_smartRepliesCache.containsKey(cacheKey)) {
        return _smartRepliesCache[cacheKey]!;
      }

      // Generate context-aware replies
      final replies = await _generateContextualReplies(messageContent, conversationContext);
      
      // Cache the results
      _smartRepliesCache[cacheKey] = replies;
      
      return replies;
    } catch (e) {
      debugPrint('Error generating smart replies: $e');
      return _getDefaultReplies();
    }
  }

  /// Analyze message sentiment
  Future<MessageSentiment> analyzeSentiment(String content) async {
    try {
      // Simulate sentiment analysis (replace with actual AI service)
      final sentiment = await _performSentimentAnalysis(content);
      return sentiment;
    } catch (e) {
      debugPrint('Error analyzing sentiment: $e');
      return MessageSentiment.neutral;
    }
  }

  /// Extract topics from message
  Future<List<String>> extractTopics(String content) async {
    try {
      // Simulate topic extraction (replace with actual AI service)
      return await _performTopicExtraction(content);
    } catch (e) {
      debugPrint('Error extracting topics: $e');
      return [];
    }
  }

  // ==================== SECURITY FEATURES ====================

  /// Encrypt message content
  Future<String> encryptMessage(String content) async {
    try {
      final encrypted = _encrypter.encrypt(content);
      return encrypted.base64;
    } catch (e) {
      debugPrint('Error encrypting message: $e');
      return content; // Return original content on error
    }
  }

  /// Decrypt message content
  Future<String> decryptMessage(String encryptedContent) async {
    try {
      final encrypted = encrypt.Encrypted.fromBase64(encryptedContent);
      return _encrypter.decrypt(encrypted);
    } catch (e) {
      debugPrint('Error decrypting message: $e');
      return encryptedContent; // Return encrypted content on error
    }
  }

  /// Generate message signature for verification
  Future<String> generateMessageSignature(String content, String senderId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final dataToSign = '$content|$senderId|$timestamp';
      final bytes = utf8.encode(dataToSign);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      debugPrint('Error generating message signature: $e');
      return '';
    }
  }

  /// Verify message signature
  Future<bool> verifyMessageSignature(String content, String senderId, String signature, String timestamp) async {
    try {
      final dataToVerify = '$content|$senderId|$timestamp';
      final bytes = utf8.encode(dataToVerify);
      final digest = sha256.convert(bytes);
      return digest.toString() == signature;
    } catch (e) {
      debugPrint('Error verifying message signature: $e');
      return false;
    }
  }

  // ==================== VOICE & VIDEO FEATURES ====================

  /// Initiate voice call
  Future<CallSession?> initiateVoiceCall(String conversationId, List<String> participantIds) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return null;

      final callSession = CallSession(
        id: _firestore.collection('calls').doc().id,
        conversationId: conversationId,
        initiatorId: currentUser.uid,
        participantIds: participantIds,
        callType: CallType.voice,
        status: CallStatus.initiating,
        startedAt: DateTime.now(),
      );

      // Store call session in Firestore
      await _firestore.collection('calls').doc(callSession.id).set(callSession.toMap());

      // Send call notification to participants
      await _sendCallNotification(callSession);

      return callSession;
    } catch (e) {
      debugPrint('Error initiating voice call: $e');
      return null;
    }
  }

  /// Initiate video call
  Future<CallSession?> initiateVideoCall(String conversationId, List<String> participantIds) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return null;

      final callSession = CallSession(
        id: _firestore.collection('calls').doc().id,
        conversationId: conversationId,
        initiatorId: currentUser.uid,
        participantIds: participantIds,
        callType: CallType.video,
        status: CallStatus.initiating,
        startedAt: DateTime.now(),
      );

      // Store call session in Firestore
      await _firestore.collection('calls').doc(callSession.id).set(callSession.toMap());

      // Send call notification to participants
      await _sendCallNotification(callSession);

      return callSession;
    } catch (e) {
      debugPrint('Error initiating video call: $e');
      return null;
    }
  }

  /// Answer incoming call
  Future<bool> answerCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.active.name,
        'answeredAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error answering call: $e');
      return false;
    }
  }

  /// End call
  Future<bool> endCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error ending call: $e');
      return false;
    }
  }

  // ==================== MESSAGE SCHEDULING ====================

  /// Schedule message for future delivery
  Future<String?> scheduleMessage({
    required String conversationId,
    required String content,
    required DateTime scheduledAt,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return null;

      final scheduledMessage = ScheduledMessage(
        id: _firestore.collection('scheduled_messages').doc().id,
        conversationId: conversationId,
        senderId: currentUser.uid,
        content: content,
        messageType: messageType,
        mediaUrls: mediaUrls ?? [],
        scheduledAt: scheduledAt,
        status: ScheduledMessageStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('scheduled_messages')
          .doc(scheduledMessage.id)
          .set(scheduledMessage.toMap());

      return scheduledMessage.id;
    } catch (e) {
      debugPrint('Error scheduling message: $e');
      return null;
    }
  }

  /// Get scheduled messages for user
  Future<List<ScheduledMessage>> getScheduledMessages() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('scheduled_messages')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: ScheduledMessageStatus.pending.name)
          .orderBy('scheduledAt')
          .get();

      return snapshot.docs
          .map((doc) => ScheduledMessage.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting scheduled messages: $e');
      return [];
    }
  }

  /// Cancel scheduled message
  Future<bool> cancelScheduledMessage(String messageId) async {
    try {
      await _firestore.collection('scheduled_messages').doc(messageId).update({
        'status': ScheduledMessageStatus.cancelled.name,
      });
      return true;
    } catch (e) {
      debugPrint('Error cancelling scheduled message: $e');
      return false;
    }
  }

  // ==================== ANALYTICS ====================

  /// Get conversation analytics
  Future<ConversationAnalytics> getConversationAnalytics(String conversationId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .get();

      final messages = messagesSnapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      return ConversationAnalytics.fromMessages(messages);
    } catch (e) {
      debugPrint('Error getting conversation analytics: $e');
      return ConversationAnalytics.empty();
    }
  }

  /// Get user messaging statistics
  Future<UserMessagingStats> getUserMessagingStats() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return UserMessagingStats.empty();

      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: currentUser.uid)
          .get();

      final messages = messagesSnapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      return UserMessagingStats.fromMessages(messages);
    } catch (e) {
      debugPrint('Error getting user messaging stats: $e');
      return UserMessagingStats.empty();
    }
  }

  // ==================== PRIVATE HELPER METHODS ====================

  Future<SearchIntent> _analyzeSearchIntent(String query) async {
    // Simulate AI-powered search intent analysis
    // In production, this would use NLP services
    
    final lowercaseQuery = query.toLowerCase();
    final words = lowercaseQuery.split(' ');

    // Date range detection
    if (words.any((word) => ['today', 'yesterday', 'week', 'month'].contains(word))) {
      return SearchIntent(
        type: SearchIntentType.dateRange,
        keywords: words.where((word) => !['today', 'yesterday', 'week', 'month'].contains(word)).toList(),
        startDate: _extractDateFromQuery(query),
      );
    }

    // Media type detection
    if (words.any((word) => ['image', 'photo', 'video', 'document', 'file'].contains(word))) {
      return SearchIntent(
        type: SearchIntentType.mediaType,
        keywords: words.where((word) => !['image', 'photo', 'video', 'document', 'file'].contains(word)).toList(),
        messageTypes: _extractMessageTypesFromQuery(query),
      );
    }

    // Person detection
    if (words.any((word) => ['from', 'by', 'sent'].contains(word))) {
      return SearchIntent(
        type: SearchIntentType.person,
        keywords: words,
        personId: await _extractPersonIdFromQuery(query),
      );
    }

    return SearchIntent(
      type: SearchIntentType.general,
      keywords: words,
    );
  }

  DateTime? _extractDateFromQuery(String query) {
    final now = DateTime.now();
    if (query.contains('today')) return now;
    if (query.contains('yesterday')) return now.subtract(const Duration(days: 1));
    if (query.contains('week')) return now.subtract(const Duration(days: 7));
    if (query.contains('month')) return now.subtract(const Duration(days: 30));
    return null;
  }

  List<MessageType> _extractMessageTypesFromQuery(String query) {
    final types = <MessageType>[];
    if (query.contains('image') || query.contains('photo')) types.add(MessageType.image);
    if (query.contains('video')) types.add(MessageType.video);
    if (query.contains('document') || query.contains('file')) types.add(MessageType.document);
    return types;
  }

  Future<String?> _extractPersonIdFromQuery(String query) async {
    // In production, this would search user database
    return null;
  }

  Future<String> _performTranslation(String content, String targetLanguage) async {
    // Simulate translation - replace with actual AI service
    await Future.delayed(const Duration(milliseconds: 500));
    return '[Translated to $targetLanguage] $content';
  }

  Future<List<String>> _generateContextualReplies(String messageContent, String? context) async {
    // Simulate AI reply generation - replace with actual AI service
    await Future.delayed(const Duration(milliseconds: 300));
    
    final replies = <String>[];
    
    // Context-aware replies based on message content
    if (messageContent.toLowerCase().contains('meeting')) {
      replies.addAll(['I will be there', 'What time?', 'Can we reschedule?']);
    } else if (messageContent.toLowerCase().contains('document')) {
      replies.addAll(['I will review it', 'Looks good', 'I have some questions']);
    } else if (messageContent.toLowerCase().contains('urgent')) {
      replies.addAll(['On it!', 'How can I help?', 'I will handle this']);
    } else {
      replies.addAll(_getDefaultReplies());
    }
    
    return replies.take(3).toList();
  }

  List<String> _getDefaultReplies() {
    return [
      'Thanks!',
      'Got it',
      'I will get back to you',
      'Sounds good',
      'Let me check',
    ];
  }

  Future<MessageSentiment> _performSentimentAnalysis(String content) async {
    // Simulate sentiment analysis - replace with actual AI service
    await Future.delayed(const Duration(milliseconds: 200));
    
    final positiveWords = ['good', 'great', 'excellent', 'happy', 'love', 'amazing'];
    final negativeWords = ['bad', 'terrible', 'hate', 'angry', 'frustrated', 'disappointed'];
    
    final lowercaseContent = content.toLowerCase();
    final positiveCount = positiveWords.where((word) => lowercaseContent.contains(word)).length;
    final negativeCount = negativeWords.where((word) => lowercaseContent.contains(word)).length;
    
    if (positiveCount > negativeCount) return MessageSentiment.positive;
    if (negativeCount > positiveCount) return MessageSentiment.negative;
    return MessageSentiment.neutral;
  }

  Future<List<String>> _performTopicExtraction(String content) async {
    // Simulate topic extraction - replace with actual AI service
    await Future.delayed(const Duration(milliseconds: 300));
    
    final topics = <String>[];
    final lowercaseContent = content.toLowerCase();
    
    if (lowercaseContent.contains('land') || lowercaseContent.contains('property')) {
      topics.add('Land Rights');
    }
    if (lowercaseContent.contains('legal') || lowercaseContent.contains('court')) {
      topics.add('Legal');
    }
    if (lowercaseContent.contains('meeting') || lowercaseContent.contains('schedule')) {
      topics.add('Meetings');
    }
    if (lowercaseContent.contains('document') || lowercaseContent.contains('file')) {
      topics.add('Documents');
    }
    
    return topics;
  }

  Future<void> _sendCallNotification(CallSession callSession) async {
    // Send push notifications to participants
    // Implementation would depend on your notification service
    debugPrint('Sending call notification for ${callSession.id}');
  }
}

// ==================== DATA MODELS ====================

class SearchIntent {
  final SearchIntentType type;
  final List<String> keywords;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? personId;
  final List<MessageType>? messageTypes;

  SearchIntent({
    required this.type,
    required this.keywords,
    this.startDate,
    this.endDate,
    this.personId,
    this.messageTypes,
  });
}

enum SearchIntentType {
  general,
  dateRange,
  person,
  mediaType,
}

enum MessageSentiment {
  positive,
  negative,
  neutral,
}

class CallSession {
  final String id;
  final String conversationId;
  final String initiatorId;
  final List<String> participantIds;
  final CallType callType;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  CallSession({
    required this.id,
    required this.conversationId,
    required this.initiatorId,
    required this.participantIds,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'initiatorId': initiatorId,
      'participantIds': participantIds,
      'callType': callType.name,
      'status': status.name,
      'startedAt': Timestamp.fromDate(startedAt),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }
}

enum CallType { voice, video }
enum CallStatus { initiating, ringing, active, ended, missed }

class ScheduledMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageType messageType;
  final List<String> mediaUrls;
  final DateTime scheduledAt;
  final ScheduledMessageStatus status;
  final DateTime createdAt;

  ScheduledMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.messageType,
    required this.mediaUrls,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
      'messageType': messageType.value,
      'mediaUrls': mediaUrls,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static ScheduledMessage fromMap(Map<String, dynamic> map) {
    return ScheduledMessage(
      id: map['id'],
      conversationId: map['conversationId'],
      senderId: map['senderId'],
      content: map['content'],
      messageType: MessageTypeExtension.fromString(map['messageType']),
      mediaUrls: List<String>.from(map['mediaUrls']),
      scheduledAt: (map['scheduledAt'] as Timestamp).toDate(),
      status: ScheduledMessageStatus.values.byName(map['status']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

enum ScheduledMessageStatus { pending, sent, cancelled }

class ConversationAnalytics {
  final int totalMessages;
  final int totalParticipants;
  final Map<String, int> messagesByType;
  final Map<String, int> messagesBySender;
  final double averageResponseTime;
  final List<String> topTopics;

  ConversationAnalytics({
    required this.totalMessages,
    required this.totalParticipants,
    required this.messagesByType,
    required this.messagesBySender,
    required this.averageResponseTime,
    required this.topTopics,
  });

  static ConversationAnalytics fromMessages(List<MessageModel> messages) {
    final messagesByType = <String, int>{};
    final messagesBySender = <String, int>{};
    final senderIds = <String>{};

    for (final message in messages) {
      messagesByType[message.messageType.value] = 
          (messagesByType[message.messageType.value] ?? 0) + 1;
      messagesBySender[message.senderName] = 
          (messagesBySender[message.senderName] ?? 0) + 1;
      senderIds.add(message.senderId);
    }

    return ConversationAnalytics(
      totalMessages: messages.length,
      totalParticipants: senderIds.length,
      messagesByType: messagesByType,
      messagesBySender: messagesBySender,
      averageResponseTime: 0.0, // Calculate based on message timestamps
      topTopics: [], // Extract from message content
    );
  }

  static ConversationAnalytics empty() {
    return ConversationAnalytics(
      totalMessages: 0,
      totalParticipants: 0,
      messagesByType: {},
      messagesBySender: {},
      averageResponseTime: 0.0,
      topTopics: [],
    );
  }
}

class UserMessagingStats {
  final int totalMessagesSent;
  final int totalConversations;
  final Map<String, int> messagesByType;
  final double averageMessagesPerDay;
  final List<String> favoriteContacts;

  UserMessagingStats({
    required this.totalMessagesSent,
    required this.totalConversations,
    required this.messagesByType,
    required this.averageMessagesPerDay,
    required this.favoriteContacts,
  });

  static UserMessagingStats fromMessages(List<MessageModel> messages) {
    final messagesByType = <String, int>{};
    final conversationIds = <String>{};

    for (final message in messages) {
      messagesByType[message.messageType.value] = 
          (messagesByType[message.messageType.value] ?? 0) + 1;
      conversationIds.add(message.conversationId);
    }

    return UserMessagingStats(
      totalMessagesSent: messages.length,
      totalConversations: conversationIds.length,
      messagesByType: messagesByType,
      averageMessagesPerDay: 0.0, // Calculate based on date range
      favoriteContacts: [], // Calculate based on message frequency
    );
  }

  static UserMessagingStats empty() {
    return UserMessagingStats(
      totalMessagesSent: 0,
      totalConversations: 0,
      messagesByType: {},
      averageMessagesPerDay: 0.0,
      favoriteContacts: [],
    );
  }
}