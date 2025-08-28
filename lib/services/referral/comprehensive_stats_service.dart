import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Comprehensive service to ensure all referral statistics are accurate and up-to-date
class ComprehensiveStatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update all statistics for a user by recalculating from actual data
  static Future<Map<String, dynamic>> updateUserStats(String userId) async {
    try {
      debugPrint('🔄 Updating comprehensive stats for user: $userId');

      // Get user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found: $userId');
      }

      final userData = userDoc.data()!;
      final referralCode = userData['referralCode'] as String? ?? '';

      if (referralCode.isEmpty) {
        debugPrint('⚠️ User has no referral code, skipping stats update');
        return {
          'directReferrals': 0,
          'teamSize': 0,
          'teamReferrals': 0,
          'currentRole': userData['role'] ?? 'Member',
          'updated': false,
        };
      }

      // Calculate direct referrals (users who used this user's referral code)
      final directReferralsQuery = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: referralCode)
          .get();

      final directReferrals = directReferralsQuery.docs.length;

      // Calculate team size (users who have this user in their referral chain)
      final teamSizeQuery = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .get();

      final teamSize = teamSizeQuery.docs.length;

      // Update user document with calculated stats
      await userDoc.reference.update({
        'directReferrals': directReferrals,
        'teamSize': teamSize,
        'teamReferrals': teamSize, // Keep both fields for compatibility
        'lastStatsUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Updated stats for ${userData['fullName']}: Direct=$directReferrals, Team=$teamSize');

      return {
        'directReferrals': directReferrals,
        'teamSize': teamSize,
        'teamReferrals': teamSize,
        'currentRole': userData['role'] ?? 'Member',
        'referralCode': referralCode,
        'updated': true,
      };

    } catch (e) {
      debugPrint('❌ Error updating user stats: $e');
      rethrow;
    }
  }

  /// Get current stats for a user (with option to force recalculation)
  static Future<Map<String, dynamic>> getUserStats(String userId, {bool forceRecalculate = false}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'directReferrals': 0,
          'teamSize': 0,
          'teamReferrals': 0,
          'currentRole': 'Member',
          'error': 'User not found',
        };
      }

      final userData = userDoc.data()!;

      // Check if we need to recalculate
      final lastUpdate = userData['lastStatsUpdate'] as Timestamp?;
      final needsUpdate = forceRecalculate || 
          lastUpdate == null || 
          DateTime.now().difference(lastUpdate.toDate()).inMinutes > 5;

      if (needsUpdate) {
        return await updateUserStats(userId);
      }

      // Return cached stats
      return {
        'directReferrals': userData['directReferrals'] ?? 0,
        'teamSize': userData['teamSize'] ?? 0,
        'teamReferrals': userData['teamReferrals'] ?? userData['teamSize'] ?? 0,
        'currentRole': userData['role'] ?? 'Member',
        'referralCode': userData['referralCode'] ?? '',
        'lastUpdate': lastUpdate?.toDate(),
        'cached': true,
      };

    } catch (e) {
      debugPrint('❌ Error getting user stats: $e');
      return {
        'directReferrals': 0,
        'teamSize': 0,
        'teamReferrals': 0,
        'currentRole': 'Member',
        'error': e.toString(),
      };
    }
  }

  /// Fix all stats for all users (admin function)
  static Future<Map<String, dynamic>> fixAllUserStats({int batchSize = 50}) async {
    try {
      debugPrint('🔧 Starting comprehensive stats fix for all users...');

      // Get all users
      final usersQuery = await _firestore.collection('users').get();
      final totalUsers = usersQuery.docs.length;
      
      int processed = 0;
      int updated = 0;
      int errors = 0;

      // Process in batches
      for (int i = 0; i < usersQuery.docs.length; i += batchSize) {
        final batch = usersQuery.docs.skip(i).take(batchSize);
        
        for (final userDoc in batch) {
          try {
            final result = await updateUserStats(userDoc.id);
            if (result['updated'] == true) {
              updated++;
            }
            processed++;
          } catch (e) {
            debugPrint('❌ Error updating stats for user ${userDoc.id}: $e');
            errors++;
            processed++;
          }
        }

        // Small delay between batches
        if (i + batchSize < usersQuery.docs.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }

        debugPrint('📊 Progress: $processed/$totalUsers users processed');
      }

      final result = {
        'totalUsers': totalUsers,
        'processed': processed,
        'updated': updated,
        'errors': errors,
        'success': errors == 0,
        'completedAt': DateTime.now().toIso8601String(),
      };

      debugPrint('✅ Stats fix completed: $result');
      return result;

    } catch (e) {
      debugPrint('❌ Error in comprehensive stats fix: $e');
      return {
        'error': e.toString(),
        'success': false,
      };
    }
  }

  /// Get stats summary for dashboard display
  static Future<Map<String, dynamic>> getStatsSummary(String userId) async {
    try {
      final stats = await getUserStats(userId);
      
      // Calculate role progression
      final roleProgression = _calculateRoleProgression(
        stats['directReferrals'] as int,
        stats['teamSize'] as int,
        stats['currentRole'] as String,
      );

      return {
        'current': stats,
        'roleProgression': roleProgression,
        'generatedAt': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      debugPrint('❌ Error getting stats summary: $e');
      return {
        'error': e.toString(),
        'current': {
          'directReferrals': 0,
          'teamSize': 0,
          'currentRole': 'Member',
        },
      };
    }
  }

  /// Calculate role progression based on current stats
  static Map<String, dynamic>? _calculateRoleProgression(int directReferrals, int teamSize, String currentRole) {
    // Talowa's complete 9-level role system
    final roles = [
      {'level': 1, 'name': 'Member', 'directRequired': 0, 'teamRequired': 0},
      {'level': 2, 'name': 'Active Member', 'directRequired': 10, 'teamRequired': 10},
      {'level': 3, 'name': 'Team Leader', 'directRequired': 20, 'teamRequired': 100},
      {'level': 4, 'name': 'Area Coordinator', 'directRequired': 40, 'teamRequired': 700},
      {'level': 5, 'name': 'Mandal Coordinator', 'directRequired': 80, 'teamRequired': 6000},
      {'level': 6, 'name': 'Constituency Coordinator', 'directRequired': 160, 'teamRequired': 50000},
      {'level': 7, 'name': 'District Coordinator', 'directRequired': 320, 'teamRequired': 500000},
      {'level': 8, 'name': 'Zonal Coordinator', 'directRequired': 500, 'teamRequired': 1000000},
      {'level': 9, 'name': 'State Coordinator', 'directRequired': 1000, 'teamRequired': 3000000},
    ];

    // Find current role index
    int currentIndex = 0;
    for (int i = 0; i < roles.length; i++) {
      if (roles[i]['name'].toString().toLowerCase() == currentRole.toLowerCase()) {
        currentIndex = i;
        break;
      }
    }

    // Check if already at highest role
    if (currentIndex >= roles.length - 1) {
      return null; // Already at highest role
    }

    // Find next role
    final nextRole = roles[currentIndex + 1];
    final directRequired = nextRole['directRequired'] as int;
    final teamRequired = nextRole['teamRequired'] as int;

    final directProgress = directRequired > 0 
        ? ((directReferrals / directRequired) * 100).clamp(0, 100)
        : 100.0;
    
    final teamProgress = teamRequired > 0
        ? ((teamSize / teamRequired) * 100).clamp(0, 100)
        : 100.0;

    final overallProgress = (directProgress * teamProgress / 100).clamp(0, 100).round();

    return {
      'nextRole': {
        'name': nextRole['name'],
        'level': nextRole['level'],
      },
      'requirements': {
        'directReferrals': {
          'current': directReferrals,
          'required': directRequired,
          'progress': directProgress.round(),
        },
        'teamSize': {
          'current': teamSize,
          'required': teamRequired,
          'progress': teamProgress.round(),
        },
      },
      'overallProgress': overallProgress,
      'readyForPromotion': directReferrals >= directRequired && teamSize >= teamRequired,
    };
  }

  /// Stream real-time stats for a user
  static Stream<Map<String, dynamic>> streamUserStats(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return {
          'directReferrals': 0,
          'teamSize': 0,
          'teamReferrals': 0,
          'currentRole': 'Member',
          'error': 'User not found',
        };
      }

      final data = snapshot.data()!;
      return {
        'directReferrals': data['directReferrals'] ?? 0,
        'teamSize': data['teamSize'] ?? 0,
        'teamReferrals': data['teamReferrals'] ?? data['teamSize'] ?? 0,
        'currentRole': data['role'] ?? 'Member',
        'referralCode': data['referralCode'] ?? '',
        'lastUpdate': data['lastStatsUpdate'],
        'realtime': true,
      };
    });
  }
}