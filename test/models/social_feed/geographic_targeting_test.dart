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
          village: 'à¤°à¤¾à¤®à¤ªà¥à¤°',
          mandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Assert
        expect(targeting.village, equals('à¤°à¤¾à¤®à¤ªà¥à¤°'));
        expect(targeting.mandal, equals('à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾'));
        expect(targeting.district, equals('à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚'));
        expect(targeting.state, equals('à¤à¤¾à¤°à¤–à¤‚à¤¡'));
        expect(targeting.scope, equals(TargetingScope.village));
      });

      test('should create mandal-level targeting', () {
        // Act
        final targeting = GeographicTargeting.forMandal(
          mandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Assert
        expect(targeting.village, isNull);
        expect(targeting.mandal, equals('à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾'));
        expect(targeting.district, equals('à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚'));
        expect(targeting.state, equals('à¤à¤¾à¤°à¤–à¤‚à¤¡'));
        expect(targeting.scope, equals(TargetingScope.mandal));
      });

      test('should create district-level targeting', () {
        // Act
        final targeting = GeographicTargeting.forDistrict(
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Assert
        expect(targeting.village, isNull);
        expect(targeting.mandal, isNull);
        expect(targeting.district, equals('à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚'));
        expect(targeting.state, equals('à¤à¤¾à¤°à¤–à¤‚à¤¡'));
        expect(targeting.scope, equals(TargetingScope.district));
      });

      test('should create state-level targeting', () {
        // Act
        final targeting = GeographicTargeting.forState(
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Assert
        expect(targeting.village, isNull);
        expect(targeting.mandal, isNull);
        expect(targeting.district, isNull);
        expect(targeting.state, equals('à¤à¤¾à¤°à¤–à¤‚à¤¡'));
        expect(targeting.scope, equals(TargetingScope.state));
      });

      test('should create radius-based targeting', () {
        // Arrange
        const centerPoint = GeoPoint(23.3441, 85.3096); // Ranchi coordinates
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
          village: 'à¤°à¤¾à¤®à¤ªà¥à¤°',
          mandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'à¤°à¤¾à¤®à¤ªà¥à¤°',
          userMandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          userDistrict: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          userState: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        ), isTrue);

        expect(targeting.matchesUserLocation(
          userVillage: 'à¤…à¤¨à¥à¤¯ à¤—à¤¾à¤‚à¤µ',
          userMandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          userDistrict: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          userState: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        ), isFalse);
      });

      test('should match mandal-level targeting', () {
        // Arrange
        final targeting = GeographicTargeting.forMandal(
          mandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤—à¤¾à¤‚à¤µ',
          userMandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          userDistrict: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          userState: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        ), isTrue);

        expect(targeting.matchesUserLocation(
          userVillage: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤—à¤¾à¤‚à¤µ',
          userMandal: 'à¤…à¤¨à¥à¤¯ à¤®à¤‚à¤¡à¤²',
          userDistrict: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          userState: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        ), isFalse);
      });

      test('should match district-level targeting', () {
        // Arrange
        final targeting = GeographicTargeting.forDistrict(
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤—à¤¾à¤‚à¤µ',
          userMandal: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤®à¤‚à¤¡à¤²',
          userDistrict: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          userState: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        ), isTrue);

        expect(targeting.matchesUserLocation(
          userVillage: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤—à¤¾à¤‚à¤µ',
          userMandal: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤®à¤‚à¤¡à¤²',
          userDistrict: 'à¤…à¤¨à¥à¤¯ à¤œà¤¿à¤²à¤¾',
          userState: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        ), isFalse);
      });

      test('should match state-level targeting', () {
        // Arrange
        final targeting = GeographicTargeting.forState(
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤—à¤¾à¤‚à¤µ',
          userMandal: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤®à¤‚à¤¡à¤²',
          userDistrict: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤œà¤¿à¤²à¤¾',
          userState: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        ), isTrue);

        expect(targeting.matchesUserLocation(
          userVillage: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤—à¤¾à¤‚à¤µ',
          userMandal: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤®à¤‚à¤¡à¤²',
          userDistrict: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤œà¤¿à¤²à¤¾',
          userState: 'à¤¬à¤¿à¤¹à¤¾à¤°',
        ), isFalse);
      });

      test('should match national targeting for all users', () {
        // Arrange
        final targeting = GeographicTargeting.forNational();

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userVillage: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤—à¤¾à¤‚à¤µ',
          userMandal: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤®à¤‚à¤¡à¤²',
          userDistrict: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤œà¤¿à¤²à¤¾',
          userState: 'à¤•à¥‹à¤ˆ à¤­à¥€ à¤°à¤¾à¤œà¥à¤¯',
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
        const centerPoint = GeoPoint(23.3441, 85.3096); // Ranchi
        final targeting = GeographicTargeting.forRadius(
          centerPoint: centerPoint,
          radiusKm: 100.0,
        );

        // Nearby location (approximately 50km from Ranchi)
        const nearbyLocation = GeoPoint(23.8103, 85.8372);

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userLocation: nearbyLocation,
        ), isTrue);
      });

      test('should not match locations outside radius', () {
        // Arrange
        const centerPoint = GeoPoint(23.3441, 85.3096); // Ranchi
        final targeting = GeographicTargeting.forRadius(
          centerPoint: centerPoint,
          radiusKm: 50.0,
        );

        // Far location (Delhi - much farther than 50km)
        const farLocation = GeoPoint(28.6139, 77.2090);

        // Act & Assert
        expect(targeting.matchesUserLocation(
          userLocation: farLocation,
        ), isFalse);
      });

      test('should handle missing location data for radius targeting', () {
        // Arrange
        const centerPoint = GeoPoint(23.3441, 85.3096);
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
          village: 'à¤°à¤¾à¤®à¤ªà¥à¤°',
          mandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );
        expect(villageTargeting.getDisplayString(), equals('à¤°à¤¾à¤®à¤ªà¥à¤°'));

        final mandalTargeting = GeographicTargeting.forMandal(
          mandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );
        expect(mandalTargeting.getDisplayString(), equals('à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾'));

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
          village: 'à¤°à¤¾à¤®à¤ªà¥à¤°',
          mandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Act
        final hierarchical = targeting.getHierarchicalString();

        // Assert
        expect(hierarchical, equals('à¤°à¤¾à¤®à¤ªà¥à¤°, à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾, à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚, à¤à¤¾à¤°à¤–à¤‚à¤¡'));
      });

      test('should handle partial hierarchical data', () {
        // Arrange
        final targeting = GeographicTargeting.forDistrict(
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Act
        final hierarchical = targeting.getHierarchicalString();

        // Assert
        expect(hierarchical, equals('à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚, à¤à¤¾à¤°à¤–à¤‚à¤¡'));
      });
    });

    group('Validation', () {
      test('should validate village targeting successfully', () {
        // Arrange
        final targeting = GeographicTargeting.forVillage(
          village: 'à¤°à¤¾à¤®à¤ªà¥à¤°',
          mandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
        );

        // Act
        final validation = targeting.validate();

        // Assert
        expect(validation, isNull);
      });

      test('should fail validation for incomplete village targeting', () {
        // Arrange
        const targeting = GeographicTargeting(
          village: 'à¤°à¤¾à¤®à¤ªà¥à¤°',
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
        const targeting = GeographicTargeting(
          centerPoint: GeoPoint(23.3441, 85.3096),
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
        const targeting = GeographicTargeting(
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
          village: 'à¤°à¤¾à¤®à¤ªà¥à¤°',
          mandal: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾',
          district: 'à¤¸à¤°à¤¾à¤¯à¤•à¥‡à¤²à¤¾ à¤–à¤°à¤¸à¤¾à¤µà¤¾à¤‚',
          state: 'à¤à¤¾à¤°à¤–à¤‚à¤¡',
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
        expect(TargetingScope.village.icon, equals('ðŸ˜ï¸'));
        expect(TargetingScope.mandal.icon, equals('ðŸ™ï¸'));
        expect(TargetingScope.district.icon, equals('ðŸŒ†'));
        expect(TargetingScope.state.icon, equals('ðŸ—ºï¸'));
        expect(TargetingScope.radius.icon, equals('ðŸ“'));
        expect(TargetingScope.national.icon, equals('ðŸ‡®ðŸ‡³'));
      });
    });
  });
}
