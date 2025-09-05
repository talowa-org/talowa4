// Legal Search Service - Specialized legal document and case search
// Complete legal search functionality for TALOWA platform

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/search/search_result_model.dart';
import '../../models/search/search_filter_model.dart';

class LegalSearchService {
  static LegalSearchService? _instance;
  static LegalSearchService get instance => _instance ??= LegalSearchService._internal();
  
  LegalSearchService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Search legal cases with specialized filters
  Future<SearchResultModel> searchLegalCases(
    String query, {
    LegalCaseFilter? filters,
    int? hitsPerPage,
    int? page,
  }) async {
    try {
      debugPrint('ðŸ›ï¸ Searching legal cases for: "$query"');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('legal_cases');
      
      // Apply text search
      if (query.isNotEmpty) {
        queryRef = queryRef.where('title', isGreaterThanOrEqualTo: query)
                          .where('title', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply legal-specific filters
      if (filters != null) {
        queryRef = _applyLegalFilters(queryRef, filters);
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
        data['type'] = 'legal_case';
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'legal_cases',
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
      
      debugPrint('âœ… Legal cases search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Legal cases search failed: $e');
      rethrow;
    }
  }
  
  /// Search legal documents and resources
  Future<SearchResultModel> searchLegalDocuments(
    String query, {
    DocumentType? documentType,
    String? jurisdiction,
    DateTime? fromDate,
    DateTime? toDate,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('ðŸ“„ Searching legal documents for: "$query"');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('legal_documents');
      
      // Apply text search
      if (query.isNotEmpty) {
        queryRef = queryRef.where('title', isGreaterThanOrEqualTo: query)
                          .where('title', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply document type filter
      if (documentType != null) {
        queryRef = queryRef.where('documentType', isEqualTo: documentType.toString().split('.').last);
      }
      
      // Apply jurisdiction filter
      if (jurisdiction != null) {
        queryRef = queryRef.where('jurisdiction', isEqualTo: jurisdiction);
      }
      
      // Apply date range filters
      if (fromDate != null) {
        queryRef = queryRef.where('publishedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
      }
      if (toDate != null) {
        queryRef = queryRef.where('publishedAt', isLessThanOrEqualTo: Timestamp.fromDate(toDate));
      }
      
      queryRef = queryRef.limit(hitsPerPage ?? 20);
      
      final snapshot = await queryRef.get();
      
      final hits = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        data['type'] = 'legal_document';
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'legal_documents',
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
      
      debugPrint('âœ… Legal documents search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Legal documents search failed: $e');
      rethrow;
    }
  }
  
  /// Search for legal professionals (lawyers, advocates, etc.)
  Future<SearchResultModel> searchLegalProfessionals(
    String query, {
    String? specialization,
    String? location,
    double? minRating,
    int? minExperience,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('ðŸ‘¨â€âš–ï¸ Searching legal professionals for: "$query"');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('legal_professionals');
      
      // Apply text search
      if (query.isNotEmpty) {
        queryRef = queryRef.where('name', isGreaterThanOrEqualTo: query)
                          .where('name', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply specialization filter
      if (specialization != null) {
        queryRef = queryRef.where('specializations', arrayContains: specialization);
      }
      
      // Apply location filter
      if (location != null) {
        queryRef = queryRef.where('location.state', isEqualTo: location);
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
  
  /// Get legal search suggestions based on common legal terms
  Future<List<String>> getLegalSuggestions(String query) async {
    try {
      if (query.length < 2) return [];
      
      final legalTerms = [
        'land acquisition',
        'property rights',
        'land dispute',
        'compensation',
        'court case',
        'legal notice',
        'property title',
        'land records',
        'revenue records',
        'mutation',
        'survey settlement',
        'land ceiling',
        'agricultural land',
        'non-agricultural land',
        'land conversion',
        'property registration',
        'stamp duty',
        'registration fee',
        'property tax',
        'land revenue',
      ];
      
      final suggestions = legalTerms
          .where((term) => term.toLowerCase().contains(query.toLowerCase()))
          .take(10)
          .toList();
      
      debugPrint('ðŸ’¡ Found ${suggestions.length} legal suggestions');
      return suggestions;
      
    } catch (e) {
      debugPrint('âŒ Failed to get legal suggestions: $e');
      return [];
    }
  }
  
  /// Apply legal-specific filters to query
  Query<Map<String, dynamic>> _applyLegalFilters(
    Query<Map<String, dynamic>> query,
    LegalCaseFilter filters,
  ) {
    // Apply case status filter
    if (filters.caseStatus != null) {
      query = query.where('status', isEqualTo: filters.caseStatus);
    }
    
    // Apply court type filter
    if (filters.courtType != null) {
      query = query.where('courtType', isEqualTo: filters.courtType);
    }
    
    // Apply case type filter
    if (filters.caseType != null) {
      query = query.where('caseType', isEqualTo: filters.caseType);
    }
    
    // Apply priority filter
    if (filters.priority != null) {
      query = query.where('priority', isEqualTo: filters.priority);
    }
    
    // Apply location filter
    if (filters.state != null) {
      query = query.where('location.state', isEqualTo: filters.state);
    }
    
    return query;
  }
}

// Legal case filter model
class LegalCaseFilter {
  final String? caseStatus;
  final String? courtType;
  final String? caseType;
  final String? priority;
  final String? state;
  final DateTime? fromDate;
  final DateTime? toDate;

  const LegalCaseFilter({
    this.caseStatus,
    this.courtType,
    this.caseType,
    this.priority,
    this.state,
    this.fromDate,
    this.toDate,
  });
}

// Document type enumeration
enum DocumentType {
  act,
  rule,
  notification,
  circular,
  judgment,
  order,
  guideline,
  policy,
}

// Legal specializations
class LegalSpecializations {
  static const List<String> all = [
    'Land Rights',
    'Property Law',
    'Agricultural Law',
    'Civil Litigation',
    'Constitutional Law',
    'Administrative Law',
    'Revenue Law',
    'Real Estate Law',
    'Environmental Law',
    'Human Rights',
  ];
}

