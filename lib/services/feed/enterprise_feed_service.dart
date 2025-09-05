// Enterprise Feed Service for TALOWA
// Advanced feed management with enterprise-grade performance optimizations

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/social_feed/index.dart';
import '../performance/enterprise_performance_service.dart';
import '../performance/performance_optimization_service.dart';

class EnterpriseFeedService {
  static final EnterpriseFeedService _instance = EnterpriseFeedService._internal();
  factory EnterpriseFeedService() => _instance;
  EnterpriseFeedService._internal();

  // Services
  final EnterprisePerformanceService _performanceService = EnterprisePerformanceService();
  final PerformanceOptimizationService _optimizationService = PerformanceOptimizationService();
  
  // Database
  Database? _database;
  
  // Caching
  final Map<String, List<PostModel>> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Feed algorithm parameters
  final Map<String, double> _userEngagementScores = {};
  final Map<String, Set<String>> _userInterests = {};
  
  // Performance monitoring
  final Map<String, int> _feedRequestCounts = {};
  final Map<String, double> _averageLoadTimes = {};
  
  // Configuration
  static const Duration cacheExpiration = Duration(minutes: 30);
  static const int maxCacheSize = 1000;
  static const int batchSize = 20;
  static const double engagementDecayFactor = 0.95;
  
  /// Initialize the enterprise feed service
  Future<void> initialize() async {
    try {
      await _initializeDatabase();
      await _performanceService.initialize();
      await _optimizationService.initialize();
      await _loadUserPreferences();
      
      debugPrint('EnterpriseFeedService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing EnterpriseFeedService: $e');
    }
  }

  /// Initialize SQLite database for persistent storage
  Future<void> _initializeDatabase() async {
    try {
      _database = await openDatabase(
        'enterprise_feed.db',
        version: 1,
        onCreate: (db, version) async {
          // Posts table
          await db.execute('''
            CREATE TABLE posts (
              id TEXT PRIMARY KEY,
              content TEXT NOT NULL,
              author_id TEXT NOT NULL,
              author_name TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              likes INTEGER DEFAULT 0,
              comments INTEGER DEFAULT 0,
              shares INTEGER DEFAULT 0,
              engagement_score REAL DEFAULT 0.0,
              category TEXT,
              tags TEXT,
              cached_at INTEGER
            )
          ''');
          
          // User engagement table
          await db.execute('''
            CREATE TABLE user_engagement (
              user_id TEXT,
              post_id TEXT,
              action_type TEXT,
              timestamp INTEGER,
              PRIMARY KEY (user_id, post_id, action_type)
            )
          ''');
          
          // Feed analytics table
          await db.execute('''
            CREATE TABLE feed_analytics (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT,
              feed_type TEXT,
              load_time REAL,
              post_count INTEGER,
              cache_hit_rate REAL,
              timestamp INTEGER
            )
          ''');
          
          // Create indexes for better performance
          await db.execute('CREATE INDEX idx_posts_created_at ON posts(created_at)');
          await db.execute('CREATE INDEX idx_posts_engagement ON posts(engagement_score)');
          await db.execute('CREATE INDEX idx_engagement_user ON user_engagement(user_id)');
          await db.execute('CREATE INDEX idx_analytics_timestamp ON feed_analytics(timestamp)');
        },
      );
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  /// Load user preferences and engagement history
  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load engagement scores
      final engagementData = prefs.getString('user_engagement_scores');
      if (engagementData != null) {
        final Map<String, dynamic> data = jsonDecode(engagementData);
        _userEngagementScores.addAll(data.cast<String, double>());
      }
      
      // Load user interests
      final interestsData = prefs.getString('user_interests');
      if (interestsData != null) {
        final Map<String, dynamic> data = jsonDecode(interestsData);
        data.forEach((key, value) {
          _userInterests[key] = Set<String>.from(value);
        });
      }
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
    }
  }

  /// Get personalized feed with enterprise optimizations
  Future<List<PostModel>> getPersonalizedFeed({
    required String userId,
    int page = 0,
    int pageSize = 20,
    String? category,
    FeedAlgorithm algorithm = FeedAlgorithm.personalized,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final cacheKey = _generateCacheKey(userId, page, pageSize, category, algorithm);
      
      // Check multi-level cache
      final cachedPosts = await _getCachedFeed(cacheKey);
      if (cachedPosts != null) {
        _recordFeedAnalytics(userId, 'cached', stopwatch.elapsedMilliseconds.toDouble(), cachedPosts.length, 1.0);
        return cachedPosts;
      }
      
      // Generate feed based on algorithm
      List<PostModel> posts;
      switch (algorithm) {
        case FeedAlgorithm.personalized:
          posts = await _generatePersonalizedFeed(userId, page, pageSize, category);
          break;
        case FeedAlgorithm.trending:
          posts = await _generateTrendingFeed(page, pageSize, category);
          break;
        case FeedAlgorithm.recent:
          posts = await _generateRecentFeed(page, pageSize, category);
          break;
        case FeedAlgorithm.following:
          posts = await _generateFollowingFeed(userId, page, pageSize, category);
          break;
      }
      
      // Cache the results
      await _cacheFeed(cacheKey, posts);
      
      // Record analytics
      _recordFeedAnalytics(userId, algorithm.name, stopwatch.elapsedMilliseconds.toDouble(), posts.length, 0.0);
      
      // Prefetch next page in background
      _prefetchNextPage(userId, page + 1, pageSize, category, algorithm);
      
      return posts;
    } catch (e) {
      debugPrint('Error getting personalized feed: $e');
      return [];
    } finally {
      stopwatch.stop();
    }
  }

  /// Generate personalized feed using ML-like algorithm
  Future<List<PostModel>> _generatePersonalizedFeed(
    String userId,
    int page,
    int pageSize,
    String? category,
  ) async {
    try {
      // Get user engagement score
      final userScore = _userEngagementScores[userId] ?? 0.5;
      final userInterests = _userInterests[userId] ?? <String>{};
      
      // Load posts from database with scoring
      final posts = await _loadPostsFromDatabase(
        page: page,
        pageSize: pageSize * 2, // Load more for better filtering
        category: category,
      );
      
      // Score and rank posts
      final scoredPosts = posts.map((post) {
        double score = _calculatePostScore(post, userId, userScore, userInterests);
        return ScoredPost(post, score);
      }).toList();
      
      // Sort by score and take top results
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));
      
      return scoredPosts
          .take(pageSize)
          .map((scoredPost) => scoredPost.post)
          .toList();
    } catch (e) {
      debugPrint('Error generating personalized feed: $e');
      return [];
    }
  }

  /// Calculate post relevance score for user
  double _calculatePostScore(
    PostModel post,
    String userId,
    double userEngagementScore,
    Set<String> userInterests,
  ) {
    double score = 0.0;
    
    // Base engagement score (40% weight)
    score += (post.engagementScore ?? 0.0) * 0.4;
    
    // Recency score (30% weight)
    final hoursSincePost = DateTime.now().difference(post.createdAt).inHours;
    final recencyScore = 1.0 / (1.0 + hoursSincePost * 0.1);
    score += recencyScore * 0.3;
    
    // User interest alignment (20% weight)
    if (userInterests.isNotEmpty) {
      final postTags = post.tags ?? [];
      final commonInterests = userInterests.intersection(postTags.toSet()).length;
      final interestScore = commonInterests / userInterests.length;
      score += interestScore * 0.2;
    }
    
    // User engagement history (10% weight)
    score += userEngagementScore * 0.1;
    
    return score.clamp(0.0, 1.0);
  }

  /// Generate trending feed based on engagement metrics
  Future<List<PostModel>> _generateTrendingFeed(
    int page,
    int pageSize,
    String? category,
  ) async {
    try {
      if (_database == null) return [];
      
      final whereClause = category != null ? 'WHERE category = ?' : '';
      final whereArgs = category != null ? [category] : <dynamic>[];
      
      final result = await _database!.query(
        'posts',
        where: whereClause.isEmpty ? null : whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'engagement_score DESC, created_at DESC',
        limit: pageSize,
        offset: page * pageSize,
      );
      
      return result.map((row) => PostModel.fromMap(row)).toList();
    } catch (e) {
      debugPrint('Error generating trending feed: $e');
      return [];
    }
  }

  /// Generate recent feed ordered by creation time
  Future<List<PostModel>> _generateRecentFeed(
    int page,
    int pageSize,
    String? category,
  ) async {
    try {
      return await _loadPostsFromDatabase(
        page: page,
        pageSize: pageSize,
        category: category,
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint('Error generating recent feed: $e');
      return [];
    }
  }

  /// Generate following feed (placeholder - would integrate with social graph)
  Future<List<PostModel>> _generateFollowingFeed(
    String userId,
    int page,
    int pageSize,
    String? category,
  ) async {
    // This would integrate with a social graph service
    // For now, return personalized feed
    return await _generatePersonalizedFeed(userId, page, pageSize, category);
  }

  /// Load posts from database with optimizations
  Future<List<PostModel>> _loadPostsFromDatabase({
    required int page,
    required int pageSize,
    String? category,
    String orderBy = 'created_at DESC',
  }) async {
    try {
      if (_database == null) return [];
      
      final whereClause = category != null ? 'WHERE category = ?' : '';
      final whereArgs = category != null ? [category] : <dynamic>[];
      
      final result = await _database!.query(
        'posts',
        where: whereClause.isEmpty ? null : whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: orderBy,
        limit: pageSize,
        offset: page * pageSize,
      );
      
      return result.map((row) => PostModel.fromMap(row)).toList();
    } catch (e) {
      debugPrint('Error loading posts from database: $e');
      return _generateMockPosts(page, pageSize); // Fallback to mock data
    }
  }

  /// Cache management
  Future<List<PostModel>?> _getCachedFeed(String cacheKey) async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null && DateTime.now().difference(timestamp) < cacheExpiration) {
          return _memoryCache[cacheKey];
        } else {
          _memoryCache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
      }
      
      // Check enterprise cache
      return await _performanceService.getCached<List<PostModel>>(cacheKey);
    } catch (e) {
      debugPrint('Error getting cached feed: $e');
      return null;
    }
  }

  Future<void> _cacheFeed(String cacheKey, List<PostModel> posts) async {
    try {
      // Cache in memory
      _memoryCache[cacheKey] = posts;
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      // Maintain cache size
      if (_memoryCache.length > maxCacheSize) {
        final oldestKey = _cacheTimestamps.entries
            .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
            .key;
        _memoryCache.remove(oldestKey);
        _cacheTimestamps.remove(oldestKey);
      }
      
      // Cache in enterprise service
      await _performanceService.setCached(cacheKey, posts);
    } catch (e) {
      debugPrint('Error caching feed: $e');
    }
  }

  /// Record user engagement for algorithm improvement
  Future<void> recordUserEngagement({
    required String userId,
    required String postId,
    required String actionType,
    List<String>? tags,
  }) async {
    try {
      if (_database == null) return;
      
      // Record engagement in database
      await _database!.insert(
        'user_engagement',
        {
          'user_id': userId,
          'post_id': postId,
          'action_type': actionType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Update user engagement score
      final currentScore = _userEngagementScores[userId] ?? 0.5;
      final actionWeight = _getActionWeight(actionType);
      _userEngagementScores[userId] = (currentScore * engagementDecayFactor) + (actionWeight * (1 - engagementDecayFactor));
      
      // Update user interests
      if (tags != null && tags.isNotEmpty) {
        _userInterests[userId] ??= <String>{};
        _userInterests[userId]!.addAll(tags);
      }
      
      // Save to preferences
      await _saveUserPreferences();
      
      // Invalidate related caches
      await _invalidateUserCaches(userId);
    } catch (e) {
      debugPrint('Error recording user engagement: $e');
    }
  }

  /// Prefetch next page in background
  void _prefetchNextPage(
    String userId,
    int page,
    int pageSize,
    String? category,
    FeedAlgorithm algorithm,
  ) {
    Future.microtask(() async {
      try {
        await getPersonalizedFeed(
          userId: userId,
          page: page,
          pageSize: pageSize,
          category: category,
          algorithm: algorithm,
        );
      } catch (e) {
        debugPrint('Error prefetching page $page: $e');
      }
    });
  }

  /// Generate cache key
  String _generateCacheKey(
    String userId,
    int page,
    int pageSize,
    String? category,
    FeedAlgorithm algorithm,
  ) {
    return 'feed_${userId}_${page}_${pageSize}_${category ?? 'all'}_${algorithm.name}';
  }

  /// Record feed analytics
  void _recordFeedAnalytics(
    String userId,
    String feedType,
    double loadTime,
    int postCount,
    double cacheHitRate,
  ) {
    Future.microtask(() async {
      try {
        if (_database == null) return;
        
        await _database!.insert('feed_analytics', {
          'user_id': userId,
          'feed_type': feedType,
          'load_time': loadTime,
          'post_count': postCount,
          'cache_hit_rate': cacheHitRate,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e) {
        debugPrint('Error recording feed analytics: $e');
      }
    });
  }

  /// Helper methods
  double _getActionWeight(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'like': return 0.1;
      case 'comment': return 0.3;
      case 'share': return 0.5;
      case 'view': return 0.05;
      case 'save': return 0.4;
      default: return 0.05;
    }
  }

  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save engagement scores
      await prefs.setString('user_engagement_scores', jsonEncode(_userEngagementScores));
      
      // Save user interests
      final interestsMap = <String, List<String>>{};
      _userInterests.forEach((key, value) {
        interestsMap[key] = value.toList();
      });
      await prefs.setString('user_interests', jsonEncode(interestsMap));
    } catch (e) {
      debugPrint('Error saving user preferences: $e');
    }
  }

  Future<void> _invalidateUserCaches(String userId) async {
    try {
      final keysToRemove = _memoryCache.keys
          .where((key) => key.contains(userId))
          .toList();
      
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    } catch (e) {
      debugPrint('Error invalidating user caches: $e');
    }
  }

  /// Generate mock posts for testing
  List<PostModel> _generateMockPosts(int page, int pageSize) {
    return List.generate(pageSize, (index) {
      final globalIndex = (page * pageSize) + index;
      return PostModel(
        id: 'enterprise_post_$globalIndex',
        content: 'Enterprise optimized post content #$globalIndex with advanced caching and performance monitoring.',
        authorId: 'user_${globalIndex % 10}',
        authorName: 'Enterprise User ${globalIndex % 10}',
        createdAt: DateTime.now().subtract(Duration(hours: globalIndex)),
        likes: (globalIndex * 2) % 100,
        comments: globalIndex % 20,
        shares: globalIndex % 10,
        engagementScore: (globalIndex % 100) / 100.0,
        category: ['technology', 'business', 'social', 'news'][globalIndex % 4],
        tags: ['enterprise', 'performance', 'optimization', 'caching'],
      );
    });
  }

  /// Get feed analytics
  Future<Map<String, dynamic>> getFeedAnalytics(String userId) async {
    try {
      if (_database == null) return {};
      
      final result = await _database!.rawQuery('''
        SELECT 
          AVG(load_time) as avg_load_time,
          AVG(cache_hit_rate) as avg_cache_hit_rate,
          COUNT(*) as total_requests,
          SUM(post_count) as total_posts_served
        FROM feed_analytics 
        WHERE user_id = ? AND timestamp > ?
      ''', [userId, DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch]);
      
      if (result.isNotEmpty) {
        return result.first;
      }
    } catch (e) {
      debugPrint('Error getting feed analytics: $e');
    }
    
    return {};
  }

  /// Cleanup old data
  Future<void> cleanup() async {
    try {
      if (_database == null) return;
      
      final cutoffTime = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      
      // Clean old analytics
      await _database!.delete(
        'feed_analytics',
        where: 'timestamp < ?',
        whereArgs: [cutoffTime],
      );
      
      // Clean old engagement data
      await _database!.delete(
        'user_engagement',
        where: 'timestamp < ?',
        whereArgs: [cutoffTime],
      );
      
      debugPrint('Feed service cleanup completed');
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _database?.close();
    await _performanceService.dispose();
  }
}

/// Feed algorithm types
enum FeedAlgorithm {
  personalized,
  trending,
  recent,
  following,
}

/// Scored post for ranking
class ScoredPost {
  final PostModel post;
  final double score;
  
  ScoredPost(this.post, this.score);
}

/// Extension for PostModel to support database operations
extension PostModelDatabase on PostModel {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'author_id': authorId,
      'author_name': authorName,
      'created_at': createdAt.millisecondsSinceEpoch,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'engagement_score': engagementScore ?? 0.0,
      'category': category,
      'tags': tags?.join(','),
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  static PostModel fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'],
      content: map['content'],
      authorId: map['author_id'],
      authorName: map['author_name'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      shares: map['shares'] ?? 0,
      engagementScore: map['engagement_score']?.toDouble(),
      category: map['category'],
      tags: map['tags']?.split(','),
    );
  }
}
