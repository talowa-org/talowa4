// Personalization and Recommendation Engine for TALOWA Advanced Social Feed System
// AI-powered personalized feed algorithm with user behavior analysis and collaborative filtering
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/ai/recommendation_models.dart';
import '../performance/cache_service.dart';
import '../performance/advanced_cache_service.dart';
import '../performance/cache_partition_service.dart';
import '../performance/performance_monitoring_service.dart';

/// Personalization and Recommendation Engine providing AI-powered content recommendations
class PersonalizationRecommendationEngine {
  static final PersonalizationRecommendationEngine _instance = PersonalizationRecommendationEngine._internal();
  factory PersonalizationRecommendationEngine() => _instance;
  PersonalizationRecommendationEngine._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late CacheService _cacheService;
  late AdvancedCacheService _advancedCacheService;
  late CachePartitionService _partitionService;
  late PerformanceMonitoringService _performanceService;

  bool _isInitialized = false;

  // Configuration
  static const Duration _cacheTimeout = Duration(minutes: 15);
  static const Duration _longCacheTimeout = Duration(hours: 1);
  static const int _minInteractionsForPersonalization = 5;
  static const double _recencyDecayFactor = 0.95;
  static const double _engagementWeight = 0.3;
  static const double _recencyWeight = 0.25;
  static const double _relevanceWeight = 0.25;
  static const double _diversityWeight = 0.2;

  /// Initialize the Personalization and Recommendation Engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    _cacheService = CacheService.instance;
    _advancedCacheService = AdvancedCacheService.instance;
    _partitionService = CachePartitionService.instance;
    _performanceService = PerformanceMonitoringService.instance;

    await _cacheService.initialize();
    await _advancedCacheService.initialize();
    await _partitionService.initialize();

    _isInitialized = true;
    debugPrint('✅ Personalization and Recommendation Engine initialized');
  }

  /// Get AI-powered personalized feed for user
  Future<List<PostModel>> getPersonalizedFeed({
    required String userId,
    int limit = 20,
    List<String>? excludePostIds,
    bool useCollaborativeFiltering = true,
    bool useContentBasedFiltering = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    _performanceService.startOperation('personalized_feed');

    try {
      final cacheKey = 'personalized_feed_${userId}_$limit';
      
      // Check cache
      final cachedFeed = await _partitionService.getFromPartition<List<PostModel>>(
        CachePartition.userProfiles,
        cacheKey,
      );
      
      if (cachedFeed != null && cachedFeed.isNotEmpty) {
        debugPrint('📦 Personalized feed loaded from cache');
        return cachedFeed;
      }

      // Get user profile and behavior data
      final userProfile = await _getUserProfile(userId);
      final userBehavior = await _analyzeUserBehavior(userId);
      
      // Get candidate posts
      final candidatePosts = await _getCandidatePosts(limit * 3, excludePostIds);
      
      // Apply personalization algorithms
      List<ScoredPost> scoredPosts = [];
      
      if (useCollaborativeFiltering && userBehavior.totalInteractions >= _minInteractionsForPersonalization) {
        scoredPosts = await _applyCollaborativeFiltering(candidatePosts, userId, userBehavior);
      } else if (useContentBasedFiltering) {
        scoredPosts = await _applyContentBasedFiltering(candidatePosts, userProfile, userBehavior);
      } else {
        // Fallback to basic scoring
        scoredPosts = await _applyBasicScoring(candidatePosts, userProfile);
      }
      
      // Apply diversity and freshness
      scoredPosts = _applyDiversityBoost(scoredPosts, userProfile);
      
      // Sort by final score
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));
      
      final personalizedFeed = scoredPosts.take(limit).map((sp) => sp.post).toList();
      
      // Cache results
      await _partitionService.setInPartition(
        CachePartition.userProfiles,
        cacheKey,
        personalizedFeed,
        duration: _cacheTimeout,
        dependencies: ['user_$userId', 'personalization_model'],
      );

      _performanceService.recordMetric('personalized_feed_time', stopwatch.elapsedMilliseconds.toDouble());
      debugPrint('✅ Personalized feed generated in ${stopwatch.elapsedMilliseconds}ms');
      
      return personalizedFeed;

    } catch (e) {
      _performanceService.recordError('personalized_feed_error', e.toString());
      debugPrint('❌ Error generating personalized feed: $e');
      return [];
    } finally {
      stopwatch.stop();
      _performanceService.endOperation('personalized_feed');
    }
  }

  /// Analyze user behavior and build preference profile
  Future<UserBehaviorProfile> analyzeUserBehavior(String userId) async {
    try {
      final cacheKey = 'user_behavior_$userId';
      
      // Check cache
      final cachedBehavior = await _partitionService.getFromPartition<UserBehaviorProfile>(
        CachePartition.userProfiles,
        cacheKey,
      );
      
      if (cachedBehavior != null) {
        return cachedBehavior;
      }

      final behavior = await _analyzeUserBehavior(userId);
      
      // Cache behavior profile
      await _partitionService.setInPartition(
        CachePartition.userProfiles,
        cacheKey,
        behavior,
        duration: _longCacheTimeout,
        dependencies: ['user_$userId'],
      );
      
      return behavior;

    } catch (e) {
      debugPrint('❌ Error analyzing user behavior: $e');
      return UserBehaviorProfile.empty(userId);
    }
  }

  /// Apply collaborative filtering for content recommendations
  Future<List<ScoredPost>> applyCollaborativeFiltering({
    required List<PostModel> candidatePosts,
    required String userId,
    int limit = 20,
  }) async {
    try {
      final userBehavior = await _analyzeUserBehavior(userId);
      return await _applyCollaborativeFiltering(candidatePosts, userId, userBehavior);
    } catch (e) {
      debugPrint('❌ Error in collaborative filtering: $e');
      return [];
    }
  }

  /// Apply content-based filtering with feature extraction
  Future<List<ScoredPost>> applyContentBasedFiltering({
    required List<PostModel> candidatePosts,
    required String userId,
    int limit = 20,
  }) async {
    try {
      final userProfile = await _getUserProfile(userId);
      final userBehavior = await _analyzeUserBehavior(userId);
      return await _applyContentBasedFiltering(candidatePosts, userProfile, userBehavior);
    } catch (e) {
      debugPrint('❌ Error in content-based filtering: $e');
      return [];
    }
  }

  /// Predict optimal posting time for user based on activity patterns
  Future<OptimalPostingTime> predictOptimalPostingTime(String userId) async {
    try {
      final cacheKey = 'optimal_posting_time_$userId';
      
      // Check cache
      final cachedTime = await _partitionService.getFromPartition<OptimalPostingTime>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedTime != null) {
        return cachedTime;
      }

      // Analyze user's historical engagement patterns
      final engagementPatterns = await _analyzeEngagementPatterns(userId);
      
      // Find peak engagement hours
      final peakHours = _findPeakEngagementHours(engagementPatterns);
      
      // Find peak days of week
      final peakDays = _findPeakEngagementDays(engagementPatterns);
      
      // Calculate confidence based on data volume
      final confidence = _calculatePredictionConfidence(engagementPatterns);
      
      final optimalTime = OptimalPostingTime(
        userId: userId,
        peakHours: peakHours,
        peakDaysOfWeek: peakDays,
        nextOptimalTime: _calculateNextOptimalTime(peakHours, peakDays),
        confidence: confidence,
        basedOnInteractions: engagementPatterns.totalInteractions,
        calculatedAt: DateTime.now(),
      );
      
      // Cache optimal posting time
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        optimalTime,
        duration: const Duration(days: 1),
        dependencies: ['user_$userId'],
      );
      
      return optimalTime;

    } catch (e) {
      debugPrint('❌ Error predicting optimal posting time: $e');
      return OptimalPostingTime.defaultTime(userId);
    }
  }

  /// Predict trending topics with geographic awareness
  Future<List<TrendingTopic>> predictTrendingTopics({
    String? location,
    int limit = 10,
    Duration timeWindow = const Duration(hours: 24),
  }) async {
    try {
      final cacheKey = 'trending_topics_${location ?? 'global'}_$limit';
      
      // Check cache
      final cachedTopics = await _partitionService.getFromPartition<List<TrendingTopic>>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedTopics != null && cachedTopics.isNotEmpty) {
        return cachedTopics;
      }

      // Get recent posts within time window
      final recentPosts = await _getRecentPosts(timeWindow, location);
      
      // Extract and score topics
      final topicScores = <String, TopicScore>{};
      
      for (final post in recentPosts) {
        // Extract topics from hashtags
        for (final hashtag in post.hashtags) {
          final topic = hashtag.replaceAll('#', '').toLowerCase();
          if (!topicScores.containsKey(topic)) {
            topicScores[topic] = TopicScore(topic: topic);
          }
          topicScores[topic]!.incrementMentions();
          topicScores[topic]!.addEngagement(post.likesCount + post.commentsCount + post.sharesCount);
        }
        
        // Extract topics from content (simple keyword extraction)
        final contentTopics = _extractTopicsFromContent(post.content);
        for (final topic in contentTopics) {
          if (!topicScores.containsKey(topic)) {
            topicScores[topic] = TopicScore(topic: topic);
          }
          topicScores[topic]!.incrementMentions();
          topicScores[topic]!.addEngagement(post.likesCount + post.commentsCount);
        }
      }
      
      // Calculate trending scores with velocity
      final trendingTopics = <TrendingTopic>[];
      
      for (final entry in topicScores.entries) {
        final topic = entry.key;
        final score = entry.value;
        
        final trendingScore = _calculateTrendingScore(
          mentions: score.mentions,
          engagement: score.totalEngagement,
          timeWindow: timeWindow,
        );
        
        final velocity = await _calculateTopicVelocity(topic, timeWindow);
        
        trendingTopics.add(TrendingTopic(
          topic: topic,
          mentions: score.mentions,
          engagement: score.totalEngagement,
          trendingScore: trendingScore,
          velocity: velocity,
          location: location,
          timeWindow: timeWindow,
          calculatedAt: DateTime.now(),
        ));
      }
      
      // Sort by trending score
      trendingTopics.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
      
      final result = trendingTopics.take(limit).toList();
      
      // Cache trending topics
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        result,
        duration: const Duration(minutes: 30),
      );
      
      return result;

    } catch (e) {
      debugPrint('❌ Error predicting trending topics: $e');
      return [];
    }
  }

  /// Predict engagement for a post
  Future<EngagementPrediction> predictEngagement({
    required PostModel post,
    String? userId,
  }) async {
    try {
      final cacheKey = 'engagement_prediction_${post.id}_${userId ?? 'anonymous'}';
      
      // Check cache
      final cachedPrediction = await _partitionService.getFromPartition<EngagementPrediction>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedPrediction != null) {
        return cachedPrediction;
      }

      // Extract post features
      final features = _extractPostFeatures(post);
      
      // Get user context if available
      UserBehaviorProfile? userBehavior;
      if (userId != null) {
        userBehavior = await _analyzeUserBehavior(userId);
      }
      
      // Calculate engagement predictions
      final likeProbability = _predictLikeProbability(features, userBehavior);
      final commentProbability = _predictCommentProbability(features, userBehavior);
      final shareProbability = _predictShareProbability(features, userBehavior);
      
      // Estimate engagement counts
      final estimatedLikes = _estimateEngagementCount(likeProbability, features);
      final estimatedComments = _estimateEngagementCount(commentProbability, features) * 0.3;
      final estimatedShares = _estimateEngagementCount(shareProbability, features) * 0.1;
      
      // Calculate overall engagement score
      final overallScore = (likeProbability * 0.5) + 
                          (commentProbability * 0.3) + 
                          (shareProbability * 0.2);
      
      final prediction = EngagementPrediction(
        postId: post.id,
        userId: userId,
        likeProbability: likeProbability,
        commentProbability: commentProbability,
        shareProbability: shareProbability,
        estimatedLikes: estimatedLikes.round(),
        estimatedComments: estimatedComments.round(),
        estimatedShares: estimatedShares.round(),
        overallEngagementScore: overallScore,
        confidence: _calculateEngagementPredictionConfidence(features, userBehavior),
        predictedAt: DateTime.now(),
      );
      
      // Cache prediction
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        prediction,
        duration: _cacheTimeout,
      );
      
      return prediction;

    } catch (e) {
      debugPrint('❌ Error predicting engagement: $e');
      return EngagementPrediction.defaultPrediction(post.id, userId);
    }
  }

  /// A/B testing framework for recommendation algorithms
  Future<ABTestResult> runABTest({
    required String testName,
    required String userId,
    required List<PostModel> candidatePosts,
    required Map<String, RecommendationAlgorithm> algorithms,
    int limit = 20,
  }) async {
    try {
      final cacheKey = 'ab_test_${testName}_$userId';
      
      // Check if user is already assigned to a variant
      var assignment = await _partitionService.getFromPartition<ABTestAssignment>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (assignment == null) {
        // Assign user to a variant
        final variantNames = algorithms.keys.toList();
        final assignedVariant = variantNames[math.Random().nextInt(variantNames.length)];
        
        assignment = ABTestAssignment(
          testName: testName,
          userId: userId,
          variant: assignedVariant,
          assignedAt: DateTime.now(),
        );
        
        // Cache assignment
        await _partitionService.setInPartition(
          CachePartition.analytics,
          cacheKey,
          assignment,
          duration: const Duration(days: 30),
        );
      }
      
      // Get algorithm for assigned variant
      final algorithm = algorithms[assignment.variant]!;
      
      // Apply algorithm
      final recommendations = await algorithm.recommend(candidatePosts, userId, limit);
      
      // Track metrics
      await _trackABTestMetrics(testName, assignment.variant, userId, recommendations);
      
      return ABTestResult(
        testName: testName,
        variant: assignment.variant,
        recommendations: recommendations,
        assignment: assignment,
      );

    } catch (e) {
      debugPrint('❌ Error running A/B test: $e');
      // Return default algorithm results
      return ABTestResult.defaultResult(testName, candidatePosts.take(limit).toList());
    }
  }

  /// Get A/B test performance metrics
  Future<Map<String, ABTestMetrics>> getABTestMetrics(String testName) async {
    try {
      final cacheKey = 'ab_test_metrics_$testName';
      
      // Check cache
      final cachedMetrics = await _partitionService.getFromPartition<Map<String, ABTestMetrics>>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedMetrics != null) {
        return cachedMetrics;
      }

      // Fetch metrics from database
      final metricsSnapshot = await _firestore
          .collection('ab_test_metrics')
          .where('testName', isEqualTo: testName)
          .get();
      
      final metrics = <String, ABTestMetrics>{};
      
      for (final doc in metricsSnapshot.docs) {
        final data = doc.data();
        final variant = data['variant'] as String;
        
        metrics[variant] = ABTestMetrics(
          variant: variant,
          impressions: data['impressions'] ?? 0,
          clicks: data['clicks'] ?? 0,
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          shares: data['shares'] ?? 0,
          timeSpent: data['timeSpent'] ?? 0.0,
          conversionRate: data['conversionRate'] ?? 0.0,
        );
      }
      
      // Cache metrics
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        metrics,
        duration: const Duration(minutes: 5),
      );
      
      return metrics;

    } catch (e) {
      debugPrint('❌ Error getting A/B test metrics: $e');
      return {};
    }
  }

  // Private helper methods

  Future<UserProfile> _getUserProfile(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return UserProfile.empty(userId);
      }
      
      final data = userDoc.data()!;
      return UserProfile(
        userId: userId,
        preferredCategories: List<String>.from(data['preferredCategories'] ?? []),
        location: data['address']?['villageCity'] ?? '',
        interests: List<String>.from(data['interests'] ?? []),
        followedUsers: List<String>.from(data['followedUsers'] ?? []),
        language: data['preferredLanguage'] ?? 'en',
      );
    } catch (e) {
      return UserProfile.empty(userId);
    }
  }

  Future<UserBehaviorProfile> _analyzeUserBehavior(String userId) async {
    try {
      // Get user's interaction history
      final likesSnapshot = await _firestore
          .collection('post_likes')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      
      final commentsSnapshot = await _firestore
          .collection('post_comments')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      
      final sharesSnapshot = await _firestore
          .collection('post_shares')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      
      // Analyze interaction patterns
      final categoryPreferences = <String, double>{};
      final topicPreferences = <String, double>{};
      final authorPreferences = <String, double>{};
      final timePatterns = <int, int>{}; // hour -> count
      final dayPatterns = <int, int>{}; // day of week -> count
      
      // Process likes
      for (final doc in likesSnapshot.docs) {
        final data = doc.data();
        final postId = data['postId'] as String;
        final timestamp = (data['createdAt'] as Timestamp).toDate();
        
        // Get post details
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data()!;
          
          // Update category preferences
          final category = postData['category'] as String?;
          if (category != null) {
            categoryPreferences[category] = (categoryPreferences[category] ?? 0) + 1.0;
          }
          
          // Update author preferences
          final authorId = postData['authorId'] as String?;
          if (authorId != null) {
            authorPreferences[authorId] = (authorPreferences[authorId] ?? 0) + 1.0;
          }
          
          // Update topic preferences from hashtags
          final hashtags = List<String>.from(postData['hashtags'] ?? []);
          for (final hashtag in hashtags) {
            final topic = hashtag.replaceAll('#', '').toLowerCase();
            topicPreferences[topic] = (topicPreferences[topic] ?? 0) + 0.5;
          }
        }
        
        // Update time patterns
        final hour = timestamp.hour;
        timePatterns[hour] = (timePatterns[hour] ?? 0) + 1;
        
        final dayOfWeek = timestamp.weekday;
        dayPatterns[dayOfWeek] = (dayPatterns[dayOfWeek] ?? 0) + 1;
      }
      
      // Process comments (higher weight than likes)
      for (final doc in commentsSnapshot.docs) {
        final data = doc.data();
        final postId = data['postId'] as String;
        final timestamp = (data['createdAt'] as Timestamp).toDate();
        
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data()!;
          
          final category = postData['category'] as String?;
          if (category != null) {
            categoryPreferences[category] = (categoryPreferences[category] ?? 0) + 2.0;
          }
          
          final authorId = postData['authorId'] as String?;
          if (authorId != null) {
            authorPreferences[authorId] = (authorPreferences[authorId] ?? 0) + 2.0;
          }
          
          final hashtags = List<String>.from(postData['hashtags'] ?? []);
          for (final hashtag in hashtags) {
            final topic = hashtag.replaceAll('#', '').toLowerCase();
            topicPreferences[topic] = (topicPreferences[topic] ?? 0) + 1.0;
          }
        }
        
        final hour = timestamp.hour;
        timePatterns[hour] = (timePatterns[hour] ?? 0) + 1;
        
        final dayOfWeek = timestamp.weekday;
        dayPatterns[dayOfWeek] = (dayPatterns[dayOfWeek] ?? 0) + 1;
      }
      
      // Normalize preferences
      final totalInteractions = likesSnapshot.docs.length + 
                               commentsSnapshot.docs.length + 
                               sharesSnapshot.docs.length;
      
      if (totalInteractions > 0) {
        categoryPreferences.updateAll((key, value) => value / totalInteractions);
        topicPreferences.updateAll((key, value) => value / totalInteractions);
        authorPreferences.updateAll((key, value) => value / totalInteractions);
      }
      
      return UserBehaviorProfile(
        userId: userId,
        categoryPreferences: categoryPreferences,
        topicPreferences: topicPreferences,
        authorPreferences: authorPreferences,
        timePatterns: timePatterns,
        dayPatterns: dayPatterns,
        totalInteractions: totalInteractions,
        lastUpdated: DateTime.now(),
      );

    } catch (e) {
      debugPrint('❌ Error analyzing user behavior: $e');
      return UserBehaviorProfile.empty(userId);
    }
  }

  Future<List<PostModel>> _getCandidatePosts(int limit, List<String>? excludePostIds) async {
    try {
      var query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(limit);
      
      final snapshot = await query.get();
      
      final posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .where((post) => excludePostIds == null || !excludePostIds.contains(post.id))
          .toList();
      
      return posts;
    } catch (e) {
      debugPrint('❌ Error getting candidate posts: $e');
      return [];
    }
  }

  Future<List<ScoredPost>> _applyCollaborativeFiltering(
    List<PostModel> candidatePosts,
    String userId,
    UserBehaviorProfile userBehavior,
  ) async {
    try {
      // Find similar users based on behavior patterns
      final similarUsers = await _findSimilarUsers(userId, userBehavior);
      
      // Get posts liked by similar users
      final recommendedPostIds = <String, double>{};
      
      for (final similarUser in similarUsers) {
        final userLikes = await _firestore
            .collection('post_likes')
            .where('userId', isEqualTo: similarUser.userId)
            .limit(50)
            .get();
        
        for (final doc in userLikes.docs) {
          final postId = doc.data()['postId'] as String;
          final similarity = similarUser.similarity;
          
          recommendedPostIds[postId] = (recommendedPostIds[postId] ?? 0) + similarity;
        }
      }
      
      // Score candidate posts based on collaborative filtering
      final scoredPosts = <ScoredPost>[];
      
      for (final post in candidatePosts) {
        final collaborativeScore = recommendedPostIds[post.id] ?? 0.0;
        final recencyScore = _calculateRecencyScore(post.createdAt);
        final engagementScore = _calculateEngagementScore(post);
        
        final finalScore = (collaborativeScore * 0.5) + 
                          (recencyScore * 0.3) + 
                          (engagementScore * 0.2);
        
        scoredPosts.add(ScoredPost(
          post: post,
          score: finalScore,
          scoreBreakdown: {
            'collaborative': collaborativeScore,
            'recency': recencyScore,
            'engagement': engagementScore,
          },
        ));
      }
      
      return scoredPosts;

    } catch (e) {
      debugPrint('❌ Error in collaborative filtering: $e');
      return [];
    }
  }

  Future<List<ScoredPost>> _applyContentBasedFiltering(
    List<PostModel> candidatePosts,
    UserProfile userProfile,
    UserBehaviorProfile userBehavior,
  ) async {
    try {
      final scoredPosts = <ScoredPost>[];
      
      for (final post in candidatePosts) {
        // Calculate relevance score based on user preferences
        double relevanceScore = 0.0;
        
        // Category match
        if (userBehavior.categoryPreferences.containsKey(post.category.value)) {
          relevanceScore += userBehavior.categoryPreferences[post.category.value]! * 0.3;
        }
        
        // Topic match (hashtags)
        for (final hashtag in post.hashtags) {
          final topic = hashtag.replaceAll('#', '').toLowerCase();
          if (userBehavior.topicPreferences.containsKey(topic)) {
            relevanceScore += userBehavior.topicPreferences[topic]! * 0.2;
          }
        }
        
        // Author match
        if (userBehavior.authorPreferences.containsKey(post.authorId)) {
          relevanceScore += userBehavior.authorPreferences[post.authorId]! * 0.2;
        }
        
        // Location match
        if (post.location == userProfile.location) {
          relevanceScore += 0.15;
        }
        
        // Calculate other scores
        final recencyScore = _calculateRecencyScore(post.createdAt);
        final engagementScore = _calculateEngagementScore(post);
        
        // Combine scores
        final finalScore = (relevanceScore * _relevanceWeight) + 
                          (recencyScore * _recencyWeight) + 
                          (engagementScore * _engagementWeight);
        
        scoredPosts.add(ScoredPost(
          post: post,
          score: finalScore,
          scoreBreakdown: {
            'relevance': relevanceScore,
            'recency': recencyScore,
            'engagement': engagementScore,
          },
        ));
      }
      
      return scoredPosts;

    } catch (e) {
      debugPrint('❌ Error in content-based filtering: $e');
      return [];
    }
  }

  Future<List<ScoredPost>> _applyBasicScoring(
    List<PostModel> candidatePosts,
    UserProfile userProfile,
  ) async {
    final scoredPosts = <ScoredPost>[];
    
    for (final post in candidatePosts) {
      final recencyScore = _calculateRecencyScore(post.createdAt);
      final engagementScore = _calculateEngagementScore(post);
      final locationScore = post.location == userProfile.location ? 0.2 : 0.0;
      
      final finalScore = (recencyScore * 0.4) + 
                        (engagementScore * 0.4) + 
                        (locationScore * 0.2);
      
      scoredPosts.add(ScoredPost(
        post: post,
        score: finalScore,
        scoreBreakdown: {
          'recency': recencyScore,
          'engagement': engagementScore,
          'location': locationScore,
        },
      ));
    }
    
    return scoredPosts;
  }

  List<ScoredPost> _applyDiversityBoost(
    List<ScoredPost> scoredPosts,
    UserProfile userProfile,
  ) {
    // Apply diversity to avoid filter bubbles
    final seenCategories = <String>{};
    final seenAuthors = <String>{};
    final diversifiedPosts = <ScoredPost>[];
    
    for (final scoredPost in scoredPosts) {
      var diversityBoost = 0.0;
      
      // Boost posts from new categories
      if (!seenCategories.contains(scoredPost.post.category.value)) {
        diversityBoost += 0.1;
        seenCategories.add(scoredPost.post.category.value);
      }
      
      // Boost posts from new authors
      if (!seenAuthors.contains(scoredPost.post.authorId)) {
        diversityBoost += 0.05;
        seenAuthors.add(scoredPost.post.authorId);
      }
      
      // Apply diversity boost
      final newScore = scoredPost.score + (diversityBoost * _diversityWeight);
      
      diversifiedPosts.add(ScoredPost(
        post: scoredPost.post,
        score: newScore,
        scoreBreakdown: {
          ...scoredPost.scoreBreakdown,
          'diversity': diversityBoost,
        },
      ));
    }
    
    return diversifiedPosts;
  }

  double _calculateRecencyScore(DateTime createdAt) {
    final hoursSincePost = DateTime.now().difference(createdAt).inHours;
    // Exponential decay: newer posts get higher scores
    return math.pow(_recencyDecayFactor, hoursSincePost / 24).toDouble();
  }

  double _calculateEngagementScore(PostModel post) {
    final totalEngagement = post.likesCount + 
                           (post.commentsCount * 2) + 
                           (post.sharesCount * 3);
    
    // Normalize engagement score (log scale to handle outliers)
    return math.log(totalEngagement + 1) / math.log(100);
  }

  Future<List<SimilarUser>> _findSimilarUsers(
    String userId,
    UserBehaviorProfile userBehavior,
  ) async {
    try {
      // Get all users who have similar interaction patterns
      // This is a simplified implementation
      // In production, this would use more sophisticated similarity metrics
      
      final similarUsers = <SimilarUser>[];
      
      // Get users who liked similar posts
      final userLikes = await _firestore
          .collection('post_likes')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .get();
      
      final likedPostIds = userLikes.docs.map((doc) => doc.data()['postId'] as String).toSet();
      
      // Find users who also liked these posts
      for (final postId in likedPostIds.take(10)) {
        final otherLikes = await _firestore
            .collection('post_likes')
            .where('postId', isEqualTo: postId)
            .limit(20)
            .get();
        
        for (final doc in otherLikes.docs) {
          final otherUserId = doc.data()['userId'] as String;
          if (otherUserId != userId) {
            // Calculate similarity (Jaccard similarity)
            const similarity = 0.5; // Simplified
            
            similarUsers.add(SimilarUser(
              userId: otherUserId,
              similarity: similarity,
            ));
          }
        }
      }
      
      // Remove duplicates and sort by similarity
      final uniqueUsers = <String, SimilarUser>{};
      for (final user in similarUsers) {
        if (!uniqueUsers.containsKey(user.userId) || 
            uniqueUsers[user.userId]!.similarity < user.similarity) {
          uniqueUsers[user.userId] = user;
        }
      }
      
      final result = uniqueUsers.values.toList();
      result.sort((a, b) => b.similarity.compareTo(a.similarity));
      
      return result.take(10).toList();

    } catch (e) {
      debugPrint('❌ Error finding similar users: $e');
      return [];
    }
  }

  Future<EngagementPatterns> _analyzeEngagementPatterns(String userId) async {
    try {
      final interactions = await _firestore
          .collection('post_likes')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();
      
      final hourlyEngagement = <int, int>{};
      final dailyEngagement = <int, int>{};
      
      for (final doc in interactions.docs) {
        final timestamp = (doc.data()['createdAt'] as Timestamp).toDate();
        final hour = timestamp.hour;
        final dayOfWeek = timestamp.weekday;
        
        hourlyEngagement[hour] = (hourlyEngagement[hour] ?? 0) + 1;
        dailyEngagement[dayOfWeek] = (dailyEngagement[dayOfWeek] ?? 0) + 1;
      }
      
      return EngagementPatterns(
        hourlyEngagement: hourlyEngagement,
        dailyEngagement: dailyEngagement,
        totalInteractions: interactions.docs.length,
      );

    } catch (e) {
      return EngagementPatterns.empty();
    }
  }

  List<int> _findPeakEngagementHours(EngagementPatterns patterns) {
    if (patterns.hourlyEngagement.isEmpty) {
      return [9, 12, 18, 21]; // Default peak hours
    }
    
    final sortedHours = patterns.hourlyEngagement.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedHours.take(4).map((e) => e.key).toList();
  }

  List<int> _findPeakEngagementDays(EngagementPatterns patterns) {
    if (patterns.dailyEngagement.isEmpty) {
      return [1, 3, 5]; // Default: Monday, Wednesday, Friday
    }
    
    final sortedDays = patterns.dailyEngagement.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedDays.take(3).map((e) => e.key).toList();
  }

  double _calculatePredictionConfidence(EngagementPatterns patterns) {
    // Confidence based on data volume
    if (patterns.totalInteractions < 10) return 0.3;
    if (patterns.totalInteractions < 50) return 0.6;
    if (patterns.totalInteractions < 100) return 0.8;
    return 0.9;
  }

  DateTime _calculateNextOptimalTime(List<int> peakHours, List<int> peakDays) {
    final now = DateTime.now();
    final currentDay = now.weekday;
    final currentHour = now.hour;
    
    // Find next peak day
    int nextPeakDay = peakDays.firstWhere(
      (day) => day > currentDay,
      orElse: () => peakDays.first,
    );
    
    // Find next peak hour
    int nextPeakHour = peakHours.firstWhere(
      (hour) => hour > currentHour,
      orElse: () => peakHours.first,
    );
    
    // Calculate days to add
    int daysToAdd = nextPeakDay - currentDay;
    if (daysToAdd <= 0) daysToAdd += 7;
    
    return DateTime(
      now.year,
      now.month,
      now.day + daysToAdd,
      nextPeakHour,
      0,
    );
  }

  Future<List<PostModel>> _getRecentPosts(Duration timeWindow, String? location) async {
    try {
      final cutoffTime = DateTime.now().subtract(timeWindow);
      
      var query = _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .orderBy('createdAt', descending: true)
          .limit(500);
      
      if (location != null) {
        query = query.where('location', isEqualTo: location);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();

    } catch (e) {
      debugPrint('❌ Error getting recent posts: $e');
      return [];
    }
  }

  List<String> _extractTopicsFromContent(String content) {
    final topics = <String>[];
    final contentLower = content.toLowerCase();
    
    // Simple keyword-based topic extraction
    const topicKeywords = {
      'agriculture': ['farm', 'crop', 'harvest', 'agriculture'],
      'land_rights': ['land', 'property', 'rights', 'ownership'],
      'legal': ['law', 'legal', 'court', 'case'],
      'government': ['government', 'scheme', 'policy'],
      'education': ['education', 'school', 'student'],
      'health': ['health', 'medical', 'doctor'],
      'community': ['community', 'village', 'people'],
    };
    
    for (final entry in topicKeywords.entries) {
      for (final keyword in entry.value) {
        if (contentLower.contains(keyword)) {
          topics.add(entry.key);
          break;
        }
      }
    }
    
    return topics;
  }

  double _calculateTrendingScore({
    required int mentions,
    required int engagement,
    required Duration timeWindow,
  }) {
    // Trending score combines mentions and engagement with time decay
    final hoursSinceWindow = timeWindow.inHours.toDouble();
    final mentionScore = mentions / hoursSinceWindow;
    final engagementScore = engagement / hoursSinceWindow;
    
    return (mentionScore * 0.4) + (engagementScore * 0.6);
  }

  Future<double> _calculateTopicVelocity(String topic, Duration timeWindow) async {
    try {
      // Calculate how fast the topic is growing
      final halfWindow = Duration(hours: timeWindow.inHours ~/ 2);
      
      final recentPosts = await _getRecentPosts(halfWindow, null);
      final olderPosts = await _getRecentPosts(timeWindow, null);
      
      int recentMentions = 0;
      int olderMentions = 0;
      
      for (final post in recentPosts) {
        if (post.hashtags.any((h) => h.toLowerCase().contains(topic))) {
          recentMentions++;
        }
      }
      
      for (final post in olderPosts) {
        if (post.hashtags.any((h) => h.toLowerCase().contains(topic))) {
          olderMentions++;
        }
      }
      
      // Velocity is the rate of change
      if (olderMentions == 0) return recentMentions.toDouble();
      return (recentMentions - olderMentions) / olderMentions;

    } catch (e) {
      return 0.0;
    }
  }

  PostFeatures _extractPostFeatures(PostModel post) {
    return PostFeatures(
      contentLength: post.content.length,
      hasImages: post.imageUrls.isNotEmpty,
      hasVideos: post.videoUrls.isNotEmpty,
      hashtagCount: post.hashtags.length,
      hasTitle: post.title != null && post.title!.isNotEmpty,
      category: post.category.value,
      location: post.location,
      authorRole: post.authorRole ?? 'member',
      createdAt: post.createdAt,
    );
  }

  double _predictLikeProbability(PostFeatures features, UserBehaviorProfile? userBehavior) {
    double probability = 0.5; // Base probability
    
    // Content features
    if (features.contentLength > 50 && features.contentLength < 500) probability += 0.1;
    if (features.hasImages) probability += 0.15;
    if (features.hasVideos) probability += 0.1;
    if (features.hashtagCount > 0 && features.hashtagCount < 5) probability += 0.05;
    
    // User behavior
    if (userBehavior != null) {
      if (userBehavior.categoryPreferences.containsKey(features.category)) {
        probability += userBehavior.categoryPreferences[features.category]! * 0.2;
      }
    }
    
    return probability.clamp(0.0, 1.0);
  }

  double _predictCommentProbability(PostFeatures features, UserBehaviorProfile? userBehavior) {
    double probability = 0.3; // Base probability (lower than likes)
    
    // Questions tend to get more comments
    if (features.contentLength > 100) probability += 0.1;
    if (features.hasTitle) probability += 0.05;
    
    // User behavior
    if (userBehavior != null && userBehavior.totalInteractions > 20) {
      probability += 0.1;
    }
    
    return probability.clamp(0.0, 1.0);
  }

  double _predictShareProbability(PostFeatures features, UserBehaviorProfile? userBehavior) {
    double probability = 0.2; // Base probability (lowest)
    
    // High-quality content gets shared more
    if (features.hasImages || features.hasVideos) probability += 0.1;
    if (features.contentLength > 200) probability += 0.05;
    if (features.category == 'announcement' || features.category == 'emergency') {
      probability += 0.15;
    }
    
    return probability.clamp(0.0, 1.0);
  }

  double _estimateEngagementCount(double probability, PostFeatures features) {
    // Estimate based on probability and typical engagement rates
    const baseCount = 10.0;
    final multiplier = features.hasImages ? 1.5 : 1.0;
    
    return baseCount * probability * multiplier;
  }

  double _calculateEngagementPredictionConfidence(
    PostFeatures features,
    UserBehaviorProfile? userBehavior,
  ) {
    double confidence = 0.5;
    
    if (userBehavior != null && userBehavior.totalInteractions > 50) {
      confidence += 0.3;
    }
    
    if (features.hasImages || features.hasVideos) {
      confidence += 0.1;
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  Future<void> _trackABTestMetrics(
    String testName,
    String variant,
    String userId,
    List<PostModel> recommendations,
  ) async {
    try {
      final docId = '${testName}_$variant';
      
      await _firestore.collection('ab_test_metrics').doc(docId).set({
        'testName': testName,
        'variant': variant,
        'impressions': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('❌ Error tracking A/B test metrics: $e');
    }
  }
}
