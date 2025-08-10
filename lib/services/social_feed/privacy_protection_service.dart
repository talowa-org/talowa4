// Privacy Protection Service for TALOWA Social Feed
// Implements Task 17: Implement privacy protection system

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/index.dart';
import '../../models/user_model.dart';

class PrivacyProtectionService {
  static final PrivacyProtectionService _instance = PrivacyProtectionService._internal();
  factory PrivacyProtectionService() => _instance;
  PrivacyProtectionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Privacy levels
  static const String privacyPublic = 'public';
  static const String privacyNetwork = 'network';
  static const String privacyDirectReferrals = 'direct_referrals';
  static const String privacyCoordinators = 'coordinators';
  static const String privacyPrivate = 'private';

  // Role hierarchy levels
  static const Map<String, int> roleHierarchy = {
    'member': 1,
    'volunteer': 2,
    'village_coordinator': 3,
    'mandal_coordinator': 4,
    'district_coordinator': 5,
    'state_coordinator': 6,
    'legal_advisor': 7,
    'media_coordinator': 7,
    'founder': 8,
    'root_admin': 9,
  };

  /// Check if user can view content based on privacy settings
  Future<bool> canViewContent({
    required String contentId,
    required String viewerId,
    required String contentAuthorId,
    required String contentPrivacy,
    GeographicTargeting? contentGeographicScope,
  }) async {
    try {
      // Public content is visible to everyone
      if (contentPrivacy == privacyPublic) {
        return true;
      }

      // Author can always view their own content
      if (viewerId == contentAuthorId) {
        return true;
      }

      // Get viewer and author information
      final viewerDoc = await _firestore.collection('users').doc(viewerId).get();
      final authorDoc = await _firestore.collection('users').doc(contentAuthorId).get();

      if (!viewerDoc.exists || !authorDoc.exists) {
        return false;
      }

      final viewer = UserModel.fromFirestore(viewerDoc);
      final author = UserModel.fromFirestore(authorDoc);

      // Check role-based access
      if (await _hasRoleBasedAccess(viewer, author, contentPrivacy)) {
        return true;
      }

      // Check network-based access
      if (await _hasNetworkBasedAccess(viewer, author, contentPrivacy)) {
        return true;
      }

      // Check geographic-based access
      if (await _hasGeographicAccess(viewer, author, contentGeographicScope)) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking content visibility: $e');
      return false;
    }
  }

  /// Check role-based access permissions
  Future<bool> _hasRoleBasedAccess(
    UserModel viewer,
    UserModel author,
    String contentPrivacy,
  ) async {
    final viewerRoleLevel = roleHierarchy[viewer.role] ?? 0;
    final authorRoleLevel = roleHierarchy[author.role] ?? 0;

    switch (contentPrivacy) {
      case privacyCoordinators:
        // Only coordinators and above can view
        return viewerRoleLevel >= roleHierarchy['village_coordinator']!;
      
      case privacyPrivate:
        // Only higher-level coordinators can view
        return viewerRoleLevel > authorRoleLevel;
      
      default:
        return false;
    }
  }

  /// Check network-based access (referral relationships)
  Future<bool> _hasNetworkBasedAccess(
    UserModel viewer,
    UserModel author,
    String contentPrivacy,
  ) async {
    try {
      switch (contentPrivacy) {
        case privacyNetwork:
          // Check if viewer is in author's network (direct or indirect referral)
          return await _isInNetwork(viewer.id, author.id);
        
        case privacyDirectReferrals:
          // Check if viewer is a direct referral of author
          return await _isDirectReferral(viewer.id, author.id);
        
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Error checking network access: $e');
      return false;
    }
  }

  /// Check if viewer is in author's network
  Future<bool> _isInNetwork(String viewerId, String authorId) async {
    try {
      // Check direct referral relationship
      if (await _isDirectReferral(viewerId, authorId)) {
        return true;
      }

      // Check indirect referral relationship (up to 3 levels)
      return await _isIndirectReferral(viewerId, authorId, maxLevels: 3);
    } catch (e) {
      debugPrint('Error checking network relationship: $e');
      return false;
    }
  }

  /// Check if viewer is a direct referral of author
  Future<bool> _isDirectReferral(String viewerId, String authorId) async {
    try {
      final viewerDoc = await _firestore.collection('users').doc(viewerId).get();
      if (!viewerDoc.exists) return false;

      final referredBy = viewerDoc.data()?['referredBy'] as String?;
      return referredBy == authorId;
    } catch (e) {
      debugPrint('Error checking direct referral: $e');
      return false;
    }
  }

  /// Check if viewer is an indirect referral of author
  Future<bool> _isIndirectReferral(String viewerId, String authorId, {int maxLevels = 3}) async {
    try {
      String? currentUserId = viewerId;
      
      for (int level = 0; level < maxLevels; level++) {
        if (currentUserId == null) break;
        
        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        if (!userDoc.exists) break;
        
        final referredBy = userDoc.data()?['referredBy'] as String?;
        if (referredBy == null) break;
        
        if (referredBy == authorId) {
          return true;
        }
        
        currentUserId = referredBy;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking indirect referral: $e');
      return false;
    }
  }

  /// Check geographic-based access
  Future<bool> _hasGeographicAccess(
    UserModel viewer,
    UserModel author,
    GeographicTargeting? contentGeographicScope,
  ) async {
    try {
      // If no geographic scope specified, allow access
      if (contentGeographicScope == null) {
        return true;
      }

      final viewerLocation = viewer.address;

      // Check state-level access
      if (contentGeographicScope.stateCode != null &&
          contentGeographicScope.stateCode != viewerLocation.stateCode) {
        return false;
      }

      // Check district-level access
      if (contentGeographicScope.districtCode != null &&
          contentGeographicScope.districtCode != viewerLocation.districtCode) {
        return false;
      }

      // Check mandal-level access
      if (contentGeographicScope.mandalCode != null &&
          contentGeographicScope.mandalCode != viewerLocation.mandalCode) {
        return false;
      }

      // Check village-level access
      if (contentGeographicScope.villageCode != null &&
          contentGeographicScope.villageCode != viewerLocation.villageCode) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking geographic access: $e');
      return false;
    }
  }

  /// Filter posts based on user's privacy permissions
  Future<List<PostModel>> filterPostsByPrivacy({
    required List<PostModel> posts,
    required String viewerId,
  }) async {
    try {
      final filteredPosts = <PostModel>[];
      
      for (final post in posts) {
        final canView = await canViewContent(
          contentId: post.id,
          viewerId: viewerId,
          contentAuthorId: post.authorId,
          contentPrivacy: post.visibility.toString(),
          contentGeographicScope: post.geographicTargeting,
        );
        
        if (canView) {
          filteredPosts.add(post);
        }
      }
      
      return filteredPosts;
    } catch (e) {
      debugPrint('Error filtering posts by privacy: $e');
      return [];
    }
  }

  /// Get user's contact visibility based on relationship
  Future<ContactVisibility> getContactVisibility({
    required String viewerId,
    required String targetUserId,
  }) async {
    try {
      // User can always see their own full details
      if (viewerId == targetUserId) {
        return ContactVisibility.full;
      }

      // Get user information
      final viewerDoc = await _firestore.collection('users').doc(viewerId).get();
      final targetDoc = await _firestore.collection('users').doc(targetUserId).get();

      if (!viewerDoc.exists || !targetDoc.exists) {
        return ContactVisibility.none;
      }

      final viewer = UserModel.fromFirestore(viewerDoc);
      final target = UserModel.fromFirestore(targetDoc);

      // Check if viewer is a coordinator with higher role
      final viewerRoleLevel = roleHierarchy[viewer.role] ?? 0;
      final targetRoleLevel = roleHierarchy[target.role] ?? 0;

      if (viewerRoleLevel >= roleHierarchy['village_coordinator']! &&
          viewerRoleLevel > targetRoleLevel) {
        return ContactVisibility.full;
      }

      // Check direct referral relationship
      if (await _isDirectReferral(targetUserId, viewerId) ||
          await _isDirectReferral(viewerId, targetUserId)) {
        return ContactVisibility.full;
      }

      // Check indirect referral relationship
      if (await _isIndirectReferral(targetUserId, viewerId) ||
          await _isIndirectReferral(viewerId, targetUserId)) {
        return ContactVisibility.limited;
      }

      // Check geographic proximity (same village/mandal)
      if (await _hasGeographicProximity(viewer, target)) {
        return ContactVisibility.limited;
      }

      return ContactVisibility.anonymous;
    } catch (e) {
      debugPrint('Error getting contact visibility: $e');
      return ContactVisibility.none;
    }
  }

  /// Check if users have geographic proximity
  Future<bool> _hasGeographicProximity(UserModel viewer, UserModel target) async {
    try {
      final viewerLocation = viewer.address;
      final targetLocation = target.address;

      if (targetLocation == null) {
        return false;
      }

      // Same village
      if (viewerLocation.villageCode == targetLocation.villageCode) {
        return true;
      }

      // Same mandal
      if (viewerLocation.mandalCode == targetLocation.mandalCode) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking geographic proximity: $e');
      return false;
    }
  }

  /// Apply privacy filters to user profile data
  Map<String, dynamic> applyPrivacyFilters({
    required Map<String, dynamic> userData,
    required ContactVisibility visibility,
  }) {
    final filteredData = Map<String, dynamic>.from(userData);

    switch (visibility) {
      case ContactVisibility.full:
        // Return all data
        break;
      
      case ContactVisibility.limited:
        // Remove sensitive information
        filteredData.remove('phoneNumber');
        filteredData.remove('email');
        filteredData.remove('referralCode');
        filteredData.remove('fcmToken');
        
        // Generalize location
        if (filteredData['address'] != null) {
          final address = Map<String, dynamic>.from(filteredData['address']);
          address.remove('villageCode');
          address.remove('villageName');
          filteredData['address'] = address;
        }
        break;
      
      case ContactVisibility.anonymous:
        // Only show basic public information
        filteredData.clear();
        filteredData['id'] = userData['id'];
        filteredData['displayName'] = 'Anonymous User';
        filteredData['role'] = userData['role'];
        filteredData['isOnline'] = userData['isOnline'];
        break;
      
      case ContactVisibility.none:
        // Return empty data
        filteredData.clear();
        break;
    }

    return filteredData;
  }

  /// Log privacy access for audit trail
  Future<void> logPrivacyAccess({
    required String viewerId,
    required String targetId,
    required String accessType,
    required String result,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('privacy_logs').add({
        'viewerId': viewerId,
        'targetId': targetId,
        'accessType': accessType,
        'result': result,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      debugPrint('Error logging privacy access: $e');
    }
  }

  /// Get user's privacy preferences
  Future<Map<String, dynamic>> getUserPrivacyPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_privacy_preferences')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data()!;
      }

      // Return default privacy preferences
      return {
        'profileVisibility': privacyNetwork,
        'contactVisibility': privacyDirectReferrals,
        'postDefaultPrivacy': privacyPublic,
        'showOnlineStatus': true,
        'allowDirectMessages': true,
        'allowGroupInvites': true,
        'showInSearch': true,
        'dataProcessingConsent': false,
        'marketingConsent': false,
      };
    } catch (e) {
      debugPrint('Error getting privacy preferences: $e');
      return {};
    }
  }

  /// Update user's privacy preferences
  Future<void> updatePrivacyPreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      await _firestore
          .collection('user_privacy_preferences')
          .doc(userId)
          .set(preferences, SetOptions(merge: true));

      // Log privacy preference change
      await logPrivacyAccess(
        viewerId: userId,
        targetId: userId,
        accessType: 'privacy_preferences_update',
        result: 'success',
        metadata: {'updatedFields': preferences.keys.toList()},
      );
    } catch (e) {
      debugPrint('Error updating privacy preferences: $e');
      rethrow;
    }
  }

  /// Check if user has consented to data processing
  Future<bool> hasDataProcessingConsent(String userId) async {
    try {
      final preferences = await getUserPrivacyPreferences(userId);
      return preferences['dataProcessingConsent'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking data processing consent: $e');
      return false;
    }
  }

  /// Request data processing consent
  Future<void> requestDataProcessingConsent({
    required String userId,
    required bool granted,
    String? purpose,
  }) async {
    try {
      await _firestore.collection('consent_logs').add({
        'userId': userId,
        'consentType': 'data_processing',
        'granted': granted,
        'purpose': purpose,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': null, // TODO: Get IP address
        'userAgent': null, // TODO: Get user agent
      });

      // Update privacy preferences
      await updatePrivacyPreferences(
        userId: userId,
        preferences: {'dataProcessingConsent': granted},
      );
    } catch (e) {
      debugPrint('Error requesting data processing consent: $e');
      rethrow;
    }
  }

  /// Get anonymized user data for analytics
  Map<String, dynamic> getAnonymizedUserData(Map<String, dynamic> userData) {
    return {
      'role': userData['role'],
      'registrationDate': userData['createdAt'],
      'isActive': userData['isActive'],
      'state': userData['address']?['stateCode'],
      'district': userData['address']?['districtCode'],
      // Remove all personally identifiable information
    };
  }
}

// Contact visibility levels
enum ContactVisibility {
  full,      // Full contact details visible
  limited,   // Limited information visible
  anonymous, // Only anonymous information
  none,      // No information visible
}

// Privacy violation types
enum PrivacyViolationType {
  unauthorizedAccess,
  dataLeakage,
  consentViolation,
  retentionViolation,
  purposeViolation,
}

// Privacy audit log entry
class PrivacyAuditLog {
  final String id;
  final String viewerId;
  final String targetId;
  final String accessType;
  final String result;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  PrivacyAuditLog({
    required this.id,
    required this.viewerId,
    required this.targetId,
    required this.accessType,
    required this.result,
    required this.timestamp,
    required this.metadata,
  });

  factory PrivacyAuditLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PrivacyAuditLog(
      id: doc.id,
      viewerId: data['viewerId'],
      targetId: data['targetId'],
      accessType: data['accessType'],
      result: data['result'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
}