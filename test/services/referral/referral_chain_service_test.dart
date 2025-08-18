import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:talowa/services/referral/referral_chain_service.dart';

void main() {
  group('ReferralChainService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      ReferralChainService.setFirestoreInstance(fakeFirestore);
    });

    group('Chain Building', () {
      test('should build referral chain correctly', () async {
        // Setup test data: A -> B -> C -> D
        await fakeFirestore.collection('users').doc('userA').set({
          'fullName': 'User A',
          'referredBy': null, // Root user
        });

        await fakeFirestore.collection('users').doc('userB').set({
          'fullName': 'User B',
          'referredBy': 'userA',
        });

        await fakeFirestore.collection('users').doc('userC').set({
          'fullName': 'User C',
          'referredBy': 'userB',
        });

        await fakeFirestore.collection('users').doc('userD').set({
          'fullName': 'User D',
          'referredBy': 'userC',
        });

        final chain = await ReferralChainService.buildReferralChain('userD');

        expect(chain, equals(['userD', 'userC', 'userB', 'userA']));
      });

      test('should handle single user chain', () async {
        await fakeFirestore.collection('users').doc('singleUser').set({
          'fullName': 'Single User',
          'referredBy': null,
        });

        final chain = await ReferralChainService.buildReferralChain('singleUser');

        expect(chain, equals(['singleUser']));
      });

      test('should handle non-existent user', () async {
        final chain = await ReferralChainService.buildReferralChain('nonExistentUser');

        expect(chain, equals(['nonExistentUser']));
      });
    });

    group('Upline Chain', () {
      test('should get upline chain with user details', () async {
        // Setup test data: A -> B -> C
        await fakeFirestore.collection('users').doc('userA').set({
          'fullName': 'User A',
          'email': 'a@example.com',
          'currentRole': 'coordinator',
          'membershipPaid': true,
          'referredBy': null,
        });

        await fakeFirestore.collection('users').doc('userB').set({
          'fullName': 'User B',
          'email': 'b@example.com',
          'currentRole': 'leader',
          'membershipPaid': true,
          'referredBy': 'userA',
        });

        await fakeFirestore.collection('users').doc('userC').set({
          'fullName': 'User C',
          'email': 'c@example.com',
          'currentRole': 'member',
          'membershipPaid': false,
          'referredBy': 'userB',
        });

        final upline = await ReferralChainService.getUplineChain('userC');

        expect(upline.length, equals(2));
        expect(upline[0]['userId'], equals('userB'));
        expect(upline[0]['fullName'], equals('User B'));
        expect(upline[0]['level'], equals(1));
        expect(upline[1]['userId'], equals('userA'));
        expect(upline[1]['fullName'], equals('User A'));
        expect(upline[1]['level'], equals(2));
      });

      test('should return empty upline for root user', () async {
        await fakeFirestore.collection('users').doc('rootUser').set({
          'fullName': 'Root User',
          'referredBy': null,
        });

        final upline = await ReferralChainService.getUplineChain('rootUser');

        expect(upline, isEmpty);
      });
    });

    group('Downline Chain', () {
      test('should get downline chain with depth limit', () async {
        // Setup test data: A -> B -> C -> D
        await fakeFirestore.collection('users').doc('userA').set({
          'fullName': 'User A',
          'email': 'a@example.com',
          'currentRole': 'coordinator',
          'membershipPaid': true,
        });

        await fakeFirestore.collection('users').doc('userB').set({
          'fullName': 'User B',
          'email': 'b@example.com',
          'currentRole': 'member',
          'membershipPaid': true,
          'referredBy': 'userA',
        });

        await fakeFirestore.collection('users').doc('userC').set({
          'fullName': 'User C',
          'email': 'c@example.com',
          'currentRole': 'member',
          'membershipPaid': false,
          'referredBy': 'userB',
        });

        await fakeFirestore.collection('users').doc('userD').set({
          'fullName': 'User D',
          'email': 'd@example.com',
          'currentRole': 'member',
          'membershipPaid': true,
          'referredBy': 'userC',
        });

        final downline = await ReferralChainService.getDownlineChain('userA', maxDepth: 3);

        expect(downline.length, equals(3));
        
        // Check that all downline users are included
        final userIds = downline.map((user) => user['userId']).toList();
        expect(userIds, contains('userB'));
        expect(userIds, contains('userC'));
        expect(userIds, contains('userD'));
      });

      test('should respect max depth limit', () async {
        // Setup deep chain
        await fakeFirestore.collection('users').doc('userA').set({
          'fullName': 'User A',
        });

        await fakeFirestore.collection('users').doc('userB').set({
          'fullName': 'User B',
          'referredBy': 'userA',
        });

        await fakeFirestore.collection('users').doc('userC').set({
          'fullName': 'User C',
          'referredBy': 'userB',
        });

        final downline = await ReferralChainService.getDownlineChain('userA', maxDepth: 1);

        expect(downline.length, equals(1));
        expect(downline[0]['userId'], equals('userB'));
      });
    });

    group('Direct Referrals', () {
      test('should get direct referrals only', () async {
        await fakeFirestore.collection('users').doc('referrer').set({
          'fullName': 'Referrer',
        });

        await fakeFirestore.collection('users').doc('direct1').set({
          'fullName': 'Direct 1',
          'email': 'direct1@example.com',
          'referredBy': 'referrer',
          'membershipPaid': true,
        });

        await fakeFirestore.collection('users').doc('direct2').set({
          'fullName': 'Direct 2',
          'email': 'direct2@example.com',
          'referredBy': 'referrer',
          'membershipPaid': false,
        });

        await fakeFirestore.collection('users').doc('indirect').set({
          'fullName': 'Indirect',
          'referredBy': 'direct1',
        });

        final directReferrals = await ReferralChainService.getDirectReferrals('referrer');

        expect(directReferrals.length, equals(2));
        
        final userIds = directReferrals.map((user) => user['userId']).toList();
        expect(userIds, contains('direct1'));
        expect(userIds, contains('direct2'));
        expect(userIds, isNot(contains('indirect')));
      });

      test('should return empty list for user with no referrals', () async {
        await fakeFirestore.collection('users').doc('noReferrals').set({
          'fullName': 'No Referrals',
        });

        final directReferrals = await ReferralChainService.getDirectReferrals('noReferrals');

        expect(directReferrals, isEmpty);
      });
    });

    group('Counting Functions', () {
      test('should count direct referrals correctly', () async {
        await fakeFirestore.collection('users').doc('referrer').set({
          'fullName': 'Referrer',
        });

        // Add 3 direct referrals
        for (int i = 1; i <= 3; i++) {
          await fakeFirestore.collection('users').doc('direct$i').set({
            'fullName': 'Direct $i',
            'referredBy': 'referrer',
            'membershipPaid': i <= 2, // First 2 are paid
          });
        }

        final totalCount = await ReferralChainService.countDirectReferrals('referrer');
        final activeCount = await ReferralChainService.countActiveDirectReferrals('referrer');

        expect(totalCount, equals(3));
        expect(activeCount, equals(2));
      });

      test('should calculate team size correctly', () async {
        // Setup multi-level team
        await fakeFirestore.collection('users').doc('leader').set({
          'fullName': 'Leader',
        });

        await fakeFirestore.collection('users').doc('level1_1').set({
          'fullName': 'Level 1-1',
          'referredBy': 'leader',
          'membershipPaid': true,
        });

        await fakeFirestore.collection('users').doc('level1_2').set({
          'fullName': 'Level 1-2',
          'referredBy': 'leader',
          'membershipPaid': false,
        });

        await fakeFirestore.collection('users').doc('level2_1').set({
          'fullName': 'Level 2-1',
          'referredBy': 'level1_1',
          'membershipPaid': true,
        });

        final teamSize = await ReferralChainService.calculateTeamSize('leader');
        final activeTeamSize = await ReferralChainService.calculateActiveTeamSize('leader');

        expect(teamSize, equals(3));
        expect(activeTeamSize, equals(2));
      });
    });

    group('Chain Statistics', () {
      test('should get comprehensive chain statistics', () async {
        await fakeFirestore.collection('users').doc('user').set({
          'fullName': 'Test User',
          'referredBy': 'uplineUser',
        });

        await fakeFirestore.collection('users').doc('uplineUser').set({
          'fullName': 'Upline User',
        });

        await fakeFirestore.collection('users').doc('downline1').set({
          'fullName': 'Downline 1',
          'referredBy': 'user',
          'membershipPaid': true,
        });

        await fakeFirestore.collection('users').doc('downline2').set({
          'fullName': 'Downline 2',
          'referredBy': 'user',
          'membershipPaid': false,
        });

        final stats = await ReferralChainService.getChainStatistics('user');

        expect(stats['userId'], equals('user'));
        expect(stats['directReferrals'], equals(2));
        expect(stats['activeDirectReferrals'], equals(1));
        expect(stats['teamSize'], equals(2));
        expect(stats['activeTeamSize'], equals(1));
        expect(stats['chainDepth'], equals(1)); // 1 level up from root
        expect(stats['uplineCount'], equals(1));
      });
    });

    group('Chain Validation', () {
      test('should validate chain integrity', () async {
        await fakeFirestore.collection('users').doc('validUser').set({
          'fullName': 'Valid User',
          'referredBy': 'existingReferrer',
        });

        await fakeFirestore.collection('users').doc('existingReferrer').set({
          'fullName': 'Existing Referrer',
        });

        final validation = await ReferralChainService.validateChainIntegrity('validUser');

        expect(validation['isValid'], isTrue);
        expect(validation['issues'], isEmpty);
        expect(validation['chainLength'], equals(2));
      });

      test('should detect missing referrer', () async {
        await fakeFirestore.collection('users').doc('orphanUser').set({
          'fullName': 'Orphan User',
          'referredBy': 'missingReferrer',
        });

        final validation = await ReferralChainService.validateChainIntegrity('orphanUser');

        expect(validation['isValid'], isFalse);
        expect(validation['issues'], isNotEmpty);
        expect(validation['issues'][0], contains('Referrer does not exist'));
      });
    });

    group('Error Handling', () {
      test('should create ReferralChainException correctly', () {
        const message = 'Test chain error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};

        final exception = ReferralChainException(message, code, context);

        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test chain error';
        final exception = ReferralChainException(message);

        expect(exception.code, equals('REFERRAL_CHAIN_FAILED'));
        expect(exception.context, isNull);
      });
    });

    group('Batch Operations', () {
      test('should batch update statistics for multiple users', () async {
        final userIds = ['user1', 'user2', 'user3'];

        // Setup test users
        for (final userId in userIds) {
          await fakeFirestore.collection('users').doc(userId).set({
            'fullName': 'User $userId',
            'directReferrals': 0,
            'teamSize': 0,
          });
        }

        await ReferralChainService.batchUpdateStatistics(userIds);

        // Verify all users were updated
        for (final userId in userIds) {
          final userDoc = await fakeFirestore.collection('users').doc(userId).get();
          final userData = userDoc.data()!;
          expect(userData.containsKey('lastStatsUpdate'), isTrue);
        }
      });
    });

    group('Chain Depth and Root Finding', () {
      test('should calculate chain depth correctly', () async {
        // Setup chain: A -> B -> C
        await fakeFirestore.collection('users').doc('userA').set({
          'fullName': 'User A',
          'referredBy': null,
        });

        await fakeFirestore.collection('users').doc('userB').set({
          'fullName': 'User B',
          'referredBy': 'userA',
        });

        await fakeFirestore.collection('users').doc('userC').set({
          'fullName': 'User C',
          'referredBy': 'userB',
        });

        final depthC = await ReferralChainService.getChainDepth('userC');
        final depthB = await ReferralChainService.getChainDepth('userB');
        final depthA = await ReferralChainService.getChainDepth('userA');

        expect(depthC, equals(2)); // 2 levels from root
        expect(depthB, equals(1)); // 1 level from root
        expect(depthA, equals(0)); // Is the root
      });

      test('should find chain root correctly', () async {
        // Setup chain: A -> B -> C
        await fakeFirestore.collection('users').doc('userA').set({
          'fullName': 'User A',
          'referredBy': null,
        });

        await fakeFirestore.collection('users').doc('userB').set({
          'fullName': 'User B',
          'referredBy': 'userA',
        });

        await fakeFirestore.collection('users').doc('userC').set({
          'fullName': 'User C',
          'referredBy': 'userB',
        });

        final rootFromC = await ReferralChainService.findChainRoot('userC');
        final rootFromB = await ReferralChainService.findChainRoot('userB');
        final rootFromA = await ReferralChainService.findChainRoot('userA');

        expect(rootFromC, equals('userA'));
        expect(rootFromB, equals('userA'));
        expect(rootFromA, equals('userA'));
      });
    });
  });
}
