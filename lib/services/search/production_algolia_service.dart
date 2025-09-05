// Production Algolia Service - Lightning-fast search with advanced features
// Complete production-ready Algolia integration for TALOWA platform

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import '../../config/algolia_config.dart';
import '../../models/search/search_result_model.dart';
import '../../models/search/search_filter_model.dart';

class ProductionAlgoliaService {
  static ProductionAlgoliaService? _instance;
  static ProductionAlgoliaService get instance => _instance ??= ProductionAlgoliaService._internal();
  
  ProductionAlgoliaService._internal();
  
  // Algolia searchers for different indices
  late Map<String, HitsSearcher> _searchers;
  late Map<String, FacetList> _facetLists;
  late Map<String, FilterState> _filterStates;
  
  bool _isInitialized = false;
  
  /// Initialize Algolia service with production configuration
  Future<void> initialize() async {
    try {
      debugPrint('ðŸ” Initializing Production Algolia Service...');
      
      if (!AlgoliaConfig.validateConfiguration()) {
        throw Exception('Algolia configuration is invalid');
      }
      
      _searchers = {};
      _facetLists = {};
      _filterStates = {};
      
      // Initialize searchers for each index
      await _initializeSearchers();
      
      // Setup facet lists for filtering
      await _initializeFacetLists();
      
      // Configure filter states
      await _initializeFilterStates();
      
      _isInitialized = true;
      debugPrint('âœ… Production Algolia Service initialized successfully');
      
    } catch (e) {
      debugPrint('âŒ Failed to initialize Production Algolia Service: $e');
      rethrow;
    }
  }
  
  /// Initialize searchers for all indices
  Future<void> _initializeSearchers() async {
    final indices = [
      AlgoliaConfig.postsIndex,
      AlgoliaConfig.usersIndex,
      AlgoliaConfig.legalCasesIndex,
      AlgoliaConfig.newsIndex,
      AlgoliaConfig.professionalsIndex,
      AlgoliaConfig.campaignsIndex,
      AlgoliaConfig.organizationsIndex,
      AlgoliaConfig.landRecordsIndex,
    ];
    
    for (final indexName in indices) {
      final environmentIndexName = AlgoliaConfig.getIndexName(indexName);
      
      _searchers[indexName] = HitsSearcher(
        applicationID: AlgoliaConfig.applicationId,
        apiKey: AlgoliaConfig.searchApiKey,
        indexName: environmentIndexName,
      );
      
      // Configure search parameters
      _searchers[indexName]!.applyState((state) => state.copyWith(
        query: '',
        hitsPerPage: AlgoliaConfig.defaultHitsPerPage,
        facets: AlgoliaConfig.defaultFacets,
        maxValuesPerFacet: 100,
        typoTolerance: TypoTolerance.strict,
        ignorePlurals: true,
        removeStopWords: true,
        queryLanguages: ['en', 'hi'],
        indexLanguages: ['en', 'hi'],
        enablePersonalization: AlgoliaConfig.enablePersonalization,
        clickAnalytics: AlgoliaConfig.enableClickAnalytics,
        analytics: AlgoliaConfig.enableAnalytics,
      ));
      
      debugPrint('ðŸ”Ž Initialized searcher for: $indexName');
    }
  }
  
  /// Initialize facet lists for advanced filtering
  Future<void> _initializeFacetLists() async {
    for (final entry in _searchers.entries) {
      final indexName = entry.key;
      final searcher = entry.value;
      
      _facetLists[indexName] = searcher.buildFacetList(
        facet: Attribute('category'),
        persistent: true,
      );
      
      debugPrint('ðŸ“Š Initialized facet list for: $indexName');
    }
  }
  
  /// Initialize filter states for complex filtering
  Future<void> _initializeFilterStates() async {
    for (final indexName in _searchers.keys) {
      _filterStates[indexName] = FilterState();
      debugPrint('ðŸ”§ Initialized filter state for: $indexName');
    }
  }
  
  /// Perform lightning-fast universal search
  Future<UniversalSearchResultModel> universalSearch(
    String query, {
    SearchFilterModel? filters,
    int? hitsPerPage,
    bool enablePersonalization = true,
    bool enableAnalytics = true,
  }) async {
    _ensureInitialized();
    
    try {
      final startTime = DateTime.now();
      debugPrint('ðŸ” Performing universal search: "$query"');
      
      final results = <String, SearchResultModel>{};
      final futures = <Future>[];
      
      // Search across all indices simultaneously
      for (final entry in _searchers.entries) {
        final indexName = entry.key;
        final searcher = entry.value;
        
        final future = _performIndexSearch(
          searcher,
          indexName,
          query,
          filters: filters,
          hitsPerPage: hitsPerPage ?? 5,
          enablePersonalization: enablePersonalization,
          enableAnalytics: enableAnalytics,
        ).then((result) {
          results[indexName] = result;
        });
        
        futures.add(future);
      }
      
      // Wait for all searches to complete
      await Future.wait(futures);
      
      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime).inMilliseconds;
      
      final universalResult = UniversalSearchResultModel.fromResults(query, results);
      
      debugPrint('âœ… Universal search completed in ${processingTime}ms with ${universalResult.totalHits} results');
      
      // Track search analytics
      if (enableAnalytics) {
        _trackSearchAnalytics(query, universalResult, processingTime);
      }
      
      return universalResult;
      
    } catch (e) {
      debugPrint('âŒ Universal search failed: $e');
      rethrow;
    }
  }
  
  /// Perform search on specific index with advanced features
  Future<SearchResultModel> _performIndexSearch(
    HitsSearcher searcher,
    String indexName,
    String query, {
    SearchFilterModel? filters,
    int hitsPerPage = 20,
    int page = 0,
    bool enablePersonalization = true,
    bool enableAnalytics = true,
  }) async {
    try {
      // Apply search query and parameters
      searcher.applyState((state) => state.copyWith(
        query: query,
        hitsPerPage: hitsPerPage,
        page: page,
        enablePersonalization: enablePersonalization,
        clickAnalytics: enableAnalytics,
        analytics: enableAnalytics,
      ));
      
      // Apply filters if provided
      if (filters != null) {
        _applyFiltersToSearcher(searcher, indexName, filters);
      }
      
      // Execute search
      final response = await searcher.responses.first;
      
      // Convert to SearchResultModel
      final hits = response.hits.map((hit) {
        final data = Map<String, dynamic>.from(hit.toJson());
        data['objectID'] = hit.objectID;
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      return SearchResultModel(
        indexName: indexName,
        query: query,
        hits: hits,
        totalHits: response.nbHits,
        page: response.page,
        hitsPerPage: response.hitsPerPage,
        totalPages: response.nbPages,
        facets: response.facets ?? {},
        processingTimeMS: response.processingTimeMS,
        exhaustiveNbHits: response.exhaustiveNbHits,
      );
      
    } catch (e) {
      debugPrint('âŒ Index search failed for "$indexName": $e');
      rethrow;
    }
  }
  
  /// Apply advanced filters to searcher
  void _applyFiltersToSearcher(
    HitsSearcher searcher,
    String indexName,
    SearchFilterModel filters,
  ) {
    final filterState = _filterStates[indexName];
    if (filterState == null) return;
    
    // Clear existing filters
    filterState.clear();
    
    // Apply category filters
    if (filters.categories != null && filters.categories!.isNotEmpty) {
      for (final category in filters.categories!) {
        filterState.add(FilterGroupID.and(Attribute('category')), {category});
      }
    }
    
    // Apply type filters
    if (filters.types != null && filters.types!.isNotEmpty) {
      for (final type in filters.types!) {
        filterState.add(FilterGroupID.and(Attribute('type')), {type});
      }
    }
    
    // Apply location filters
    if (filters.location?.states != null && filters.location!.states!.isNotEmpty) {
      for (final state in filters.location!.states!) {
        filterState.add(FilterGroupID.and(Attribute('location.state')), {state});
      }
    }
    
    // Apply date range filters
    if (filters.dateRange != null) {
      final dateRange = filters.dateRange!;
      if (dateRange.startDate != null && dateRange.endDate != null) {
        final startTimestamp = dateRange.startDate!.millisecondsSinceEpoch;
        final endTimestamp = dateRange.endDate!.millisecondsSinceEpoch;
        
        filterState.add(
          FilterGroupID.and(Attribute(dateRange.fieldName)),
          {NumericRange(startTimestamp, endTimestamp)},
        );
      }
    }
    
    // Connect filter state to searcher
    searcher.connectFilterState(filterState);
  }
  
  /// Get intelligent search suggestions with typo tolerance
  Future<List<String>> getIntelligentSuggestions(
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
      final searcher = _searchers[targetIndex];
      if (searcher == null) return [];
      
      debugPrint('ðŸ’¡ Getting intelligent suggestions for: "$query"');
      
      // Configure for suggestion search
      searcher.applyState((state) => state.copyWith(
        query: query,
        hitsPerPage: maxSuggestions,
        typoTolerance: TypoTolerance.min,
        ignorePlurals: true,
        removeStopWords: true,
        attributesToRetrieve: ['title', 'name', 'content'],
        attributesToHighlight: ['title', 'name'],
      ));
      
      final response = await searcher.responses.first;
      
      // Extract suggestions from results
      final suggestions = <String>[];
      for (final hit in response.hits) {
        final data = hit.toJson();
        
        // Extract relevant text for suggestions
        final title = data['title'] as String?;
        final name = data['name'] as String?;
        
        if (title != null && title.isNotEmpty) {
          suggestions.add(title);
        } else if (name != null && name.isNotEmpty) {
          suggestions.add(name);
        }
      }
      
      debugPrint('ðŸ’¡ Found ${suggestions.length} intelligent suggestions');
      return suggestions.take(maxSuggestions).toList();
      
    } catch (e) {
      debugPrint('âŒ Failed to get intelligent suggestions: $e');
      return [];
    }
  }
  
  /// Get faceted search results for advanced filtering
  Future<Map<String, Map<String, int>>> getFacetedResults(
    String indexName,
    String query,
  ) async {
    _ensureInitialized();
    
    try {
      final facetList = _facetLists[indexName];
      if (facetList == null) return {};
      
      final searcher = _searchers[indexName];
      if (searcher == null) return {};
      
      // Update search query
      searcher.applyState((state) => state.copyWith(query: query));
      
      // Get facet values
      final facets = await facetList.facets.first;
      
      final result = <String, Map<String, int>>{};
      for (final facet in facets) {
        result[facet.value] = {facet.value: facet.count};
      }
      
      return result;
      
    } catch (e) {
      debugPrint('âŒ Failed to get faceted results: $e');
      return {};
    }
  }
  
  /// Track search analytics for optimization
  void _trackSearchAnalytics(
    String query,
    UniversalSearchResultModel results,
    int processingTimeMs,
  ) {
    try {
      // Track search performance
      debugPrint('ðŸ“Š Search Analytics: "$query" - ${results.totalHits} results in ${processingTimeMs}ms');
      
      // Here you would send analytics to your backend or analytics service
      // For now, we'll just log the metrics
      
    } catch (e) {
      debugPrint('âŒ Failed to track search analytics: $e');
    }
  }
  
  /// Clear search cache and reset searchers
  void clearCache() {
    for (final searcher in _searchers.values) {
      searcher.applyState((state) => state.copyWith(query: ''));
    }
    debugPrint('ðŸ§¹ Algolia search cache cleared');
  }
  
  /// Dispose all resources
  void dispose() {
    for (final searcher in _searchers.values) {
      searcher.dispose();
    }
    for (final facetList in _facetLists.values) {
      facetList.dispose();
    }
    
    _searchers.clear();
    _facetLists.clear();
    _filterStates.clear();
    
    _isInitialized = false;
    debugPrint('ðŸ—‘ï¸ Production Algolia Service disposed');
  }
  
  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('ProductionAlgoliaService not initialized. Call initialize() first.');
    }
  }
  
  /// Get service statistics
  Map<String, dynamic> getServiceStats() {
    return {
      'isInitialized': _isInitialized,
      'searchersCount': _searchers.length,
      'facetListsCount': _facetLists.length,
      'filterStatesCount': _filterStates.length,
      'availableIndices': _searchers.keys.toList(),
      'algoliaConfig': {
        'applicationId': AlgoliaConfig.applicationId,
        'enablePersonalization': AlgoliaConfig.enablePersonalization,
        'enableAnalytics': AlgoliaConfig.enableAnalytics,
      },
    };
  }
}

