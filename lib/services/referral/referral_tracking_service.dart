import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/referral/referral_models.dart';
import 'referral_lookup_service.dart';

/// Exception thrown when referral tracking fails
class ReferralTrackingException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const ReferralTrackingException(this.message, [this.code = 'REFERRAL_TRACKING_FAILED', this.context]);
  
  @override
  String toString() => 'ReferralTrackingException: $message';
}

/// Service for tracking referral relationships and statistics
class ReferralTrackingService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Records referral relationship and immediately activates it
  static Future<void> recordReferralRelationship({
    required String newUserId,
    required String referralCode,
  }) async {
    final batch = _firestore.batch();
    
    try {
      // Validate referral code
      final referrerData = await _validateReferralCode(referralCode);
      if (referrerData == null) {
        throw ReferralTrackingException(
          'Invalid referral code: $referralCode',
          'INVALID_REFERRAL_CODE',
          {'referralCode': referralCode}
        );
      }
      
      final referralChain = await _buildReferralChain(referrerData['uid']);
      
      // Update new user with referral info
      final userRef = _firestore.collection('users').doc(newUserId);
      batch.update(userRef, {
        'referredBy': referralCode,
        'referralChain': referralChain,
        'referralStatus': 'active', // Immediately active in simplified system
        'referralRecordedAt': FieldValue.serverTimestamp(),
      });
      
      // Immediately update referral chain statistics
      await _updateReferralChainStatistics(batch, referralChain, newUserId);
      
      // Check for role progressions
      await _checkRoleProgressions(batch, referralChain);
      
      await batch.commit();
      
      // Track referral event
      await _trackReferralEvent('referral_activated', {
        'referrer_id': referrerData['uid'],
        'referee_id': newUserId,
        'referral_code': referralCode,
      });
      
      // Send notifications
      await _sendReferralActivationNotifications(referralChain, newUserId);
      
      // Award achievements for milestones
      await _checkAndAwardAchievements(referralChain);
      
    } catch (e) {
      await _logReferralError('record_referral_relationship', e, {
        'new_user_id': newUserId,
        'referral_code': referralCode,
      });
      rethrow;
    }
  }
  
  /// Legacy method - no longer needed in simplified system
  @deprecated
  static Future<void> activateReferralChain(String userId) async {
    // In simplified system, referrals are activated immediately upon registration
    // This method is kept for backward compatibility but does nothing
    print('activateReferralChain called but not needed in simplified system');
  }
  
  /// Validates referral code and returns referrer data
  static Future<Map<String, dynamic>?> _validateReferralCode(String code) async {
    try {
      final validationResult = await ReferralLookupService.validateReferralCode(code);
      return validationResult;
    } catch (e) {
      return null;
    }
  }
  
  /// Builds referral chain for a user
  static Future<List<String>> _buildReferralChain(String referrerUserId) async {
    try {
      final referrerDoc = await _firestore.collection('users').doc(referrerUserId).get();
      if (!referrerDoc.exists) {
        return [referrerUserId];
      }
      
      final referrerData = referrerDoc.data()!;
      final existingChain = List<String>.from(referrerData['referralChain'] ?? []);
      
      // Add current referrer to the chain
      return [...existingChain, referrerUserId];
    } catch (e) {
      // Return minimal chain on error
      return [referrerUserId];
    }
  }
  
  /// Updates referral chain statistics
  static Future<void> _updateReferralChainStatistics(
    WriteBatch batch,
    List<dynamic> referralChain,
    String newUserId,
  ) async {
    for (final userId in referralChain) {
      final userRef = _firestore.collection('users').doc(userId);
      
      // Update direct referral count for immediate referrer
      if (userId == referralChain.last) {
        batch.update(userRef, {
          'directReferrals': FieldValue.increment(1),
          'directReferralsList': FieldValue.arrayUnion([newUserId]),
        });
      }
      
      // Update team size for all in chain (using UserModel field names)
      batch.update(userRef, {
        'teamSize': FieldValue.increment(1),
        'teamReferrals': FieldValue.increment(1),
        'lastTeamUpdate': FieldValue.serverTimestamp(),
      });
    }
  }
  
  /// Checks and updates role progressions for referral chain
  static Future<void> _checkRoleProgressions(WriteBatch batch, List<dynamic> referralChain) async {
    for (final userId in referralChain) {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) continue;
      
      final directReferrals = userData['directReferrals'] as int? ?? 0;
      final teamSize = userData['teamSize'] as int? ?? 0;
      final currentRole = userData['currentRole'] as String? ?? 'member';
      final location = userData['address'] as Map<String, dynamic>?;
      final isUrban = location?['type'] == 'urban';
      
      final newRole = _calculateNewRole(directReferrals, teamSize, currentRole, isUrban);
      
      if (newRole.toString() != currentRole) {
        batch.update(userDoc.reference, {
          'currentRole': newRole.toString(),
          'rolePromotedAt': FieldValue.serverTimestamp(),
          'previousRole': currentRole,
        });
        
        // Queue role promotion notification
        await _queueRolePromotionNotification(userId, newRole, directReferrals, teamSize);
      }
    }
  }
  
  /// Calculates new role based on direct referrals and team size
  static UserRole _calculateNewRole(int directReferrals, int teamSize, String currentRole, bool isUrban) {
    if (directReferrals >= 1000 && teamSize >= 3000000) return UserRole.state_coordinator;
    if (directReferrals >= 500 && teamSize >= 1000000) return UserRole.zonal_regional_coordinator;
    if (directReferrals >= 320 && teamSize >= 500000) return UserRole.district_coordinator;
    if (directReferrals >= 160 && teamSize >= 50000) return UserRole.constituency_coordinator;
    if (directReferrals >= 80 && teamSize >= 6000) return UserRole.mandal_coordinator;
    if (directReferrals >= 40 && teamSize >= 700) {
      return isUrban ? UserRole.area_coordinator_urban : UserRole.village_coordinator_rural;
    }
    if (directReferrals >= 20 && teamSize >= 100) return UserRole.coordinator;
    if (directReferrals >= 10) return UserRole.team_leader;
    return UserRole.member;
  }
  
  /// Tracks referral event for analytics
  static Future<void> _trackReferralEvent(String eventType, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('referralEvents').add({
        'eventType': eventType,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't fail the main operation for analytics errors
      print('Warning: Failed to track referral event: $e');
    }
  }
  
  /// Logs referral error
  static Future<void> _logReferralError(String operation, dynamic error, Map<String, dynamic> context) async {
    try {
      await _firestore.collection('referralErrors').add({
        'operation': operation,
        'error': error.toString(),
        'context': context,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to log referral error: $e');
    }
  }
  
  /// Sends referral activation notifications
  static Future<void> _sendReferralActivationNotifications(List<dynamic> referralChain, String newUserId) async {
    // Implementation would depend on notification service
    // For now, just log the event
    print('Sending referral activation notifications for user $newUserId to chain: $referralChain');
  }
  
  /// Checks and awards achievements
  static Future<void> _checkAndAwardAchievements(List<dynamic> referralChain) async {
    // Implementation would depend on achievement service
    // For now, just log the event
    print('Checking achievements for referral chain: $referralChain');
  }
  
  /// Queues role promotion notification
  static Future<void> _queueRolePromotionNotification(String userId, UserRole newRole, int directReferrals, int teamSize) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'role_promotion',
        'title': 'Congratulations! Role Promotion',
        'body': 'You have been promoted to ${newRole.toString().replaceAll('_', ' ').toUpperCase()}!',
        'data': {
          'newRole': newRole.toString(),
          'directReferrals': directReferrals,
          'teamSize': teamSize,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Warning: Failed to queue role promotion notification: $e');
    }
  }
  
  /// Gets referral statistics for a user
  static Future<Map<String, dynamic>> getUserReferralStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'directReferrals': 0,
          'totalTeamSize': 0,
          'currentRole': 'member',
          'referralCode': null,
        };
      }
      
      final userData = userDoc.data()!;
      return {
        'directReferrals': userData['directReferrals'] ?? 0,
        'totalTeamSize': userData['teamSize'] ?? 0,
        'teamReferrals': userData['teamReferrals'] ?? userData['teamSize'] ?? 0,
        'currentRole': userData['role'] ?? 'member',
        'referralCode': userData['referralCode'],
        'referralChain': userData['referralChain'] ?? [],
        'membershipPaid': userData['membershipPaid'] ?? false, // Use actual payment status
      };
    } catch (e) {
      throw ReferralTrackingException(
        'Failed to get referral stats for user $userId: $e',
        'STATS_RETRIEVAL_FAILED',
        {'userId': userId, 'error': e.toString()}
      );
    }
  }
}

