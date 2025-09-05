import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'security_service.dart';

class LocationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current location with permission handling
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get location with timeout for rural areas
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  /// Auto-tag location for reports
  static Future<Map<String, dynamic>> getLocationData() async {
    final position = await getCurrentLocation();
    if (position == null) return {};

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final placemark = placemarks.first;
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'village': placemark.subLocality ?? placemark.locality,
        'mandal': placemark.subAdministrativeArea,
        'district': placemark.administrativeArea,
        'state': placemark.administrativeArea,
        'pincode': placemark.postalCode,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  /// Find nearby coordinators
  static Future<List<Map<String, dynamic>>> findNearbyCoordinators({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // Query coordinators within radius
      final coordinators = await _firestore
          .collection('users')
          .where('role', whereIn: ['village_coordinator', 'mandal_coordinator', 'district_coordinator'])
          .where('isActive', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> nearbyCoordinators = [];

      for (var doc in coordinators.docs) {
        final data = doc.data();
        final coordLat = data['location']?['latitude'];
        final coordLng = data['location']?['longitude'];

        if (coordLat != null && coordLng != null) {
          final distance = _calculateDistance(
            latitude, longitude,
            coordLat.toDouble(), coordLng.toDouble(),
          );

          if (distance <= radiusKm) {
            nearbyCoordinators.add({
              ...data,
              'id': doc.id,
              'distance': distance,
            });
          }
        }
      }

      // Sort by distance
      nearbyCoordinators.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double));

      return nearbyCoordinators;
    } catch (e) {
      debugPrint('Error finding nearby coordinators: $e');
      return [];
    }
  }

  /// Calculate distance between two points (Haversine formula)
  static double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Generate geo-analytics for admins
  static Future<Map<String, dynamic>> generateGeoAnalytics({
    required String adminLevel, // 'state', 'district', 'mandal'
    required String adminId,
  }) async {
    try {
      Query query = _firestore.collection('users');
      
      // Filter based on admin level
      switch (adminLevel) {
        case 'state':
          query = query.where('address.state', isEqualTo: adminId);
          break;
        case 'district':
          query = query.where('address.district', isEqualTo: adminId);
          break;
        case 'mandal':
          query = query.where('address.mandal', isEqualTo: adminId);
          break;
      }

      final snapshot = await query.get();
      
      Map<String, int> membersByArea = {};
      Map<String, int> issuesByArea = {};
      List<Map<String, dynamic>> hotspots = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final location = data['address'];
        
        if (location != null) {
          final area = location['village'] ?? location['mandal'] ?? 'Unknown';
          membersByArea[area] = (membersByArea[area] ?? 0) + 1;
        }
      }

      // Get recent issues for heatmap
      final recentIssues = await _firestore
          .collection('incidents')
          .where('createdAt', isGreaterThan: 
            Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))))
          .get();

      for (var doc in recentIssues.docs) {
        final data = doc.data();
        final location = data['location'];
        
        if (location != null) {
          final area = location['village'] ?? 'Unknown';
          issuesByArea[area] = (issuesByArea[area] ?? 0) + 1;
        }
      }

      // Identify hotspots (areas with high issues relative to members)
      membersByArea.forEach((area, memberCount) {
        final issueCount = issuesByArea[area] ?? 0;
        final issueRatio = memberCount > 0 ? issueCount / memberCount : 0;
        
        if (issueRatio > 0.1) { // More than 10% of members reported issues
          hotspots.add({
            'area': area,
            'members': memberCount,
            'issues': issueCount,
            'issueRatio': issueRatio,
            'priority': issueRatio > 0.3 ? 'high' : 'medium',
          });
        }
      });

      return {
        'totalMembers': snapshot.docs.length,
        'membersByArea': membersByArea,
        'issuesByArea': issuesByArea,
        'hotspots': hotspots,
        'generatedAt': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('Error generating geo-analytics: $e');
      return {};
    }
  }

  /// Cache offline maps data
  static Future<void> cacheOfflineMapData({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
  }) async {
    // In production, implement offline map tile caching
    // For now, cache essential location data
    try {
      final locationData = {
        'center': {'lat': centerLat, 'lng': centerLng},
        'radius': radiusKm,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'villages': await _getNearbyVillages(centerLat, centerLng, radiusKm),
      };

      // Store in secure local storage
      await SecurityService.storeSecurely(
        'offline_map_data',
        jsonEncode(locationData),
      );
    } catch (e) {
      debugPrint('Error caching map data: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _getNearbyVillages(
    double centerLat, double centerLng, double radiusKm,
  ) async {
    // Query nearby villages from database
    // This would be populated with village boundary data
    return [];
  }
}
