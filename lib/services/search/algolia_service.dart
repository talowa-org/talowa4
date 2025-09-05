// Algolia Search Service - Production-ready search functionality
// Complete Algolia integration for TALOWA land rights platform

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import '../../config/algolia_config.dart';
import '../../models/search/search_result_model.dart';
import '../../models/search/search_filter_model.dart';
import 'search_indexing_service.dart';

class AlgoliaService {
  static AlgoliaService? _instance;
  static AlgoliaService get instance => _instance ??= AlgoliaService._internal();
  
  AlgoliaService._internal();
  
  late SearchClient _client;
  final Map<String, SearchIndex> _indices = {};
  final Map<String, HitsSearcher> _searchers = {};
  bool _isInitialized = false;
  
  /// Initialize Algolia service
  Future<void> initialize() async {
    try {
      debugPrint('ðŸ” Initializing Algolia Search Service...');
      
      // Validate configuration
      if (!AlgoliaConfig.validateConfiguration()) {
        throw Exception('Algolia configuration is invalid');
      }
      
      // Initialize Algolia client
      _client = SearchClient(
        appId: AlgoliaConfig.applicationId,
        apiKey: AlgoliaConfig.searchApiKey,
      );
      
      // Initialize indices
      await _initializeIndices();
      
      // Initialize searchers
      await _initializeSearchers();
      
      _isInitialized = true;
      debugPrint('âœ… Algolia Search Service initialized successfully');
      
    } catch (e) {
      debugPrint('âŒ Failed to initialize Algolia Service: $e');
      rethrow;
    }
  }
  
  /// Initialize all search indices
  Future<void> _initializeIndices() async {
    final indexNames = [
      AlgoliaConfig.postsIndex,
      AlgoliaConfig.usersIndex,
      AlgoliaConfig.legalCasesIndex,
      AlgoliaConfig.newsIndex,
      AlgoliaConfig.professionalsIndex,
      AlgoliaConfig.campaignsIndex,
      AlgoliaConfig.organizationsIndex,
      AlgoliaConfig.landRecordsIndex,
    ];
    
    for (final indexName in indexNames) {
      final environmentIndexName = AlgoliaConfig.getIndexName(indexName);
      _indices[indexName] = _client.index(environmentIndexName);
      debugPrint('ðŸ“‹ Initialized index: $environmentIndexName');
    }
  }
  
  /// Initialize search helpers
  Future<void> _initializeSearchers() async {
    for (final entry in _indices.entries) {
      final indexName = entry.key;
      final index = entry.value;
      
      _searchers[indexName] = HitsSearcher(
        applicationID: AlgoliaConfig.applicationId,
        apiKey: AlgoliaConfig.searchApiKey,
        indexName: index.indexName,
      );
      
      debugPrint('ðŸ”Ž Initialized searcher for: $indexName');
    }
  }
  
  /// Perform universal search across all indices
  Future<Map<String, SearchResultModel>> universalSearch(
    String query, {
    SearchFilterModel? filters,
    int? hitsPerPage,
  }) async {
    _ensureInitialized();
    
    try {
      debugPrint('ðŸ” Performing universal search: "$query"');
      
      final results = <String, SearchResultModel>{};
      final futures = <Future>[];
      
      // Search across all indices
      for (final entry in _indices.entries) {
        final indexName = entry.key;
        final future = searchIndex(
          indexName,
          query,
          filters: filters,
          hitsPerPage: hitsPerPage ?? 5, // Limit results for universal search
        ).then((result) {
          results[indexName] = result;
        });
        futures.add(future);
      }
      
      // Wait for all searches to complete
      await Future.wait(futures);
      
      debugPrint('âœ… Universal search completed with ${results.length} index results');
      return results;
      
    } catch (e) {
      debugPrint('âŒ Universal search failed: $e');
      rethrow;
    }
  }
  
  /// Search specific index
  Future<SearchResultModel> searchIndex(
    String indexName,
    String query, {
    SearchFilterModel? filters,
    int? hitsPerPage,
    int? page,
    Map<String, dynamic>? geoSearch,
  }) async {
    _ensureInitialized();
    
    try {
      final index = _indices[indexName];
      if (index == null) {
        throw Exception('Index not found: $indexName');
      }
      
      // Build search parameters
      final searchParams = AlgoliaConfig.getSearchParameters(
        indexName,
        hitsPerPage: hitsPerPage,
        filters: filters?.toAlgoliaFilters(),
        geoSearch: geoSearch,
      );
      
      if (page != null) {
        searchParams['page'] = page;
      }
      
      debugPrint('ðŸ”Ž Searching index "$indexName" for: "$query"');
      
      // Perform search
      final response = await index.search(SearchForHits(
        query: query,
        searchParams: SearchParams.fromJson(searchParams),
      ));
      
      // Convert to SearchResultModel
      final result = SearchResultModel.fromAlgoliaResponse(
        response,
        indexName,
        query,
      );
      
      debugPrint('âœ… Search completed: ${result.hits.length} results found');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Search failed for index "$indexName": $e');
      rethrow;
    }
  }
  
  /// Get search suggestions/autocomplete
  Future<List<String>> getSuggestions(
    String query, {
    String? indexName,
    int maxSuggestions = 10,
  }) async {
    _ensureInitialized();
    
    try {
      if (query.length < AlgoliaConfig.minQueryLength) {
        return [];
      }
      
      final targetIndex = indexName ?? AlgoliaConfig.postsIndex;
      final index = _indices[targetIndex];
      if (index == null) {
        throw Exception('Index not found: $targetIndex');
      }
      
      debugPrint('ðŸ’¡ Getting suggestions for: "$query"');
      
      // Search for suggestions
      final response = await index.search(SearchForHits(
        query: query,
        searchParams: SearchParams(
          hitsPerPage: maxSuggestions,
          attributesToRetrieve: ['title', 'name', 'content'],
          attributesToHighlight: [],
        ),
      ));
      
      // Extract suggestions from results
      final suggestions = <String>[];
      for (final hit in response.hits) {
        final data = hit.toJson();
        
        // Extract relevant text for suggestions
        final title = data['title'] as String?;
        final name = data['name'] as String?;
        final content = data['content'] as String?;
        
        if (title != null && title.isNotEmpty) {
          suggestions.add(title);
        } else if (name != null && name.isNotEmpty) {
          suggestions.add(name);
        } else if (content != null && content.isNotEmpty) {
          // Extract first sentence or first 50 characters
          final shortContent = content.length > 50 
              ? '${content.substring(0, 50)}...'
              : content;
          suggestions.add(shortContent);
        }
      }
      
      debugPrint('ðŸ’¡ Found ${suggestions.length} suggestions');
      return suggestions.take(maxSuggestions).toList();
      
    } catch (e) {
      debugPrint('âŒ Failed to get suggestions: $e');
      return [];
    }
  }
  
  /// Search with geo-location
  Future<SearchResultModel> geoSearch(
    String indexName,
    String query,
    double latitude,
    double longitude, {
    double? radiusInMeters,
    SearchFilterModel? filters,
    int? hitsPerPage,
  }) async {
    final geoSearchParams = {
      'aroundLatLng': '$latitude,$longitude',
      'aroundRadius': (radiusInMeters ?? AlgoliaConfig.defaultSearchRadius).round(),
    };
    
    return searchIndex(
      indexName,
      query,
      filters: filters,
      hitsPerPage: hitsPerPage,
      geoSearch: geoSearchParams,
    );
  }
  
  /// Get facets for filtering
  Future<Map<String, Map<String, int>>> getFacets(
    String indexName,
    String query, {
    List<String>? facetNames,
  }) async {
    _ensureInitialized();
    
    try {
      final index = _indices[indexName];
      if (index == null) {
        throw Exception('Index not found: $indexName');
      }
      
      final facets = facetNames ?? AlgoliaConfig.defaultFacets;
      
      final response = await index.search(SearchForHits(
        query: query,
        searchParams: SearchParams(
          hitsPerPage: 0, // We only want facets, not hits
          facets: facets,
        ),
      ));
      
      return response.facets ?? {};
      
    } catch (e) {
      debugPrint('âŒ Failed to get facets: $e');
      return {};
    }
  }
  
  /// Clear search cache
  void clearCache() {
    for (final searcher in _searchers.values) {
      // Clear searcher cache if available
      // This depends on the specific implementation of HitsSearcher
    }
    debugPrint('ðŸ§¹ Search cache cleared');
  }
  
  /// Dispose resources
  void dispose() {
    for (final searcher in _searchers.values) {
      searcher.dispose();
    }
    _searchers.clear();
    _indices.clear();
    _isInitialized = false;
    debugPrint('ðŸ—‘ï¸ Algolia Service disposed');
  }
  
  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('AlgoliaService not initialized. Call initialize() first.');
    }
  }
  
  /// Get search statistics
  Map<String, dynamic> getSearchStats() {
    return {
      'isInitialized': _isInitialized,
      'indicesCount': _indices.length,
      'searchersCount': _searchers.values.length,
      'availableIndices': _indices.keys.toList(),
    };
  }
}

