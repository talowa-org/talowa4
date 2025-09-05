import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:talowa/services/referral/referral_code_generator.dart';
import 'package:talowa/services/referral/user_registration_service.dart';
import 'package:talowa/services/admin/admin_bootstrap_service.dart';
import 'package:talowa/services/referral/universal_link_service.dart';

void main() {
  group('Referral-First Registration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser(
        uid: 'test-user-123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      
      // Inject fake instances
      ReferralCodeGenerator.setFirestoreInstance(fakeFirestore);
      UserRegistrationService.setFirestoreInstance(fakeFirestore);
      AdminBootstrapService.setFirebaseInstances(fakeFirestore, mockAuth);
    });

    test('TAL prefix referral code generation', () async {
      // Generate multiple codes and verify TAL prefix
      for (int i = 0; i < 5; i++) {
        final code = await ReferralCodeGenerator.generateUniqueCode();
        expect(code.startsWith('TAL'), true, reason: 'Code should start with TAL: $code');
        expect(code.length, 9, reason: 'Code should be 9 characters (TAL + 6): $code');
        
        // Verify code is reserved
        final codeDoc = await fakeFirestore.collection('referralCodes').doc(code).get();
        expect(codeDoc.exists, true, reason: 'Code should be reserved in database');
      }
    });

    test('Admin bootstrap creates TALADMIN', () async {
      // Bootstrap admin
      final adminUid = await AdminBootstrapService.bootstrapAdmin();
      expect(adminUid, isNotEmpty);
      
      // Verify admin user document
      final adminDoc = await fakeFirestore.collection('users').doc(adminUid).get();
      expect(adminDoc.exists, true);
      
      final adminData = adminDoc.data()!;
      expect(adminData['referralCode'], 'TALADMIN');
      expect(adminData['membershipPaid'], true);
      expect(adminData['email'], '+917981828388@talowa.app');
      expect(adminData['phoneNumber'], '+917981828388');
      
      // Verify TALADMIN code is reserved
      final codeDoc = await fakeFirestore.collection('referralCodes').doc('TALADMIN').get();
      expect(codeDoc.exists, true);
      
      final codeData = codeDoc.data()!;
      expect(codeData['uid'], adminUid);
      expect(codeData['active'], true);
    });

    test('Registration returns immediate referral code (not Loading)', () async {
      // Create user profile
      final result = await UserRegistrationService.createUserProfile(
        userId: 'user-123',
        fullName: 'John Doe',
        email: 'john@example.com',
        phone: '+1234567890',
      );
      
      expect(result['success'], true);
      expect(result['referralCode'], isNotEmpty);
      expect(result['referralCode'], isNot('Loading'));
      expect(result['referralCode'], startsWith('TAL'));
      expect(result['status'], 'pending_payment');
      expect(result['provisionalRef'], 'TALADMIN'); // Default when no ref provided
      expect(result['assignedBySystem'], true);
    });

    test('Registration with valid deep link ref', () async {
      // First create a referrer
      await fakeFirestore.collection('referralCodes').doc('TAL123456').set({
        'uid': 'referrer-123',
        'active': true,
      });
      
      // Create user profile with provided referral code
      final result = await UserRegistrationService.createUserProfile(
        userId: 'user-456',
        fullName: 'Jane Doe',
        email: 'jane@example.com',
        providedReferralCode: 'TAL123456',
      );
      
      expect(result['success'], true);
      expect(result['provisionalRef'], 'TAL123456');
      expect(result['assignedBySystem'], false);
    });

    test('Registration with invalid ref defaults to TALADMIN', () async {
      // Create user profile with invalid referral code
      final result = await UserRegistrationService.createUserProfile(
        userId: 'user-789',
        fullName: 'Bob Smith',
        email: 'bob@example.com',
        providedReferralCode: 'INVALID123',
      );
      
      expect(result['success'], true);
      expect(result['provisionalRef'], 'TALADMIN');
      expect(result['assignedBySystem'], true);
    });

    test('Payment success binds referral and updates counters', () async {
      // Setup: Create referrer
      await fakeFirestore.collection('users').doc('referrer-123').set({
        'referralCode': 'TAL123456',
        'directReferralCount': 0,
        'totalTeamSize': 0,
        'referralChain': [],
      });
      
      await fakeFirestore.collection('referralCodes').doc('TAL123456').set({
        'uid': 'referrer-123',
        'active': true,
      });
      
      // Create user with provisional referral
      await UserRegistrationService.createUserProfile(
        userId: 'user-999',
        fullName: 'Alice Johnson',
        email: 'alice@example.com',
        providedReferralCode: 'TAL123456',
      );
      
      // Simulate payment success
      final paymentResult = await UserRegistrationService.activateUserAfterPayment(
        userId: 'user-999',
        paymentId: 'payment-123',
        amount: 100.0,
        currency: 'USD',
      );
      
      expect(paymentResult['success'], true);
      expect(paymentResult['status'], 'active');
      expect(paymentResult['referredBy'], 'TAL123456');
      
      // Verify referrer's counters were updated
      final referrerDoc = await fakeFirestore.collection('users').doc('referrer-123').get();
      final referrerData = referrerDoc.data()!;
      expect(referrerData['directReferralCount'], 1);
      expect(referrerData['totalTeamSize'], 1);
      
      // Verify user's referral binding
      final userDoc = await fakeFirestore.collection('users').doc('user-999').get();
      final userData = userDoc.data()!;
      expect(userData['referredBy'], 'TAL123456');
      expect(userData['referralChain'], ['TAL123456']);
      expect(userData['membershipPaid'], true);
    });

    test('Legacy code migration to TAL prefix', () async {
      // Setup legacy users with non-TAL codes
      await fakeFirestore.collection('users').doc('legacy-1').set({
        'referralCode': 'OLD123456',
        'fullName': 'Legacy User 1',
      });
      
      await fakeFirestore.collection('users').doc('legacy-2').set({
        'referralCode': 'LEGACY789',
        'fullName': 'Legacy User 2',
      });
      
      // Keep TALADMIN unchanged
      await fakeFirestore.collection('users').doc('admin').set({
        'referralCode': 'TALADMIN',
        'fullName': 'Admin User',
      });
      
      // Run migration
      final migratedCount = await ReferralCodeGenerator.migrateLegacyCodes();
      expect(migratedCount, 2); // Should migrate 2 users, skip TALADMIN
      
      // Verify legacy users now have TAL codes
      final legacy1Doc = await fakeFirestore.collection('users').doc('legacy-1').get();
      final legacy1Code = legacy1Doc.data()!['referralCode'];
      expect(legacy1Code, startsWith('TAL'));
      
      final legacy2Doc = await fakeFirestore.collection('users').doc('legacy-2').get();
      final legacy2Code = legacy2Doc.data()!['referralCode'];
      expect(legacy2Code, startsWith('TAL'));
      
      // Verify TALADMIN unchanged
      final adminDoc = await fakeFirestore.collection('users').doc('admin').get();
      expect(adminDoc.data()!['referralCode'], 'TALADMIN');
    });

    test('Deep link auto-fill one-time consumption', () {
      // Test pending referral code consumption
      UniversalLinkService.setPendingReferralCodeForTesting('TAL999888');
      
      // First read should return the code
      final firstRead = UniversalLinkService.getPendingReferralCode();
      expect(firstRead, 'TAL999888');
      
      // Second read should return null (consumed)
      final secondRead = UniversalLinkService.getPendingReferralCode();
      expect(secondRead, null);
    });

    test('Ensure referral code idempotent operation', () async {
      // Create user document first
      await fakeFirestore.collection('users').doc('user-ensure-123').set({
        'fullName': 'Ensure Test User',
      });

      // First call should generate and assign a code
      final firstCode = await ReferralCodeGenerator.ensureReferralCode('user-ensure-123');
      expect(firstCode, startsWith('TAL'));

      // Call ensure again - should return same code
      final secondCode = await ReferralCodeGenerator.ensureReferralCode('user-ensure-123');
      expect(secondCode, firstCode);
    });
  });
}

