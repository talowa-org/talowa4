// Content Analytics Service for TALOWA
// Implements Task 23: Implement content analytics - Analytics Engine

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';

class ContentAnalyticsService {
  static final ContentAnalyticsService _instance = ContentAnalyticsService._internal();
  factory ContentAnalyticsService() => _instance;
  ContentAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Track post performance metrics
  Future<void> trackPostMetrics({
    required String postId,
    required PostMetricType metricType,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final metricData = {
        'postId': postId,
        'metricType': metricType.toString(),
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'additionalData': additionalData ?? {},
      };

      // Store individual metric event
      await _firestore.collection('post_metrics').add(metricData);

      // Update aggregated metrics
      await _updateAggregatedMetrics(postId, metricType, additionalData);

      debugPrint('Post metric tracked: $postId - $metricType');
    } catch (e) {
      debugPrint('Error tracking post metrics: $e');
    }
  }

  /// Get comprehensive post analytics
  Future<PostAnalytics> getPostAnalytics({
    required String postId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final post = await _getPostData(postId);
      if (post == null) {
        throw Exception('Post not found');
      }

      final dateRange = _getDateRange(startDate, endDate);
      
      final results = await Future.wait([
        _getPostEngagementMetrics(postId, dateRange),
        _getPostReachMetrics(postId, dateRange),
        _getPostImpressionMetrics(postId, dateRange),
        _getPostDemographics(postId, dateRange),
        _getPostPerformanceScore(postId),
      ]);

      return PostAnalytics(
        postId: postId,
        postData: post,
        engagementMetrics: results[0] as EngagementMetrics,
        reachMetrics: results[1] as ReachMetrics,
        impressionMetrics: results[2] as ImpressionMetrics,
        demographics: results[3] as DemographicsData,
        performanceScore: results[4] as double,
        dateRange: dateRange,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting post analytics: $e');
      rethrow;
    }
  }

  /// Get content effectiveness insights
  Future<ContentEffectivenessInsights> getContentEffectivenessInsights({
    String? authorId,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _getDateRange(startDate, endDate);
      
      final results = await Future.wait([
        _getTopPerformingContent(authorId, category, dateRange),
        _getContentTrends(authorId, category, dateRange),
        _getOptimalPostingTimes(authorId, category, dateRange),
        _getContentRecommendations(authorId, category, dateRange),
      ]);

      return ContentEffectivenessInsights(
        topPerformingContent: results[0] as List<PostPerformance>,
        contentTrends: results[1] as List<ContentTrend>,
        optimalPostingTimes: results[2] as List<OptimalTime>,
        recommendations: results[3] as List<ContentRecommendation>,
        dateRange: dateRange,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting content effectiveness insights: $e');
      rethrow;
    }
  }

  /// Get movement analytics dashboard
  Future<MovementAnalytics> getMovementAnalytics({
    String? region,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _getDateRange(startDate, endDate);
      
      final results = await Future.wait([
        _getMovementGrowthMetrics(region, dateRange),
        _getEngagementTrends(region, dateRange),
        _getCampaignEffectiveness(region, dateRange),
        _getGeographicDistribution(region, dateRange),
      ]);

      return MovementAnalytics(
        growthMetrics: results[0] as GrowthMetrics,
        engagementTrends: results[1] as List<EngagementTrend>,
        campaignEffectiveness: results[2] as List<CampaignMetrics>,
        geographicDistribution: results[3] as GeographicDistribution,
        dateRange: dateRange,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting movement analytics: $e');
      rethrow;
    }
  }

  /// Run A/B test for content features
  Future<ABTestResult> runABTest({
    required String testName,
    required String postId,
    required Map<String, dynamic> variantA,
    required Map<String, dynamic> variantB,
    required int targetSampleSize,
    Duration? testDuration,
  }) async {
    try {
      final testId = _generateTestId();
      final endDate = DateTime.now().add(testDuration ?? const Duration(days: 7));

      // Create A/B test record
      await _firestore.collection('ab_tests').doc(testId).set({
        'testName': testName,
        'postId': postId,
        'variantA': variantA,
        'variantB': variantB,
        'targetSampleSize': targetSampleSize,
        'startDate': FieldValue.serverTimestamp(),
        'endDate': Timestamp.fromDate(endDate),
        'status': 'running',
        'results': {},
      });

      return ABTestResult(
        testId: testId,
        testName: testName,
        status: ABTestStatus.running,
        startDate: DateTime.now(),
        endDate: endDate,
        variantAResults: ABVariantResult.empty(),
        variantBResults: ABVariantResult.empty(),
        statisticalSignificance: 0.0,
        winningVariant: null,
      );
    } catch (e) {
      debugPrint('Error running A/B test: $e');
      rethrow;
    }
  }

  /// Get real-time analytics dashboard
  Future<RealTimeAnalytics> getRealTimeAnalytics() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      
      final results = await Future.wait([
        _getRealTimeEngagement(last24Hours),
        _getRealTimeUserActivity(last24Hours),
        _getRealTimeContentMetrics(last24Hours),
        _getRealTimeTrendingTopics(last24Hours),
      ]);

      return RealTimeAnalytics(
        engagement: results[0] as RealTimeEngagement,
        userActivity: results[1] as RealTimeUserActivity,
        contentMetrics: results[2] as RealTimeContentMetrics,
        trendingTopics: results[3] as List<TrendingTopic>,
        lastUpdated: now,
      );
    } catch (e) {
      debugPrint('Error getting real-time analytics: $e');
      rethrow;
    }
  }

  // Private helper methods

  Future<void> _updateAggregatedMetrics(
    String postId,
    PostMetricType metricType,
    Map<String, dynamic>? additionalData,
  ) async {
    try {
      final aggregateRef = _firestore.collection('post_aggregates').doc(postId);
      final updateData = <String, dynamic>{'lastUpdated': FieldValue.serverTimestamp()};

      switch (metricType) {
        case PostMetricType.view:
          updateData['viewCount'] = FieldValue.increment(1);
          updateData['impressions'] = FieldValue.increment(1);
          break;
        case PostMetricType.like:
          updateData['likeCount'] = FieldValue.increment(1);
          updateData['engagementCount'] = FieldValue.increment(1);
          break;
        case PostMetricType.comment:
          updateData['commentCount'] = FieldValue.increment(1);
          updateData['engagementCount'] = FieldValue.increment(1);
          break;
        case PostMetricType.share:
          updateData['shareCount'] = FieldValue.increment(1);
          updateData['engagementCount'] = FieldValue.increment(1);
          break;
        case PostMetricType.click:
          updateData['clickCount'] = FieldValue.increment(1);
          break;
        case PostMetricType.timeSpent:
          final timeSpent = additionalData?['timeSpent'] as int? ?? 0;
          updateData['totalTimeSpent'] = FieldValue.increment(timeSpent);
          break;
      }

      await aggregateRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating aggregated metrics: $e');
    }
  }

  Future<Map<String, dynamic>?> _getPostData(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error getting post data: $e');
      return null;
    }
  }

  DateRange _getDateRange(DateTime? startDate, DateTime? endDate) {
    final end = endDate ?? DateTime.now();
    final start = startDate ?? end.subtract(const Duration(days: 30));
    return DateRange(start: start, end: end);
  }

  Future<EngagementMetrics> _getPostEngagementMetrics(String postId, DateRange dateRange) async {
    try {
      final aggregateDoc = await _firestore.collection('post_aggregates').doc(postId).get();
      if (!aggregateDoc.exists) return EngagementMetrics.empty();

      final data = aggregateDoc.data()!;
      return EngagementMetrics(
        likes: data['likeCount'] ?? 0,
        comments: data['commentCount'] ?? 0,
        shares: data['shareCount'] ?? 0,
        clicks: data['clickCount'] ?? 0,
        totalEngagements: data['engagementCount'] ?? 0,
        engagementRate: _calculateEngagementRate(data),
        averageTimeSpent: _calculateAverageTimeSpent(data),
      );
    } catch (e) {
      debugPrint('Error getting engagement metrics: $e');
      return EngagementMetrics.empty();
    }
  }

  Future<ReachMetrics> _getPostReachMetrics(String postId, DateRange dateRange) async {
    try {
      final metricsSnapshot = await _firestore
          .collection('post_metrics')
          .where('postId', isEqualTo: postId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final uniqueUsers = <String>{};
      final organicReach = <String>{};
      final viralReach = <String>{};

      for (final doc in metricsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        
        if (userId != null) {
          uniqueUsers.add(userId);
          final additionalData = data['additionalData'] as Map<String, dynamic>? ?? {};
          final source = additionalData['source'] as String? ?? 'organic';
          
          if (source == 'share' || source == 'viral') {
            viralReach.add(userId);
          } else {
            organicReach.add(userId);
          }
        }
      }

      return ReachMetrics(
        totalReach: uniqueUsers.length,
        organicReach: organicReach.length,
        viralReach: viralReach.length,
        reachRate: 0.0,
        uniqueUsers: uniqueUsers.length,
      );
    } catch (e) {
      debugPrint('Error getting reach metrics: $e');
      return ReachMetrics.empty();
    }
  }

  Future<ImpressionMetrics> _getPostImpressionMetrics(String postId, DateRange dateRange) async {
    try {
      final aggregateDoc = await _firestore.collection('post_aggregates').doc(postId).get();
      if (!aggregateDoc.exists) return ImpressionMetrics.empty();

      final data = aggregateDoc.data()!;
      final impressions = data['impressions'] ?? 0;
      final views = data['viewCount'] ?? 0;
      
      return ImpressionMetrics(
        totalImpressions: impressions,
        uniqueImpressions: views,
        impressionRate: 0.0,
        viewThroughRate: views > 0 ? views / impressions : 0.0,
      );
    } catch (e) {
      debugPrint('Error getting impression metrics: $e');
      return ImpressionMetrics.empty();
    }
  }

  Future<DemographicsData> _getPostDemographics(String postId, DateRange dateRange) async {
    try {
      final metricsSnapshot = await _firestore
          .collection('post_metrics')
          .where('postId', isEqualTo: postId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      final userIds = metricsSnapshot.docs
          .map((doc) => doc.data()['userId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      if (userIds.isEmpty) return DemographicsData.empty();

      final ageGroups = <String, int>{};
      final genders = <String, int>{};
      final locations = <String, int>{};
      final roles = <String, int>{};

      for (final userId in userIds.take(100)) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            
            final age = userData['age'] as int?;
            if (age != null) {
              final ageGroup = _getAgeGroup(age);
              ageGroups[ageGroup] = (ageGroups[ageGroup] ?? 0) + 1;
            }
            
            final gender = userData['gender'] as String? ?? 'unknown';
            genders[gender] = (genders[gender] ?? 0) + 1;
            
            final location = userData['location'] as String? ?? 'unknown';
            locations[location] = (locations[location] ?? 0) + 1;
            
            final role = userData['role'] as String? ?? 'member';
            roles[role] = (roles[role] ?? 0) + 1;
          }
        } catch (e) {
          continue;
        }
      }

      return DemographicsData(
        ageGroups: ageGroups,
        genders: genders,
        locations: locations,
        roles: roles,
        totalUsers: userIds.length,
      );
    } catch (e) {
      debugPrint('Error getting demographics: $e');
      return DemographicsData.empty();
    }
  }

  Future<double> _getPostPerformanceScore(String postId) async {
    try {
      final aggregateDoc = await _firestore.collection('post_aggregates').doc(postId).get();
      if (!aggregateDoc.exists) return 0.0;

      final data = aggregateDoc.data()!;
      final likes = (data['likeCount'] ?? 0) as int;
      final comments = (data['commentCount'] ?? 0) as int;
      final shares = (data['shareCount'] ?? 0) as int;
      final views = (data['viewCount'] ?? 0) as int;
      final timeSpent = (data['totalTimeSpent'] ?? 0) as int;

      double score = 0.0;
      score += likes * 1.0;
      score += comments * 3.0;
      score += shares * 5.0;
      score += views * 0.1;
      score += (timeSpent / 1000) * 0.5;

      return min(score / 10, 100.0);
    } catch (e) {
      debugPrint('Error calculating performance score: $e');
      return 0.0;
    }
  }

  // Additional helper methods for analytics calculations
  double _calculateEngagementRate(Map<String, dynamic> data) {
    final engagements = (data['engagementCount'] ?? 0) as int;
    final views = (data['viewCount'] ?? 0) as int;
    return views > 0 ? engagements / views : 0.0;
  }

  double _calculateAverageTimeSpent(Map<String, dynamic> data) {
    final totalTime = (data['totalTimeSpent'] ?? 0) as int;
    final views = (data['viewCount'] ?? 0) as int;
    return views > 0 ? totalTime / views / 1000 : 0.0;
  }

  String _getAgeGroup(int age) {
    if (age < 18) return '13-17';
    if (age < 25) return '18-24';
    if (age < 35) return '25-34';
    if (age < 45) return '35-44';
    if (age < 55) return '45-54';
    return '55+';
  }

  String _generateTestId() {
    return 'test_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Placeholder implementations for complex analytics methods
  Future<List<PostPerformance>> _getTopPerformingContent(String? authorId, String? category, DateRange dateRange) async {
    return []; // Implementation would analyze top performing posts
  }

  Future<List<ContentTrend>> _getContentTrends(String? authorId, String? category, DateRange dateRange) async {
    return []; // Implementation would analyze content trends
  }

  Future<List<OptimalTime>> _getOptimalPostingTimes(String? authorId, String? category, DateRange dateRange) async {
    return []; // Implementation would analyze optimal posting times
  }

  Future<List<ContentRecommendation>> _getContentRecommendations(String? authorId, String? category, DateRange dateRange) async {
    return []; // Implementation would generate AI recommendations
  }

  Future<GrowthMetrics> _getMovementGrowthMetrics(String? region, DateRange dateRange) async {
    return GrowthMetrics.empty(); // Implementation would calculate growth metrics
  }

  Future<List<EngagementTrend>> _getEngagementTrends(String? region, DateRange dateRange) async {
    return []; // Implementation would analyze engagement trends
  }

  Future<List<CampaignMetrics>> _getCampaignEffectiveness(String? region, DateRange dateRange) async {
    return []; // Implementation would analyze campaign effectiveness
  }

  Future<GeographicDistribution> _getGeographicDistribution(String? region, DateRange dateRange) async {
    return GeographicDistribution.empty(); // Implementation would analyze geographic distribution
  }

  Future<RealTimeEngagement> _getRealTimeEngagement(DateTime since) async {
    return RealTimeEngagement.empty(); // Implementation would get real-time engagement
  }

  Future<RealTimeUserActivity> _getRealTimeUserActivity(DateTime since) async {
    return RealTimeUserActivity.empty(); // Implementation would get real-time user activity
  }

  Future<RealTimeContentMetrics> _getRealTimeContentMetrics(DateTime since) async {
    return RealTimeContentMetrics.empty(); // Implementation would get real-time content metrics
  }

  Future<List<TrendingTopic>> _getRealTimeTrendingTopics(DateTime since) async {
    return []; // Implementation would analyze trending topics
  }
}

// Enums and basic data models
enum PostMetricType { view, like, comment, share, click, timeSpent }
enum ABTestStatus { running, completed, cancelled }

class DateRange {
  final DateTime start;
  final DateTime end;
  DateRange({required this.start, required this.end});
  int get durationInDays => end.difference(start).inDays;
}