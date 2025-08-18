import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Configuration for the referral system
class ReferralConfig {
  static const String defaultReferrerCode = 'TALADMIN';
  static const bool fallbackEnabled = true;
  static const String adminEmail = '+917981828388@talowa.app';
  static const String adminPhone = '+91 7981828388';
  
  // Monitoring thresholds
  static const double maxFallbackPercentage = 25.0;
  static const int fallbackAlertThreshold = 100; // Alert after 100 fallback assignments
  
  // Admin user details
  static const Map<String, dynamic> adminUserProfile = {
    'fullName': 'Talowa Admin',
    'email': adminEmail,
    'phone': adminPhone,
    'role': 'regional_coordinator',
    'status': 'active',
    'membershipPaid': true,
    'isSystemAdmin': true,
    'directReferralCount': 0,
    'totalTeamSize': 0,
    'referralCode': defaultReferrerCode,
    'referralChain': <String>[],
  };
  
  /// Bootstrap the admin user and referral code
  static Future<void> bootstrapAdminUser() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Check if admin referral code exists
      final codeDoc = await firestore
          .collection('referralCodes')
          .doc(defaultReferrerCode)
          .get();
      
      String adminUid;
      
      if (!codeDoc.exists) {
        // Create admin user first
        adminUid = await _createAdminUser();
        
        // Create admin referral code
        await firestore
            .collection('referralCodes')
            .doc(defaultReferrerCode)
            .set({
          'code': defaultReferrerCode,
          'uid': adminUid,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'clickCount': 0,
          'conversionCount': 0,
          'isSystemAdmin': true,
        });
        
        if (kDebugMode) {
          print('Created admin referral code: $defaultReferrerCode');
        }
      } else {
        // Get existing admin UID
        final codeData = codeDoc.data()!;
        adminUid = codeData['uid'];
        
        // Verify admin user exists and update if needed
        await _verifyAndUpdateAdminUser(adminUid);
        
        // Ensure referral code is active
        if (codeData['isActive'] != true) {
          await firestore
              .collection('referralCodes')
              .doc(defaultReferrerCode)
              .update({'isActive': true});
        }
      }
      
      if (kDebugMode) {
        print('Admin user bootstrap completed. UID: $adminUid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error bootstrapping admin user: $e');
      }
      rethrow;
    }
  }
  
  /// Create the admin user
  static Future<String> _createAdminUser() async {
    final firestore = FirebaseFirestore.instance;
    
    // Generate a deterministic admin UID based on email
    final adminUid = 'admin_${adminEmail.hashCode.abs()}';
    
    await firestore
        .collection('users')
        .doc(adminUid)
        .set({
      ...adminUserProfile,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    if (kDebugMode) {
      print('Created admin user with UID: $adminUid');
    }
    
    return adminUid;
  }
  
  /// Verify and update admin user if needed
  static Future<void> _verifyAndUpdateAdminUser(String adminUid) async {
    final firestore = FirebaseFirestore.instance;
    
    final userDoc = await firestore
        .collection('users')
        .doc(adminUid)
        .get();
    
    if (!userDoc.exists) {
      // Create admin user if it doesn't exist
      await firestore
          .collection('users')
          .doc(adminUid)
          .set({
        ...adminUserProfile,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('Created missing admin user: $adminUid');
      }
    } else {
      // Update admin user to ensure correct configuration
      final userData = userDoc.data()!;
      final updates = <String, dynamic>{};
      
      // Ensure required fields are set correctly
      if (userData['referralCode'] != defaultReferrerCode) {
        updates['referralCode'] = defaultReferrerCode;
      }
      
      if (userData['role'] != 'regional_coordinator') {
        updates['role'] = 'regional_coordinator';
      }
      
      if (userData['status'] != 'active') {
        updates['status'] = 'active';
      }
      
      if (userData['membershipPaid'] != true) {
        updates['membershipPaid'] = true;
      }
      
      if (userData['isSystemAdmin'] != true) {
        updates['isSystemAdmin'] = true;
      }
      
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        
        await firestore
            .collection('users')
            .doc(adminUid)
            .update(updates);
        
        if (kDebugMode) {
          print('Updated admin user fields: ${updates.keys.join(', ')}');
        }
      }
    }
  }
  
  /// Get the admin user UID
  static Future<String> getAdminUid() async {
    final firestore = FirebaseFirestore.instance;
    
    final codeDoc = await firestore
        .collection('referralCodes')
        .doc(defaultReferrerCode)
        .get();
    
    if (!codeDoc.exists) {
      throw Exception('Admin referral code not found. Run bootstrap first.');
    }
    
    return codeDoc.data()!['uid'];
  }
  
  /// Verify admin configuration is valid
  static Future<bool> verifyAdminConfiguration() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Check referral code exists and is active
      final codeDoc = await firestore
          .collection('referralCodes')
          .doc(defaultReferrerCode)
          .get();
      
      if (!codeDoc.exists || codeDoc.data()!['isActive'] != true) {
        return false;
      }
      
      // Check admin user exists and has correct referral code
      final adminUid = codeDoc.data()!['uid'];
      final userDoc = await firestore
          .collection('users')
          .doc(adminUid)
          .get();
      
      if (!userDoc.exists) {
        return false;
      }
      
      final userData = userDoc.data()!;
      return userData['referralCode'] == defaultReferrerCode &&
             userData['status'] == 'active' &&
             userData['membershipPaid'] == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying admin configuration: $e');
      }
      return false;
    }
  }
  
  /// Get fallback statistics
  static Future<Map<String, dynamic>> getFallbackStatistics() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get total active users
      final totalUsersQuery = await firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      
      final totalUsers = totalUsersQuery.count ?? 0;

      // Get users assigned by system (fallback)
      final fallbackUsersQuery = await firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .where('assignedBySystem', isEqualTo: true)
          .count()
          .get();

      final fallbackUsers = fallbackUsersQuery.count ?? 0;

      final fallbackPercentage = totalUsers > 0
          ? (fallbackUsers / totalUsers) * 100
          : 0.0;
      
      return {
        'totalActiveUsers': totalUsers,
        'fallbackAssignments': fallbackUsers,
        'fallbackPercentage': fallbackPercentage,
        'isAboveThreshold': fallbackPercentage > maxFallbackPercentage,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting fallback statistics: $e');
      }
      return {
        'totalActiveUsers': 0,
        'fallbackAssignments': 0,
        'fallbackPercentage': 0.0,
        'isAboveThreshold': false,
        'error': e.toString(),
      };
    }
  }
}
