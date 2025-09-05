// Messaging Integration Service for TALOWA
// Integrates messaging system with existing TALOWA systems
// Reference: in-app-communication/tasks.md - Task 11

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/group_model.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';
import '../auth_service.dart';
import '../database_service.dart';
import '../legal_case_service.dart';
import 'messaging_service.dart';
import 'group_service.dart';

class MessagingIntegrationService {
  static final MessagingIntegrationService _instance = MessagingIntegrationService._internal();
  factory MessagingIntegrationService() => _instance;
  MessagingIntegrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessagingService _messagingService = MessagingService();
  final GroupService _groupService = GroupService();
  final LegalCaseService _legalCaseService = LegalCaseService();

  /// Connect messaging system with user authentication and role management
  Future<void> initializeUserMessagingProfile(String userId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception('User not authenticated or unauthorized');
      }

      // Get user profile
      final userProfile = await DatabaseService.getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      // Create messaging profile document
      await _firestore.collection('messaging_profiles').doc(userId).set({
        'userId': userId,
        'fullName': userProfile.fullName,
        'role': userProfile.role,
        'phoneNumber': userProfile.phoneNumber,
        'address': userProfile.address.toMap(),
        'messagingPreferences': {
          'allowDirectMessages': userProfile.preferences.privacy.allowDirectContact,
          'showOnlineStatus': true,
          'allowGroupInvites': true,
          'allowAnonymousMessages': false,
          'encryptionLevel': _getDefaultEncryptionLevel(userProfile.role),
        },
        'rolePermissions': _getRolePermissions(userProfile.role),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Auto-join geographic groups based on user location
      await _autoJoinGeographicGroups(userId, userProfile);

      debugPrint('User messaging profile initialized: $userId');
    } catch (e) {
      debugPrint('Error initializing user messaging profile: $e');
      rethrow;
    }
  }

  /// Integrate group creation with geographic hierarchy
  Future<String> createGeographicGroup({
    required String name,
    required String description,
    required GroupType type,
    required String level, // village, mandal, district
    required String locationId,
    String? avatarUrl,
    GroupSettings? customSettings,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile to verify permissions
      final userProfile = await DatabaseService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      // Verify user has permission to create group at this level
      if (!_canCreateGroupAtLevel(userProfile.role, level)) {
        throw Exception('Insufficient permissions to create group at $level level');
      }

      // Get location details from geographic hierarchy
      final locationDetails = await _getLocationDetails(level, locationId);
      if (locationDetails == null) {
        throw Exception('Location not found in geographic hierarchy');
      }

      // Create geographic scope
      final geographicScope = GeographicScope(
        level: level,
        locationId: locationId,
        locationName: locationDetails['name'] ?? locationId,
        coordinates: locationDetails['coordinates'] != null
            ? GeographicCoordinates.fromMap(locationDetails['coordinates'])
            : null,
      );

      // Get suggested members based on location
      final suggestedMembers = await _getSuggestedMembersByLocation(level, locationId);

      // Create group with geographic integration
      final groupId = await _groupService.createGroup(
        name: name,
        description: description,
        type: type,
        location: geographicScope,
        initialMemberIds: suggestedMembers.take(10).toList(), // Limit initial members
        settings: customSettings ?? _getDefaultGroupSettings(type, level),
        avatarUrl: avatarUrl,
      );

      // Update geographic hierarchy with group reference
      await _updateGeographicHierarchyWithGroup(level, locationId, groupId);

      // Send welcome message to group
      await _sendGroupWelcomeMessage(groupId, type, level);

      debugPrint('Geographic group created: $groupId at $level level');
      return groupId;
    } catch (e) {
      debugPrint('Error creating geographic group: $e');
      rethrow;
    }
  }

  /// Link messages to legal cases and land records
  Future<void> linkMessageToCase({
    required String messageId,
    String? legalCaseId,
    String? landRecordId,
    String? campaignId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Verify user has access to the entities being linked
      if (legalCaseId != null) {
        final legalCase = await _legalCaseService.getLegalCase(legalCaseId);
        if (legalCase == null || legalCase.clientId != currentUser.uid) {
          throw Exception('Legal case not found or access denied');
        }
      }

      if (landRecordId != null) {
        final landRecords = await DatabaseService.getUserLandRecords(currentUser.uid);
        final hasAccess = landRecords.any((record) => record.id == landRecordId);
        if (!hasAccess) {
          throw Exception('Land record not found or access denied');
        }
      }

      // Update message with links
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (legalCaseId != null) updateData['linkedCaseId'] = legalCaseId;
      if (landRecordId != null) updateData['linkedLandRecordId'] = landRecordId;
      if (campaignId != null) updateData['linkedCampaignId'] = campaignId;

      await _firestore.collection('messages').doc(messageId).update(updateData);

      // Add timeline entry to legal case if linked
      if (legalCaseId != null) {
        await _legalCaseService.addTimelineEntry(
          caseId: legalCaseId,
          event: 'Message Linked',
          description: 'Message linked to case for reference',
        );
      }

      debugPrint('Message linked successfully: $messageId');
    } catch (e) {
      debugPrint('Error linking message: $e');
      rethrow;
    }
  }

  /// Connect with campaign management for event coordination
  Future<String> createCampaignGroup({
    required String campaignId,
    required String campaignName,
    required String description,
    List<String>? coordinatorIds,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Verify user has permission to create campaign groups
      final userProfile = await DatabaseService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      if (!_canCreateCampaignGroup(userProfile.role)) {
        throw Exception('Insufficient permissions to create campaign group');
      }

      // Create campaign-specific geographic scope (based on user's location)
      final geographicScope = GeographicScope(
        level: AppConstants.levelDistrict, // Campaign groups are district-level by default
        locationId: userProfile.address.district,
        locationName: userProfile.address.district,
      );

      // Create group for campaign coordination
      final groupId = await _groupService.createGroup(
        name: 'Campaign: $campaignName',
        description: description,
        type: GroupType.campaign,
        location: geographicScope,
        initialMemberIds: coordinatorIds ?? [],
        settings: GroupSettings(
          whoCanAddMembers: GroupPermission.coordinators,
          whoCanSendMessages: GroupPermission.all,
          whoCanShareMedia: GroupPermission.coordinators,
          messageRetention: 90, // Keep campaign messages for 90 days
          requireApprovalToJoin: true,
          allowAnonymousMessages: false,
          encryptionLevel: 'standard',
        ),
      );

      // Link group to campaign in metadata
      await _firestore.collection('groups').doc(groupId).update({
        'metadata.campaignId': campaignId,
        'metadata.campaignType': 'coordination',
      });

      // Create campaign record if it doesn't exist
      await _createOrUpdateCampaignRecord(campaignId, campaignName, groupId);

      debugPrint('Campaign group created: $groupId for campaign: $campaignId');
      return groupId;
    } catch (e) {
      debugPrint('Error creating campaign group: $e');
      rethrow;
    }
  }

  /// Implement single sign-on with existing TALOWA user accounts
  Future<void> syncUserAccountWithMessaging(String userId) async {
    try {
      // Get latest user profile
      final userProfile = await DatabaseService.getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      // Update messaging profile with latest user data
      await _firestore.collection('messaging_profiles').doc(userId).update({
        'fullName': userProfile.fullName,
        'role': userProfile.role,
        'phoneNumber': userProfile.phoneNumber,
        'address': userProfile.address.toMap(),
        'rolePermissions': _getRolePermissions(userProfile.role),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user's group memberships based on role changes
      await _updateGroupMembershipsForRoleChange(userId, userProfile.role);

      // Update conversation participant details
      await _updateConversationParticipantDetails(userId, userProfile.fullName);

      debugPrint('User account synced with messaging: $userId');
    } catch (e) {
      debugPrint('Error syncing user account with messaging: $e');
      rethrow;
    }
  }

  /// Get messages linked to a specific legal case
  Stream<List<MessageModel>> getCaseMessages(String caseId) {
    try {
      return _firestore
          .collection('messages')
          .where('linkedCaseId', isEqualTo: caseId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('sentAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList());
    } catch (e) {
      debugPrint('Error getting case messages: $e');
      return Stream.value([]);
    }
  }

  /// Get messages linked to a specific land record
  Stream<List<MessageModel>> getLandRecordMessages(String landRecordId) {
    try {
      return _firestore
          .collection('messages')
          .where('linkedLandRecordId', isEqualTo: landRecordId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('sentAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList());
    } catch (e) {
      debugPrint('Error getting land record messages: $e');
      return Stream.value([]);
    }
  }

  /// Get groups by user's geographic location
  Future<List<GroupModel>> getLocationBasedGroups() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      final userProfile = await DatabaseService.getUserProfile(currentUser.uid);
      if (userProfile == null) return [];

      final address = userProfile.address;
      final groups = <GroupModel>[];

      // Get village groups
      final villageGroups = await _groupService.getGroupsByLocation(
        GeographicScope(
          level: AppConstants.levelVillage,
          locationId: address.villageCity,
          locationName: address.villageCity,
        ),
      );
      groups.addAll(villageGroups);

      // Get mandal groups
      final mandalGroups = await _groupService.getGroupsByLocation(
        GeographicScope(
          level: AppConstants.levelMandal,
          locationId: address.mandal,
          locationName: address.mandal,
        ),
      );
      groups.addAll(mandalGroups);

      // Get district groups
      final districtGroups = await _groupService.getGroupsByLocation(
        GeographicScope(
          level: AppConstants.levelDistrict,
          locationId: address.district,
          locationName: address.district,
        ),
      );
      groups.addAll(districtGroups);

      // Remove duplicates
      final uniqueGroups = <String, GroupModel>{};
      for (final group in groups) {
        uniqueGroups[group.id] = group;
      }

      return uniqueGroups.values.toList();
    } catch (e) {
      debugPrint('Error getting location-based groups: $e');
      return [];
    }
  }

  // Private helper methods

  Future<void> _autoJoinGeographicGroups(String userId, UserModel userProfile) async {
    try {
      // Find relevant geographic groups
      final locationGroups = await getLocationBasedGroups();
      
      for (final group in locationGroups) {
        // Auto-join village-level groups for members
        if (group.type == GroupType.village && 
            group.location.locationId == userProfile.address.villageCity &&
            !group.isMember(userId)) {
          try {
            await _groupService.addMember(
              groupId: group.id,
              userId: userId,
              groupRole: GroupRole.member,
            );
          } catch (e) {
            debugPrint('Could not auto-join group ${group.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error auto-joining geographic groups: $e');
    }
  }

  Map<String, dynamic> _getRolePermissions(String role) {
    switch (role) {
      case AppConstants.roleFounder:
      case AppConstants.roleRootAdmin:
        return {
          'canCreateGroups': true,
          'canCreateCampaignGroups': true,
          'canCreateLegalCaseGroups': true,
          'canSendEmergencyBroadcasts': true,
          'canModerateContent': true,
          'canAccessAllGroups': true,
          'canLinkToAllCases': true,
        };
      case AppConstants.roleStateCoordinator:
      case AppConstants.roleDistrictCoordinator:
      case AppConstants.roleMandalCoordinator:
      case AppConstants.roleVillageCoordinator:
        return {
          'canCreateGroups': true,
          'canCreateCampaignGroups': true,
          'canCreateLegalCaseGroups': true,
          'canSendEmergencyBroadcasts': true,
          'canModerateContent': true,
          'canAccessAllGroups': false,
          'canLinkToAllCases': false,
        };
      case AppConstants.roleLegalAdvisor:
        return {
          'canCreateGroups': false,
          'canCreateCampaignGroups': false,
          'canCreateLegalCaseGroups': true,
          'canSendEmergencyBroadcasts': false,
          'canModerateContent': false,
          'canAccessAllGroups': false,
          'canLinkToAllCases': true,
        };
      default:
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
  }

  String _getDefaultEncryptionLevel(String role) {
    switch (role) {
      case AppConstants.roleFounder:
      case AppConstants.roleRootAdmin:
      case AppConstants.roleLegalAdvisor:
        return 'high_security';
      default:
        return 'standard';
    }
  }

  bool _canCreateGroupAtLevel(String userRole, String level) {
    switch (level) {
      case AppConstants.levelVillage:
        return [
          AppConstants.roleVillageCoordinator,
          AppConstants.roleMandalCoordinator,
          AppConstants.roleDistrictCoordinator,
          AppConstants.roleStateCoordinator,
          AppConstants.roleFounder,
          AppConstants.roleRootAdmin,
        ].contains(userRole);
      case AppConstants.levelMandal:
        return [
          AppConstants.roleMandalCoordinator,
          AppConstants.roleDistrictCoordinator,
          AppConstants.roleStateCoordinator,
          AppConstants.roleFounder,
          AppConstants.roleRootAdmin,
        ].contains(userRole);
      case AppConstants.levelDistrict:
        return [
          AppConstants.roleDistrictCoordinator,
          AppConstants.roleStateCoordinator,
          AppConstants.roleFounder,
          AppConstants.roleRootAdmin,
        ].contains(userRole);
      default:
        return false;
    }
  }

  bool _canCreateCampaignGroup(String userRole) {
    return [
      AppConstants.roleVillageCoordinator,
      AppConstants.roleMandalCoordinator,
      AppConstants.roleDistrictCoordinator,
      AppConstants.roleStateCoordinator,
      AppConstants.roleMediaCoordinator,
      AppConstants.roleFounder,
      AppConstants.roleRootAdmin,
    ].contains(userRole);
  }

  Future<Map<String, dynamic>?> _getLocationDetails(String level, String locationId) async {
    try {
      // This would query the geographic hierarchy collections
      // For now, return basic structure
      return {
        'name': locationId,
        'level': level,
        'coordinates': null,
      };
    } catch (e) {
      debugPrint('Error getting location details: $e');
      return null;
    }
  }

  Future<List<String>> _getSuggestedMembersByLocation(String level, String locationId) async {
    try {
      final users = await DatabaseService.getUsersByLocation(
        level: level,
        locationId: locationId,
        limit: 50,
      );
      return users.map((user) => user.id).toList();
    } catch (e) {
      debugPrint('Error getting suggested members: $e');
      return [];
    }
  }

  GroupSettings _getDefaultGroupSettings(GroupType type, String level) {
    switch (type) {
      case GroupType.village:
        return GroupSettings(
          whoCanAddMembers: GroupPermission.coordinators,
          whoCanSendMessages: GroupPermission.all,
          whoCanShareMedia: GroupPermission.all,
          messageRetention: 365,
          requireApprovalToJoin: false,
          allowAnonymousMessages: true,
          encryptionLevel: 'standard',
        );
      case GroupType.legalCase:
        return GroupSettings(
          whoCanAddMembers: GroupPermission.admin,
          whoCanSendMessages: GroupPermission.all,
          whoCanShareMedia: GroupPermission.all,
          messageRetention: 1095, // 3 years for legal cases
          requireApprovalToJoin: true,
          allowAnonymousMessages: false,
          encryptionLevel: 'high_security',
        );
      case GroupType.campaign:
        return GroupSettings(
          whoCanAddMembers: GroupPermission.coordinators,
          whoCanSendMessages: GroupPermission.all,
          whoCanShareMedia: GroupPermission.coordinators,
          messageRetention: 90,
          requireApprovalToJoin: true,
          allowAnonymousMessages: false,
          encryptionLevel: 'standard',
        );
      default:
        return GroupSettings.defaultSettings();
    }
  }

  Future<void> _updateGeographicHierarchyWithGroup(String level, String locationId, String groupId) async {
    try {
      // Update the geographic hierarchy document with group reference
      await _firestore
          .collection('geographic_hierarchy')
          .doc('${level}_$locationId')
          .update({
        'groups': FieldValue.arrayUnion([groupId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating geographic hierarchy: $e');
    }
  }

  Future<void> _sendGroupWelcomeMessage(String groupId, GroupType type, String level) async {
    try {
      final group = await _groupService.getGroup(groupId);
      if (group == null) return;

      final conversationId = group.metadata['conversationId'] as String?;
      if (conversationId == null) return;

      final welcomeMessage = _getWelcomeMessage(type, level);
      
      await _messagingService.sendMessage(
        conversationId: conversationId,
        content: welcomeMessage,
        messageType: MessageType.system,
      );
    } catch (e) {
      debugPrint('Error sending group welcome message: $e');
    }
  }

  String _getWelcomeMessage(GroupType type, String level) {
    switch (type) {
      case GroupType.village:
        return 'Welcome to your village group! This is a secure space for coordinating land rights activities in your area.';
      case GroupType.campaign:
        return 'Welcome to the campaign coordination group! Use this space to organize events and share updates.';
      case GroupType.legalCase:
        return 'Welcome to the legal case group! All communications here are encrypted and will be retained for legal purposes.';
      default:
        return 'Welcome to the group! Let\'s work together for land rights.';
    }
  }

  Future<void> _createOrUpdateCampaignRecord(String campaignId, String campaignName, String groupId) async {
    try {
      await _firestore.collection('campaigns').doc(campaignId).set({
        'id': campaignId,
        'name': campaignName,
        'groupId': groupId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creating/updating campaign record: $e');
    }
  }

  Future<void> _updateGroupMembershipsForRoleChange(String userId, String newRole) async {
    try {
      // Get user's current groups
      final userGroups = await _groupService.getUserGroups();
      
      for (final group in userGroups) {
        final member = group.getMember(userId);
        if (member != null) {
          // Update member role in group based on new TALOWA role
          final newGroupRole = _getGroupRoleForTalowaRole(newRole, group.type);
          if (newGroupRole != member.groupRole) {
            await _groupService.updateMemberRole(
              groupId: group.id,
              userId: userId,
              newRole: newGroupRole,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating group memberships for role change: $e');
    }
  }

  GroupRole _getGroupRoleForTalowaRole(String talowaRole, GroupType groupType) {
    switch (talowaRole) {
      case AppConstants.roleFounder:
      case AppConstants.roleRootAdmin:
        return GroupRole.admin;
      case AppConstants.roleStateCoordinator:
      case AppConstants.roleDistrictCoordinator:
      case AppConstants.roleMandalCoordinator:
      case AppConstants.roleVillageCoordinator:
        return GroupRole.coordinator;
      case AppConstants.roleLegalAdvisor:
        return groupType == GroupType.legalCase ? GroupRole.coordinator : GroupRole.member;
      default:
        return GroupRole.member;
    }
  }

  Future<void> _updateConversationParticipantDetails(String userId, String newName) async {
    try {
      // This would update participant details in conversations
      // For now, we'll just log it
      debugPrint('Would update conversation participant details for $userId to $newName');
    } catch (e) {
      debugPrint('Error updating conversation participant details: $e');
    }
  }
}
