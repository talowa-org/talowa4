import 'package:cloud_firestore/cloud_firestore.dart';

/// Exception thrown when referral chain operations fail
class ReferralChainException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const ReferralChainException(this.message, [this.code = 'REFERRAL_CHAIN_FAILED', this.context]);
  
  @override
  String toString() => 'ReferralChainException: $message';
}

/// Service for managing referral chains and calculating statistics
class ReferralChainService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Get direct referrals for a user
  static Future<List<Map<String, dynamic>>> getDirectReferrals(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return [];
      }
      
      final userData = userDoc.data()!;
      final referralCode = userData['referralCode'] as String?;
      
      if (referralCode == null) {
        return [];
      }
      
      final query = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: referralCode)
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fullName': data['fullName'] ?? 'Unknown',
          'membershipPaid': data['membershipPaid'] ?? false,
          'isActive': data['isActive'] ?? true,
          'createdAt': data['createdAt'],
          'referralCode': data['referralCode'],
        };
      }).toList();
    } catch (e) {
      throw ReferralChainException(
        'Failed to get direct referrals for user $userId: $e',
        'DIRECT_REFERRALS_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Calculate team size (all downline users)
  static Future<int> calculateTeamSize(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .get();
      
      return query.docs.length;
    } catch (e) {
      throw ReferralChainException(
        'Failed to calculate team size for user $userId: $e',
        'TEAM_SIZE_CALCULATION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Calculate active team size (paid members only)
  static Future<int> calculateActiveTeamSize(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .where('membershipPaid', isEqualTo: true)
          .get();
      
      return query.docs.length;
    } catch (e) {
      throw ReferralChainException(
        'Failed to calculate active team size for user $userId: $e',
        'ACTIVE_TEAM_SIZE_CALCULATION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get chain statistics for a user
  static Future<Map<String, dynamic>> getChainStatistics(String userId) async {
    try {
      final directReferrals = await getDirectReferrals(userId);
      final teamSize = await calculateTeamSize(userId);
      final activeTeamSize = await calculateActiveTeamSize(userId);
      
      final activeDirectReferrals = directReferrals
          .where((user) => user['membershipPaid'] == true)
          .length;
      
      // Calculate chain depth
      final chainDepth = await _calculateChainDepth(userId);
      
      return {
        'directReferrals': directReferrals.length,
        'activeDirectReferrals': activeDirectReferrals,
        'teamSize': teamSize,
        'activeTeamSize': activeTeamSize,
        'chainDepth': chainDepth,
        'calculatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw ReferralChainException(
        'Failed to get chain statistics for user $userId: $e',
        'CHAIN_STATISTICS_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Calculate the maximum depth of the referral chain
  static Future<int> _calculateChainDepth(String userId) async {
    try {
      int maxDepth = 0;
      
      // Get all users in the chain
      final query = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .get();
      
      for (final doc in query.docs) {
        final data = doc.data();
        final chain = List<String>.from(data['referralChain'] ?? []);
        
        // Find the position of current user in the chain
        final userIndex = chain.indexOf(userId);
        if (userIndex != -1) {
          final depth = chain.length - userIndex;
          if (depth > maxDepth) {
            maxDepth = depth;
          }
        }
      }
      
      return maxDepth;
    } catch (e) {
      return 0; // Return 0 if calculation fails
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
  
  /// Get referral chain for a user (upline)
  static Future<List<Map<String, dynamic>>> getReferralChain(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return [];
      }
      
      final userData = userDoc.data()!;
      final chain = List<String>.from(userData['referralChain'] ?? []);
      
      final chainUsers = <Map<String, dynamic>>[];
      
      for (final chainUserId in chain) {
        final chainUserDoc = await _firestore.collection('users').doc(chainUserId).get();
        if (chainUserDoc.exists) {
          final chainUserData = chainUserDoc.data()!;
          chainUsers.add({
            'id': chainUserId,
            'fullName': chainUserData['fullName'] ?? 'Unknown',
            'currentRole': chainUserData['currentRole'] ?? 'member',
            'referralCode': chainUserData['referralCode'],
          });
        }
      }
      
      return chainUsers;
    } catch (e) {
      throw ReferralChainException(
        'Failed to get referral chain for user $userId: $e',
        'REFERRAL_CHAIN_RETRIEVAL_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get all downline users for a user
  static Future<List<Map<String, dynamic>>> getDownlineUsers(String userId, {int? maxDepth}) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId);
      
      final results = await query.get();
      
      final downlineUsers = <Map<String, dynamic>>[];
      
      for (final doc in results.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final chain = List<String>.from(data['referralChain'] ?? []);
        
        // Calculate depth from current user
        final userIndex = chain.indexOf(userId);
        if (userIndex != -1) {
          final depth = chain.length - userIndex;
          
          // Apply max depth filter if specified
          if (maxDepth != null && depth > maxDepth) {
            continue;
          }
          
          downlineUsers.add({
            'id': doc.id,
            'fullName': data['fullName'] ?? 'Unknown',
            'currentRole': data['currentRole'] ?? 'member',
            'membershipPaid': data['membershipPaid'] ?? false,
            'depth': depth,
            'referralCode': data['referralCode'],
            'createdAt': data['createdAt'],
          });
        }
      }
      
      // Sort by depth and then by creation date
      downlineUsers.sort((a, b) {
        final depthComparison = (a['depth'] as int).compareTo(b['depth'] as int);
        if (depthComparison != 0) return depthComparison;
        
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;
        if (aDate != null && bDate != null) {
          return bDate.compareTo(aDate); // Newest first
        }
        return 0;
      });
      
      return downlineUsers;
    } catch (e) {
      throw ReferralChainException(
        'Failed to get downline users for user $userId: $e',
        'DOWNLINE_USERS_FAILED',
        {'userId': userId, 'maxDepth': maxDepth}
      );
    }
  }
}