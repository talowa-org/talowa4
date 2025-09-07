// Advanced Analytics Service - Comprehensive analytics and insights
// Complete analytics system for TALOWA platform

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/analytics/analytics_model.dart';

class AdvancedAnalyticsService {
  static AdvancedAnalyticsService? _instance;
  static AdvancedAnalyticsService get instance => _instance ??= AdvancedAnalyticsService._internal();
  
  AdvancedAnalyticsService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Analytics collections
  static const String _userAnalyticsCollection = 'user_analytics';
  static const String _contentAnalyticsCollection = 'content_analytics';
  static const String _searchAnalyticsCollection = 'search_analytics';
  static const String _engagementAnalyticsCollection = 'engagement_analytics';
  static const String _activismAnalyticsCollection = 'activism_analytics';
  
  /// Get comprehensive user analytics
  Future<UserAnalyticsModel> getUserAnalytics(String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('ðŸ“Š Getting user analytics for: $userId');
      
      final now = DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 30));
      final end = endDate ?? now;
      
      // Get user engagement metrics
      final engagementMetrics = await _getUserEngagementMetrics(userId, start, end);
      
      // Get content performance metrics
      final contentMetrics = await _getUserContentMetrics(userId, start, end);
      
      // Get search behavior metrics
      final searchMetrics = await _getUserSearchMetrics(userId, start, end);
      
      // Get activism impact metrics
      final activismMetrics = await _getUserActivismMetrics(userId, start, end);
      
      // Get growth metrics
      final growthMetrics = await _getUserGrowthMetrics(userId, start, end);
      
      final analytics = UserAnalyticsModel(
        userId: userId,
        periodStart: start,
        periodEnd: end,
        engagementMetrics: engagementMetrics,
        contentMetrics: contentMetrics,
        searchMetrics: searchMetrics,
        activismMetrics: activismMetrics,
        growthMetrics: growthMetrics,
        generatedAt: DateTime.now(),
      );
      
      debugPrint('âœ… User analytics generated successfully');
      return analytics;
      
    } catch (e) {
      debugPrint('âŒ Failed to get user analytics: $e');
      rethrow;
    }
  }
  
  /// Get platform-wide analytics
  Future<PlatformAnalyticsModel> getPlatformAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('ðŸ“Š Getting platform analytics...');
      
      final now = DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 30));
      final end = endDate ?? now;
      
      // Get user metrics
      final userMetrics = await _getPlatformUserMetrics(start, end);
      
      // Get content metrics
      final contentMetrics = await _getPlatformContentMetrics(start, end);
      
      // Get engagement metrics
      final engagementMetrics = await _getPlatformEngagementMetrics(start, end);
      
      // Get search metrics
      final searchMetrics = await _getPlatformSearchMetrics(start, end);
      
      // Get activism impact metrics
      final activismMetrics = await _getPlatformActivismMetrics(start, end);
      
      final analytics = PlatformAnalyticsModel(
        periodStart: start,
        periodEnd: end,
        userMetrics: userMetrics,
        contentMetrics: contentMetrics,
        engagementMetrics: engagementMetrics,
        searchMetrics: searchMetrics,
        activismMetrics: activismMetrics,
        generatedAt: DateTime.now(),
      );
      
      debugPrint('âœ… Platform analytics generated successfully');
      return analytics;
      
    } catch (e) {
      debugPrint('âŒ Failed to get platform analytics: $e');
      rethrow;
    }
  }
  
  /// Track user engagement event
  Future<void> trackEngagementEvent(EngagementEvent event) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      final eventData = {
        'userId': currentUser.uid,
        'eventType': event.type.toString(),
        'eventCategory': event.category,
        'eventAction': event.action,
        'eventLabel': event.label,
        'eventValue': event.value,
        'metadata': event.metadata,
        'timestamp': FieldValue.serverTimestamp(),
        'sessionId': event.sessionId,
        'deviceInfo': event.deviceInfo,
        'location': event.location,
      };
      
      await _firestore
          .collection(_engagementAnalyticsCollection)
          .add(eventData);
      
      debugPrint('ðŸ“Š Engagement event tracked: ${event.type}');
      
    } catch (e) {
      debugPrint('âŒ Failed to track engagement event: $e');
    }
  }
  
  /// Track content performance
  Future<void> trackContentPerformance(ContentPerformanceEvent event) async {
    try {
      final eventData = {
        'contentId': event.contentId,
        'contentType': event.contentType,
        'authorId': event.authorId,
        'performanceMetric': event.metric.toString(),
        'value': event.value,
        'metadata': event.metadata,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection(_contentAnalyticsCollection)
          .add(eventData);
      
      debugPrint('ðŸ“Š Content performance tracked: ${event.metric}');
      
    } catch (e) {
      debugPrint('âŒ Failed to track content performance: $e');
    }
  }
  
  /// Track search analytics
  Future<void> trackSearchEvent(SearchAnalyticsEvent event) async {
    try {
      final currentUser = _auth.currentUser;
      
      final eventData = {
        'userId': currentUser?.uid,
        'query': event.query,
        'searchType': event.searchType.toString(),
        'resultsCount': event.resultsCount,
        'clickedResultIndex': event.clickedResultIndex,
        'clickedResultId': event.clickedResultId,
        'searchDuration': event.searchDuration,
        'filters': event.filters,
        'metadata': event.metadata,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection(_searchAnalyticsCollection)
          .add(eventData);
      
      debugPrint('ðŸ“Š Search event tracked: ${event.searchType}');
      
    } catch (e) {
      debugPrint('âŒ Failed to track search event: $e');
    }
  }
  
  /// Track activism impact
  Future<void> trackActivismImpact(ActivismImpactEvent event) async {
    try {
      final eventData = {
        'userId': event.userId,
        'impactType': event.impactType.toString(),
        'impactCategory': event.impactCategory,
        'impactValue': event.impactValue,
        'beneficiaries': event.beneficiaries,
        'location': event.location,
        'caseId': event.caseId,
        'campaignId': event.campaignId,
        'metadata': event.metadata,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection(_activismAnalyticsCollection)
          .add(eventData);
      
      debugPrint('ðŸ“Š Activism impact tracked: ${event.impactType}');
      
    } catch (e) {
      debugPrint('âŒ Failed to track activism impact: $e');
    }
  }
  
  /// Get user engagement metrics
  Future<EngagementMetrics> _getUserEngagementMetrics(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final query = await _firestore
        .collection(_engagementAnalyticsCollection)
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    
    final events = query.docs;
    
    // Calculate engagement metrics
    final totalEvents = events.length;
    final uniqueSessions = events.map((e) => e.data()['sessionId']).toSet().length;
    final avgSessionDuration = _calculateAverageSessionDuration(events);
    final engagementRate = _calculateEngagementRate(events);
    final topActions = _getTopActions(events);
    
    return EngagementMetrics(
      totalEvents: totalEvents,
      uniqueSessions: uniqueSessions,
      averageSessionDuration: avgSessionDuration,
      engagementRate: engagementRate,
      topActions: topActions,
    );
  }
  
  /// Get user content metrics
  Future<ContentMetrics> _getUserContentMetrics(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final query = await _firestore
        .collection(_contentAnalyticsCollection)
        .where('authorId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    
    final events = query.docs;
    
    // Calculate content metrics
    final totalPosts = _countContentByType(events, 'post');
    final totalViews = _sumMetricValues(events, ContentPerformanceMetric.view);
    final totalLikes = _sumMetricValues(events, ContentPerformanceMetric.like);
    final totalComments = _sumMetricValues(events, ContentPerformanceMetric.comment);
    final totalShares = _sumMetricValues(events, ContentPerformanceMetric.share);
    final avgEngagementRate = _calculateContentEngagementRate(events);
    final topPerformingContent = _getTopPerformingContent(events);
    
    return ContentMetrics(
      totalPosts: totalPosts,
      totalViews: totalViews,
      totalLikes: totalLikes,
      totalComments: totalComments,
      totalShares: totalShares,
      averageEngagementRate: avgEngagementRate,
      topPerformingContent: topPerformingContent,
    );
  }
  
  /// Get user search metrics
  Future<SearchMetrics> _getUserSearchMetrics(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final query = await _firestore
        .collection(_searchAnalyticsCollection)
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    
    final events = query.docs;
    
    // Calculate search metrics
    final totalSearches = events.length;
    final uniqueQueries = events.map((e) => e.data()['query']).toSet().length;
    final avgResultsCount = _calculateAverageResultsCount(events);
    final clickThroughRate = _calculateClickThroughRate(events);
    final topQueries = _getTopQueries(events);
    final searchTypes = _getSearchTypeDistribution(events);
    
    return SearchMetrics(
      totalSearches: totalSearches,
      uniqueQueries: uniqueQueries,
      averageResultsCount: avgResultsCount,
      clickThroughRate: clickThroughRate,
      topQueries: topQueries,
      searchTypeDistribution: searchTypes,
    );
  }
  
  /// Get user activism metrics
  Future<ActivismMetrics> _getUserActivismMetrics(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final query = await _firestore
        .collection(_activismAnalyticsCollection)
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    
    final events = query.docs;
    
    // Calculate activism metrics
    final totalImpactEvents = events.length;
    final totalBeneficiaries = _sumBeneficiaries(events);
    final impactScore = _calculateImpactScore(events);
    final casesSupported = _countUniqueCases(events);
    final campaignsParticipated = _countUniqueCampaigns(events);
    final impactCategories = _getImpactCategoryDistribution(events);
    
    return ActivismMetrics(
      totalImpactEvents: totalImpactEvents,
      totalBeneficiaries: totalBeneficiaries,
      impactScore: impactScore,
      casesSupported: casesSupported,
      campaignsParticipated: campaignsParticipated,
      impactCategoryDistribution: impactCategories,
    );
  }
  
  /// Get user growth metrics
  Future<GrowthMetrics> _getUserGrowthMetrics(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    // Get follower growth
    final followerGrowth = await _getFollowerGrowth(userId, start, end);
    
    // Get content reach growth
    final reachGrowth = await _getReachGrowth(userId, start, end);
    
    // Get engagement growth
    final engagementGrowth = await _getEngagementGrowth(userId, start, end);
    
    return GrowthMetrics(
      followerGrowth: followerGrowth,
      reachGrowth: reachGrowth,
      engagementGrowth: engagementGrowth,
    );
  }
  
  /// Helper methods for calculations
  double _calculateAverageSessionDuration(List<QueryDocumentSnapshot> events) {
    // Implementation for calculating average session duration
    return 0.0; // Placeholder
  }
  
  double _calculateEngagementRate(List<QueryDocumentSnapshot> events) {
    // Implementation for calculating engagement rate
    return 0.0; // Placeholder
  }
  
  List<String> _getTopActions(List<QueryDocumentSnapshot> events) {
    // Implementation for getting top actions
    return []; // Placeholder
  }
  
  int _countContentByType(List<QueryDocumentSnapshot> events, String type) {
    return events.where((e) => e.data()['contentType'] == type).length;
  }
  
  int _sumMetricValues(List<QueryDocumentSnapshot> events, ContentPerformanceMetric metric) {
    return events
        .where((e) => e.data()['performanceMetric'] == metric.toString())
        .fold(0, (sum, e) => sum + (e.data()['value'] as int? ?? 0));
  }
  
  double _calculateContentEngagementRate(List<QueryDocumentSnapshot> events) {
    // Implementation for calculating content engagement rate
    return 0.0; // Placeholder
  }
  
  List<String> _getTopPerformingContent(List<QueryDocumentSnapshot> events) {
    // Implementation for getting top performing content
    return []; // Placeholder
  }
  
  double _calculateAverageResultsCount(List<QueryDocumentSnapshot> events) {
    if (events.isEmpty) return 0.0;
    
    final totalResults = events.fold(0, (sum, e) => 
        sum + (e.data()['resultsCount'] as int? ?? 0));
    
    return totalResults / events.length;
  }
  
  double _calculateClickThroughRate(List<QueryDocumentSnapshot> events) {
    if (events.isEmpty) return 0.0;
    
    final clickedEvents = events.where((e) => 
        e.data()['clickedResultId'] != null).length;
    
    return clickedEvents / events.length;
  }
  
  List<String> _getTopQueries(List<QueryDocumentSnapshot> events) {
    final queryCount = <String, int>{};
    
    for (final event in events) {
      final query = event.data()['query'] as String?;
      if (query != null) {
        queryCount[query] = (queryCount[query] ?? 0) + 1;
      }
    }
    
    final sortedQueries = queryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedQueries.take(10).map((e) => e.key).toList();
  }
  
  Map<String, int> _getSearchTypeDistribution(List<QueryDocumentSnapshot> events) {
    final distribution = <String, int>{};
    
    for (final event in events) {
      final searchType = event.data()['searchType'] as String?;
      if (searchType != null) {
        distribution[searchType] = (distribution[searchType] ?? 0) + 1;
      }
    }
    
    return distribution;
  }
  
  int _sumBeneficiaries(List<QueryDocumentSnapshot> events) {
    return events.fold(0, (sum, e) => 
        sum + (e.data()['beneficiaries'] as int? ?? 0));
  }
  
  double _calculateImpactScore(List<QueryDocumentSnapshot> events) {
    // Implementation for calculating impact score
    return 0.0; // Placeholder
  }
  
  int _countUniqueCases(List<QueryDocumentSnapshot> events) {
    return events
        .map((e) => e.data()['caseId'])
        .where((id) => id != null)
        .toSet()
        .length;
  }
  
  int _countUniqueCampaigns(List<QueryDocumentSnapshot> events) {
    return events
        .map((e) => e.data()['campaignId'])
        .where((id) => id != null)
        .toSet()
        .length;
  }
  
  Map<String, int> _getImpactCategoryDistribution(List<QueryDocumentSnapshot> events) {
    final distribution = <String, int>{};
    
    for (final event in events) {
      final category = event.data()['impactCategory'] as String?;
      if (category != null) {
        distribution[category] = (distribution[category] ?? 0) + 1;
      }
    }
    
    return distribution;
  }
  
  Future<List<GrowthDataPoint>> _getFollowerGrowth(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    // Implementation for getting follower growth data
    return []; // Placeholder
  }
  
  Future<List<GrowthDataPoint>> _getReachGrowth(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    // Implementation for getting reach growth data
    return []; // Placeholder
  }
  
  Future<List<GrowthDataPoint>> _getEngagementGrowth(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    // Implementation for getting engagement growth data
    return []; // Placeholder
  }
  
  // Platform-wide analytics methods
  Future<PlatformUserMetrics> _getPlatformUserMetrics(DateTime start, DateTime end) async {
    // Implementation for platform user metrics
    return const PlatformUserMetrics(
      totalUsers: 0,
      activeUsers: 0,
      newUsers: 0,
      retentionRate: 0.0,
    ); // Placeholder
  }
  
  Future<PlatformContentMetrics> _getPlatformContentMetrics(DateTime start, DateTime end) async {
    // Implementation for platform content metrics
    return const PlatformContentMetrics(
      totalPosts: 0,
      totalViews: 0,
      totalEngagements: 0,
      averageEngagementRate: 0.0,
    ); // Placeholder
  }
  
  Future<PlatformEngagementMetrics> _getPlatformEngagementMetrics(DateTime start, DateTime end) async {
    // Implementation for platform engagement metrics
    return const PlatformEngagementMetrics(
      totalSessions: 0,
      averageSessionDuration: 0.0,
      bounceRate: 0.0,
      pageViews: 0,
    ); // Placeholder
  }
  
  Future<PlatformSearchMetrics> _getPlatformSearchMetrics(DateTime start, DateTime end) async {
    // Implementation for platform search metrics
    return const PlatformSearchMetrics(
      totalSearches: 0,
      uniqueQueries: 0,
      averageClickThroughRate: 0.0,
      searchSuccessRate: 0.0,
    ); // Placeholder
  }
  
  Future<PlatformActivismMetrics> _getPlatformActivismMetrics(DateTime start, DateTime end) async {
    // Implementation for platform activism metrics
    return const PlatformActivismMetrics(
      totalCases: 0,
      resolvedCases: 0,
      totalBeneficiaries: 0,
      impactScore: 0.0,
    ); // Placeholder
  }
}

