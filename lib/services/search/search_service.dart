// Search Service - Comprehensive search functionality for TALOWA
// Simplified implementation with Firebase and future Algolia integration

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/search/search_result_model.dart';
import '../../models/search/search_filter_model.dart';

class SearchService {
  static SearchService? _instance;
  static SearchService get instance => _instance ??= SearchService._internal();
  
  SearchService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;
  
  /// Initialize search service
  Future<void> initialize() async {
    try {
      debugPrint('ðŸ” Initializing Search Service...');
      _isInitialized = true;
      debugPrint('âœ… Search Service initialized successfully');
    } catch (e) {
      debugPrint('âŒ Failed to initialize Search Service: $e');
      rethrow;
    }
  }
  
  /// Perform universal search across all content types
  Future<UniversalSearchResultModel> universalSearch(
    String query, {
    SearchFilterModel? filters,
    int? hitsPerPage,
  }) async {
    _ensureInitialized();
    
    try {
      debugPrint('ðŸ” Performing universal search: "$query"');
      
      final results = <String, SearchResultModel>{};
      
      // Search posts
      final postsResult = await searchPosts(query, filters: filters, hitsPerPage: hitsPerPage ?? 5);
      results['posts'] = postsResult;
      
      // Search users
      final usersResult = await searchUsers(query, filters: filters, hitsPerPage: hitsPerPage ?? 5);
      results['users'] = usersResult;
      
      // Search news
      final newsResult = await searchNews(query, filters: filters, hitsPerPage: hitsPerPage ?? 5);
      results['news'] = newsResult;
      
      debugPrint('âœ… Universal search completed');
      return UniversalSearchResultModel.fromResults(query, results);
      
    } catch (e) {
      debugPrint('âŒ Universal search failed: $e');
      rethrow;
    }
  }
  
  /// Search posts
  Future<SearchResultModel> searchPosts(
    String query, {
    SearchFilterModel? filters,
    int? hitsPerPage,
    int? page,
  }) async {
    _ensureInitialized();
    
    try {
      debugPrint('ðŸ“ Searching posts for: "$query"');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('posts');
      
      // Apply text search (simplified - in production use Algolia)
      if (query.isNotEmpty) {
        // Firebase doesn't support full-text search, so we'll search in title and content
        // This is a simplified approach - Algolia would handle this much better
        queryRef = queryRef.where('title', isGreaterThanOrEqualTo: query)
                          .where('title', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply filters
      if (filters != null) {
        queryRef = _applyFiltersToQuery(queryRef, filters);
      }
      
      // Apply pagination
      queryRef = queryRef.limit(hitsPerPage ?? 20);
      if (page != null && page > 0) {
        queryRef = queryRef.startAfter([page * (hitsPerPage ?? 20)]);
      }
      
      final snapshot = await queryRef.get();
      
      final hits = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'posts',
        query: query,
        hits: hits,
        totalHits: hits.length, // Firebase doesn't provide total count easily
        page: page ?? 0,
        hitsPerPage: hitsPerPage ?? 20,
        totalPages: 1, // Simplified
        facets: {},
        processingTimeMS: 0,
        exhaustiveNbHits: true,
      );
      
      debugPrint('âœ… Posts search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Posts search failed: $e');
      rethrow;
    }
  }
  
  /// Search users
  Future<SearchResultModel> searchUsers(
    String query, {
    SearchFilterModel? filters,
    int? hitsPerPage,
    int? page,
  }) async {
    _ensureInitialized();
    
    try {
      debugPrint('ðŸ‘¤ Searching users for: "$query"');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('users');
      
      // Apply text search
      if (query.isNotEmpty) {
        queryRef = queryRef.where('name', isGreaterThanOrEqualTo: query)
                          .where('name', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply filters
      if (filters != null) {
        queryRef = _applyFiltersToQuery(queryRef, filters);
      }
      
      queryRef = queryRef.limit(hitsPerPage ?? 20);
      
      final snapshot = await queryRef.get();
      
      final hits = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'users',
        query: query,
        hits: hits,
        totalHits: hits.length,
        page: page ?? 0,
        hitsPerPage: hitsPerPage ?? 20,
        totalPages: 1,
        facets: {},
        processingTimeMS: 0,
        exhaustiveNbHits: true,
      );
      
      debugPrint('âœ… Users search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Users search failed: $e');
      rethrow;
    }
  }
  
  /// Search news
  Future<SearchResultModel> searchNews(
    String query, {
    SearchFilterModel? filters,
    int? hitsPerPage,
    int? page,
  }) async {
    _ensureInitialized();
    
    try {
      debugPrint('ðŸ“° Searching news for: "$query"');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('news');
      
      // Apply text search
      if (query.isNotEmpty) {
        queryRef = queryRef.where('title', isGreaterThanOrEqualTo: query)
                          .where('title', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply filters
      if (filters != null) {
        queryRef = _applyFiltersToQuery(queryRef, filters);
      }
      
      queryRef = queryRef.limit(hitsPerPage ?? 20);
      
      final snapshot = await queryRef.get();
      
      final hits = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'news',
        query: query,
        hits: hits,
        totalHits: hits.length,
        page: page ?? 0,
        hitsPerPage: hitsPerPage ?? 20,
        totalPages: 1,
        facets: {},
        processingTimeMS: 0,
        exhaustiveNbHits: true,
      );
      
      debugPrint('âœ… News search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ News search failed: $e');
      rethrow;
    }
  }
  
  /// Get search suggestions
  Future<List<String>> getSuggestions(String query, {int maxSuggestions = 10}) async {
    _ensureInitialized();
    
    try {
      if (query.length < 2) return [];
      
      debugPrint('ðŸ’¡ Getting suggestions for: "$query"');
      
      // Get suggestions from posts titles
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(maxSuggestions)
          .get();
      
      final suggestions = postsSnapshot.docs
          .map((doc) => doc.data()['title'] as String?)
          .where((title) => title != null && title.isNotEmpty)
          .cast<String>()
          .toList();
      
      debugPrint('ðŸ’¡ Found ${suggestions.length} suggestions');
      return suggestions;
      
    } catch (e) {
      debugPrint('âŒ Failed to get suggestions: $e');
      return [];
    }
  }
  
  /// Apply filters to Firestore query
  Query<Map<String, dynamic>> _applyFiltersToQuery(
    Query<Map<String, dynamic>> query,
    SearchFilterModel filters,
  ) {
    // Apply category filters
    if (filters.categories != null && filters.categories!.isNotEmpty) {
      query = query.where('category', whereIn: filters.categories);
    }
    
    // Apply type filters
    if (filters.types != null && filters.types!.isNotEmpty) {
      query = query.where('type', whereIn: filters.types);
    }
    
    // Apply status filters
    if (filters.statuses != null && filters.statuses!.isNotEmpty) {
      query = query.where('status', whereIn: filters.statuses);
    }
    
    // Apply location filters
    if (filters.location?.states != null && filters.location!.states!.isNotEmpty) {
      query = query.where('location.state', whereIn: filters.location!.states);
    }
    
    // Apply date range filters
    if (filters.dateRange != null) {
      if (filters.dateRange!.startDate != null) {
        query = query.where(filters.dateRange!.fieldName, 
                           isGreaterThanOrEqualTo: Timestamp.fromDate(filters.dateRange!.startDate!));
      }
      if (filters.dateRange!.endDate != null) {
        query = query.where(filters.dateRange!.fieldName, 
                           isLessThanOrEqualTo: Timestamp.fromDate(filters.dateRange!.endDate!));
      }
    }
    
    return query;
  }
  
  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('SearchService not initialized. Call initialize() first.');
    }
  }
  
  /// Get search statistics
  Map<String, dynamic> getSearchStats() {
    return {
      'isInitialized': _isInitialized,
      'searchProvider': 'Firebase (with future Algolia integration)',
    };
  }
  
  /// Dispose resources
  void dispose() {
    _isInitialized = false;
    debugPrint('ðŸ—‘ï¸ Search Service disposed');
  }
}

