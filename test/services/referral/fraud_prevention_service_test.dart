import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:talowa/services/referral/fraud_prevention_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('FraudPreventionService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      FraudPreventionService.setFirestoreInstance(fakeFirestore);
    });

    group('Device Fingerprint', () {
      test('should generate device fingerprint', () async {
        final fingerprint = await FraudPreventionService.generateDeviceFingerprint();
        
        expect(fingerprint.deviceId, isNotEmpty);
        expect(fingerprint.platform, isNotEmpty);
        expect(fingerprint.fingerprint, isNotEmpty);
        expect(fingerprint.createdAt, isNotNull);
      });

      test('should register device fingerprint', () async {
        const userId = 'test_user';
        final fingerprint = await FraudPreventionService.generateDeviceFingerprint();
        
        await FraudPreventionService.registerDeviceFingerprint(userId, fingerprint);
        
        // Verify fingerprint was stored
        final query = await fakeFirestore
            .collection('deviceFingerprints')
            .where('userId', isEqualTo: userId)
            .get();
        
        expect(query.docs.length, equals(1));
        final data = query.docs.first.data();
        expect(data['fingerprint'], equals(fingerprint.fingerprint));
        expect(data['platform'], equals(fingerprint.platform));
      });
    });

    group('Multiple Accounts Detection', () {
      test('should detect multiple accounts on same device', () async {
        final fingerprint = await FraudPreventionService.generateDeviceFingerprint();
        
        // Register multiple users with same fingerprint
        await FraudPreventionService.registerDeviceFingerprint('user1', fingerprint);
        await FraudPreventionService.registerDeviceFingerprint('user2', fingerprint);
        await FraudPreventionService.registerDeviceFingerprint('user3', fingerprint);
        
        final result = await FraudPreventionService.checkMultipleAccounts('user4', fingerprint);
        
        expect(result['isSuspicious'], isTrue);
        expect(result['existingUsers'].length, equals(3));
        expect(result['accountCount'], equals(4));
      });

      test('should not flag single account as suspicious', () async {
        final fingerprint = await FraudPreventionService.generateDeviceFingerprint();
        
        final result = await FraudPreventionService.checkMultipleAccounts('single_user', fingerprint);
        
        expect(result['isSuspicious'], isFalse);
        expect(result['existingUsers'], isEmpty);
        expect(result['accountCount'], equals(1));
      });
    });

    group('Rate Limit Checks', () {
      test('should detect daily rate limit exceeded', () async {
        const userId = 'rate_limit_user';
        final today = DateTime.now();
        
        // Create many referrals for today
        for (int i = 0; i < 12; i++) {
          await fakeFirestore.collection('users').add({
            'referredBy': userId,
            'registeredAt': today.add(Duration(minutes: i * 10)),
          });
        }
        
        final result = await FraudPreventionService.checkReferralRateLimits(userId);
        
        expect(result['isDailyLimitExceeded'], isTrue);
        expect(result['dailyCount'], greaterThanOrEqualTo(10));
      });

      test('should detect hourly rate limit exceeded', () async {
        const userId = 'hourly_limit_user';
        final now = DateTime.now();
        
        // Create many referrals in current hour
        for (int i = 0; i < 5; i++) {
          await fakeFirestore.collection('users').add({
            'referredBy': userId,
            'registeredAt': now.add(Duration(minutes: i * 5)),
          });
        }
        
        final result = await FraudPreventionService.checkReferralRateLimits(userId);
        
        expect(result['isHourlyLimitExceeded'], isTrue);
        expect(result['hourlyCount'], greaterThanOrEqualTo(3));
      });

      test('should pass rate limits for normal usage', () async {
        const userId = 'normal_user';
        final today = DateTime.now();
        
        // Create normal amount of referrals
        for (int i = 0; i < 2; i++) {
          await fakeFirestore.collection('users').add({
            'referredBy': userId,
            'registeredAt': today.add(Duration(hours: i * 2)),
          });
        }
        
        final result = await FraudPreventionService.checkReferralRateLimits(userId);
        
        expect(result['isDailyLimitExceeded'], isFalse);
        expect(result['isHourlyLimitExceeded'], isFalse);
      });
    });

    group('Suspicious Pattern Detection', () {
      test('should detect similar email patterns', () async {
        const userId = 'pattern_user';
        
        // Create users with sequential email patterns
        final emails = ['test1@example.com', 'test2@example.com', 'test3@example.com'];
        for (int i = 0; i < emails.length; i++) {
          await fakeFirestore.collection('users').add({
            'referredBy': userId,
            'email': emails[i],
            'registeredAt': DateTime.now().add(Duration(minutes: i)),
          });
        }
        
        final result = await FraudPreventionService.detectSuspiciousPatterns(userId);
        
        expect(result['isSuspicious'], isTrue);
        expect(result['patterns'], contains('similar_email_patterns'));
      });

      test('should detect rapid sequential registrations', () async {
        const userId = 'rapid_user';
        final now = DateTime.now();
        
        // Create rapid registrations
        for (int i = 0; i < 4; i++) {
          await fakeFirestore.collection('users').add({
            'referredBy': userId,
            'email': 'user$i@example.com',
            'registeredAt': now.add(Duration(minutes: i * 2)), // 2 minutes apart
          });
        }
        
        final result = await FraudPreventionService.detectSuspiciousPatterns(userId);
        
        expect(result['isSuspicious'], isTrue);
        expect(result['patterns'], contains('rapid_sequential_registrations'));
      });

      test('should not flag normal patterns as suspicious', () async {
        const userId = 'normal_pattern_user';
        final now = DateTime.now();
        
        // Create normal registrations
        final emails = ['alice@gmail.com', 'bob@yahoo.com'];
        for (int i = 0; i < emails.length; i++) {
          await fakeFirestore.collection('users').add({
            'referredBy': userId,
            'email': emails[i],
            'registeredAt': now.add(Duration(hours: i * 2)),
          });
        }
        
        final result = await FraudPreventionService.detectSuspiciousPatterns(userId);
        
        expect(result['isSuspicious'], isFalse);
        expect(result['patterns'], isEmpty);
      });
    });

    group('Comprehensive Fraud Check', () {
      test('should perform comprehensive fraud check', () async {
        const userId = 'fraud_check_user';
        
        final result = await FraudPreventionService.performFraudCheck(userId);
        
        expect(result.containsKey('isFraudulent'), isTrue);
        expect(result.containsKey('riskScore'), isTrue);
        expect(result.containsKey('deviceFingerprint'), isTrue);
        expect(result.containsKey('checks'), isTrue);
        
        final checks = result['checks'] as Map<String, dynamic>;
        expect(checks.containsKey('multipleAccounts'), isTrue);
        expect(checks.containsKey('rateLimits'), isTrue);
        expect(checks.containsKey('patterns'), isTrue);
      });

      test('should calculate risk score correctly', () async {
        const userId = 'risk_score_user';

        // Create conditions that should increase risk score
        final fingerprint = await FraudPreventionService.generateDeviceFingerprint();

        // Register multiple accounts to trigger multiple accounts check
        await FraudPreventionService.registerDeviceFingerprint('other1', fingerprint);
        await FraudPreventionService.registerDeviceFingerprint('other2', fingerprint);
        await FraudPreventionService.registerDeviceFingerprint('other3', fingerprint);

        final result = await FraudPreventionService.performFraudCheck(userId);

        // The risk score should be calculated and checks should be present
        expect(result['riskScore'], isA<int>());
        expect(result['checks'], isNotNull);
        expect(result['checks']['multipleAccounts'], isNotNull);
        expect(result['checks']['rateLimits'], isNotNull);
        expect(result['checks']['patterns'], isNotNull);
      });
    });

    group('User Blocking', () {
      test('should block user for fraudulent activity', () async {
        const userId = 'block_user';
        const reason = 'Multiple accounts detected';
        const adminUserId = 'admin_123';
        
        // Setup user
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Block User',
          'isBlocked': false,
        });
        
        await FraudPreventionService.blockUser(userId, reason, adminUserId: adminUserId);
        
        // Verify user was blocked
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        expect(userData['isBlocked'], isTrue);
        expect(userData['blockReason'], equals(reason));
        expect(userData['blockedBy'], equals(adminUserId));
        
        // Verify block record was created
        final blockQuery = await fakeFirestore
            .collection('userBlocks')
            .where('userId', isEqualTo: userId)
            .get();
        expect(blockQuery.docs.length, equals(1));
      });

      test('should unblock user', () async {
        const userId = 'unblock_user';
        const adminUserId = 'admin_123';
        
        // Setup blocked user
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Unblock User',
          'isBlocked': true,
          'blockReason': 'Test block',
        });
        
        await FraudPreventionService.unblockUser(userId, adminUserId: adminUserId);
        
        // Verify user was unblocked
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        expect(userData['isBlocked'], isFalse);
        expect(userData.containsKey('blockReason'), isFalse);
        expect(userData['unblockedBy'], equals(adminUserId));
      });
    });

    group('Fraud History', () {
      test('should get user fraud history', () async {
        const userId = 'history_user';
        
        // Create suspicious activities
        await fakeFirestore.collection('suspiciousActivities').add({
          'userId': userId,
          'activityType': 'multiple_accounts',
          'details': {'test': 'data'},
          'timestamp': DateTime.now(),
          'resolved': false,
        });
        
        await fakeFirestore.collection('suspiciousActivities').add({
          'userId': userId,
          'activityType': 'rate_limit_exceeded',
          'details': {'test': 'data2'},
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
          'resolved': false,
        });
        
        final history = await FraudPreventionService.getUserFraudHistory(userId);
        
        expect(history.length, equals(2));
        expect(history[0]['activityType'], equals('multiple_accounts'));
        expect(history[1]['activityType'], equals('rate_limit_exceeded'));
      });

      test('should return empty history for clean user', () async {
        const userId = 'clean_user';
        
        final history = await FraudPreventionService.getUserFraudHistory(userId);
        
        expect(history, isEmpty);
      });
    });

    group('Fraud Statistics', () {
      test('should get fraud statistics', () async {
        final today = DateTime.now();
        
        // Create suspicious activities
        await fakeFirestore.collection('suspiciousActivities').add({
          'userId': 'user1',
          'activityType': 'multiple_accounts',
          'timestamp': today,
        });
        
        await fakeFirestore.collection('suspiciousActivities').add({
          'userId': 'user2',
          'activityType': 'rate_limit_exceeded',
          'timestamp': today,
        });
        
        // Create blocked users
        await fakeFirestore.collection('users').add({
          'isBlocked': true,
          'blockReason': 'Fraud',
        });
        
        final stats = await FraudPreventionService.getFraudStatistics();
        
        expect(stats['todaySuspiciousActivities'], equals(2));
        expect(stats['totalBlockedUsers'], equals(1));
        expect(stats['activitiesByType']['multiple_accounts'], equals(1));
        expect(stats['activitiesByType']['rate_limit_exceeded'], equals(1));
      });
    });

    group('Error Handling', () {
      test('should create FraudPreventionException correctly', () {
        const message = 'Test fraud prevention error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};

        final exception = FraudPreventionException(message, code, context);

        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test fraud prevention error';
        final exception = const FraudPreventionException(message);

        expect(exception.code, equals('FRAUD_PREVENTION_FAILED'));
        expect(exception.context, isNull);
      });
    });

    group('DeviceFingerprint Model', () {
      test('should convert to and from map correctly', () {
        final fingerprint = DeviceFingerprint(
          deviceId: 'test_device',
          platform: 'test_platform',
          model: 'test_model',
          osVersion: '1.0',
          appVersion: '1.0.0',
          fingerprint: 'test_fingerprint',
          createdAt: DateTime.now(),
        );

        final map = fingerprint.toMap();
        final restored = DeviceFingerprint.fromMap(map);

        expect(restored.deviceId, equals(fingerprint.deviceId));
        expect(restored.platform, equals(fingerprint.platform));
        expect(restored.model, equals(fingerprint.model));
        expect(restored.osVersion, equals(fingerprint.osVersion));
        expect(restored.appVersion, equals(fingerprint.appVersion));
        expect(restored.fingerprint, equals(fingerprint.fingerprint));
      });
    });

    group('Edge Cases', () {
      test('should handle empty referral list', () async {
        const userId = 'empty_referrals_user';
        
        final rateLimitResult = await FraudPreventionService.checkReferralRateLimits(userId);
        final patternResult = await FraudPreventionService.detectSuspiciousPatterns(userId);
        
        expect(rateLimitResult['isDailyLimitExceeded'], isFalse);
        expect(rateLimitResult['isHourlyLimitExceeded'], isFalse);
        expect(patternResult['isSuspicious'], isFalse);
      });

      test('should handle users with no email addresses', () async {
        const userId = 'no_email_user';
        
        // Create referrals without email
        await fakeFirestore.collection('users').add({
          'referredBy': userId,
          'registeredAt': DateTime.now(),
          // No email field
        });
        
        final result = await FraudPreventionService.detectSuspiciousPatterns(userId);
        
        expect(result['isSuspicious'], isFalse);
      });
    });
  });
}
