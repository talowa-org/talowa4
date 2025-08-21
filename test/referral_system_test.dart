import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:talowa/services/referral/simplified_referral_service.dart';
import 'package:talowa/services/referral/referral_registration_service.dart';
import 'package:talowa/services/referral/role_progression_service.dart';
import 'package:talowa/services/referral/referral_tracking_service.dart';
import 'package:talowa/services/referral/referral_lookup_service.dart';

void main() {
  group('Simplified Referral System Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      
      // Inject fake instances
      SimplifiedReferralService.setFirestoreInstance(fakeFirestore);
      ReferralRegistrationService.setFirestoreInstance(fakeFirestore);
      RoleProgressionService.setFirestoreInstance(fakeFirestore);
      ReferralTrackingService.setFirestoreInstance(fakeFirestore);
      ReferralLookupService.setFirestoreInstance(fakeFirestore);
    });

    test('User registration creates active referral immediately', () async {
      // Create a referrer user first
      await fakeFirestore.collection('users').doc('referrer123').set({
        'id': 'referrer123',
        'fullName': 'John Referrer',
        'email': 'referrer@test.com',
        'referralCode': 'TAL123ABC',
        'currentRole': 'member',
        'activeDirectReferrals': 0,
        'activeTeamSize': 0,
        'isActive': true,
        'membershipPaid': true,
      });

      await fakeFirestore.collection('referralCodes').doc('TAL123ABC').set({
        'code': 'TAL123ABC',
        'uid': 'referrer123',
        'isActive': true,
        'createdAt': DateTime.now(),
        'clickCount': 0,
        'conversionCount': 0,
      });

      // Register new user with referral code
      final result = await SimplifiedReferralService.setupUserReferral(
        userId: 'newuser456',
        fullName: 'Jane Newuser',
        email: 'newuser@test.com',
        referralCode: 'TAL123ABC',
      );

      // Verify results
      expect(result['success'], true);
      expect(result['wasReferred'], true);
      expect(result['referrerUserId'], 'referrer123');
      expect(result['referralCode'], isNotNull);
      expect(result['referralCode'], startsWith('TAL'));

      // Verify new user document
      final newUserDoc = await fakeFirestore.collection('users').doc('newuser456').get();
      final newUserData = newUserDoc.data()!;
      
      expect(newUserData['referralStatus'], 'active');
      expect(newUserData['membershipPaid'], true);
      expect(newUserData['referredBy'], 'TAL123ABC');
      expect(newUserData['referralChain'], contains('referrer123'));

      // Verify referrer statistics were updated
      final referrerDoc = await fakeFirestore.collection('users').doc('referrer123').get();
      final referrerData = referrerDoc.data()!;
      
      expect(referrerData['activeDirectReferrals'], 1);
      expect(referrerData['activeTeamSize'], 1);
    });

    test('Role progression works immediately after referral', () async {
      // Create a user with enough referrals for team leader role
      await fakeFirestore.collection('users').doc('leader123').set({
        'id': 'leader123',
        'fullName': 'Team Leader',
        'email': 'leader@test.com',
        'referralCode': 'TALLEADER',
        'currentRole': 'member',
        'activeDirectReferrals': 10, // Enough for team leader
        'activeTeamSize': 50,
        'isActive': true,
        'membershipPaid': true,
      });

      // Check role progression
      final result = await RoleProgressionService.checkAndUpdateRole('leader123');

      expect(result['promoted'], true);
      expect(result['currentRole'], 'team_leader');
      expect(result['previousRole'], 'member');

      // Verify user document was updated
      final userDoc = await fakeFirestore.collection('users').doc('leader123').get();
      final userData = userDoc.data()!;
      
      expect(userData['currentRole'], 'team_leader');
      expect(userData['previousRole'], 'member');
      expect(userData['rolePromotedAt'], isNotNull);
    });

    test('Referral chain statistics update correctly', () async {
      // Create a referral chain: founder -> coordinator -> team_leader -> new_user
      await fakeFirestore.collection('users').doc('founder').set({
        'id': 'founder',
        'fullName': 'Founder',
        'referralCode': 'TALFOUNDER',
        'currentRole': 'state_coordinator',
        'activeDirectReferrals': 100,
        'activeTeamSize': 5000,
        'referralChain': [],
        'isActive': true,
        'membershipPaid': true,
      });

      await fakeFirestore.collection('users').doc('coordinator').set({
        'id': 'coordinator',
        'fullName': 'Coordinator',
        'referralCode': 'TALCOORD',
        'currentRole': 'coordinator',
        'activeDirectReferrals': 20,
        'activeTeamSize': 150,
        'referralChain': ['founder'],
        'isActive': true,
        'membershipPaid': true,
      });

      await fakeFirestore.collection('users').doc('teamlead').set({
        'id': 'teamlead',
        'fullName': 'Team Lead',
        'referralCode': 'TALTEAM',
        'currentRole': 'team_leader',
        'activeDirectReferrals': 10,
        'activeTeamSize': 50,
        'referralChain': ['founder', 'coordinator'],
        'isActive': true,
        'membershipPaid': true,
      });

      await fakeFirestore.collection('referralCodes').doc('TALTEAM').set({
        'code': 'TALTEAM',
        'uid': 'teamlead',
        'isActive': true,
        'createdAt': DateTime.now(),
        'clickCount': 0,
        'conversionCount': 0,
      });

      // Add new user to the chain
      final result = await SimplifiedReferralService.setupUserReferral(
        userId: 'newmember',
        fullName: 'New Member',
        email: 'newmember@test.com',
        referralCode: 'TALTEAM',
      );

      expect(result['success'], true);
      expect(result['referralChain'], ['founder', 'coordinator', 'teamlead']);

      // Verify all users in chain have updated statistics
      final founderDoc = await fakeFirestore.collection('users').doc('founder').get();
      final coordinatorDoc = await fakeFirestore.collection('users').doc('coordinator').get();
      final teamleadDoc = await fakeFirestore.collection('users').doc('teamlead').get();

      // Each should have their team size increased by 1
      expect(founderDoc.data()!['activeTeamSize'], greaterThan(5000));
      expect(coordinatorDoc.data()!['activeTeamSize'], greaterThan(150));
      expect(teamleadDoc.data()!['activeDirectReferrals'], greaterThan(10));
    });

    test('Referral validation works correctly', () async {
      // Create valid referral code
      await fakeFirestore.collection('users').doc('validuser').set({
        'id': 'validuser',
        'fullName': 'Valid User',
        'email': 'valid@test.com',
        'referralCode': 'TALVALID',
        'currentRole': 'member',
        'isActive': true,
      });

      await fakeFirestore.collection('referralCodes').doc('TALVALID').set({
        'code': 'TALVALID',
        'uid': 'validuser',
        'isActive': true,
        'createdAt': DateTime.now(),
        'clickCount': 0,
        'conversionCount': 0,
      });

      // Test valid code
      final validResult = await SimplifiedReferralService.validateReferralCode('TALVALID');
      expect(validResult['valid'], true);
      expect(validResult['referrerUserId'], 'validuser');
      expect(validResult['referrerName'], 'Valid User');

      // Test invalid code
      final invalidResult = await SimplifiedReferralService.validateReferralCode('TALINVALID');
      expect(invalidResult['valid'], false);
    });

    test('User referral status retrieval works', () async {
      // Create user with referral data
      await fakeFirestore.collection('users').doc('testuser').set({
        'id': 'testuser',
        'fullName': 'Test User',
        'email': 'test@test.com',
        'referralCode': 'TALTEST',
        'currentRole': 'team_leader',
        'activeDirectReferrals': 15,
        'activeTeamSize': 75,
        'referralChain': ['founder'],
        'referredBy': 'TALFOUNDER',
        'referralStatus': 'active',
        'isActive': true,
        'membershipPaid': true,
      });

      final status = await SimplifiedReferralService.getUserReferralStatus('testuser');

      expect(status['userId'], 'testuser');
      expect(status['referralCode'], 'TALTEST');
      expect(status['currentRole'], 'team_leader');
      expect(status['activeDirectReferrals'], 15);
      expect(status['activeTeamSize'], 75);
      expect(status['referralStatus'], 'active');
      expect(status['membershipPaid'], true);
    });

    test('Leaderboard generation works', () async {
      // Create multiple users with different referral counts
      final users = [
        {'id': 'user1', 'name': 'User 1', 'referrals': 50, 'team': 500},
        {'id': 'user2', 'name': 'User 2', 'referrals': 30, 'team': 300},
        {'id': 'user3', 'name': 'User 3', 'referrals': 80, 'team': 800},
      ];

      for (final user in users) {
        await fakeFirestore.collection('users').doc(user['id'] as String).set({
          'id': user['id'],
          'fullName': user['name'],
          'email': '${user['id']}@test.com',
          'referralCode': 'TAL${user['id']?.toString().toUpperCase()}',
          'currentRole': 'coordinator',
          'activeDirectReferrals': user['referrals'],
          'activeTeamSize': user['team'],
          'isActive': true,
        });
      }

      final leaderboard = await SimplifiedReferralService.getReferralLeaderboard(limit: 10);

      expect(leaderboard.length, 3);
      // Should be ordered by activeDirectReferrals descending
      expect(leaderboard[0]['userId'], 'user3'); // 80 referrals
      expect(leaderboard[1]['userId'], 'user1'); // 50 referrals
      expect(leaderboard[2]['userId'], 'user2'); // 30 referrals
    });

    test('Analytics calculation works', () async {
      // Create test users with various referral counts
      await fakeFirestore.collection('users').doc('user1').set({
        'currentRole': 'member',
        'activeDirectReferrals': 0,
        'isActive': true,
      });

      await fakeFirestore.collection('users').doc('user2').set({
        'currentRole': 'team_leader',
        'activeDirectReferrals': 15,
        'isActive': true,
      });

      await fakeFirestore.collection('users').doc('user3').set({
        'currentRole': 'coordinator',
        'activeDirectReferrals': 25,
        'isActive': true,
      });

      final analytics = await SimplifiedReferralService.getReferralAnalytics();

      expect(analytics['totalUsers'], 3);
      expect(analytics['usersWithReferrals'], 2); // user2 and user3 have referrals
      expect(analytics['referralRate'], 67); // 2/3 * 100 = 67%
      expect(analytics['roleDistribution']['member'], 1);
      expect(analytics['roleDistribution']['team_leader'], 1);
      expect(analytics['roleDistribution']['coordinator'], 1);
    });
  });
}