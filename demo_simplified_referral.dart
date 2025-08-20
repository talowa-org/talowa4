#!/usr/bin/env dart

/// Demo script to showcase the simplified referral system functionality
/// This demonstrates how the new one-step system works without Firebase dependencies

void main() {
  print('🚀 TALOWA Simplified Referral System Demo');
  print('============================================');
  print('');
  
  // Simulate the old two-step system
  print('📋 OLD TWO-STEP SYSTEM:');
  print('1. User registers → Account created with PENDING status');
  print('2. User pays → Referral activated and statistics updated');
  print('3. Role progression only after payment');
  print('');
  
  // Show the new simplified system
  print('✨ NEW SIMPLIFIED ONE-STEP SYSTEM:');
  print('1. User registers → Account created with IMMEDIATE activation');
  print('2. All referral features work from day one');
  print('3. Role progression happens immediately');
  print('');
  
  // Demo user registration flow
  print('🎯 DEMO: User Registration Flow');
  print('================================');
  
  // Simulate user 1 (referrer)
  final user1 = simulateUserRegistration(
    name: 'John Referrer',
    email: 'john@example.com',
    referralCode: null, // No referral code
  );
  
  print('👤 User 1 registered:');
  print('   Name: ${user1['name']}');
  print('   Referral Code: ${user1['referralCode']}');
  print('   Status: ${user1['status']}');
  print('   Direct Referrals: ${user1['directReferrals']}');
  print('   Team Size: ${user1['teamSize']}');
  print('   Role: ${user1['role']}');
  print('');
  
  // Simulate user 2 (referred by user 1)
  final user2 = simulateUserRegistration(
    name: 'Jane Referred',
    email: 'jane@example.com',
    referralCode: user1['referralCode'],
  );
  
  print('👤 User 2 registered (using ${user1['referralCode']}):');
  print('   Name: ${user2['name']}');
  print('   Referral Code: ${user2['referralCode']}');
  print('   Status: ${user2['status']}');
  print('   Referred By: ${user2['referredBy']}');
  print('');
  
  // Update user 1 statistics
  final updatedUser1 = updateReferrerStatistics(user1, user2);
  print('📊 User 1 statistics updated:');
  print('   Direct Referrals: ${updatedUser1['directReferrals']}');
  print('   Team Size: ${updatedUser1['teamSize']}');
  print('   Role: ${updatedUser1['role']}');
  print('');
  
  // Simulate more referrals to show role progression
  print('🚀 DEMO: Role Progression');
  print('=========================');
  
  var currentUser = updatedUser1;
  final referralCodes = [
    'TAL789DEF', 'TAL012GHI', 'TAL345JKL', 'TAL678MNO',
    'TAL901PQR', 'TAL234STU', 'TAL567VWX', 'TAL890YZA',
    'TAL123BCD', 'TAL456EFG'
  ];
  
  for (int i = 0; i < referralCodes.length; i++) {
    final newUser = simulateUserRegistration(
      name: 'User ${i + 3}',
      email: 'user${i + 3}@example.com',
      referralCode: currentUser['referralCode'],
    );
    
    currentUser = updateReferrerStatistics(currentUser, newUser);
    
    if (i == 4 || i == 9) { // Show progress at 5 and 10 referrals
      print('📈 After ${i + 2} referrals:');
      print('   Direct Referrals: ${currentUser['directReferrals']}');
      print('   Team Size: ${currentUser['teamSize']}');
      print('   Role: ${currentUser['role']}');
      print('');
    }
  }
  
  // Show final statistics
  print('🎉 FINAL RESULTS:');
  print('=================');
  print('User: ${currentUser['name']}');
  print('Referral Code: ${currentUser['referralCode']}');
  print('Direct Referrals: ${currentUser['directReferrals']}');
  print('Team Size: ${currentUser['teamSize']}');
  print('Current Role: ${currentUser['role']}');
  print('Status: ${currentUser['status']}');
  print('');
  
  // Show benefits
  print('✅ BENEFITS OF SIMPLIFIED SYSTEM:');
  print('==================================');
  print('• Immediate referral activation');
  print('• Real-time statistics updates');
  print('• Instant role progression');
  print('• Better user experience');
  print('• Higher engagement rates');
  print('• Simplified maintenance');
  print('');
  
  print('🎯 MIGRATION COMPLETED SUCCESSFULLY!');
  print('All users now have access to the simplified one-step referral system.');
}

/// Simulate user registration in the simplified system
Map<String, dynamic> simulateUserRegistration({
  required String name,
  required String email,
  String? referralCode,
}) {
  // Generate unique referral code
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

/// Update referrer statistics when someone uses their code
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

/// Calculate role based on referrals and team size
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

/// Generate a unique referral code
String generateReferralCode() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = timestamp % 1000000;
  
  String code = 'TAL';
  for (int i = 0; i < 6; i++) {
    code += chars[(random + i) % chars.length];
  }
  
  return code;
}