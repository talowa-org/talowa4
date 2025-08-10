// Feed Service for TALOWA
// Fully functional social feed implementation with Firebase
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/post_model.dart';
import '../auth_service.dart';

class FeedService {
  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;
  FeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _postsCollection = 'posts';
  final String _likesCollection = 'post_likes';
  final String _commentsCollection = 'post_comments';

  // Create a new post
  Future<String> createPost({
    required String content,
    String? title,
    List<String>? mediaUrls,
    List<String>? hashtags,
    PostCategory category = PostCategory.generalDiscussion,
    String? location,
    bool isPublic = true,
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
        mediaUrls: mediaUrls ?? [],
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

      debugPrint('Post created successfully: $postId');
      return postId;
    } catch (e) {
      debugPrint('Error creating post: $e');
      rethrow;
    }
  }

  // Get feed posts with pagination and filters
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
        final data = doc.data() as Map<String, dynamic>;
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

      return posts;
    } catch (e) {
      debugPrint('Error getting feed posts: $e');
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
      debugPrint('Error getting post: $e');
      return null;
    }
  }

  // Like/Unlike post
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
    } catch (e) {
      debugPrint('Error toggling like: $e');
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

      return commentId;
    } catch (e) {
      debugPrint('Error adding comment: $e');
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
      debugPrint('Error getting comments: $e');
      return [];
    }
  }

  // Share post (increment share count)
  Future<void> sharePost(String postId) async {
    try {
      // Use a transaction to ensure the post exists before updating
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(_firestore.collection(_postsCollection).doc(postId));
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        transaction.update(_firestore.collection(_postsCollection).doc(postId), {
          'sharesCount': FieldValue.increment(1),
        });
      });
    } catch (e) {
      debugPrint('Error sharing post: $e');
      rethrow;
    }
  }

  // Delete post
  Future<void> deletePost(String postId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user owns the post
      final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data()!;
      if (postData['authorId'] != currentUser.uid) {
        throw Exception('Not authorized to delete this post');
      }

      // Delete the post
      await _firestore.collection(_postsCollection).doc(postId).delete();

      // Delete associated likes
      final likesSnapshot = await _firestore
          .collection(_likesCollection)
          .where('postId', isEqualTo: postId)
          .get();

      for (final doc in likesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete associated comments
      final commentsSnapshot = await _firestore
          .collection(_commentsCollection)
          .where('postId', isEqualTo: postId)
          .get();

      for (final doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting post: $e');
      rethrow;
    }
  }

  // Get trending hashtags
  Future<List<String>> getTrendingHashtags({int limit = 10}) async {
    try {
      // This is a simplified implementation
      // In a real app, you'd have a separate collection for hashtag analytics
      final snapshot = await _firestore
          .collection(_postsCollection)
          .orderBy('createdAt', descending: true)
          .limit(100)
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
      debugPrint('Error getting trending hashtags: $e');
      return [];
    }
  }

  // Search posts
  Future<List<PostModel>> searchPosts({
    required String query,
    int limit = 20,
  }) async {
    try {
      // This is a basic implementation
      // For better search, consider using Algolia or similar service
      final snapshot = await _firestore
          .collection(_postsCollection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final currentUserId = AuthService.currentUser?.uid;
      List<PostModel> posts = [];

      for (final doc in snapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        
        // Check if matches search query
        final searchQuery = query.toLowerCase();
        if (post.content.toLowerCase().contains(searchQuery) ||
            post.title?.toLowerCase().contains(searchQuery) == true ||
            post.authorName.toLowerCase().contains(searchQuery) ||
            post.hashtags.any((tag) => tag.toLowerCase().contains(searchQuery))) {
          
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

        if (posts.length >= limit) break;
      }

      return posts;
    } catch (e) {
      debugPrint('Error searching posts: $e');
      return [];
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