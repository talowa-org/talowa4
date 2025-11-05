// Instagram-style Feed Service for TALOWA
// Modern social media feed service with advanced features
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../auth/auth_service.dart';
import '../cache/cache_service.dart';
import '../analytics/analytics_service.dart';

class InstagramFeedService {
  static final InstagramFeedService _instance = InstagramFeedService._internal();
  factory InstagramFeedService() => _instance;
  InstagramFeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CacheService _cacheService = CacheService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Cache keys
  static const String _feedCacheKey = 'instagram_feed_cache';
  static const String _userLikesCacheKey = 'user_likes_cache';
  static const String _userBookmarksCacheKey = 'user_bookmarks_cache';

  // Feed algorithm parameters
  static const int _defaultPageSize = 10;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Stream controllers for real-time updates
  final StreamController<List<InstagramPostModel>> _feedStreamController = 
      StreamController<List<InstagramPostModel>>.broadcast();
  final StreamController<String> _postUpdateController = 
      StreamController<String>.broadcast();

  // Internal state
  List<InstagramPostModel> _cachedFeed = [];
  Set<String> _userLikes = {};
  Set<String> _userBookmarks = {};
  DocumentSnapshot? _lastDocument;
  bool _hasMorePosts = true;
  bool _isInitialized = false;

  // Getters
  Stream<List<InstagramPostModel>> get feedStream => _feedStreamController.stream;
  Stream<String> get postUpdateStream => _postUpdateController.stream;
  bool get hasMorePosts => _hasMorePosts;
  bool get isInitialized => _isInitialized;

  /// Initialize the feed service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadUserEngagementData();
      _isInitialized = true;
      debugPrint('✅ Instagram Feed Service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Instagram Feed Service: $e');
      rethrow;
    }
  }

  /// Get personalized feed with infinite scroll support
  Future<List<InstagramPostModel>> getFeed({
    int limit = _defaultPageSize,
    bool refresh = false,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      // Track analytics
      _analyticsService.trackEvent('feed_load_requested', {
        'limit': limit,
        'refresh': refresh,
        'has_start_after': startAfter != null,
      });

      // Handle refresh
      if (refresh) {
        _cachedFeed.clear();
        _lastDocument = null;
        _hasMorePosts = true;
      }

      // Use cached data if available and not refreshing
      if (!refresh && _cachedFeed.isNotEmpty && startAfter == null) {
        return _applyUserEngagementData(_cachedFeed.take(limit).toList());
      }

      // Build query with personalization
      Query query = _buildPersonalizedQuery();

      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      } else if (_lastDocument != null && !refresh) {
        query = query.startAfterDocument(_lastDocument!);
      }

      query = query.limit(limit);

      // Execute query
      final querySnapshot = await query.get();
      
      debugPrint('🔍 Feed Query Results: Found ${querySnapshot.docs.length} documents');
      
      // Convert to models - handle both old PostModel and new InstagramPostModel
      final posts = querySnapshot.docs
          .map((doc) => _convertToInstagramPost(doc))
          .where((post) => post != null)
          .cast<InstagramPostModel>()
          .toList();
          
      debugPrint('✅ Converted ${posts.length} posts successfully');

      // Apply user engagement data
      final enrichedPosts = _applyUserEngagementData(posts);

      // Update cache and state
      if (refresh || startAfter == null) {
        _cachedFeed = enrichedPosts;
      } else {
        _cachedFeed.addAll(enrichedPosts);
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
      }

      _hasMorePosts = querySnapshot.docs.length == limit;

      // Cache the results
      await _cacheResults(enrichedPosts);

      // Emit to stream
      _feedStreamController.add(_cachedFeed);

      // Track analytics
      _analyticsService.trackEvent('feed_loaded', {
        'posts_count': enrichedPosts.length,
        'has_more': _hasMorePosts,
        'cache_size': _cachedFeed.length,
      });

      debugPrint('✅ Loaded ${enrichedPosts.length} posts, hasMore: $_hasMorePosts');
      return enrichedPosts;

    } catch (e) {
      debugPrint('❌ Failed to load feed: $e');
      _analyticsService.trackEvent('feed_load_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Get trending posts
  Future<List<InstagramPostModel>> getTrendingPosts({int limit = 20}) async {
    try {
      final query = _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
          .orderBy('createdAt', descending: true)
          .orderBy('likesCount', descending: true)
          .orderBy('commentsCount', descending: true)
          .limit(limit);

      final querySnapshot = await query.get();
      final posts = querySnapshot.docs
          .map((doc) => InstagramPostModel.fromFirestore(doc))
          .toList();

      return _applyUserEngagementData(posts);
    } catch (e) {
      debugPrint('❌ Failed to load trending posts: $e');
      rethrow;
    }
  }

  /// Like/unlike a post
  Future<void> toggleLike(String postId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final postRef = _firestore.collection('posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(currentUser.uid);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        final likeDoc = await transaction.get(likeRef);

        if (!postDoc.exists) throw Exception('Post not found');

        final currentLikes = postDoc.data()?['likesCount'] ?? 0;
        final isLiked = likeDoc.exists;

        if (isLiked) {
          // Unlike
          transaction.delete(likeRef);
          transaction.update(postRef, {'likesCount': currentLikes - 1});
          _userLikes.remove(postId);
        } else {
          // Like
          transaction.set(likeRef, {
            'userId': currentUser.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {'likesCount': currentLikes + 1});
          _userLikes.add(postId);
        }
      });

      // Update cached post
      _updateCachedPost(postId, (post) => post.copyWith(
        isLikedByCurrentUser: !post.isLikedByCurrentUser,
        likesCount: post.isLikedByCurrentUser 
            ? post.likesCount - 1 
            : post.likesCount + 1,
      ));

      // Track analytics
      _analyticsService.trackEvent('post_like_toggled', {
        'post_id': postId,
        'is_liked': _userLikes.contains(postId),
      });

      // Emit update
      _postUpdateController.add(postId);

    } catch (e) {
      debugPrint('❌ Failed to toggle like: $e');
      rethrow;
    }
  }

  /// Bookmark/unbookmark a post
  Future<void> toggleBookmark(String postId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final bookmarkRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .doc(postId);

      final bookmarkDoc = await bookmarkRef.get();
      final isBookmarked = bookmarkDoc.exists;

      if (isBookmarked) {
        await bookmarkRef.delete();
        _userBookmarks.remove(postId);
      } else {
        await bookmarkRef.set({
          'postId': postId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _userBookmarks.add(postId);
      }

      // Update cached post
      _updateCachedPost(postId, (post) => post.copyWith(
        isBookmarkedByCurrentUser: !post.isBookmarkedByCurrentUser,
      ));

      // Track analytics
      _analyticsService.trackEvent('post_bookmark_toggled', {
        'post_id': postId,
        'is_bookmarked': _userBookmarks.contains(postId),
      });

      // Emit update
      _postUpdateController.add(postId);

    } catch (e) {
      debugPrint('❌ Failed to toggle bookmark: $e');
      rethrow;
    }
  }

  /// Increment view count for a post
  Future<void> incrementViewCount(String postId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      await postRef.update({'viewsCount': FieldValue.increment(1)});

      // Track analytics
      _analyticsService.trackEvent('post_viewed', {'post_id': postId});

    } catch (e) {
      debugPrint('❌ Failed to increment view count: $e');
      // Don't rethrow for view count errors
    }
  }

  /// Report a post
  Future<void> reportPost(String postId, String reason) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await _firestore.collection('reports').add({
        'postId': postId,
        'reportedBy': currentUser.uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Track analytics
      _analyticsService.trackEvent('post_reported', {
        'post_id': postId,
        'reason': reason,
      });

    } catch (e) {
      debugPrint('❌ Failed to report post: $e');
      rethrow;
    }
  }

  /// Search posts by hashtag
  Future<List<InstagramPostModel>> searchByHashtag(String hashtag, {int limit = 20}) async {
    try {
      final query = _firestore
          .collection('posts')
          .where('hashtags', arrayContains: hashtag.toLowerCase())
          .orderBy('createdAt', descending: true)
          .limit(limit);

      final querySnapshot = await query.get();
      final posts = querySnapshot.docs
          .map((doc) => InstagramPostModel.fromFirestore(doc))
          .toList();

      return _applyUserEngagementData(posts);
    } catch (e) {
      debugPrint('❌ Failed to search by hashtag: $e');
      rethrow;
    }
  }

  /// Get user's bookmarked posts
  Future<List<InstagramPostModel>> getBookmarkedPosts({int limit = 20}) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final bookmarksQuery = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final postIds = bookmarksQuery.docs.map((doc) => doc.id).toList();
      if (postIds.isEmpty) return [];

      final postsQuery = await _firestore
          .collection('posts')
          .where(FieldPath.documentId, whereIn: postIds)
          .get();

      final posts = postsQuery.docs
          .map((doc) => InstagramPostModel.fromFirestore(doc))
          .toList();

      return _applyUserEngagementData(posts);
    } catch (e) {
      debugPrint('❌ Failed to get bookmarked posts: $e');
      rethrow;
    }
  }

  /// Build personalized query based on user preferences and engagement
  Query _buildPersonalizedQuery() {
    // Basic query - load all posts and filter in code if needed
    // This ensures we get both old and new format posts
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true);
  }

  /// Convert old PostModel or new InstagramPostModel from Firestore
  InstagramPostModel? _convertToInstagramPost(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('⚠️ Post ${doc.id} has no data');
        return null;
      }

      debugPrint('🔄 Converting post ${doc.id} with keys: ${data.keys.toList()}');

      // Check if this is already an InstagramPostModel
      if (data.containsKey('mediaItems')) {
        debugPrint('📱 Post ${doc.id} is already InstagramPostModel format');
        return InstagramPostModel.fromFirestore(doc);
      }

      // Convert old PostModel to InstagramPostModel
      debugPrint('🔄 Converting old PostModel ${doc.id} to InstagramPostModel');
      return _convertOldPostToInstagram(doc, data);
    } catch (e) {
      debugPrint('❌ Error converting post ${doc.id}: $e');
      return null;
    }
  }

  /// Convert old PostModel format to InstagramPostModel
  InstagramPostModel _convertOldPostToInstagram(DocumentSnapshot doc, Map<String, dynamic> data) {
    // Extract media items from old format
    final List<MediaItem> mediaItems = [];
    
    // Handle old imageUrls
    final imageUrls = List<String>.from(data['imageUrls'] ?? []);
    debugPrint('📸 Found ${imageUrls.length} images in post ${doc.id}');
    for (int i = 0; i < imageUrls.length; i++) {
      mediaItems.add(MediaItem(
        id: '${doc.id}_image_$i',
        type: MediaType.image,
        url: imageUrls[i],
        altText: data['altText'],
      ));
    }

    // Handle old videoUrls
    final videoUrls = List<String>.from(data['videoUrls'] ?? []);
    debugPrint('🎥 Found ${videoUrls.length} videos in post ${doc.id}');
    for (int i = 0; i < videoUrls.length; i++) {
      mediaItems.add(MediaItem(
        id: '${doc.id}_video_$i',
        type: MediaType.video,
        url: videoUrls[i],
        altText: data['altText'],
      ));
    }

    // Handle legacy mediaUrls (could be mixed)
    final legacyMediaUrls = List<String>.from(data['mediaUrls'] ?? []);
    debugPrint('📁 Found ${legacyMediaUrls.length} legacy media items in post ${doc.id}');
    for (int i = 0; i < legacyMediaUrls.length; i++) {
      final url = legacyMediaUrls[i];
      final isVideo = url.contains('.mp4') || url.contains('.mov') || url.contains('.avi') || url.contains('video');
      
      mediaItems.add(MediaItem(
        id: '${doc.id}_legacy_$i',
        type: isVideo ? MediaType.video : MediaType.image,
        url: url,
        altText: data['altText'],
      ));
    }

    debugPrint('✅ Created ${mediaItems.length} media items for post ${doc.id}');

    return InstagramPostModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorProfileImageUrl: null, // Not available in old format
      caption: data['content'] ?? '',
      mediaItems: mediaItems,
      hashtags: List<String>.from(data['hashtags'] ?? []),
      userTags: [], // Not available in old format
      locationTag: data['location'] != null && data['location'].toString().isNotEmpty
          ? LocationTag(
              id: 'location_${doc.id}',
              name: data['location'].toString(),
            )
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      viewsCount: 0, // Not available in old format
      allowComments: true, // Default for old posts
      allowSharing: true, // Default for old posts
      visibility: PostVisibility.public, // Default for old posts
      mentionedUserIds: [], // Not available in old format
      altText: data['altText'],
    );
  }

  /// Load user engagement data (likes, bookmarks)
  Future<void> _loadUserEngagementData() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Load likes
      final likesQuery = await _firestore
          .collectionGroup('likes')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      _userLikes = likesQuery.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toSet();

      // Load bookmarks
      final bookmarksQuery = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .get();

      _userBookmarks = bookmarksQuery.docs
          .map((doc) => doc.id)
          .toSet();

      debugPrint('✅ Loaded user engagement: ${_userLikes.length} likes, ${_userBookmarks.length} bookmarks');

    } catch (e) {
      debugPrint('❌ Failed to load user engagement data: $e');
    }
  }

  /// Apply user engagement data to posts
  List<InstagramPostModel> _applyUserEngagementData(List<InstagramPostModel> posts) {
    return posts.map((post) => post.copyWith(
      isLikedByCurrentUser: _userLikes.contains(post.id),
      isBookmarkedByCurrentUser: _userBookmarks.contains(post.id),
    )).toList();
  }

  /// Update a cached post
  void _updateCachedPost(String postId, InstagramPostModel Function(InstagramPostModel) updater) {
    final index = _cachedFeed.indexWhere((post) => post.id == postId);
    if (index != -1) {
      _cachedFeed[index] = updater(_cachedFeed[index]);
      _feedStreamController.add(_cachedFeed);
    }
  }

  /// Cache results for offline access
  Future<void> _cacheResults(List<InstagramPostModel> posts) async {
    try {
      final cacheData = {
        'posts': posts.map((post) => post.toFirestore()).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _cacheService.set(_feedCacheKey, cacheData, expiry: _cacheExpiry);
    } catch (e) {
      debugPrint('❌ Failed to cache results: $e');
    }
  }

  /// Clear all caches
  Future<void> clearCache() async {
    try {
      await _cacheService.remove(_feedCacheKey);
      await _cacheService.remove(_userLikesCacheKey);
      await _cacheService.remove(_userBookmarksCacheKey);
      
      _cachedFeed.clear();
      _userLikes.clear();
      _userBookmarks.clear();
      _lastDocument = null;
      _hasMorePosts = true;

      debugPrint('✅ Feed cache cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear cache: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _feedStreamController.close();
    _postUpdateController.close();
    _isInitialized = false;
  }
}