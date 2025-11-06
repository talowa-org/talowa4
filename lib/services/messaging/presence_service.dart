// Presence Service for TALOWA Messaging System
// Requirements: 1.3, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
// Task: Build online status indicators and presence tracking

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import '../../models/messaging/presence_model.dart';

/// Service for managing user presence and online status tracking
/// Provides real-time online/offline status, typing indicators, and custom status messages
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Connection state
  bool _isInitialized = false;
  String? _currentUserId;
  
  // Stream controllers for real-time presence updates
  final StreamController<UserPresence> _presenceUpdateController = 
      StreamController<UserPresence>.broadcast();
  final StreamController<TypingIndicator> _typingIndicatorController = 
      StreamController<TypingIndicator>.broadcast();
  final StreamController<Map<String, UserPresence>> _bulkPresenceController = 
      StreamController<Map<String, UserPresence>>.broadcast();
  
  // Timers and subscriptions
  Timer? _heartbeatTimer;
  Timer? _presenceCleanupTimer;
  final Map<String, Timer> _typingTimers = {};
  final Map<String, StreamSubscription> _presenceSubscriptions = {};
  
  // Cache for presence data
  final Map<String, UserPresence> _presenceCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 2);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _typingTimeout = Duration(seconds: 3);
  static const Duration _offlineThreshold = Duration(minutes: 5);
  
  // Getters for streams
  Stream<UserPresence> get presenceUpdateStream => _presenceUpdateController.stream;
  Stream<TypingIndicator> get typingIndicatorStream => _typingIndicatorController.stream;
  Stream<Map<String, UserPresence>> get bulkPresenceStream => _bulkPresenceController.stream;
  
  bool get isInitialized => _isInitialized;

  /// Initialize the presence service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      _currentUserId = currentUser.uid;
      
      // Set initial online status
      await _setUserOnline();
      
      // Start heartbeat timer
      _startHeartbeat();
      
      // Start cleanup timer
      _startPresenceCleanup();
      
      // Set up offline detection
      await _setupOfflineDetection();
      
      _isInitialized = true;
      debugPrint('✅ PresenceService: Initialized successfully');
      
    } catch (e) {
      debugPrint('❌ PresenceService: Initialization error: $e');
      rethrow;
    }
  }

  /// Set user online status
  Future<void> _setUserOnline() async {
    if (_currentUserId == null) return;
    
    try {
      final presence = UserPresence(
        userId: _currentUserId!,
        isOnline: true,
        lastSeen: DateTime.now(),
        customStatus: null,
        statusMessage: null,
        updatedAt: DateTime.now(),
      );
      
      await _firestore
          .collection('user_presence')
          .doc(_currentUserId)
          .set(presence.toFirestore(), SetOptions(merge: true));
      
      // Update cache
      _presenceCache[_currentUserId!] = presence;
      _cacheTimestamps[_currentUserId!] = DateTime.now();
      
      debugPrint('🟢 PresenceService: User set online');
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error setting user online: $e');
    }
  }

  /// Set user offline status
  Future<void> setUserOffline() async {
    if (_currentUserId == null) return;
    
    try {
      final presence = UserPresence(
        userId: _currentUserId!,
        isOnline: false,
        lastSeen: DateTime.now(),
        customStatus: _presenceCache[_currentUserId!]?.customStatus,
        statusMessage: _presenceCache[_currentUserId!]?.statusMessage,
        updatedAt: DateTime.now(),
      );
      
      await _firestore
          .collection('user_presence')
          .doc(_currentUserId)
          .set(presence.toFirestore(), SetOptions(merge: true));
      
      // Update cache
      _presenceCache[_currentUserId!] = presence;
      _cacheTimestamps[_currentUserId!] = DateTime.now();
      
      debugPrint('🔴 PresenceService: User set offline');
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error setting user offline: $e');
    }
  }

  /// Update custom status message
  Future<void> updateCustomStatus({
    PresenceStatus? status,
    String? statusMessage,
  }) async {
    if (_currentUserId == null) return;
    
    try {
      final currentPresence = _presenceCache[_currentUserId!];
      final presence = UserPresence(
        userId: _currentUserId!,
        isOnline: currentPresence?.isOnline ?? true,
        lastSeen: DateTime.now(),
        customStatus: status,
        statusMessage: statusMessage,
        updatedAt: DateTime.now(),
      );
      
      await _firestore
          .collection('user_presence')
          .doc(_currentUserId)
          .set(presence.toFirestore(), SetOptions(merge: true));
      
      // Update cache
      _presenceCache[_currentUserId!] = presence;
      _cacheTimestamps[_currentUserId!] = DateTime.now();
      
      // Emit update
      _presenceUpdateController.add(presence);
      
      debugPrint('📝 PresenceService: Custom status updated');
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error updating custom status: $e');
    }
  }

  /// Get user presence
  Future<UserPresence?> getUserPresence(String userId) async {
    try {
      // Check cache first
      if (_isValidCache(userId)) {
        return _presenceCache[userId];
      }
      
      final doc = await _firestore
          .collection('user_presence')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final presence = UserPresence.fromFirestore(doc);
        
        // Update cache
        _presenceCache[userId] = presence;
        _cacheTimestamps[userId] = DateTime.now();
        
        return presence;
      }
      
      return null;
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error getting user presence: $e');
      return null;
    }
  }

  /// Get multiple user presences efficiently
  Future<Map<String, UserPresence>> getUserPresences(List<String> userIds) async {
    final result = <String, UserPresence>{};
    final uncachedUserIds = <String>[];
    
    try {
      // Check cache for each user
      for (final userId in userIds) {
        if (_isValidCache(userId)) {
          result[userId] = _presenceCache[userId]!;
        } else {
          uncachedUserIds.add(userId);
        }
      }
      
      // Fetch uncached users in batches
      if (uncachedUserIds.isNotEmpty) {
        const batchSize = 10; // Firestore 'in' query limit
        
        for (int i = 0; i < uncachedUserIds.length; i += batchSize) {
          final batch = uncachedUserIds.skip(i).take(batchSize).toList();
          
          final querySnapshot = await _firestore
              .collection('user_presence')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          
          for (final doc in querySnapshot.docs) {
            final presence = UserPresence.fromFirestore(doc);
            result[doc.id] = presence;
            
            // Update cache
            _presenceCache[doc.id] = presence;
            _cacheTimestamps[doc.id] = DateTime.now();
          }
        }
      }
      
      // Emit bulk update
      if (result.isNotEmpty) {
        _bulkPresenceController.add(result);
      }
      
      return result;
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error getting user presences: $e');
      return result;
    }
  }

  /// Subscribe to user presence updates
  StreamSubscription<UserPresence> subscribeToUserPresence(
    String userId,
    Function(UserPresence) onUpdate,
  ) {
    // Cancel existing subscription if any
    _presenceSubscriptions[userId]?.cancel();
    
    final subscription = _firestore
        .collection('user_presence')
        .doc(userId)
        .snapshots()
        .map((doc) => UserPresence.fromFirestore(doc))
        .listen(
          (presence) {
            // Update cache
            _presenceCache[userId] = presence;
            _cacheTimestamps[userId] = DateTime.now();
            
            // Call callback
            onUpdate(presence);
            
            // Emit to stream
            _presenceUpdateController.add(presence);
          },
          onError: (error) {
            debugPrint('❌ PresenceService: Presence subscription error: $error');
          },
        );
    
    _presenceSubscriptions[userId] = subscription;
    return subscription;
  }

  /// Subscribe to multiple user presences
  void subscribeToMultiplePresences(
    List<String> userIds,
    Function(Map<String, UserPresence>) onUpdate,
  ) {
    const batchSize = 10;
    final presenceMap = <String, UserPresence>{};
    
    for (int i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();
      final subscriptionKey = 'batch_$i';
      
      final subscription = _firestore
          .collection('user_presence')
          .where(FieldPath.documentId, whereIn: batch)
          .snapshots()
          .listen(
            (snapshot) {
              for (final doc in snapshot.docs) {
                final presence = UserPresence.fromFirestore(doc);
                presenceMap[doc.id] = presence;
                
                // Update cache
                _presenceCache[doc.id] = presence;
                _cacheTimestamps[doc.id] = DateTime.now();
              }
              
              // Call callback with updated map
              onUpdate(Map.from(presenceMap));
              
              // Emit to stream
              _bulkPresenceController.add(Map.from(presenceMap));
            },
            onError: (error) {
              debugPrint('❌ PresenceService: Bulk presence subscription error: $error');
            },
          );
      
      _presenceSubscriptions[subscriptionKey] = subscription;
    }
  }

  /// Send typing indicator
  void sendTypingIndicator(String conversationId, bool isTyping) {
    if (_currentUserId == null) return;
    
    try {
      final typingIndicator = TypingIndicator(
        userId: _currentUserId!,
        conversationId: conversationId,
        isTyping: isTyping,
        timestamp: DateTime.now(),
      );
      
      // Store in Firestore with TTL
      _firestore
          .collection('typing_indicators')
          .doc('${conversationId}_$_currentUserId')
          .set(typingIndicator.toFirestore())
          .catchError((error) {
        debugPrint('❌ PresenceService: Error sending typing indicator: $error');
      });
      
      // Emit to stream
      _typingIndicatorController.add(typingIndicator);
      
      // Auto-stop typing after timeout
      if (isTyping) {
        _typingTimers[conversationId]?.cancel();
        _typingTimers[conversationId] = Timer(_typingTimeout, () {
          sendTypingIndicator(conversationId, false);
        });
      } else {
        _typingTimers[conversationId]?.cancel();
        _typingTimers.remove(conversationId);
      }
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error sending typing indicator: $e');
    }
  }

  /// Subscribe to typing indicators for a conversation
  StreamSubscription<List<TypingIndicator>> subscribeToTypingIndicators(
    String conversationId,
    Function(List<TypingIndicator>) onUpdate,
  ) {
    return _firestore
        .collection('typing_indicators')
        .where('conversationId', isEqualTo: conversationId)
        .where('isTyping', isEqualTo: true)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(seconds: 10)),
        ))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TypingIndicator.fromFirestore(doc))
            .where((indicator) => indicator.userId != _currentUserId) // Exclude self
            .toList())
        .listen(
          onUpdate,
          onError: (error) {
            debugPrint('❌ PresenceService: Typing indicators subscription error: $error');
          },
        );
  }

  /// Get online users count
  Future<int> getOnlineUsersCount() async {
    try {
      final cutoffTime = DateTime.now().subtract(_offlineThreshold);
      
      final snapshot = await _firestore
          .collection('user_presence')
          .where('isOnline', isEqualTo: true)
          .where('lastSeen', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .get();
      
      return snapshot.docs.length;
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error getting online users count: $e');
      return 0;
    }
  }

  /// Get recently active users
  Future<List<UserPresence>> getRecentlyActiveUsers({
    int limit = 50,
    Duration threshold = const Duration(hours: 24),
  }) async {
    try {
      final cutoffTime = DateTime.now().subtract(threshold);
      
      final snapshot = await _firestore
          .collection('user_presence')
          .where('lastSeen', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .orderBy('lastSeen', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => UserPresence.fromFirestore(doc))
          .toList();
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error getting recently active users: $e');
      return [];
    }
  }

  /// Start heartbeat to maintain online status
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _setUserOnline();
    });
  }

  /// Start presence cleanup timer
  void _startPresenceCleanup() {
    _presenceCleanupTimer?.cancel();
    _presenceCleanupTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _cleanupOfflineUsers();
    });
  }

  /// Clean up offline users
  Future<void> _cleanupOfflineUsers() async {
    try {
      final cutoffTime = DateTime.now().subtract(_offlineThreshold);
      
      final snapshot = await _firestore
          .collection('user_presence')
          .where('isOnline', isEqualTo: true)
          .where('lastSeen', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isOnline': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
        debugPrint('🧹 PresenceService: Cleaned up ${snapshot.docs.length} offline users');
      }
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error cleaning up offline users: $e');
    }
  }

  /// Set up offline detection
  Future<void> _setupOfflineDetection() async {
    if (_currentUserId == null) return;
    
    try {
      // Use Firestore's onDisconnect equivalent
      // This is a simplified version - in production, you might want to use
      // Firebase Realtime Database for better offline detection
      
      // Set up a document that gets updated on disconnect
      await _firestore
          .collection('user_presence')
          .doc(_currentUserId)
          .set({
        'userId': _currentUserId,
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      debugPrint('❌ PresenceService: Error setting up offline detection: $e');
    }
  }

  /// Check if cache is valid for given user
  bool _isValidCache(String userId) {
    if (!_presenceCache.containsKey(userId) || !_cacheTimestamps.containsKey(userId)) {
      return false;
    }
    
    final cacheAge = DateTime.now().difference(_cacheTimestamps[userId]!);
    return cacheAge < _cacheDuration;
  }

  /// Clear cache for specific user or all users
  void clearCache([String? userId]) {
    if (userId != null) {
      _presenceCache.remove(userId);
      _cacheTimestamps.remove(userId);
    } else {
      _presenceCache.clear();
      _cacheTimestamps.clear();
    }
    debugPrint('🧹 PresenceService: Cache cleared${userId != null ? ' for $userId' : ''}');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedPresences': _presenceCache.length,
      'activeSubscriptions': _presenceSubscriptions.length,
      'activeTypingTimers': _typingTimers.length,
      'oldestCache': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
    };
  }

  /// Dispose of all resources
  Future<void> dispose() async {
    debugPrint('🔄 PresenceService: Disposing...');
    
    // Set user offline
    await setUserOffline();
    
    // Cancel all timers
    _heartbeatTimer?.cancel();
    _presenceCleanupTimer?.cancel();
    
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    
    // Cancel all subscriptions
    for (final subscription in _presenceSubscriptions.values) {
      await subscription.cancel();
    }
    _presenceSubscriptions.clear();
    
    // Close stream controllers
    await _presenceUpdateController.close();
    await _typingIndicatorController.close();
    await _bulkPresenceController.close();
    
    // Clear caches
    clearCache();
    
    _isInitialized = false;
    _currentUserId = null;
    
    debugPrint('✅ PresenceService: Disposed successfully');
  }
}