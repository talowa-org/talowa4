import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/user_model.dart';
import '../auth_service.dart';

/// Enterprise-grade analytics service for post performance and engagement metrics
class PostAnalyticsService {
  static final PostAnalyticsService _instance = PostAnalyticsService._internal();
  factory PostAnalyticsService() => _instance;
  PostAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _analyticsCollection = 'post_analytics';
  static const String _engagementCollection = 'engagement_events';
  static const String _impressionsCollection = 'post_impressions';

  /// Track post impression (view)
  Future<void> trackPostImpression({
    required String postId,
    required String userId,
    required String viewSource, // 'feed', 'search', 'profile', etc.
    Duration? viewDuration,
  }) async {
    try {
      final impressionData = {
        'postId': postId,
        'userId': userId,
        'viewSource': viewSource,
        'viewDuration': viewDuration?.inSeconds ?? 0,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceType': defaultTargetPlatform.name,
      };

      await _firestore.collection(_impressionsCollection).add(impressionData);
      
      // Update post analytics summary
      await _updatePostAnalytics(postId, {
        'totalImpressions': FieldValue.increment(1),
        'lastImpressionAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('ðŸ“Š Tracked impression for post: $postId');
    } catch (e) {
      debugPrint('âŒ Error tracking post impression: $e');
    }
  }

  /// Track engagement event (like, comment, share, etc.)
  Future<void> trackEngagementEvent({
    required String postId,
    required String userId,
    required String eventType, // 'like', 'comment', 'share', 'save', 'report'
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final engagementData = {
        'postId': postId,
        'userId': userId,
        'eventType': eventType,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_engagementCollection).add(engagementData);
      
      // Update post analytics summary
      final updateData = <String, dynamic>{
        'totalEngagements': FieldValue.increment(1),
        'lastEngagementAt': FieldValue.serverTimestamp(),
      };
      
      // Update specific engagement counters
      switch (eventType) {
        case 'like':
          updateData['totalLikes'] = FieldValue.increment(1);
          break;
        case 'comment':
          updateData['totalComments'] = FieldValue.increment(1);
          break;
        case 'share':
          updateData['totalShares'] = FieldValue.increment(1);
          break;
        case 'save':
          updateData['totalSaves'] = FieldValue.increment(1);
          break;
      }
      
      await _updatePostAnalytics(postId, updateData);
      
      debugPrint('ðŸ“Š Tracked $eventType engagement for post: $postId');
    } catch (e) {
      debugPrint('âŒ Error tracking engagement event: $e');
    }
  }

  /// Get comprehensive analytics for a specific post
  Future<PostAnalytics?> getPostAnalytics(String postId) async {
    try {
      final doc = await _firestore
          .collection(_analyticsCollection)
          .doc(postId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      return PostAnalytics.fromFirestore(doc);
    } catch (e) {
      debugPrint('âŒ Error getting post analytics: $e');
      return null;
    }
  }

  /// Get analytics dashboard data for user's posts
  Future<UserAnalyticsDashboard> getUserAnalyticsDashboard(String userId) async {
    try {
      // Get user's posts
      final postsQuery = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      final posts = postsQuery.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
      final postIds = posts.map((p) => p.id).toList();
      
      // Get analytics for all user posts
      final analyticsQuery = await _firestore
          .collection(_analyticsCollection)
          .where(FieldPath.documentId, whereIn: postIds.take(10).toList()) // Firestore limit
          .get();
      
      final postAnalytics = analyticsQuery.docs
          .map((doc) => PostAnalytics.fromFirestore(doc))
          .toList();
      
      // Calculate summary metrics
      int totalImpressions = 0;
      int totalEngagements = 0;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;
      
      for (final analytics in postAnalytics) {
        totalImpressions += analytics.totalImpressions;
        totalEngagements += analytics.totalEngagements;
        totalLikes += analytics.totalLikes;
        totalComments += analytics.totalComments;
        totalShares += analytics.totalShares;
      }
      
      return UserAnalyticsDashboard(
        userId: userId,
        totalPosts: posts.length,
        totalImpressions: totalImpressions,
        totalEngagements: totalEngagements,
        totalLikes: totalLikes,
        totalComments: totalComments,
        totalShares: totalShares,
        averageEngagementRate: totalImpressions > 0 ? (totalEngagements / totalImpressions) * 100 : 0,
        topPerformingPosts: _getTopPerformingPosts(posts, postAnalytics),
        recentPosts: posts.take(10).toList(),
      );
      
    } catch (e) {
      debugPrint('âŒ Error getting user analytics dashboard: $e');
      return UserAnalyticsDashboard.empty(userId);
    }
  }

  /// Get trending posts analytics
  Future<List<TrendingPostAnalytics>> getTrendingPosts({
    int limit = 20,
    Duration timeWindow = const Duration(days: 7),
  }) async {
    try {
      final cutoffTime = Timestamp.fromDate(
        DateTime.now().subtract(timeWindow),
      );
      
      final query = await _firestore
          .collection(_analyticsCollection)
          .where('lastEngagementAt', isGreaterThan: cutoffTime)
          .orderBy('engagementRate', descending: true)
          .limit(limit)
          .get();
      
      final trendingPosts = <TrendingPostAnalytics>[];
      
      for (final doc in query.docs) {
        final analytics = PostAnalytics.fromFirestore(doc);
        
        // Get post details
        final postDoc = await _firestore
            .collection('posts')
            .doc(doc.id)
            .get();
        
        if (postDoc.exists) {
          final post = PostModel.fromFirestore(postDoc);
          trendingPosts.add(TrendingPostAnalytics(
            post: post,
            analytics: analytics,
            trendingScore: _calculateTrendingScore(analytics, timeWindow),
          ));
        }
      }
      
      return trendingPosts;
    } catch (e) {
      debugPrint('âŒ Error getting trending posts: $e');
      return [];
    }
  }

  /// Update post analytics summary
  Future<void> _updatePostAnalytics(String postId, Map<String, dynamic> updates) async {
    await _firestore
        .collection(_analyticsCollection)
        .doc(postId)
        .set(updates, SetOptions(merge: true));
  }

  /// Calculate trending score based on recent engagement
  double _calculateTrendingScore(PostAnalytics analytics, Duration timeWindow) {
    final hoursSinceCreation = DateTime.now()
        .difference(analytics.createdAt ?? DateTime.now())
        .inHours;
    
    if (hoursSinceCreation == 0) return 0;
    
    // Engagement velocity (engagements per hour)
    final engagementVelocity = analytics.totalEngagements / hoursSinceCreation;
    
    // Engagement rate
    final engagementRate = analytics.totalImpressions > 0 
        ? analytics.totalEngagements / analytics.totalImpressions 
        : 0;
    
    // Time decay factor (newer posts get higher scores)
    final timeDecay = 1 / (1 + (hoursSinceCreation / 24));
    
    return (engagementVelocity * 0.4 + engagementRate * 0.4 + timeDecay * 0.2) * 100;
  }

  /// Get top performing posts
  List<PostModel> _getTopPerformingPosts(
    List<PostModel> posts, 
    List<PostAnalytics> analytics,
  ) {
    final postAnalyticsMap = <String, PostAnalytics>{};
    for (final analytic in analytics) {
      postAnalyticsMap[analytic.postId] = analytic;
    }
    
    posts.sort((a, b) {
      final aAnalytics = postAnalyticsMap[a.id];
      final bAnalytics = postAnalyticsMap[b.id];
      
      if (aAnalytics == null && bAnalytics == null) return 0;
      if (aAnalytics == null) return 1;
      if (bAnalytics == null) return -1;
      
      return bAnalytics.engagementRate.compareTo(aAnalytics.engagementRate);
    });
    
    return posts.take(5).toList();
  }
}

/// Post analytics data model
class PostAnalytics {
  final String postId;
  final int totalImpressions;
  final int totalEngagements;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final int totalSaves;
  final double engagementRate;
  final DateTime? createdAt;
  final DateTime? lastImpressionAt;
  final DateTime? lastEngagementAt;

  PostAnalytics({
    required this.postId,
    required this.totalImpressions,
    required this.totalEngagements,
    required this.totalLikes,
    required this.totalComments,
    required this.totalShares,
    required this.totalSaves,
    required this.engagementRate,
    this.createdAt,
    this.lastImpressionAt,
    this.lastEngagementAt,
  });

  factory PostAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final totalImpressions = data['totalImpressions'] ?? 0;
    final totalEngagements = data['totalEngagements'] ?? 0;
    
    return PostAnalytics(
      postId: doc.id,
      totalImpressions: totalImpressions,
      totalEngagements: totalEngagements,
      totalLikes: data['totalLikes'] ?? 0,
      totalComments: data['totalComments'] ?? 0,
      totalShares: data['totalShares'] ?? 0,
      totalSaves: data['totalSaves'] ?? 0,
      engagementRate: totalImpressions > 0 ? (totalEngagements / totalImpressions) * 100 : 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastImpressionAt: (data['lastImpressionAt'] as Timestamp?)?.toDate(),
      lastEngagementAt: (data['lastEngagementAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// User analytics dashboard data model
class UserAnalyticsDashboard {
  final String userId;
  final int totalPosts;
  final int totalImpressions;
  final int totalEngagements;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final double averageEngagementRate;
  final List<PostModel> topPerformingPosts;
  final List<PostModel> recentPosts;

  UserAnalyticsDashboard({
    required this.userId,
    required this.totalPosts,
    required this.totalImpressions,
    required this.totalEngagements,
    required this.totalLikes,
    required this.totalComments,
    required this.totalShares,
    required this.averageEngagementRate,
    required this.topPerformingPosts,
    required this.recentPosts,
  });

  factory UserAnalyticsDashboard.empty(String userId) {
    return UserAnalyticsDashboard(
      userId: userId,
      totalPosts: 0,
      totalImpressions: 0,
      totalEngagements: 0,
      totalLikes: 0,
      totalComments: 0,
      totalShares: 0,
      averageEngagementRate: 0,
      topPerformingPosts: [],
      recentPosts: [],
    );
  }
}

/// Trending post analytics data model
class TrendingPostAnalytics {
  final PostModel post;
  final PostAnalytics analytics;
  final double trendingScore;

  TrendingPostAnalytics({
    required this.post,
    required this.analytics,
    required this.trendingScore,
  });
}
