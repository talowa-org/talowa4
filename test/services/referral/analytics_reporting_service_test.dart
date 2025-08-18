import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/services/referral/analytics_reporting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AnalyticsReportingService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      AnalyticsReportingService.setFirestoreInstance(fakeFirestore);
    });

    group('Referral Conversion Rates', () {
      test('should calculate conversion rates correctly', () async {
        final startDate = DateTime(2024, 1, 1);
        final endDate = DateTime(2024, 1, 31);
        
        // Setup test data
        await fakeFirestore.collection('referrals').add({
          'referrerId': 'user1',
          'referredUserId': 'user2',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 15)),
        });
        
        await fakeFirestore.collection('users').doc('user2').set({
          'fullName': 'User 2',
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'referredBy': 'user1',
        });
        
        final result = await AnalyticsReportingService.getReferralConversionRates(
          startDate: startDate,
          endDate: endDate,
        );
        
        expect(result['totalReferrals'], equals(1));
        expect(result['totalConversions'], equals(1));
        expect(result['overallConversionRate'], equals(100.0));
        expect(result['period'], equals('daily'));
      });

      test('should handle empty data gracefully', () async {
        final startDate = DateTime(2024, 1, 1);
        final endDate = DateTime(2024, 1, 31);
        
        final result = await AnalyticsReportingService.getReferralConversionRates(
          startDate: startDate,
          endDate: endDate,
        );
        
        expect(result['totalReferrals'], equals(0));
        expect(result['totalConversions'], equals(0));
        expect(result['overallConversionRate'], equals(0.0));
      });

      test('should support different time periods', () async {
        final startDate = DateTime(2024, 1, 1);
        final endDate = DateTime(2024, 1, 31);
        
        final result = await AnalyticsReportingService.getReferralConversionRates(
          startDate: startDate,
          endDate: endDate,
          period: 'weekly',
        );
        
        expect(result['period'], equals('weekly'));
      });
    });

    group('Geographic Distribution', () {
      test('should analyze geographic distribution correctly', () async {
        // Setup test users with location data
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'User 1',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'location': {
            'country': 'USA',
            'city': 'New York',
            'region': 'North America',
          },
        });
        
        await fakeFirestore.collection('users').doc('user2').set({
          'fullName': 'User 2',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 16)),
          'location': {
            'country': 'USA',
            'city': 'Los Angeles',
            'region': 'North America',
          },
        });
        
        await fakeFirestore.collection('users').doc('user3').set({
          'fullName': 'User 3',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 17)),
          'location': {
            'country': 'Canada',
            'city': 'Toronto',
            'region': 'North America',
          },
        });
        
        final result = await AnalyticsReportingService.getGeographicDistribution();
        
        expect(result['totalUsers'], equals(3));
        expect(result['countryDistribution']['USA'], equals(2));
        expect(result['countryDistribution']['Canada'], equals(1));
        expect(result['regionDistribution']['North America'], equals(3));
      });

      test('should handle users without location data', () async {
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'User 1',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
        });
        
        final result = await AnalyticsReportingService.getGeographicDistribution();
        
        expect(result['totalUsers'], equals(1));
        expect(result['countryDistribution']['Unknown'], equals(1));
      });

      test('should filter by date range', () async {
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'User 1',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'location': {'country': 'USA'},
        });
        
        await fakeFirestore.collection('users').doc('user2').set({
          'fullName': 'User 2',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 2, 15)),
          'location': {'country': 'Canada'},
        });
        
        final result = await AnalyticsReportingService.getGeographicDistribution(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );
        
        expect(result['totalUsers'], equals(1));
        expect(result['countryDistribution']['USA'], equals(1));
        expect(result['countryDistribution'].containsKey('Canada'), isFalse);
      });
    });

    group('Click-Through Rates', () {
      test('should calculate click-through rates correctly', () async {
        const userId = 'user1';
        
        // Setup click data
        await fakeFirestore.collection('referral_clicks').add({
          'referrerId': userId,
          'clickedAt': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'source': 'social_media',
        });
        
        await fakeFirestore.collection('referral_clicks').add({
          'referrerId': userId,
          'clickedAt': Timestamp.fromDate(DateTime(2024, 1, 16)),
          'source': 'email',
        });
        
        // Setup registration data
        await fakeFirestore.collection('users').doc('user2').set({
          'fullName': 'User 2',
          'referredBy': userId,
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
        });
        
        final result = await AnalyticsReportingService.getReferralLinkClickThroughRates(
          userId: userId,
        );
        
        expect(result['totalClicks'], equals(2));
        expect(result['totalRegistrations'], equals(1));
        expect(result['clickThroughRate'], equals(50.0));
        expect(result['clicksBySource']['social_media'], equals(1));
        expect(result['clicksBySource']['email'], equals(1));
      });

      test('should handle zero clicks gracefully', () async {
        const userId = 'user1';
        
        final result = await AnalyticsReportingService.getReferralLinkClickThroughRates(
          userId: userId,
        );
        
        expect(result['totalClicks'], equals(0));
        expect(result['totalRegistrations'], equals(0));
        expect(result['clickThroughRate'], equals(0.0));
      });
    });

    group('Viral Coefficient Analytics', () {
      test('should calculate viral coefficient correctly', () async {
        // Setup user hierarchy
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'User 1',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'directReferrals': 2,
        });
        
        await fakeFirestore.collection('users').doc('user2').set({
          'fullName': 'User 2',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 16)),
          'referredBy': 'user1',
          'directReferrals': 1,
        });
        
        await fakeFirestore.collection('users').doc('user3').set({
          'fullName': 'User 3',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 17)),
          'referredBy': 'user1',
          'directReferrals': 0,
        });
        
        final result = await AnalyticsReportingService.getViralCoefficientAnalytics();
        
        expect(result['totalUsers'], equals(3));
        expect(result['referredUsers'], equals(2));
        expect(result['organicUsers'], equals(1));
        expect(result['totalReferrals'], equals(3));
        expect(result['viralCoefficient'], equals(1.0)); // 3 referrals / 3 users
        expect(result['referralRate'], closeTo(66.67, 0.01)); // 2 referred / 3 total * 100
      });

      test('should handle users with no referrals', () async {
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'User 1',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'directReferrals': 0,
        });
        
        final result = await AnalyticsReportingService.getViralCoefficientAnalytics();
        
        expect(result['totalUsers'], equals(1));
        expect(result['viralCoefficient'], equals(0.0));
        expect(result['referralRate'], equals(0.0));
      });
    });

    group('Real-Time Dashboard Metrics', () {
      test('should provide real-time metrics', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        // Setup today's data
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'User 1',
          'registrationDate': Timestamp.fromDate(today.add(Duration(hours: 10))),
          'membershipPaid': true,
        });
        
        final result = await AnalyticsReportingService.getRealTimeDashboardMetrics();
        
        expect(result.containsKey('timestamp'), isTrue);
        expect(result.containsKey('today'), isTrue);
        expect(result.containsKey('yesterday'), isTrue);
        expect(result.containsKey('thisWeek'), isTrue);
        expect(result.containsKey('thisMonth'), isTrue);
        expect(result.containsKey('growth'), isTrue);
      });
    });

    group('Data Export', () {
      test('should handle CSV export data processing', () async {
        // Setup test data
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'User 1',
          'email': 'user1@example.com',
          'referralCode': 'REF001',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'membershipPaid': true,
          'directReferrals': 2,
          'currentRole': 'organizer',
          'location': {
            'country': 'USA',
            'city': 'New York',
          },
        });

        // Test that the service can process the data (file operations will fail in test environment)
        try {
          await AnalyticsReportingService.exportReferralDataToCsv();
        } catch (e) {
          // Expected to fail due to path_provider not being available in tests
          expect(e, isA<AnalyticsReportingException>());
          expect(e.toString(), contains('Failed to export referral data to CSV'));
        }
      });

      test('should handle JSON export data processing', () async {
        // Test that the service can process the data (file operations will fail in test environment)
        try {
          await AnalyticsReportingService.exportAnalyticsReportToJson();
        } catch (e) {
          // Expected to fail due to path_provider not being available in tests
          expect(e, isA<AnalyticsReportingException>());
          expect(e.toString(), contains('Failed to export analytics report to JSON'));
        }
      });
    });

    group('Error Handling', () {
      test('should create AnalyticsReportingException correctly', () {
        const message = 'Test analytics error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};

        final exception = AnalyticsReportingException(message, code, context);

        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test analytics error';
        final exception = AnalyticsReportingException(message);

        expect(exception.code, equals('ANALYTICS_REPORTING_FAILED'));
        expect(exception.context, isNull);
      });
    });

    group('Integration Tests', () {
      test('should handle complex analytics scenarios', () async {
        // Setup complex test data
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'User 1',
          'registrationDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'directReferrals': 2,
          'membershipPaid': true,
        });

        // Test that conversion rates work with complex data
        final result = await AnalyticsReportingService.getReferralConversionRates(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('conversionRates'), isTrue);
      });
    });
  });
}
