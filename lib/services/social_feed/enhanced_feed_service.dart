// Enhanced Feed Service for TALOWA
// Fully functional social feed with advanced database integration
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/comment_model.dart';
import '../auth_service.dart';
import '../performance/cache_service.dart';
import '../performance/advanced_cache_service.dart';
import '../performance/cache_partition_service.dart';
import '../performance/cache_monitoring_service.dart';
import '../performance/cache_failover_service.dart';
import '../performance/network_optimization_service.dart';
import '../performance/performance_monitoring_service.dart';
import '../performance/database_optimization_service.dart';
import '../ai/ai_moderation_service.dart';
import '../../models/ai/moderation_models.dart';

class EnhancedFeedService {
  static final EnhancedFeedService _instance = EnhancedFeedService._internal();
  factory EnhancedFeedService() => _instance;
  EnhancedFeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _postsCollection = 'posts';
  final String _likesCollection = 'post_likes';
  final String _commentsCollection = 'post_comments';
  final String _sharesCollection = 'post_shares';

  // Performance services
  late CacheService _cacheService;
  late AdvancedCacheService _advancedCacheService;
  late CachePartitionService _partitionService;
  late CacheMonitoringService _cacheMonitoringService;
  late CacheFailoverService _failoverService;
  late NetworkOptimizationService _networkService;
  late PerformanceMonitoringService _performanceService;
  late DatabaseOptimizationService _databaseService;
  late AIModerationService _moderationService;

  // Real-time listeners
  StreamSubscription<QuerySnapshot>? _postsListener;
  final StreamController<List<PostModel>> _postsStreamController = 
      StreamController<List<PostModel>>.broadcast();

  bool _isInitialized = false;

  /// Initialize the enhanced feed service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _cacheService = CacheService.instance;
    _advancedCacheService = AdvancedCacheService.instance;
    _partitionService = CachePartitionService.instance;
    _cacheMonitoringService = CacheMonitoringService.instance;
    _failoverService = CacheFailoverService.instance;
    _networkService = NetworkOptimizationService.instance;
    _performanceService = PerformanceMonitoringService.instance;
    _databaseService = DatabaseOptimizationService.instance;
    _moderationService = AIModerationService();

    // Initialize cache services
    await _cacheService.initialize();
    await _advancedCacheService.initialize();
    await _partitionService.initialize();
    await _cacheMonitoringService.initialize();
    await _failoverService.initialize();
    await _moderationService.initialize();

    // Configure advanced cache for feed data
    _advancedCacheService.configure(
      maxL1Size: 50 * 1024 * 1024,   // 50MB L1 cache
      maxL2Size: 200 * 1024 * 1024,  // 200MB L2 cache
      maxL3Size: 500 * 1024 * 1024,  // 500MB L3 cache
      compressionEnabled: true,
      compressionThreshold: 1024,     // Compress data > 1KB
    );

    // Configure cache monitoring
    _cacheMonitoringService.configure(
      hitRateThreshold: 0.7,
      memoryUsageThreshold: 0.8,
      responseTimeThreshold: 100.0,
    );

    // Setup real-time listeners
    _setupRealTimeListeners();

    _isInitialized = true;
    debugPrint('✅ Enhanced Feed Service initialized');
  }

  /// Setup real-time listeners for feed updates
  void _setupRealTimeListeners() {
    _postsListener = _firestore
        .collection(_postsCollection)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        final posts = snapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .toList();
        
        // Update cache with real-time data using advanced caching
        _partitionService.setInPartition(
          CachePartition.realtime,
          'posts',
          posts,
          duration: const Duration(minutes: 5),
        );
        
        // Notify listeners
        _postsStreamController.add(posts);
      },
      onError: (error) {
        debugPrint('❌ Real-time posts listener error: $error');
        _performanceService.recordError('realtime_posts_error', error.toString());
      },
    );
  }

  /// Get real-time posts stream
  Stream<List<PostModel>> get postsStream => _postsStreamController.stream;

  /// Get feed posts with advanced caching and optimization
  Future<List<PostModel>> getFeedPosts({
    int limit = 15, // Reduced from 20 to improve performance
    DocumentSnapshot? lastDocument,
    PostCategory? category,
    String? location,
    String? searchQuery,
    FeedSortOption sortOption = FeedSortOption.newest,
    bool useCache = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    _performanceService.startOperation('enhanced_feed_load');

    try {
      // Generate cache key
      final cacheKey = _generateCacheKey(
        limit: limit,
        category: category,
        location: location,
        searchQuery: searchQuery,
        sortOption: sortOption,
        lastDocument: lastDocument,
      );

      // Try advanced cache first with failover protection
      if (useCache) {
        final cachedPosts = await _failoverService.executeWithFailover<List<PostModel>>(
          cacheKey,
          () => _partitionService.getFromPartition<List<PostModel>>(
            CachePartition.feedPosts, 
            cacheKey,
          ),
          () async => <PostModel>[], // Empty fallback
          partition: CachePartition.feedPosts,
        );
        
        if (cachedPosts != null && cachedPosts.isNotEmpty) {
          debugPrint('📦 Loaded ${cachedPosts.length} posts from advanced cache');
          _cacheMonitoringService.recordCacheOperation(
            operation: 'get_feed',
            isHit: true,
            responseTime: stopwatch.elapsedMilliseconds.toDouble(),
            partition: CachePartition.feedPosts.name,
          );
          return await _enrichPostsWithUserData(cachedPosts);
        }
      }

      // Build optimized query
      Query query = _buildOptimizedQuery(
        category: category,
        location: location,
        sortOption: sortOption,
      );

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      query = query.limit(limit);

      // Execute query with network optimization
      final snapshot = await _networkService.optimizeRequest(() async {
        return await _databaseService.executeOptimizedQuery(query);
      });

      // Process results with error handling
      List<PostModel> posts = [];
      for (final doc in snapshot.docs) {
        try {
          final post = PostModel.fromFirestore(doc);
          posts.add(post);
        } catch (e) {
          debugPrint('❌ Error parsing post ${doc.id}: $e');
          // Skip malformed posts instead of crashing
        }
      }

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        try {
          posts = _applySearchFilter(posts, searchQuery);
        } catch (e) {
          debugPrint('❌ Error applying search filter: $e');
          // Continue without search filter if it fails
        }
      }

      // Enrich with user-specific data
      try {
        posts = await _enrichPostsWithUserData(posts);
      } catch (e) {
        debugPrint('❌ Error enriching posts: $e');
        // Continue with non-enriched posts if enrichment fails
      }

      // Cache results using advanced partitioned caching
      if (useCache) {
        await _partitionService.setInPartition(
          CachePartition.feedPosts,
          cacheKey,
          posts,
          duration: const Duration(minutes: 10),
          dependencies: ['user_${AuthService.currentUser?.uid}', 'feed_global'],
          metadata: {
            'query_params': {
              'limit': limit,
              'category': category?.value,
              'location': location,
              'sort': sortOption.name,
            },
          },
        );
        
        _cacheMonitoringService.recordCacheOperation(
          operation: 'set_feed',
          isHit: false,
          responseTime: stopwatch.elapsedMilliseconds.toDouble(),
          partition: CachePartition.feedPosts.name,
        );
      }

      // Track performance
      _performanceService.recordMetric('feed_load_time', 
          stopwatch.elapsedMilliseconds.toDouble());
      _performanceService.recordMetric('posts_loaded', posts.length.toDouble());

      debugPrint('✅ Loaded ${posts.length} posts in ${stopwatch.elapsedMilliseconds}ms');
      return posts;

    } catch (e) {
      _performanceService.recordError('enhanced_feed_load_error', e.toString());
      debugPrint('❌ Error loading feed posts: $e');
      rethrow;
    } finally {
      stopwatch.stop();
      _performanceService.endOperation('enhanced_feed_load');
    }
  }

  /// Get personalized feed using advanced algorithm
  Future<List<PostModel>> getPersonalizedFeed({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    final currentUserId = AuthService.currentUser?.uid;
    if (currentUserId == null) {
      return getFeedPosts(limit: limit, lastDocument: lastDocument);
    }

    final stopwatch = Stopwatch()..start();
    _performanceService.startOperation('personalized_feed_load');

    try {
      final cacheKey = 'personalized_feed_${currentUserId}_${limit}_${lastDocument?.id ?? 'start'}';
      
      // Check advanced cache with failover
      final cachedPosts = await _failoverService.executeWithFailover<List<PostModel>>(
        cacheKey,
        () => _partitionService.getFromPartition<List<PostModel>>(
          CachePartition.userProfiles,
          cacheKey,
        ),
        () async => <PostModel>[], // Empty fallback
        partition: CachePartition.userProfiles,
      );
      
      if (cachedPosts != null && cachedPosts.isNotEmpty) {
        debugPrint('📦 Loaded personalized feed from advanced cache');
        return cachedPosts;
      }

      // Get user preferences and activity
      final userPreferences = await _getUserPreferences(currentUserId);
      
      // Build personalized query
      Query query = _firestore.collection(_postsCollection);
      
      // Apply user-specific filters
      if (userPreferences['preferredCategories'] != null) {
        final categories = List<String>.from(userPreferences['preferredCategories']);
        if (categories.isNotEmpty) {
          query = query.where('category', whereIn: categories.take(10).toList());
        }
      }

      // Apply location-based filtering
      if (userPreferences['location'] != null) {
        query = query.where('location', isEqualTo: userPreferences['location']);
      }

      // Order by engagement score and recency
      query = query.orderBy('createdAt', descending: true);

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      query = query.limit(limit * 2); // Get more to apply personalization

      // Execute query
      final snapshot = await _networkService.optimizeRequest(() async {
        return await query.get();
      });

      // Process and rank posts
      List<PostModel> posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // Apply personalization algorithm
      posts = await _applyPersonalizationAlgorithm(posts, currentUserId, userPreferences);
      
      // Limit to requested amount
      posts = posts.take(limit).toList();

      // Enrich with user data
      posts = await _enrichPostsWithUserData(posts);

      // Cache personalized results with user-specific partition
      await _partitionService.setInPartition(
        CachePartition.userProfiles,
        cacheKey,
        posts,
        duration: const Duration(minutes: 3),
        dependencies: ['user_$currentUserId', 'personalization_model'],
        metadata: {
          'user_id': currentUserId,
          'personalization_version': '1.0',
        },
      );

      _performanceService.recordMetric('personalized_feed_time', 
          stopwatch.elapsedMilliseconds.toDouble());

      debugPrint('✅ Loaded ${posts.length} personalized posts');
      return posts;

    } catch (e) {
      _performanceService.recordError('personalized_feed_error', e.toString());
      debugPrint('❌ Error loading personalized feed: $e');
      // Fallback to regular feed
      return getFeedPosts(limit: limit, lastDocument: lastDocument);
    } finally {
      stopwatch.stop();
      _performanceService.endOperation('personalized_feed_load');
    }
  }

  /// Create a new post with validation and optimization
  Future<String> createPost({
    required String content,
    String? title,
    List<String>? imageUrls,
    List<String>? videoUrls,
    List<String>? documentUrls,
    List<String>? hashtags,
    PostCategory category = PostCategory.generalDiscussion,
    String? location,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final stopwatch = Stopwatch()..start();
    _performanceService.startOperation('create_post');

    try {
      // Validate content
      _validatePostContent(content, title);

      // Moderate content using AI moderation system
      final moderationResult = await _moderationService.moderateContent(
        content: content,
        mediaUrls: [...(imageUrls ?? []), ...(videoUrls ?? [])],
        authorId: currentUser.uid,
        contentType: 'post',
      );

      // Handle moderation decision
      if (moderationResult.decision == ModerationAction.reject) {
        throw Exception('Content violates community guidelines: ${moderationResult.reason}');
      }

      // If flagged for review, still create post but mark it as pending
      final isPendingReview = moderationResult.decision == ModerationAction.flagForReview;

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final postId = _firestore.collection(_postsCollection).doc().id;

      // Extract hashtags from content
      final extractedHashtags = hashtags ?? _extractHashtags(content);

      // Create post model with moderation data
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

      // Create post data with moderation information
      final postData = post.toFirestore();
      postData['moderationResult'] = moderationResult.toMap();
      postData['isPendingReview'] = isPendingReview;
      postData['moderationFlags'] = moderationResult.flags;
      postData['moderationScore'] = moderationResult.overallScore;

      // Save to database with batch write for consistency
      final batch = _firestore.batch();
      
      // Add post with moderation data
      batch.set(_firestore.collection(_postsCollection).doc(postId), postData);
      
      // Update user stats
      batch.update(_firestore.collection('users').doc(currentUser.uid), {
        'postsCount': FieldValue.increment(1),
        'lastPostAt': FieldValue.serverTimestamp(),
      });

      // Commit batch
      await batch.commit();

      // Invalidate relevant caches using dependency tracking
      await _advancedCacheService.invalidate('feed_global');
      await _advancedCacheService.invalidatePattern('feed_.*');
      await _advancedCacheService.invalidate('user_${currentUser.uid}');

      // Track performance
      _performanceService.recordMetric('create_post_time', 
          stopwatch.elapsedMilliseconds.toDouble());

      debugPrint('✅ Post created successfully: $postId');
      return postId;

    } catch (e) {
      _performanceService.recordError('create_post_error', e.toString());
      debugPrint('❌ Error creating post: $e');
      rethrow;
    } finally {
      stopwatch.stop();
      _performanceService.endOperation('create_post');
    }
  }

  /// Toggle like on a post with optimistic updates
  Future<void> toggleLike(String postId) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final likeId = '${postId}_${currentUser.uid}';
    
    try {
      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(
            _firestore.collection(_likesCollection).doc(likeId));
        final postDoc = await transaction.get(
            _firestore.collection(_postsCollection).doc(postId));
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        if (likeDoc.exists) {
          // Unlike the post
          transaction.delete(_firestore.collection(_likesCollection).doc(likeId));
          transaction.update(_firestore.collection(_postsCollection).doc(postId), {
            'likesCount': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
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
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Invalidate post caches using intelligent invalidation
      await _advancedCacheService.invalidate('post_$postId');
      await _advancedCacheService.invalidatePattern('feed_.*');
      await _advancedCacheService.invalidate('user_${currentUser.uid}');

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
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Validate comment content
      final validation = CommentModel.validateContent(content);
      if (validation != null) {
        throw Exception(validation);
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
        authorRole: userData['role'],
        content: content,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
      );

      // Use batch write for consistency
      final batch = _firestore.batch();
      
      // Add comment
      batch.set(_firestore.collection(_commentsCollection).doc(commentId), 
          comment.toFirestore());
      
      // Update post comment count
      batch.update(_firestore.collection(_postsCollection).doc(postId), {
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Invalidate caches with dependency tracking
      await _advancedCacheService.invalidate('post_$postId');
      await _advancedCacheService.invalidate('comments_$postId');

      return commentId;

    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      rethrow;
    }
  }

  /// Get comments for a post
  Future<List<CommentModel>> getComments(String postId, {int limit = 50}) async {
    try {
      final cacheKey = 'comments_$postId';
      
      // Check advanced cache with failover
      final cachedComments = await _failoverService.executeWithFailover<List<CommentModel>>(
        cacheKey,
        () => _partitionService.getFromPartition<List<CommentModel>>(
          CachePartition.feedPosts,
          cacheKey,
        ),
        () async => <CommentModel>[], // Empty fallback
        partition: CachePartition.feedPosts,
      );
      
      if (cachedComments != null && cachedComments.isNotEmpty) {
        return cachedComments;
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

      // Cache results in partitioned cache
      await _partitionService.setInPartition(
        CachePartition.feedPosts,
        cacheKey,
        comments,
        duration: const Duration(minutes: 10),
        dependencies: ['post_$postId'],
      );

      return comments;

    } catch (e) {
      debugPrint('❌ Error getting comments: $e');
      return [];
    }
  }

  /// Share post (increment share count)
  Future<void> sharePost(String postId, {String? shareType}) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(
            _firestore.collection(_postsCollection).doc(postId));
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        // Update share count
        transaction.update(_firestore.collection(_postsCollection).doc(postId), {
          'sharesCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
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

      // Invalidate caches with intelligent dependency tracking
      await _advancedCacheService.invalidate('post_$postId');
      await _advancedCacheService.invalidatePattern('feed_.*');

    } catch (e) {
      debugPrint('❌ Error sharing post: $e');
      rethrow;
    }
  }

  /// Search posts with advanced filtering
  Future<List<PostModel>> searchPosts({
    required String query,
    PostCategory? category,
    String? location,
    int limit = 20,
  }) async {
    try {
      final cacheKey = 'search_${query}_${category?.toString() ?? ''}_${location ?? ''}_$limit';
      
      // Check advanced cache with failover for search results
      final cachedResults = await _failoverService.executeWithFailover<List<PostModel>>(
        cacheKey,
        () => _partitionService.getFromPartition<List<PostModel>>(
          CachePartition.searchResults,
          cacheKey,
        ),
        () async => <PostModel>[], // Empty fallback
        partition: CachePartition.searchResults,
      );
      
      if (cachedResults != null && cachedResults.isNotEmpty) {
        return cachedResults;
      }

      // Build query
      Query firestoreQuery = _firestore.collection(_postsCollection);
      
      if (category != null) {
        firestoreQuery = firestoreQuery.where('category', isEqualTo: category.value);
      }
      
      if (location != null && location.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('location', isEqualTo: location);
      }

      firestoreQuery = firestoreQuery
          .orderBy('createdAt', descending: true)
          .limit(limit * 2); // Get more for filtering

      final snapshot = await firestoreQuery.get();
      
      List<PostModel> posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // Apply text search filter
      posts = _applySearchFilter(posts, query);
      posts = posts.take(limit).toList();

      // Enrich with user data
      posts = await _enrichPostsWithUserData(posts);

      // Cache search results in dedicated partition
      await _partitionService.setInPartition(
        CachePartition.searchResults,
        cacheKey,
        posts,
        duration: const Duration(minutes: 5),
        metadata: {
          'search_query': query,
          'category': category?.value,
          'location': location,
        },
      );

      return posts;

    } catch (e) {
      debugPrint('❌ Error searching posts: $e');
      return [];
    }
  }

  /// Get trending hashtags
  Future<List<String>> getTrendingHashtags({int limit = 10}) async {
    try {
      const cacheKey = 'trending_hashtags';
      
      // Check advanced cache for trending hashtags
      final cachedHashtags = await _failoverService.executeWithFailover<List<String>>(
        cacheKey,
        () => _partitionService.getFromPartition<List<String>>(
          CachePartition.analytics,
          cacheKey,
        ),
        () async => <String>[], // Empty fallback
        partition: CachePartition.analytics,
      );
      
      if (cachedHashtags != null && cachedHashtags.isNotEmpty) {
        return cachedHashtags;
      }

      // Get recent posts
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

      final trending = sortedHashtags
          .take(limit)
          .map((entry) => entry.key)
          .toList();

      // Cache trending hashtags in analytics partition
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        trending,
        duration: const Duration(hours: 1),
        metadata: {
          'calculation_time': DateTime.now().toIso8601String(),
          'sample_size': snapshot.docs.length,
        },
      );

      return trending;

    } catch (e) {
      debugPrint('❌ Error getting trending hashtags: $e');
      return [];
    }
  }

  // Private helper methods

  String _generateCacheKey({
    required int limit,
    PostCategory? category,
    String? location,
    String? searchQuery,
    required FeedSortOption sortOption,
    DocumentSnapshot? lastDocument,
  }) {
    return 'feed_${category?.toString() ?? 'all'}_${location ?? 'all'}_${searchQuery ?? 'all'}_${sortOption.toString()}_${limit}_${lastDocument?.id ?? 'start'}';
  }

  Query _buildOptimizedQuery({
    PostCategory? category,
    String? location,
    required FeedSortOption sortOption,
  }) {
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

    return query;
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

  Future<List<PostModel>> _enrichPostsWithUserData(List<PostModel> posts) async {
    if (posts.isEmpty) return posts;
    
    final currentUserId = AuthService.currentUser?.uid;
    if (currentUserId == null) return posts;

    try {
      // Batch get like status for all posts
      final likeRefs = posts.map((post) => 
        _firestore.collection(_likesCollection).doc('${post.id}_$currentUserId')
      ).toList();
      
      if (likeRefs.isEmpty) return posts;
      
      final likeSnapshots = await _databaseService.batchGetDocuments(likeRefs);
      
      // Create posts with like status
      final enrichedPosts = <PostModel>[];
      for (int i = 0; i < posts.length; i++) {
        try {
          final post = posts[i];
          final isLiked = i < likeSnapshots.length ? likeSnapshots[i].exists : false;
          enrichedPosts.add(post.copyWith(isLikedByCurrentUser: isLiked));
        } catch (e) {
          debugPrint('❌ Error enriching individual post ${posts[i].id}: $e');
          // Add the original post if enrichment fails
          enrichedPosts.add(posts[i]);
        }
      }
      
      return enrichedPosts;
    } catch (e) {
      debugPrint('❌ Error enriching posts with user data: $e');
      return posts; // Return original posts if enrichment fails
    }
  }

  Future<Map<String, dynamic>> _getUserPreferences(String userId) async {
    try {
      final cacheKey = 'user_preferences_$userId';
      
      // Check advanced cache for user preferences
      final cachedPrefs = await _failoverService.executeWithFailover<Map<String, dynamic>>(
        cacheKey,
        () => _partitionService.getFromPartition<Map<String, dynamic>>(
          CachePartition.userProfiles,
          cacheKey,
        ),
        () async => <String, dynamic>{}, // Empty fallback
        partition: CachePartition.userProfiles,
      );
      
      if (cachedPrefs != null && cachedPrefs.isNotEmpty) {
        return cachedPrefs;
      }

      // Get from database
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      final preferences = {
        'preferredCategories': userData['preferredCategories'] ?? [],
        'location': userData['address']?['villageCity'],
        'interests': userData['interests'] ?? [],
        'followedUsers': userData['followedUsers'] ?? [],
      };

      // Cache user preferences in user profiles partition
      await _partitionService.setInPartition(
        CachePartition.userProfiles,
        cacheKey,
        preferences,
        duration: const Duration(hours: 1),
        dependencies: ['user_$userId'],
        metadata: {
          'user_id': userId,
          'last_updated': DateTime.now().toIso8601String(),
        },
      );

      return preferences;
    } catch (e) {
      debugPrint('❌ Error getting user preferences: $e');
      return {};
    }
  }

  Future<List<PostModel>> _applyPersonalizationAlgorithm(
    List<PostModel> posts, 
    String userId, 
    Map<String, dynamic> preferences
  ) async {
    // Simple personalization algorithm
    // In production, this would be more sophisticated
    
    final scoredPosts = posts.map((post) {
      double score = 0.0;
      
      // Recency score (newer posts get higher score)
      final hoursSincePost = DateTime.now().difference(post.createdAt).inHours;
      score += (24 - hoursSincePost.clamp(0, 24)) / 24 * 10;
      
      // Engagement score
      score += (post.likesCount * 0.1) + (post.commentsCount * 0.2);
      
      // Category preference score
      final preferredCategories = List<String>.from(preferences['preferredCategories'] ?? []);
      if (preferredCategories.contains(post.category.value)) {
        score += 5.0;
      }
      
      // Location relevance
      if (post.location == preferences['location']) {
        score += 3.0;
      }
      
      return {'post': post, 'score': score};
    }).toList();
    
    // Sort by score
    scoredPosts.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    
    return scoredPosts.map((item) => item['post'] as PostModel).toList();
  }

  void _validatePostContent(String content, String? title) {
    if (content.trim().isEmpty) {
      throw Exception('Post content cannot be empty');
    }
    
    if (content.length > 5000) {
      throw Exception('Post content cannot exceed 5000 characters');
    }
    
    if (title != null && title.length > 200) {
      throw Exception('Post title cannot exceed 200 characters');
    }
  }

  List<String> _extractHashtags(String content) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(content);
    return matches.map((match) => match.group(1)!).toList();
  }

  /// Get comprehensive cache performance report
  Map<String, dynamic> getCachePerformanceReport() {
    return {
      'monitoring': _cacheMonitoringService.getPerformanceReport(),
      'partitions': _partitionService.getPartitionStats(),
      'failover': _failoverService.getFailoverStatus(),
      'advanced_cache': _advancedCacheService.getStats(),
    };
  }

  /// Warm up cache with popular content
  Future<void> warmUpFeedCache() async {
    try {
      debugPrint('🔥 Warming up feed cache with popular content');
      
      // Get recent popular posts for cache warming
      final popularPosts = await _firestore
          .collection(_postsCollection)
          .orderBy('likesCount', descending: true)
          .limit(20)
          .get();

      final posts = popularPosts.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // Warm cache partitions
      final warmingData = <String, dynamic>{};
      for (int i = 0; i < posts.length; i++) {
        warmingData['popular_post_$i'] = posts[i];
      }

      await _advancedCacheService.warmCache(warmingData);
      
      debugPrint('✅ Feed cache warming completed');
      
    } catch (e) {
      debugPrint('❌ Error warming feed cache: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _postsListener?.cancel();
    _postsStreamController.close();
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