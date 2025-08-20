import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Exception thrown when role progression operations fail
class RoleProgressionException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const RoleProgressionException(this.message, [this.code = 'ROLE_PROGRESSION_FAILED', this.context]);
  
  @override
  String toString() => 'RoleProgressionException: $message';
}

/// Role definition with requirements
class RoleDefinition {
  final String name;
  final int directReferralsRequired;
  final int teamSizeRequired;
  final List<String> permissions;
  final Map<String, dynamic> benefits;
  final bool isLocationBased;
  
  const RoleDefinition({
    required this.name,
    required this.directReferralsRequired,
    required this.teamSizeRequired,
    required this.permissions,
    required this.benefits,
    this.isLocationBased = false,
  });
}

/// Service for managing role-based progression system
class RoleProgressionService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// 10-tier role progression system
  static const Map<String, RoleDefinition> ROLE_DEFINITIONS = {
    'member': RoleDefinition(
      name: 'Member',
      directReferralsRequired: 0,
      teamSizeRequired: 0,
      permissions: ['basic_access'],
      benefits: {'description': 'Basic TALOWA membership'},
    ),
    'activist': RoleDefinition(
      name: 'Activist',
      directReferralsRequired: 2,
      teamSizeRequired: 5,
      permissions: ['basic_access', 'share_content'],
      benefits: {'description': 'Enhanced sharing capabilities'},
    ),
    'organizer': RoleDefinition(
      name: 'Organizer',
      directReferralsRequired: 5,
      teamSizeRequired: 15,
      permissions: ['basic_access', 'share_content', 'create_events'],
      benefits: {'description': 'Event creation and management'},
    ),
    'team_leader': RoleDefinition(
      name: 'Team Leader',
      directReferralsRequired: 10,
      teamSizeRequired: 50,
      permissions: ['basic_access', 'share_content', 'create_events', 'manage_team'],
      benefits: {'description': 'Team management capabilities'},
    ),
    'coordinator': RoleDefinition(
      name: 'Coordinator',
      directReferralsRequired: 20,
      teamSizeRequired: 150,
      permissions: ['basic_access', 'share_content', 'create_events', 'manage_team', 'coordinate_activities'],
      benefits: {'description': 'Activity coordination and planning'},
    ),
    'area_coordinator': RoleDefinition(
      name: 'Area Coordinator',
      directReferralsRequired: 30,
      teamSizeRequired: 350,
      permissions: ['basic_access', 'share_content', 'create_events', 'manage_team', 'coordinate_activities', 'area_management'],
      benefits: {'description': 'Area-wide coordination and management'},
    ),
    'district_coordinator': RoleDefinition(
      name: 'District Coordinator',
      directReferralsRequired: 40,
      teamSizeRequired: 700,
      permissions: ['basic_access', 'share_content', 'create_events', 'manage_team', 'coordinate_activities', 'area_management', 'district_oversight'],
      benefits: {'description': 'District-level oversight and coordination'},
      isLocationBased: true,
    ),
    'regional_coordinator': RoleDefinition(
      name: 'Regional Coordinator',
      directReferralsRequired: 60,
      teamSizeRequired: 1500,
      permissions: ['basic_access', 'share_content', 'create_events', 'manage_team', 'coordinate_activities', 'area_management', 'district_oversight', 'regional_leadership'],
      benefits: {'description': 'Regional leadership and strategy'},
    ),
    'state_coordinator': RoleDefinition(
      name: 'State Coordinator',
      directReferralsRequired: 100,
      teamSizeRequired: 5000,
      permissions: ['basic_access', 'share_content', 'create_events', 'manage_team', 'coordinate_activities', 'area_management', 'district_oversight', 'regional_leadership', 'state_governance'],
      benefits: {'description': 'State-level governance and policy'},
    ),
    'national_coordinator': RoleDefinition(
      name: 'National Coordinator',
      directReferralsRequired: 200,
      teamSizeRequired: 15000,
      permissions: ['basic_access', 'share_content', 'create_events', 'manage_team', 'coordinate_activities', 'area_management', 'district_oversight', 'regional_leadership', 'state_governance', 'national_leadership'],
      benefits: {'description': 'National leadership and movement direction'},
    ),
  };
  
  /// Role hierarchy order
  static const List<String> ROLE_HIERARCHY = [
    'member',
    'activist',
    'organizer',
    'team_leader',
    'coordinator',
    'area_coordinator',
    'district_coordinator',
    'regional_coordinator',
    'state_coordinator',
    'national_coordinator',
  ];
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Check and update user role based on current statistics
  static Future<Map<String, dynamic>> checkAndUpdateRole(String userId) async {
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
      final currentRole = userData['currentRole'] as String? ?? 'member';
      
      // In simplified system, all registered users are eligible for role progression
      
      // Get current statistics
      final directReferrals = userData['activeDirectReferrals'] as int? ?? 0;
      final teamSize = userData['activeTeamSize'] as int? ?? 0;
      final location = userData['location'] as Map<String, dynamic>?;
      
      // Determine eligible role
      final eligibleRole = _determineEligibleRole(
        directReferrals: directReferrals,
        teamSize: teamSize,
        location: location,
      );
      
      // Check if promotion is needed
      if (_isRoleHigher(eligibleRole, currentRole)) {
        await _promoteUser(userId, currentRole, eligibleRole, userData);
        
        return {
          'promoted': true,
          'previousRole': currentRole,
          'currentRole': eligibleRole,
          'directReferrals': directReferrals,
          'teamSize': teamSize,
          'promotedAt': DateTime.now().toIso8601String(),
        };
      }
      
      return {
        'promoted': false,
        'currentRole': currentRole,
        'eligibleRole': eligibleRole,
        'directReferrals': directReferrals,
        'teamSize': teamSize,
        'nextRoleRequirements': _getNextRoleRequirements(currentRole),
      };
      
    } catch (e) {
      if (e is RoleProgressionException) {
        rethrow;
      }
      
      throw RoleProgressionException(
        'Failed to check and update role: $e',
        'ROLE_CHECK_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Determine eligible role based on statistics and location
  static String _determineEligibleRole({
    required int directReferrals,
    required int teamSize,
    Map<String, dynamic>? location,
  }) {
    String eligibleRole = 'member';
    
    for (final role in ROLE_HIERARCHY.reversed) {
      final definition = ROLE_DEFINITIONS[role]!;
      
      // Check if user meets requirements
      if (directReferrals >= definition.directReferralsRequired &&
          teamSize >= definition.teamSizeRequired) {
        
        // For location-based roles, check location requirements
        if (definition.isLocationBased) {
          if (_meetsLocationRequirements(role, location)) {
            eligibleRole = role;
            break;
          }
        } else {
          eligibleRole = role;
          break;
        }
      }
    }
    
    return eligibleRole;
  }
  
  /// Check if user meets location requirements for role
  static bool _meetsLocationRequirements(String role, Map<String, dynamic>? location) {
    if (location == null) return false;
    
    final locationType = location['type'] as String?;
    
    switch (role) {
      case 'district_coordinator':
        // Special handling for district coordinator - urban vs rural
        if (locationType == 'urban') {
          // Urban areas need higher requirements (already handled in role definitions)
          return true;
        } else if (locationType == 'rural') {
          // Rural areas have same requirements but different designation
          return true;
        }
        return false;
      default:
        return true;
    }
  }
  
  /// Check if role A is higher than role B in hierarchy
  static bool _isRoleHigher(String roleA, String roleB) {
    final indexA = ROLE_HIERARCHY.indexOf(roleA);
    final indexB = ROLE_HIERARCHY.indexOf(roleB);
    return indexA > indexB;
  }
  
  /// Promote user to new role
  static Future<void> _promoteUser(
    String userId,
    String previousRole,
    String newRole,
    Map<String, dynamic> userData,
  ) async {
    final batch = _firestore.batch();
    
    // Update user document
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'currentRole': newRole,
      'previousRole': previousRole,
      'rolePromotedAt': FieldValue.serverTimestamp(),
      'rolePromotionHistory': FieldValue.arrayUnion([{
        'from': previousRole,
        'to': newRole,
        'promotedAt': DateTime.now().toIso8601String(),
        'directReferrals': userData['activeDirectReferrals'] ?? 0,
        'teamSize': userData['activeTeamSize'] ?? 0,
      }]),
    });
    
    // Record promotion in history
    final promotionRef = _firestore.collection('rolePromotions').doc();
    batch.set(promotionRef, {
      'userId': userId,
      'userName': userData['fullName'],
      'userEmail': userData['email'],
      'previousRole': previousRole,
      'newRole': newRole,
      'directReferrals': userData['activeDirectReferrals'] ?? 0,
      'teamSize': userData['activeTeamSize'] ?? 0,
      'location': userData['location'],
      'promotedAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
    
    // Send promotion notification
    await _sendPromotionNotification(userId, previousRole, newRole, userData);
  }
  
  /// Send promotion notification
  static Future<void> _sendPromotionNotification(
    String userId,
    String previousRole,
    String newRole,
    Map<String, dynamic> userData,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'role_promotion',
        'title': 'Congratulations on Your Promotion!',
        'message': 'You have been promoted from ${ROLE_DEFINITIONS[previousRole]!.name} to ${ROLE_DEFINITIONS[newRole]!.name}!',
        'data': {
          'previousRole': previousRole,
          'newRole': newRole,
          'benefits': ROLE_DEFINITIONS[newRole]!.benefits,
          'permissions': ROLE_DEFINITIONS[newRole]!.permissions,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      // Don't fail the main operation for notification errors
      print('Warning: Failed to send promotion notification: $e');
    }
  }
  
  /// Get requirements for next role
  static Map<String, dynamic>? _getNextRoleRequirements(String currentRole) {
    final currentIndex = ROLE_HIERARCHY.indexOf(currentRole);
    if (currentIndex == -1 || currentIndex >= ROLE_HIERARCHY.length - 1) {
      return null; // Already at highest role
    }
    
    final nextRole = ROLE_HIERARCHY[currentIndex + 1];
    final definition = ROLE_DEFINITIONS[nextRole]!;
    
    return {
      'role': nextRole,
      'name': definition.name,
      'directReferralsRequired': definition.directReferralsRequired,
      'teamSizeRequired': definition.teamSizeRequired,
      'isLocationBased': definition.isLocationBased,
      'benefits': definition.benefits,
    };
  }
  
  /// Get user's role progression status
  static Future<Map<String, dynamic>> getRoleProgressionStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw RoleProgressionException(
          'User not found: $userId',
          'USER_NOT_FOUND',
          {'userId': userId}
        );
      }
      
      final userData = userDoc.data()!;
      final currentRole = userData['currentRole'] as String? ?? 'member';
      final directReferrals = userData['activeDirectReferrals'] as int? ?? 0;
      final teamSize = userData['activeTeamSize'] as int? ?? 0;
      
      final nextRoleRequirements = _getNextRoleRequirements(currentRole);
      
      Map<String, dynamic>? progress;
      if (nextRoleRequirements != null) {
        final directProgress = (directReferrals / nextRoleRequirements['directReferralsRequired'] * 100).clamp(0, 100);
        final teamProgress = (teamSize / nextRoleRequirements['teamSizeRequired'] * 100).clamp(0, 100);
        
        progress = {
          'directReferrals': {
            'current': directReferrals,
            'required': nextRoleRequirements['directReferralsRequired'],
            'progress': directProgress.round(),
          },
          'teamSize': {
            'current': teamSize,
            'required': nextRoleRequirements['teamSizeRequired'],
            'progress': teamProgress.round(),
          },
          'overallProgress': ((directProgress + teamProgress) / 2).round(),
        };
      }
      
      return {
        'userId': userId,
        'currentRole': currentRole,
        'currentRoleDefinition': ROLE_DEFINITIONS[currentRole],
        'directReferrals': directReferrals,
        'teamSize': teamSize,
        'nextRole': nextRoleRequirements,
        'progress': progress,
        'membershipPaid': true, // Always true in simplified system
        'rolePromotionHistory': userData['rolePromotionHistory'] ?? [],
      };
    } catch (e) {
      if (e is RoleProgressionException) {
        rethrow;
      }
      
      throw RoleProgressionException(
        'Failed to get role progression status: $e',
        'STATUS_RETRIEVAL_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get all role definitions
  static Map<String, RoleDefinition> getAllRoleDefinitions() {
    return Map.from(ROLE_DEFINITIONS);
  }
  
  /// Get role hierarchy
  static List<String> getRoleHierarchy() {
    return List.from(ROLE_HIERARCHY);
  }
  
  /// Check if user has specific permission
  static Future<bool> hasPermission(String userId, String permission) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final currentRole = userData['currentRole'] as String? ?? 'member';
      final roleDefinition = ROLE_DEFINITIONS[currentRole];
      
      return roleDefinition?.permissions.contains(permission) ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Get users by role
  static Future<List<Map<String, dynamic>>> getUsersByRole(String role, {int limit = 50}) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('currentRole', isEqualTo: role)
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'fullName': data['fullName'],
          'email': data['email'],
          'currentRole': data['currentRole'],
          'directReferrals': data['activeDirectReferrals'] ?? 0,
          'teamSize': data['activeTeamSize'] ?? 0,
          'rolePromotedAt': data['rolePromotedAt'],
          'location': data['location'],
        };
      }).toList();
    } catch (e) {
      throw RoleProgressionException(
        'Failed to get users by role: $e',
        'USERS_BY_ROLE_FAILED',
        {'role': role}
      );
    }
  }
  
  /// Get role distribution statistics
  static Future<Map<String, dynamic>> getRoleDistributionStats() async {
    try {
      final distribution = <String, int>{};
      
      for (final role in ROLE_HIERARCHY) {
        final query = await _firestore
            .collection('users')
            .where('currentRole', isEqualTo: role)
            .where('isActive', isEqualTo: true)
            .get();
        
        distribution[role] = query.docs.length;
      }
      
      final totalUsers = distribution.values.fold(0, (sum, count) => sum + count);
      
      return {
        'distribution': distribution,
        'totalUsers': totalUsers,
        'calculatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw RoleProgressionException(
        'Failed to get role distribution stats: $e',
        'DISTRIBUTION_STATS_FAILED'
      );
    }
  }
  
  /// Batch check role progressions for multiple users
  static Future<List<Map<String, dynamic>>> batchCheckRoleProgressions(List<String> userIds) async {
    try {
      final results = <Map<String, dynamic>>[];
      
      for (final userId in userIds) {
        try {
          final result = await checkAndUpdateRole(userId);
          results.add({
            'userId': userId,
            'success': true,
            'result': result,
          });
        } catch (e) {
          results.add({
            'userId': userId,
            'success': false,
            'error': e.toString(),
          });
        }
      }
      
      return results;
    } catch (e) {
      throw RoleProgressionException(
        'Failed to batch check role progressions: $e',
        'BATCH_CHECK_FAILED',
        {'userIds': userIds}
      );
    }
  }
}
