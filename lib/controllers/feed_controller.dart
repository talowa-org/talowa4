// Feed Controller with Pagination and Web Optimization
// Implements fixes from talowa_social_feed_fix.md

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/social_feed/post_model.dart';

class FeedController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<PostModel> _posts = [];
  QueryDocumentSnapshot? _lastPost;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  
  static const int _postsPerPage = 20;
  
  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  
  /// Fetch initial posts
  Future<void> fetchPosts({bool refresh = false}) async {
    if (_isLoading) return;
    
    if (refresh) {
      _posts.clear();
      _lastPost = null;
      _hasMore = true;
      _error = null;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      var query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_postsPerPage);
      
      if (_lastPost != null && !refresh) {
        query = query.startAfterDocument(_lastPost!);
      }
      
      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        _hasMore = false;
      } else {
        _lastPost = snapshot.docs.last;
        
        final newPosts = snapshot.docs.map((doc) {
          try {
            return PostModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('Error parsing post ${doc.id}: $e');
            return null;
          }
        }).whereType<PostModel>().toList();
        
        if (refresh) {
          _posts = newPosts;
        } else {
          _posts.addAll(newPosts);
        }
        
        if (newPosts.length < _postsPerPage) {
          _hasMore = false;
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching posts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load more posts (pagination)
  Future<void> loadMore() async {
    if (!_hasMore || _isLoading) return;
    await fetchPosts();
  }
  
  /// Refresh feed
  Future<void> refresh() async {
    await fetchPosts(refresh: true);
  }
  
  /// Like a post
  Future<void> likePost(String postId, String userId) async {
    try {
      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId);
      
      final likeDoc = await likeRef.get();
      
      if (likeDoc.exists) {
        // Unlike
        await likeRef.delete();
        await _firestore.collection('posts').doc(postId).update({
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        // Like
        await likeRef.set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('posts').doc(postId).update({
          'likesCount': FieldValue.increment(1),
        });
      }
      
      // Update local post
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        _posts[postIndex] = PostModel(
          id: post.id,
          authorId: post.authorId,
          authorName: post.authorName,
          authorAvatar: post.authorAvatar,
          content: post.content,
          imageUrls: post.imageUrls,
          videoUrl: post.videoUrl,
          likesCount: likeDoc.exists ? post.likesCount - 1 : post.likesCount + 1,
          commentsCount: post.commentsCount,
          sharesCount: post.sharesCount,
          createdAt: post.createdAt,
          location: post.location,
          category: post.category,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error liking post: $e');
      rethrow;
    }
  }
  
  /// Add a comment to a post
  Future<void> addComment(String postId, String userId, String userName, String content) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': userId,
        'userName': userName,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      });
      
      // Update local post
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        _posts[postIndex] = PostModel(
          id: post.id,
          authorId: post.authorId,
          authorName: post.authorName,
          authorAvatar: post.authorAvatar,
          content: post.content,
          imageUrls: post.imageUrls,
          videoUrl: post.videoUrl,
          likesCount: post.likesCount,
          commentsCount: post.commentsCount + 1,
          sharesCount: post.sharesCount,
          createdAt: post.createdAt,
          location: post.location,
          category: post.category,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }
  
  /// Create a new post
  Future<void> createPost({
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required String content,
    List<String>? imageUrls,
    String? videoUrl,
    String? location,
    String? category,
  }) async {
    try {
      await _firestore.collection('posts').add({
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'content': content,
        'imageUrls': imageUrls ?? [],
        'videoUrl': videoUrl,
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'location': location,
        'category': category,
      });
      
      // Refresh feed to show new post
      await refresh();
    } catch (e) {
      debugPrint('Error creating post: $e');
      rethrow;
    }
  }
}
