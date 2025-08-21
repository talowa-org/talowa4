// Redis Cache Service for TALOWA Messaging
// Handles session management and presence tracking
// Requirements: 1.6, 7.2, 7.3

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Redis Cache Service for session management and presence tracking
/// Enhanced for performance optimization with message and user data caching
/// Note: This is a local implementation using SharedPreferences
/// In production, this would connect to actual Redis server
class RedisCacheService {
  static final RedisCacheService _instance = RedisCacheService._internal();
  factory RedisCacheService() => _instance;
  RedisCacheService._internal();

  SharedPreferences? _prefs;
  final Map<String, Timer> _expirationTimers = {};
  final Map<String, StreamController<PresenceUpdate>> _presenceControllers = {};
  
  // Enhanced caching for performance optimization
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, List<dynamic>> _paginatedCache = {};
  
  // Cache configuration
  static const Duration defaultCacheExpiration = Duration(hours: 1);
  static const Duration messageCacheExpiration = Duration(hours: 6);
  static const Duration userDataCacheExpiration = Duration(hours: 2);
  static const int maxCacheSize = 100; // Maximum number of cached items
  static const int messagePaginationSize = 50;

  /// Initialize the cache service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('Redis cache service initialized');
    } catch (e) {
      debugPrint('Error initializing Redis cache service: $e');
      rethrow;
    }
  }

  /// Set user session data
  Future<void> setUserSession({
    required String userId,
    required UserSession session,
    Duration? expiration,
  }) async {
    try {
      await _ensureInitialized();
      
      final key = 'session:$userId';
      final sessionData = jsonEncode(session.toMap());
      
      await _prefs!.setString(key, sessionData);
      
      // Set expiration if provided
      if (expiration != null) {
        _setExpiration(key, expiration);
      }
      
      debugPrint('User session set for: $userId');
    } catch (e) {
      debugPrint('Error setting user session: $e');
    }
  }

  /// Get user session data
  Future<UserSession?> getUserSession(String userId) async {
    try {
      await _ensureInitialized();
      
      final key = 'session:$userId';
      final sessionData = _prefs!.getString(key);
      
      if (sessionData == null) return null;
      
      final sessionMap = jsonDecode(sessionData) as Map<String, dynamic>;
      return UserSession.fromMap(sessionMap);
    } catch (e) {
      debugPrint('Error getting user session: $e');
      return null;
    }
  }

  /// Remove user session
  Future<void> removeUserSession(String userId) async {
    try {
      await _ensureInitialized();
      
      final key = 'session:$userId';
      await _prefs!.remove(key);
      _cancelExpiration(key);
      
      debugPrint('User session removed for: $userId');
    } catch (e) {
      debugPrint('Error removing user session: $e');
    }
  }

  /// Set user presence status
  Future<void> setUserPresence({
    required String userId,
    required PresenceStatus status,
    String? customMessage,
    DateTime? lastSeen,
  }) async {
    try {
      await _ensureInitialized();
      
      final presence = UserPresence(
        userId: userId,
        status: status,
        customMessage: customMessage,
        lastSeen: lastSeen ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final key = 'presence:$userId';
      final presenceData = jsonEncode(presence.toMap());
      
      await _prefs!.setString(key, presenceData);
      
      // Notify presence subscribers
      _notifyPresenceUpdate(PresenceUpdate(
        userId: userId,
        status: status,
        customMessage: customMessage,
        timestamp: DateTime.now(),
      ));
      
      debugPrint('User presence set for $userId: ${status.value}');
    } catch (e) {
      debugPrint('Error setting user presence: $e');
    }
  }

  /// Get user presence status
  Future<UserPresence?> getUserPresence(String userId) async {
    try {
      await _ensureInitialized();
      
      final key = 'presence:$userId';
      final presenceData = _prefs!.getString(key);
      
      if (presenceData == null) return null;
      
      final presenceMap = jsonDecode(presenceData) as Map<String, dynamic>;
      return UserPresence.fromMap(presenceMap);
    } catch (e) {
      debugPrint('Error getting user presence: $e');
      return null;
    }
  }

  /// Get multiple user presences
  Future<Map<String, UserPresence>> getMultipleUserPresences(List<String> userIds) async {
    final presences = <String, UserPresence>{};
    
    for (final userId in userIds) {
      final presence = await getUserPresence(userId);
      if (presence != null) {
        presences[userId] = presence;
      }
    }
    
    return presences;
  }

  /// Subscribe to presence updates for specific users
  Stream<PresenceUpdate> subscribeToPresenceUpdates(List<String> userIds) {
    final controller = StreamController<PresenceUpdate>.broadcast();
    
    for (final userId in userIds) {
      _presenceControllers[userId] = controller;
    }
    
    // Clean up when stream is cancelled
    controller.onCancel = () {
      for (final userId in userIds) {
        _presenceControllers.remove(userId);
      }
    };
    
    return controller.stream;
  }

  /// Cache message for offline delivery
  Future<void> cacheMessage({
    required String messageId,
    required Map<String, dynamic> messageData,
    Duration? expiration,
  }) async {
    try {
      await _ensureInitialized();
      
      final key = 'message:$messageId';
      final data = jsonEncode(messageData);
      
      await _prefs!.setString(key, data);
      
      // Set expiration (default 7 days for messages)
      _setExpiration(key, expiration ?? const Duration(days: 7));
      
      debugPrint('Message cached: $messageId');
    } catch (e) {
      debugPrint('Error caching message: $e');
    }
  }

  /// Get cached message
  Future<Map<String, dynamic>?> getCachedMessage(String messageId) async {
    try {
      await _ensureInitialized();
      
      final key = 'message:$messageId';
      final data = _prefs!.getString(key);
      
      if (data == null) return null;
      
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting cached message: $e');
      return null;
    }
  }

  /// Cache conversation metadata
  Future<void> cacheConversation({
    required String conversationId,
    required Map<String, dynamic> conversationData,
  }) async {
    try {
      await _ensureInitialized();
      
      final key = 'conversation:$conversationId';
      final data = jsonEncode(conversationData);
      
      await _prefs!.setString(key, data);
      
      debugPrint('Conversation cached: $conversationId');
    } catch (e) {
      debugPrint('Error caching conversation: $e');
    }
  }

  /// Get cached conversation
  Future<Map<String, dynamic>?> getCachedConversation(String conversationId) async {
    try {
      await _ensureInitialized();
      
      final key = 'conversation:$conversationId';
      final data = _prefs!.getString(key);
      
      if (data == null) return null;
      
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting cached conversation: $e');
      return null;
    }
  }

  /// Set typing indicator
  Future<void> setTypingIndicator({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      await _ensureInitialized();
      
      final key = 'typing:$conversationId:$userId';
      
      if (isTyping) {
        await _prefs!.setBool(key, true);
        // Auto-expire typing indicator after 5 seconds
        _setExpiration(key, const Duration(seconds: 5));
      } else {
        await _prefs!.remove(key);
        _cancelExpiration(key);
      }
      
      debugPrint('Typing indicator set for $userId in $conversationId: $isTyping');
    } catch (e) {
      debugPrint('Error setting typing indicator: $e');
    }
  }

  /// Get typing users in conversation
  Future<List<String>> getTypingUsers(String conversationId) async {
    try {
      await _ensureInitialized();
      
      final typingUsers = <String>[];
      final keys = _prefs!.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('typing:$conversationId:')) {
          final isTyping = _prefs!.getBool(key) ?? false;
          if (isTyping) {
            final userId = key.split(':').last;
            typingUsers.add(userId);
          }
        }
      }
      
      return typingUsers;
    } catch (e) {
      debugPrint('Error getting typing users: $e');
      return [];
    }
  }

  /// Cache frequently accessed messages with pagination support
  Future<void> cacheMessagesPaginated({
    required String conversationId,
    required List<Map<String, dynamic>> messages,
    required int page,
    int pageSize = messagePaginationSize,
  }) async {
    try {
      await _ensureInitialized();
      
      final cacheKey = 'messages_paginated:$conversationId:$page';
      final data = jsonEncode(messages);
      
      await _prefs!.setString(cacheKey, data);
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      // Also cache in memory for faster access
      _memoryCache[cacheKey] = messages;
      
      // Set expiration
      _setExpiration(cacheKey, messageCacheExpiration);
      
      debugPrint('Cached ${messages.length} messages for conversation $conversationId, page $page');
    } catch (e) {
      debugPrint('Error caching paginated messages: $e');
    }
  }

  /// Get cached messages for a specific page
  Future<List<Map<String, dynamic>>?> getCachedMessagesPaginated({
    required String conversationId,
    required int page,
  }) async {
    try {
      await _ensureInitialized();
      
      final cacheKey = 'messages_paginated:$conversationId:$page';
      
      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null && 
            DateTime.now().difference(timestamp) < messageCacheExpiration) {
          return List<Map<String, dynamic>>.from(_memoryCache[cacheKey]);
        }
      }
      
      // Check persistent cache
      final data = _prefs!.getString(cacheKey);
      if (data == null) return null;
      
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp == null || 
          DateTime.now().difference(timestamp) >= messageCacheExpiration) {
        await _prefs!.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
        return null;
      }
      
      final messages = List<Map<String, dynamic>>.from(jsonDecode(data));
      
      // Update memory cache
      _memoryCache[cacheKey] = messages;
      
      return messages;
    } catch (e) {
      debugPrint('Error getting cached paginated messages: $e');
      return null;
    }
  }

  /// Cache user data for quick access
  Future<void> cacheUserData({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    try {
      await _ensureInitialized();
      
      final cacheKey = 'user_data:$userId';
      final data = jsonEncode(userData);
      
      await _prefs!.setString(cacheKey, data);
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      // Cache in memory for faster access
      _memoryCache[cacheKey] = userData;
      
      // Set expiration
      _setExpiration(cacheKey, userDataCacheExpiration);
      
      debugPrint('User data cached for: $userId');
    } catch (e) {
      debugPrint('Error caching user data: $e');
    }
  }

  /// Get cached user data
  Future<Map<String, dynamic>?> getCachedUserData(String userId) async {
    try {
      await _ensureInitialized();
      
      final cacheKey = 'user_data:$userId';
      
      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null && 
            DateTime.now().difference(timestamp) < userDataCacheExpiration) {
          return Map<String, dynamic>.from(_memoryCache[cacheKey]);
        }
      }
      
      // Check persistent cache
      final data = _prefs!.getString(cacheKey);
      if (data == null) return null;
      
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp == null || 
          DateTime.now().difference(timestamp) >= userDataCacheExpiration) {
        await _prefs!.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
        return null;
      }
      
      final userData = Map<String, dynamic>.from(jsonDecode(data));
      
      // Update memory cache
      _memoryCache[cacheKey] = userData;
      
      return userData;
    } catch (e) {
      debugPrint('Error getting cached user data: $e');
      return null;
    }
  }

  /// Cache conversation list with metadata
  Future<void> cacheConversationList({
    required String userId,
    required List<Map<String, dynamic>> conversations,
  }) async {
    try {
      await _ensureInitialized();
      
      final cacheKey = 'conversation_list:$userId';
      final data = jsonEncode(conversations);
      
      await _prefs!.setString(cacheKey, data);
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      // Cache in memory
      _memoryCache[cacheKey] = conversations;
      
      // Set expiration
      _setExpiration(cacheKey, defaultCacheExpiration);
      
      debugPrint('Conversation list cached for user: $userId');
    } catch (e) {
      debugPrint('Error caching conversation list: $e');
    }
  }

  /// Get cached conversation list
  Future<List<Map<String, dynamic>>?> getCachedConversationList(String userId) async {
    try {
      await _ensureInitialized();
      
      final cacheKey = 'conversation_list:$userId';
      
      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null && 
            DateTime.now().difference(timestamp) < defaultCacheExpiration) {
          return List<Map<String, dynamic>>.from(_memoryCache[cacheKey]);
        }
      }
      
      // Check persistent cache
      final data = _prefs!.getString(cacheKey);
      if (data == null) return null;
      
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp == null || 
          DateTime.now().difference(timestamp) >= defaultCacheExpiration) {
        await _prefs!.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
        return null;
      }
      
      final conversations = List<Map<String, dynamic>>.from(jsonDecode(data));
      
      // Update memory cache
      _memoryCache[cacheKey] = conversations;
      
      return conversations;
    } catch (e) {
      debugPrint('Error getting cached conversation list: $e');
      return null;
    }
  }

  /// Cache group member list with pagination
  Future<void> cacheGroupMembers({
    required String groupId,
    required List<Map<String, dynamic>> members,
    required int page,
    int pageSize = 50,
  }) async {
    try {
      await _ensureInitialized();
      
      final cacheKey = 'group_members:$groupId:$page';
      final data = jsonEncode(members);
      
      await _prefs!.setString(cacheKey, data);
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      // Cache in memory
      _memoryCache[cacheKey] = members;
      
      // Set expiration
      _setExpiration(cacheKey, defaultCacheExpiration);
      
      debugPrint('Cached ${members.length} group members for group $groupId, page $page');
    } catch (e) {
      debugPrint('Error caching group members: $e');
    }
  }

  /// Get cached group members for a specific page
  Future<List<Map<String, dynamic>>?> getCachedGroupMembers({
    required String groupId,
    required int page,
  }) async {
    try {
      await _ensureInitialized();
      
      final cacheKey = 'group_members:$groupId:$page';
      
      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null && 
            DateTime.now().difference(timestamp) < defaultCacheExpiration) {
          return List<Map<String, dynamic>>.from(_memoryCache[cacheKey]);
        }
      }
      
      // Check persistent cache
      final data = _prefs!.getString(cacheKey);
      if (data == null) return null;
      
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp == null || 
          DateTime.now().difference(timestamp) >= defaultCacheExpiration) {
        await _prefs!.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
        return null;
      }
      
      final members = List<Map<String, dynamic>>.from(jsonDecode(data));
      
      // Update memory cache
      _memoryCache[cacheKey] = members;
      
      return members;
    } catch (e) {
      debugPrint('Error getting cached group members: $e');
      return null;
    }
  }

  /// Invalidate cache for specific conversation
  Future<void> invalidateConversationCache(String conversationId) async {
    try {
      await _ensureInitialized();
      
      final keysToRemove = <String>[];
      
      // Find all cache keys related to this conversation
      for (final key in _prefs!.getKeys()) {
        if (key.contains(conversationId)) {
          keysToRemove.add(key);
        }
      }
      
      // Remove from persistent cache
      for (final key in keysToRemove) {
        await _prefs!.remove(key);
        _cacheTimestamps.remove(key);
        _memoryCache.remove(key);
        _cancelExpiration(key);
      }
      
      debugPrint('Invalidated cache for conversation: $conversationId');
    } catch (e) {
      debugPrint('Error invalidating conversation cache: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return {
      'memory_cache_size': _memoryCache.length,
      'persistent_cache_size': _prefs?.getKeys().length ?? 0,
      'active_timers': _expirationTimers.length,
      'presence_controllers': _presenceControllers.length,
      'cache_timestamps': _cacheTimestamps.length,
    };
  }

  /// Cleanup expired cache entries
  Future<void> cleanupExpiredCache() async {
    try {
      await _ensureInitialized();
      
      final now = DateTime.now();
      final keysToRemove = <String>[];
      
      // Check all cached items for expiration
      for (final entry in _cacheTimestamps.entries) {
        final key = entry.key;
        final timestamp = entry.value;
        
        Duration expiration = defaultCacheExpiration;
        if (key.startsWith('messages_')) {
          expiration = messageCacheExpiration;
        } else if (key.startsWith('user_data:')) {
          expiration = userDataCacheExpiration;
        }
        
        if (now.difference(timestamp) > expiration) {
          keysToRemove.add(key);
        }
      }
      
      // Remove expired items
      for (final key in keysToRemove) {
        await _prefs!.remove(key);
        _cacheTimestamps.remove(key);
        _memoryCache.remove(key);
        _cancelExpiration(key);
      }
      
      debugPrint('Cleaned up ${keysToRemove.length} expired cache entries');
    } catch (e) {
      debugPrint('Error cleaning up expired cache: $e');
    }
  }

  /// Clear all cache data
  Future<void> clearCache() async {
    try {
      await _ensureInitialized();
      
      // Cancel all timers
      for (final timer in _expirationTimers.values) {
        timer.cancel();
      }
      _expirationTimers.clear();
      
      // Close all presence controllers
      for (final controller in _presenceControllers.values) {
        await controller.close();
      }
      _presenceControllers.clear();
      
      // Clear memory caches
      _memoryCache.clear();
      _cacheTimestamps.clear();
      _paginatedCache.clear();
      
      // Clear all preferences
      await _prefs!.clear();
      
      debugPrint('All cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Private helper methods
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }

  void _setExpiration(String key, Duration duration) {
    _cancelExpiration(key);
    
    _expirationTimers[key] = Timer(duration, () async {
      await _prefs?.remove(key);
      _expirationTimers.remove(key);
      debugPrint('Cache key expired: $key');
    });
  }

  void _cancelExpiration(String key) {
    final timer = _expirationTimers.remove(key);
    timer?.cancel();
  }

  void _notifyPresenceUpdate(PresenceUpdate update) {
    final controller = _presenceControllers[update.userId];
    if (controller != null && !controller.isClosed) {
      controller.add(update);
    }
  }
}

/// User session model
class UserSession {
  final String userId;
  final String sessionId;
  final DateTime createdAt;
  final DateTime lastActivity;
  final String deviceId;
  final String platform;
  final Map<String, dynamic> metadata;

  UserSession({
    required this.userId,
    required this.sessionId,
    required this.createdAt,
    required this.lastActivity,
    required this.deviceId,
    required this.platform,
    required this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sessionId': sessionId,
      'createdAt': createdAt.toIso8601String(),
      'lastActivity': lastActivity.toIso8601String(),
      'deviceId': deviceId,
      'platform': platform,
      'metadata': metadata,
    };
  }

  factory UserSession.fromMap(Map<String, dynamic> map) {
    return UserSession(
      userId: map['userId'] ?? '',
      sessionId: map['sessionId'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      lastActivity: DateTime.parse(map['lastActivity']),
      deviceId: map['deviceId'] ?? '',
      platform: map['platform'] ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}

/// User presence model
class UserPresence {
  final String userId;
  final PresenceStatus status;
  final String? customMessage;
  final DateTime lastSeen;
  final DateTime updatedAt;

  UserPresence({
    required this.userId,
    required this.status,
    this.customMessage,
    required this.lastSeen,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status.value,
      'customMessage': customMessage,
      'lastSeen': lastSeen.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserPresence.fromMap(Map<String, dynamic> map) {
    return UserPresence(
      userId: map['userId'] ?? '',
      status: PresenceStatusExtension.fromString(map['status'] ?? 'offline'),
      customMessage: map['customMessage'],
      lastSeen: DateTime.parse(map['lastSeen']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}

/// Presence status enum
enum PresenceStatus {
  online,
  away,
  busy,
  offline,
}

extension PresenceStatusExtension on PresenceStatus {
  String get value {
    switch (this) {
      case PresenceStatus.online:
        return 'online';
      case PresenceStatus.away:
        return 'away';
      case PresenceStatus.busy:
        return 'busy';
      case PresenceStatus.offline:
        return 'offline';
    }
  }

  static PresenceStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return PresenceStatus.online;
      case 'away':
        return PresenceStatus.away;
      case 'busy':
        return PresenceStatus.busy;
      default:
        return PresenceStatus.offline;
    }
  }
}

/// Presence update model
class PresenceUpdate {
  final String userId;
  final PresenceStatus status;
  final String? customMessage;
  final DateTime timestamp;

  PresenceUpdate({
    required this.userId,
    required this.status,
    this.customMessage,
    required this.timestamp,
  });
}