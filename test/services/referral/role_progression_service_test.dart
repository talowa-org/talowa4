import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:talowa/services/referral/role_progression_service.dart';

void main() {
  group('RoleProgressionService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      RoleProgressionService.setFirestoreInstance(fakeFirestore);
    });

    group('Role Definitions', () {
      test('should have correct role hierarchy', () {
        final hierarchy = RoleProgressionService.getRoleHierarchy();
        
        expect(hierarchy.length, equals(10));
        expect(hierarchy[0], equals('member'));
        expect(hierarchy[1], equals('activist'));
        expect(hierarchy[9], equals('national_coordinator'));
      });

      test('should have all role definitions', () {
        final definitions = RoleProgressionService.getAllRoleDefinitions();
        
        expect(definitions.length, equals(10));
        expect(definitions.containsKey('member'), isTrue);
        expect(definitions.containsKey('national_coordinator'), isTrue);
        
        // Check member role
        final memberRole = definitions['member']!;
        expect(memberRole.name, equals('Member'));
        expect(memberRole.directReferralsRequired, equals(0));
        expect(memberRole.teamSizeRequired, equals(0));
        
        // Check highest role
        final nationalRole = definitions['national_coordinator']!;
        expect(nationalRole.name, equals('National Coordinator'));
        expect(nationalRole.directReferralsRequired, equals(200));
        expect(nationalRole.teamSizeRequired, equals(15000));
      });
    });

    group('Role Progression Check', () {
      test('should not promote user without membership payment', () async {
        const userId = 'unpaid_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Unpaid User',
          'currentRole': 'member',
          'membershipPaid': false,
          'activeDirectReferrals': 10,
          'activeTeamSize': 100,
        });

        final result = await RoleProgressionService.checkAndUpdateRole(userId);

        expect(result['promoted'], isFalse);
        expect(result['reason'], contains('Membership payment required'));
      });

      test('should promote user when requirements are met', () async {
        const userId = 'eligible_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Eligible User',
          'email': 'eligible@example.com',
          'currentRole': 'member',
          'membershipPaid': true,
          'activeDirectReferrals': 5,
          'activeTeamSize': 15,
        });

        final result = await RoleProgressionService.checkAndUpdateRole(userId);

        expect(result['promoted'], isTrue);
        expect(result['previousRole'], equals('member'));
        expect(result['currentRole'], equals('organizer'));

        // Verify user document was updated
        final userDoc = await fakeFirestore.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        expect(userData['currentRole'], equals('organizer'));
        expect(userData['previousRole'], equals('member'));
      });

      test('should not promote if requirements not met', () async {
        const userId = 'not_eligible_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Not Eligible User',
          'currentRole': 'member',
          'membershipPaid': true,
          'activeDirectReferrals': 1,
          'activeTeamSize': 3,
        });

        final result = await RoleProgressionService.checkAndUpdateRole(userId);

        expect(result['promoted'], isFalse);
        expect(result['currentRole'], equals('member'));
        expect(result['nextRoleRequirements'], isNotNull);
      });

      test('should handle user not found', () async {
        expect(
          () => RoleProgressionService.checkAndUpdateRole('nonexistent_user'),
          throwsA(isA<RoleProgressionException>()),
        );
      });
    });

    group('Role Progression Status', () {
      test('should get comprehensive progression status', () async {
        const userId = 'status_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Status User',
          'currentRole': 'activist',
          'membershipPaid': true,
          'activeDirectReferrals': 3,
          'activeTeamSize': 8,
          'rolePromotionHistory': [
            {
              'from': 'member',
              'to': 'activist',
              'promotedAt': '2024-01-01T00:00:00.000Z',
            }
          ],
        });

        final status = await RoleProgressionService.getRoleProgressionStatus(userId);

        expect(status['userId'], equals(userId));
        expect(status['currentRole'], equals('activist'));
        expect(status['directReferrals'], equals(3));
        expect(status['teamSize'], equals(8));
        expect(status['nextRole'], isNotNull);
        expect(status['progress'], isNotNull);
        
        // Check progress calculations
        final progress = status['progress'] as Map<String, dynamic>;
        expect(progress['directReferrals']['current'], equals(3));
        expect(progress['directReferrals']['required'], equals(5)); // Organizer requirement
        expect(progress['teamSize']['current'], equals(8));
        expect(progress['teamSize']['required'], equals(15)); // Organizer requirement
      });

      test('should handle highest role with no next role', () async {
        const userId = 'highest_role_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Highest Role User',
          'currentRole': 'national_coordinator',
          'membershipPaid': true,
          'activeDirectReferrals': 300,
          'activeTeamSize': 20000,
        });

        final status = await RoleProgressionService.getRoleProgressionStatus(userId);

        expect(status['currentRole'], equals('national_coordinator'));
        expect(status['nextRole'], isNull);
        expect(status['progress'], isNull);
      });
    });

    group('Permissions', () {
      test('should check user permissions correctly', () async {
        const userId = 'permission_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Permission User',
          'currentRole': 'team_leader',
          'membershipPaid': true,
        });

        final hasBasicAccess = await RoleProgressionService.hasPermission(userId, 'basic_access');
        final hasManageTeam = await RoleProgressionService.hasPermission(userId, 'manage_team');
        final hasStateGovernance = await RoleProgressionService.hasPermission(userId, 'state_governance');

        expect(hasBasicAccess, isTrue);
        expect(hasManageTeam, isTrue);
        expect(hasStateGovernance, isFalse);
      });

      test('should return false for non-existent user', () async {
        final hasPermission = await RoleProgressionService.hasPermission('nonexistent', 'basic_access');
        expect(hasPermission, isFalse);
      });
    });

    group('Users by Role', () {
      test('should get users by specific role', () async {
        // Setup multiple users with different roles
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'User 1',
          'email': 'user1@example.com',
          'currentRole': 'organizer',
          'membershipPaid': true,
          'activeDirectReferrals': 5,
          'activeTeamSize': 15,
        });

        await fakeFirestore.collection('users').doc('user2').set({
          'fullName': 'User 2',
          'email': 'user2@example.com',
          'currentRole': 'organizer',
          'membershipPaid': true,
          'activeDirectReferrals': 7,
          'activeTeamSize': 20,
        });

        await fakeFirestore.collection('users').doc('user3').set({
          'fullName': 'User 3',
          'email': 'user3@example.com',
          'currentRole': 'team_leader',
          'membershipPaid': true,
          'activeDirectReferrals': 12,
          'activeTeamSize': 60,
        });

        final organizers = await RoleProgressionService.getUsersByRole('organizer');

        expect(organizers.length, equals(2));
        expect(organizers[0]['currentRole'], equals('organizer'));
        expect(organizers[1]['currentRole'], equals('organizer'));
      });

      test('should return empty list for role with no users', () async {
        final users = await RoleProgressionService.getUsersByRole('national_coordinator');
        expect(users, isEmpty);
      });
    });

    group('Role Distribution Statistics', () {
      test('should calculate role distribution correctly', () async {
        // Setup users with different roles
        await fakeFirestore.collection('users').doc('member1').set({
          'currentRole': 'member',
          'membershipPaid': true,
        });

        await fakeFirestore.collection('users').doc('member2').set({
          'currentRole': 'member',
          'membershipPaid': true,
        });

        await fakeFirestore.collection('users').doc('activist1').set({
          'currentRole': 'activist',
          'membershipPaid': true,
        });

        await fakeFirestore.collection('users').doc('unpaid').set({
          'currentRole': 'member',
          'membershipPaid': false, // Should not be counted
        });

        final stats = await RoleProgressionService.getRoleDistributionStats();

        expect(stats['totalUsers'], equals(3)); // Only paid users
        expect(stats['distribution']['member'], equals(2));
        expect(stats['distribution']['activist'], equals(1));
        expect(stats['distribution']['organizer'], equals(0));
      });
    });

    group('Batch Operations', () {
      test('should batch check role progressions', () async {
        final userIds = ['batch1', 'batch2', 'batch3'];

        // Setup users
        for (int i = 0; i < userIds.length; i++) {
          await fakeFirestore.collection('users').doc(userIds[i]).set({
            'fullName': 'Batch User ${i + 1}',
            'email': 'batch${i + 1}@example.com',
            'currentRole': 'member',
            'membershipPaid': true,
            'activeDirectReferrals': i * 3, // 0, 3, 6
            'activeTeamSize': i * 10, // 0, 10, 20
          });
        }

        final results = await RoleProgressionService.batchCheckRoleProgressions(userIds);

        expect(results.length, equals(3));
        
        for (final result in results) {
          expect(result['success'], isTrue);
          expect(result['userId'], isIn(userIds));
        }
      });

      test('should handle errors in batch processing', () async {
        final userIds = ['existing_user', 'nonexistent_user'];

        // Setup only one user
        await fakeFirestore.collection('users').doc('existing_user').set({
          'fullName': 'Existing User',
          'currentRole': 'member',
          'membershipPaid': true,
          'activeDirectReferrals': 0,
          'activeTeamSize': 0,
        });

        final results = await RoleProgressionService.batchCheckRoleProgressions(userIds);

        expect(results.length, equals(2));
        expect(results[0]['success'], isTrue);
        expect(results[1]['success'], isFalse);
        expect(results[1]['error'], isNotNull);
      });
    });

    group('Error Handling', () {
      test('should create RoleProgressionException correctly', () {
        const message = 'Test role progression error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};

        final exception = RoleProgressionException(message, code, context);

        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test role progression error';
        final exception = const RoleProgressionException(message);

        expect(exception.code, equals('ROLE_PROGRESSION_FAILED'));
        expect(exception.context, isNull);
      });
    });

    group('Role Hierarchy Logic', () {
      test('should determine correct eligible role', () async {
        const userId = 'hierarchy_user';
        
        // Test user eligible for team_leader (10 direct, 50 team)
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Hierarchy User',
          'currentRole': 'member',
          'membershipPaid': true,
          'activeDirectReferrals': 15,
          'activeTeamSize': 75,
        });

        final result = await RoleProgressionService.checkAndUpdateRole(userId);

        expect(result['promoted'], isTrue);
        expect(result['currentRole'], equals('team_leader'));
      });

      test('should not skip roles in progression', () async {
        const userId = 'progression_user';
        
        // User meets requirements for higher roles but should progress step by step
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Progression User',
          'currentRole': 'member',
          'membershipPaid': true,
          'activeDirectReferrals': 100,
          'activeTeamSize': 1000,
        });

        final result = await RoleProgressionService.checkAndUpdateRole(userId);

        expect(result['promoted'], isTrue);
        // Should be promoted to the highest eligible role, not step by step
        expect(result['currentRole'], equals('area_coordinator'));
      });
    });

    group('Location-Based Roles', () {
      test('should handle location-based role requirements', () async {
        const userId = 'location_user';
        
        await fakeFirestore.collection('users').doc(userId).set({
          'fullName': 'Location User',
          'currentRole': 'coordinator',
          'membershipPaid': true,
          'activeDirectReferrals': 40,
          'activeTeamSize': 700,
          'location': {
            'type': 'urban',
            'city': 'Mumbai',
            'state': 'Maharashtra',
          },
        });

        final result = await RoleProgressionService.checkAndUpdateRole(userId);

        expect(result['promoted'], isTrue);
        expect(result['currentRole'], equals('district_coordinator'));
      });
    });
  });
}
