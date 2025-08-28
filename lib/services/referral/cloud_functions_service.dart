import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Service to handle referral system Cloud Functions
class CloudFunctionsService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Process referral chain for a user
  static Future<bool> processReferral(String userId) async {
    try {
      debugPrint('🔄 Calling processReferral Cloud Function for user: $userId');
      
      final callable = _functions.httpsCallable('processReferral');
      final result = await callable.call({'userId': userId});
      
      debugPrint('✅ processReferral result: ${result.data}');
      return result.data['success'] ?? false;
    } catch (e) {
      debugPrint('❌ Error calling processReferral: $e');
      return false;
    }
  }

  /// Auto-promote user based on referral stats
  static Future<Map<String, dynamic>?> autoPromoteUser(String userId) async {
    try {
      debugPrint('🔄 Calling autoPromoteUser Cloud Function for user: $userId');
      
      final callable = _functions.httpsCallable('autoPromoteUser');
      final result = await callable.call({'userId': userId});
      
      debugPrint('✅ autoPromoteUser result: ${result.data}');
      return result.data;
    } catch (e) {
      debugPrint('❌ Error calling autoPromoteUser: $e');
      return null;
    }
  }

  /// Fix orphaned users (admin function)
  static Future<bool> fixOrphanedUsers() async {
    try {
      debugPrint('🔄 Calling fixOrphanedUsers Cloud Function');
      
      final callable = _functions.httpsCallable('fixOrphanedUsers');
      final result = await callable.call();
      
      debugPrint('✅ fixOrphanedUsers result: ${result.data}');
      return result.data['success'] ?? false;
    } catch (e) {
      debugPrint('❌ Error calling fixOrphanedUsers: $e');
      return false;
    }
  }

  /// Process referral and auto-promote in sequence
  static Future<void> processReferralAndPromote(String userId) async {
    try {
      // First process the referral chain
      final referralProcessed = await processReferral(userId);
      
      if (referralProcessed) {
        // Then check for auto-promotion
        await autoPromoteUser(userId);
      }
    } catch (e) {
      debugPrint('❌ Error in processReferralAndPromote: $e');
    }
  }
}