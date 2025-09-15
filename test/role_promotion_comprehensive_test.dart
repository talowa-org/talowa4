import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:talowa/services/referral/role_progression_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() async {
    // Initialize Firebase for testing
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: 'test-app-id',
          messagingSenderId: 'test-sender-id',
          projectId: 'test-project',
          storageBucket: 'test-bucket.appspot.com',
        ),
      );
    } catch (e) {
      // Firebase might already be initialized
      print('Firebase initialization: $e');
    }
  });
  
  group('Role Promotion System Tests', () {

    // Test each role transition
    final testCases = [
      {'from': 'member', 'to': 'volunteer', 'direct': 10, 'team': 10},
      {'from': 'volunteer', 'to': 'team_leader', 'direct': 20, 'team': 100},
      {'from': 'team_leader', 'to': 'area_coordinator', 'direct': 40, 'team': 700},
      {'from': 'area_coordinator', 'to': 'mandal_coordinator', 'direct': 80, 'team': 6000},
      {'from': 'mandal_coordinator', 'to': 'constituency_coordinator', 'direct': 160, 'team': 50000},
      {'from': 'constituency_coordinator', 'to': 'district_coordinator', 'direct': 320, 'team': 500000},
      {'from': 'district_coordinator', 'to': 'zonal_regional_coordinator', 'direct': 500, 'team': 1500000},
      {'from': 'zonal_regional_coordinator', 'to': 'state_coordinator', 'direct': 1000, 'team': 3000000},
    ];

    for (final testCase in testCases) {
      test('Should validate promotion requirements from ${testCase['from']} to ${testCase['to']}', () {
        // Test role definition validation
        final fromRole = RoleProgressionService.ROLE_DEFINITIONS[testCase['from']];
        final toRole = RoleProgressionService.ROLE_DEFINITIONS[testCase['to']];
        
        expect(fromRole, isNotNull, reason: 'Source role ${testCase['from']} should be defined');
        expect(toRole, isNotNull, reason: 'Target role ${testCase['to']} should be defined');
        
        // Verify promotion requirements
         expect(toRole!.directReferralsRequired, equals(testCase['direct']),
             reason: 'Direct referrals requirement should match for ${testCase['to']}');
         expect(toRole.teamSizeRequired, equals(testCase['team']),
             reason: 'Team size requirement should match for ${testCase['to']}');
        
        // Verify level progression
        expect(toRole.level, greaterThan(fromRole!.level),
            reason: 'Target role level should be higher than source role level');
      });
    }

    // Boundary condition tests
    group('Boundary Condition Tests', () {
      test('Should validate Member role requirements', () {
        final memberRole = RoleProgressionService.ROLE_DEFINITIONS['member'];
        final volunteerRole = RoleProgressionService.ROLE_DEFINITIONS['volunteer'];
        
        expect(memberRole, isNotNull);
        expect(volunteerRole, isNotNull);
        
        // Test boundary conditions for promotion to Volunteer
         expect(volunteerRole!.directReferralsRequired, equals(10));
         expect(volunteerRole.teamSizeRequired, equals(10));
        
        // Verify that Member is the starting role
        expect(memberRole!.level, equals(1));
        expect(volunteerRole.level, equals(2));
      });

      test('Should validate all role level progressions', () {
        final roles = ['member', 'volunteer', 'team_leader', 'area_coordinator', 
                      'mandal_coordinator', 'constituency_coordinator', 
                      'district_coordinator', 'zonal_regional_coordinator', 'state_coordinator'];
        
        for (int i = 0; i < roles.length; i++) {
          final role = RoleProgressionService.ROLE_DEFINITIONS[roles[i]];
          expect(role, isNotNull, reason: 'Role ${roles[i]} should be defined');
          expect(role!.level, equals(i + 1), reason: 'Role ${roles[i]} should have level ${i + 1}');
        }
      });

      test('Should validate increasing requirements across roles', () {
        final roles = ['member', 'volunteer', 'team_leader', 'area_coordinator'];
        
        for (int i = 1; i < roles.length; i++) {
          final currentRole = RoleProgressionService.ROLE_DEFINITIONS[roles[i]];
          final previousRole = RoleProgressionService.ROLE_DEFINITIONS[roles[i-1]];
          
          expect(currentRole!.directReferralsRequired, 
                  greaterThan(previousRole!.directReferralsRequired),
                  reason: 'Direct referrals should increase from ${roles[i-1]} to ${roles[i]}');
           expect(currentRole.teamSizeRequired, 
                  greaterThan(previousRole.teamSizeRequired),
                  reason: 'Team size should increase from ${roles[i-1]} to ${roles[i]}');
        }
      });
    });

    // Role definition validation tests
    group('Role Definition Validation Tests', () {
      test('Should validate all role definitions exist', () {
         final expectedRoles = {
           'member': {'level': 1, 'name': 'Member'},
           'volunteer': {'level': 2, 'name': 'Volunteer'},
           'team_leader': {'level': 3, 'name': 'Team Leader'},
           'area_coordinator': {'level': 4, 'name': 'Area Coordinator'},
           'mandal_coordinator': {'level': 5, 'name': 'Mandal Coordinator'},
           'constituency_coordinator': {'level': 6, 'name': 'Constituency Coordinator'},
           'district_coordinator': {'level': 7, 'name': 'District Coordinator'},
           'zonal_regional_coordinator': {'level': 8, 'name': 'Zonal Regional Coordinator'},
           'state_coordinator': {'level': 9, 'name': 'State Coordinator'},
         };
         
         expectedRoles.forEach((roleKey, roleData) {
           final role = RoleProgressionService.ROLE_DEFINITIONS[roleKey];
           expect(role, isNotNull, reason: 'Role $roleKey should be defined');
           expect(role!.level, equals(roleData['level']), 
                  reason: 'Role $roleKey should have level ${roleData['level']}');
           expect(role.name, equals(roleData['name']), 
                  reason: 'Role name should be ${roleData['name']}');
         });
      });
      
      test('Should validate role requirements are positive numbers', () {
         RoleProgressionService.ROLE_DEFINITIONS.forEach((roleName, role) {
           expect(role.directReferralsRequired, greaterThanOrEqualTo(0),
                  reason: 'Direct referrals for $roleName should be non-negative');
           expect(role.teamSizeRequired, greaterThanOrEqualTo(0),
                  reason: 'Team size for $roleName should be non-negative');
           expect(role.level, greaterThan(0),
                  reason: 'Level for $roleName should be positive');
         });
       });
     });
   });
 }