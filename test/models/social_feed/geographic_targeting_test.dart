// Test file for GeographicTargeting
// Tests for geographic targeting functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/models/social_feed/index.dart';

void main() {
  group('GeographicTargeting Tests', () {
    group('Factory Constructors', () {
      test('should create village-level targeting', () {
        // Act
        final targeting = GeographicTargeting.forVillage(
          village: 'रामपुर',
          mandal: 'सरायकेला',
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Assert
        expect(targeting.village, equals('रामपुर'));
        expect(targeting.mandal, equals('सरायकेला'));
        expect(targeting.district, equals('सरायकेला खरसावां'));
        expect(targeting.state, equals('झारखंड'));
        expect(targeting.scope, equals(TargetingScope.village));
      });

      test('should create mandal-level targeting', () {
        // Act
        final targeting = GeographicTargeting.forMandal(
          mandal: 'सरायकेला',
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Assert
        expect(targeting.village, isNull);
        expect(targeting.mandal, equals('सरायकेला'));
        expect(targeting.district, equals('सरायकेला खरसावां'));
        expect(targeting.state, equals('झारखंड'));
        expect(targeting.scope, equals(TargetingScope.mandal));
      });

      test('should create district-level targeting', () {
        // Act
        final targeting = GeographicTargeting.forDistrict(
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Assert
        expect(targeting.village, isNull);
        expect(targeting.mandal, isNull);
        expect(targeting.district, equals('सरायकेला खरसावां'));
        expect(targeting.state, equals('झारखंड'));
        expect(targeting.scope, equals(TargetingScope.district));
      });

      test('should create state-level targeting', () {
        // Act
        final targeting = GeographicTargeting.forState(
          state: 'झारखंड',
        );

        // Assert
        expect(targeting.village, isNull);
        expect(targeting.mandal, isNull);
        expect(targeting.district, isNull);
        expect(targeting.state, equals('झारखंड'));
        expect(targeting.scope, equals(TargetingScope.state));
      });

      test('should create radius-based targeting', () {
        // Arrange
        final centerPoint = const GeoPoint(23.3441, 85.3096); // Ranchi coordinates
        const radiusKm = 50.0;

        // Act
        final targeting = GeographicTargeting.forRadius(
          centerPoint: centerPoint,
          radiusKm: radiusKm,
        );

        // Assert
        expect(targeting.centerPoint, equals(centerPoint));
        expect(targeting.radiusKm, equals(radiusKm));
        expect(targeting.scope, equals(TargetingScope.radius));
      });

      test('should create national targeting', () {
        // Act
        final targeting = GeographicTargeting.forNational();

        // Assert
        expect(targeting.village, isNull);
        expect(targeting.mandal, isNull);
        expect(targeting.district, isNull);
        expect(targeting.state, isNull);
        expect(targeting.scope, equals(TargetingScope.national));
      });
    });

    group('User Location Matching', () {
      test('should match village-level targeting', () {
        // Arrange
        final targeting = GeographicTargeting.forVillage(
          village: 'रामपुर',
          mandal: 'सरायकेला',
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'रामपुर',
          userMandal: 'सरायकेला',
          userDistrict: 'सरायकेला खरसावां',
          userState: 'झारखंड',
        ), isTrue);

        expect(targeting.matchesUserLocation(
          userVillage: 'अन्य गांव',
          userMandal: 'सरायकेला',
          userDistrict: 'सरायकेला खरसावां',
          userState: 'झारखंड',
        ), isFalse);
      });

      test('should match mandal-level targeting', () {
        // Arrange
        final targeting = GeographicTargeting.forMandal(
          mandal: 'सरायकेला',
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'कोई भी गांव',
          userMandal: 'सरायकेला',
          userDistrict: 'सरायकेला खरसावां',
          userState: 'झारखंड',
        ), isTrue);

        expect(targeting.matchesUserLocation(
          userVillage: 'कोई भी गांव',
          userMandal: 'अन्य मंडल',
          userDistrict: 'सरायकेला खरसावां',
          userState: 'झारखंड',
        ), isFalse);
      });

      test('should match district-level targeting', () {
        // Arrange
        final targeting = GeographicTargeting.forDistrict(
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'कोई भी गांव',
          userMandal: 'कोई भी मंडल',
          userDistrict: 'सरायकेला खरसावां',
          userState: 'झारखंड',
        ), isTrue);

        expect(targeting.matchesUserLocation(
          userVillage: 'कोई भी गांव',
          userMandal: 'कोई भी मंडल',
          userDistrict: 'अन्य जिला',
          userState: 'झारखंड',
        ), isFalse);
      });

      test('should match state-level targeting', () {
        // Arrange
        final targeting = GeographicTargeting.forState(
          state: 'झारखंड',
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'कोई भी गांव',
          userMandal: 'कोई भी मंडल',
          userDistrict: 'कोई भी जिला',
          userState: 'झारखंड',
        ), isTrue);

        expect(targeting.matchesUserLocation(
          userVillage: 'कोई भी गांव',
          userMandal: 'कोई भी मंडल',
          userDistrict: 'कोई भी जिला',
          userState: 'बिहार',
        ), isFalse);
      });

      test('should match national targeting for all users', () {
        // Arrange
        final targeting = GeographicTargeting.forNational();

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'कोई भी गांव',
          userMandal: 'कोई भी मंडल',
          userDistrict: 'कोई भी जिला',
          userState: 'कोई भी राज्य',
        ), isTrue);

        expect(targeting.matchesUserLocation(), isTrue);
      });

      test('should handle case-insensitive matching', () {
        // Arrange
        final targeting = GeographicTargeting.forDistrict(
          district: 'Saraikela Kharsawan',
          state: 'Jharkhand',
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userDistrict: 'saraikela kharsawan',
          userState: 'jharkhand',
        ), isTrue);

        expect(targeting.matchesUserLocation(
          userDistrict: 'SARAIKELA KHARSAWAN',
          userState: 'JHARKHAND',
        ), isTrue);
      });
    });

    group('Radius-based Targeting', () {
      test('should match locations within radius', () {
        // Arrange
        final centerPoint = const GeoPoint(23.3441, 85.3096); // Ranchi
        final targeting = GeographicTargeting.forRadius(
          centerPoint: centerPoint,
          radiusKm: 100.0,
        );

        // Nearby location (approximately 50km from Ranchi)
        final nearbyLocation = const GeoPoint(23.8103, 85.8372);

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userLocation: nearbyLocation,
        ), isTrue);
      });

      test('should not match locations outside radius', () {
        // Arrange
        final centerPoint = const GeoPoint(23.3441, 85.3096); // Ranchi
        final targeting = GeographicTargeting.forRadius(
          centerPoint: centerPoint,
          radiusKm: 50.0,
        );

        // Far location (Delhi - much farther than 50km)
        final farLocation = const GeoPoint(28.6139, 77.2090);

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userLocation: farLocation,
        ), isFalse);
      });

      test('should handle missing location data for radius targeting', () {
        // Arrange
        final centerPoint = const GeoPoint(23.3441, 85.3096);
        final targeting = GeographicTargeting.forRadius(
          centerPoint: centerPoint,
          radiusKm: 50.0,
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(), isFalse);
      });
    });

    group('Display Strings', () {
      test('should generate correct display strings', () {
        // Arrange & Act & Assert
        final villageTargeting = GeographicTargeting.forVillage(
          village: 'रामपुर',
          mandal: 'सरायकेला',
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );
        expect(villageTargeting.getDisplayString(), equals('रामपुर'));

        final mandalTargeting = GeographicTargeting.forMandal(
          mandal: 'सरायकेला',
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );
        expect(mandalTargeting.getDisplayString(), equals('सरायकेला'));

        final radiusTargeting = GeographicTargeting.forRadius(
          centerPoint: const GeoPoint(23.3441, 85.3096),
          radiusKm: 25.5,
        );
        expect(radiusTargeting.getDisplayString(), equals('25km radius'));

        final nationalTargeting = GeographicTargeting.forNational();
        expect(nationalTargeting.getDisplayString(), equals('National'));
      });

      test('should generate hierarchical strings', () {
        // Arrange
        final targeting = GeographicTargeting.forVillage(
          village: 'रामपुर',
          mandal: 'सरायकेला',
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Act
        final hierarchical = targeting.getHierarchicalString();

        // Assert
        expect(hierarchical, equals('रामपुर, सरायकेला, सरायकेला खरसावां, झारखंड'));
      });

      test('should handle partial hierarchical data', () {
        // Arrange
        final targeting = GeographicTargeting.forDistrict(
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Act
        final hierarchical = targeting.getHierarchicalString();

        // Assert
        expect(hierarchical, equals('सरायकेला खरसावां, झारखंड'));
      });
    });

    group('Validation', () {
      test('should validate village targeting successfully', () {
        // Arrange
        final targeting = GeographicTargeting.forVillage(
          village: 'रामपुर',
          mandal: 'सरायकेला',
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Act
        final validation = targeting.validate();

        // Assert
        expect(validation, isNull);
      });

      test('should fail validation for incomplete village targeting', () {
        // Arrange
        final targeting = GeographicTargeting(
          village: 'रामपुर',
          // Missing mandal, district, state
          scope: TargetingScope.village,
        );

        // Act
        final validation = targeting.validate();

        // Assert
        expect(validation, isNotNull);
        expect(validation, contains('Mandal name is required'));
      });

      test('should validate radius targeting successfully', () {
        // Arrange
        final targeting = GeographicTargeting.forRadius(
          centerPoint: const GeoPoint(23.3441, 85.3096),
          radiusKm: 50.0,
        );

        // Act
        final validation = targeting.validate();

        // Assert
        expect(validation, isNull);
      });

      test('should fail validation for invalid radius', () {
        // Arrange
        final targeting = GeographicTargeting(
          centerPoint: const GeoPoint(23.3441, 85.3096),
          radiusKm: 1500.0, // Exceeds 1000km limit
          scope: TargetingScope.radius,
        );

        // Act
        final validation = targeting.validate();

        // Assert
        expect(validation, isNotNull);
        expect(validation, contains('cannot exceed 1000 km'));
      });

      test('should fail validation for missing radius data', () {
        // Arrange
        final targeting = GeographicTargeting(
          // Missing centerPoint and radiusKm
          scope: TargetingScope.radius,
        );

        // Act
        final validation = targeting.validate();

        // Assert
        expect(validation, isNotNull);
        expect(validation, contains('Center point is required'));
      });

      test('should validate national targeting without requirements', () {
        // Arrange
        final targeting = GeographicTargeting.forNational();

        // Act
        final validation = targeting.validate();

        // Assert
        expect(validation, isNull);
      });
    });

    group('Serialization', () {
      test('should serialize and deserialize correctly', () {
        // Arrange
        final originalTargeting = GeographicTargeting.forVillage(
          village: 'रामपुर',
          mandal: 'सरायकेला',
          district: 'सरायकेला खरसावां',
          state: 'झारखंड',
        );

        // Act
        final map = originalTargeting.toMap();
        final deserializedTargeting = GeographicTargeting.fromMap(map);

        // Assert
        expect(deserializedTargeting.village, equals(originalTargeting.village));
        expect(deserializedTargeting.mandal, equals(originalTargeting.mandal));
        expect(deserializedTargeting.district, equals(originalTargeting.district));
        expect(deserializedTargeting.state, equals(originalTargeting.state));
        expect(deserializedTargeting.scope, equals(originalTargeting.scope));
      });

      test('should handle radius targeting serialization', () {
        // Arrange
        final originalTargeting = GeographicTargeting.forRadius(
          centerPoint: const GeoPoint(23.3441, 85.3096),
          radiusKm: 50.0,
        );

        // Act
        final map = originalTargeting.toMap();
        final deserializedTargeting = GeographicTargeting.fromMap(map);

        // Assert
        expect(deserializedTargeting.centerPoint, equals(originalTargeting.centerPoint));
        expect(deserializedTargeting.radiusKm, equals(originalTargeting.radiusKm));
        expect(deserializedTargeting.scope, equals(originalTargeting.scope));
      });
    });

    group('TargetingScope Extensions', () {
      test('should have correct display names', () {
        expect(TargetingScope.village.displayName, equals('Village'));
        expect(TargetingScope.mandal.displayName, equals('Mandal'));
        expect(TargetingScope.district.displayName, equals('District'));
        expect(TargetingScope.state.displayName, equals('State'));
        expect(TargetingScope.radius.displayName, equals('Radius'));
        expect(TargetingScope.national.displayName, equals('National'));
      });

      test('should have appropriate descriptions', () {
        expect(TargetingScope.village.description, equals('Target specific village'));
        expect(TargetingScope.mandal.description, equals('Target entire mandal/tehsil'));
        expect(TargetingScope.district.description, equals('Target entire district'));
        expect(TargetingScope.state.description, equals('Target entire state'));
        expect(TargetingScope.radius.description, equals('Target within radius'));
        expect(TargetingScope.national.description, equals('Target entire country'));
      });

      test('should have appropriate icons', () {
        expect(TargetingScope.village.icon, equals('🏘️'));
        expect(TargetingScope.mandal.icon, equals('🏙️'));
        expect(TargetingScope.district.icon, equals('🌆'));
        expect(TargetingScope.state.icon, equals('🗺️'));
        expect(TargetingScope.radius.icon, equals('📍'));
        expect(TargetingScope.national.icon, equals('🇮🇳'));
      });
    });
  });
}