// Geographic Targeting Model for TALOWA Social Feed System
// Handles location-based content targeting and filtering

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

class GeographicTargeting {
  final String? village;
  final String? mandal;
  final String? district;
  final String? state;
  final double? radiusKm;
  final GeoPoint? centerPoint;
  final TargetingScope scope;

  const GeographicTargeting({
    this.village,
    this.mandal,
    this.district,
    this.state,
    this.radiusKm,
    this.centerPoint,
    this.scope = TargetingScope.district,
  });

  /// Create GeographicTargeting from Map
  factory GeographicTargeting.fromMap(Map<String, dynamic> data) {
    return GeographicTargeting(
      village: data['village'],
      mandal: data['mandal'],
      district: data['district'],
      state: data['state'],
      radiusKm: data['radiusKm']?.toDouble(),
      centerPoint: data['centerPoint'] as GeoPoint?,
      scope: TargetingScope.values.firstWhere(
        (e) => e.toString().split('.').last == data['scope'],
        orElse: () => TargetingScope.district,
      ),
    );
  }

  /// Convert GeographicTargeting to Map
  Map<String, dynamic> toMap() {
    return {
      'village': village,
      'mandal': mandal,
      'district': district,
      'state': state,
      'radiusKm': radiusKm,
      'centerPoint': centerPoint,
      'scope': scope.toString().split('.').last,
    };
  }

  /// Create a copy with updated fields
  GeographicTargeting copyWith({
    String? village,
    String? mandal,
    String? district,
    String? state,
    double? radiusKm,
    GeoPoint? centerPoint,
    TargetingScope? scope,
  }) {
    return GeographicTargeting(
      village: village ?? this.village,
      mandal: mandal ?? this.mandal,
      district: district ?? this.district,
      state: state ?? this.state,
      radiusKm: radiusKm ?? this.radiusKm,
      centerPoint: centerPoint ?? this.centerPoint,
      scope: scope ?? this.scope,
    );
  }

  /// Check if a user location matches this targeting
  bool matchesUserLocation({
    String? userVillage,
    String? userMandal,
    String? userDistrict,
    String? userState,
    GeoPoint? userLocation,
  }) {
    switch (scope) {
      case TargetingScope.village:
        return village != null && 
               userVillage != null && 
               village!.toLowerCase() == userVillage.toLowerCase();
               
      case TargetingScope.mandal:
        return mandal != null && 
               userMandal != null && 
               mandal!.toLowerCase() == userMandal.toLowerCase();
               
      case TargetingScope.district:
        return district != null && 
               userDistrict != null && 
               district!.toLowerCase() == userDistrict.toLowerCase();
               
      case TargetingScope.state:
        return state != null && 
               userState != null && 
               state!.toLowerCase() == userState.toLowerCase();
               
      case TargetingScope.radius:
        if (centerPoint != null && userLocation != null && radiusKm != null) {
          final distance = _calculateDistance(centerPoint!, userLocation);
          return distance <= radiusKm!;
        }
        return false;
        
      case TargetingScope.national:
        return true; // National scope matches everyone
    }
  }

  /// Calculate distance between two GeoPoints in kilometers
  double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    // Haversine formula for calculating distance between two points on Earth
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);
    
    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  /// Get display string for the targeting scope
  String getDisplayString() {
    switch (scope) {
      case TargetingScope.village:
        return village ?? 'Village';
      case TargetingScope.mandal:
        return mandal ?? 'Mandal';
      case TargetingScope.district:
        return district ?? 'District';
      case TargetingScope.state:
        return state ?? 'State';
      case TargetingScope.radius:
        return radiusKm != null ? '${radiusKm!.toInt()}km radius' : 'Radius';
      case TargetingScope.national:
        return 'National';
    }
  }

  /// Get hierarchical location string
  String getHierarchicalString() {
    final parts = <String>[];
    
    if (village != null) parts.add(village!);
    if (mandal != null) parts.add(mandal!);
    if (district != null) parts.add(district!);
    if (state != null) parts.add(state!);
    
    return parts.join(', ');
  }

  /// Create targeting for village level
  static GeographicTargeting forVillage({
    required String village,
    required String mandal,
    required String district,
    required String state,
  }) {
    return GeographicTargeting(
      village: village,
      mandal: mandal,
      district: district,
      state: state,
      scope: TargetingScope.village,
    );
  }

  /// Create targeting for mandal level
  static GeographicTargeting forMandal({
    required String mandal,
    required String district,
    required String state,
  }) {
    return GeographicTargeting(
      mandal: mandal,
      district: district,
      state: state,
      scope: TargetingScope.mandal,
    );
  }

  /// Create targeting for district level
  static GeographicTargeting forDistrict({
    required String district,
    required String state,
  }) {
    return GeographicTargeting(
      district: district,
      state: state,
      scope: TargetingScope.district,
    );
  }

  /// Create targeting for state level
  static GeographicTargeting forState({
    required String state,
  }) {
    return GeographicTargeting(
      state: state,
      scope: TargetingScope.state,
    );
  }

  /// Create targeting for radius-based
  static GeographicTargeting forRadius({
    required GeoPoint centerPoint,
    required double radiusKm,
  }) {
    return GeographicTargeting(
      centerPoint: centerPoint,
      radiusKm: radiusKm,
      scope: TargetingScope.radius,
    );
  }

  /// Create national targeting
  static GeographicTargeting forNational() {
    return const GeographicTargeting(
      scope: TargetingScope.national,
    );
  }

  /// Validate targeting data
  String? validate() {
    switch (scope) {
      case TargetingScope.village:
        if (village == null || village!.isEmpty) {
          return 'Village name is required for village targeting';
        }
        if (mandal == null || mandal!.isEmpty) {
          return 'Mandal name is required for village targeting';
        }
        if (district == null || district!.isEmpty) {
          return 'District name is required for village targeting';
        }
        if (state == null || state!.isEmpty) {
          return 'State name is required for village targeting';
        }
        break;
        
      case TargetingScope.mandal:
        if (mandal == null || mandal!.isEmpty) {
          return 'Mandal name is required for mandal targeting';
        }
        if (district == null || district!.isEmpty) {
          return 'District name is required for mandal targeting';
        }
        if (state == null || state!.isEmpty) {
          return 'State name is required for mandal targeting';
        }
        break;
        
      case TargetingScope.district:
        if (district == null || district!.isEmpty) {
          return 'District name is required for district targeting';
        }
        if (state == null || state!.isEmpty) {
          return 'State name is required for district targeting';
        }
        break;
        
      case TargetingScope.state:
        if (state == null || state!.isEmpty) {
          return 'State name is required for state targeting';
        }
        break;
        
      case TargetingScope.radius:
        if (centerPoint == null) {
          return 'Center point is required for radius targeting';
        }
        if (radiusKm == null || radiusKm! <= 0) {
          return 'Valid radius is required for radius targeting';
        }
        if (radiusKm! > 1000) {
          return 'Radius cannot exceed 1000 km';
        }
        break;
        
      case TargetingScope.national:
        // No validation needed for national scope
        break;
    }
    
    return null; // Valid
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeographicTargeting &&
          runtimeType == other.runtimeType &&
          village == other.village &&
          mandal == other.mandal &&
          district == other.district &&
          state == other.state &&
          radiusKm == other.radiusKm &&
          centerPoint == other.centerPoint &&
          scope == other.scope;

  @override
  int get hashCode =>
      village.hashCode ^
      mandal.hashCode ^
      district.hashCode ^
      state.hashCode ^
      radiusKm.hashCode ^
      centerPoint.hashCode ^
      scope.hashCode;

  @override
  String toString() {
    return 'GeographicTargeting{scope: $scope, ${getHierarchicalString()}}';
  }
}

/// Targeting scope enumeration
enum TargetingScope {
  village,
  mandal,
  district,
  state,
  radius,
  national,
}

/// Extension for TargetingScope localization
extension TargetingScopeExtension on TargetingScope {
  String get displayName {
    switch (this) {
      case TargetingScope.village:
        return 'Village';
      case TargetingScope.mandal:
        return 'Mandal';
      case TargetingScope.district:
        return 'District';
      case TargetingScope.state:
        return 'State';
      case TargetingScope.radius:
        return 'Radius';
      case TargetingScope.national:
        return 'National';
    }
  }

  String get description {
    switch (this) {
      case TargetingScope.village:
        return 'Target specific village';
      case TargetingScope.mandal:
        return 'Target entire mandal/tehsil';
      case TargetingScope.district:
        return 'Target entire district';
      case TargetingScope.state:
        return 'Target entire state';
      case TargetingScope.radius:
        return 'Target within radius';
      case TargetingScope.national:
        return 'Target entire country';
    }
  }

  String get icon {
    switch (this) {
      case TargetingScope.village:
        return '🏘️';
      case TargetingScope.mandal:
        return '🏙️';
      case TargetingScope.district:
        return '🌆';
      case TargetingScope.state:
        return '🗺️';
      case TargetingScope.radius:
        return '📍';
      case TargetingScope.national:
        return '🇮🇳';
    }
  }
}