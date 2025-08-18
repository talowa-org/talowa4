import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/services/referral/referral_code_service.dart';
import 'package:talowa/services/referral/referral_tracking_service.dart';
import 'package:talowa/services/referral/payment_integration_service.dart';
import 'package:talowa/services/referral/fraud_prevention_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Referral System Security Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      
      // Set up all services with fake firestore
      ReferralCodeService.setFirestoreInstance(fakeFirestore);
      ReferralTrackingService.setFirestoreInstance(fakeFirestore);
      PaymentIntegrationService.setFirestoreInstance(fakeFirestore);
      FraudPreventionService.setFirestoreInstance(fakeFirestore);
    });

    group('Fraud Prevention Tests', () {
      test('detects and prevents self-referral attempts', () async {
        const userId = 'selfref_user';
        const userCode = 'TALSELF01';
        
        // Set up user with referral code
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Self Referral User',
          'email': 'selfref@example.com',
          'referralCode': userCode,
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });
        
        await fakeFirestore.collection('referralCodes').doc(userCode).set({
          'userId': userId,
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });

        // Attempt self-referral
        expect(
          () => ReferralTrackingService.recordReferralRelationship(
            newUserId: userId,
            referralCode: userCode,
          ),
          throwsA(predicate((e) => 
            e.toString().contains('self-referral') || 
            e.toString().contains('cannot refer yourself')
          )),
        );
        
        // Verify fraud attempt was logged
        final fraudLogs = await fakeFirestore
            .collection('fraud_logs')
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'self_referral_attempt')
            .get();
        
        expect(fraudLogs.docs.length, equals(1));
      });

      test('detects multiple registrations from same device', () async {
        const deviceId = 'device123';
        const ipAddress = '192.168.1.100';
        
        // Create multiple users from same device
        final userIds = ['device_user1', 'device_user2', 'device_user3'];
        
        for (final userId in userIds) {
          await fakeFirestore.collection('users').doc(userId).set({
            'fullName': 'Device User',
            'email': '$userId@example.com',
            'deviceId': deviceId,
            'ipAddress': ipAddress,
            'membershipPaid': false,
            'registrationDate': Timestamp.fromDate(DateTime.now()),
          });
        }
        
        // Check for suspicious device activity
        final suspiciousActivity = await FraudPreventionService.detectSuspiciousDeviceActivity(deviceId);
        
        expect(suspiciousActivity['isSuspicious'], isTrue);
        expect(suspiciousActivity['userCount'], equals(3));
        expect(suspiciousActivity['riskLevel'], equals('high'));
        
        // Verify fraud detection was logged
        final fraudLogs = await fakeFirestore
            .collection('fraud_logs')
            .where('deviceId', isEqualTo: deviceId)
            .where('type', isEqualTo: 'multiple_device_registrations')
            .get();
        
        expect(fraudLogs.docs.length, greaterThan(0));
      });

      test('detects suspicious referral patterns', () async {
        const referrerId = 'suspicious_referrer';
        const referrerCode = 'TALSUS001';
        
        // Set up referrer
        await fakeFirestore.collection('users').doc(referrerId).set({
          'fullName': 'Suspicious Referrer',
          'email': 'suspicious@example.com',
          'referralCode': referrerCode,
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });
        
        await fakeFirestore.collection('referralCodes').doc(referrerCode).set({
          'userId': referrerId,
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        
        // Create many referrals in short time period (suspicious pattern)
        final now = DateTime.now();
        for (int i = 0; i < 50; i++) {
          final userId = 'rapid_user$i';
          
          await fakeFirestore.collection('users').doc(userId).set({
            'fullName': 'Rapid User $i',
            'email': 'rapid$i@example.com',
            'referredBy': referrerId,
            'membershipPaid': false,
            'referralStatus': 'pending',
            'registrationDate': Timestamp.fromDate(now.add(Duration(minutes: i))),
          });
        }
        
        // Analyze referral patterns
        final patternAnalysis = await FraudPreventionService.analyzeReferralPatterns(referrerId);
        
        expect(patternAnalysis['isSuspicious'], isTrue);
        expect(patternAnalysis['rapidReferrals'], equals(50));
        expect(patternAnalysis['riskScore'], greaterThan(80));
        
        // Verify pattern was flagged
        final fraudLogs = await fakeFirestore
            .collection('fraud_logs')
            .where('userId', isEqualTo: referrerId)
            .where('type', isEqualTo: 'suspicious_referral_pattern')
            .get();
        
        expect(fraudLogs.docs.length, greaterThan(0));
      });

      test('validates payment authenticity', () async {
        const userId = 'payment_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Payment User',
          'email': 'payment@example.com',
          'membershipPaid': false,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        // Test invalid payment scenarios
        final invalidPayments = [
          // Negative amount
          {'amount': -99.99, 'currency': 'USD'},
          // Invalid currency
          {'amount': 99.99, 'currency': 'INVALID'},
          // Zero amount
          {'amount': 0.0, 'currency': 'USD'},
          // Extremely high amount (potential fraud)
          {'amount': 999999.99, 'currency': 'USD'},
        ];
        
        for (final payment in invalidPayments) {
          expect(
            () => PaymentIntegrationService.processPaymentSuccess(
              userId: userId,
              paymentId: 'invalid_${payment['amount']}_${payment['currency']}',
              amount: payment['amount'] as double,
              currency: payment['currency'] as String,
            ),
            throwsA(isA<Exception>()),
          );
        }
        
        // Verify fraud attempts were logged
        final fraudLogs = await fakeFirestore
            .collection('fraud_logs')
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'invalid_payment_attempt')
            .get();
        
        expect(fraudLogs.docs.length, greaterThan(0));
      });
    });

    group('Access Control Tests', () {
      test('enforces role-based permissions', () async {
        const memberId = 'member_user';
        const organizerId = 'organizer_user';
        
        // Set up users with different roles
        await fakeFirestore.collection('users').doc(memberId).set({
          'fullName': 'Member User',
          'email': 'member@example.com',
          'currentRole': 'member',
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });
        
        await fakeFirestore.collection('users').doc(organizerId).set({
          'fullName': 'Organizer User',
          'email': 'organizer@example.com',
          'currentRole': 'organizer',
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        // Test member trying to access organizer features
        expect(
          () => FraudPreventionService.validateRolePermissions(
            userId: memberId,
            requiredRole: 'organizer',
            action: 'view_team_analytics',
          ),
          throwsA(predicate((e) => 
            e.toString().contains('insufficient permissions') ||
            e.toString().contains('access denied')
          )),
        );
        
        // Test organizer accessing valid features
        expect(
          () => FraudPreventionService.validateRolePermissions(
            userId: organizerId,
            requiredRole: 'organizer',
            action: 'view_team_analytics',
          ),
          returnsNormally,
        );
      });

      test('prevents unauthorized data access', () async {
        const userId1 = 'user1';
        const userId2 = 'user2';
        
        // Set up users
        await fakeFirestore.collection('users').doc(userId1).set({
          'fullName': 'User 1',
          'email': 'user1@example.com',
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });
        
        await fakeFirestore.collection('users').doc(userId2).set({
          'fullName': 'User 2',
          'email': 'user2@example.com',
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        // Test user1 trying to access user2's data
        expect(
          () => FraudPreventionService.validateDataAccess(
            requestingUserId: userId1,
            targetUserId: userId2,
            dataType: 'referral_statistics',
          ),
          throwsA(predicate((e) => 
            e.toString().contains('unauthorized access') ||
            e.toString().contains('permission denied')
          )),
        );
        
        // Test user accessing their own data
        expect(
          () => FraudPreventionService.validateDataAccess(
            requestingUserId: userId1,
            targetUserId: userId1,
            dataType: 'referral_statistics',
          ),
          returnsNormally,
        );
      });
    });

    group('Rate Limiting Tests', () {
      test('enforces referral code generation rate limits', () async {
        const userId = 'rate_limit_user';
        
        // Generate codes rapidly to trigger rate limit
        final futures = <Future<String>>[];
        for (int i = 0; i < 100; i++) {
          futures.add(ReferralCodeService.generateReferralCode('$userId$i'));
        }
        
        // Some requests should be rate limited
        final results = await Future.wait(futures, eagerError: false);
        
        // Count successful vs failed requests
        int successCount = 0;
        int failureCount = 0;
        
        for (final result in results) {
          if (result is String && result.isNotEmpty) {
            successCount++;
          } else {
            failureCount++;
          }
        }
        
        // Verify rate limiting is working
        expect(failureCount, greaterThan(0));
        
        // Verify rate limit logs
        final rateLimitLogs = await fakeFirestore
            .collection('rate_limit_logs')
            .where('type', isEqualTo: 'referral_code_generation')
            .get();
        
        expect(rateLimitLogs.docs.length, greaterThan(0));
      });

      test('enforces payment processing rate limits', () async {
        const userId = 'payment_rate_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Payment Rate User',
          'email': 'paymentrate@example.com',
          'membershipPaid': false,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        // Attempt rapid payment processing
        final futures = <Future<void>>[];
        for (int i = 0; i < 20; i++) {
          futures.add(
            PaymentIntegrationService.processPaymentSuccess(
              userId: userId,
              paymentId: 'rapid_payment_$i',
              amount: 99.99,
              currency: 'USD',
            ).catchError((e) => null) // Catch rate limit errors
          );
        }
        
        await Future.wait(futures);
        
        // Verify rate limiting was applied
        final rateLimitLogs = await fakeFirestore
            .collection('rate_limit_logs')
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'payment_processing')
            .get();
        
        expect(rateLimitLogs.docs.length, greaterThan(0));
      });
    });

    group('Data Integrity Tests', () {
      test('prevents referral chain corruption', () async {
        // Set up valid referral chain
        const rootUserId = 'root_user';
        const level1UserId = 'level1_user';
        const level2UserId = 'level2_user';
        
        await fakeFirestore.collection('users').doc(rootUserId).set({
          'fullName': 'Root User',
          'email': 'root@example.com',
          'referralCode': 'TALROOT01',
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });
        
        await fakeFirestore.collection('users').doc(level1UserId).set({
          'fullName': 'Level 1 User',
          'email': 'level1@example.com',
          'referredBy': rootUserId,
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });
        
        await fakeFirestore.collection('users').doc(level2UserId).set({
          'fullName': 'Level 2 User',
          'email': 'level2@example.com',
          'referredBy': level1UserId,
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        // Attempt to create circular reference (should be prevented)
        expect(
          () => fakeFirestore.collection('users').doc(rootUserId).update({
            'referredBy': level2UserId, // This would create a cycle
          }),
          throwsA(isA<Exception>()),
        );
        
        // Verify chain integrity
        final integrityCheck = await FraudPreventionService.validateReferralChainIntegrity(level2UserId);
        expect(integrityCheck['isValid'], isTrue);
        expect(integrityCheck['chainDepth'], equals(2));
        expect(integrityCheck['hasCircularReference'], isFalse);
      });

      test('validates referral statistics consistency', () async {
        const referrerId = 'stats_referrer';
        
        // Set up referrer with inconsistent statistics
        await fakeFirestore.collection('users').doc(referrerId).set({
          'fullName': 'Stats Referrer',
          'email': 'stats@example.com',
          'directReferrals': 10,
          'activeDirectReferrals': 15, // Inconsistent: more active than total
          'teamSize': 5, // Inconsistent: smaller than direct referrals
          'activeTeamSize': 20, // Inconsistent: larger than team size
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });
        
        // Validate statistics
        final validation = await FraudPreventionService.validateReferralStatistics(referrerId);
        
        expect(validation['isValid'], isFalse);
        expect(validation['inconsistencies'], isNotEmpty);
        expect(validation['inconsistencies'], contains('active_exceeds_total'));
        expect(validation['inconsistencies'], contains('team_size_mismatch'));
        
        // Verify validation failure was logged
        final validationLogs = await fakeFirestore
            .collection('validation_logs')
            .where('userId', isEqualTo: referrerId)
            .where('type', isEqualTo: 'statistics_inconsistency')
            .get();
        
        expect(validationLogs.docs.length, greaterThan(0));
      });
    });

    group('Input Validation Tests', () {
      test('validates referral code format', () async {
        final invalidCodes = [
          'INVALID', // Too short
          'TOOLONGCODE123', // Too long
          'TAL123456', // Contains numbers that look like letters
          'tal123abc', // Lowercase
          'TAL@#$%^&', // Special characters
          '', // Empty
          'TALO0O0O0', // Confusing characters
        ];
        
        for (final code in invalidCodes) {
          expect(
            () => ReferralTrackingService.recordReferralRelationship(
              newUserId: 'test_user',
              referralCode: code,
            ),
            throwsA(predicate((e) => 
              e.toString().contains('invalid referral code') ||
              e.toString().contains('code format')
            )),
          );
        }
      });

      test('validates user input sanitization', () async {
        final maliciousInputs = [
          '<script>alert("xss")</script>',
          'DROP TABLE users;',
          '../../etc/passwd',
          '${DateTime.now()}', // Template injection
          'null\x00byte',
        ];
        
        for (final input in maliciousInputs) {
          expect(
            () => fakeFirestore.collection('users').doc('test_user').set({
              'fullName': input,
              'email': 'test@example.com',
              'membershipPaid': false,
              'registrationDate': Timestamp.fromDate(DateTime.now()),
            }),
            throwsA(isA<Exception>()),
          );
        }
      });
    });
  });
}
