// Live Updates Service - Real-time data synchronization
// Enhanced real-time features for TALOWA app

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../social_feed/feed_service.dart';
// Removed: live_activity_service.dart (feature deprecated)
import '../notifications/notification_service.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../models/user_model.dart';

/// Service for managing real-time updates across the application
class LiveUpdatesService {
  static LiveUpdatesService? _instance;
  static LiveUpdatesService get instance => _instance ??= LiveUpdatesService._();
  
  LiveUpdatesService._();
  
  // Firestore instance
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream controllers for different data types
  static final StreamController<PostModel> _postUpdatesController = 
      StreamController<PostModel>.broadcast();
  static final StreamController<CommentModel> _commentUpdatesController = 
      StreamController<CommentModel>.broadcast();
  static final StreamController<UserPresence> _userPresenceController = 
      StreamController<UserPresence>.broadcast();
  static final StreamController<LiveEngagement> _engagementController = 
      StreamController<LiveEngagement>.broadcast();
  
  // Stream subscriptions
  static final Map<String, StreamSubscription> _subscriptions = {};
  
  // Connection state
  static bool _isInitialized = false;
  static bool _isConnected = false;
  
  // Current user info
  static String? _currentUserId;
  static Timer? _presenceTimer;
  
  /// Initialize live updates service
  static Future<void> initialize({required String userId}) async {
    if (_isInitialized) return;
    
    try {
      debugPrint('ðŸ”„ LiveUpdatesService: Initializing...');
      
      _currentUserId = userId;
      
      // Set up Firestore settings for real-time updates
      await _setupFirestoreSettings();
      
      // Start listening to various data streams
      await _startPostUpdatesListener();
      await _startCommentUpdatesListener();
      await _startUserPresenceListener();
      await _startEngagementListener();
      
      // Set up user presence
      await _setupUserPresence();
      
      _isInitialized = true;
      _isConnected = true;
      
      debugPrint('âœ… LiveUpdatesService: Initialized successfully');
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Initialization error: $e');
      rethrow;
    }
  }
  
  /// Dispose of all resources
  static Future<void> dispose() async {
    debugPrint('ðŸ”„ LiveUpdatesService: Disposing...');
    
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // Cancel presence timer
    _presenceTimer?.cancel();
    _presenceTimer = null;
    
    // Update user presence to offline
    if (_currentUserId != null) {
      await _updateUserPresence(false);
    }
    
    // Close stream controllers
    await _postUpdatesController.close();
    await _commentUpdatesController.close();
    await _userPresenceController.close();
    await _engagementController.close();
    
    _isInitialized = false;
    _isConnected = false;
    _currentUserId = null;
    
    debugPrint('âœ… LiveUpdatesService: Disposed successfully');
  }
  
  /// Get post updates stream
  static Stream<PostModel> get postUpdatesStream => _postUpdatesController.stream;
  
  /// Get comment updates stream
  static Stream<CommentModel> get commentUpdatesStream => _commentUpdatesController.stream;
  
  /// Get user presence stream
  static Stream<UserPresence> get userPresenceStream => _userPresenceController.stream;
  
  /// Get engagement updates stream
  static Stream<LiveEngagement> get engagementStream => _engagementController.stream;
  
  /// Check if service is connected
  static bool get isConnected => _isConnected;
  
  /// Set up Firestore settings for optimal real-time performance
  static Future<void> _setupFirestoreSettings() async {
    try {
      // Enable offline persistence
      await _firestore.enablePersistence();
      
      // Set up connection state listener
      _firestore.enableNetwork();
      
    } catch (e) {
      debugPrint('âš ï¸ LiveUpdatesService: Firestore setup warning: $e');
    }
  }
  
  /// Start listening to post updates
  static Future<void> _startPostUpdatesListener() async {
    try {
      final subscription = _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .snapshots()
          .listen(
            (snapshot) {
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.modified || 
                    change.type == DocumentChangeType.added) {
                  
                  final post = PostModel.fromFirestore(change.doc);
                  _postUpdatesController.add(post);
                  
                  // Removed: Live activity tracking for post changes
                }
              }
            },
            onError: (error) {
              debugPrint('âŒ LiveUpdatesService: Post updates error: $error');
            },
          );
      
      _subscriptions['posts'] = subscription;
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error setting up post listener: $e');
    }
  }
  
  /// Start listening to comment updates
  static Future<void> _startCommentUpdatesListener() async {
    try {
      final subscription = _firestore
          .collectionGroup('comments')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added) {
                  final comment = CommentModel.fromFirestore(change.doc);
                  _commentUpdatesController.add(comment);
                  
                  // Removed: Live activity tracking for comments
                }
              }
            },
            onError: (error) {
              debugPrint('âŒ LiveUpdatesService: Comment updates error: $error');
            },
          );
      
      _subscriptions['comments'] = subscription;
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error setting up comment listener: $e');
    }
  }
  
  /// Start listening to user presence updates
  static Future<void> _startUserPresenceListener() async {
    try {
      final subscription = _firestore
          .collection('user_presence')
          .where('isOnline', isEqualTo: true)
          .snapshots()
          .listen(
            (snapshot) {
              for (final change in snapshot.docChanges) {
                final presence = UserPresence.fromFirestore(change.doc);
                _userPresenceController.add(presence);
              }
            },
            onError: (error) {
              debugPrint('âŒ LiveUpdatesService: User presence error: $error');
            },
          );
      
      _subscriptions['user_presence'] = subscription;
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error setting up presence listener: $e');
    }
  }
  
  /// Start listening to engagement updates (likes, shares, etc.)
  static Future<void> _startEngagementListener() async {
    try {
      final subscription = _firestore
          .collectionGroup('engagements')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots()
          .listen(
            (snapshot) {
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added) {
                  final engagement = LiveEngagement.fromFirestore(change.doc);
                  _engagementController.add(engagement);
                  
                  // Removed: Live activity tracking for engagement
                }
              }
            },
            onError: (error) {
              debugPrint('âŒ LiveUpdatesService: Engagement updates error: $error');
            },
          );
      
      _subscriptions['engagements'] = subscription;
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error setting up engagement listener: $e');
    }
  }
  
  /// Set up user presence tracking
  static Future<void> _setupUserPresence() async {
    if (_currentUserId == null) return;
    
    try {
      // Set initial presence
      await _updateUserPresence(true);
      
      // Set up periodic presence updates
      _presenceTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _updateUserPresence(true),
      );
      
      // Set up offline detection
      await _setupOfflineDetection();
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error setting up user presence: $e');
    }
  }
  
  /// Update user presence status
  static Future<void> _updateUserPresence(bool isOnline) async {
    if (_currentUserId == null) return;
    
    try {
      await _firestore
          .collection('user_presence')
          .doc(_currentUserId)
          .set({
        'userId': _currentUserId,
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error updating presence: $e');
    }
  }
  
  /// Set up offline detection
  static Future<void> _setupOfflineDetection() async {
    if (_currentUserId == null) return;
    
    try {
      // Use Firestore's offline capabilities
      final presenceRef = _firestore
          .collection('user_presence')
          .doc(_currentUserId);
      
      // Set up onDisconnect equivalent using server timestamp
      await presenceRef.set({
        'userId': _currentUserId,
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error setting up offline detection: $e');
    }
  }
  
  /// Manually trigger a post update
  static Future<void> triggerPostUpdate(PostModel post) async {
    try {
      await _firestore
          .collection('posts')
          .doc(post.id)
          .update({
        'updatedAt': FieldValue.serverTimestamp(),
        'version': FieldValue.increment(1),
      });
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error triggering post update: $e');
    }
  }
  
  /// Get online users count
  static Future<int> getOnlineUsersCount() async {
    try {
      final snapshot = await _firestore
          .collection('user_presence')
          .where('isOnline', isEqualTo: true)
          .get();
      
      return snapshot.docs.length;
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error getting online users count: $e');
      return 0;
    }
  }
  
  /// Get recent activity summary
  static Future<Map<String, int>> getRecentActivitySummary() async {
    try {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      // Get posts count
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();
      
      // Get comments count
      final commentsSnapshot = await _firestore
          .collectionGroup('comments')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();
      
      // Get engagements count
      final engagementsSnapshot = await _firestore
          .collectionGroup('engagements')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();
      
      // Get online users count
      final onlineUsers = await getOnlineUsersCount();
      
      return {
        'posts': postsSnapshot.docs.length,
        'comments': commentsSnapshot.docs.length,
        'likes': engagementsSnapshot.docs
            .where((doc) => doc.data()['type'] == 'like')
            .length,
        'shares': engagementsSnapshot.docs
            .where((doc) => doc.data()['type'] == 'share')
            .length,
        'users_online': onlineUsers,
      };
      
    } catch (e) {
      debugPrint('âŒ LiveUpdatesService: Error getting activity summary: $e');
      return {};
    }
  }
}

/// Model for user presence data
class UserPresence {
  final String userId;
  final bool isOnline;
  final DateTime lastSeen;
  final DateTime updatedAt;
  
  UserPresence({
    required this.userId,
    required this.isOnline,
    required this.lastSeen,
    required this.updatedAt,
  });
  
  factory UserPresence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPresence(
      userId: data['userId'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isOnline': isOnline,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Model for live engagement data
class LiveEngagement {
  final String id;
  final String userId;
  final String targetId;
  final String type; // 'like', 'share', etc.
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  
  LiveEngagement({
    required this.id,
    required this.userId,
    required this.targetId,
    required this.type,
    required this.timestamp,
    this.metadata = const {},
  });
  
  factory LiveEngagement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveEngagement(
      id: doc.id,
      userId: data['userId'] ?? '',
      targetId: data['targetId'] ?? '',
      type: data['type'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] ?? {},
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'targetId': targetId,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}