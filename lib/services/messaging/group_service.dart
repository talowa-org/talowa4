// Group Service for TALOWA Messaging System
// Reference: in-app-communication/design.md - Group Management Component

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/group_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/messaging/message_model.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';
import '../auth_service.dart';
import 'messaging_service.dart';

class GroupService {
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;
  GroupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _groupsCollection = 'groups';
  final String _usersCollection = AppConstants.collectionUsers;
  final MessagingService _messagingService = MessagingService();

  // Create a new group
  Future<String> createGroup({
    required String name,
    required String description,
    required GroupType type,
    required GeographicScope location,
    List<String>? initialMemberIds,
    GroupSettings? settings,
    String? avatarUrl,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user profile
      final userDoc = await _firestore.collection(_usersCollection).doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final userModel = UserModel.fromFirestore(userDoc);

      // Check if user has permission to create groups
      if (!_canCreateGroup(userModel.role, type)) {
        throw Exception('Insufficient permissions to create this type of group');
      }

      final groupId = _firestore.collection(_groupsCollection).doc().id;

      // Create initial members list with creator as admin
      final members = <GroupMember>[
        GroupMember(
          userId: currentUser.uid,
          name: userData['fullName'] ?? 'Unknown User',
          role: userModel.role,
          groupRole: GroupRole.admin,
          joinedAt: DateTime.now(),
          isActive: true,
        ),
      ];

      // Add initial members if provided
      if (initialMemberIds != null && initialMemberIds.isNotEmpty) {
        for (final memberId in initialMemberIds) {
          if (memberId != currentUser.uid) {
            final memberDoc = await _firestore.collection(_usersCollection).doc(memberId).get();
            if (memberDoc.exists) {
              final memberData = memberDoc.data()!;
              members.add(
                GroupMember(
                  userId: memberId,
                  name: memberData['fullName'] ?? 'Unknown User',
                  role: memberData['role'] ?? AppConstants.roleMember,
                  groupRole: GroupRole.member,
                  joinedAt: DateTime.now(),
                  isActive: true,
                ),
              );
            }
          }
        }
      }

      final group = GroupModel(
        id: groupId,
        name: name,
        description: description,
        type: type,
        location: location,
        members: members,
        maxMembers: _getMaxMembersForType(type),
        memberCount: members.length,
        settings: settings ?? GroupSettings.defaultSettings(),
        createdBy: currentUser.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        avatarUrl: avatarUrl,
        metadata: {},
      );

      // Save group to Firestore
      await _firestore.collection(_groupsCollection).doc(groupId).set(group.toFirestore());

      // Create associated conversation
      final conversationId = await _messagingService.createConversation(
        name: name,
        type: ConversationType.group,
        participantIds: members.map((m) => m.userId).toList(),
        description: description,
      );

      // Update group with conversation ID
      await _firestore.collection(_groupsCollection).doc(groupId).update({
        'metadata.conversationId': conversationId,
      });

      debugPrint('Group created successfully: $groupId');
      return groupId;
    } catch (e) {
      debugPrint('Error creating group: $e');
      rethrow;
    }
  }

  // Get groups by geographic location
  Future<List<GroupModel>> getGroupsByLocation(GeographicScope location) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      Query query = _firestore
          .collection(_groupsCollection)
          .where('isActive', isEqualTo: true)
          .where('location.level', isEqualTo: location.level);

      // Add location-specific filtering
      if (location.locationId.isNotEmpty) {
        query = query.where('location.locationId', isEqualTo: location.locationId);
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => GroupModel.fromFirestore(doc))
          .where((group) => group.isActive)
          .toList();
    } catch (e) {
      debugPrint('Error getting groups by location: $e');
      return [];
    }
  }

  // Get groups for current user
  Future<List<GroupModel>> getUserGroups() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection(_groupsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => GroupModel.fromFirestore(doc))
          .where((group) => group.isMember(currentUser.uid))
          .toList();
    } catch (e) {
      debugPrint('Error getting user groups: $e');
      return [];
    }
  }

  // Search groups
  Future<List<GroupModel>> searchGroups({
    required String query,
    GroupType? type,
    String? level,
    String? locationId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      Query firestoreQuery = _firestore
          .collection(_groupsCollection)
          .where('isActive', isEqualTo: true);

      // Add type filter if specified
      if (type != null) {
        firestoreQuery = firestoreQuery.where('type', isEqualTo: type.value);
      }

      // Add location filters if specified
      if (level != null) {
        firestoreQuery = firestoreQuery.where('location.level', isEqualTo: level);
      }

      if (locationId != null) {
        firestoreQuery = firestoreQuery.where('location.locationId', isEqualTo: locationId);
      }

      final snapshot = await firestoreQuery.get();

      // Filter by search query locally
      return snapshot.docs
          .map((doc) => GroupModel.fromFirestore(doc))
          .where((group) =>
              group.name.toLowerCase().contains(query.toLowerCase()) ||
              group.description.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      debugPrint('Error searching groups: $e');
      return [];
    }
  }

  // Add member to group
  Future<void> addMember({
    required String groupId,
    required String userId,
    GroupRole? groupRole,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get group
      final groupDoc = await _firestore.collection(_groupsCollection).doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final group = GroupModel.fromFirestore(groupDoc);

      // Check permissions
      if (!group.canAddMembers(currentUser.uid)) {
        throw Exception('Insufficient permissions to add members');
      }

      // Check if user is already a member
      if (group.isMember(userId)) {
        throw Exception('User is already a member of this group');
      }

      // Check member limit
      if (group.memberCount >= group.maxMembers) {
        throw Exception('Group has reached maximum member limit');
      }

      // Get user profile
      final userDoc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;

      // Create new member
      final newMember = GroupMember(
        userId: userId,
        name: userData['fullName'] ?? 'Unknown User',
        role: userData['role'] ?? AppConstants.roleMember,
        groupRole: groupRole ?? GroupRole.member,
        joinedAt: DateTime.now(),
        isActive: true,
      );

      // Update group with new member
      final updatedMembers = [...group.members, newMember];
      
      await _firestore.collection(_groupsCollection).doc(groupId).update({
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'memberCount': updatedMembers.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to conversation if it exists
      final conversationId = group.metadata['conversationId'] as String?;
      if (conversationId != null) {
        await _messagingService.addParticipant(
          conversationId: conversationId,
          userId: userId,
        );
      }

      debugPrint('Member added successfully to group: $groupId');
    } catch (e) {
      debugPrint('Error adding member to group: $e');
      rethrow;
    }
  }

  // Remove member from group
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get group
      final groupDoc = await _firestore.collection(_groupsCollection).doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final group = GroupModel.fromFirestore(groupDoc);

      // Check permissions (admin can remove anyone, users can remove themselves)
      if (!group.isAdmin(currentUser.uid) && currentUser.uid != userId) {
        throw Exception('Insufficient permissions to remove this member');
      }

      // Don't allow removing the last admin
      final member = group.getMember(userId);
      if (member?.groupRole == GroupRole.admin) {
        final adminCount = group.members.where((m) => m.groupRole == GroupRole.admin).length;
        if (adminCount <= 1) {
          throw Exception('Cannot remove the last admin from the group');
        }
      }

      // Remove member
      final updatedMembers = group.members.where((m) => m.userId != userId).toList();
      
      await _firestore.collection(_groupsCollection).doc(groupId).update({
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'memberCount': updatedMembers.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove from conversation if it exists
      final conversationId = group.metadata['conversationId'] as String?;
      if (conversationId != null) {
        await _messagingService.removeParticipant(
          conversationId: conversationId,
          userId: userId,
        );
      }

      debugPrint('Member removed successfully from group: $groupId');
    } catch (e) {
      debugPrint('Error removing member from group: $e');
      rethrow;
    }
  }

  // Update member role
  Future<void> updateMemberRole({
    required String groupId,
    required String userId,
    required GroupRole newRole,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get group
      final groupDoc = await _firestore.collection(_groupsCollection).doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final group = GroupModel.fromFirestore(groupDoc);

      // Check permissions (only admin can change roles)
      if (!group.isAdmin(currentUser.uid)) {
        throw Exception('Insufficient permissions to change member roles');
      }

      // Find and update member
      final updatedMembers = group.members.map((member) {
        if (member.userId == userId) {
          return member.copyWith(groupRole: newRole);
        }
        return member;
      }).toList();

      await _firestore.collection(_groupsCollection).doc(groupId).update({
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Member role updated successfully in group: $groupId');
    } catch (e) {
      debugPrint('Error updating member role: $e');
      rethrow;
    }
  }

  // Update group settings
  Future<void> updateGroupSettings({
    required String groupId,
    required GroupSettings settings,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get group
      final groupDoc = await _firestore.collection(_groupsCollection).doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final group = GroupModel.fromFirestore(groupDoc);

      // Check permissions (only admin can change settings)
      if (!group.isAdmin(currentUser.uid)) {
        throw Exception('Insufficient permissions to change group settings');
      }

      await _firestore.collection(_groupsCollection).doc(groupId).update({
        'settings': settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Group settings updated successfully: $groupId');
    } catch (e) {
      debugPrint('Error updating group settings: $e');
      rethrow;
    }
  }

  // Send bulk message to all group members
  Future<void> sendBulkMessage({
    required String groupId,
    required String content,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get group
      final groupDoc = await _firestore.collection(_groupsCollection).doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final group = GroupModel.fromFirestore(groupDoc);

      // Check permissions
      if (!group.canSendMessages(currentUser.uid)) {
        throw Exception('Insufficient permissions to send messages to this group');
      }

      // Send message to group conversation
      final conversationId = group.metadata['conversationId'] as String?;
      if (conversationId != null) {
        await _messagingService.sendMessage(
          conversationId: conversationId,
          content: content,
          messageType: messageType,
          mediaUrls: mediaUrls,
          metadata: {
            ...?metadata,
            'isBulkMessage': true,
            'groupId': groupId,
          },
        );
      } else {
        throw Exception('Group conversation not found');
      }

      debugPrint('Bulk message sent successfully to group: $groupId');
    } catch (e) {
      debugPrint('Error sending bulk message: $e');
      rethrow;
    }
  }

  // Get group by ID
  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final doc = await _firestore.collection(_groupsCollection).doc(groupId).get();
      if (doc.exists) {
        return GroupModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting group: $e');
      return null;
    }
  }

  // Get group analytics
  Future<GroupAnalytics> getGroupAnalytics(String groupId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get group
      final group = await getGroup(groupId);
      if (group == null) {
        throw Exception('Group not found');
      }

      // Check permissions (only coordinators and admins can view analytics)
      if (!group.isCoordinator(currentUser.uid) && !group.isAdmin(currentUser.uid)) {
        throw Exception('Insufficient permissions to view group analytics');
      }

      // Calculate analytics
      final totalMembers = group.memberCount;
      final activeMembers = group.members.where((m) => m.isActive).length;
      final coordinators = group.members.where((m) => m.groupRole == GroupRole.coordinator).length;
      final admins = group.members.where((m) => m.groupRole == GroupRole.admin).length;

      // Get message count from conversation
      int messageCount = 0;
      final conversationId = group.metadata['conversationId'] as String?;
      if (conversationId != null) {
        final messagesSnapshot = await _firestore
            .collection('messages')
            .where('conversationId', isEqualTo: conversationId)
            .where('isDeleted', isEqualTo: false)
            .get();
        messageCount = messagesSnapshot.docs.length;
      }

      return GroupAnalytics(
        groupId: groupId,
        totalMembers: totalMembers,
        activeMembers: activeMembers,
        coordinators: coordinators,
        admins: admins,
        messageCount: messageCount,
        createdAt: group.createdAt,
        lastActivity: group.updatedAt,
      );
    } catch (e) {
      debugPrint('Error getting group analytics: $e');
      rethrow;
    }
  }

  // Discover groups based on user's location
  Future<List<GroupModel>> discoverGroups() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      // Get user profile to determine location
      final userDoc = await _firestore.collection(_usersCollection).doc(currentUser.uid).get();
      if (!userDoc.exists) return [];

      final userModel = UserModel.fromFirestore(userDoc);
      final userAddress = userModel.address;

      // Search for groups at different geographic levels
      final List<GroupModel> discoveredGroups = [];

      // Village level groups
      final villageGroups = await getGroupsByLocation(
        GeographicScope(
          level: AppConstants.levelVillage,
          locationId: userAddress.villageCity,
          locationName: userAddress.villageCity,
        ),
      );
      discoveredGroups.addAll(villageGroups);

      // Mandal level groups
      final mandalGroups = await getGroupsByLocation(
        GeographicScope(
          level: AppConstants.levelMandal,
          locationId: userAddress.mandal,
          locationName: userAddress.mandal,
        ),
      );
      discoveredGroups.addAll(mandalGroups);

      // District level groups
      final districtGroups = await getGroupsByLocation(
        GeographicScope(
          level: AppConstants.levelDistrict,
          locationId: userAddress.district,
          locationName: userAddress.district,
        ),
      );
      discoveredGroups.addAll(districtGroups);

      // Remove duplicates and groups user is already a member of
      final uniqueGroups = <String, GroupModel>{};
      for (final group in discoveredGroups) {
        if (!group.isMember(currentUser.uid) && !uniqueGroups.containsKey(group.id)) {
          uniqueGroups[group.id] = group;
        }
      }

      return uniqueGroups.values.toList();
    } catch (e) {
      debugPrint('Error discovering groups: $e');
      return [];
    }
  }

  // Private helper methods
  bool _canCreateGroup(String userRole, GroupType groupType) {
    switch (groupType) {
      case GroupType.village:
        return [
          AppConstants.roleAreaCoordinator,
          AppConstants.roleMandalCoordinator,
          AppConstants.roleConstituencyCoordinator,
          AppConstants.roleDistrictCoordinator,
          AppConstants.roleZonalRegionalCoordinator,
          AppConstants.roleStateCoordinator,
          AppConstants.roleFounder,
          AppConstants.roleRootAdmin,
        ].contains(userRole);
      case GroupType.mandal:
        return [
          AppConstants.roleMandalCoordinator,
          AppConstants.roleConstituencyCoordinator,
          AppConstants.roleDistrictCoordinator,
          AppConstants.roleZonalRegionalCoordinator,
          AppConstants.roleStateCoordinator,
          AppConstants.roleFounder,
          AppConstants.roleRootAdmin,
        ].contains(userRole);
      case GroupType.district:
        return [
          AppConstants.roleDistrictCoordinator,
          AppConstants.roleZonalRegionalCoordinator,
          AppConstants.roleStateCoordinator,
          AppConstants.roleFounder,
          AppConstants.roleRootAdmin,
        ].contains(userRole);
      case GroupType.campaign:
      case GroupType.legalCase:
      case GroupType.custom:
        return [
          AppConstants.roleTeamLeader,
          AppConstants.roleAreaCoordinator,
          AppConstants.roleMandalCoordinator,
          AppConstants.roleConstituencyCoordinator,
          AppConstants.roleDistrictCoordinator,
          AppConstants.roleZonalRegionalCoordinator,
          AppConstants.roleStateCoordinator,
          AppConstants.roleLegalAdvisor,
          AppConstants.roleMediaCoordinator,
          AppConstants.roleFounder,
          AppConstants.roleRootAdmin,
        ].contains(userRole);
    }
  }

  int _getMaxMembersForType(GroupType type) {
    switch (type) {
      case GroupType.village:
        return 500;
      case GroupType.mandal:
        return 2000;
      case GroupType.district:
        return 10000;
      case GroupType.campaign:
        return 1000;
      case GroupType.legalCase:
        return 100;
      case GroupType.custom:
        return 500;
    }
  }
}

// Group analytics model
class GroupAnalytics {
  final String groupId;
  final int totalMembers;
  final int activeMembers;
  final int coordinators;
  final int admins;
  final int messageCount;
  final DateTime createdAt;
  final DateTime lastActivity;

  GroupAnalytics({
    required this.groupId,
    required this.totalMembers,
    required this.activeMembers,
    required this.coordinators,
    required this.admins,
    required this.messageCount,
    required this.createdAt,
    required this.lastActivity,
  });

  double get activityRate {
    if (totalMembers == 0) return 0.0;
    return activeMembers / totalMembers;
  }

  double get messagesPerMember {
    if (totalMembers == 0) return 0.0;
    return messageCount / totalMembers;
  }
}
