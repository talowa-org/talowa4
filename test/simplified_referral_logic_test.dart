import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simplified Referral System Logic Tests', () {
    test('Role calculation works correctly', () {
      // Test member role (starting role)
      expect(calculateRole(0, 0), 'Member');
      
      // Test activist role
      expect(calculateRole(2, 5), 'Activist');
      expect(calculateRole(4, 10), 'Activist');
      
      // Test organizer role
      expect(calculateRole(5, 15), 'Organizer');
      expect(calculateRole(8, 25), 'Organizer');
      
      // Test team leader role
      expect(calculateRole(10, 50), 'Team Leader');
      expect(calculateRole(15, 75), 'Team Leader');
      
      // Test coordinator role
      expect(calculateRole(20, 150), 'Coordinator');
      expect(calculateRole(25, 200), 'Coordinator');
      
      // Test area coordinator role
      expect(calculateRole(30, 350), 'Area Coordinator');
      expect(calculateRole(35, 500), 'Area Coordinator');
      
      // Test district coordinator role
      expect(calculateRole(40, 700), 'District Coordinator');
      expect(calculateRole(50, 1000), 'District Coordinator');
      
      // Test regional coordinator role
      expect(calculateRole(60, 1500), 'Regional Coordinator');
      expect(calculateRole(80, 3000), 'Regional Coordinator');
      
      // Test state coordinator role
      expect(calculateRole(100, 5000), 'State Coordinator');
      expect(calculateRole(150, 8000), 'State Coordinator');
      
      // Test national coordinator role
      expect(calculateRole(200, 15000), 'National Coordinator');
      expect(calculateRole(500, 50000), 'National Coordinator');
    });

    test('Referral code generation format is correct', () {
      final code = generateReferralCode();
      
      // Should start with TAL
      expect(code.startsWith('TAL'), true);
      
      // Should be 9 characters total (TAL + 6 chars)
      expect(code.length, 9);
      
      // Should only contain alphanumeric characters
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(code), true);
    });

    test('User registration simulation works', () {
      final user = simulateUserRegistration(
        name: 'Test User',
        email: 'test@example.com',
        referralCode: null,
      );

      expect(user['name'], 'Test User');
      expect(user['email'], 'test@example.com');
      expect(user['status'], 'active');
      expect(user['membershipPaid'], true);
      expect(user['directReferrals'], 0);
      expect(user['teamSize'], 0);
      expect(user['role'], 'member');
      expect(user['referralCode'], isNotNull);
      expect(user['referralCode'], startsWith('TAL'));
    });

    test('Referrer statistics update correctly', () {
      final referrer = {
        'name': 'Referrer',
        'directReferrals': 5,
        'teamSize': 15, // Meets organizer team size requirement
        'role': 'Organizer',
      };

      final newUser = {
        'name': 'New User',
        'referredBy': 'TAL123ABC',
      };

      final updated = updateReferrerStatistics(referrer, newUser);

      expect(updated['directReferrals'], 6);
      expect(updated['teamSize'], 16);
      expect(updated['role'], 'Organizer'); // Still organizer, needs 10 direct referrals for team leader
    });

    test('Role progression happens at correct thresholds', () {
      Map<String, dynamic> user = {
        'name': 'Test User',
        'directReferrals': 0,
        'teamSize': 0,
        'role': 'Member',
      };

      // Add referrals one by one and check role progression
      for (int i = 1; i <= 25; i++) {
        final newUser = {'name': 'User $i'};
        user = updateReferrerStatistics(user, newUser);

        if (i == 5) {
          expect(user['role'], 'Activist'); // 2+ direct and 5+ team size
        } else if (i == 15) {
          expect(user['role'], 'Organizer'); // 5+ direct and 15+ team size
        }
      }
    });

    test('Simplified system benefits are maintained', () {
      // Test that all users start with active status
      final user1 = simulateUserRegistration(
        name: 'User 1',
        email: 'user1@test.com',
        referralCode: null,
      );
      
      expect(user1['status'], 'active');
      expect(user1['membershipPaid'], true);

      // Test that referred users also start active
      final user2 = simulateUserRegistration(
        name: 'User 2',
        email: 'user2@test.com',
        referralCode: user1['referralCode'],
      );
      
      expect(user2['status'], 'active');
      expect(user2['membershipPaid'], true);
      expect(user2['referredBy'], user1['referralCode']);
    });

    test('Referral codes have correct format', () {
      // Generate a few codes and check format
      for (int i = 0; i < 5; i++) {
        final code = generateReferralCode();
        
        // Check format requirements
        expect(code.startsWith('TAL'), true, reason: 'Code should start with TAL');
        expect(code.length, 9, reason: 'Code should be 9 characters long');
        expect(RegExp(r'^[A-Z0-9]+$').hasMatch(code), true, reason: 'Code should only contain alphanumeric characters');
      }
    });
  });
}

/// Calculate role based on referrals and team size (same logic as demo)
String calculateRole(int directReferrals, int teamSize) {
  if (directReferrals >= 200 && teamSize >= 15000) return 'National Coordinator';
  if (directReferrals >= 100 && teamSize >= 5000) return 'State Coordinator';
  if (directReferrals >= 60 && teamSize >= 1500) return 'Regional Coordinator';
  if (directReferrals >= 40 && teamSize >= 700) return 'District Coordinator';
  if (directReferrals >= 30 && teamSize >= 350) return 'Area Coordinator';
  if (directReferrals >= 20 && teamSize >= 150) return 'Coordinator';
  if (directReferrals >= 10 && teamSize >= 50) return 'Team Leader';
  if (directReferrals >= 5 && teamSize >= 15) return 'Organizer';
  if (directReferrals >= 2 && teamSize >= 5) return 'Activist';
  return 'Member';
}

/// Simulate user registration (same logic as demo)
Map<String, dynamic> simulateUserRegistration({
  required String name,
  required String email,
  String? referralCode,
}) {
  final newReferralCode = generateReferralCode();
  
  return {
    'name': name,
    'email': email,
    'referralCode': newReferralCode,
    'referredBy': referralCode,
    'status': 'active', // Always active in simplified system
    'directReferrals': 0,
    'teamSize': 0,
    'role': 'member',
    'membershipPaid': true, // Always true in simplified system
    'createdAt': DateTime.now().toIso8601String(),
  };
}

/// Update referrer statistics (same logic as demo)
Map<String, dynamic> updateReferrerStatistics(
  Map<String, dynamic> referrer,
  Map<String, dynamic> newUser,
) {
  final updatedReferrer = Map<String, dynamic>.from(referrer);
  
  // Increment statistics
  updatedReferrer['directReferrals'] = (updatedReferrer['directReferrals'] as int) + 1;
  updatedReferrer['teamSize'] = (updatedReferrer['teamSize'] as int) + 1;
  
  // Check for role progression
  final directReferrals = updatedReferrer['directReferrals'] as int;
  final teamSize = updatedReferrer['teamSize'] as int;
  
  updatedReferrer['role'] = calculateRole(directReferrals, teamSize);
  
  return updatedReferrer;
}

/// Generate referral code (improved for uniqueness)
String generateReferralCode() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  
  String code = 'TAL';
  for (int i = 0; i < 6; i++) {
    final index = (timestamp + i * 1000 + i * i) % chars.length;
    code += chars[index];
  }
  
  return code;
}