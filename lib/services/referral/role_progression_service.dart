import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Exception thrown when role progression operations fail
class RoleProgressionException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const RoleProgressionException(this.message, [this.code = 'ROLE_PROGRESSION_FAILED', this.context]);
  
  @override
  String toString() => 'RoleProgressionException: $message';
}

/// Role definition with automated promotion requirements
class RoleDefinition {
  final String name;
  final int level;
  final int directReferralsRequired;
  final int teamSizeRequired;
  final List<String> permissions;
  final Map<String, dynamic> benefits;
  final bool isLocationBased;
  
  const RoleDefinition({
    required this.name,
    required this.level,
    required this.directReferralsRequired,
    required this.teamSizeRequired,
    required this.permissions,
    required this.benefits,
    this.isLocationBased = false,
  });
}

/// Automated Real-Time Role Progression Service
/// Implements the new promotion system with specified thresholds
class RoleProgressionService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Automated Role Promotion Rules (Real-Time Implementation)
  static const Map<String, RoleDefinition> ROLE_DEFINITIONS = {
    'member': RoleDefinition(
      name: 'Member',
      level: 1,
      directReferralsRequired: 0,
      teamSizeRequired: 0,
      permissions: ['basic_access'],
      benefits: {'description': 'Default role assigned to all new users'},
    ),
    'volunteer': RoleDefinition(
      name: 'Volunteer',
      level: 2,
      directReferralsRequired: 10,
      teamSizeRequired: 10,
      permissions: ['basic_access', 'share_content'],
      benefits: {'description': 'Automatic promotion when user achieves 10 direct referrals and 10 team size'},
    ),
    'team_leader': RoleDefinition(
      name: 'Team Leader',
      level: 3,
      directReferralsRequired: 20,
      teamSizeRequired: 100,
      permissions: ['basic_access', 'share_content', 'manage_team'],
      benefits: {'description': 'Automatic promotion when user achieves 20 direct referrals and 100 team size'},
    ),
    'area_coordinator': RoleDefinition(
      name: 'Area Coordinator',
      level: 4,
      directReferralsRequired: 40,
      teamSizeRequired: 700,
      permissions: ['basic_access', 'share_content', 'manage_team', 'coordinate_area'],
      benefits: {'description': 'Automatic promotion when user achieves 40 direct referrals and 700 team size'},
    ),
    'mandal_coordinator': RoleDefinition(
      name: 'Mandal Coordinator',
      level: 5,
      directReferralsRequired: 80,
      teamSizeRequired: 6000,
      permissions: ['basic_access', 'share_content', 'manage_team', 'coordinate_area', 'mandal_management'],
      benefits: {'description': 'Automatic promotion when user achieves 80 direct referrals and 6,000 team size'},
    ),
    'constituency_coordinator': RoleDefinition(
      name: 'Constituency Coordinator',
      level: 6,
      directReferralsRequired: 160,
      teamSizeRequired: 50000,
      permissions: ['basic_access', 'share_content', 'manage_team', 'coordinate_area', 'mandal_management', 'constituency_oversight'],
      benefits: {'description': 'Automatic promotion when user achieves 160 direct referrals and 50,000 team size'},
    ),
    'district_coordinator': RoleDefinition(
      name: 'District Coordinator',
      level: 7,
      directReferralsRequired: 320,
      teamSizeRequired: 500000,
      permissions: ['basic_access', 'share_content', 'manage_team', 'coordinate_area', 'mandal_management', 'constituency_oversight', 'district_leadership'],
      benefits: {'description': 'Automatic promotion when user achieves 320 direct referrals and 500,000 team size'},
      isLocationBased: true,
    ),
    'zonal_regional_coordinator': RoleDefinition(
      name: 'Zonal Regional Coordinator',
      level: 8,
      directReferralsRequired: 500,
      teamSizeRequired: 1500000,
      permissions: ['basic_access', 'share_content', 'manage_team', 'coordinate_area', 'mandal_management', 'constituency_oversight', 'district_leadership', 'regional_coordination'],
      benefits: {'description': 'Automatic promotion when user achieves 500 direct referrals and 1,500,000 team size'},
      isLocationBased: true,
    ),
    'state_coordinator': RoleDefinition(
      name: 'State Coordinator',
      level: 9,
      directReferralsRequired: 1000,
      teamSizeRequired: 3000000,
      permissions: ['basic_access', 'share_content', 'manage_team', 'coordinate_area', 'mandal_management', 'constituency_oversight', 'district_leadership', 'regional_coordination', 'state_governance'],
      benefits: {'description': 'Automatic promotion when user achieves 1000 direct referrals and 3,000,000 team size'},
      isLocationBased: true,
    ),
  };
  
  /// Role hierarchy order for automated promotions
  static const List<String> ROLE_HIERARCHY = [
    'member',
    'volunteer',
    'team_leader',
    'area_coordinator',
    'mandal_coordinator',
    'constituency_coordinator',
    'district_coordinator',
    'zonal_regional_coordinator',
    'state_coordinator',
  ];
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Real-time automated role promotion check and update
  /// Processes promotions in real-time when thresholds are met
  static Future<Map<String, dynamic>> checkAndUpdateRoleRealTime(String userId) async {
    try {
      // Get current user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw RoleProgressionException(
          'User not found: $userId',
          'USER_NOT_FOUND',
          {'userId': userId}
        );
      }
      
      final userData = userDoc.data()!;
      final currentRole = userData['role'] as String? ?? 'member';
      final currentRoleLevel = userData['currentRoleLevel'] as int? ?? 1;
      
      // Get current statistics for real-time evaluation
      final directReferrals = userData['directReferrals'] as int? ?? 0;
      final teamSize = userData['teamReferrals'] as int? ?? 0; // Using teamReferrals as team size
      
      // Determine the highest eligible role using automated promotion rules
      final eligibleRoleData = _determineHighestEligibleRole(
        directReferrals: directReferrals,
        teamSize: teamSize,
      );
      
      final eligibleRole = eligibleRoleData['role'] as String;
      final eligibleLevel = eligibleRoleData['level'] as int;
      
      // Check if promotion is needed (real-time processing)
      if (eligibleLevel > currentRoleLevel) {
        // Perform validation checks before applying promotion
        final validationResult = await _validatePromotionEligibility(userId, userData, eligibleRole);
        
        if (validationResult['valid'] == true) {
          await _promoteUserRealTime(userId, currentRole, eligibleRole, userData, directReferrals, teamSize);
          
          return {
            'promoted': true,
            'previousRole': currentRole,
            'currentRole': eligibleRole,
            'previousLevel': currentRoleLevel,
            'currentLevel': eligibleLevel,
            'directReferrals': directReferrals,
            'teamSize': teamSize,
            'promotedAt': DateTime.now().toIso8601String(),
            'promotionType': 'automated_real_time',
          };
        } else {
          // Log validation failure for audit purposes
          await _logPromotionEvent(userId, 'promotion_validation_failed', {
            'reason': validationResult['reason'],
            'currentRole': currentRole,
            'eligibleRole': eligibleRole,
            'directReferrals': directReferrals,
            'teamSize': teamSize,
          });
        }
      }
      
      return {
        'promoted': false,
        'currentRole': currentRole,
        'currentLevel': currentRoleLevel,
        'eligibleRole': eligibleRole,
        'eligibleLevel': eligibleLevel,
        'directReferrals': directReferrals,
        'teamSize': teamSize,
        'nextRoleRequirements': _getNextRoleRequirements(currentRole),
      };
      
    } catch (e) {
      if (e is RoleProgressionException) {
        rethrow;
      }
      
      throw RoleProgressionException(
        'Failed to check and update role in real-time: $e',
        'REAL_TIME_ROLE_CHECK_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Determine the highest eligible role based on automated promotion rules
  static Map<String, dynamic> _determineHighestEligibleRole({
    required int directReferrals,
    required int teamSize,
  }) {
    String eligibleRole = 'member';
    int eligibleLevel = 1;
    
    // Check roles in descending order to find the highest eligible role
    for (final role in ROLE_HIERARCHY.reversed) {
      final definition = ROLE_DEFINITIONS[role]!;
      
      // Check if user meets both direct referrals AND team size requirements
      if (directReferrals >= definition.directReferralsRequired &&
          teamSize >= definition.teamSizeRequired) {
        eligibleRole = role;
        eligibleLevel = definition.level;
        break; // Found the highest eligible role
      }
    }
    
    return {
      'role': eligibleRole,
      'level': eligibleLevel,
    };
  }
  
  /// Validate promotion eligibility with proper validation checks
  static Future<Map<String, dynamic>> _validatePromotionEligibility(
    String userId,
    Map<String, dynamic> userData,
    String targetRole,
  ) async {
    try {
      // Check if user is not admin (admins cannot be promoted)
      final currentRoleLevel = userData['currentRoleLevel'] as int? ?? 1;
      if (currentRoleLevel == 0) {
        return {
          'valid': false,
          'reason': 'Admin users cannot be promoted',
        };
      }
      
      // Check if user account is active and verified
      final isActive = userData['isActive'] as bool? ?? true;
      final isVerified = userData['isVerified'] as bool? ?? false;
      
      if (!isActive) {
        return {
          'valid': false,
          'reason': 'User account is not active',
        };
      }
      
      if (!isVerified) {
        return {
          'valid': false,
          'reason': 'User account is not verified',
        };
      }
      
      // Additional validation for location-based roles
      final roleDefinition = ROLE_DEFINITIONS[targetRole]!;
      if (roleDefinition.isLocationBased) {
        final location = userData['location'] as Map<String, dynamic>?;
        if (location == null || location.isEmpty) {
          return {
            'valid': false,
            'reason': 'Location information required for this role',
          };
        }
      }
      
      return {
        'valid': true,
        'reason': 'All validation checks passed',
      };
      
    } catch (e) {
      return {
        'valid': false,
        'reason': 'Validation error: $e',
      };
    }
  }
  
  /// Promote user to new role with real-time processing
  static Future<void> _promoteUserRealTime(
    String userId,
    String previousRole,
    String newRole,
    Map<String, dynamic> userData,
    int directReferrals,
    int teamSize,
  ) async {
    final batch = _firestore.batch();
    final promotionTimestamp = DateTime.now();
    final newRoleDefinition = ROLE_DEFINITIONS[newRole]!;
    
    // Update user document with new role
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'role': newRole,
      'currentRoleLevel': newRoleDefinition.level,
      'previousRole': previousRole,
      'rolePromotedAt': FieldValue.serverTimestamp(),
      'lastRoleUpdate': FieldValue.serverTimestamp(),
      'rolePromotionHistory': FieldValue.arrayUnion([{
        'from': previousRole,
        'to': newRole,
        'promotedAt': promotionTimestamp.toIso8601String(),
        'directReferrals': directReferrals,
        'teamSize': teamSize,
        'promotionType': 'automated_real_time',
      }]),
      'permissions': newRoleDefinition.permissions,
    });
    
    // Record promotion in audit log for tracking
    final promotionRef = _firestore.collection('rolePromotions').doc();
    batch.set(promotionRef, {
      'userId': userId,
      'userName': userData['fullName'] ?? 'Unknown',
      'userEmail': userData['email'] ?? 'Unknown',
      'previousRole': previousRole,
      'newRole': newRole,
      'previousLevel': ROLE_DEFINITIONS[previousRole]?.level ?? 1,
      'newLevel': newRoleDefinition.level,
      'directReferrals': directReferrals,
      'teamSize': teamSize,
      'location': userData['location'],
      'promotedAt': FieldValue.serverTimestamp(),
      'promotionType': 'automated_real_time',
      'validationPassed': true,
    });
    
    await batch.commit();
    
    // Log promotion event for audit purposes
    await _logPromotionEvent(userId, 'role_promoted', {
      'previousRole': previousRole,
      'newRole': newRole,
      'directReferrals': directReferrals,
      'teamSize': teamSize,
      'promotionType': 'automated_real_time',
    });
    
    // Send promotion notification
    await _sendPromotionNotification(userId, previousRole, newRole, userData);
    
    if (kDebugMode) {
      print('🎉 Real-time promotion: User $userId promoted from $previousRole to $newRole');
    }
  }
  
  /// Log all promotion events for audit purposes
  static Future<void> _logPromotionEvent(
    String userId,
    String eventType,
    Map<String, dynamic> eventData,
  ) async {
    try {
      await _firestore.collection('promotionAuditLogs').add({
        'userId': userId,
        'eventType': eventType,
        'eventData': eventData,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'automated_real_time_promotion_system',
      });
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Failed to log promotion event: $e');
      }
    }
  }
  
  /// Send promotion notification to user
  static Future<void> _sendPromotionNotification(
    String userId,
    String previousRole,
    String newRole,
    Map<String, dynamic> userData,
  ) async {
    try {
      final newRoleDefinition = ROLE_DEFINITIONS[newRole]!;
      
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'role_promotion',
        'title': 'Congratulations on Your Automatic Promotion!',
        'message': 'You have been automatically promoted from ${ROLE_DEFINITIONS[previousRole]!.name} to ${newRoleDefinition.name}!',
        'data': {
          'previousRole': previousRole,
          'newRole': newRole,
          'newLevel': newRoleDefinition.level,
          'benefits': newRoleDefinition.benefits,
          'permissions': newRoleDefinition.permissions,
          'promotionType': 'automated_real_time',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'priority': 'high',
      });
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Failed to send promotion notification: $e');
      }
    }
  }
  
  /// Get next role requirements for progress tracking
  static Map<String, dynamic>? _getNextRoleRequirements(String currentRole) {
    final currentIndex = ROLE_HIERARCHY.indexOf(currentRole);
    if (currentIndex == -1 || currentIndex >= ROLE_HIERARCHY.length - 1) {
      return null; // Already at highest role or role not found
    }
    
    final nextRole = ROLE_HIERARCHY[currentIndex + 1];
    final nextRoleDefinition = ROLE_DEFINITIONS[nextRole]!;
    
    return {
      'nextRole': nextRole,
      'nextRoleName': nextRoleDefinition.name,
      'nextLevel': nextRoleDefinition.level,
      'directReferralsRequired': nextRoleDefinition.directReferralsRequired,
      'teamSizeRequired': nextRoleDefinition.teamSizeRequired,
      'benefits': nextRoleDefinition.benefits,
    };
  }
  
  /// Get role definition by name
  static RoleDefinition? getRoleDefinition(String roleName) {
    return ROLE_DEFINITIONS[roleName];
  }
  
  /// Get all role definitions
  static Map<String, RoleDefinition> getAllRoleDefinitions() {
    return Map.from(ROLE_DEFINITIONS);
  }
  
  /// Check if role A is higher than role B in hierarchy
  static bool isRoleHigher(String roleA, String roleB) {
    final indexA = ROLE_HIERARCHY.indexOf(roleA);
    final indexB = ROLE_HIERARCHY.indexOf(roleB);
    return indexA > indexB;
  }
}

