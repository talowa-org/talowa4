// Clean Feed Service for TALOWA
// Simplified, working implementation focused on core functionality
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/post_model.dart';
import '../auth_service.dart';

class CleanFeedService {
  static final CleanFeedService _instance = CleanFeedService._internal();
  factory CleanFeedService() => _instance;
  CleanFeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _postsCollection = 'posts';
  final String _likesCollection = 'post_likes';
  final String _commentsCollection = 'post_comments';

  // Create a new post
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

      // Get user profile for author info
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final postId = _firestore.collection(_postsCollection).doc().id;

      // Extract hashtags from content if not provided
      final extractedHashtags = hashtags ?? _extractHashtags(content);

      final post = PostModel(
        id: postId,
        authorId: currentUser.uid,
        authorName: userData['fullName'] ?? 'Unknown User',
        authorRole: userData['role'] ?? 'member',
        title: title,
        content: content,
        imageUrls: imageUrls ?? [],
        videoUrls: videoUrls ?? [],
        documentUrls: documentUrls ?? [],
        hashtags: extractedHashtags,
        category: category,
        location: location ?? userData['address']?['villageCity'] ?? '',
        createdAt: DateTime.now(),
        likesCount: 0,
        commentsCount: 0,
        sharesCount: 0,
        isLikedByCurrentUser: false,
      );

      // Save post to Firestore
      await _firestore.collection(_postsCollection).doc(postId).set(post.toFirestore());

      debugPrint('✅ Post created successfully: $postId');
      return postId;
    } catch (e) {
      debugPrint('❌ Error creating post: $e');
      rethrow;
    }
  }

  // Get feed posts with pagination
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

      final snapshot = await query.get();
      final currentUserId = AuthService.currentUser?.uid;

      List<PostModel> posts = [];
      for (final doc in snapshot.docs) {
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

        posts.add(post.copyWith(isLikedByCurrentUser: isLiked));
      }

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        posts = posts.where((post) {
          final query = searchQuery.toLowerCase();
          return post.content.toLowerCase().contains(query) ||
                 post.title?.toLowerCase().contains(query) == true ||
                 post.authorName.toLowerCase().contains(query) ||
                 post.hashtags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
      }

      debugPrint('✅ Loaded ${posts.length} posts');
      return posts;
    } catch (e) {
      debugPrint('❌ Error getting feed posts: $e');
      return [];
    }
  }

  // Get single post
  Future<PostModel?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection(_postsCollection).doc(postId).get();
      if (doc.exists) {
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

        return post.copyWith(isLikedByCurrentUser: isLiked);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting post: $e');
      return null;
    }
  }

  // Toggle like on a post
  Future<void> toggleLike(String postId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final likeId = '${postId}_${currentUser.uid}';
      
      // Use a transaction to ensure consistency
      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(_firestore.collection(_likesCollection).doc(likeId));
        final postDoc = await transaction.get(_firestore.collection(_postsCollection).doc(postId));
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        if (likeDoc.exists) {
          // Unlike the post
          transaction.delete(_firestore.collection(_likesCollection).doc(likeId));
          transaction.update(_firestore.collection(_postsCollection).doc(postId), {
            'likesCount': FieldValue.increment(-1),
          });
        } else {
          // Like the post
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

      debugPrint('✅ Like toggled for post: $postId');
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');
      rethrow;
    }
  }

  // Add comment to post
  Future<String> addComment({
    required String postId,
    required String content,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile for author info
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final commentId = _firestore.collection(_commentsCollection).doc().id;

      final comment = {
        'id': commentId,
        'postId': postId,
        'authorId': currentUser.uid,
        'authorName': userData['fullName'] ?? 'Unknown User',
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add comment
      await _firestore.collection(_commentsCollection).doc(commentId).set(comment);

      // Update post comment count
      await _firestore.collection(_postsCollection).doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      });

      debugPrint('✅ Comment added: $commentId');
      return commentId;
    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      rethrow;
    }
  }

  // Get comments for a post
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final snapshot = await _firestore
          .collection(_commentsCollection)
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': data['id'],
          'authorName': data['authorName'],
          'content': data['content'],
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting comments: $e');
      return [];
    }
  }

  // Share post (increment share count)
  Future<void> sharePost(String postId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(_firestore.collection(_postsCollection).doc(postId));
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        transaction.update(_firestore.collection(_postsCollection).doc(postId), {
          'sharesCount': FieldValue.increment(1),
        });
      });

      debugPrint('✅ Post shared: $postId');
    } catch (e) {
      debugPrint('❌ Error sharing post: $e');
      rethrow;
    }
  }

  // Get real-time posts stream
  Stream<List<PostModel>> getPostsStream({int limit = 20}) {
    try {
      return _firestore
          .collection(_postsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting posts stream: $e');
      return Stream.value([]);
    }
  }

  // Private helper methods
  List<String> _extractHashtags(String content) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(content);
    return matches.map((match) => match.group(1)!).toList();
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