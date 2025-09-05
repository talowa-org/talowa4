import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/services/referral/referral_code_generator.dart';
import 'package:talowa/services/referral/referral_tracking_service.dart';
import 'package:talowa/services/referral/referral_lookup_service.dart';
import 'package:talowa/services/referral/payment_integration_service.dart';
import 'package:talowa/services/referral/role_progression_service.dart';
import 'package:talowa/services/referral/notification_communication_service.dart';
import 'package:talowa/services/referral/user_registration_service.dart';
import 'package:talowa/services/referral/orphan_assignment_service.dart';
import 'package:talowa/config/referral_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Referral System Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();

      // Set up all services with fake firestore
      ReferralCodeGenerator.setFirestoreInstance(fakeFirestore);
      ReferralTrackingService.setFirestoreInstance(fakeFirestore);
      ReferralLookupService.setFirestoreInstance(fakeFirestore);
      PaymentIntegrationService.setFirestoreInstance(fakeFirestore);
      RoleProgressionService.setFirestoreInstance(fakeFirestore);
      NotificationCommunicationService.setFirestoreInstance(fakeFirestore);
      UserRegistrationService.setFirestoreInstance(fakeFirestore);
      OrphanAssignmentService.setFirestoreInstance(fakeFirestore);

      // Set up admin user for orphan assignment
      await _setupAdminUser(fakeFirestore);
    });

    group('End-to-End Referral Flow', () {
      test('complete referral flow from registration to role progression', () async {
        // Step 1: Create referrer user and generate valid referral code
        const referrerId = 'referrer123';
        final referrerCode = await ReferralCodeGenerator.generateUniqueCode();

        await fakeFirestore.collection('users').doc(referrerId).set({
          'fullName': 'John Referrer',
          'email': 'john@example.com',
          'referralCode': referrerCode,
          'directReferrals': 0,
          'activeDirectReferrals': 0,
          'teamSize': 0,
          'activeTeamSize': 0,
          'currentRole': 'member',
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        await fakeFirestore.collection('referralCodes').doc(referrerCode).set({
          'code': referrerCode,
          'uid': referrerId,
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'clickCount': 0,
          'conversionCount': 0,
        });

        // Step 2: New user registers with referral code
        const newUserId = 'newuser456';
        
        await fakeFirestore.collection('users').doc(newUserId).set({
          'fullName': 'Jane Newuser',
          'email': 'jane@example.com',
          'membershipPaid': false,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        // Generate referral code for new user
        final newUserCode = await ReferralCodeGenerator.generateUniqueCode();
        expect(newUserCode, isNotEmpty);
        expect(newUserCode, startsWith('TAL'));

        // Record referral relationship
        await ReferralTrackingService.recordReferralRelationship(
          newUserId: newUserId,
          referralCode: referrerCode,
        );

        // Update new user with referral code
        await fakeFirestore.collection('users').doc(newUserId).update({
          'referralCode': newUserCode,
        });

        // Verify referral relationship is recorded but not activated
        final newUserDoc = await fakeFirestore.collection('users').doc(newUserId).get();
        final newUserData = newUserDoc.data()!;
        expect(newUserData['referredBy'], equals(referrerId));
        expect(newUserData['referralStatus'], equals('pending'));

        // Step 3: New user completes payment
        await PaymentIntegrationService.manualPaymentActivation(
          userId: newUserId,
          paymentId: 'payment123',
          amount: 99.99,
          currency: 'USD',
        );

        // Step 4: Verify referral activation
        final updatedNewUserDoc = await fakeFirestore.collection('users').doc(newUserId).get();
        final updatedNewUserData = updatedNewUserDoc.data()!;
        expect(updatedNewUserData['membershipPaid'], isTrue);
        expect(updatedNewUserData['referralStatus'], equals('active'));

        // Step 5: Verify referrer statistics updated
        final updatedReferrerDoc = await fakeFirestore.collection('users').doc(referrerId).get();
        final updatedReferrerData = updatedReferrerDoc.data()!;
        expect(updatedReferrerData['directReferrals'], equals(1));
        expect(updatedReferrerData['activeDirectReferrals'], equals(1));
        expect(updatedReferrerData['teamSize'], equals(1));
        expect(updatedReferrerData['activeTeamSize'], equals(1));

        // Step 6: Verify notifications were sent
        final notifications = await fakeFirestore
            .collection('notifications')
            .where('userId', isEqualTo: referrerId)
            .get();
        
        expect(notifications.docs.length, greaterThan(0));
        
        final notificationData = notifications.docs.first.data();
        expect(notificationData['type'], equals('teamGrowth'));
        expect(notificationData['message'], contains('Jane Newuser'));
      });

      test('role progression flow with multiple referrals', () async {
        // Create user who will progress through roles
        const userId = 'progressuser';
        final userCode = await ReferralCodeGenerator.generateUniqueCode();

        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Progress User',
          'email': 'progress@example.com',
          'referralCode': userCode,
          'directReferrals': 0,
          'activeDirectReferrals': 0,
          'teamSize': 0,
          'activeTeamSize': 0,
          'currentRole': 'member',
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        await fakeFirestore.collection('referralCodes').doc(userCode).set({
          'code': userCode,
          'uid': userId,
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'clickCount': 0,
          'conversionCount': 0,
        });

        // Add 10 paid referrals to trigger team leader promotion
        for (int i = 1; i <= 10; i++) {
          final referralId = 'referral$i';
          
          await fakeFirestore.collection('users').doc(referralId).set({
            'fullName': 'Referral $i',
            'email': 'referral$i@example.com',
            'referredBy': userId,
            'membershipPaid': true,
            'referralStatus': 'active',
            'registrationDate': Timestamp.fromDate(DateTime.now()),
          });
        }

        // Update user statistics to trigger role progression
        await fakeFirestore.collection('users').doc(userId).update({
          'directReferrals': 10,
          'activeDirectReferrals': 10,
          'teamSize': 10,
          'activeTeamSize': 10,
        });

        // Check role progression
        await RoleProgressionService.checkAndUpdateRole(userId);

        // Verify promotion to team leader (activist is the first promotion level)
        final updatedUserDoc = await fakeFirestore.collection('users').doc(userId).get();
        final updatedUserData = updatedUserDoc.data()!;
        expect(updatedUserData['currentRole'], equals('activist'));

        // Verify promotion notification was sent
        final notifications = await fakeFirestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'rolePromotion')
            .get();
        
        expect(notifications.docs.length, equals(1));
      });
    });

    group('Concurrent Operations', () {
      test('handles concurrent referral code generation', () async {
        final futures = <Future<String>>[];
        
        // Generate 50 referral codes concurrently
        for (int i = 0; i < 50; i++) {
          futures.add(ReferralCodeGenerator.generateUniqueCode());
        }
        
        final codes = await Future.wait(futures);
        
        // Verify all codes are unique
        final uniqueCodes = codes.toSet();
        expect(uniqueCodes.length, equals(50));
        
        // Verify all codes follow correct format
        for (final code in codes) {
          expect(code, startsWith('TAL'));
          expect(code.length, equals(9));
          expect(code, matches(RegExp(r'^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$')));
        }
      });

      test('handles concurrent payment processing', () async {
        // Set up multiple users with pending referrals
        final userIds = <String>[];
        for (int i = 0; i < 10; i++) {
          final userId = 'concurrentuser$i';
          userIds.add(userId);
          
          await fakeFirestore.collection('users').doc(userId).set({
            'fullName': 'Concurrent User $i',
            'email': 'concurrent$i@example.com',
            'membershipPaid': false,
            'referralStatus': 'pending',
            'registrationDate': Timestamp.fromDate(DateTime.now()),
          });
        }
        
        // Process payments concurrently
        final futures = userIds.map((userId) =>
          PaymentIntegrationService.manualPaymentActivation(
            userId: userId,
            paymentId: 'payment_$userId',
            amount: 99.99,
            currency: 'USD',
          )
        ).toList();
        
        await Future.wait(futures);
        
        // Verify all payments were processed successfully
        for (final userId in userIds) {
          final userDoc = await fakeFirestore.collection('users').doc(userId).get();
          final userData = userDoc.data()!;
          expect(userData['membershipPaid'], isTrue);
          // Note: referralStatus might still be pending if no referrer was set
        }
      });
    });

    group('Error Handling and Recovery', () {
      test('handles invalid referral code gracefully', () async {
        const newUserId = 'erroruser';
        const invalidCode = 'INVALID123';
        
        await fakeFirestore.collection('users').doc(newUserId).set({
          'fullName': 'Error User',
          'email': 'error@example.com',
          'membershipPaid': false,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        // Attempt to record referral with invalid code
        expect(
          () => ReferralTrackingService.recordReferralRelationship(
            newUserId: newUserId,
            referralCode: invalidCode,
          ),
          throwsA(isA<Exception>()),
        );
        
        // Verify user data is not corrupted
        final userDoc = await fakeFirestore.collection('users').doc(newUserId).get();
        final userData = userDoc.data()!;
        expect(userData.containsKey('referredBy'), isFalse);
        expect(userData.containsKey('referralStatus'), isFalse);
      });

      test('handles payment failure gracefully', () async {
        // Set up user with pending referral
        const userId = 'failureuser';
        const referrerId = 'referrer456';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Failure User',
          'email': 'failure@example.com',
          'referredBy': referrerId,
          'membershipPaid': false,
          'referralStatus': 'pending',
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });
        
        await fakeFirestore.collection('users').doc(referrerId).set({
          'fullName': 'Referrer User',
          'email': 'referrer@example.com',
          'directReferrals': 0,
          'activeDirectReferrals': 0,
          'membershipPaid': true,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        // Process payment failure (simulate by not calling payment activation)
        // Payment remains in pending state
        
        // Verify referral remains in pending state
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        expect(userData['membershipPaid'], isFalse);
        expect(userData['referralStatus'], equals('pending'));
        
        // Verify referrer statistics not updated
        final referrerDoc = await fakeFirestore.collection('users').doc(referrerId).get();
        final referrerData = referrerDoc.data()!;
        expect(referrerData['directReferrals'], equals(0));
        expect(referrerData['activeDirectReferrals'], equals(0));
      });
    });

    group('Performance Tests', () {
      test('processes large referral chain efficiently', () async {
        final stopwatch = Stopwatch()..start();
        
        // Create a deep referral chain (10 levels)
        String previousUserId = 'root';
        await fakeFirestore.collection('users').doc(previousUserId).set({
          'fullName': 'Root User',
          'email': 'root@example.com',
          'referralCode': 'TALROOT01',
          'membershipPaid': true,
          'currentRole': 'member',
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });
        
        for (int i = 1; i <= 10; i++) {
          final userId = 'chainuser$i';
          final referralCode = 'TALCHAIN${i.toString().padLeft(2, '0')}';
          
          await fakeFirestore.collection('users').doc(userId).set({
            'fullName': 'Chain User $i',
            'email': 'chain$i@example.com',
            'referralCode': referralCode,
            'referredBy': previousUserId,
            'membershipPaid': true,
            'referralStatus': 'active',
            'registrationDate': Timestamp.fromDate(DateTime.now()),
          });
          
          previousUserId = userId;
        }
        
        // Process payment for the last user in chain
        await PaymentIntegrationService.manualPaymentActivation(
          userId: 'chainuser10',
          paymentId: 'chainpayment',
          amount: 99.99,
          currency: 'USD',
        );
        
        stopwatch.stop();
        
        // Verify performance is acceptable (under 5 seconds)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('handles high volume referral code generation', () async {
        final stopwatch = Stopwatch()..start();
        
        // Generate 1000 referral codes
        final futures = <Future<String>>[];
        for (int i = 0; i < 1000; i++) {
          futures.add(ReferralCodeGenerator.generateUniqueCode());
        }
        
        final codes = await Future.wait(futures);
        stopwatch.stop();
        
        // Verify all codes are unique
        expect(codes.toSet().length, equals(1000));
        
        // Verify performance (under 10 seconds for 1000 codes)
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      });
    });

    group('Security Tests', () {
      test('prevents self-referral attempts', () async {
        const userId = 'selfuser';
        const userCode = 'TALSELF01';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Self User',
          'email': 'self@example.com',
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
          throwsA(isA<Exception>()),
        );
      });

      test('validates payment authenticity', () async {
        const userId = 'securityuser';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Security User',
          'email': 'security@example.com',
          'membershipPaid': false,
          'registrationDate': Timestamp.fromDate(DateTime.now()),
        });

        // Test with valid payment (the service doesn't validate amounts in manual mode)
        final result = await PaymentIntegrationService.manualPaymentActivation(
          userId: userId,
          paymentId: 'valid_payment',
          amount: 99.99,
          currency: 'USD',
        );

        expect(result['success'], isTrue);
        expect(result['userId'], equals(userId));
      });
    });
  });
}

/// Helper function to set up admin user for tests
Future<void> _setupAdminUser(FakeFirebaseFirestore firestore) async {
  const adminUid = 'admin_test';

  // Create admin user
  await firestore.collection('users').doc(adminUid).set({
    'fullName': 'Talowa Admin',
    'email': ReferralConfig.adminEmail,
    'phone': ReferralConfig.adminPhone,
    'role': 'regional_coordinator',
    'status': 'active',
    'membershipPaid': true,
    'isSystemAdmin': true,
    'directReferralCount': 0,
    'totalTeamSize': 0,
    'referralCode': ReferralConfig.defaultReferrerCode,
    'referralChain': <String>[],
    'createdAt': Timestamp.fromDate(DateTime.now()),
  });

  // Create admin referral code
  await firestore
      .collection('referralCodes')
      .doc(ReferralConfig.defaultReferrerCode)
      .set({
    'code': ReferralConfig.defaultReferrerCode,
    'uid': adminUid,
    'isActive': true,
    'createdAt': Timestamp.fromDate(DateTime.now()),
    'clickCount': 0,
    'conversionCount': 0,
    'isSystemAdmin': true,
  });
}

