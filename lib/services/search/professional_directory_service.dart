// Professional Directory Search Service - Find lawyers, activists, experts
// Complete professional directory for TALOWA platform

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/search/search_result_model.dart';
import '../../models/search/search_filter_model.dart';

class ProfessionalDirectoryService {
  static ProfessionalDirectoryService? _instance;
  static ProfessionalDirectoryService get instance => _instance ??= ProfessionalDirectoryService._internal();
  
  ProfessionalDirectoryService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Search for legal professionals (lawyers, advocates)
  Future<SearchResultModel> searchLegalProfessionals(
    String query, {
    ProfessionalFilter? filters,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('ðŸ‘¨â€âš–ï¸ Searching legal professionals for: "$query"');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('users');
      
      // Filter by legal professions
      queryRef = queryRef.where('profession', whereIn: [
        'Lawyer',
        'Advocate',
        'Legal Advisor',
        'Legal Consultant',
        'Public Interest Lawyer',
      ]);
      
      // Apply text search
      if (query.isNotEmpty) {
        queryRef = queryRef.where('name', isGreaterThanOrEqualTo: query)
                          .where('name', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply filters
      if (filters != null) {
        queryRef = _applyProfessionalFilters(queryRef, filters);
      }
      
      queryRef = queryRef.limit(hitsPerPage ?? 20);
      
      final snapshot = await queryRef.get();
      
      final hits = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        data['type'] = 'legal_professional';
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'legal_professionals',
        query: query,
        hits: hits,
        totalHits: hits.length,
        page: 0,
        hitsPerPage: hitsPerPage ?? 20,
        totalPages: 1,
        facets: {},
        processingTimeMS: 0,
        exhaustiveNbHits: true,
      );
      
      debugPrint('âœ… Legal professionals search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Legal professionals search failed: $e');
      rethrow;
    }
  }
  
  /// Search for activists and community leaders
  Future<SearchResultModel> searchActivists(
    String query, {
    String? focusArea,
    String? location,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('âœŠ Searching activists for: "$query"');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('users');
      
      // Filter by activist roles
      queryRef = queryRef.where('profession', whereIn: [
        'Activist',
        'Community Leader',
        'Social Worker',
        'NGO Worker',
        'Human Rights Activist',
        'Land Rights Activist',
      ]);
      
      // Apply text search
      if (query.isNotEmpty) {
        queryRef = queryRef.where('name', isGreaterThanOrEqualTo: query)
                          .where('name', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply focus area filter
      if (focusArea != null) {
        queryRef = queryRef.where('specializations', arrayContains: focusArea);
      }
      
      // Apply location filter
      if (location != null) {
        queryRef = queryRef.where('location.state', isEqualTo: location);
      }
      
      queryRef = queryRef.limit(hitsPerPage ?? 20);
      
      final snapshot = await queryRef.get();
      
      final hits = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        data['type'] = 'activist';
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'activists',
        query: query,
        hits: hits,
        totalHits: hits.length,
        page: 0,
        hitsPerPage: hitsPerPage ?? 20,
        totalPages: 1,
        facets: {},
        processingTimeMS: 0,
        exhaustiveNbHits: true,
      );
      
      debugPrint('âœ… Activists search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Activists search failed: $e');
      rethrow;
    }
  }
  
  /// Search for experts and consultants
  Future<SearchResultModel> searchExperts(
    String query, {
    String? expertise,
    double? minRating,
    int? minExperience,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('ðŸŽ“ Searching experts for: "$query"');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('users');
      
      // Filter by expert roles
      queryRef = queryRef.where('profession', whereIn: [
        'Expert',
        'Consultant',
        'Researcher',
        'Policy Analyst',
        'Land Surveyor',
        'Agricultural Expert',
        'Legal Expert',
      ]);
      
      // Apply text search
      if (query.isNotEmpty) {
        queryRef = queryRef.where('name', isGreaterThanOrEqualTo: query)
                          .where('name', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply expertise filter
      if (expertise != null) {
        queryRef = queryRef.where('specializations', arrayContains: expertise);
      }
      
      // Apply rating filter
      if (minRating != null) {
        queryRef = queryRef.where('rating', isGreaterThanOrEqualTo: minRating);
      }
      
      // Apply experience filter
      if (minExperience != null) {
        queryRef = queryRef.where('experienceYears', isGreaterThanOrEqualTo: minExperience);
      }
      
      queryRef = queryRef.limit(hitsPerPage ?? 20);
      
      final snapshot = await queryRef.get();
      
      final hits = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        data['type'] = 'expert';
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'experts',
        query: query,
        hits: hits,
        totalHits: hits.length,
        page: 0,
        hitsPerPage: hitsPerPage ?? 20,
        totalPages: 1,
        facets: {},
        processingTimeMS: 0,
        exhaustiveNbHits: true,
      );
      
      debugPrint('âœ… Experts search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Experts search failed: $e');
      rethrow;
    }
  }
  
  /// Get professional directory suggestions
  Future<List<String>> getProfessionalSuggestions(String query) async {
    try {
      if (query.length < 2) return [];
      
      final professions = [
        'Lawyer',
        'Advocate',
        'Legal Advisor',
        'Activist',
        'Community Leader',
        'Social Worker',
        'Land Rights Expert',
        'Agricultural Expert',
        'Policy Analyst',
        'Legal Consultant',
        'Human Rights Lawyer',
        'Public Interest Lawyer',
        'Land Surveyor',
        'Revenue Official',
        'NGO Worker',
      ];
      
      final suggestions = professions
          .where((profession) => profession.toLowerCase().contains(query.toLowerCase()))
          .take(10)
          .toList();
      
      debugPrint('ðŸ’¡ Found ${suggestions.length} professional suggestions');
      return suggestions;
      
    } catch (e) {
      debugPrint('âŒ Failed to get professional suggestions: $e');
      return [];
    }
  }
  
  /// Get top-rated professionals by category
  Future<SearchResultModel> getTopRatedProfessionals(
    String category, {
    String? location,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('â­ Getting top-rated professionals in: $category');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('users');
      
      // Filter by category/profession
      queryRef = queryRef.where('profession', isEqualTo: category);
      
      // Apply location filter if specified
      if (location != null) {
        queryRef = queryRef.where('location.state', isEqualTo: location);
      }
      
      // Order by rating and review count
      queryRef = queryRef
          .where('rating', isGreaterThanOrEqualTo: 4.0)
          .orderBy('rating', descending: true)
          .orderBy('reviewsCount', descending: true);
      
      queryRef = queryRef.limit(hitsPerPage ?? 10);
      
      final snapshot = await queryRef.get();
      
      final hits = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        data['type'] = 'top_professional';
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'top_professionals',
        query: category,
        hits: hits,
        totalHits: hits.length,
        page: 0,
        hitsPerPage: hitsPerPage ?? 10,
        totalPages: 1,
        facets: {},
        processingTimeMS: 0,
        exhaustiveNbHits: true,
      );
      
      debugPrint('âœ… Top-rated professionals search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Top-rated professionals search failed: $e');
      rethrow;
    }
  }
  
  /// Apply professional-specific filters
  Query<Map<String, dynamic>> _applyProfessionalFilters(
    Query<Map<String, dynamic>> query,
    ProfessionalFilter filters,
  ) {
    // Apply specialization filter
    if (filters.specializations != null && filters.specializations!.isNotEmpty) {
      query = query.where('specializations', arrayContainsAny: filters.specializations);
    }
    
    // Apply location filter
    if (filters.location != null) {
      query = query.where('location.state', isEqualTo: filters.location);
    }
    
    // Apply rating filter
    if (filters.minRating != null) {
      query = query.where('rating', isGreaterThanOrEqualTo: filters.minRating);
    }
    
    // Apply experience filter
    if (filters.minExperience != null) {
      query = query.where('experienceYears', isGreaterThanOrEqualTo: filters.minExperience);
    }
    
    // Apply verification filter
    if (filters.verifiedOnly == true) {
      query = query.where('isVerified', isEqualTo: true);
    }
    
    return query;
  }
}

// Professional filter model
class ProfessionalFilter {
  final List<String>? specializations;
  final String? location;
  final double? minRating;
  final int? minExperience;
  final bool? verifiedOnly;
  final bool? availableNow;

  const ProfessionalFilter({
    this.specializations,
    this.location,
    this.minRating,
    this.minExperience,
    this.verifiedOnly,
    this.availableNow,
  });
}

// Professional categories
class ProfessionalCategories {
  static const List<String> legal = [
    'Lawyer',
    'Advocate',
    'Legal Advisor',
    'Legal Consultant',
    'Public Interest Lawyer',
    'Human Rights Lawyer',
  ];
  
  static const List<String> activism = [
    'Activist',
    'Community Leader',
    'Social Worker',
    'NGO Worker',
    'Human Rights Activist',
    'Land Rights Activist',
  ];
  
  static const List<String> experts = [
    'Expert',
    'Consultant',
    'Researcher',
    'Policy Analyst',
    'Land Surveyor',
    'Agricultural Expert',
    'Legal Expert',
  ];
  
  static const List<String> all = [
    ...legal,
    ...activism,
    ...experts,
  ];
}

