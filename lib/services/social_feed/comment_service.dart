// Comment Service for TALOWA Instagram-like Comments
// Comprehensive comment management with real-time updates and nested replies
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/comment_model.dart';
import '../auth/auth_service.dart';
import '../cache/cache_service.dart';
import '../analytics/analytics_service.dart';

class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CacheService _cacheService = CacheService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Collections
  static const String _commentsCollection = 'comments';
  static const String _commentLikesCollection = 'comment_likes';

  // Cache keys
  static const String _commentsCachePrefix = 'post_comments_';
  static const String _userCommentLikesKey = 'user_comment_likes';

  // Stream controllers
  final Map<String, StreamController<List<CommentThread>>> _commentStreamControllers = {};
  final StreamController<String> _commentUpdateController = 
      StreamController<String>.broadcast();

  // Internal state
  final Map<String, List<CommentThread>> _cachedComments = {};
  Set<String> _userCommentLikes = {};
  bool _isInitialized = false;

  // Getters
  Stream<String> get commentUpdateStream => _commentUpdateController.stream;
  bool get isInitialized => _isInitialized;

  /// Initialize the comment service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadUserCommentLikes();
      _isInitialized = true;
      debugPrint('✅ Comment Service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Comment Service: $e');
      rethrow;
    }
  }

  /// Get comments stream for a specific post
  Stream<List<CommentThread>> getCommentsStream(String postId) {
    if (!_commentStreamControllers.containsKey(postId)) {
      _commentStreamControllers[postId] = StreamController<List<CommentThread>>.broadcast();
      _setupCommentsListener(postId);
    }
    return _commentStreamControllers[postId]!.stream;
  }

  /// Get comments for a post with pagination
  Future<List<CommentThread>> getComments(
    String postId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    CommentSortOption sortOption = CommentSortOption.newest,
    bool useCache = true,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      // Track analytics
      _analyticsService.trackEvent('comments_load_requested', {
        'post_id': postId,
        'limit': limit,
        'sort_option': sortOption.name,
      });

      final cacheKey = '$_commentsCachePrefix${postId}_${sortOption.name}';

      // Check cache first
      if (useCache && _cachedComments.containsKey(cacheKey)) {
        return _applyUserLikeStatus(_cachedComments[cacheKey]!);
      }

      // Build query for top-level comments only
      Query query = _firestore
          .collection(_commentsCollection)
          .where('postId', isEqualTo: postId)
          .where('parentCommentId', isNull: true);

      // Apply sorting
      switch (sortOption) {
        case CommentSortOption.newest:
          query = query.orderBy('createdAt', descending: true);
          break;
        case CommentSortOption.oldest:
          query = query.orderBy('createdAt', descending: false);
          break;
        case CommentSortOption.mostLiked:
          query = query.orderBy('likesCount', descending: true);
          break;
        case CommentSortOption.mostReplies:
          query = query.orderBy('repliesCount', descending: true);
          break;
      }

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      query = query.limit(limit);

      // Execute query
      final querySnapshot = await query.get();
      
      final comments = querySnapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();

      // Build comment threads with replies
      final commentThreads = <CommentThread>[];
      
      for (final comment in comments) {
        // Get replies for this comment (limited to 3 most recent)
        final repliesQuery = await _firestore
            .collection(_commentsCollection)
            .where('parentCommentId', isEqualTo: comment.id)
            .orderBy('createdAt', descending: false)
            .limit(3)
            .get();

        final replies = repliesQuery.docs
            .map((doc) => CommentModel.fromFirestore(doc))
            .toList();

        final thread = CommentThread(
          parentComment: comment,
          replies: replies,
          hasMoreReplies: comment.repliesCount > replies.length,
          totalRepliesCount: comment.repliesCount,
        );

        commentThreads.add(thread);
      }

      // Apply user like status
      final enrichedThreads = _applyUserLikeStatus(commentThreads);

      // Update cache
      _cachedComments[cacheKey] = enrichedThreads;
      await _cacheResults(cacheKey, enrichedThreads);

      // Emit to stream
      if (_commentStreamControllers.containsKey(postId)) {
        _commentStreamControllers[postId]!.add(enrichedThreads);
      }

      // Track analytics
      _analyticsService.trackEvent('comments_loaded', {
        'post_id': postId,
        'comments_count': enrichedThreads.length,
      });

      debugPrint('✅ Loaded ${enrichedThreads.length} comment threads for post $postId');
      return enrichedThreads;

    } catch (e) {
      debugPrint('❌ Failed to load comments: $e');
      _analyticsService.trackEvent('comments_load_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Get replies for a specific comment
  Future<List<CommentModel>> getReplies(
    String commentId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_commentsCollection)
          .where('parentCommentId', isEqualTo: commentId)
          .orderBy('createdAt', descending: false);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      query = query.limit(limit);

      final querySnapshot = await query.get();
      
      final replies = querySnapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();

      // Apply user like status
      final enrichedReplies = replies.map((reply) => reply.copyWith(
        isLikedByCurrentUser: _userCommentLikes.contains(reply.id),
      )).toList();

      debugPrint('✅ Loaded ${enrichedReplies.length} replies for comment $commentId');
      return enrichedReplies;

    } catch (e) {
      debugPrint('❌ Failed to load replies: $e');
      rethrow;
    }
  }

  /// Add a new comment
  Future<String> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Validate content
      final validation = CommentModel.validateContent(content);
      if (validation != null) throw Exception(validation);

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) throw Exception('User profile not found');

      final userData = userDoc.data()!;
      final commentId = _firestore.collection(_commentsCollection).doc().id;

      // Extract mentions
      final mentionedUserIds = CommentModel.extractMentions(content);

      // Create comment model
      final comment = CommentModel(
        id: commentId,
        postId: postId,
        authorId: currentUser.uid,
        authorName: userData['fullName'] ?? 'Unknown User',
        authorProfileImageUrl: userData['profileImageUrl'],
        authorRole: userData['role'],
        content: content,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
        mentionedUserIds: mentionedUserIds,
        isAuthorVerified: userData['isVerified'] ?? false,
      );

      // Use batch write for consistency
      final batch = _firestore.batch();
      
      // Add comment
      batch.set(_firestore.collection(_commentsCollection).doc(commentId), 
          comment.toFirestore());
      
      // Update post comment count
      batch.update(_firestore.collection('posts').doc(postId), {
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If this is a reply, update parent comment reply count
      if (parentCommentId != null) {
        batch.update(_firestore.collection(_commentsCollection).doc(parentCommentId), {
          'repliesCount': FieldValue.increment(1),
        });
      }

      await batch.commit();

      // Invalidate caches
      await _invalidateCommentCaches(postId);

      // Send notifications for mentions
      if (mentionedUserIds.isNotEmpty) {
        _sendMentionNotifications(mentionedUserIds, comment);
      }

      // Track analytics
      _analyticsService.trackEvent('comment_added', {
        'post_id': postId,
        'comment_id': commentId,
        'is_reply': parentCommentId != null,
        'mentions_count': mentionedUserIds.length,
      });

      // Emit update
      _commentUpdateController.add(commentId);

      debugPrint('✅ Comment added successfully: $commentId');
      return commentId;

    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      _analyticsService.trackEvent('comment_add_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Edit a comment
  Future<void> editComment(String commentId, String newContent) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Validate content
      final validation = CommentModel.validateContent(newContent);
      if (validation != null) throw Exception(validation);

      // Verify ownership
      final commentDoc = await _firestore.collection(_commentsCollection).doc(commentId).get();
      if (!commentDoc.exists) throw Exception('Comment not found');

      final commentData = commentDoc.data()!;
      if (commentData['authorId'] != currentUser.uid) {
        throw Exception('You can only edit your own comments');
      }

      // Extract new mentions
      final mentionedUserIds = CommentModel.extractMentions(newContent);

      // Update comment
      await _firestore.collection(_commentsCollection).doc(commentId).update({
        'content': newContent,
        'editedAt': FieldValue.serverTimestamp(),
        'mentionedUserIds': mentionedUserIds,
      });

      // Invalidate caches
      final postId = commentData['postId'];
      await _invalidateCommentCaches(postId);

      // Track analytics
      _analyticsService.trackEvent('comment_edited', {
        'comment_id': commentId,
        'post_id': postId,
      });

      // Emit update
      _commentUpdateController.add(commentId);

      debugPrint('✅ Comment edited successfully: $commentId');

    } catch (e) {
      debugPrint('❌ Error editing comment: $e');
      rethrow;
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get comment data
      final commentDoc = await _firestore.collection(_commentsCollection).doc(commentId).get();
      if (!commentDoc.exists) throw Exception('Comment not found');

      final commentData = commentDoc.data()!;
      final postId = commentData['postId'];
      final parentCommentId = commentData['parentCommentId'];
      final isReply = parentCommentId != null;

      // Verify ownership or admin privileges
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final isAdmin = userData['role'] == 'admin' || userData['role'] == 'superAdmin';
      
      if (commentData['authorId'] != currentUser.uid && !isAdmin) {
        throw Exception('You can only delete your own comments');
      }

      // Get replies count for this comment
      final repliesQuery = await _firestore
          .collection(_commentsCollection)
          .where('parentCommentId', isEqualTo: commentId)
          .get();

      final repliesCount = repliesQuery.docs.length;

      // Use batch write for consistency
      final batch = _firestore.batch();

      // Delete the comment
      batch.delete(_firestore.collection(_commentsCollection).doc(commentId));

      // Delete all replies
      for (final replyDoc in repliesQuery.docs) {
        batch.delete(replyDoc.reference);
      }

      // Update post comment count
      batch.update(_firestore.collection('posts').doc(postId), {
        'commentsCount': FieldValue.increment(-(1 + repliesCount)),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If this is a reply, update parent comment reply count
      if (isReply) {
        batch.update(_firestore.collection(_commentsCollection).doc(parentCommentId), {
          'repliesCount': FieldValue.increment(-1),
        });
      }

      await batch.commit();

      // Delete comment likes
      final likesQuery = await _firestore
          .collection(_commentLikesCollection)
          .where('commentId', isEqualTo: commentId)
          .get();

      final likesBatch = _firestore.batch();
      for (final likeDoc in likesQuery.docs) {
        likesBatch.delete(likeDoc.reference);
      }
      await likesBatch.commit();

      // Invalidate caches
      await _invalidateCommentCaches(postId);

      // Track analytics
      _analyticsService.trackEvent('comment_deleted', {
        'comment_id': commentId,
        'post_id': postId,
        'replies_deleted': repliesCount,
      });

      // Emit update
      _commentUpdateController.add(commentId);

      debugPrint('✅ Comment deleted successfully: $commentId');

    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
      rethrow;
    }
  }

  /// Toggle like on a comment
  Future<void> toggleCommentLike(String commentId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final likeId = '${commentId}_${currentUser.uid}';
      
      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(
            _firestore.collection(_commentLikesCollection).doc(likeId));
        final commentDoc = await transaction.get(
            _firestore.collection(_commentsCollection).doc(commentId));
        
        if (!commentDoc.exists) throw Exception('Comment not found');

        if (likeDoc.exists) {
          // Unlike the comment
          transaction.delete(_firestore.collection(_commentLikesCollection).doc(likeId));
          transaction.update(_firestore.collection(_commentsCollection).doc(commentId), {
            'likesCount': FieldValue.increment(-1),
          });
          _userCommentLikes.remove(commentId);
        } else {
          // Like the comment
          transaction.set(_firestore.collection(_commentLikesCollection).doc(likeId), {
            'commentId': commentId,
            'userId': currentUser.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(_firestore.collection(_commentsCollection).doc(commentId), {
            'likesCount': FieldValue.increment(1),
          });
          _userCommentLikes.add(commentId);
        }
      });

      // Track analytics
      _analyticsService.trackEvent('comment_like_toggled', {
        'comment_id': commentId,
        'is_liked': _userCommentLikes.contains(commentId),
      });

      // Emit update
      _commentUpdateController.add(commentId);

    } catch (e) {
      debugPrint('❌ Error toggling comment like: $e');
      rethrow;
    }
  }

  /// Pin/unpin a comment (for post authors)
  Future<void> toggleCommentPin(String commentId, String postId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Verify post ownership
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final postData = postDoc.data()!;
      if (postData['authorId'] != currentUser.uid) {
        throw Exception('Only post authors can pin comments');
      }

      // Get comment data
      final commentDoc = await _firestore.collection(_commentsCollection).doc(commentId).get();
      if (!commentDoc.exists) throw Exception('Comment not found');

      final commentData = commentDoc.data()!;
      final isPinned = commentData['isPinned'] ?? false;

      // Update comment
      await _firestore.collection(_commentsCollection).doc(commentId).update({
        'isPinned': !isPinned,
      });

      // Invalidate caches
      await _invalidateCommentCaches(postId);

      // Track analytics
      _analyticsService.trackEvent('comment_pin_toggled', {
        'comment_id': commentId,
        'post_id': postId,
        'is_pinned': !isPinned,
      });

      // Emit update
      _commentUpdateController.add(commentId);

      debugPrint('✅ Comment pin toggled: $commentId');

    } catch (e) {
      debugPrint('❌ Error toggling comment pin: $e');
      rethrow;
    }
  }

  // Private helper methods

  void _setupCommentsListener(String postId) {
    _firestore
        .collection(_commentsCollection)
        .where('postId', isEqualTo: postId)
        .snapshots()
        .listen(
      (snapshot) {
        // Refresh comments when changes occur
        getComments(postId, useCache: false);
      },
      onError: (error) {
        debugPrint('❌ Comments real-time listener error: $error');
      },
    );
  }

  Future<void> _loadUserCommentLikes() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      final likesQuery = await _firestore
          .collection(_commentLikesCollection)
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      _userCommentLikes = likesQuery.docs
          .map((doc) => doc.data()['commentId'] as String)
          .toSet();

      debugPrint('✅ Loaded ${_userCommentLikes.length} comment likes');

    } catch (e) {
      debugPrint('❌ Failed to load user comment likes: $e');
    }
  }

  List<CommentThread> _applyUserLikeStatus(List<CommentThread> threads) {
    return threads.map((thread) {
      final updatedParent = thread.parentComment.copyWith(
        isLikedByCurrentUser: _userCommentLikes.contains(thread.parentComment.id),
      );
      
      final updatedReplies = thread.replies.map((reply) => reply.copyWith(
        isLikedByCurrentUser: _userCommentLikes.contains(reply.id),
      )).toList();

      return thread.copyWith(
        parentComment: updatedParent,
        replies: updatedReplies,
      );
    }).toList();
  }

  Future<void> _cacheResults(String key, List<CommentThread> threads) async {
    try {
      final cacheData = {
        'threads': threads.map((thread) => {
          'parentComment': thread.parentComment.toFirestore(),
          'replies': thread.replies.map((reply) => reply.toFirestore()).toList(),
          'hasMoreReplies': thread.hasMoreReplies,
          'totalRepliesCount': thread.totalRepliesCount,
        }).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _cacheService.set(key, cacheData, 
          expiry: const Duration(minutes: 10));
    } catch (e) {
      debugPrint('❌ Failed to cache comments: $e');
    }
  }

  Future<void> _invalidateCommentCaches(String postId) async {
    try {
      // Remove all cache entries for this post
      final keysToRemove = _cachedComments.keys
          .where((key) => key.contains(postId))
          .toList();

      for (final key in keysToRemove) {
        await _cacheService.remove(key);
        _cachedComments.remove(key);
      }

      debugPrint('✅ Comment caches invalidated for post $postId');
    } catch (e) {
      debugPrint('❌ Failed to invalidate comment caches: $e');
    }
  }

  void _sendMentionNotifications(List<String> mentionedUserIds, CommentModel comment) {
    // TODO: Implement push notifications for mentions
    // This would integrate with your notification service
    debugPrint('📢 Sending mention notifications to ${mentionedUserIds.length} users');
  }

  /// Clear all caches
  Future<void> clearCache() async {
    try {
      _cachedComments.clear();
      _userCommentLikes.clear();
      
      // Clear all comment-related cache entries
      await _cacheService.remove(_userCommentLikesKey);

      debugPrint('✅ Comment caches cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear comment caches: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    for (final controller in _commentStreamControllers.values) {
      controller.close();
    }
    _commentStreamControllers.clear();
    _commentUpdateController.close();
    _isInitialized = false;
  }
}