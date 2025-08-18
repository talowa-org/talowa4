import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/config/referral_config.dart';
import 'package:talowa/services/referral/user_registration_service.dart';
import 'package:talowa/services/referral/orphan_assignment_service.dart';
import 'package:talowa/services/referral/referral_code_generator.dart';
import 'package:talowa/services/referral/monitoring_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('UserRegistrationService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      UserRegistrationService.setFirestoreInstance(fakeFirestore);
      OrphanAssignmentService.setFirestoreInstance(fakeFirestore);
      ReferralCodeGenerator.setFirestoreInstance(fakeFirestore);
      MonitoringService.setFirestoreInstance(fakeFirestore);
      
      // Bootstrap admin user for tests
      await _setupAdminUser(fakeFirestore);
    });

    group('User Profile Creation (Step 1)', () {
      test('should create user profile with pending payment status', () async {
        const userId = 'new_user_1';
        const fullName = 'John Doe';
        const email = 'john@example.com';
        const phone = '+1234567890';
        
        final result = await UserRegistrationService.createUserProfile(
          userId: userId,
          fullName: fullName,
          email: email,
          phone: phone,
        );
        
        // Verify result
        expect(result['success'], isTrue);
        expect(result['userId'], equals(userId));
        expect(result['status'], equals('pending_payment'));
        expect(result['referralCode'], isNotNull);
        
        // Verify user document
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        expect(userDoc.exists, isTrue);
        
        final userData = userDoc.data()!;
        expect(userData['fullName'], equals(fullName));
        expect(userData['email'], equals(email));
        expect(userData['phone'], equals(phone));
        expect(userData['status'], equals('pending_payment'));
        expect(userData['membershipPaid'], isFalse);
        expect(userData['directReferralCount'], equals(0));
        expect(userData['totalTeamSize'], equals(0));
        expect(userData['role'], equals('member'));
        expect(userData['referralCode'], isNotNull);
        
        // Verify referral code document
        final userReferralCode = userData['referralCode'];
        final codeDoc = await fakeFirestore
            .collection('referralCodes')
            .doc(userReferralCode)
            .get();
        expect(codeDoc.exists, isTrue);
        
        final codeData = codeDoc.data()!;
        expect(codeData['code'], equals(userReferralCode));
        expect(codeData['uid'], equals(userId));
        expect(codeData['isActive'], isFalse); // Not active until payment
      });

      test('should assign provisional referral for orphan user', () async {
        const userId = 'orphan_user';
        const fullName = 'Orphan User';
        const email = 'orphan@example.com';
        
        final result = await UserRegistrationService.createUserProfile(
          userId: userId,
          fullName: fullName,
          email: email,
          providedReferralCode: null, // No referral code provided
        );
        
        expect(result['success'], isTrue);
        
        // Verify provisional referral was assigned
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['provisionalRef'], equals(ReferralConfig.defaultReferrerCode));
        expect(userData['assignedBySystem'], isTrue);
        expect(userData['provisionalAssignedAt'], isNotNull);
      });

      test('should not assign provisional referral when valid code provided', () async {
        const userId = 'user_with_valid_ref';
        const validCode = 'TAL234567';
        
        // Create valid referral code
        await fakeFirestore.collection('referralCodes').doc(validCode).set({
          'code': validCode,
          'uid': 'referrer123',
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        
        final result = await UserRegistrationService.createUserProfile(
          userId: userId,
          fullName: 'User With Valid Ref',
          email: 'valid@example.com',
          providedReferralCode: validCode,
        );
        
        expect(result['success'], isTrue);
        
        // Verify no provisional referral was assigned
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['provisionalRef'], isNull);
        expect(userData['assignedBySystem'], isNull);
      });

      test('should prevent duplicate user creation', () async {
        const userId = 'duplicate_user';
        
        // Create user first time
        await UserRegistrationService.createUserProfile(
          userId: userId,
          fullName: 'First User',
          email: 'first@example.com',
        );
        
        // Attempt to create same user again
        expect(
          () => UserRegistrationService.createUserProfile(
            userId: userId,
            fullName: 'Second User',
            email: 'second@example.com',
          ),
          throwsA(isA<UserRegistrationException>()),
        );
      });
    });

    group('User Activation (Step 2)', () {
      test('should activate user after payment confirmation', () async {
        const userId = 'activate_user_1';
        const paymentId = 'payment_123';
        const amount = 99.99;
        const currency = 'USD';
        
        // Create user in pending payment status
        await UserRegistrationService.createUserProfile(
          userId: userId,
          fullName: 'Activate User',
          email: 'activate@example.com',
        );
        
        // Activate user after payment
        final result = await UserRegistrationService.activateUserAfterPayment(
          userId: userId,
          paymentId: paymentId,
          amount: amount,
          currency: currency,
        );
        
        // Verify result
        expect(result['success'], isTrue);
        expect(result['userId'], equals(userId));
        expect(result['status'], equals('active'));
        expect(result['paymentId'], equals(paymentId));
        
        // Verify user document
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['status'], equals('active'));
        expect(userData['membershipPaid'], isTrue);
        expect(userData['paymentId'], equals(paymentId));
        expect(userData['paymentAmount'], equals(amount));
        expect(userData['paymentCurrency'], equals(currency));
        expect(userData['paidAt'], isNotNull);
        
        // Verify referral code is now active
        final userReferralCode = userData['referralCode'];
        final codeDoc = await fakeFirestore
            .collection('referralCodes')
            .doc(userReferralCode)
            .get();
        final codeData = codeDoc.data()!;
        expect(codeData['isActive'], isTrue);
        expect(codeData['activatedAt'], isNotNull);
      });

      test('should bind provisional referral during activation', () async {
        const userId = 'bind_during_activation';
        const paymentId = 'payment_456';
        
        // Create orphan user
        await UserRegistrationService.createUserProfile(
          userId: userId,
          fullName: 'Bind User',
          email: 'bind@example.com',
          providedReferralCode: null, // Will get provisional referral
        );
        
        // Activate user
        await UserRegistrationService.activateUserAfterPayment(
          userId: userId,
          paymentId: paymentId,
          amount: 99.99,
          currency: 'USD',
        );
        
        // Verify provisional referral was bound
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['referredBy'], equals(ReferralConfig.defaultReferrerCode));
        expect(userData['referralChain'], contains(ReferralConfig.defaultReferrerCode));
        expect(userData['provisionalRef'], isNull); // Should be cleared
        expect(userData['boundAt'], isNotNull);
        
        // Verify admin's referral count was updated
        const adminUid = 'admin_test';
        final adminDoc = await fakeFirestore.collection('users').doc(adminUid).get();
        final adminData = adminDoc.data()!;
        expect(adminData['directReferralCount'], equals(1));
      });

      test('should prevent activation of non-pending users', () async {
        const userId = 'already_active_user';
        
        // Create already active user
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Already Active',
          'email': 'active@example.com',
          'status': 'active',
          'membershipPaid': true,
        });
        
        // Attempt to activate again
        expect(
          () => UserRegistrationService.activateUserAfterPayment(
            userId: userId,
            paymentId: 'payment_789',
            amount: 99.99,
            currency: 'USD',
          ),
          throwsA(isA<UserRegistrationException>()),
        );
      });

      test('should handle missing user during activation', () async {
        const userId = 'missing_user';
        
        // Attempt to activate non-existent user
        expect(
          () => UserRegistrationService.activateUserAfterPayment(
            userId: userId,
            paymentId: 'payment_999',
            amount: 99.99,
            currency: 'USD',
          ),
          throwsA(isA<UserRegistrationException>()),
        );
      });
    });

    group('Registration Status', () {
      test('should return correct status for existing user', () async {
        const userId = 'status_user';
        
        // Create user
        await UserRegistrationService.createUserProfile(
          userId: userId,
          fullName: 'Status User',
          email: 'status@example.com',
        );
        
        // Get status
        final status = await UserRegistrationService.getUserRegistrationStatus(userId);
        
        expect(status['exists'], isTrue);
        expect(status['status'], equals('pending_payment'));
        expect(status['membershipPaid'], isFalse);
        expect(status['referralCode'], isNotNull);
        expect(status['createdAt'], isNotNull);
        expect(status['paidAt'], isNull);
      });

      test('should return correct status for non-existent user', () async {
        const userId = 'non_existent_user';
        
        final status = await UserRegistrationService.getUserRegistrationStatus(userId);
        
        expect(status['exists'], isFalse);
        expect(status['status'], isNull);
      });

      test('should return status after activation', () async {
        const userId = 'activated_status_user';
        
        // Create and activate user
        await UserRegistrationService.createUserProfile(
          userId: userId,
          fullName: 'Activated User',
          email: 'activated@example.com',
        );
        
        await UserRegistrationService.activateUserAfterPayment(
          userId: userId,
          paymentId: 'payment_status',
          amount: 99.99,
          currency: 'USD',
        );
        
        // Get status
        final status = await UserRegistrationService.getUserRegistrationStatus(userId);
        
        expect(status['exists'], isTrue);
        expect(status['status'], equals('active'));
        expect(status['membershipPaid'], isTrue);
        expect(status['paidAt'], isNotNull);
        expect(status['referredBy'], equals(ReferralConfig.defaultReferrerCode));
      });
    });

    group('System Initialization', () {
      test('should initialize registration system successfully', () async {
        // Clear existing admin setup
        await fakeFirestore
            .collection('referralCodes')
            .doc(ReferralConfig.defaultReferrerCode)
            .delete();
        await fakeFirestore.collection('users').doc('admin_test').delete();
        
        // Initialize system
        await UserRegistrationService.initializeRegistrationSystem();
        
        // Verify admin configuration
        final codeDoc = await fakeFirestore
            .collection('referralCodes')
            .doc(ReferralConfig.defaultReferrerCode)
            .get();
        expect(codeDoc.exists, isTrue);
        expect(codeDoc.data()!['isActive'], isTrue);
        
        final adminUid = codeDoc.data()!['uid'];
        final adminDoc = await fakeFirestore.collection('users').doc(adminUid).get();
        expect(adminDoc.exists, isTrue);
        expect(adminDoc.data()!['referralCode'], equals(ReferralConfig.defaultReferrerCode));
      });
    });

    group('Analytics Integration', () {
      test('should record payment activation analytics', () async {
        const userId = 'analytics_user';
        const paymentId = 'payment_analytics';
        
        // Create and activate user
        await UserRegistrationService.createUserProfile(
          userId: userId,
          fullName: 'Analytics User',
          email: 'analytics@example.com',
        );
        
        await UserRegistrationService.activateUserAfterPayment(
          userId: userId,
          paymentId: paymentId,
          amount: 99.99,
          currency: 'USD',
        );
        
        // Verify analytics event was recorded
        final analyticsEvents = await fakeFirestore
            .collection('analytics_events')
            .where('event', isEqualTo: 'user_payment_activation')
            .where('userId', isEqualTo: userId)
            .get();
        
        expect(analyticsEvents.docs.length, equals(1));
        
        final eventData = analyticsEvents.docs.first.data();
        expect(eventData['paymentId'], equals(paymentId));
        expect(eventData['amount'], equals(99.99));
        expect(eventData['currency'], equals('USD'));
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
