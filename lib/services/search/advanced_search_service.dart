// Advanced Search Service for TALOWA
// Implements Task 24: Add advanced search and discovery - Search Engine

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';

class AdvancedSearchService {
  static final AdvancedSearchService _instance = AdvancedSearchService._internal();
  factory AdvancedSearchService() => _instance;
  AdvancedSearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Perform full-text search with ranking
  Future<SearchResults> performFullTextSearch({
    required String query,
    SearchFilters? filters,
    int limit = 20,
    String? lastDocumentId,
  }) async {
    try {
      debugPrint('Performing full-text search: $query');
      
      final searchTerms = _preprocessQuery(query);
      final results = await _executeFullTextSearch(
        searchTerms: searchTerms,
        filters: filters,
        limit: limit,
        lastDocumentId: lastDocumentId,
      );

      // Rank results based on relevance
      final rankedResults = await _rankSearchResults(results, searchTerms);

      // Track search analytics
      await _trackSearchAnalytics(query, filters, rankedResults.length);

      return SearchResults(
        query: query,
        results: rankedResults,
        totalResults: rankedResults.length,
        hasMore: rankedResults.length == limit,
        searchTime: DateTime.now(),
        suggestions: await _generateSearchSuggestions(query),
      );
    } catch (e) {
      debugPrint('Error performing full-text search: $e');
      return SearchResults.empty(query);
    }
  }

  /// Get AI-powered content recommendations
  Future<List<ContentRecommendation>> getContentRecommendations({
    required String userId,
    int limit = 10,
    RecommendationType type = RecommendationType.personalized,
  }) async {
    try {
      debugPrint('Getting content recommendations for user: $userId');
      
      switch (type) {
        case RecommendationType.personalized:
          return await _getPersonalizedRecommendations(userId, limit);
        case RecommendationType.trending:
          return await _getTrendingRecommendations(limit);
        case RecommendationType.similar:
          return await _getSimilarContentRecommendations(userId, limit);
        case RecommendationType.collaborative:
          return await _getCollaborativeRecommendations(userId, limit);
      }
    } catch (e) {
      debugPrint('Error getting content recommendations: $e');
      return [];
    }
  }

  /// Perform semantic search using AI
  Future<List<SearchResult>> performSemanticSearch({
    required String query,
    SearchFilters? filters,
    int limit = 20,
  }) async {
    try {
      debugPrint('Performing semantic search: $query');
      
      // Generate semantic embeddings for the query
      final queryEmbedding = await _generateQueryEmbedding(query);
      
      // Find semantically similar content
      final semanticResults = await _findSemanticallySimilarContent(
        queryEmbedding: queryEmbedding,
        filters: filters,
        limit: limit,
      );

      return semanticResults;
    } catch (e) {
      debugPrint('Error performing semantic search: $e');
      return [];
    }
  }

  /// Detect and get trending topics
  Future<List<TrendingTopic>> getTrendingTopics({
    Duration? timeWindow,
    String? region,
    int limit = 10,
  }) async {
    try {
      final window = timeWindow ?? const Duration(hours: 24);
      final cutoffTime = DateTime.now().subtract(window);
      
      // Analyze hashtag frequency
      final hashtagTrends = await _analyzeHashtagTrends(cutoffTime, region);
      
      // Analyze keyword frequency
      final keywordTrends = await _analyzeKeywordTrends(cutoffTime, region);
      
      // Combine and rank trending topics
      final allTrends = [...hashtagTrends, ...keywordTrends];
      allTrends.sort((a, b) => b.score.compareTo(a.score));
      
      return allTrends.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting trending topics: $e');
      return [];
    }
  }

  /// Create personalized content feed
  Future<List<PostModel>> getPersonalizedFeed({
    required String userId,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      debugPrint('Creating personalized feed for user: $userId');
      
      // Get user preferences and behavior
      final userProfile = await _getUserProfile(userId);
      
      // Get content recommendations
      final recommendations = await _getPersonalizedRecommendations(userId, limit * 2);
      
      // Convert recommendations to posts
      final posts = await _convertRecommendationsToPosts(recommendations);
      
      // Apply personalization scoring
      final personalizedPosts = await _applyPersonalizationScoring(posts, userProfile);
      
      // Sort by personalization score and return
      personalizedPosts.sort((a, b) => b.personalizationScore.compareTo(a.personalizationScore));
      
      return personalizedPosts.take(limit).toList();
    } catch (e) {
      debugPrint('Error creating personalized feed: $e');
      return [];
    }
  }

  /// Find similar content based on content analysis
  Future<List<SearchResult>> findSimilarContent({
    required String postId,
    int limit = 10,
  }) async {
    try {
      debugPrint('Finding similar content for post: $postId');
      
      // Get the reference post
      final referencePost = await _getPostById(postId);
      if (referencePost == null) return [];
      
      // Generate content features
      final contentFeatures = await _extractContentFeatures(referencePost);
      
      // Find similar posts based on features
      final similarPosts = await _findContentBySimilarity(
        features: contentFeatures,
        excludePostId: postId,
        limit: limit,
      );
      
      return similarPosts;
    } catch (e) {
      debugPrint('Error finding similar content: $e');
      return [];
    }
  }

  /// Get search suggestions and autocomplete
  Future<List<SearchSuggestion>> getSearchSuggestions({
    required String partialQuery,
    int limit = 10,
  }) async {
    try {
      if (partialQuery.length < 2) return [];
      
      final suggestions = <SearchSuggestion>[];
      
      // Get hashtag suggestions
      final hashtagSuggestions = await _getHashtagSuggestions(partialQuery, limit ~/ 2);
      suggestions.addAll(hashtagSuggestions);
      
      // Get user suggestions
      final userSuggestions = await _getUserSuggestions(partialQuery, limit ~/ 4);
      suggestions.addAll(userSuggestions);
      
      // Get topic suggestions
      final topicSuggestions = await _getTopicSuggestions(partialQuery, limit ~/ 4);
      suggestions.addAll(topicSuggestions);
      
      // Sort by relevance and popularity
      suggestions.sort((a, b) => b.score.compareTo(a.score));
      
      return suggestions.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting search suggestions: $e');
      return [];
    }
  }

  /// Advanced search with multiple filters and facets
  Future<SearchResults> performAdvancedSearch({
    required AdvancedSearchQuery searchQuery,
  }) async {
    try {
      debugPrint('Performing advanced search with filters');
      
      // Build complex query
      Query query = _firestore.collection('posts');
      
      // Apply text search
      if (searchQuery.textQuery.isNotEmpty) {
        query = _applyTextSearch(query, searchQuery.textQuery);
      }
      
      // Apply filters
      query = _applySearchFilters(query, searchQuery.filters);
      
      // Apply sorting
      query = _applySorting(query, searchQuery.sortBy, searchQuery.sortOrder);
      
      // Execute query
      final snapshot = await query.limit(searchQuery.limit).get();
      
      // Convert to search results
      final results = await _convertToSearchResults(snapshot.docs, searchQuery.textQuery);
      
      // Get facets for filtering
      final facets = await _generateSearchFacets(searchQuery);
      
      return SearchResults(
        query: searchQuery.textQuery,
        results: results,
        totalResults: results.length,
        hasMore: results.length == searchQuery.limit,
        searchTime: DateTime.now(),
        facets: facets,
        suggestions: [],
      );
    } catch (e) {
      debugPrint('Error performing advanced search: $e');
      return SearchResults.empty(searchQuery.textQuery);
    }
  }

  // Private helper methods

  List<String> _preprocessQuery(String query) {
    // Clean and tokenize the query
    final cleanQuery = query.toLowerCase().trim();
    final terms = cleanQuery.split(RegExp(r'\s+'));
    
    // Remove stop words
    final stopWords = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'};
    final filteredTerms = terms.where((term) => !stopWords.contains(term) && term.length > 1).toList();
    
    return filteredTerms;
  }

  Future<List<SearchResult>> _executeFullTextSearch({
    required List<String> searchTerms,
    SearchFilters? filters,
    required int limit,
    String? lastDocumentId,
  }) async {
    final results = <SearchResult>[];
    
    try {
      // Search in post content
      for (final term in searchTerms) {
        final contentQuery = _firestore
            .collection('posts')
            .where('searchableContent', arrayContains: term)
            .limit(limit);
        
        final snapshot = await contentQuery.get();
        
        for (final doc in snapshot.docs) {
          final data = doc.data();
          results.add(SearchResult(
            id: doc.id,
            type: SearchResultType.post,
            title: data['content']?.toString().substring(0, min(100, data['content'].toString().length)) ?? '',
            content: data['content'] ?? '',
            authorId: data['authorId'] ?? '',
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            relevanceScore: 0.0, // Will be calculated in ranking
            metadata: data,
          ));
        }
      }
      
      // Search in hashtags
      for (final term in searchTerms) {
        if (term.startsWith('#') || searchTerms.any((t) => '#$t' == term)) {
          final hashtagQuery = _firestore
              .collection('posts')
              .where('hashtags', arrayContains: term.startsWith('#') ? term : '#$term')
              .limit(limit);
          
          final snapshot = await hashtagQuery.get();
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (!results.any((r) => r.id == doc.id)) {
              results.add(SearchResult(
                id: doc.id,
                type: SearchResultType.post,
                title: data['content']?.toString().substring(0, min(100, data['content'].toString().length)) ?? '',
                content: data['content'] ?? '',
                authorId: data['authorId'] ?? '',
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                relevanceScore: 0.0,
                metadata: data,
              ));
            }
          }
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('Error executing full-text search: $e');
      return results;
    }
  }

  Future<List<SearchResult>> _rankSearchResults(List<SearchResult> results, List<String> searchTerms) async {
    for (final result in results) {
      result.relevanceScore = await _calculateRelevanceScore(result, searchTerms);
    }
    
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return results;
  }

  Future<double> _calculateRelevanceScore(SearchResult result, List<String> searchTerms) async {
    double score = 0.0;
    final content = result.content.toLowerCase();
    final title = result.title.toLowerCase();
    
    // Term frequency scoring
    for (final term in searchTerms) {
      final termLower = term.toLowerCase();
      
      // Title matches get higher score
      if (title.contains(termLower)) {
        score += 3.0;
      }
      
      // Content matches
      final contentMatches = RegExp(termLower).allMatches(content).length;
      score += contentMatches * 1.0;
      
      // Exact phrase matches get bonus
      if (content.contains(searchTerms.join(' ').toLowerCase())) {
        score += 5.0;
      }
    }
    
    // Recency boost
    final daysSinceCreation = DateTime.now().difference(result.createdAt).inDays;
    final recencyBoost = max(0, 30 - daysSinceCreation) / 30.0;
    score += recencyBoost * 2.0;
    
    // Engagement boost (would need engagement data)
    // score += engagementScore * 1.5;
    
    return score;
  }

  Future<List<ContentRecommendation>> _getPersonalizedRecommendations(String userId, int limit) async {
    try {
      // Get user's interaction history
      final userInteractions = await _getUserInteractions(userId);
      
      // Get user's preferences
      final userPreferences = await _getUserPreferences(userId);
      
      // Generate recommendations based on collaborative filtering
      final collaborativeRecs = await _generateCollaborativeRecommendations(userId, userInteractions);
      
      // Generate content-based recommendations
      final contentBasedRecs = await _generateContentBasedRecommendations(userPreferences);
      
      // Combine and score recommendations
      final allRecommendations = [...collaborativeRecs, ...contentBasedRecs];
      
      // Remove duplicates and sort by score
      final uniqueRecs = _removeDuplicateRecommendations(allRecommendations);
      uniqueRecs.sort((a, b) => b.score.compareTo(a.score));
      
      return uniqueRecs.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting personalized recommendations: $e');
      return [];
    }
  }

  Future<List<ContentRecommendation>> _getTrendingRecommendations(int limit) async {
    try {
      // Get trending posts from the last 24 hours
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      
      final snapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('createdAt', descending: true)
          .limit(limit * 2)
          .get();
      
      final recommendations = <ContentRecommendation>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final engagementScore = await _calculateEngagementScore(doc.id);
        
        recommendations.add(ContentRecommendation(
          postId: doc.id,
          title: data['content']?.toString().substring(0, min(100, data['content'].toString().length)) ?? '',
          reason: 'Trending now',
          score: engagementScore,
          type: RecommendationType.trending,
          metadata: data,
        ));
      }
      
      recommendations.sort((a, b) => b.score.compareTo(a.score));
      return recommendations.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting trending recommendations: $e');
      return [];
    }
  }

  Future<List<ContentRecommendation>> _getSimilarContentRecommendations(String userId, int limit) async {
    try {
      // Get user's recently viewed content
      final recentlyViewed = await _getUserRecentlyViewed(userId, 5);
      
      final recommendations = <ContentRecommendation>[];
      
      for (final postId in recentlyViewed) {
        final similarContent = await findSimilarContent(postId: postId, limit: limit ~/ recentlyViewed.length + 1);
        
        for (final similar in similarContent) {
          recommendations.add(ContentRecommendation(
            postId: similar.id,
            title: similar.title,
            reason: 'Similar to content you viewed',
            score: similar.relevanceScore,
            type: RecommendationType.similar,
            metadata: similar.metadata,
          ));
        }
      }
      
      // Remove duplicates and sort
      final uniqueRecs = _removeDuplicateRecommendations(recommendations);
      uniqueRecs.sort((a, b) => b.score.compareTo(a.score));
      
      return uniqueRecs.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting similar content recommendations: $e');
      return [];
    }
  }

  Future<List<ContentRecommendation>> _getCollaborativeRecommendations(String userId, int limit) async {
    try {
      // Find users with similar interests
      final similarUsers = await _findSimilarUsers(userId, 20);
      
      // Get content liked by similar users
      final recommendations = <ContentRecommendation>[];
      
      for (final similarUserId in similarUsers) {
        final likedContent = await _getUserLikedContent(similarUserId, 10);
        
        for (final postId in likedContent) {
          final postData = await _getPostById(postId);
          if (postData != null) {
            recommendations.add(ContentRecommendation(
              postId: postId,
              title: postData['content']?.toString().substring(0, min(100, postData['content'].toString().length)) ?? '',
              reason: 'Liked by users with similar interests',
              score: 0.8, // Base collaborative score
              type: RecommendationType.collaborative,
              metadata: postData,
            ));
          }
        }
      }
      
      // Remove duplicates and sort
      final uniqueRecs = _removeDuplicateRecommendations(recommendations);
      uniqueRecs.sort((a, b) => b.score.compareTo(a.score));
      
      return uniqueRecs.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting collaborative recommendations: $e');
      return [];
    }
  }

  Future<List<String>> _generateQueryEmbedding(String query) async {
    // Simplified embedding generation - in production, use ML models
    return _preprocessQuery(query);
  }

  Future<List<SearchResult>> _findSemanticallySimilarContent({
    required List<String> queryEmbedding,
    SearchFilters? filters,
    required int limit,
  }) async {
    // Simplified semantic search - in production, use vector similarity
    return await _executeFullTextSearch(
      searchTerms: queryEmbedding,
      filters: filters,
      limit: limit,
      lastDocumentId: null,
    );
  }

  Future<List<TrendingTopic>> _analyzeHashtagTrends(DateTime cutoffTime, String? region) async {
    try {
      final trends = <TrendingTopic>[];
      
      // Get recent posts with hashtags
      final snapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .get();
      
      final hashtagCounts = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final hashtags = List<String>.from(data['hashtags'] ?? []);
        
        for (final hashtag in hashtags) {
          hashtagCounts[hashtag] = (hashtagCounts[hashtag] ?? 0) + 1;
        }
      }
      
      // Convert to trending topics
      for (final entry in hashtagCounts.entries) {
        if (entry.value >= 3) { // Minimum threshold
          trends.add(TrendingTopic(
            topic: entry.key,
            mentions: entry.value,
            score: entry.value.toDouble(),
            growth: 0.0, // Would need historical data
            category: 'hashtag',
          ));
        }
      }
      
      return trends;
    } catch (e) {
      debugPrint('Error analyzing hashtag trends: $e');
      return [];
    }
  }

  Future<List<TrendingTopic>> _analyzeKeywordTrends(DateTime cutoffTime, String? region) async {
    try {
      // Simplified keyword trend analysis
      final trends = <TrendingTopic>[];
      
      // Common keywords to track
      final keywords = ['land rights', 'patta', 'agriculture', 'farmer', 'government', 'village'];
      
      for (final keyword in keywords) {
        final count = await _countKeywordMentions(keyword, cutoffTime);
        if (count > 0) {
          trends.add(TrendingTopic(
            topic: keyword,
            mentions: count,
            score: count.toDouble(),
            growth: 0.0,
            category: 'keyword',
          ));
        }
      }
      
      return trends;
    } catch (e) {
      debugPrint('Error analyzing keyword trends: $e');
      return [];
    }
  }

  Future<int> _countKeywordMentions(String keyword, DateTime cutoffTime) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('searchableContent', arrayContains: keyword.toLowerCase())
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Additional helper methods for search functionality
  Future<void> _trackSearchAnalytics(String query, SearchFilters? filters, int resultCount) async {
    try {
      await _firestore.collection('search_analytics').add({
        'query': query,
        'filters': filters?.toMap(),
        'resultCount': resultCount,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error tracking search analytics: $e');
    }
  }

  Future<List<SearchSuggestion>> _generateSearchSuggestions(String query) async {
    // Generate suggestions based on popular searches and user history
    return [];
  }

  Future<UserProfile> _getUserProfile(String userId) async {
    // Get user profile with preferences and behavior data
    return UserProfile.empty();
  }

  Future<List<PostModel>> _convertRecommendationsToPosts(List<ContentRecommendation> recommendations) async {
    // Convert recommendations to actual post objects
    return [];
  }

  Future<List<PostModel>> _applyPersonalizationScoring(List<PostModel> posts, UserProfile userProfile) async {
    // Apply personalization scoring to posts
    return posts;
  }

  Future<Map<String, dynamic>?> _getPostById(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }

  Future<ContentFeatures> _extractContentFeatures(Map<String, dynamic> post) async {
    // Extract features for content similarity
    return ContentFeatures.empty();
  }

  Future<List<SearchResult>> _findContentBySimilarity({
    required ContentFeatures features,
    required String excludePostId,
    required int limit,
  }) async {
    // Find similar content based on features
    return [];
  }

  // Placeholder implementations for complex ML/AI features
  Future<List<String>> _getUserInteractions(String userId) async => [];
  Future<UserPreferences> _getUserPreferences(String userId) async => UserPreferences.empty();
  Future<List<ContentRecommendation>> _generateCollaborativeRecommendations(String userId, List<String> interactions) async => [];
  Future<List<ContentRecommendation>> _generateContentBasedRecommendations(UserPreferences preferences) async => [];
  Future<double> _calculateEngagementScore(String postId) async => 0.0;
  Future<List<String>> _getUserRecentlyViewed(String userId, int limit) async => [];
  Future<List<String>> _findSimilarUsers(String userId, int limit) async => [];
  Future<List<String>> _getUserLikedContent(String userId, int limit) async => [];
  Future<List<SearchSuggestion>> _getHashtagSuggestions(String partial, int limit) async => [];
  Future<List<SearchSuggestion>> _getUserSuggestions(String partial, int limit) async => [];
  Future<List<SearchSuggestion>> _getTopicSuggestions(String partial, int limit) async => [];
  
  Query _applyTextSearch(Query query, String textQuery) => query;
  Query _applySearchFilters(Query query, SearchFilters filters) => query;
  Query _applySorting(Query query, String sortBy, String sortOrder) => query;
  
  Future<List<SearchResult>> _convertToSearchResults(List<QueryDocumentSnapshot> docs, String query) async => [];
  Future<Map<String, List<FacetValue>>> _generateSearchFacets(AdvancedSearchQuery query) async => {};
  
  List<ContentRecommendation> _removeDuplicateRecommendations(List<ContentRecommendation> recommendations) {
    final seen = <String>{};
    return recommendations.where((rec) => seen.add(rec.postId)).toList();
  }
}

// Enums and data models for search and discovery

enum SearchResultType { post, user, hashtag, topic }
enum RecommendationType { personalized, trending, similar, collaborative }

class SearchFilters {
  final String? category;
  final String? author;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? location;
  final List<String>? hashtags;

  SearchFilters({
    this.category,
    this.author,
    this.startDate,
    this.endDate,
    this.location,
    this.hashtags,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'author': author,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'location': location,
      'hashtags': hashtags,
    };
  }
}

class SearchResult {
  final String id;
  final SearchResultType type;
  final String title;
  final String content;
  final String authorId;
  final DateTime createdAt;
  double relevanceScore;
  final Map<String, dynamic> metadata;

  SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.authorId,
    required this.createdAt,
    required this.relevanceScore,
    required this.metadata,
  });
}

class SearchResults {
  final String query;
  final List<SearchResult> results;
  final int totalResults;
  final bool hasMore;
  final DateTime searchTime;
  final List<SearchSuggestion> suggestions;
  final Map<String, List<FacetValue>>? facets;

  SearchResults({
    required this.query,
    required this.results,
    required this.totalResults,
    required this.hasMore,
    required this.searchTime,
    required this.suggestions,
    this.facets,
  });

  static SearchResults empty(String query) {
    return SearchResults(
      query: query,
      results: [],
      totalResults: 0,
      hasMore: false,
      searchTime: DateTime.now(),
      suggestions: [],
    );
  }
}

class ContentRecommendation {
  final String postId;
  final String title;
  final String reason;
  final double score;
  final RecommendationType type;
  final Map<String, dynamic> metadata;

  ContentRecommendation({
    required this.postId,
    required this.title,
    required this.reason,
    required this.score,
    required this.type,
    required this.metadata,
  });
}

class TrendingTopic {
  final String topic;
  final int mentions;
  final double score;
  final double growth;
  final String category;

  TrendingTopic({
    required this.topic,
    required this.mentions,
    required this.score,
    required this.growth,
    required this.category,
  });
}

class SearchSuggestion {
  final String text;
  final SearchResultType type;
  final double score;
  final int frequency;

  SearchSuggestion({
    required this.text,
    required this.type,
    required this.score,
    required this.frequency,
  });
}

class AdvancedSearchQuery {
  final String textQuery;
  final SearchFilters filters;
  final String sortBy;
  final String sortOrder;
  final int limit;

  AdvancedSearchQuery({
    required this.textQuery,
    required this.filters,
    this.sortBy = 'relevance',
    this.sortOrder = 'desc',
    this.limit = 20,
  });
}

class FacetValue {
  final String value;
  final int count;

  FacetValue({
    required this.value,
    required this.count,
  });
}

// Placeholder data models
class UserProfile {
  static UserProfile empty() => UserProfile();
}

class UserPreferences {
  static UserPreferences empty() => UserPreferences();
}

class ContentFeatures {
  static ContentFeatures empty() => ContentFeatures();
}

// Extension for PostModel to add personalization score
extension PostModelPersonalization on PostModel {
  double get personalizationScore => 0.0; // Would be calculated based on user preferences
}
