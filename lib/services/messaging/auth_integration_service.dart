// Authentication Integration Service for TALOWA Messaging
// Handles single sign-on and user account synchronization
// Reference: in-app-communication/tasks.md - Task 11

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';
import '../auth_service.dart';
import '../database_service.dart';
import 'messaging_integration_service.dart';

class AuthIntegrationService {
  static final AuthIntegrationService _instance = AuthIntegrationService._internal();
  factory AuthIntegrationService() => _instance;
  AuthIntegrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessagingIntegrationService _messagingIntegration = MessagingIntegrationService();
  
  StreamSubscription<DocumentSnapshot>? _userProfileSubscription;

  /// Initialize authentication integration
  Future<void> initialize() async {
    try {
      // Listen to auth state changes
      AuthService.authStateChanges.listen(_handleAuthStateChange);
      
      debugPrint('Auth integration service initialized');
    } catch (e) {
      debugPrint('Error initializing auth integration service: $e');
    }
  }

  /// Handle authentication state changes
  Future<void> _handleAuthStateChange(user) async {
    try {
      if (user != null) {
        // User signed in - initialize messaging profile
        await _onUserSignIn(user.uid);
      } else {
        // User signed out - cleanup
        await _onUserSignOut();
      }
    } catch (e) {
      debugPrint('Error handling auth state change: $e');
    }
  }

  /// Handle user sign in
  Future<void> _onUserSignIn(String userId) async {
    try {
      // Initialize messaging profile for the user
      await _messagingIntegration.initializeUserMessagingProfile(userId);
      
      // Start listening to user profile changes
      _startUserProfileListener(userId);
      
      // Update user's online status
      await _updateUserOnlineStatus(userId, true);
      
      debugPrint('User signed in to messaging system: $userId');
    } catch (e) {
      debugPrint('Error handling user sign in: $e');
    }
  }

  /// Handle user sign out
  Future<void> _onUserSignOut() async {
    try {
      // Stop listening to user profile changes
      await _userProfileSubscription?.cancel();
      _userProfileSubscription = null;
      
      debugPrint('User signed out from messaging system');
    } catch (e) {
      debugPrint('Error handling user sign out: $e');
    }
  }

  /// Start listening to user profile changes for real-time sync
  void _startUserProfileListener(String userId) {
    _userProfileSubscription?.cancel();
    
    _userProfileSubscription = _firestore
        .collection(AppConstants.collectionUsers)
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        try {
          final userModel = UserModel.fromFirestore(snapshot);
          await _syncUserProfileWithMessaging(userModel);
        } catch (e) {
          debugPrint('Error syncing user profile with messaging: $e');
        }
      }
    });
  }

  /// Sync user profile changes with messaging system
  Future<void> _syncUserProfileWithMessaging(UserModel userModel) async {
    try {
      await _messagingIntegration.syncUserAccountWithMessaging(userModel.id);
      debugPrint('User profile synced with messaging: ${userModel.id}');
    } catch (e) {
      debugPrint('Error syncing user profile with messaging: $e');
    }
  }

  /// Update user's online status
  Future<void> _updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('messaging_profiles').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating user online status: $e');
    }
  }

  /// Get user's messaging profile
  Future<Map<String, dynamic>?> getUserMessagingProfile(String userId) async {
    try {
      final doc = await _firestore.collection('messaging_profiles').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user messaging profile: $e');
      return null;
    }
  }

  /// Update user messaging preferences
  Future<void> updateMessagingPreferences({
    required String userId,
    bool? allowDirectMessages,
    bool? showOnlineStatus,
    bool? allowGroupInvites,
    bool? allowAnonymousMessages,
    String? encryptionLevel,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception('User not authenticated or unauthorized');
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (allowDirectMessages != null) {
        updateData['messagingPreferences.allowDirectMessages'] = allowDirectMessages;
      }
      if (showOnlineStatus != null) {
        updateData['messagingPreferences.showOnlineStatus'] = showOnlineStatus;
      }
      if (allowGroupInvites != null) {
        updateData['messagingPreferences.allowGroupInvites'] = allowGroupInvites;
      }
      if (allowAnonymousMessages != null) {
        updateData['messagingPreferences.allowAnonymousMessages'] = allowAnonymousMessages;
      }
      if (encryptionLevel != null) {
        updateData['messagingPreferences.encryptionLevel'] = encryptionLevel;
      }

      await _firestore.collection('messaging_profiles').doc(userId).update(updateData);
      
      debugPrint('Messaging preferences updated for user: $userId');
    } catch (e) {
      debugPrint('Error updating messaging preferences: $e');
      rethrow;
    }
  }

  /// Check if user can send direct messages to another user
  Future<bool> canSendDirectMessage(String fromUserId, String toUserId) async {
    try {
      // Get recipient's messaging profile
      final recipientProfile = await getUserMessagingProfile(toUserId);
      if (recipientProfile == null) return false;

      final messagingPrefs = recipientProfile['messagingPreferences'] as Map<String, dynamic>? ?? {};
      final allowDirectMessages = messagingPrefs['allowDirectMessages'] as bool? ?? true;

      if (!allowDirectMessages) return false;

      // Check if users are in the same geographic area or have mutual connections
      return await _checkUserConnection(fromUserId, toUserId);
    } catch (e) {
      debugPrint('Error checking direct message permission: $e');
      return false;
    }
  }

  /// Check if users have a connection (same area, mutual groups, etc.)
  Future<bool> _checkUserConnection(String userId1, String userId2) async {
    try {
      // Get both user profiles
      final user1Profile = await DatabaseService.getUserProfile(userId1);
      final user2Profile = await DatabaseService.getUserProfile(userId2);

      if (user1Profile == null || user2Profile == null) return false;

      // Check if users are in the same geographic area
      final user1Address = user1Profile.address;
      final user2Address = user2Profile.address;

      if (user1Address.district == user2Address.district) {
        return true; // Same district
      }

      // Check if users are in mutual groups
      // This would require querying group memberships
      // For now, we'll allow connections within the same state
      if (user1Address.state == user2Address.state) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking user connection: $e');
      return false;
    }
  }

  /// Get user's role-based messaging permissions
  Future<Map<String, bool>> getUserMessagingPermissions(String userId) async {
    try {
      final profile = await getUserMessagingProfile(userId);
      if (profile == null) {
        return _getDefaultPermissions();
      }

      final rolePermissions = profile['rolePermissions'] as Map<String, dynamic>? ?? {};
      return Map<String, bool>.from(rolePermissions);
    } catch (e) {
      debugPrint('Error getting user messaging permissions: $e');
      return _getDefaultPermissions();
    }
  }

  Map<String, bool> _getDefaultPermissions() {
    return {
      'canCreateGroups': false,
      'canCreateCampaignGroups': false,
      'canCreateLegalCaseGroups': false,
      'canSendEmergencyBroadcasts': false,
      'canModerateContent': false,
      'canAccessAllGroups': false,
      'canLinkToAllCases': false,
    };
  }

  /// Validate user session for messaging operations
  Future<bool> validateUserSession(String userId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        return false;
      }

      // Check if user's messaging profile exists and is active
      final profile = await getUserMessagingProfile(userId);
      if (profile == null || profile['isActive'] != true) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error validating user session: $e');
      return false;
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      await _userProfileSubscription?.cancel();
      _userProfileSubscription = null;
      debugPrint('Auth integration service disposed');
    } catch (e) {
      debugPrint('Error disposing auth integration service: $e');
    }
  }
}