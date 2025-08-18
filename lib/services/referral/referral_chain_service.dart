import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/referral/referral_models.dart';

/// Exception thrown when referral chain operations fail
class ReferralChainException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const ReferralChainException(this.message, [this.code = 'REFERRAL_CHAIN_FAILED', this.context]);
  
  @override
  String toString() => 'ReferralChainException: $message';
}

/// Service for managing referral chains and hierarchical relationships
class ReferralChainService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int MAX_CHAIN_DEPTH = 50; // Prevent infinite loops
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Build complete referral chain for a user
  static Future<List<String>> buildReferralChain(String userId) async {
    try {
      final chain = <String>[];
      String? currentUserId = userId;
      int depth = 0;
      
      while (currentUserId != null && depth < MAX_CHAIN_DEPTH) {
        chain.add(currentUserId);
        
        // Get user's referrer
        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        if (!userDoc.exists) {
          break;
        }
        
        final userData = userDoc.data()!;
        currentUserId = userData['referredBy'] as String?;
        depth++;
      }
      
      return chain;
    } catch (e) {
      throw ReferralChainException(
        'Failed to build referral chain: $e',
        'CHAIN_BUILD_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get upline chain (all users above in hierarchy)
  static Future<List<Map<String, dynamic>>> getUplineChain(String userId) async {
    try {
      final upline = <Map<String, dynamic>>[];
      String? currentUserId = userId;
      int depth = 0;
      
      while (currentUserId != null && depth < MAX_CHAIN_DEPTH) {
        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        if (!userDoc.exists) {
          break;
        }
        
        final userData = userDoc.data()!;
        final referredBy = userData['referredBy'] as String?;
        
        if (referredBy != null) {
          // Get referrer data
          final referrerDoc = await _firestore.collection('users').doc(referredBy).get();
          if (referrerDoc.exists) {
            final referrerData = referrerDoc.data()!;
            upline.add({
              'userId': referredBy,
              'fullName': referrerData['fullName'],
              'email': referrerData['email'],
              'currentRole': referrerData['currentRole'] ?? 'member',
              'membershipPaid': referrerData['membershipPaid'] ?? false,
              'level': depth + 1,
            });
          }
        }
        
        currentUserId = referredBy;
        depth++;
      }
      
      return upline;
    } catch (e) {
      throw ReferralChainException(
        'Failed to get upline chain: $e',
        'UPLINE_RETRIEVAL_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get downline chain (all users below in hierarchy)
  static Future<List<Map<String, dynamic>>> getDownlineChain(String userId, {int maxDepth = 10}) async {
    try {
      final downline = <Map<String, dynamic>>[];
      await _buildDownlineRecursive(userId, downline, 0, maxDepth);
      return downline;
    } catch (e) {
      throw ReferralChainException(
        'Failed to get downline chain: $e',
        'DOWNLINE_RETRIEVAL_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Recursively build downline chain
  static Future<void> _buildDownlineRecursive(
    String userId,
    List<Map<String, dynamic>> downline,
    int currentDepth,
    int maxDepth,
  ) async {
    if (currentDepth >= maxDepth) return;
    
    // Get direct referrals
    final directReferrals = await _firestore
        .collection('users')
        .where('referredBy', isEqualTo: userId)
        .get();
    
    for (final doc in directReferrals.docs) {
      final userData = doc.data();
      downline.add({
        'userId': doc.id,
        'fullName': userData['fullName'],
        'email': userData['email'],
        'currentRole': userData['currentRole'] ?? 'member',
        'membershipPaid': userData['membershipPaid'] ?? false,
        'level': currentDepth + 1,
        'registeredAt': userData['registeredAt'],
      });
      
      // Recursively get their referrals
      await _buildDownlineRecursive(doc.id, downline, currentDepth + 1, maxDepth);
    }
  }
  
  /// Get direct referrals only
  static Future<List<Map<String, dynamic>>> getDirectReferrals(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'fullName': data['fullName'],
          'email': data['email'],
          'currentRole': data['currentRole'] ?? 'member',
          'membershipPaid': data['membershipPaid'] ?? false,
          'registeredAt': data['registeredAt'],
          'referralCode': data['referralCode'],
        };
      }).toList();
    } catch (e) {
      throw ReferralChainException(
        'Failed to get direct referrals: $e',
        'DIRECT_REFERRALS_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Calculate team size (total downline)
  static Future<int> calculateTeamSize(String userId) async {
    try {
      final downline = await getDownlineChain(userId, maxDepth: MAX_CHAIN_DEPTH);
      return downline.length;
    } catch (e) {
      throw ReferralChainException(
        'Failed to calculate team size: $e',
        'TEAM_SIZE_CALCULATION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Calculate active team size (paid members only)
  static Future<int> calculateActiveTeamSize(String userId) async {
    try {
      final downline = await getDownlineChain(userId, maxDepth: MAX_CHAIN_DEPTH);
      return downline.where((user) => user['membershipPaid'] == true).length;
    } catch (e) {
      throw ReferralChainException(
        'Failed to calculate active team size: $e',
        'ACTIVE_TEAM_SIZE_CALCULATION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Count direct referrals
  static Future<int> countDirectReferrals(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .get();
      
      return query.docs.length;
    } catch (e) {
      throw ReferralChainException(
        'Failed to count direct referrals: $e',
        'DIRECT_COUNT_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Count active direct referrals (paid members only)
  static Future<int> countActiveDirectReferrals(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .where('membershipPaid', isEqualTo: true)
          .get();
      
      return query.docs.length;
    } catch (e) {
      throw ReferralChainException(
        'Failed to count active direct referrals: $e',
        'ACTIVE_DIRECT_COUNT_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Update referral chain for all upline users
  static Future<void> updateUplineChains(String userId) async {
    try {
      final upline = await getUplineChain(userId);
      final batch = _firestore.batch();
      
      for (final user in upline) {
        final userRef = _firestore.collection('users').doc(user['userId']);
        
        // Recalculate statistics for this user
        final directCount = await countDirectReferrals(user['userId']);
        final activeDirectCount = await countActiveDirectReferrals(user['userId']);
        final teamSize = await calculateTeamSize(user['userId']);
        final activeTeamSize = await calculateActiveTeamSize(user['userId']);
        
        batch.update(userRef, {
          'directReferrals': directCount,
          'activeDirectReferrals': activeDirectCount,
          'teamSize': teamSize,
          'activeTeamSize': activeTeamSize,
          'lastStatsUpdate': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      throw ReferralChainException(
        'Failed to update upline chains: $e',
        'UPLINE_UPDATE_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get chain depth for a user
  static Future<int> getChainDepth(String userId) async {
    try {
      final chain = await buildReferralChain(userId);
      return chain.length - 1; // Subtract 1 because chain includes the user themselves
    } catch (e) {
      throw ReferralChainException(
        'Failed to get chain depth: $e',
        'DEPTH_CALCULATION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Find chain root (top-level user)
  static Future<String> findChainRoot(String userId) async {
    try {
      final chain = await buildReferralChain(userId);
      return chain.last; // Last user in chain is the root
    } catch (e) {
      throw ReferralChainException(
        'Failed to find chain root: $e',
        'ROOT_FINDING_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get chain statistics
  static Future<Map<String, dynamic>> getChainStatistics(String userId) async {
    try {
      final directReferrals = await countDirectReferrals(userId);
      final activeDirectReferrals = await countActiveDirectReferrals(userId);
      final teamSize = await calculateTeamSize(userId);
      final activeTeamSize = await calculateActiveTeamSize(userId);
      final chainDepth = await getChainDepth(userId);
      final uplineChain = await getUplineChain(userId);
      
      return {
        'userId': userId,
        'directReferrals': directReferrals,
        'activeDirectReferrals': activeDirectReferrals,
        'teamSize': teamSize,
        'activeTeamSize': activeTeamSize,
        'chainDepth': chainDepth,
        'uplineCount': uplineChain.length,
        'calculatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw ReferralChainException(
        'Failed to get chain statistics: $e',
        'STATISTICS_CALCULATION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Validate chain integrity
  static Future<Map<String, dynamic>> validateChainIntegrity(String userId) async {
    try {
      final issues = <String>[];
      final warnings = <String>[];
      
      // Check for circular references
      final chain = await buildReferralChain(userId);
      final uniqueUsers = chain.toSet();
      if (uniqueUsers.length != chain.length) {
        issues.add('Circular reference detected in referral chain');
      }
      
      // Check for orphaned users
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final referredBy = userData['referredBy'] as String?;
        
        if (referredBy != null) {
          final referrerDoc = await _firestore.collection('users').doc(referredBy).get();
          if (!referrerDoc.exists) {
            issues.add('Referrer does not exist: $referredBy');
          }
        }
      }
      
      // Check chain depth
      if (chain.length > MAX_CHAIN_DEPTH) {
        warnings.add('Chain depth exceeds maximum: ${chain.length}');
      }
      
      return {
        'isValid': issues.isEmpty,
        'issues': issues,
        'warnings': warnings,
        'chainLength': chain.length,
        'validatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw ReferralChainException(
        'Failed to validate chain integrity: $e',
        'VALIDATION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Batch update statistics for multiple users
  static Future<void> batchUpdateStatistics(List<String> userIds) async {
    try {
      final batch = _firestore.batch();
      
      for (final userId in userIds) {
        final stats = await getChainStatistics(userId);
        final userRef = _firestore.collection('users').doc(userId);
        
        batch.update(userRef, {
          'directReferrals': stats['directReferrals'],
          'activeDirectReferrals': stats['activeDirectReferrals'],
          'teamSize': stats['teamSize'],
          'activeTeamSize': stats['activeTeamSize'],
          'chainDepth': stats['chainDepth'],
          'lastStatsUpdate': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      throw ReferralChainException(
        'Failed to batch update statistics: $e',
        'BATCH_UPDATE_FAILED',
        {'userIds': userIds}
      );
    }
  }
}
