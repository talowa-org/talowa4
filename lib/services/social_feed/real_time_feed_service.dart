// Real-time Feed Service - Handle real-time feed updates and synchronization
// Part of Task 13: Implement real-time feed updates

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/comment_model.dart';
import '../../models/social_feed/geographic_targeting.dart';
import '../auth/auth_service.dart';

/// Service for managing real-time feed updates
class RealTimeFeedService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Connectivity _connectivity = Connectivity();
  
  // Stream controllers for real-time updates
  static final StreamController<List<PostModel>> _feedStreamController = 
      StreamController<List<PostModel>>.broadcast();
  static final StreamController<PostModel> _postUpdateController = 
      StreamController<PostModel>.broadcast();
  static final StreamController<CommentModel> _commentUpdateController = 
      StreamController<CommentModel>.broadcast();
  static final StreamController<ConnectionState> _connectionStateController = 
      StreamController<ConnectionState>.broadcast();
  
  // Active listeners and subscriptions
  static final Map<String, StreamSubscription> _activeListeners = {};
  static StreamSubscription? _connectivitySubscription;
  static Timer? _reconnectionTimer;
  static Timer? _batchUpdateTimer;
  
  // State management
  static bool _isInitialized = false;
  static ConnectionState _currentConnectionState = ConnectionState.disconnected;
  static final List<PostModel> _pendingUpdates = [];
  static final Map<String, PostModel> _cachedPosts = {};
  static DateTime? _lastUpdateTime;
  
  // Configuration
  static const Duration _batchUpdateInterval = Duration(seconds: 2);
  static const Duration _reconnectionDelay = Duration(seconds: 5);
  static const int _maxRetryAttempts = 3;
  static const int _maxCachedPosts = 100;
  
  /// Initialize the real-time feed service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('RealTimeFeedService: Initializing...');
      
      // Set up connectivity monitoring
      await _setupConnectivityMonitoring();
      
      // Set up batch update processing
      _setupBatchUpdateProcessing();
      
      // Initialize connection state
      await _updateConnectionState();
      
      _isInitialized = true;
      debugPrint('RealTimeFeedService: Initialized successfully');
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Initialization failed: $e');
      rethrow;
    }
  }
  
  /// Start listening to feed updates for a user
  static Future<void> startFeedListener({
    String? userId,
    GeographicTargeting? userLocation,
    PostCategory? categoryFilter,
    int limit = 20,
  }) async {
    try {
      await initialize();
      
      userId ??= AuthService.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      debugPrint('RealTimeFeedService: Starting feed listener for user $userId');
      
      // Stop existing listener if any
      await stopFeedListener();
      
      // Create feed query
      Query feedQuery = _buildFeedQuery(
        userId: userId,
        userLocation: userLocation,
        categoryFilter: categoryFilter,
        limit: limit,
      );
      
      // Set up real-time listener
      final listenerId = 'feed_$userId';
      _activeListeners[listenerId] = feedQuery.snapshots().listen(
        (snapshot) => _handleFeedSnapshot(snapshot, userId!),
        onError: (error) => _handleListenerError(error, listenerId),
      );
      
      debugPrint('RealTimeFeedService: Feed listener started');
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Failed to start feed listener: $e');
      rethrow;
    }
  }
  
  /// Stop feed listener
  static Future<void> stopFeedListener() async {
    try {
      final feedListeners = _activeListeners.keys
          .where((key) => key.startsWith('feed_'))
          .toList();
      
      for (final listenerId in feedListeners) {
        await _activeListeners[listenerId]?.cancel();
        _activeListeners.remove(listenerId);
      }
      
      debugPrint('RealTimeFeedService: Feed listeners stopped');
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Error stopping feed listeners: $e');
    }
  }
  
  /// Start listening to post updates
  static Future<void> startPostListener(String postId) async {
    try {
      await initialize();
      
      debugPrint('RealTimeFeedService: Starting post listener for $postId');
      
      final listenerId = 'post_$postId';
      
      // Stop existing listener if any
      await _activeListeners[listenerId]?.cancel();
      
      // Set up post listener
      _activeListeners[listenerId] = _firestore
          .collection('posts')
          .doc(postId)
          .snapshots()
          .listen(
            (snapshot) => _handlePostSnapshot(snapshot),
            onError: (error) => _handleListenerError(error, listenerId),
          );
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Failed to start post listener: $e');
    }
  }
  
  /// Stop post listener
  static Future<void> stopPostListener(String postId) async {
    try {
      final listenerId = 'post_$postId';
      await _activeListeners[listenerId]?.cancel();
      _activeListeners.remove(listenerId);
      
      debugPrint('RealTimeFeedService: Post listener stopped for $postId');
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Error stopping post listener: $e');
    }
  }
  
  /// Start listening to comments for a post
  static Future<void> startCommentsListener(String postId) async {
    try {
      await initialize();
      
      debugPrint('RealTimeFeedService: Starting comments listener for $postId');
      
      final listenerId = 'comments_$postId';
      
      // Stop existing listener if any
      await _activeListeners[listenerId]?.cancel();
      
      // Set up comments listener
      _activeListeners[listenerId] = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .where('isHidden', isEqualTo: false)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .listen(
            (snapshot) => _handleCommentsSnapshot(snapshot, postId),
            onError: (error) => _handleListenerError(error, listenerId),
          );
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Failed to start comments listener: $e');
    }
  }
  
  /// Stop comments listener
  static Future<void> stopCommentsListener(String postId) async {
    try {
      final listenerId = 'comments_$postId';
      await _activeListeners[listenerId]?.cancel();
      _activeListeners.remove(listenerId);
      
      debugPrint('RealTimeFeedService: Comments listener stopped for $postId');
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Error stopping comments listener: $e');
    }
  }
  
  /// Get feed stream
  static Stream<List<PostModel>> get feedStream => _feedStreamController.stream;
  
  /// Get post updates stream
  static Stream<PostModel> get postUpdateStream => _postUpdateController.stream;
  
  /// Get comment updates stream
  static Stream<CommentModel> get commentUpdateStream => _commentUpdateController.stream;
  
  /// Get connection state stream
  static Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  /// Get current connection state
  static ConnectionState get connectionState => _currentConnectionState;
  
  /// Force reconnection
  static Future<void> forceReconnection() async {
    try {
      debugPrint('RealTimeFeedService: Forcing reconnection...');
      
      // Cancel all active listeners
      await _cancelAllListeners();
      
      // Update connection state
      await _updateConnectionState();
      
      // Restart listeners if connected
      if (_currentConnectionState == ConnectionState.connected) {
        // Listeners will be restarted by the calling code
        debugPrint('RealTimeFeedService: Ready for listener restart');
      }
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Force reconnection failed: $e');
    }
  }
  
  /// Dispose of all resources
  static Future<void> dispose() async {
    try {
      debugPrint('RealTimeFeedService: Disposing...');
      
      // Cancel all timers
      _reconnectionTimer?.cancel();
      _batchUpdateTimer?.cancel();
      
      // Cancel all listeners
      await _cancelAllListeners();
      
      // Cancel connectivity subscription
      await _connectivitySubscription?.cancel();
      
      // Close stream controllers
      await _feedStreamController.close();
      await _postUpdateController.close();
      await _commentUpdateController.close();
      await _connectionStateController.close();
      
      // Clear state
      _pendingUpdates.clear();
      _cachedPosts.clear();
      _isInitialized = false;
      
      debugPrint('RealTimeFeedService: Disposed successfully');
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Disposal error: $e');
    }
  }
  
  // Private helper methods
  
  static Query _buildFeedQuery({
    required String userId,
    GeographicTargeting? userLocation,
    PostCategory? categoryFilter,
    required int limit,
  }) {
    Query query = _firestore
        .collection('posts')
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    
    // Apply category filter
    if (categoryFilter != null) {
      query = query.where('category', 
          isEqualTo: categoryFilter.toString().split('.').last);
    }
    
    // TODO: Add geographic filtering based on userLocation
    // This would require additional Firestore indexes
    
    return query;
  }
  
  static Future<void> _handleFeedSnapshot(QuerySnapshot snapshot, String userId) async {
    try {
      final posts = <PostModel>[];
      
      for (final doc in snapshot.docs) {
        try {
          final post = PostModel.fromFirestore(doc);
          
          // Add user-specific engagement data
          final postWithEngagement = await _addUserEngagementData(post, userId);
          posts.add(postWithEngagement);
          
          // Cache the post
          _cachedPosts[post.id] = postWithEngagement;
        } catch (e) {
          debugPrint('RealTimeFeedService: Error parsing post ${doc.id}: $e');
        }
      }
      
      // Manage cache size
      _manageCacheSize();
      
      // Add to pending updates for batching
      _pendingUpdates.clear();
      _pendingUpdates.addAll(posts);
      _lastUpdateTime = DateTime.now();
      
      debugPrint('RealTimeFeedService: Feed snapshot processed with ${posts.length} posts');
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Error handling feed snapshot: $e');
    }
  }
  
  static Future<void> _handlePostSnapshot(DocumentSnapshot snapshot) async {
    try {
      if (!snapshot.exists) return;
      
      final post = PostModel.fromFirestore(snapshot);
      final userId = AuthService.currentUser?.uid;
      
      if (userId != null) {
        final postWithEngagement = await _addUserEngagementData(post, userId);
        
        // Update cache
        _cachedPosts[post.id] = postWithEngagement;
        
        // Emit update
        _postUpdateController.add(postWithEngagement);
        
        debugPrint('RealTimeFeedService: Post update emitted for ${post.id}');
      }
      
    } catch (e) {
      debugPrint('RealTimeFeedService: Error handling post snapshot: $e');
    }
  }
  
  static Future<void> _handleCommentsSnapshot(QuerySnapshot snapshot, String postId) async {
    try {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || 
            change.type == DocumentChangeType.modified) {
          try {
            final comment = CommentModel.fromFirestore(change.doc);
            _commentUpdateController.add(comment);
            
            debugPrint('RealTimeFeedService: Comment update emitted for ${comment.id}');
          } catch (e) {
            debugPrint('RealTimeFeedService: Error parsing comment ${change.doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('RealTimeFeedService: Error handling comments snapshot: $e');
    }
  }
  
  static void _handleListenerError(dynamic error, String listenerId) {
    debugPrint('RealTimeFeedService: Listener error for $listenerId: $error');
    
    // Update connection state
    _updateConnectionState();
    
    // Schedule reconnection
    _scheduleReconnection(listenerId);
  }
  
  static Future<void> _setupConnectivityMonitoring() async {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        debugPrint('RealTimeFeedService: Connectivity changed to $results');
        _updateConnectionState();
      },
    );
  }
  
  static void _setupBatchUpdateProcessing() {
    _batchUpdateTimer = Timer.periodic(_batchUpdateInterval, (_) {
      _processBatchUpdates();
    });
  }
  
  static void _processBatchUpdates() {
    if (_pendingUpdates.isNotEmpty) {
      final updates = List<PostModel>.from(_pendingUpdates);
      _pendingUpdates.clear();
      
      // Emit batched updates
      _feedStreamController.add(updates);
      
      debugPrint('RealTimeFeedService: Batch update emitted with ${updates.length} posts');
    }
  }
  
  static Future<void> _updateConnectionState() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      
      final newState = isConnected 
          ? ConnectionState.connected 
          : ConnectionState.disconnected;
      
      if (newState != _currentConnectionState) {
        _currentConnectionState = newState;
        _connectionStateController.add(newState);
        
        debugPrint('RealTimeFeedService: Connection state changed to $newState');
        
        if (newState == ConnectionState.connected) {
          _cancelReconnectionTimer();
        }
      }
    } catch (e) {
      debugPrint('RealTimeFeedService: Error updating connection state: $e');
    }
  }
  
  static void _scheduleReconnection(String listenerId) {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(_reconnectionDelay, () {
      debugPrint('RealTimeFeedService: Attempting reconnection for $listenerId');
      _updateConnectionState();
    });
  }
  
  static void _cancelReconnectionTimer() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }
  
  static Future<void> _cancelAllListeners() async {
    for (final subscription in _activeListeners.values) {
      await subscription.cancel();
    }
    _activeListeners.clear();
  }
  
  static void _manageCacheSize() {
    if (_cachedPosts.length > _maxCachedPosts) {
      // Remove oldest entries
      final sortedEntries = _cachedPosts.entries.toList()
        ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));
      
      final toRemove = sortedEntries.length - _maxCachedPosts;
      for (int i = 0; i < toRemove; i++) {
        _cachedPosts.remove(sortedEntries[i].key);
      }
      
      debugPrint('RealTimeFeedService: Cache cleaned, removed $toRemove entries');
    }
  }
  
  static Future<PostModel> _addUserEngagementData(PostModel post, String userId) async {
    try {
      // Get user engagement data
      final engagementDoc = await _firestore
          .collection('posts')
          .doc(post.id)
          .collection('engagement')
          .doc(userId)
          .get();
      
      if (engagementDoc.exists) {
        final data = engagementDoc.data()!;
        return post.copyWith(
          isLikedByCurrentUser: data['liked'] ?? false,
          isSharedByCurrentUser: data['shared'] ?? false,
        );
      }
      
      return post;
    } catch (e) {
      debugPrint('RealTimeFeedService: Error adding engagement data: $e');
      return post;
    }
  }
}

/// Connection state enumeration
enum ConnectionState {
  connected,
  disconnected,
  reconnecting,
}

/// Real-time update event types
enum UpdateEventType {
  postAdded,
  postModified,
  postRemoved,
  commentAdded,
  commentModified,
  engagementChanged,
}

/// Real-time update event
class RealTimeUpdateEvent {
  final UpdateEventType type;
  final String targetId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  
  const RealTimeUpdateEvent({
    required this.type,
    required this.targetId,
    required this.data,
    required this.timestamp,
  });
  
  factory RealTimeUpdateEvent.postAdded(PostModel post) {
    return RealTimeUpdateEvent(
      type: UpdateEventType.postAdded,
      targetId: post.id,
      data: {'post': post},
      timestamp: DateTime.now(),
    );
  }
  
  factory RealTimeUpdateEvent.commentAdded(CommentModel comment) {
    return RealTimeUpdateEvent(
      type: UpdateEventType.commentAdded,
      targetId: comment.id,
      data: {'comment': comment},
      timestamp: DateTime.now(),
    );
  }
  
  factory RealTimeUpdateEvent.engagementChanged(String postId, Map<String, dynamic> engagement) {
    return RealTimeUpdateEvent(
      type: UpdateEventType.engagementChanged,
      targetId: postId,
      data: engagement,
      timestamp: DateTime.now(),
    );
  }
}