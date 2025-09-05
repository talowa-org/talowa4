// Emergency Broadcast Service - Priority message delivery system
// Task 9: Build emergency broadcast system
// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifications/notification_service.dart';
import '../../models/notification_model.dart';

class EmergencyBroadcastService {
  static final EmergencyBroadcastService _instance = EmergencyBroadcastService._internal();
  factory EmergencyBroadcastService() => _instance;
  EmergencyBroadcastService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collections
  static const String _broadcastsCollection = 'emergency_broadcasts';
  static const String _deliveryTrackingCollection = 'broadcast_delivery_tracking';
  static const String _templatesCollection = 'emergency_templates';

  /// Send emergency broadcast with priority delivery
  /// Requirement 5.1: Priority message delivery bypassing normal queues
  Future<String?> sendEmergencyBroadcast({
    required String title,
    required String message,
    required EmergencyBroadcastScope scope,
    required EmergencyPriority priority,
    List<String>? mediaUrls,
    String? templateId,
    Map<String, dynamic>? customData,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Verify user has coordinator permissions
      if (!await _verifyCoordinatorPermissions(user.uid, scope)) {
        throw Exception('Insufficient permissions to send emergency broadcast');
      }

      // Create broadcast document
      final broadcastId = _firestore.collection(_broadcastsCollection).doc().id;
      final broadcast = EmergencyBroadcast(
        id: broadcastId,
        senderId: user.uid,
        title: title,
        message: message,
        scope: scope,
        priority: priority,
        mediaUrls: mediaUrls ?? [],
        templateId: templateId,
        customData: customData ?? {},
        status: BroadcastStatus.pending,
        createdAt: DateTime.now(),
        scheduledAt: DateTime.now(), // Immediate delivery
      );

      // Save broadcast to database
      await _firestore
          .collection(_broadcastsCollection)
          .doc(broadcastId)
          .set(broadcast.toMap());

      // Start priority delivery process
      await _processPriorityDelivery(broadcast);

      debugPrint('Emergency broadcast created: $broadcastId');
      return broadcastId;
    } catch (e) {
      debugPrint('Error sending emergency broadcast: $e');
      return null;
    }
  }

  /// Process priority delivery bypassing normal message queues
  /// Requirement 5.1: Priority delivery system
  Future<void> _processPriorityDelivery(EmergencyBroadcast broadcast) async {
    try {
      // Update status to processing
      await _updateBroadcastStatus(broadcast.id, BroadcastStatus.processing);

      // Get target users based on geographic scope
      final targetUsers = await _getTargetUsers(broadcast.scope);
      
      debugPrint('Emergency broadcast targeting ${targetUsers.length} users');

      // Create delivery tracking document
      final deliveryTracking = BroadcastDeliveryTracking(
        broadcastId: broadcast.id,
        totalTargets: targetUsers.length,
        deliveredCount: 0,
        failedCount: 0,
        pendingCount: targetUsers.length,
        deliveryStarted: DateTime.now(),
        channels: _getDeliveryChannels(broadcast.priority),
      );

      await _firestore
          .collection(_deliveryTrackingCollection)
          .doc(broadcast.id)
          .set(deliveryTracking.toMap());

      // Process delivery in batches for performance
      const batchSize = 100;
      final batches = <List<String>>[];
      
      for (int i = 0; i < targetUsers.length; i += batchSize) {
        final end = (i + batchSize < targetUsers.length) ? i + batchSize : targetUsers.length;
        batches.add(targetUsers.sublist(i, end));
      }

      // Process batches concurrently with controlled concurrency
      final futures = <Future>[];
      for (final batch in batches) {
        futures.add(_deliverToBatch(broadcast, batch));
        
        // Limit concurrent batches to prevent overwhelming the system
        if (futures.length >= 5) {
          await Future.wait(futures);
          futures.clear();
        }
      }

      // Wait for remaining batches
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      // Update final status
      await _updateBroadcastStatus(broadcast.id, BroadcastStatus.completed);
      
    } catch (e) {
      debugPrint('Error processing priority delivery: $e');
      await _updateBroadcastStatus(broadcast.id, BroadcastStatus.failed);
    }
  }

  /// Deliver emergency broadcast to a batch of users
  Future<void> _deliverToBatch(EmergencyBroadcast broadcast, List<String> userIds) async {
    final deliveryFutures = <Future>[];

    for (final userId in userIds) {
      deliveryFutures.add(_deliverToUser(broadcast, userId));
    }

    await Future.wait(deliveryFutures);
  }

  /// Deliver emergency broadcast to individual user with multi-channel approach
  /// Requirement 5.2: Multi-channel notification system (push, SMS, email)
  Future<void> _deliverToUser(EmergencyBroadcast broadcast, String userId) async {
    try {
      final channels = _getDeliveryChannels(broadcast.priority);
      final deliveryResults = <String, bool>{};

      // Primary delivery: Push notification (highest priority)
      if (channels.contains(DeliveryChannel.push)) {
        try {
          await NotificationService.sendNotificationToUser(
            userId: userId,
            title: 'ðŸš¨ ${broadcast.title}',
            body: broadcast.message,
            type: NotificationType.emergency,
            data: {
              'broadcastId': broadcast.id,
              'priority': broadcast.priority.toString(),
              'scope': broadcast.scope.toString(),
              'isEmergency': 'true',
              ...broadcast.customData,
            },
          );
          deliveryResults['push'] = true;
        } catch (e) {
          deliveryResults['push'] = false;
          debugPrint('Push notification failed for user $userId: $e');
        }
      }

      // Secondary delivery: SMS (for critical messages)
      if (channels.contains(DeliveryChannel.sms) && 
          (broadcast.priority == EmergencyPriority.critical || deliveryResults['push'] == false)) {
        try {
          await _sendSMSNotification(userId, broadcast);
          deliveryResults['sms'] = true;
        } catch (e) {
          deliveryResults['sms'] = false;
          debugPrint('SMS notification failed for user $userId: $e');
        }
      }

      // Tertiary delivery: Email (for high priority or fallback)
      if (channels.contains(DeliveryChannel.email) && 
          (broadcast.priority == EmergencyPriority.high || 
           (deliveryResults['push'] == false && deliveryResults['sms'] == false))) {
        try {
          await _sendEmailNotification(userId, broadcast);
          deliveryResults['email'] = true;
        } catch (e) {
          deliveryResults['email'] = false;
          debugPrint('Email notification failed for user $userId: $e');
        }
      }

      // Update delivery tracking
      final success = deliveryResults.values.any((result) => result == true);
      await _updateDeliveryTracking(broadcast.id, userId, success, deliveryResults);

    } catch (e) {
      debugPrint('Error delivering to user $userId: $e');
      await _updateDeliveryTracking(broadcast.id, userId, false, {});
    }
  }

  /// Get target users based on geographic scope
  /// Requirement 5.3: Geographic targeting for emergency broadcasts
  Future<List<String>> _getTargetUsers(EmergencyBroadcastScope scope) async {
    try {
      Query query = _firestore.collection('users');

      // Apply geographic filters
      switch (scope.level) {
        case GeographicLevel.village:
          query = query
              .where('location.village', isEqualTo: scope.village)
              .where('location.mandal', isEqualTo: scope.mandal)
              .where('location.district', isEqualTo: scope.district);
          break;
        case GeographicLevel.mandal:
          query = query
              .where('location.mandal', isEqualTo: scope.mandal)
              .where('location.district', isEqualTo: scope.district);
          break;
        case GeographicLevel.district:
          query = query.where('location.district', isEqualTo: scope.district);
          break;
        case GeographicLevel.state:
          query = query.where('location.state', isEqualTo: scope.state);
          break;
        case GeographicLevel.national:
          // No geographic filter for national broadcasts
          break;
      }

      // Apply role filters if specified
      if (scope.targetRoles.isNotEmpty) {
        query = query.where('role', whereIn: scope.targetRoles);
      }

      // Execute query
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.id).toList();

    } catch (e) {
      debugPrint('Error getting target users: $e');
      return [];
    }
  }

  /// Get delivery channels based on priority
  List<DeliveryChannel> _getDeliveryChannels(EmergencyPriority priority) {
    switch (priority) {
      case EmergencyPriority.critical:
        return [DeliveryChannel.push, DeliveryChannel.sms, DeliveryChannel.email];
      case EmergencyPriority.high:
        return [DeliveryChannel.push, DeliveryChannel.email];
      case EmergencyPriority.medium:
        return [DeliveryChannel.push];
      case EmergencyPriority.low:
        return [DeliveryChannel.push];
    }
  }

  /// Send SMS notification (placeholder - integrate with SMS service)
  /// Requirement 5.2: SMS fallback for critical messages
  Future<void> _sendSMSNotification(String userId, EmergencyBroadcast broadcast) async {
    try {
      // Get user phone number
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final phoneNumber = userData['phoneNumber'] as String?;
      
      if (phoneNumber == null) return;

      // Format SMS message
      final smsMessage = 'ðŸš¨ TALOWA EMERGENCY\n${broadcast.title}\n\n${broadcast.message}';

      // TODO: Integrate with actual SMS service (Twilio, AWS SNS, etc.)
      debugPrint('SMS would be sent to $phoneNumber: $smsMessage');

      // Log SMS delivery attempt
      await _firestore.collection('sms_logs').add({
        'userId': userId,
        'phoneNumber': phoneNumber,
        'message': smsMessage,
        'broadcastId': broadcast.id,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent', // Would be actual status from SMS service
      });

    } catch (e) {
      debugPrint('Error sending SMS notification: $e');
      rethrow;
    }
  }

  /// Send email notification (placeholder - integrate with email service)
  /// Requirement 5.2: Email fallback for critical messages
  Future<void> _sendEmailNotification(String userId, EmergencyBroadcast broadcast) async {
    try {
      // Get user email
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final email = userData['email'] as String?;
      
      if (email == null) return;

      // Format email content
      final emailSubject = 'ðŸš¨ TALOWA Emergency Alert: ${broadcast.title}';
      final emailBody = '''
Dear TALOWA Member,

This is an emergency alert from TALOWA:

${broadcast.title}

${broadcast.message}

Please take appropriate action immediately.

Stay safe,
TALOWA Team
''';

      // TODO: Integrate with actual email service (SendGrid, AWS SES, etc.)
      debugPrint('Email would be sent to $email: $emailSubject');

      // Log email delivery attempt
      await _firestore.collection('email_logs').add({
        'userId': userId,
        'email': email,
        'subject': emailSubject,
        'body': emailBody,
        'broadcastId': broadcast.id,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent', // Would be actual status from email service
      });

    } catch (e) {
      debugPrint('Error sending email notification: $e');
      rethrow;
    }
  }

  /// Update delivery tracking with retry mechanism
  /// Requirement 5.4: Delivery tracking and retry mechanism
  Future<void> _updateDeliveryTracking(
    String broadcastId,
    String userId,
    bool success,
    Map<String, bool> channelResults,
  ) async {
    try {
      final trackingRef = _firestore.collection(_deliveryTrackingCollection).doc(broadcastId);
      
      await _firestore.runTransaction((transaction) async {
        final trackingDoc = await transaction.get(trackingRef);
        if (!trackingDoc.exists) return;

        final data = trackingDoc.data()!;
        final currentDelivered = data['deliveredCount'] as int;
        final currentFailed = data['failedCount'] as int;
        final currentPending = data['pendingCount'] as int;

        // Update counters
        final updates = <String, dynamic>{
          'pendingCount': currentPending - 1,
        };

        if (success) {
          updates['deliveredCount'] = currentDelivered + 1;
        } else {
          updates['failedCount'] = currentFailed + 1;
          
          // Schedule retry for failed deliveries
          await _scheduleRetry(broadcastId, userId, channelResults);
        }

        // Update last activity
        updates['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.update(trackingRef, updates);

        // Log individual delivery result
        await _logDeliveryResult(broadcastId, userId, success, channelResults);
      });

    } catch (e) {
      debugPrint('Error updating delivery tracking: $e');
    }
  }

  /// Schedule retry for failed deliveries
  /// Requirement 5.4: Retry mechanism for failed deliveries
  Future<void> _scheduleRetry(
    String broadcastId,
    String userId,
    Map<String, bool> previousAttempts,
  ) async {
    try {
      // Get current retry count
      final retryDoc = await _firestore
          .collection('broadcast_retries')
          .doc('${broadcastId}_$userId')
          .get();

      int retryCount = 0;
      if (retryDoc.exists) {
        retryCount = retryDoc.data()!['retryCount'] as int;
      }

      // Maximum 3 retries with exponential backoff
      if (retryCount < 3) {
        final nextRetryTime = DateTime.now().add(
          Duration(minutes: (retryCount + 1) * 5), // 5, 10, 15 minutes
        );

        await _firestore
            .collection('broadcast_retries')
            .doc('${broadcastId}_$userId')
            .set({
          'broadcastId': broadcastId,
          'userId': userId,
          'retryCount': retryCount + 1,
          'nextRetryTime': Timestamp.fromDate(nextRetryTime),
          'previousAttempts': previousAttempts,
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('Scheduled retry ${retryCount + 1} for user $userId at $nextRetryTime');
      }
    } catch (e) {
      debugPrint('Error scheduling retry: $e');
    }
  }

  /// Log individual delivery result
  Future<void> _logDeliveryResult(
    String broadcastId,
    String userId,
    bool success,
    Map<String, bool> channelResults,
  ) async {
    try {
      await _firestore.collection('broadcast_delivery_logs').add({
        'broadcastId': broadcastId,
        'userId': userId,
        'success': success,
        'channelResults': channelResults,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging delivery result: $e');
    }
  }

  /// Process scheduled retries
  Future<void> processScheduledRetries() async {
    try {
      final now = DateTime.now();
      final retryQuery = await _firestore
          .collection('broadcast_retries')
          .where('nextRetryTime', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      for (final doc in retryQuery.docs) {
        final data = doc.data();
        final broadcastId = data['broadcastId'] as String;
        final userId = data['userId'] as String;

        // Get original broadcast
        final broadcastDoc = await _firestore
            .collection(_broadcastsCollection)
            .doc(broadcastId)
            .get();

        if (broadcastDoc.exists) {
          final broadcast = EmergencyBroadcast.fromFirestore(broadcastDoc);
          await _deliverToUser(broadcast, userId);
        }

        // Delete retry document
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error processing scheduled retries: $e');
    }
  }

  /// Create emergency broadcast template
  /// Requirement 5.5: Quick templates for coordinators
  Future<String?> createEmergencyTemplate({
    required String name,
    required String title,
    required String message,
    required EmergencyPriority priority,
    required List<String> applicableRoles,
    Map<String, dynamic>? customFields,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final templateId = _firestore.collection(_templatesCollection).doc().id;
      final template = EmergencyTemplate(
        id: templateId,
        name: name,
        title: title,
        message: message,
        priority: priority,
        applicableRoles: applicableRoles,
        customFields: customFields ?? {},
        createdBy: user.uid,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_templatesCollection)
          .doc(templateId)
          .set(template.toMap());

      debugPrint('Emergency template created: $templateId');
      return templateId;
    } catch (e) {
      debugPrint('Error creating emergency template: $e');
      return null;
    }
  }

  /// Get emergency templates for user role
  Future<List<EmergencyTemplate>> getEmergencyTemplates() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get user role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userRole = userDoc.data()!['role'] as String?;
      if (userRole == null) return [];

      // Get templates applicable to user role
      final query = await _firestore
          .collection(_templatesCollection)
          .where('applicableRoles', arrayContains: userRole)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return query.docs
          .map((doc) => EmergencyTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting emergency templates: $e');
      return [];
    }
  }

  /// Get broadcast delivery status
  Future<BroadcastDeliveryTracking?> getBroadcastDeliveryStatus(String broadcastId) async {
    try {
      final doc = await _firestore
          .collection(_deliveryTrackingCollection)
          .doc(broadcastId)
          .get();

      if (doc.exists) {
        return BroadcastDeliveryTracking.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting broadcast delivery status: $e');
      return null;
    }
  }

  /// Get user's sent broadcasts
  Stream<List<EmergencyBroadcast>> getUserBroadcasts() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_broadcastsCollection)
        .where('senderId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmergencyBroadcast.fromFirestore(doc))
            .toList());
  }

  /// Verify coordinator permissions for broadcast scope
  Future<bool> _verifyCoordinatorPermissions(String userId, EmergencyBroadcastScope scope) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final userRole = userData['role'] as String?;
      final userLocation = userData['location'] as Map<String, dynamic>?;

      if (userRole == null || userLocation == null) return false;

      // Check role permissions
      switch (scope.level) {
        case GeographicLevel.village:
          return userRole == 'village_coordinator' &&
                 userLocation['village'] == scope.village &&
                 userLocation['mandal'] == scope.mandal &&
                 userLocation['district'] == scope.district;
        case GeographicLevel.mandal:
          return (userRole == 'mandal_coordinator' || userRole == 'district_coordinator') &&
                 userLocation['mandal'] == scope.mandal &&
                 userLocation['district'] == scope.district;
        case GeographicLevel.district:
          return (userRole == 'district_coordinator' || userRole == 'state_coordinator') &&
                 userLocation['district'] == scope.district;
        case GeographicLevel.state:
          return userRole == 'state_coordinator' || userRole == 'national_coordinator';
        case GeographicLevel.national:
          return userRole == 'national_coordinator';
      }
    } catch (e) {
      debugPrint('Error verifying coordinator permissions: $e');
      return false;
    }
  }

  /// Update broadcast status
  Future<void> _updateBroadcastStatus(String broadcastId, BroadcastStatus status) async {
    try {
      await _firestore
          .collection(_broadcastsCollection)
          .doc(broadcastId)
          .update({
        'status': status.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating broadcast status: $e');
    }
  }
}

// Data Models

enum EmergencyPriority { low, medium, high, critical }

enum GeographicLevel { village, mandal, district, state, national }

enum BroadcastStatus { pending, processing, completed, failed, cancelled }

enum DeliveryChannel { push, sms, email }

class EmergencyBroadcastScope {
  final GeographicLevel level;
  final String? state;
  final String? district;
  final String? mandal;
  final String? village;
  final List<String> targetRoles;

  EmergencyBroadcastScope({
    required this.level,
    this.state,
    this.district,
    this.mandal,
    this.village,
    this.targetRoles = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'level': level.toString(),
      'state': state,
      'district': district,
      'mandal': mandal,
      'village': village,
      'targetRoles': targetRoles,
    };
  }

  factory EmergencyBroadcastScope.fromMap(Map<String, dynamic> data) {
    return EmergencyBroadcastScope(
      level: GeographicLevel.values.firstWhere(
        (e) => e.toString() == data['level'],
        orElse: () => GeographicLevel.district,
      ),
      state: data['state'],
      district: data['district'],
      mandal: data['mandal'],
      village: data['village'],
      targetRoles: List<String>.from(data['targetRoles'] ?? []),
    );
  }
}

class EmergencyBroadcast {
  final String id;
  final String senderId;
  final String title;
  final String message;
  final EmergencyBroadcastScope scope;
  final EmergencyPriority priority;
  final List<String> mediaUrls;
  final String? templateId;
  final Map<String, dynamic> customData;
  final BroadcastStatus status;
  final DateTime createdAt;
  final DateTime scheduledAt;
  final DateTime? completedAt;

  EmergencyBroadcast({
    required this.id,
    required this.senderId,
    required this.title,
    required this.message,
    required this.scope,
    required this.priority,
    required this.mediaUrls,
    this.templateId,
    required this.customData,
    required this.status,
    required this.createdAt,
    required this.scheduledAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'title': title,
      'message': message,
      'scope': scope.toMap(),
      'priority': priority.toString(),
      'mediaUrls': mediaUrls,
      'templateId': templateId,
      'customData': customData,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory EmergencyBroadcast.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyBroadcast(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      scope: EmergencyBroadcastScope.fromMap(data['scope'] ?? {}),
      priority: EmergencyPriority.values.firstWhere(
        (e) => e.toString() == data['priority'],
        orElse: () => EmergencyPriority.medium,
      ),
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      templateId: data['templateId'],
      customData: Map<String, dynamic>.from(data['customData'] ?? {}),
      status: BroadcastStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => BroadcastStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      scheduledAt: (data['scheduledAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
    );
  }
}

class BroadcastDeliveryTracking {
  final String broadcastId;
  final int totalTargets;
  final int deliveredCount;
  final int failedCount;
  final int pendingCount;
  final DateTime deliveryStarted;
  final DateTime? deliveryCompleted;
  final List<DeliveryChannel> channels;

  BroadcastDeliveryTracking({
    required this.broadcastId,
    required this.totalTargets,
    required this.deliveredCount,
    required this.failedCount,
    required this.pendingCount,
    required this.deliveryStarted,
    this.deliveryCompleted,
    required this.channels,
  });

  Map<String, dynamic> toMap() {
    return {
      'broadcastId': broadcastId,
      'totalTargets': totalTargets,
      'deliveredCount': deliveredCount,
      'failedCount': failedCount,
      'pendingCount': pendingCount,
      'deliveryStarted': Timestamp.fromDate(deliveryStarted),
      'deliveryCompleted': deliveryCompleted != null 
          ? Timestamp.fromDate(deliveryCompleted!) 
          : null,
      'channels': channels.map((c) => c.toString()).toList(),
    };
  }

  factory BroadcastDeliveryTracking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BroadcastDeliveryTracking(
      broadcastId: data['broadcastId'] ?? '',
      totalTargets: data['totalTargets'] ?? 0,
      deliveredCount: data['deliveredCount'] ?? 0,
      failedCount: data['failedCount'] ?? 0,
      pendingCount: data['pendingCount'] ?? 0,
      deliveryStarted: (data['deliveryStarted'] as Timestamp).toDate(),
      deliveryCompleted: data['deliveryCompleted'] != null 
          ? (data['deliveryCompleted'] as Timestamp).toDate() 
          : null,
      channels: (data['channels'] as List<dynamic>?)
          ?.map((c) => DeliveryChannel.values.firstWhere(
              (e) => e.toString() == c,
              orElse: () => DeliveryChannel.push))
          .toList() ?? [],
    );
  }

  double get deliveryRate {
    if (totalTargets == 0) return 0.0;
    return deliveredCount / totalTargets;
  }

  bool get isCompleted => pendingCount == 0;
}

class EmergencyTemplate {
  final String id;
  final String name;
  final String title;
  final String message;
  final EmergencyPriority priority;
  final List<String> applicableRoles;
  final Map<String, dynamic> customFields;
  final String createdBy;
  final DateTime createdAt;
  final bool isActive;

  EmergencyTemplate({
    required this.id,
    required this.name,
    required this.title,
    required this.message,
    required this.priority,
    required this.applicableRoles,
    required this.customFields,
    required this.createdBy,
    required this.createdAt,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'title': title,
      'message': message,
      'priority': priority.toString(),
      'applicableRoles': applicableRoles,
      'customFields': customFields,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  factory EmergencyTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      priority: EmergencyPriority.values.firstWhere(
        (e) => e.toString() == data['priority'],
        orElse: () => EmergencyPriority.medium,
      ),
      applicableRoles: List<String>.from(data['applicableRoles'] ?? []),
      customFields: Map<String, dynamic>.from(data['customFields'] ?? {}),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
}
