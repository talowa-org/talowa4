// TALOWA Messaging Integration Service
// Main integration service that coordinates all messaging integrations
// Reference: in-app-communication/tasks.md - Task 11

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/group_model.dart';
import '../../models/campaign_model.dart';
import 'cdn_integration_service.dart';
import '../../core/constants/app_constants.dart';
import '../auth_service.dart';
import 'performance_integration_service.dart';
import '../database_service.dart';
import '../campaign_service.dart';
import '../legal_case_service.dart';
import 'messaging_service.dart';
import 'group_service.dart';
import 'messaging_integration_service.dart';
import 'auth_integration_service.dart';

class TalowaMessagingIntegration {
  static final TalowaMessagingIntegration _instance = TalowaMessagingIntegration._internal();
  factory TalowaMessagingIntegration() => _instance;
  TalowaMessagingIntegration._internal();

  // Service instances
  final MessagingService _messagingService = MessagingService();
  final GroupService _groupService = GroupService();
  final MessagingIntegrationService _messagingIntegration = MessagingIntegrationService();
  final AuthIntegrationService _authIntegration = AuthIntegrationService();
  final CampaignService _campaignService = CampaignService();
  final LegalCaseService _legalCaseService = LegalCaseService();
  final PerformanceIntegrationService _performanceService = PerformanceIntegrationService();

  bool _isInitialized = false;

  /// Initialize the complete messaging integration system
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      debugPrint('Initializing TALOWA Messaging Integration...');

      // Initialize performance optimization services
      await _performanceService.initialize();

      // Initialize authentication integration
      await _authIntegration.initialize();

      // Initialize messaging profiles for existing users if needed
      await _initializeExistingUsers();

      _isInitialized = true;
      debugPrint('TALOWA Messaging Integration initialized successfully');
    } catch (e) {
      debugPrint('Error initializing TALOWA Messaging Integration: $e');
      rethrow;
    }
  }

  /// Initialize messaging profiles for existing users
  Future<void> _initializeExistingUsers() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        // Initialize current user's messaging profile
        await _messagingIntegration.initializeUserMessagingProfile(currentUser.uid);
      }
    } catch (e) {
      debugPrint('Error initializing existing users: $e');
    }
  }

  /// Create a message with automatic linking to cases/land records
  Future<String> sendIntegratedMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
    String? linkedCaseId,
    String? linkedLandRecordId,
    String? linkedCampaignId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      // Send the message first
      final messageId = await _messagingService.sendMessage(
        conversationId: conversationId,
        content: content,
        messageType: messageType,
        mediaUrls: mediaUrls,
        metadata: {
          ...?additionalMetadata,
          'hasIntegrationLinks': linkedCaseId != null || linkedLandRecordId != null || linkedCampaignId != null,
        },
      );

      // Link to cases/records if specified
      if (linkedCaseId != null || linkedLandRecordId != null || linkedCampaignId != null) {
        await _messagingIntegration.linkMessageToCase(
          messageId: messageId,
          legalCaseId: linkedCaseId,
          landRecordId: linkedLandRecordId,
          campaignId: linkedCampaignId,
        );
      }

      return messageId;
    } catch (e) {
      debugPrint('Error sending integrated message: $e');
      rethrow;
    }
  }

  /// Create a group with automatic geographic integration
  Future<String> createIntegratedGroup({
    required String name,
    required String description,
    required GroupType type,
    String? level,
    String? locationId,
    List<String>? initialMemberIds,
    GroupSettings? customSettings,
    String? avatarUrl,
  }) async {
    try {
      if (level != null && locationId != null) {
        // Create geographic group
        return await _messagingIntegration.createGeographicGroup(
          name: name,
          description: description,
          type: type,
          level: level,
          locationId: locationId,
          avatarUrl: avatarUrl,
          customSettings: customSettings,
        );
      } else {
        // Create regular group with user's location
        final currentUser = AuthService.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated');
        }

        final userProfile = await DatabaseService.getUserProfile(currentUser.uid);
        if (userProfile == null) {
          throw Exception('User profile not found');
        }

        final geographicScope = GeographicScope(
          level: AppConstants.levelVillage,
          locationId: userProfile.address.villageCity,
          locationName: userProfile.address.villageCity,
        );

        return await _groupService.createGroup(
          name: name,
          description: description,
          type: type,
          location: geographicScope,
          initialMemberIds: initialMemberIds,
          settings: customSettings,
          avatarUrl: avatarUrl,
        );
      }
    } catch (e) {
      debugPrint('Error creating integrated group: $e');
      rethrow;
    }
  }

  /// Create a campaign with integrated messaging group
  Future<String> createCampaignWithMessaging({
    required String name,
    required String description,
    required CampaignType type,
    required CampaignLocation location,
    required DateTime startDate,
    DateTime? endDate,
    required CampaignGoals goals,
    List<String>? coordinatorIds,
  }) async {
    try {
      return await _campaignService.createCampaign(
        name: name,
        description: description,
        type: type,
        location: location,
        startDate: startDate,
        endDate: endDate,
        goals: goals,
        coordinatorIds: coordinatorIds,
        createMessagingGroup: true,
      );
    } catch (e) {
      debugPrint('Error creating campaign with messaging: $e');
      rethrow;
    }
  }

  /// Get all messages related to a legal case
  Stream<List<MessageModel>> getCaseRelatedMessages(String caseId) {
    return _messagingIntegration.getCaseMessages(caseId);
  }

  /// Get all messages related to a land record
  Stream<List<MessageModel>> getLandRecordRelatedMessages(String landRecordId) {
    return _messagingIntegration.getLandRecordMessages(landRecordId);
  }

  /// Get groups based on user's location and role
  Future<List<GroupModel>> getRecommendedGroups() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      // Get location-based groups
      final locationGroups = await _messagingIntegration.getLocationBasedGroups();

      // Get user's role-based permissions
      final permissions = await _authIntegration.getUserMessagingPermissions(currentUser.uid);

      // Filter groups based on permissions and relevance
      final recommendedGroups = <GroupModel>[];

      for (final group in locationGroups) {
        // Add groups user can join based on their role and location
        if (_shouldRecommendGroup(group, permissions)) {
          recommendedGroups.add(group);
        }
      }

      return recommendedGroups;
    } catch (e) {
      debugPrint('Error getting recommended groups: $e');
      return [];
    }
  }

  /// Check if user can perform messaging action
  Future<bool> canPerformAction({
    required String action,
    String? targetUserId,
    String? groupId,
    String? caseId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return false;

      // Validate user session
      final isValidSession = await _authIntegration.validateUserSession(currentUser.uid);
      if (!isValidSession) return false;

      // Get user permissions
      final permissions = await _authIntegration.getUserMessagingPermissions(currentUser.uid);

      switch (action) {
        case 'send_direct_message':
          if (targetUserId == null) return false;
          return await _authIntegration.canSendDirectMessage(currentUser.uid, targetUserId);

        case 'create_group':
          return permissions['canCreateGroups'] ?? false;

        case 'create_campaign_group':
          return permissions['canCreateCampaignGroups'] ?? false;

        case 'create_legal_case_group':
          return permissions['canCreateLegalCaseGroups'] ?? false;

        case 'send_emergency_broadcast':
          return permissions['canSendEmergencyBroadcasts'] ?? false;

        case 'moderate_content':
          return permissions['canModerateContent'] ?? false;

        case 'link_to_case':
          if (caseId == null) return false;
          if (permissions['canLinkToAllCases'] == true) return true;
          
          // Check if user owns the case
          final legalCase = await _legalCaseService.getLegalCase(caseId);
          return legalCase?.clientId == currentUser.uid;

        default:
          return false;
      }
    } catch (e) {
      debugPrint('Error checking action permission: $e');
      return false;
    }
  }

  /// Get user's messaging dashboard data
  Future<Map<String, dynamic>> getUserMessagingDashboard() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        return {'error': 'User not authenticated'};
      }

      // Get user's conversations
      final conversations = await _messagingService.getUserConversations().first;

      // Get user's groups
      final groups = await _groupService.getUserGroups();

      // Get active campaigns for user's location
      final campaigns = await _campaignService.getActiveCampaignsForUser();

      // Get recommended groups
      final recommendedGroups = await getRecommendedGroups();

      // Get user permissions
      final permissions = await _authIntegration.getUserMessagingPermissions(currentUser.uid);

      return {
        'conversations': conversations.length,
        'groups': groups.length,
        'activeCampaigns': campaigns.length,
        'recommendedGroups': recommendedGroups.length,
        'permissions': permissions,
        'canCreateGroups': permissions['canCreateGroups'] ?? false,
        'canCreateCampaigns': permissions['canCreateCampaignGroups'] ?? false,
      };
    } catch (e) {
      debugPrint('Error getting user messaging dashboard: $e');
      return {'error': e.toString()};
    }
  }

  /// Sync user data across all messaging components
  Future<void> syncUserData(String userId) async {
    try {
      await _messagingIntegration.syncUserAccountWithMessaging(userId);
      debugPrint('User data synced across messaging components: $userId');
    } catch (e) {
      debugPrint('Error syncing user data: $e');
      rethrow;
    }
  }

  // Private helper methods

  bool _shouldRecommendGroup(GroupModel group, Map<String, bool> permissions) {
    // Don't recommend groups user is already a member of
    final currentUser = AuthService.currentUser;
    if (currentUser != null && group.isMember(currentUser.uid)) {
      return false;
    }

    // Recommend based on group type and user permissions
    switch (group.type) {
      case GroupType.village:
      case GroupType.mandal:
      case GroupType.district:
        return true; // Always recommend geographic groups

      case GroupType.campaign:
        return permissions['canCreateCampaignGroups'] == true || group.settings.requireApprovalToJoin == false;

      case GroupType.legalCase:
        return permissions['canCreateLegalCaseGroups'] == true;

      case GroupType.custom:
        return true;
    }
  }

  /// Load messages with performance optimization
  Future<OptimizedMessageResult> loadMessagesOptimized({
    required String conversationId,
    int page = 0,
    int pageSize = 50,
    bool useCache = true,
    bool preloadNext = true,
  }) async {
    return await _performanceService.loadMessagesOptimized(
      conversationId: conversationId,
      page: page,
      pageSize: pageSize,
      useCache: useCache,
      preloadNext: preloadNext,
    );
  }

  /// Load group members with performance optimization
  Future<OptimizedGroupMemberResult> loadGroupMembersOptimized({
    required String groupId,
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
    bool useCache = true,
  }) async {
    return await _performanceService.loadGroupMembersOptimized(
      groupId: groupId,
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      useCache: useCache,
    );
  }

  /// Upload media with performance optimization
  Future<OptimizedMediaUploadResult> uploadMediaOptimized({
    required String fileName,
    required Uint8List fileData,
    required MediaType mediaType,
    String? conversationId,
    bool enableCompression = true,
  }) async {
    return await _performanceService.uploadMediaOptimized(
      fileName: fileName,
      fileData: fileData,
      mediaType: mediaType,
      conversationId: conversationId,
      enableCompression: enableCompression,
    );
  }

  /// Get comprehensive performance statistics
  Map<String, dynamic> getPerformanceStatistics() {
    return _performanceService.getPerformanceStatistics();
  }

  /// Optimize performance based on current metrics
  Future<void> optimizePerformance() async {
    await _performanceService.optimizePerformance();
  }

  /// Clear all performance caches
  Future<void> clearAllCaches() async {
    await _performanceService.clearAllCaches();
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _performanceService.dispose();
      await _authIntegration.dispose();
      _isInitialized = false;
      debugPrint('TALOWA Messaging Integration disposed');
    } catch (e) {
      debugPrint('Error disposing TALOWA Messaging Integration: $e');
    }
  }
}
