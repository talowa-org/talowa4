// Search Analytics Service - Track and optimize search performance
// Complete search analytics for TALOWA platform

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchAnalyticsService {
  static SearchAnalyticsService? _instance;
  static SearchAnalyticsService get instance => _instance ??= SearchAnalyticsService._internal();
  
  SearchAnalyticsService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Track search query
  Future<void> trackSearchQuery(
    String query,
    String userId, {
    int? resultCount,
    int? processingTimeMs,
    String? searchType,
    Map<String, dynamic>? filters,
  }) async {
    try {
      await _firestore.collection('search_analytics').add({
        'query': query.toLowerCase().trim(),
        'userId': userId,
        'resultCount': resultCount ?? 0,
        'processingTimeMs': processingTimeMs ?? 0,
        'searchType': searchType ?? 'universal',
        'filters': filters ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD
      });
      
      debugPrint('ðŸ“Š Tracked search query: "$query"');
    } catch (e) {
      debugPrint('âŒ Failed to track search query: $e');
    }
  }
  
  /// Track search result click
  Future<void> trackResultClick(
    String query,
    String resultId,
    String resultType,
    int position,
    String userId,
  ) async {
    try {
      await _firestore.collection('search_clicks').add({
        'query': query.toLowerCase().trim(),
        'resultId': resultId,
        'resultType': resultType,
        'position': position,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      });
      
      debugPrint('ðŸ–±ï¸ Tracked result click: $resultType at position $position');
    } catch (e) {
      debugPrint('âŒ Failed to track result click: $e');
    }
  }
  
  /// Track search session
  Future<void> trackSearchSession(
    String sessionId,
    String userId,
    List<String> queries,
    int totalResults,
    int totalClicks,
    Duration sessionDuration,
  ) async {
    try {
      await _firestore.collection('search_sessions').add({
        'sessionId': sessionId,
        'userId': userId,
        'queries': queries,
        'queryCount': queries.length,
        'totalResults': totalResults,
        'totalClicks': totalClicks,
        'sessionDurationMs': sessionDuration.inMilliseconds,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      });
      
      debugPrint('ðŸ“ˆ Tracked search session: ${queries.length} queries, $totalClicks clicks');
    } catch (e) {
      debugPrint('âŒ Failed to track search session: $e');
    }
  }
  
  /// Get popular search queries
  Future<List<PopularQuery>> getPopularQueries({
    int limit = 10,
    int? days,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('search_analytics');
      
      // Filter by date range if specified
      if (days != null) {
        final cutoffDate = DateTime.now().subtract(Duration(days: days));
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate));
      }
      
      final snapshot = await query.get();
      
      // Aggregate queries
      final queryMap = <String, QueryStats>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final queryText = data['query'] as String;
        final resultCount = data['resultCount'] as int? ?? 0;
        
        if (queryMap.containsKey(queryText)) {
          queryMap[queryText]!.count++;
          queryMap[queryText]!.totalResults += resultCount;
        } else {
          queryMap[queryText] = QueryStats(
            query: queryText,
            count: 1,
            totalResults: resultCount,
          );
        }
      }
      
      // Sort by frequency and convert to PopularQuery
      final popularQueries = queryMap.values
          .where((stats) => stats.query.isNotEmpty)
          .map((stats) => PopularQuery(
                query: stats.query,
                searchCount: stats.count,
                avgResults: stats.totalResults / stats.count,
              ))
          .toList();
      
      popularQueries.sort((a, b) => b.searchCount.compareTo(a.searchCount));
      
      debugPrint('ðŸ“Š Retrieved ${popularQueries.length} popular queries');
      return popularQueries.take(limit).toList();
      
    } catch (e) {
      debugPrint('âŒ Failed to get popular queries: $e');
      return [];
    }
  }
  
  /// Get search performance metrics
  Future<SearchMetrics> getSearchMetrics({int? days}) async {
    try {
      Query<Map<String, dynamic>> analyticsQuery = _firestore
          .collection('search_analytics');
      
      Query<Map<String, dynamic>> clicksQuery = _firestore
          .collection('search_clicks');
      
      // Filter by date range if specified
      if (days != null) {
        final cutoffDate = DateTime.now().subtract(Duration(days: days));
        final cutoffTimestamp = Timestamp.fromDate(cutoffDate);
        
        analyticsQuery = analyticsQuery.where('timestamp', isGreaterThanOrEqualTo: cutoffTimestamp);
        clicksQuery = clicksQuery.where('timestamp', isGreaterThanOrEqualTo: cutoffTimestamp);
      }
      
      final analyticsSnapshot = await analyticsQuery.get();
      final clicksSnapshot = await clicksQuery.get();
      
      // Calculate metrics
      int totalSearches = analyticsSnapshot.docs.length;
      int totalClicks = clicksSnapshot.docs.length;
      int totalResults = 0;
      int totalProcessingTime = 0;
      int zeroResultSearches = 0;
      
      for (final doc in analyticsSnapshot.docs) {
        final data = doc.data();
        final resultCount = data['resultCount'] as int? ?? 0;
        final processingTime = data['processingTimeMs'] as int? ?? 0;
        
        totalResults += resultCount;
        totalProcessingTime += processingTime;
        
        if (resultCount == 0) {
          zeroResultSearches++;
        }
      }
      
      final metrics = SearchMetrics(
        totalSearches: totalSearches,
        totalClicks: totalClicks,
        totalResults: totalResults,
        avgResultsPerSearch: totalSearches > 0 ? totalResults / totalSearches : 0,
        avgProcessingTimeMs: totalSearches > 0 ? totalProcessingTime / totalSearches : 0,
        clickThroughRate: totalSearches > 0 ? totalClicks / totalSearches : 0,
        zeroResultRate: totalSearches > 0 ? zeroResultSearches / totalSearches : 0,
        period: days != null ? '$days days' : 'all time',
      );
      
      debugPrint('ðŸ“ˆ Retrieved search metrics: ${metrics.totalSearches} searches, ${(metrics.clickThroughRate * 100).toStringAsFixed(1)}% CTR');
      return metrics;
      
    } catch (e) {
      debugPrint('âŒ Failed to get search metrics: $e');
      return SearchMetrics.empty();
    }
  }
  
  /// Get trending search terms
  Future<List<TrendingQuery>> getTrendingQueries({
    int limit = 10,
    int days = 7,
  }) async {
    try {
      final now = DateTime.now();
      final currentPeriodStart = now.subtract(Duration(days: days));
      final previousPeriodStart = currentPeriodStart.subtract(Duration(days: days));
      
      // Get current period queries
      final currentSnapshot = await _firestore
          .collection('search_analytics')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(currentPeriodStart))
          .get();
      
      // Get previous period queries
      final previousSnapshot = await _firestore
          .collection('search_analytics')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(previousPeriodStart))
          .where('timestamp', isLessThan: Timestamp.fromDate(currentPeriodStart))
          .get();
      
      // Aggregate current period
      final currentQueries = <String, int>{};
      for (final doc in currentSnapshot.docs) {
        final query = doc.data()['query'] as String;
        currentQueries[query] = (currentQueries[query] ?? 0) + 1;
      }
      
      // Aggregate previous period
      final previousQueries = <String, int>{};
      for (final doc in previousSnapshot.docs) {
        final query = doc.data()['query'] as String;
        previousQueries[query] = (previousQueries[query] ?? 0) + 1;
      }
      
      // Calculate trends
      final trendingQueries = <TrendingQuery>[];
      
      for (final entry in currentQueries.entries) {
        final query = entry.key;
        final currentCount = entry.value;
        final previousCount = previousQueries[query] ?? 0;
        
        if (query.isNotEmpty && currentCount >= 2) { // Minimum threshold
          final growthRate = previousCount > 0 
              ? (currentCount - previousCount) / previousCount
              : double.infinity; // New queries have infinite growth
          
          trendingQueries.add(TrendingQuery(
            query: query,
            currentCount: currentCount,
            previousCount: previousCount,
            growthRate: growthRate,
          ));
        }
      }
      
      // Sort by growth rate and current count
      trendingQueries.sort((a, b) {
        if (a.growthRate == double.infinity && b.growthRate == double.infinity) {
          return b.currentCount.compareTo(a.currentCount);
        } else if (a.growthRate == double.infinity) {
          return -1;
        } else if (b.growthRate == double.infinity) {
          return 1;
        } else {
          return b.growthRate.compareTo(a.growthRate);
        }
      });
      
      debugPrint('ðŸ”¥ Retrieved ${trendingQueries.length} trending queries');
      return trendingQueries.take(limit).toList();
      
    } catch (e) {
      debugPrint('âŒ Failed to get trending queries: $e');
      return [];
    }
  }
  
  /// Get failed searches (zero results)
  Future<List<String>> getFailedSearches({
    int limit = 20,
    int? days,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('search_analytics')
          .where('resultCount', isEqualTo: 0);
      
      if (days != null) {
        final cutoffDate = DateTime.now().subtract(Duration(days: days));
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate));
      }
      
      final snapshot = await query.get();
      
      final failedQueries = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final queryText = doc.data()['query'] as String;
        if (queryText.isNotEmpty) {
          failedQueries[queryText] = (failedQueries[queryText] ?? 0) + 1;
        }
      }
      
      final sortedFailures = failedQueries.entries.toList();
      sortedFailures.sort((a, b) => b.value.compareTo(a.value));
      
      final result = sortedFailures.take(limit).map((e) => e.key).toList();
      
      debugPrint('âŒ Retrieved ${result.length} failed searches');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Failed to get failed searches: $e');
      return [];
    }
  }
}

// Data models for analytics
class PopularQuery {
  final String query;
  final int searchCount;
  final double avgResults;

  const PopularQuery({
    required this.query,
    required this.searchCount,
    required this.avgResults,
  });
}

class TrendingQuery {
  final String query;
  final int currentCount;
  final int previousCount;
  final double growthRate;

  const TrendingQuery({
    required this.query,
    required this.currentCount,
    required this.previousCount,
    required this.growthRate,
  });
}

class SearchMetrics {
  final int totalSearches;
  final int totalClicks;
  final int totalResults;
  final double avgResultsPerSearch;
  final double avgProcessingTimeMs;
  final double clickThroughRate;
  final double zeroResultRate;
  final String period;

  const SearchMetrics({
    required this.totalSearches,
    required this.totalClicks,
    required this.totalResults,
    required this.avgResultsPerSearch,
    required this.avgProcessingTimeMs,
    required this.clickThroughRate,
    required this.zeroResultRate,
    required this.period,
  });

  factory SearchMetrics.empty() {
    return const SearchMetrics(
      totalSearches: 0,
      totalClicks: 0,
      totalResults: 0,
      avgResultsPerSearch: 0,
      avgProcessingTimeMs: 0,
      clickThroughRate: 0,
      zeroResultRate: 0,
      period: 'no data',
    );
  }
}

class QueryStats {
  final String query;
  int count;
  int totalResults;

  QueryStats({
    required this.query,
    required this.count,
    required this.totalResults,
  });
}

