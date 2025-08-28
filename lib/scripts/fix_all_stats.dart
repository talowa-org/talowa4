import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/referral/comprehensive_stats_service.dart';

/// Script to fix all user statistics in the database
/// This should be run once to ensure all stats are accurate
class FixAllStatsScript {
  
  /// Run the comprehensive stats fix
  static Future<void> runFix() async {
    try {
      debugPrint('🚀 Starting comprehensive stats fix...');
      
      final result = await ComprehensiveStatsService.fixAllUserStats();
      
      if (result['success'] == true) {
        debugPrint('✅ Stats fix completed successfully!');
        debugPrint('📊 Results:');
        debugPrint('   Total users: ${result['totalUsers']}');
        debugPrint('   Processed: ${result['processed']}');
        debugPrint('   Updated: ${result['updated']}');
        debugPrint('   Errors: ${result['errors']}');
      } else {
        debugPrint('❌ Stats fix failed: ${result['error']}');
      }
      
    } catch (e) {
      debugPrint('❌ Error running stats fix: $e');
    }
  }
  
  /// Fix stats for a specific user
  static Future<void> fixUserStats(String userId) async {
    try {
      debugPrint('🔧 Fixing stats for user: $userId');
      
      final result = await ComprehensiveStatsService.updateUserStats(userId);
      
      debugPrint('✅ User stats updated:');
      debugPrint('   Direct Referrals: ${result['directReferrals']}');
      debugPrint('   Team Size: ${result['teamSize']}');
      debugPrint('   Role: ${result['currentRole']}');
      
    } catch (e) {
      debugPrint('❌ Error fixing user stats: $e');
    }
  }
  
  /// Validate all user stats are consistent
  static Future<Map<String, dynamic>> validateAllStats() async {
    try {
      debugPrint('🔍 Validating all user stats...');
      
      final firestore = FirebaseFirestore.instance;
      final usersQuery = await firestore.collection('users').get();
      
      int totalUsers = 0;
      int inconsistentUsers = 0;
      final List<String> inconsistentUserIds = [];
      
      for (final userDoc in usersQuery.docs) {
        totalUsers++;
        final userData = userDoc.data();
        final userId = userDoc.id;
        final referralCode = userData['referralCode'] as String? ?? '';
        
        if (referralCode.isEmpty) continue;
        
        // Check direct referrals consistency
        final directReferralsQuery = await firestore
            .collection('users')
            .where('referredBy', isEqualTo: referralCode)
            .get();
        
        final actualDirectReferrals = directReferralsQuery.docs.length;
        final storedDirectReferrals = userData['directReferrals'] as int? ?? 0;
        
        // Check team size consistency
        final teamSizeQuery = await firestore
            .collection('users')
            .where('referralChain', arrayContains: userId)
            .get();
        
        final actualTeamSize = teamSizeQuery.docs.length;
        final storedTeamSize = userData['teamSize'] as int? ?? 0;
        
        if (actualDirectReferrals != storedDirectReferrals || 
            actualTeamSize != storedTeamSize) {
          inconsistentUsers++;
          inconsistentUserIds.add(userId);
          
          debugPrint('⚠️ Inconsistent stats for ${userData['fullName']} ($userId):');
          debugPrint('   Direct: stored=$storedDirectReferrals, actual=$actualDirectReferrals');
          debugPrint('   Team: stored=$storedTeamSize, actual=$actualTeamSize');
        }
      }
      
      final result = {
        'totalUsers': totalUsers,
        'inconsistentUsers': inconsistentUsers,
        'inconsistentUserIds': inconsistentUserIds,
        'consistencyRate': totalUsers > 0 ? ((totalUsers - inconsistentUsers) / totalUsers * 100).round() : 100,
        'validatedAt': DateTime.now().toIso8601String(),
      };
      
      debugPrint('📊 Validation Results:');
      debugPrint('   Total Users: $totalUsers');
      debugPrint('   Inconsistent: $inconsistentUsers');
      debugPrint('   Consistency Rate: ${result['consistencyRate']}%');
      
      return result;
      
    } catch (e) {
      debugPrint('❌ Error validating stats: $e');
      return {
        'error': e.toString(),
        'success': false,
      };
    }
  }
  
  /// Fix only inconsistent user stats
  static Future<void> fixInconsistentStats() async {
    try {
      debugPrint('🔧 Finding and fixing inconsistent stats...');
      
      final validation = await validateAllStats();
      final inconsistentUserIds = validation['inconsistentUserIds'] as List<String>? ?? [];
      
      if (inconsistentUserIds.isEmpty) {
        debugPrint('✅ All stats are consistent!');
        return;
      }
      
      debugPrint('🔄 Fixing ${inconsistentUserIds.length} inconsistent users...');
      
      int fixed = 0;
      int errors = 0;
      
      for (final userId in inconsistentUserIds) {
        try {
          await ComprehensiveStatsService.updateUserStats(userId);
          fixed++;
          debugPrint('✅ Fixed stats for user: $userId');
        } catch (e) {
          errors++;
          debugPrint('❌ Error fixing user $userId: $e');
        }
      }
      
      debugPrint('📊 Fix Results:');
      debugPrint('   Fixed: $fixed');
      debugPrint('   Errors: $errors');
      debugPrint('   Success Rate: ${inconsistentUserIds.isNotEmpty ? (fixed / inconsistentUserIds.length * 100).round() : 100}%');
      
    } catch (e) {
      debugPrint('❌ Error fixing inconsistent stats: $e');
    }
  }
}