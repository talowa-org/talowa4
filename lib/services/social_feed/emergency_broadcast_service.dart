// Emergency Broadcast Service for TALOWA Social Feed
// Implements Task 16: Create emergency content system

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/index.dart';

class EmergencyBroadcastService {
  static final EmergencyBroadcastService _instance = EmergencyBroadcastService._internal();
  factory EmergencyBroadcastService() => _instance;
  EmergencyBroadcastService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Emergency broadcast types
  static const String typeUrgentAlert = 'urgent_alert';
  static const String typeLandGrabbing = 'land_grabbing';
  static const String typeLegalDeadline = 'legal_deadline';
  static const String typeCoordinatorCall = 'coordinator_call';
  static const String typeEvacuation = 'evacuation';
  static const String typeWeatherAlert = 'weather_alert';

  // Priority levels
  static const String priorityCritical = 'critical';
  static const String priorityHigh = 'high';
  static const String priorityMedium = 'medium';

  /// Create and send emergency broadcast
  Future<String> createEmergencyBroadcast({
    required String title,
    required String message,
    required String broadcastType,
    required String priority,
    required String coordinatorId,
    GeographicTargeting? geographicTargeting,
    List<String>? specificUserIds,
    Map<String, dynamic>? actionData,
    DateTime? expiresAt,
  }) async {
    try {
      // Create emergency broadcast document
      final broadcastRef = await _firestore.collection('emergency_broadcasts').add({
        'title': title,
        'message': message,
        'type': broadcastType,
        'priority': priority,
        'coordinatorId': coordinatorId,
        'geographicTargeting': geographicTargeting?.toMap(),
        'specificUserIds': specificUserIds ?? [],
        'actionData': actionData ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'status': 'active',
        'deliveryStats': {
          'sent': 0,
          'delivered': 0,
          'failed': 0,
          'acknowledged': 0,
        },
      });

      // Send immediate notifications
      await _sendEmergencyNotifications(
        broadcastId: broadcastRef.id,
        title: title,
        message: message,
        priority: priority,
        geographicTargeting: geographicTargeting,
        specificUserIds: specificUserIds,
      );

      // Create emergency post in feed
      await _createEmergencyPost(
        broadcastId: broadcastRef.id,
        title: title,
        message: message,
        broadcastType: broadcastType,
        priority: priority,
        coordinatorId: coordinatorId,
        geographicTargeting: geographicTargeting,
      );

      // Log emergency action
      await _logEmergencyAction(
        action: 'broadcast_created',
        broadcastId: broadcastRef.id,
        coordinatorId: coordinatorId,
        details: {
          'type': broadcastType,
          'priority': priority,
          'geographic_scope': geographicTargeting?.toString(),
        },
      );

      return broadcastRef.id;
    } catch (e) {
      debugPrint('Error creating emergency broadcast: $e');
      rethrow;
    }
  }

  /// Send emergency notifications through multiple channels
  Future<void> _sendEmergencyNotifications({
    required String broadcastId,
    required String title,
    required String message,
    required String priority,
    GeographicTargeting? geographicTargeting,
    List<String>? specificUserIds,
  }) async {
    try {
      // Determine notification channels based on priority
      final channels = _getNotificationChannels(priority);
      
      // Send push notifications
      if (channels.contains('push')) {
        await _sendPushNotifications(
          broadcastId: broadcastId,
          title: title,
          message: message,
          priority: priority,
          geographicTargeting: geographicTargeting,
          specificUserIds: specificUserIds,
        );
      }

      // Send SMS notifications for critical alerts
      if (channels.contains('sms') && priority == priorityCritical) {
        await _sendSMSNotifications(
          broadcastId: broadcastId,
          message: message,
          geographicTargeting: geographicTargeting,
          specificUserIds: specificUserIds,
        );
      }

      // Send email notifications for high priority
      if (channels.contains('email') && 
          (priority == priorityCritical || priority == priorityHigh)) {
        await _sendEmailNotifications(
          broadcastId: broadcastId,
          title: title,
          message: message,
          geographicTargeting: geographicTargeting,
          specificUserIds: specificUserIds,
        );
      }

      // Update delivery stats
      await _updateDeliveryStats(broadcastId, 'sent');
      
    } catch (e) {
      debugPrint('Error sending emergency notifications: $e');
      await _updateDeliveryStats(broadcastId, 'failed');
    }
  }

  /// Send push notifications with priority handling
  Future<void> _sendPushNotifications({
    required String broadcastId,
    required String title,
    required String message,
    required String priority,
    GeographicTargeting? geographicTargeting,
    List<String>? specificUserIds,
  }) async {
    try {
      // Build topic list for geographic targeting
      final topics = <String>[];
      
      if (geographicTargeting != null) {
        if (geographicTargeting.stateCode != null) {
          topics.add('state_${geographicTargeting.stateCode}');
        }
        if (geographicTargeting.districtCode != null) {
          topics.add('district_${geographicTargeting.districtCode}');
        }
        if (geographicTargeting.mandalCode != null) {
          topics.add('mandal_${geographicTargeting.mandalCode}');
        }
        if (geographicTargeting.villageCode != null) {
          topics.add('village_${geographicTargeting.villageCode}');
        }
      } else {
        topics.add('all_users');
      }

      // Send to topics
      for (final topic in topics) {
        await _messaging.sendMessage(
          to: '/topics/$topic',
          data: {
            'type': 'emergency_broadcast',
            'broadcast_id': broadcastId,
            'priority': priority,
            'action': 'show_emergency_alert',
          },
          notification: RemoteNotification(
            title: 'ðŸš¨ $title',
            body: message,
            android: AndroidNotification(
              channelId: 'emergency_alerts',
              priority: AndroidNotificationPriority.max,
              importance: AndroidNotificationImportance.max,
              sound: 'emergency_alert',
              vibrationPattern: [0, 1000, 500, 1000],
              color: '#DC2626', // Red color for emergency
            ),
            apple: AppleNotification(
              sound: AppleNotificationSound.critical('emergency_alert.wav'),
              badge: 1,
            ),
          ),
        );
      }

      // Send to specific users if provided
      if (specificUserIds != null && specificUserIds.isNotEmpty) {
        for (final userId in specificUserIds) {
          // Get user's FCM token
          final userDoc = await _firestore.collection('users').doc(userId).get();
          final fcmToken = userDoc.data()?['fcmToken'] as String?;
          
          if (fcmToken != null) {
            await _messaging.sendMessage(
              to: fcmToken,
              data: {
                'type': 'emergency_broadcast',
                'broadcast_id': broadcastId,
                'priority': priority,
                'action': 'show_emergency_alert',
              },
              notification: RemoteNotification(
                title: 'ðŸš¨ $title',
                body: message,
              ),
            );
          }
        }
      }
      
    } catch (e) {
      debugPrint('Error sending push notifications: $e');
    }
  }

  /// Send SMS notifications for critical alerts
  Future<void> _sendSMSNotifications({
    required String broadcastId,
    required String message,
    GeographicTargeting? geographicTargeting,
    List<String>? specificUserIds,
  }) async {
    try {
      // Get target users
      final targetUsers = await _getTargetUsers(
        geographicTargeting: geographicTargeting,
        specificUserIds: specificUserIds,
      );

      // Send SMS to each user (mock implementation)
      for (final user in targetUsers) {
        final phoneNumber = user['phoneNumber'] as String?;
        if (phoneNumber != null) {
          // TODO: Integrate with SMS service provider
          debugPrint('Sending SMS to $phoneNumber: $message');
          
          // Log SMS delivery attempt
          await _firestore.collection('sms_logs').add({
            'broadcastId': broadcastId,
            'phoneNumber': phoneNumber,
            'message': message,
            'status': 'sent',
            'sentAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
    } catch (e) {
      debugPrint('Error sending SMS notifications: $e');
    }
  }

  /// Send email notifications
  Future<void> _sendEmailNotifications({
    required String broadcastId,
    required String title,
    required String message,
    GeographicTargeting? geographicTargeting,
    List<String>? specificUserIds,
  }) async {
    try {
      // Get target users
      final targetUsers = await _getTargetUsers(
        geographicTargeting: geographicTargeting,
        specificUserIds: specificUserIds,
      );

      // Send email to each user (mock implementation)
      for (final user in targetUsers) {
        final email = user['email'] as String?;
        if (email != null) {
          // TODO: Integrate with email service provider
          debugPrint('Sending email to $email: $title - $message');
          
          // Log email delivery attempt
          await _firestore.collection('email_logs').add({
            'broadcastId': broadcastId,
            'email': email,
            'title': title,
            'message': message,
            'status': 'sent',
            'sentAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
    } catch (e) {
      debugPrint('Error sending email notifications: $e');
    }
  }

  /// Create emergency post in social feed
  Future<void> _createEmergencyPost({
    required String broadcastId,
    required String title,
    required String message,
    required String broadcastType,
    required String priority,
    required String coordinatorId,
    GeographicTargeting? geographicTargeting,
  }) async {
    try {
      await _firestore.collection('posts').add({
        'id': 'emergency_$broadcastId',
        'authorId': coordinatorId,
        'title': title,
        'content': message,
        'category': 'emergency',
        'priority': priority,
        'broadcastType': broadcastType,
        'isEmergency': true,
        'isPinned': true,
        'geographicTargeting': geographicTargeting?.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'viewsCount': 0,
        'hashtags': ['emergency', broadcastType],
        'visibility': 'public',
        'allowComments': true,
        'allowShares': true,
        'emergencyBroadcastId': broadcastId,
      });
      
    } catch (e) {
      debugPrint('Error creating emergency post: $e');
    }
  }

  /// Get target users based on geographic targeting
  Future<List<Map<String, dynamic>>> _getTargetUsers({
    GeographicTargeting? geographicTargeting,
    List<String>? specificUserIds,
  }) async {
    try {
      Query query = _firestore.collection('users');

      // Apply geographic filters
      if (geographicTargeting != null) {
        if (geographicTargeting.stateCode != null) {
          query = query.where('address.stateCode', isEqualTo: geographicTargeting.stateCode);
        }
        if (geographicTargeting.districtCode != null) {
          query = query.where('address.districtCode', isEqualTo: geographicTargeting.districtCode);
        }
        if (geographicTargeting.mandalCode != null) {
          query = query.where('address.mandalCode', isEqualTo: geographicTargeting.mandalCode);
        }
        if (geographicTargeting.villageCode != null) {
          query = query.where('address.villageCode', isEqualTo: geographicTargeting.villageCode);
        }
      }

      // Apply specific user filter
      if (specificUserIds != null && specificUserIds.isNotEmpty) {
        query = query.where(FieldPath.documentId, whereIn: specificUserIds);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
      
    } catch (e) {
      debugPrint('Error getting target users: $e');
      return [];
    }
  }

  /// Get notification channels based on priority
  List<String> _getNotificationChannels(String priority) {
    switch (priority) {
      case priorityCritical:
        return ['push', 'sms', 'email'];
      case priorityHigh:
        return ['push', 'email'];
      case priorityMedium:
      default:
        return ['push'];
    }
  }

  /// Update delivery statistics
  Future<void> _updateDeliveryStats(String broadcastId, String status) async {
    try {
      await _firestore.collection('emergency_broadcasts').doc(broadcastId).update({
        'deliveryStats.$status': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating delivery stats: $e');
    }
  }

  /// Log emergency actions for audit trail
  Future<void> _logEmergencyAction({
    required String action,
    required String broadcastId,
    required String coordinatorId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _firestore.collection('emergency_logs').add({
        'action': action,
        'broadcastId': broadcastId,
        'coordinatorId': coordinatorId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details ?? {},
      });
    } catch (e) {
      debugPrint('Error logging emergency action: $e');
    }
  }

  /// Get active emergency broadcasts
  Stream<List<EmergencyBroadcast>> getActiveEmergencyBroadcasts({
    GeographicTargeting? userLocation,
  }) {
    Query query = _firestore
        .collection('emergency_broadcasts')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true);

    // Filter by expiration
    query = query.where('expiresAt', isGreaterThan: Timestamp.now());

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => EmergencyBroadcast.fromFirestore(doc))
          .where((broadcast) => _isRelevantToUser(broadcast, userLocation))
          .toList();
    });
  }

  /// Check if broadcast is relevant to user's location
  bool _isRelevantToUser(EmergencyBroadcast broadcast, GeographicTargeting? userLocation) {
    if (broadcast.geographicTargeting == null || userLocation == null) {
      return true; // Show all broadcasts if no targeting specified
    }

    final broadcastTarget = broadcast.geographicTargeting!;
    
    // Check state match
    if (broadcastTarget.stateCode != null && 
        broadcastTarget.stateCode != userLocation.stateCode) {
      return false;
    }

    // Check district match
    if (broadcastTarget.districtCode != null && 
        broadcastTarget.districtCode != userLocation.districtCode) {
      return false;
    }

    // Check mandal match
    if (broadcastTarget.mandalCode != null && 
        broadcastTarget.mandalCode != userLocation.mandalCode) {
      return false;
    }

    // Check village match
    if (broadcastTarget.villageCode != null && 
        broadcastTarget.villageCode != userLocation.villageCode) {
      return false;
    }

    return true;
  }

  /// Acknowledge emergency broadcast
  Future<void> acknowledgeEmergencyBroadcast({
    required String broadcastId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('emergency_acknowledgments').add({
        'broadcastId': broadcastId,
        'userId': userId,
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });

      // Update acknowledgment count
      await _updateDeliveryStats(broadcastId, 'acknowledged');
      
    } catch (e) {
      debugPrint('Error acknowledging emergency broadcast: $e');
    }
  }

  /// Cancel emergency broadcast
  Future<void> cancelEmergencyBroadcast({
    required String broadcastId,
    required String coordinatorId,
    String? reason,
  }) async {
    try {
      await _firestore.collection('emergency_broadcasts').doc(broadcastId).update({
        'status': 'cancelled',
        'cancelledBy': coordinatorId,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log cancellation
      await _logEmergencyAction(
        action: 'broadcast_cancelled',
        broadcastId: broadcastId,
        coordinatorId: coordinatorId,
        details: {'reason': reason},
      );
      
    } catch (e) {
      debugPrint('Error cancelling emergency broadcast: $e');
    }
  }

  /// Get emergency broadcast templates
  List<EmergencyTemplate> getEmergencyTemplates() {
    return [
      EmergencyTemplate(
        id: 'land_grabbing_alert',
        title: 'ðŸš¨ Land Grabbing Alert',
        message: 'Urgent: Land grabbing incident reported in {location}. All members please stay alert and report any suspicious activity.',
        type: typeLandGrabbing,
        priority: priorityHigh,
        suggestedActions: ['Report to authorities', 'Document evidence', 'Contact coordinator'],
      ),
      EmergencyTemplate(
        id: 'legal_deadline_reminder',
        title: 'âš–ï¸ Legal Deadline Alert',
        message: 'Important: Legal deadline approaching for {case_type} on {date}. Please ensure all documents are submitted.',
        type: typeLegalDeadline,
        priority: priorityMedium,
        suggestedActions: ['Check documents', 'Contact lawyer', 'Submit papers'],
      ),
      EmergencyTemplate(
        id: 'coordinator_urgent_call',
        title: 'ðŸ“ž Urgent Coordinator Call',
        message: 'Emergency meeting called by {coordinator_name}. All coordinators please join immediately.',
        type: typeCoordinatorCall,
        priority: priorityHigh,
        suggestedActions: ['Join meeting', 'Prepare reports', 'Alert team'],
      ),
      EmergencyTemplate(
        id: 'weather_alert',
        title: 'ðŸŒ§ï¸ Weather Alert',
        message: 'Severe weather warning for {location}. Please take necessary precautions to protect crops and property.',
        type: typeWeatherAlert,
        priority: priorityMedium,
        suggestedActions: ['Secure crops', 'Move to safety', 'Monitor updates'],
      ),
    ];
  }
}

// Data models for emergency broadcasts
class EmergencyBroadcast {
  final String id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final String coordinatorId;
  final GeographicTargeting? geographicTargeting;
  final List<String> specificUserIds;
  final Map<String, dynamic> actionData;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String status;
  final Map<String, int> deliveryStats;

  EmergencyBroadcast({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.coordinatorId,
    this.geographicTargeting,
    required this.specificUserIds,
    required this.actionData,
    required this.createdAt,
    this.expiresAt,
    required this.status,
    required this.deliveryStats,
  });

  factory EmergencyBroadcast.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyBroadcast(
      id: doc.id,
      title: data['title'],
      message: data['message'],
      type: data['type'],
      priority: data['priority'],
      coordinatorId: data['coordinatorId'],
      geographicTargeting: data['geographicTargeting'] != null
          ? GeographicTargeting.fromMap(data['geographicTargeting'])
          : null,
      specificUserIds: List<String>.from(data['specificUserIds'] ?? []),
      actionData: Map<String, dynamic>.from(data['actionData'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null 
          ? (data['expiresAt'] as Timestamp).toDate() 
          : null,
      status: data['status'],
      deliveryStats: Map<String, int>.from(data['deliveryStats'] ?? {}),
    );
  }
}

class EmergencyTemplate {
  final String id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final List<String> suggestedActions;

  EmergencyTemplate({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.suggestedActions,
  });
}
