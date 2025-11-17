// Offline Sync Service for TALOWA Social Feed
// Implements Task 20: Implement offline functionality

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/social_feed/index.dart';
import '../database/local_database.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._instance();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._instance();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDatabase _localDb = LocalDatabase();
  final Connectivity _connectivity = Connectivity();
  
  // Sync status
  bool _isOnline = true;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  
  // Stream controllers
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  
  // Public streams
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  
  // Getters
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initialize offline sync service
  Future<void> initialize() async {
    try {
      // Initialize local database
      await _localDb.initialize();
      
      // Load last sync time
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString('last_sync_time');
      if (lastSyncString != null) {
        _lastSyncTime = DateTime.parse(lastSyncString);
      }
      
      // Check initial connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;
      _connectionController.add(_isOnline);
      
      // Listen to connectivity changes (standardized to List<ConnectivityResult>)
      _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
        final wasOnline = _isOnline;
        final latest = results.isNotEmpty ? results.last : ConnectivityResult.none;
        _isOnline = latest != ConnectivityResult.none;
        _connectionController.add(_isOnline);
        
        // Trigger sync when coming back online
        if (!wasOnline && _isOnline) {
          _triggerSync();
        }
      });
      
      // Start periodic sync when online
      if (_isOnline) {
        _startPeriodicSync();
      }
      
      debugPrint('OfflineSyncService initialized. Online: $_isOnline');
    } catch (e) {
      debugPrint('Error initializing OfflineSyncService: $e');
    }
  }

  /// Get posts with offline support
  Future<List<PostModel>> getPosts({
    int limit = 20,
    String? lastPostId,
    PostCategory? category,
    bool forceRefresh = false,
  }) async {
    try {
      if (_isOnline && !forceRefresh) {
        // Try to get fresh data from server
        try {
          final posts = await _getPostsFromServer(
            limit: limit,
            lastPostId: lastPostId,
            category: category,
          );
          
          // Cache posts locally
          await _cachePostsLocally(posts);
          return posts;
        } catch (e) {
          debugPrint('Error getting posts from server, falling back to cache: $e');
        }
      }
      
      // Get posts from local cache
      return await _getPostsFromCache(
        limit: limit,
        lastPostId: lastPostId,
        category: category,
      );
    } catch (e) {
      debugPrint('Error getting posts: $e');
      return [];
    }
  }

  /// Create post with offline support
  Future<String> createPost({
    required String title,
    required String content,
    required PostCategory category,
    required String authorId,
    List<String> hashtags = const [],
    List<String> imageUrls = const [],
    List<String> documentUrls = const [],
    GeographicTargeting? geographicTargeting,
  }) async {
    try {
      final postId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      
      final post = PostModel(
        id: postId,
        authorId: authorId,
        authorName: 'You', // Will be updated during sync
        title: title,
        content: content,
        category: category,
        hashtags: hashtags,
        imageUrls: imageUrls,
        documentUrls: documentUrls,
        geographicTargeting: geographicTargeting,
        createdAt: DateTime.now(),
        likesCount: 0,
        commentsCount: 0,
        sharesCount: 0,
        viewsCount: 0,
      );

      if (_isOnline) {
        // Try to create post on server immediately
        try {
          final serverPostId = await _createPostOnServer(post);
          
          // Update local cache with server ID
          await _localDb.updatePost({'id': postId, 'serverId': serverPostId, 'synced': true});
          return serverPostId;
        } catch (e) {
          debugPrint('Error creating post on server, queuing for sync: $e');
        }
      }
      
      // Store post locally for later sync
      await _localDb.insertPost(post.copyWith(
        metadata: {'synced': false, 'action': 'create'},
      ));
      
      // Add to sync queue
      await _addToSyncQueue('create_post', postId, post.toMap());
      
      return postId;
    } catch (e) {
      debugPrint('Error creating post: $e');
      rethrow;
    }
  }

  /// Like post with offline support
  Future<void> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      // Update local cache immediately for instant feedback
      await _localDb.updatePostEngagement(postId, {
        'isLikedByCurrentUser': isLiked,
        'likesCount': isLiked ? 1 : -1, // Increment/decrement
      });

      if (_isOnline) {
        // Try to sync with server immediately
        try {
          await _likePostOnServer(postId, userId, isLiked);
          return;
        } catch (e) {
          debugPrint('Error liking post on server, queuing for sync: $e');
        }
      }
      
      // Add to sync queue
      await _addToSyncQueue('like_post', postId, {
        'userId': userId,
        'isLiked': isLiked,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error liking post: $e');
    }
  }

  /// Add comment with offline support
  Future<String> addComment({
    required String postId,
    required String content,
    required String authorId,
    String? parentCommentId,
  }) async {
    try {
      final commentId = 'offline_comment_${DateTime.now().millisecondsSinceEpoch}';
      
      final comment = CommentModel(
        id: commentId,
        postId: postId,
        authorId: authorId,
        authorName: 'You', // Will be updated during sync
        content: content,
        parentCommentId: parentCommentId,
        createdAt: DateTime.now(),
        likesCount: 0,
        replies: [],
      );

      // Update local cache immediately
      await _localDb.insertComment(comment);
      await _localDb.updatePostEngagement(postId, {
        'commentsCount': 1, // Increment
      });

      if (_isOnline) {
        // Try to create comment on server immediately
        try {
          final serverCommentId = await _createCommentOnServer(comment);
          
          // Update local cache with server ID
          await _localDb.updateComment({
            'id': commentId,
            'serverId': serverCommentId,
            'synced': true,
          });
          
          return serverCommentId;
        } catch (e) {
          debugPrint('Error creating comment on server, queuing for sync: $e');
        }
      }
      
      // Add to sync queue
      await _addToSyncQueue('create_comment', commentId, comment.toMap());
      
      return commentId;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  /// Get cached posts from local database
  Future<List<PostModel>> _getPostsFromCache({
    int limit = 20,
    String? lastPostId,
    PostCategory? category,
  }) async {
    try {
      return await _localDb.getPosts(
        limit: limit,
        lastPostId: lastPostId,
        category: category,
      );
    } catch (e) {
      debugPrint('Error getting posts from cache: $e');
      return [];
    }
  }

  /// Get posts from server
  Future<List<PostModel>> _getPostsFromServer({
    int limit = 20,
    String? lastPostId,
    PostCategory? category,
  }) async {
    try {
      Query query = _firestore
          .collection('posts')
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true);

      if (category != null) {
        query = query.where('category', isEqualTo: category.toString());
      }

      if (lastPostId != null) {
        final lastDoc = await _firestore.collection('posts').doc(lastPostId).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting posts from server: $e');
      rethrow;
    }
  }

  /// Cache posts locally
  Future<void> _cachePostsLocally(List<PostModel> posts) async {
    try {
      for (final post in posts) {
        await _localDb.insertOrUpdatePost(post.copyWith(
          metadata: {'synced': true, 'cached_at': DateTime.now().toIso8601String()},
        ));
      }
    } catch (e) {
      debugPrint('Error caching posts locally: $e');
    }
  }

  /// Create post on server
  Future<String> _createPostOnServer(PostModel post) async {
    try {
      final docRef = await _firestore.collection('posts').add(post.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating post on server: $e');
      rethrow;
    }
  }

  /// Like post on server
  Future<void> _likePostOnServer(String postId, String userId, bool isLiked) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection('posts').doc(postId);
        final likeRef = postRef.collection('likes').doc(userId);
        
        final postDoc = await transaction.get(postRef);
        final likeDoc = await transaction.get(likeRef);
        
        if (!postDoc.exists) return;
        
        final currentLikes = postDoc.data()!['likesCount'] as int? ?? 0;
        
        if (isLiked && !likeDoc.exists) {
          // Add like
          transaction.set(likeRef, {
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {
            'likesCount': currentLikes + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (!isLiked && likeDoc.exists) {
          // Remove like
          transaction.delete(likeRef);
          transaction.update(postRef, {
            'likesCount': currentLikes - 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error liking post on server: $e');
      rethrow;
    }
  }

  /// Create comment on server
  Future<String> _createCommentOnServer(CommentModel comment) async {
    try {
      final docRef = await _firestore
          .collection('posts')
          .doc(comment.postId)
          .collection('comments')
          .add(comment.toMap());
      
      // Update post comment count
      await _firestore.collection('posts').doc(comment.postId).update({
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating comment on server: $e');
      rethrow;
    }
  }

  /// Add item to sync queue
  Future<void> _addToSyncQueue(String action, String itemId, Map<String, dynamic> data) async {
    try {
      await _localDb.insertSyncItem(SyncItem(
        id: '${action}_${itemId}_${DateTime.now().millisecondsSinceEpoch}',
        action: action,
        itemId: itemId,
        data: data,
        createdAt: DateTime.now(),
        attempts: 0,
        status: SyncStatus.pending,
      ));
    } catch (e) {
      debugPrint('Error adding to sync queue: $e');
    }
  }

  /// Start periodic sync
  void _startPeriodicSync() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline && !_isSyncing) {
        _triggerSync();
      }
    });
  }

  /// Trigger sync process
  Future<void> _triggerSync() async {
    if (_isSyncing || !_isOnline) return;

    try {
      _isSyncing = true;
      _syncStatusController.add(SyncStatus.syncing);

      // Sync pending items
      await _syncPendingItems();
      
      // Sync fresh content from server
      await _syncFreshContent();
      
      // Update last sync time
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());
      
      _syncStatusController.add(SyncStatus.completed);
      debugPrint('Sync completed successfully');
    } catch (e) {
      _syncStatusController.add(SyncStatus.failed);
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync pending items to server
  Future<void> _syncPendingItems() async {
    try {
      final pendingItems = await _localDb.getPendingSyncItems();
      
      for (final item in pendingItems) {
        try {
          await _processSyncItem(item);
          
          // Mark as completed
          await _localDb.updateSyncItem({
            'id': item.id,
            'status': SyncStatus.completed.toString(),
            'completedAt': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          // Increment attempts and mark as failed if max attempts reached
          final newAttempts = item.attempts + 1;
          if (newAttempts >= 3) {
            await _localDb.updateSyncItem({
              'id': item.id,
              'status': SyncStatus.failed.toString(),
              'attempts': newAttempts,
              'error': e.toString(),
            });
          } else {
            await _localDb.updateSyncItem({
              'id': item.id,
              'attempts': newAttempts,
              'lastAttemptAt': DateTime.now().toIso8601String(),
            });
          }
          
          debugPrint('Error syncing item ${item.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error syncing pending items: $e');
    }
  }

  /// Process individual sync item
  Future<void> _processSyncItem(SyncItem item) async {
    switch (item.action) {
      case 'create_post':
        final post = PostModel.fromMap(item.data);
        final serverPostId = await _createPostOnServer(post);
        
        // Update local post with server ID
        await _localDb.updatePost({
          'id': item.itemId,
          'serverId': serverPostId,
          'synced': true,
        });
        break;
        
      case 'like_post':
        await _likePostOnServer(
          item.itemId,
          item.data['userId'],
          item.data['isLiked'],
        );
        break;
        
      case 'create_comment':
        final comment = CommentModel.fromMap(item.data);
        final serverCommentId = await _createCommentOnServer(comment);
        
        // Update local comment with server ID
        await _localDb.updateComment({
          'id': item.itemId,
          'serverId': serverCommentId,
          'synced': true,
        });
        break;
        
      default:
        debugPrint('Unknown sync action: ${item.action}');
    }
  }

  /// Sync fresh content from server
  Future<void> _syncFreshContent() async {
    try {
      // Get posts updated since last sync
      DateTime? since = _lastSyncTime;
      since ??= DateTime.now().subtract(const Duration(days: 7));

      final query = _firestore
          .collection('posts')
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('updatedAt', descending: true)
          .limit(50);

      final snapshot = await query.get();
      final posts = snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
      
      // Cache fresh posts
      await _cachePostsLocally(posts);
      
      debugPrint('Synced ${posts.length} fresh posts');
    } catch (e) {
      debugPrint('Error syncing fresh content: $e');
    }
  }

  /// Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    try {
      return await _localDb.getSyncStats();
    } catch (e) {
      debugPrint('Error getting sync stats: $e');
      return {};
    }
  }

  /// Clear old cached data
  Future<void> clearOldCache({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      await _localDb.clearOldCache();
      debugPrint('Cleared cache older than $daysToKeep days');
    } catch (e) {
      debugPrint('Error clearing old cache: $e');
    }
  }

  /// Force sync now
  Future<void> forceSyncNow() async {
    if (_isOnline) {
      await _triggerSync();
    } else {
      throw Exception('Cannot sync while offline');
    }
  }

  /// Get offline storage usage
  Future<Map<String, dynamic>> getStorageUsage() async {
    try {
      return await _localDb.getStorageUsage();
    } catch (e) {
      debugPrint('Error getting storage usage: $e');
      return {};
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionController.close();
    _syncStatusController.close();
  }
}

// Sync status enum
enum SyncStatus {
  pending,
  syncing,
  completed,
  failed,
}

// Sync item model
class SyncItem {
  final String id;
  final String action;
  final String itemId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int attempts;
  final SyncStatus status;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final String? error;

  SyncItem({
    required this.id,
    required this.action,
    required this.itemId,
    required this.data,
    required this.createdAt,
    required this.attempts,
    required this.status,
    this.lastAttemptAt,
    this.completedAt,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'itemId': itemId,
      'data': jsonEncode(data),
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
      'status': status.toString(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'error': error,
    };
  }

  factory SyncItem.fromMap(Map<String, dynamic> map) {
    return SyncItem(
      id: map['id'],
      action: map['action'],
      itemId: map['itemId'],
      data: jsonDecode(map['data']),
      createdAt: DateTime.parse(map['createdAt']),
      attempts: map['attempts'],
      status: SyncStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => SyncStatus.pending,
      ),
      lastAttemptAt: map['lastAttemptAt'] != null 
          ? DateTime.parse(map['lastAttemptAt']) 
          : null,
      completedAt: map['completedAt'] != null 
          ? DateTime.parse(map['completedAt']) 
          : null,
      error: map['error'],
    );
  }
}
