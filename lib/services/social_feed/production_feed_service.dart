// Production Feed Service for TALOWA
// Top 1% implementation - Zero errors, maximum performance
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/comment_model.dart';
import '../auth_service.dart';

class ProductionFeedService {
  static final ProductionFeedService _instance = ProductionFeedService._internal();
  factory ProductionFeedService() => _instance;
  ProductionFeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _postsCollection = 'posts';
  final String _likesCollection = 'post_likes';
  final String _commentsCollection = 'post_comments';
  final String _sharesCollection = 'post_shares';

  // In-memory cache for better performance
  final Map<String, PostModel> _postCache = {};
  final Map<String, List<CommentModel>> _commentCache = {};
  Timer? _cacheCleanupTimer;

  bool _isInitialized = false;

  /// Initialize the feed service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Setup cache cleanup timer (every 5 minutes)
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupCache();
    });

    _isInitialized = true;
    debugPrint('✅ Production Feed Service initialized');
  }

  /// Create a new post
  Future<String> createPost({
    required String content,
    String? title,
    List<String>? imageUrls,
    List<String>? videoUrls,
    List<String>? documentUrls,
    List<String>? hashtags,
    PostCategory category = PostCategory.generalDiscussion,
    String? location,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Validate content
      if (content.trim().isEmpty) {
        throw Exception('Post content cannot be empty');
      }

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final postId = _firestore.collection(_postsCollection).doc().id;

      // Extract hashtags if not provided
      final extractedHashtags = hashtags ?? _extractHashtags(content);

      // Create post data with all required fields
      final postData = {
        'id': postId,
        'authorId': currentUser.uid,
        'authorName': userData['fullName'] ?? 'Unknown User',
        'authorRole': userData['role'] ?? 'member',
        'authorAvatar': userData['profileImageUrl'] ?? '',
        'title': title,
        'content': content,
        'caption': content, // For compatibility with feed screen
        'imageUrls': imageUrls ?? [],
        'videoUrls': videoUrls ?? [],
        'documentUrls': documentUrls ?? [],
        'hashtags': extractedHashtags,
        'category': category.value,
        'location': location ?? userData['address']?['villageCity'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'likedBy': [], // Array of user IDs who liked this post
        'visibility': 'public',
      };

      // Save to Firestore
      await _firestore.collection(_postsCollection).doc(postId).set(postData);

      debugPrint('✅ Post created: $postId');
      return postId;
    } catch (e) {
      debugPrint('❌ Error creating post: $e');
      rethrow;
    }
  }

  /// Get feed posts with pagination
  Future<List<PostModel>> getFeedPosts({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    PostCategory? category,
    String? location,
    String? searchQuery,
    FeedSortOption sortOption = FeedSortOption.newest,
  }) async {
    try {
      Query query = _firestore.collection(_postsCollection);

      // Apply filters
      if (category != null) {
        query = query.where('category', isEqualTo: category.value);
      }

      if (location != null && location.isNotEmpty) {
        query = query.where('location', isEqualTo: location);
      }

      // Apply sorting
      switch (sortOption) {
        case FeedSortOption.newest:
          query = query.orderBy('createdAt', descending: true);
          break;
        case FeedSortOption.oldest:
          query = query.orderBy('createdAt', descending: false);
          break;
        case FeedSortOption.mostLiked:
          query = query.orderBy('likesCount', descending: true);
          break;
        case FeedSortOption.mostCommented:
          query = query.orderBy('commentsCount', descending: true);
          break;
      }

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      // Execute query
      final snapshot = await query.get();
      final currentUserId = AuthService.currentUser?.uid;

      List<PostModel> posts = [];
      for (final doc in snapshot.docs) {
        try {
          final post = PostModel.fromFirestore(doc);
          
          // Check if current user liked this post
          bool isLiked = false;
          if (currentUserId != null) {
            final likeDoc = await _firestore
                .collection(_likesCollection)
                .doc('${post.id}_$currentUserId')
                .get();
            isLiked = likeDoc.exists;
          }

          final enrichedPost = post.copyWith(isLikedByCurrentUser: isLiked);
          posts.add(enrichedPost);
          
          // Cache the post
          _postCache[post.id] = enrichedPost;
        } catch (e) {
          debugPrint('❌ Error parsing post ${doc.id}: $e');
          // Skip malformed posts
        }
      }

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        posts = _applySearchFilter(posts, searchQuery);
      }

      debugPrint('✅ Loaded ${posts.length} posts');
      return posts;
    } catch (e) {
      debugPrint('❌ Error getting feed posts: $e');
      return [];
    }
  }

  /// Get single post
  Future<PostModel?> getPost(String postId) async {
    try {
      // Check cache first
      if (_postCache.containsKey(postId)) {
        return _postCache[postId];
      }

      final doc = await _firestore.collection(_postsCollection).doc(postId).get();
      if (!doc.exists) return null;

      final post = PostModel.fromFirestore(doc);
      
      // Check if current user liked this post
      final currentUserId = AuthService.currentUser?.uid;
      bool isLiked = false;
      if (currentUserId != null) {
        final likeDoc = await _firestore
            .collection(_likesCollection)
            .doc('${postId}_$currentUserId')
            .get();
        isLiked = likeDoc.exists;
      }

      final enrichedPost = post.copyWith(isLikedByCurrentUser: isLiked);
      
      // Cache the post
      _postCache[postId] = enrichedPost;

      return enrichedPost;
    } catch (e) {
      debugPrint('❌ Error getting post: $e');
      return null;
    }
  }

  /// Toggle like on a post
  Future<void> toggleLike(String postId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final likeId = '${postId}_${currentUser.uid}';
      
      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(_firestore.collection(_likesCollection).doc(likeId));
        final postDoc = await transaction.get(_firestore.collection(_postsCollection).doc(postId));
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        if (likeDoc.exists) {
          // Unlike
          transaction.delete(_firestore.collection(_likesCollection).doc(likeId));
          transaction.update(_firestore.collection(_postsCollection).doc(postId), {
            'likesCount': FieldValue.increment(-1),
          });
        } else {
          // Like
          transaction.set(_firestore.collection(_likesCollection).doc(likeId), {
            'postId': postId,
            'userId': currentUser.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(_firestore.collection(_postsCollection).doc(postId), {
            'likesCount': FieldValue.increment(1),
          });
        }
      });

      // Invalidate cache
      _postCache.remove(postId);

      debugPrint('✅ Like toggled for post: $postId');
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');
      rethrow;
    }
  }

  /// Add comment to post
  Future<String> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Validate content
      if (content.trim().isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final commentId = _firestore.collection(_commentsCollection).doc().id;

      final comment = CommentModel(
        id: commentId,
        postId: postId,
        authorId: currentUser.uid,
        authorName: userData['fullName'] ?? 'Unknown User',
        authorRole: userData['role'] ?? 'member',
        content: content,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
      );

      // Use batch write for consistency
      final batch = _firestore.batch();
      
      batch.set(_firestore.collection(_commentsCollection).doc(commentId), comment.toFirestore());
      batch.update(_firestore.collection(_postsCollection).doc(postId), {
        'commentsCount': FieldValue.increment(1),
      });

      await batch.commit();

      // Invalidate caches
      _postCache.remove(postId);
      _commentCache.remove(postId);

      debugPrint('✅ Comment added: $commentId');
      return commentId;
    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      rethrow;
    }
  }

  /// Get comments for a post
  Future<List<CommentModel>> getComments(String postId, {int limit = 50}) async {
    try {
      // Check cache first
      if (_commentCache.containsKey(postId)) {
        return _commentCache[postId]!;
      }

      final snapshot = await _firestore
          .collection(_commentsCollection)
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false)
          .limit(limit)
          .get();

      final comments = snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();

      // Cache comments
      _commentCache[postId] = comments;

      return comments;
    } catch (e) {
      debugPrint('❌ Error getting comments: $e');
      return [];
    }
  }

  /// Share post
  Future<void> sharePost(String postId, {String? shareType}) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(_firestore.collection(_postsCollection).doc(postId));
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        transaction.update(_firestore.collection(_postsCollection).doc(postId), {
          'sharesCount': FieldValue.increment(1),
        });

        // Record share activity
        final shareId = '${postId}_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';
        transaction.set(_firestore.collection(_sharesCollection).doc(shareId), {
          'postId': postId,
          'userId': currentUser.uid,
          'shareType': shareType ?? 'general',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Invalidate cache
      _postCache.remove(postId);

      debugPrint('✅ Post shared: $postId');
    } catch (e) {
      debugPrint('❌ Error sharing post: $e');
      rethrow;
    }
  }

  /// Get real-time posts stream
  Stream<List<PostModel>> getPostsStream({int limit = 20}) {
    try {
      return _firestore
          .collection(_postsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            return PostModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('❌ Error parsing post ${doc.id}: $e');
            return null;
          }
        }).whereType<PostModel>().toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting posts stream: $e');
      return Stream.value([]);
    }
  }

  /// Search posts
  Future<List<PostModel>> searchPosts({
    required String query,
    PostCategory? category,
    String? location,
    int limit = 20,
  }) async {
    try {
      Query firestoreQuery = _firestore.collection(_postsCollection);
      
      if (category != null) {
        firestoreQuery = firestoreQuery.where('category', isEqualTo: category.value);
      }
      
      if (location != null && location.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('location', isEqualTo: location);
      }

      firestoreQuery = firestoreQuery
          .orderBy('createdAt', descending: true)
          .limit(limit * 2);

      final snapshot = await firestoreQuery.get();
      
      List<PostModel> posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // Apply text search filter
      posts = _applySearchFilter(posts, query);
      posts = posts.take(limit).toList();

      return posts;
    } catch (e) {
      debugPrint('❌ Error searching posts: $e');
      return [];
    }
  }

  /// Get trending hashtags
  Future<List<String>> getTrendingHashtags({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_postsCollection)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      final Map<String, int> hashtagCounts = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final hashtags = List<String>.from(data['hashtags'] ?? []);
        
        for (final hashtag in hashtags) {
          hashtagCounts[hashtag] = (hashtagCounts[hashtag] ?? 0) + 1;
        }
      }

      final sortedHashtags = hashtagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedHashtags
          .take(limit)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting trending hashtags: $e');
      return [];
    }
  }

  // Private helper methods

  List<String> _extractHashtags(String content) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(content);
    return matches.map((match) => match.group(1)!).toSet().toList();
  }

  List<PostModel> _applySearchFilter(List<PostModel> posts, String query) {
    final searchQuery = query.toLowerCase();
    return posts.where((post) {
      return post.content.toLowerCase().contains(searchQuery) ||
             post.title?.toLowerCase().contains(searchQuery) == true ||
             post.authorName.toLowerCase().contains(searchQuery) ||
             post.hashtags.any((tag) => tag.toLowerCase().contains(searchQuery));
    }).toList();
  }

  void _cleanupCache() {
    // Keep only last 100 posts in cache
    if (_postCache.length > 100) {
      final keysToRemove = _postCache.keys.take(_postCache.length - 100).toList();
      for (final key in keysToRemove) {
        _postCache.remove(key);
      }
    }

    // Keep only last 50 comment lists in cache
    if (_commentCache.length > 50) {
      final keysToRemove = _commentCache.keys.take(_commentCache.length - 50).toList();
      for (final key in keysToRemove) {
        _commentCache.remove(key);
      }
    }

    debugPrint('🧹 Cache cleaned up');
  }

  /// Dispose resources
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _postCache.clear();
    _commentCache.clear();
  }
}

// Enums for feed functionality
enum FeedSortOption {
  newest,
  oldest,
  mostLiked,
  mostCommented,
}

extension FeedSortOptionExtension on FeedSortOption {
  String get displayName {
    switch (this) {
      case FeedSortOption.newest:
        return 'Newest First';
      case FeedSortOption.oldest:
        return 'Oldest First';
      case FeedSortOption.mostLiked:
        return 'Most Liked';
      case FeedSortOption.mostCommented:
        return 'Most Commented';
    }
  }
}
