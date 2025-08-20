// Campaign Service for TALOWA
// Manages campaigns and integrates with messaging system
// Reference: TALOWA_APP_BLUEPRINT.md - Campaign Management

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/campaign_model.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'messaging/messaging_integration_service.dart';

class CampaignService {
  static final CampaignService _instance = CampaignService._internal();
  factory CampaignService() => _instance;
  CampaignService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _campaignsCollection = 'campaigns';
  final MessagingIntegrationService _messagingIntegration = MessagingIntegrationService();

  /// Create a new campaign
  Future<String> createCampaign({
    required String name,
    required String description,
    required CampaignType type,
    required CampaignLocation location,
    required DateTime startDate,
    DateTime? endDate,
    required CampaignGoals goals,
    List<String>? coordinatorIds,
    bool createMessagingGroup = true,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Verify user has permission to create campaigns
      final userProfile = await DatabaseService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      if (!_canCreateCampaign(userProfile.role)) {
        throw Exception('Insufficient permissions to create campaigns');
      }

      final campaignId = _firestore.collection(_campaignsCollection).doc().id;

      // Create campaign
      final campaign = CampaignModel(
        id: campaignId,
        name: name,
        description: description,
        type: type,
        status: CampaignStatus.planning,
        createdBy: currentUser.uid,
        coordinatorIds: coordinatorIds ?? [currentUser.uid],
        location: location,
        startDate: startDate,
        endDate: endDate,
        goals: goals,
        events: [],
        metrics: CampaignMetrics.empty(),
        documentUrls: [],
        metadata: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      // Save campaign to Firestore
      await _firestore.collection(_campaignsCollection).doc(campaignId).set(campaign.toFirestore());

      // Create messaging group for campaign coordination
      String? groupId;
      if (createMessagingGroup) {
        try {
          groupId = await _messagingIntegration.createCampaignGroup(
            campaignId: campaignId,
            campaignName: name,
            description: 'Coordination group for $name campaign',
            coordinatorIds: coordinatorIds,
          );

          // Update campaign with group ID
          await _firestore.collection(_campaignsCollection).doc(campaignId).update({
            'groupId': groupId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Failed to create messaging group for campaign: $e');
        }
      }

      debugPrint('Campaign created successfully: $campaignId');
      return campaignId;
    } catch (e) {
      debugPrint('Error creating campaign: $e');
      rethrow;
    }
  }

  /// Get campaigns for current user
  Stream<List<CampaignModel>> getUserCampaigns() {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        return Stream.value([]);
      }

      return _firestore
          .collection(_campaignsCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CampaignModel.fromFirestore(doc))
            .where((campaign) =>
                campaign.createdBy == currentUser.uid ||
                campaign.coordinatorIds.contains(currentUser.uid))
            .toList();
      });
    } catch (e) {
      debugPrint('Error getting user campaigns: $e');
      return Stream.value([]);
    }
  }

  /// Get campaigns by location
  Future<List<CampaignModel>> getCampaignsByLocation({
    required String level,
    required String locationId,
    CampaignStatus? status,
  }) async {
    try {
      Query query = _firestore
          .collection(_campaignsCollection)
          .where('isActive', isEqualTo: true)
          .where('location.level', isEqualTo: level)
          .where('location.locationId', isEqualTo: locationId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => CampaignModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting campaigns by location: $e');
      return [];
    }
  }

  /// Get campaign by ID
  Future<CampaignModel?> getCampaign(String campaignId) async {
    try {
      final doc = await _firestore.collection(_campaignsCollection).doc(campaignId).get();
      if (doc.exists) {
        return CampaignModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting campaign: $e');
      return null;
    }
  }

  /// Update campaign
  Future<void> updateCampaign({
    required String campaignId,
    String? name,
    String? description,
    CampaignStatus? status,
    DateTime? endDate,
    CampaignGoals? goals,
    List<String>? coordinatorIds,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Verify user has permission to update campaign
      final campaign = await getCampaign(campaignId);
      if (campaign == null) {
        throw Exception('Campaign not found');
      }

      if (!_canUpdateCampaign(currentUser.uid, campaign)) {
        throw Exception('Insufficient permissions to update campaign');
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (status != null) updateData['status'] = status.value;
      if (endDate != null) updateData['endDate'] = Timestamp.fromDate(endDate);
      if (goals != null) updateData['goals'] = goals.toMap();
      if (coordinatorIds != null) updateData['coordinatorIds'] = coordinatorIds;

      await _firestore.collection(_campaignsCollection).doc(campaignId).update(updateData);

      debugPrint('Campaign updated successfully: $campaignId');
    } catch (e) {
      debugPrint('Error updating campaign: $e');
      rethrow;
    }
  }

  /// Add event to campaign
  Future<void> addCampaignEvent({
    required String campaignId,
    required String eventName,
    required String eventDescription,
    required DateTime scheduledAt,
    String? location,
    List<String>? participantIds,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Verify user has permission to add events
      final campaign = await getCampaign(campaignId);
      if (campaign == null) {
        throw Exception('Campaign not found');
      }

      if (!_canUpdateCampaign(currentUser.uid, campaign)) {
        throw Exception('Insufficient permissions to add events');
      }

      final eventId = _firestore.collection('campaign_events').doc().id;
      final event = CampaignEvent(
        id: eventId,
        name: eventName,
        description: eventDescription,
        scheduledAt: scheduledAt,
        location: location,
        status: EventStatus.scheduled,
        participantIds: participantIds ?? [],
        metadata: {},
      );

      // Add event to campaign
      await _firestore.collection(_campaignsCollection).doc(campaignId).update({
        'events': FieldValue.arrayUnion([event.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to campaign group if exists
      if (campaign.groupId != null) {
        await _notifyCampaignGroup(
          campaign.groupId!,
          'New Event: $eventName',
          'Event scheduled for ${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year}',
        );
      }

      debugPrint('Event added to campaign: $eventId');
    } catch (e) {
      debugPrint('Error adding campaign event: $e');
      rethrow;
    }
  }

  /// Update campaign metrics
  Future<void> updateCampaignMetrics({
    required String campaignId,
    int? actualParticipants,
    int? landRecordsDocumented,
    int? pattaApplicationsSubmitted,
    int? eventsCompleted,
    Map<String, int>? customMetrics,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Verify user has permission to update metrics
      final campaign = await getCampaign(campaignId);
      if (campaign == null) {
        throw Exception('Campaign not found');
      }

      if (!_canUpdateCampaign(currentUser.uid, campaign)) {
        throw Exception('Insufficient permissions to update metrics');
      }

      final currentMetrics = campaign.metrics;
      final updatedMetrics = CampaignMetrics(
        actualParticipants: actualParticipants ?? currentMetrics.actualParticipants,
        landRecordsDocumented: landRecordsDocumented ?? currentMetrics.landRecordsDocumented,
        pattaApplicationsSubmitted: pattaApplicationsSubmitted ?? currentMetrics.pattaApplicationsSubmitted,
        eventsCompleted: eventsCompleted ?? currentMetrics.eventsCompleted,
        successRate: _calculateSuccessRate(campaign.goals, currentMetrics),
        customMetrics: customMetrics ?? currentMetrics.customMetrics,
      );

      await _firestore.collection(_campaignsCollection).doc(campaignId).update({
        'metrics': updatedMetrics.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Campaign metrics updated: $campaignId');
    } catch (e) {
      debugPrint('Error updating campaign metrics: $e');
      rethrow;
    }
  }

  /// Search campaigns
  Future<List<CampaignModel>> searchCampaigns({
    required String query,
    CampaignType? type,
    CampaignStatus? status,
    String? location,
  }) async {
    try {
      Query firestoreQuery = _firestore
          .collection(_campaignsCollection)
          .where('isActive', isEqualTo: true);

      if (type != null) {
        firestoreQuery = firestoreQuery.where('type', isEqualTo: type.value);
      }

      if (status != null) {
        firestoreQuery = firestoreQuery.where('status', isEqualTo: status.value);
      }

      if (location != null) {
        firestoreQuery = firestoreQuery.where('location.locationId', isEqualTo: location);
      }

      final snapshot = await firestoreQuery.get();

      // Filter by search query locally
      return snapshot.docs
          .map((doc) => CampaignModel.fromFirestore(doc))
          .where((campaign) =>
              campaign.name.toLowerCase().contains(query.toLowerCase()) ||
              campaign.description.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      debugPrint('Error searching campaigns: $e');
      return [];
    }
  }

  /// Get active campaigns for user's location
  Future<List<CampaignModel>> getActiveCampaignsForUser() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      final userProfile = await DatabaseService.getUserProfile(currentUser.uid);
      if (userProfile == null) return [];

      final address = userProfile.address;
      final campaigns = <CampaignModel>[];

      // Get village campaigns
      final villageCampaigns = await getCampaignsByLocation(
        level: AppConstants.levelVillage,
        locationId: address.villageCity,
        status: CampaignStatus.active,
      );
      campaigns.addAll(villageCampaigns);

      // Get mandal campaigns
      final mandalCampaigns = await getCampaignsByLocation(
        level: AppConstants.levelMandal,
        locationId: address.mandal,
        status: CampaignStatus.active,
      );
      campaigns.addAll(mandalCampaigns);

      // Get district campaigns
      final districtCampaigns = await getCampaignsByLocation(
        level: AppConstants.levelDistrict,
        locationId: address.district,
        status: CampaignStatus.active,
      );
      campaigns.addAll(districtCampaigns);

      // Remove duplicates
      final uniqueCampaigns = <String, CampaignModel>{};
      for (final campaign in campaigns) {
        uniqueCampaigns[campaign.id] = campaign;
      }

      return uniqueCampaigns.values.toList();
    } catch (e) {
      debugPrint('Error getting active campaigns for user: $e');
      return [];
    }
  }

  /// Join campaign as participant
  Future<void> joinCampaign(String campaignId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final campaign = await getCampaign(campaignId);
      if (campaign == null) {
        throw Exception('Campaign not found');
      }

      // Add user to campaign participants (stored in metadata)
      await _firestore.collection(_campaignsCollection).doc(campaignId).update({
        'metadata.participants': FieldValue.arrayUnion([currentUser.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update participant count in metrics
      await _firestore.collection(_campaignsCollection).doc(campaignId).update({
        'metrics.actualParticipants': FieldValue.increment(1),
      });

      debugPrint('User joined campaign: $campaignId');
    } catch (e) {
      debugPrint('Error joining campaign: $e');
      rethrow;
    }
  }

  // Private helper methods

  bool _canCreateCampaign(String userRole) {
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

  bool _canUpdateCampaign(String userId, CampaignModel campaign) {
    return campaign.createdBy == userId || campaign.coordinatorIds.contains(userId);
  }

  double _calculateSuccessRate(CampaignGoals goals, CampaignMetrics metrics) {
    if (goals.targetParticipants == 0) return 0.0;
    
    final participantRate = metrics.actualParticipants / goals.targetParticipants;
    final landRecordRate = goals.targetLandRecords > 0 
        ? metrics.landRecordsDocumented / goals.targetLandRecords 
        : 1.0;
    final pattaRate = goals.targetPattaApplications > 0 
        ? metrics.pattaApplicationsSubmitted / goals.targetPattaApplications 
        : 1.0;

    return ((participantRate + landRecordRate + pattaRate) / 3).clamp(0.0, 1.0);
  }

  Future<void> _notifyCampaignGroup(String groupId, String title, String message) async {
    try {
      // This would send a message to the campaign group
      // For now, we'll just log it
      debugPrint('Would notify campaign group $groupId: $title - $message');
    } catch (e) {
      debugPrint('Error notifying campaign group: $e');
    }
  }
}