import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/config/referral_config.dart';
import 'package:talowa/services/referral/orphan_assignment_service.dart';
import 'package:talowa/services/referral/monitoring_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('OrphanAssignmentService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      OrphanAssignmentService.setFirestoreInstance(fakeFirestore);
      MonitoringService.setFirestoreInstance(fakeFirestore);
      
      // Bootstrap admin user for tests
      await _setupAdminUser(fakeFirestore);
    });

    group('Provisional Referral Assignment', () {
      test('should assign provisional referral when no code provided', () async {
        const userId = 'orphan_user_1';
        
        // Create user without referral
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Orphan User',
          'email': 'orphan@example.com',
          'status': 'pending_payment',
          'membershipPaid': false,
        });
        
        // Handle provisional referral
        await OrphanAssignmentService.handleProvisionalReferral(
          userId: userId,
          providedReferralCode: null,
        );
        
        // Verify provisional referral was set
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['provisionalRef'], equals(ReferralConfig.defaultReferrerCode));
        expect(userData['assignedBySystem'], isTrue);
        expect(userData['provisionalAssignedAt'], isNotNull);
      });

      test('should assign provisional referral when invalid code provided', () async {
        const userId = 'orphan_user_2';
        const invalidCode = 'INVALID123';
        
        // Create user
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Orphan User 2',
          'email': 'orphan2@example.com',
          'status': 'pending_payment',
          'membershipPaid': false,
        });
        
        // Handle provisional referral with invalid code
        await OrphanAssignmentService.handleProvisionalReferral(
          userId: userId,
          providedReferralCode: invalidCode,
        );
        
        // Verify provisional referral was set
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['provisionalRef'], equals(ReferralConfig.defaultReferrerCode));
        expect(userData['assignedBySystem'], isTrue);
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
        
        // Create user
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'User With Valid Ref',
          'email': 'valid@example.com',
          'status': 'pending_payment',
          'membershipPaid': false,
        });
        
        // Handle provisional referral with valid code
        await OrphanAssignmentService.handleProvisionalReferral(
          userId: userId,
          providedReferralCode: validCode,
        );
        
        // Verify no provisional referral was set
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['provisionalRef'], isNull);
        expect(userData['assignedBySystem'], isNull);
      });

      test('should skip if user already has referral relationship', () async {
        const userId = 'user_with_existing_ref';
        
        // Create user with existing referral
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'User With Existing Ref',
          'email': 'existing@example.com',
          'status': 'pending_payment',
          'membershipPaid': false,
          'referredBy': 'TAL234567',
        });
        
        // Handle provisional referral
        await OrphanAssignmentService.handleProvisionalReferral(
          userId: userId,
          providedReferralCode: null,
        );
        
        // Verify no provisional referral was set
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['provisionalRef'], isNull);
        expect(userData['assignedBySystem'], isNull);
        expect(userData['referredBy'], equals('TAL234567'));
      });
    });

    group('Provisional Referral Binding', () {
      test('should bind provisional referral after payment', () async {
        const userId = 'bind_user_1';
        const adminUid = 'admin_test';
        
        // Create user with provisional referral
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Bind User',
          'email': 'bind@example.com',
          'status': 'active',
          'membershipPaid': true,
          'provisionalRef': ReferralConfig.defaultReferrerCode,
          'assignedBySystem': true,
        });
        
        // Bind provisional referral
        await OrphanAssignmentService.bindProvisionalReferral(userId);
        
        // Verify binding was successful
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['referredBy'], equals(ReferralConfig.defaultReferrerCode));
        expect(userData['referralChain'], contains(ReferralConfig.defaultReferrerCode));
        expect(userData['provisionalRef'], isNull);
        expect(userData['boundAt'], isNotNull);
        
        // Verify admin's direct referral count was incremented
        final adminDoc = await fakeFirestore.collection('users').doc(adminUid).get();
        final adminData = adminDoc.data()!;
        expect(adminData['directReferralCount'], equals(1));
        
        // Verify referral code conversion count was incremented
        final codeDoc = await fakeFirestore
            .collection('referralCodes')
            .doc(ReferralConfig.defaultReferrerCode)
            .get();
        final codeData = codeDoc.data()!;
        expect(codeData['conversionCount'], equals(1));
      });

      test('should skip binding if user already has referral relationship', () async {
        const userId = 'bind_user_2';
        
        // Create user with existing referral
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Bind User 2',
          'email': 'bind2@example.com',
          'status': 'active',
          'membershipPaid': true,
          'referredBy': 'TAL234567',
          'provisionalRef': ReferralConfig.defaultReferrerCode,
        });
        
        // Attempt to bind provisional referral
        await OrphanAssignmentService.bindProvisionalReferral(userId);
        
        // Verify existing referral was not changed
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['referredBy'], equals('TAL234567'));
        expect(userData['provisionalRef'], equals(ReferralConfig.defaultReferrerCode));
      });

      test('should skip binding if no provisional referral exists', () async {
        const userId = 'bind_user_3';
        
        // Create user without provisional referral
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Bind User 3',
          'email': 'bind3@example.com',
          'status': 'active',
          'membershipPaid': true,
        });
        
        // Attempt to bind provisional referral
        await OrphanAssignmentService.bindProvisionalReferral(userId);
        
        // Verify no changes were made
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        expect(userData['referredBy'], isNull);
        expect(userData['provisionalRef'], isNull);
      });

      test('should handle invalid provisional referral code', () async {
        const userId = 'bind_user_4';
        const invalidCode = 'INVALID123';
        
        // Create user with invalid provisional referral
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Bind User 4',
          'email': 'bind4@example.com',
          'status': 'active',
          'membershipPaid': true,
          'provisionalRef': invalidCode,
          'assignedBySystem': true,
        });
        
        // Attempt to bind provisional referral should throw exception
        expect(
          () => OrphanAssignmentService.bindProvisionalReferral(userId),
          throwsA(isA<OrphanAssignmentException>()),
        );
      });
    });

    group('Legacy Migration', () {
      test('should migrate legacy orphan users', () async {
        // Create legacy orphan users
        const legacyUser1 = 'legacy_user_1';
        const legacyUser2 = 'legacy_user_2';
        
        await fakeFirestore.collection('users').doc(legacyUser1).set({
          'fullName': 'Legacy User 1',
          'email': 'legacy1@example.com',
          'status': 'active',
          'membershipPaid': true,
          'referredBy': null,
        });
        
        await fakeFirestore.collection('users').doc(legacyUser2).set({
          'fullName': 'Legacy User 2',
          'email': 'legacy2@example.com',
          'status': 'active',
          'membershipPaid': true,
          'referredBy': null,
        });
        
        // Run migration
        await OrphanAssignmentService.migrateLegacyOrphanUsers();
        
        // Verify users were migrated
        final user1Doc = await fakeFirestore.collection('users').doc(legacyUser1).get();
        final user1Data = user1Doc.data()!;
        expect(user1Data['referredBy'], equals(ReferralConfig.defaultReferrerCode));
        expect(user1Data['assignedBySystem'], isTrue);
        
        final user2Doc = await fakeFirestore.collection('users').doc(legacyUser2).get();
        final user2Data = user2Doc.data()!;
        expect(user2Data['referredBy'], equals(ReferralConfig.defaultReferrerCode));
        expect(user2Data['assignedBySystem'], isTrue);
      });

      test('should skip users already migrated', () async {
        const userId = 'already_migrated';
        
        // Create user already migrated
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Already Migrated',
          'email': 'migrated@example.com',
          'status': 'active',
          'membershipPaid': true,
          'referredBy': null,
          'assignedBySystem': true,
        });
        
        // Run migration
        await OrphanAssignmentService.migrateLegacyOrphanUsers();
        
        // Verify user was not processed again
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        expect(userData['referredBy'], isNull);
        expect(userData['assignedBySystem'], isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle missing user gracefully', () async {
        const userId = 'missing_user';
        
        // Attempt to handle provisional referral for missing user
        expect(
          () => OrphanAssignmentService.handleProvisionalReferral(
            userId: userId,
            providedReferralCode: null,
          ),
          throwsA(isA<OrphanAssignmentException>()),
        );
      });

      test('should handle admin configuration errors', () async {
        // Remove admin referral code to simulate configuration error
        await fakeFirestore
            .collection('referralCodes')
            .doc(ReferralConfig.defaultReferrerCode)
            .delete();
        
        const userId = 'config_error_user';
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Config Error User',
          'email': 'config@example.com',
          'status': 'pending_payment',
        });
        
        // Should throw exception due to invalid admin configuration
        expect(
          () => OrphanAssignmentService.handleProvisionalReferral(
            userId: userId,
            providedReferralCode: null,
          ),
          throwsA(isA<OrphanAssignmentException>()),
        );
      });
    });

    group('Monitoring Integration', () {
      test('should log monitoring events during operations', () async {
        const userId = 'monitoring_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Monitoring User',
          'email': 'monitoring@example.com',
          'status': 'pending_payment',
        });
        
        // Handle provisional referral
        await OrphanAssignmentService.handleProvisionalReferral(
          userId: userId,
          providedReferralCode: null,
        );
        
        // Verify monitoring events were logged
        final errorEvents = await fakeFirestore
            .collection('error_events')
            .where('operation', isEqualTo: 'provisional_referral_assignment')
            .get();
        
        // Should have info log for provisional assignment
        expect(errorEvents.docs.length, greaterThan(0));
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
