// Location Search Service - Geographic and proximity-based search
// Complete location-based search for TALOWA platform

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/search/search_result_model.dart';
import '../../models/search/search_filter_model.dart';

class LocationSearchService {
  static LocationSearchService? _instance;
  static LocationSearchService get instance => _instance ??= LocationSearchService._internal();
  
  LocationSearchService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Search content near a specific location
  Future<SearchResultModel> searchNearLocation(
    String query,
    double latitude,
    double longitude, {
    double radiusKm = 50.0,
    String? contentType,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('ðŸ“ Searching near location: $latitude, $longitude (${radiusKm}km radius)');
      
      // Calculate bounding box for initial filtering
      final bounds = _calculateBoundingBox(latitude, longitude, radiusKm);
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection(contentType ?? 'posts');
      
      // Apply text search if provided
      if (query.isNotEmpty) {
        queryRef = queryRef.where('title', isGreaterThanOrEqualTo: query)
                          .where('title', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply geographic bounding box filter
      queryRef = queryRef
          .where('location.latitude', isGreaterThanOrEqualTo: bounds.minLat)
          .where('location.latitude', isLessThanOrEqualTo: bounds.maxLat)
          .where('location.longitude', isGreaterThanOrEqualTo: bounds.minLng)
          .where('location.longitude', isLessThanOrEqualTo: bounds.maxLng);
      
      queryRef = queryRef.limit(hitsPerPage ?? 50); // Get more for distance filtering
      
      final snapshot = await queryRef.get();
      
      // Filter by actual distance and sort by proximity
      final hits = <SearchHitModel>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docLat = data['location']?['latitude'] as double?;
        final docLng = data['location']?['longitude'] as double?;
        
        if (docLat != null && docLng != null) {
          final distance = _calculateDistance(latitude, longitude, docLat, docLng);
          
          if (distance <= radiusKm) {
            data['objectID'] = doc.id;
            data['distance'] = distance;
            data['type'] = contentType ?? 'post';
            hits.add(SearchHitModel.fromFirebaseDoc(data));
          }
        }
      }
      
      // Sort by distance
      hits.sort((a, b) {
        final distanceA = a.data['distance'] as double? ?? double.infinity;
        final distanceB = b.data['distance'] as double? ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });
      
      // Limit to requested page size
      final limitedHits = hits.take(hitsPerPage ?? 20).toList();
      
      final result = SearchResultModel(
        indexName: 'location_search',
        query: query,
        hits: limitedHits,
        totalHits: limitedHits.length,
        page: 0,
        hitsPerPage: hitsPerPage ?? 20,
        totalPages: 1,
        facets: {},
        processingTimeMS: 0,
        exhaustiveNbHits: true,
      );
      
      debugPrint('âœ… Location search completed: ${limitedHits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Location search failed: $e');
      rethrow;
    }
  }
  
  /// Search by administrative boundaries (state, district, mandal)
  Future<SearchResultModel> searchByAdministrativeBoundary(
    String query, {
    String? state,
    String? district,
    String? mandal,
    String? village,
    String? contentType,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('ðŸ›ï¸ Searching by administrative boundary: $state/$district/$mandal/$village');
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection(contentType ?? 'posts');
      
      // Apply text search if provided
      if (query.isNotEmpty) {
        queryRef = queryRef.where('title', isGreaterThanOrEqualTo: query)
                          .where('title', isLessThanOrEqualTo: '$query\uf8ff');
      }
      
      // Apply administrative boundary filters (most specific first)
      if (village != null) {
        queryRef = queryRef.where('location.village', isEqualTo: village);
      } else if (mandal != null) {
        queryRef = queryRef.where('location.mandal', isEqualTo: mandal);
      } else if (district != null) {
        queryRef = queryRef.where('location.district', isEqualTo: district);
      } else if (state != null) {
        queryRef = queryRef.where('location.state', isEqualTo: state);
      }
      
      queryRef = queryRef.limit(hitsPerPage ?? 20);
      
      final snapshot = await queryRef.get();
      
      final hits = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        data['type'] = contentType ?? 'post';
        return SearchHitModel.fromFirebaseDoc(data);
      }).toList();
      
      final result = SearchResultModel(
        indexName: 'administrative_search',
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
      
      debugPrint('âœ… Administrative boundary search completed: ${hits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Administrative boundary search failed: $e');
      rethrow;
    }
  }
  
  /// Get location-based suggestions
  Future<List<String>> getLocationSuggestions(String query) async {
    try {
      if (query.length < 2) return [];
      
      // Search in states, districts, and mandals
      final suggestions = <String>[];
      
      // Search states
      final statesSnapshot = await _firestore
          .collection('locations')
          .doc('states')
          .get();
      
      if (statesSnapshot.exists) {
        final states = statesSnapshot.data()?['list'] as List<dynamic>? ?? [];
        for (final state in states) {
          if (state.toString().toLowerCase().contains(query.toLowerCase())) {
            suggestions.add(state.toString());
          }
        }
      }
      
      // Search districts
      final districtsSnapshot = await _firestore
          .collection('locations')
          .doc('districts')
          .get();
      
      if (districtsSnapshot.exists) {
        final districts = districtsSnapshot.data()?['list'] as List<dynamic>? ?? [];
        for (final district in districts) {
          if (district.toString().toLowerCase().contains(query.toLowerCase())) {
            suggestions.add(district.toString());
          }
        }
      }
      
      debugPrint('ðŸ’¡ Found ${suggestions.length} location suggestions');
      return suggestions.take(10).toList();
      
    } catch (e) {
      debugPrint('âŒ Failed to get location suggestions: $e');
      return [];
    }
  }
  
  /// Find nearby professionals or services
  Future<SearchResultModel> findNearbyProfessionals(
    double latitude,
    double longitude, {
    String? profession,
    String? specialization,
    double radiusKm = 25.0,
    int? hitsPerPage,
  }) async {
    try {
      debugPrint('ðŸ‘¥ Finding nearby professionals: $profession/$specialization');
      
      final bounds = _calculateBoundingBox(latitude, longitude, radiusKm);
      
      Query<Map<String, dynamic>> queryRef = _firestore.collection('users');
      
      // Filter by profession if specified
      if (profession != null) {
        queryRef = queryRef.where('profession', isEqualTo: profession);
      }
      
      // Apply geographic bounding box filter
      queryRef = queryRef
          .where('location.latitude', isGreaterThanOrEqualTo: bounds.minLat)
          .where('location.latitude', isLessThanOrEqualTo: bounds.maxLat);
      
      queryRef = queryRef.limit(hitsPerPage ?? 50);
      
      final snapshot = await queryRef.get();
      
      // Filter by actual distance and specialization
      final hits = <SearchHitModel>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docLat = data['location']?['latitude'] as double?;
        final docLng = data['location']?['longitude'] as double?;
        final userSpecializations = data['specializations'] as List<dynamic>? ?? [];
        
        if (docLat != null && docLng != null) {
          final distance = _calculateDistance(latitude, longitude, docLat, docLng);
          
          if (distance <= radiusKm) {
            // Check specialization if specified
            if (specialization == null || userSpecializations.contains(specialization)) {
              data['objectID'] = doc.id;
              data['distance'] = distance;
              data['type'] = 'professional';
              hits.add(SearchHitModel.fromFirebaseDoc(data));
            }
          }
        }
      }
      
      // Sort by distance
      hits.sort((a, b) {
        final distanceA = a.data['distance'] as double? ?? double.infinity;
        final distanceB = b.data['distance'] as double? ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });
      
      final limitedHits = hits.take(hitsPerPage ?? 20).toList();
      
      final result = SearchResultModel(
        indexName: 'nearby_professionals',
        query: profession ?? 'professionals',
        hits: limitedHits,
        totalHits: limitedHits.length,
        page: 0,
        hitsPerPage: hitsPerPage ?? 20,
        totalPages: 1,
        facets: {},
        processingTimeMS: 0,
        exhaustiveNbHits: true,
      );
      
      debugPrint('âœ… Nearby professionals search completed: ${limitedHits.length} results');
      return result;
      
    } catch (e) {
      debugPrint('âŒ Nearby professionals search failed: $e');
      rethrow;
    }
  }
  
  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  
  /// Calculate bounding box for geographic filtering
  BoundingBox _calculateBoundingBox(double lat, double lng, double radiusKm) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double latRadian = _degreesToRadians(lat);
    final double deltaLat = radiusKm / earthRadius;
    final double deltaLng = radiusKm / (earthRadius * math.cos(latRadian));
    
    return BoundingBox(
      minLat: lat - _radiansToDegrees(deltaLat),
      maxLat: lat + _radiansToDegrees(deltaLat),
      minLng: lng - _radiansToDegrees(deltaLng),
      maxLng: lng + _radiansToDegrees(deltaLng),
    );
  }
  
  /// Convert radians to degrees
  double _radiansToDegrees(double radians) {
    return radians * (180 / math.pi);
  }
}

// Bounding box for geographic queries
class BoundingBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const BoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}

