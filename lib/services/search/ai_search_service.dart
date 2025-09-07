// AI-Powered Search Service - Natural language and semantic search
// Complete AI search capabilities for TALOWA platform

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/search/search_result_model.dart';
import '../../models/search/search_filter_model.dart';
import '../../services/search/search_service.dart';

class AISearchService {
  static AISearchService? _instance;
  static AISearchService get instance => _instance ??= AISearchService._internal();
  
  AISearchService._internal();
  
  // AI service configuration
  static const String _aiServiceUrl = 'https://api.openai.com/v1';
  static const String _apiKey = 'your-openai-api-key'; // Replace with actual key
  
  // Natural language processing patterns
  final Map<String, List<String>> _intentPatterns = {
    'find_lawyer': [
      'find lawyer',
      'need attorney',
      'legal help',
      'advocate for',
      'legal representation',
      'court case help',
    ],
    'land_dispute': [
      'land dispute',
      'property conflict',
      'land grabbing',
      'illegal occupation',
      'boundary dispute',
      'land rights violation',
    ],
    'legal_documents': [
      'legal documents',
      'court papers',
      'legal forms',
      'property papers',
      'land records',
      'revenue documents',
    ],
    'government_schemes': [
      'government scheme',
      'subsidy',
      'compensation',
      'rehabilitation',
      'land acquisition',
      'government benefits',
    ],
    'success_stories': [
      'success story',
      'won case',
      'victory',
      'positive outcome',
      'resolved dispute',
      'justice served',
    ],
  };
  
  /// Process natural language query and convert to structured search
  Future<ProcessedQuery> processNaturalLanguageQuery(String query) async {
    try {
      debugPrint('ðŸ¤– Processing natural language query: "$query"');
      
      final processedQuery = ProcessedQuery(
        originalQuery: query,
        intent: _detectIntent(query),
        entities: _extractEntities(query),
        structuredQuery: _buildStructuredQuery(query),
        confidence: _calculateConfidence(query),
        suggestions: _generateSuggestions(query),
      );
      
      debugPrint('âœ… Processed query with intent: ${processedQuery.intent}');
      return processedQuery;
      
    } catch (e) {
      debugPrint('âŒ Failed to process natural language query: $e');
      rethrow;
    }
  }
  
  /// Perform semantic search with AI understanding
  Future<UniversalSearchResultModel> semanticSearch(
    String query, {
    SearchFilterModel? filters,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('ðŸ§  Performing semantic search: "$query"');
      
      // Process the natural language query
      final processedQuery = await processNaturalLanguageQuery(query);
      
      // Use the structured query for search
      final searchQuery = processedQuery.structuredQuery.isNotEmpty 
          ? processedQuery.structuredQuery 
          : query;
      
      // Apply intent-based filters
      final enhancedFilters = _enhanceFiltersWithIntent(
        filters ?? const SearchFilterModel(),
        processedQuery.intent,
        processedQuery.entities,
      );
      
      // Perform the search with enhanced parameters
      final results = await SearchService.instance.universalSearch(
        searchQuery,
        filters: enhancedFilters,
        hitsPerPage: hitsPerPage,
      );
      
      // Re-rank results based on semantic relevance
      final rerankedResults = _reRankResultsSemanticaly(results, processedQuery);
      
      debugPrint('âœ… Semantic search completed with ${rerankedResults.totalHits} results');
      return rerankedResults;
      
    } catch (e) {
      debugPrint('âŒ Semantic search failed: $e');
      rethrow;
    }
  }
  
  /// Generate smart recommendations based on user context
  Future<List<SmartRecommendation>> generateSmartRecommendations(
    String userId, {
    String? currentQuery,
    List<String>? recentSearches,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      debugPrint('ðŸ’¡ Generating smart recommendations for user: $userId');
      
      final recommendations = <SmartRecommendation>[];
      
      // Generate recommendations based on user profile
      if (userProfile != null) {
        recommendations.addAll(_generateProfileBasedRecommendations(userProfile));
      }
      
      // Generate recommendations based on recent searches
      if (recentSearches != null && recentSearches.isNotEmpty) {
        recommendations.addAll(_generateSearchHistoryRecommendations(recentSearches));
      }
      
      // Generate contextual recommendations
      if (currentQuery != null && currentQuery.isNotEmpty) {
        recommendations.addAll(_generateContextualRecommendations(currentQuery));
      }
      
      // Sort by relevance score
      recommendations.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      
      debugPrint('âœ… Generated ${recommendations.length} smart recommendations');
      return recommendations.take(10).toList();
      
    } catch (e) {
      debugPrint('âŒ Failed to generate smart recommendations: $e');
      return [];
    }
  }
  
  /// Detect user intent from natural language query
  String _detectIntent(String query) {
    final lowerQuery = query.toLowerCase();
    
    for (final entry in _intentPatterns.entries) {
      final intent = entry.key;
      final patterns = entry.value;
      
      for (final pattern in patterns) {
        if (lowerQuery.contains(pattern.toLowerCase())) {
          return intent;
        }
      }
    }
    
    return 'general_search';
  }
  
  /// Extract entities (locations, names, dates) from query
  Map<String, List<String>> _extractEntities(String query) {
    final entities = <String, List<String>>{};
    
    // Extract locations (Indian states and cities)
    final locations = _extractLocations(query);
    if (locations.isNotEmpty) {
      entities['locations'] = locations;
    }
    
    // Extract legal terms
    final legalTerms = _extractLegalTerms(query);
    if (legalTerms.isNotEmpty) {
      entities['legal_terms'] = legalTerms;
    }
    
    // Extract time references
    final timeReferences = _extractTimeReferences(query);
    if (timeReferences.isNotEmpty) {
      entities['time'] = timeReferences;
    }
    
    return entities;
  }
  
  /// Extract location entities from query
  List<String> _extractLocations(String query) {
    final locations = <String>[];
    final lowerQuery = query.toLowerCase();
    
    // Indian states
    final states = [
      'bihar', 'uttar pradesh', 'maharashtra', 'west bengal', 'tamil nadu',
      'karnataka', 'gujarat', 'rajasthan', 'odisha', 'kerala', 'jharkhand',
      'assam', 'punjab', 'chhattisgarh', 'haryana', 'delhi', 'jammu kashmir',
    ];
    
    // Major cities
    final cities = [
      'patna', 'mumbai', 'delhi', 'bangalore', 'hyderabad', 'chennai',
      'kolkata', 'pune', 'ahmedabad', 'surat', 'jaipur', 'lucknow',
    ];
    
    for (final state in states) {
      if (lowerQuery.contains(state)) {
        locations.add(state);
      }
    }
    
    for (final city in cities) {
      if (lowerQuery.contains(city)) {
        locations.add(city);
      }
    }
    
    return locations;
  }
  
  /// Extract legal terms from query
  List<String> _extractLegalTerms(String query) {
    final legalTerms = <String>[];
    final lowerQuery = query.toLowerCase();
    
    final terms = [
      'land acquisition', 'property rights', 'compensation', 'rehabilitation',
      'court case', 'legal notice', 'injunction', 'stay order', 'appeal',
      'high court', 'supreme court', 'district court', 'revenue court',
      'mutation', 'registry', 'title deed', 'survey settlement',
    ];
    
    for (final term in terms) {
      if (lowerQuery.contains(term)) {
        legalTerms.add(term);
      }
    }
    
    return legalTerms;
  }
  
  /// Extract time references from query
  List<String> _extractTimeReferences(String query) {
    final timeRefs = <String>[];
    final lowerQuery = query.toLowerCase();
    
    final patterns = [
      'recent', 'latest', 'new', 'today', 'yesterday', 'this week',
      'this month', 'this year', 'last week', 'last month', 'last year',
      '2024', '2023', '2022', 'ongoing', 'pending',
    ];
    
    for (final pattern in patterns) {
      if (lowerQuery.contains(pattern)) {
        timeRefs.add(pattern);
      }
    }
    
    return timeRefs;
  }
  
  /// Build structured query from natural language
  String _buildStructuredQuery(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Convert natural language to search terms
    final conversions = {
      'find lawyer': 'lawyer advocate legal',
      'need attorney': 'attorney lawyer legal help',
      'land dispute': 'land dispute property conflict',
      'court case': 'court case legal proceeding',
      'government scheme': 'government scheme subsidy benefit',
      'success story': 'success victory won case',
    };
    
    for (final entry in conversions.entries) {
      if (lowerQuery.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return query;
  }
  
  /// Calculate confidence score for query processing
  double _calculateConfidence(String query) {
    double confidence = 0.5; // Base confidence
    
    // Increase confidence for recognized patterns
    final lowerQuery = query.toLowerCase();
    for (final patterns in _intentPatterns.values) {
      for (final pattern in patterns) {
        if (lowerQuery.contains(pattern)) {
          confidence += 0.1;
        }
      }
    }
    
    // Increase confidence for specific entities
    if (_extractLocations(query).isNotEmpty) confidence += 0.1;
    if (_extractLegalTerms(query).isNotEmpty) confidence += 0.1;
    if (_extractTimeReferences(query).isNotEmpty) confidence += 0.05;
    
    return confidence.clamp(0.0, 1.0);
  }
  
  /// Generate query suggestions
  List<String> _generateSuggestions(String query) {
    final suggestions = <String>[];
    final intent = _detectIntent(query);
    
    switch (intent) {
      case 'find_lawyer':
        suggestions.addAll([
          'land rights lawyer near me',
          'property dispute attorney',
          'experienced land lawyer',
          'legal aid for farmers',
        ]);
        break;
      case 'land_dispute':
        suggestions.addAll([
          'land dispute resolution',
          'property boundary conflict',
          'illegal land occupation',
          'land grabbing cases',
        ]);
        break;
      case 'legal_documents':
        suggestions.addAll([
          'property title documents',
          'land registration papers',
          'court case documents',
          'legal notice format',
        ]);
        break;
      default:
        suggestions.addAll([
          'land rights information',
          'legal help for farmers',
          'property dispute resolution',
          'government land schemes',
        ]);
    }
    
    return suggestions;
  }
  
  /// Enhance filters based on detected intent
  SearchFilterModel _enhanceFiltersWithIntent(
    SearchFilterModel baseFilters,
    String intent,
    Map<String, List<String>> entities,
  ) {
    var enhancedFilters = baseFilters;
    
    // Add intent-based type filters
    switch (intent) {
      case 'find_lawyer':
        enhancedFilters = enhancedFilters.copyWith(
          types: ['user', 'professional'],
          categories: ['Legal Services', 'Professional Directory'],
        );
        break;
      case 'land_dispute':
        enhancedFilters = enhancedFilters.copyWith(
          types: ['post', 'legal_case', 'news'],
          categories: ['Land Disputes', 'Legal Cases', 'Property Rights'],
        );
        break;
      case 'legal_documents':
        enhancedFilters = enhancedFilters.copyWith(
          types: ['legal_case', 'news'],
          categories: ['Legal Documents', 'Court Cases', 'Legal Resources'],
        );
        break;
    }
    
    // Add location filters from entities
    if (entities.containsKey('locations') && entities['locations']!.isNotEmpty) {
      final locations = entities['locations']!;
      enhancedFilters = enhancedFilters.copyWith(
        location: LocationFilter(states: locations),
      );
    }
    
    return enhancedFilters;
  }
  
  /// Re-rank search results based on semantic relevance
  UniversalSearchResultModel _reRankResultsSemanticaly(
    UniversalSearchResultModel results,
    ProcessedQuery processedQuery,
  ) {
    // For now, return results as-is
    // In a full implementation, this would use ML models to re-rank
    return results;
  }
  
  /// Generate profile-based recommendations
  List<SmartRecommendation> _generateProfileBasedRecommendations(
    Map<String, dynamic> userProfile,
  ) {
    final recommendations = <SmartRecommendation>[];
    
    final location = userProfile['location'] as Map<String, dynamic>?;
    final profession = userProfile['profession'] as String?;
    
    if (location != null) {
      final state = location['state'] as String?;
      if (state != null) {
        recommendations.add(SmartRecommendation(
          title: 'Land rights updates in $state',
          description: 'Latest news and updates about land rights in your state',
          query: 'land rights $state',
          type: 'location_based',
          relevanceScore: 0.8,
        ));
      }
    }
    
    if (profession == 'Farmer' || profession == 'Agriculturist') {
      recommendations.add(const SmartRecommendation(
        title: 'Agricultural land schemes',
        description: 'Government schemes and benefits for farmers',
        query: 'agricultural land scheme farmer benefits',
        type: 'profession_based',
        relevanceScore: 0.9,
      ));
    }
    
    return recommendations;
  }
  
  /// Generate recommendations based on search history
  List<SmartRecommendation> _generateSearchHistoryRecommendations(
    List<String> recentSearches,
  ) {
    final recommendations = <SmartRecommendation>[];
    
    // Analyze search patterns
    final searchPatterns = <String, int>{};
    for (final search in recentSearches) {
      final intent = _detectIntent(search);
      searchPatterns[intent] = (searchPatterns[intent] ?? 0) + 1;
    }
    
    // Generate recommendations based on most common patterns
    final sortedPatterns = searchPatterns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final pattern in sortedPatterns.take(3)) {
      switch (pattern.key) {
        case 'find_lawyer':
          recommendations.add(const SmartRecommendation(
            title: 'Top-rated land lawyers',
            description: 'Highly rated lawyers specializing in land rights',
            query: 'top rated land rights lawyer',
            type: 'search_history',
            relevanceScore: 0.7,
          ));
          break;
        case 'land_dispute':
          recommendations.add(const SmartRecommendation(
            title: 'Land dispute resolution guide',
            description: 'Step-by-step guide to resolve land disputes',
            query: 'land dispute resolution guide steps',
            type: 'search_history',
            relevanceScore: 0.7,
          ));
          break;
      }
    }
    
    return recommendations;
  }
  
  /// Generate contextual recommendations
  List<SmartRecommendation> _generateContextualRecommendations(String query) {
    final recommendations = <SmartRecommendation>[];
    final intent = _detectIntent(query);
    
    switch (intent) {
      case 'find_lawyer':
        recommendations.add(const SmartRecommendation(
          title: 'Legal aid organizations',
          description: 'Free legal aid organizations for land rights',
          query: 'legal aid organization land rights free',
          type: 'contextual',
          relevanceScore: 0.6,
        ));
        break;
      case 'land_dispute':
        recommendations.add(const SmartRecommendation(
          title: 'Similar land dispute cases',
          description: 'Cases similar to your situation with outcomes',
          query: 'land dispute case study outcome',
          type: 'contextual',
          relevanceScore: 0.6,
        ));
        break;
    }
    
    return recommendations;
  }
}

// Data models for AI search
class ProcessedQuery {
  final String originalQuery;
  final String intent;
  final Map<String, List<String>> entities;
  final String structuredQuery;
  final double confidence;
  final List<String> suggestions;

  const ProcessedQuery({
    required this.originalQuery,
    required this.intent,
    required this.entities,
    required this.structuredQuery,
    required this.confidence,
    required this.suggestions,
  });
}

class SmartRecommendation {
  final String title;
  final String description;
  final String query;
  final String type;
  final double relevanceScore;

  const SmartRecommendation({
    required this.title,
    required this.description,
    required this.query,
    required this.type,
    required this.relevanceScore,
  });
}

