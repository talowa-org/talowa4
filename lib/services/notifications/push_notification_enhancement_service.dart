// Push Notification Enhancement Service - Advanced notification features
// Enhanced real-time features for TALOWA app

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// Enhanced push notification service with advanced features
class PushNotificationEnhancementService {
  static PushNotificationEnhancementService? _instance;
  static PushNotificationEnhancementService get instance => 
      _instance ??= PushNotificationEnhancementService._();
  
  PushNotificationEnhancementService._();
  
  // Firebase instances
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream controllers
  static final StreamController<NotificationAnalytics> _analyticsController = 
      StreamController<NotificationAnalytics>.broadcast();
  static final StreamController<NotificationDeliveryStatus> _deliveryController = 
      StreamController<NotificationDeliveryStatus>.broadcast();
  
  // State
  static bool _isInitialized = false;
  static String? _currentUserId;
  static NotificationPreferences? _userPreferences;
  static Timer? _analyticsTimer;
  
  /// Initialize enhanced push notification service
  static Future<void> initialize({required String userId}) async {
    if (_isInitialized) return;
    
    try {
      debugPrint('ðŸ”„ PushNotificationEnhancementService: Initializing...');
      
      _currentUserId = userId;
      
      // Load user preferences
      await _loadUserPreferences();
      
      // Set up notification handlers
      await _setupNotificationHandlers();
      
      // Set up analytics tracking
      await _setupAnalyticsTracking();
      
      // Set up delivery tracking
      await _setupDeliveryTracking();
      
      // Start periodic analytics collection
      _startAnalyticsCollection();
      
      _isInitialized = true;
      
      debugPrint('âœ… PushNotificationEnhancementService: Initialized successfully');
      
    } catch (e) {
      debugPrint('âŒ PushNotificationEnhancementService: Initialization error: $e');
      rethrow;
    }
  }
  
  /// Dispose of all resources
  static Future<void> dispose() async {
    debugPrint('ðŸ”„ PushNotificationEnhancementService: Disposing...');
    
    _analyticsTimer?.cancel();
    _analyticsTimer = null;
    
    await _analyticsController.close();
    await _deliveryController.close();
    
    _isInitialized = false;
    _currentUserId = null;
    _userPreferences = null;
    
    debugPrint('âœ… PushNotificationEnhancementService: Disposed successfully');
  }
  
  /// Get notification analytics stream
  static Stream<NotificationAnalytics> get analyticsStream => 
      _analyticsController.stream;
  
  /// Get delivery status stream
  static Stream<NotificationDeliveryStatus> get deliveryStream => 
      _deliveryController.stream;
  
  /// Send targeted push notification
  static Future<bool> sendTargetedNotification({
    required String title,
    required String body,
    required List<String> targetUserIds,
    Map<String, dynamic>? data,
    NotificationPriority priority = NotificationPriority.normal,
    DateTime? scheduledTime,
    List<String>? tags,
    String? imageUrl,
    String? actionUrl,
  }) async {
    try {
      debugPrint('ðŸ“¤ Sending targeted notification to ${targetUserIds.length} users');
      
      // Create notification document
      final notificationId = _firestore.collection('notifications').doc().id;
      
      final notificationData = {
        'id': notificationId,
        'title': title,
        'body': body,
        'targetUserIds': targetUserIds,
        'data': data ?? {},
        'priority': priority.name,
        'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime) : null,
        'tags': tags ?? [],
        'imageUrl': imageUrl,
        'actionUrl': actionUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'senderId': _currentUserId,
        'analytics': {
          'sent': 0,
          'delivered': 0,
          'opened': 0,
          'clicked': 0,
        },
      };
      
      // Save notification to Firestore
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notificationData);
      
      // If scheduled, set up timer
      if (scheduledTime != null && scheduledTime.isAfter(DateTime.now())) {
        await _scheduleNotification(notificationId, scheduledTime);
        return true;
      }
      
      // Send immediately
      return await _sendNotificationNow(notificationId, notificationData);
      
    } catch (e) {
      debugPrint('âŒ PushNotificationEnhancementService: Error sending notification: $e');
      return false;
    }
  }
  
  /// Send notification to user segments
  static Future<bool> sendSegmentedNotification({
    required String title,
    required String body,
    required List<UserSegment> segments,
    Map<String, dynamic>? data,
    NotificationPriority priority = NotificationPriority.normal,
    List<String>? tags,
    String? imageUrl,
    String? actionUrl,
  }) async {
    try {
      // Get target users based on segments
      final targetUserIds = await _getUsersFromSegments(segments);
      
      if (targetUserIds.isEmpty) {
        debugPrint('âš ï¸ No users found for specified segments');
        return false;
      }
      
      return await sendTargetedNotification(
        title: title,
        body: body,
        targetUserIds: targetUserIds,
        data: data,
        priority: priority,
        tags: tags,
        imageUrl: imageUrl,
        actionUrl: actionUrl,
      );
      
    } catch (e) {
      debugPrint('âŒ PushNotificationEnhancementService: Error sending segmented notification: $e');
      return false;
    }
  }
  
  /// Update user notification preferences
  static Future<void> updateNotificationPreferences(NotificationPreferences preferences) async {
    if (_currentUserId == null) return;
    
    try {
      _userPreferences = preferences;
      
      // Save to Firestore
      await _firestore
          .collection('user_notification_preferences')
          .doc(_currentUserId)
          .set(preferences.toMap(), SetOptions(merge: true));
      
      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notification_preferences', jsonEncode(preferences.toMap()));
      
      debugPrint('âœ… Notification preferences updated');
      
    } catch (e) {
      debugPrint('âŒ PushNotificationEnhancementService: Error updating preferences: $e');
    }
  }
  
  /// Get notification analytics
  static Future<NotificationAnalytics> getNotificationAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();
      
      Query query = _firestore
          .collection('notifications')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
      
      if (tags != null && tags.isNotEmpty) {
        query = query.where('tags', arrayContainsAny: tags);
      }
      
      final snapshot = await query.get();
      
      int totalSent = 0;
      int totalDelivered = 0;
      int totalOpened = 0;
      int totalClicked = 0;
      
      for (final doc in snapshot.docs) {
        final analytics = doc.data()['analytics'] as Map<String, dynamic>? ?? {};
        totalSent += (analytics['sent'] as int?) ?? 0;
        totalDelivered += (analytics['delivered'] as int?) ?? 0;
        totalOpened += (analytics['opened'] as int?) ?? 0;
        totalClicked += (analytics['clicked'] as int?) ?? 0;
      }
      
      return NotificationAnalytics(
        totalNotifications: snapshot.docs.length,
        totalSent: totalSent,
        totalDelivered: totalDelivered,
        totalOpened: totalOpened,
        totalClicked: totalClicked,
        deliveryRate: totalSent > 0 ? (totalDelivered / totalSent) : 0.0,
        openRate: totalDelivered > 0 ? (totalOpened / totalDelivered) : 0.0,
        clickRate: totalOpened > 0 ? (totalClicked / totalOpened) : 0.0,
        period: DateRange(start: start, end: end),
      );
      
    } catch (e) {
      debugPrint('âŒ PushNotificationEnhancementService: Error getting analytics: $e');
      return NotificationAnalytics.empty();
    }
  }
  
  /// Track notification interaction
  static Future<void> trackNotificationInteraction({
    required String notificationId,
    required NotificationInteractionType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Update notification analytics
      final notificationRef = _firestore.collection('notifications').doc(notificationId);
      
      String field;
      switch (type) {
        case NotificationInteractionType.delivered:
          field = 'analytics.delivered';
          break;
        case NotificationInteractionType.opened:
          field = 'analytics.opened';
          break;
        case NotificationInteractionType.clicked:
          field = 'analytics.clicked';
          break;
      }
      
      await notificationRef.update({
        field: FieldValue.increment(1),
        'lastInteraction': FieldValue.serverTimestamp(),
      });
      
      // Track individual user interaction
      if (_currentUserId != null) {
        await _firestore
            .collection('notification_interactions')
            .add({
          'notificationId': notificationId,
          'userId': _currentUserId,
          'type': type.name,
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': metadata ?? {},
        });
      }
      
      debugPrint('ðŸ“Š Tracked notification interaction: ${type.name}');
      
    } catch (e) {
      debugPrint('âŒ PushNotificationEnhancementService: Error tracking interaction: $e');
    }
  }
  
  /// Load user notification preferences
  static Future<void> _loadUserPreferences() async {
    if (_currentUserId == null) return;
    
    try {
      // Try to load from Firestore first
      final doc = await _firestore
          .collection('user_notification_preferences')
          .doc(_currentUserId)
          .get();
      
      if (doc.exists) {
        _userPreferences = NotificationPreferences.fromMap(doc.data()!);
      } else {
        // Load from local storage as fallback
        final prefs = await SharedPreferences.getInstance();
        final prefsJson = prefs.getString('notification_preferences');
        
        if (prefsJson != null) {
          final prefsMap = jsonDecode(prefsJson) as Map<String, dynamic>;
          _userPreferences = NotificationPreferences.fromMap(prefsMap);
        } else {
          // Use default preferences
          _userPreferences = NotificationPreferences.defaultPreferences();
        }
      }
      
    } catch (e) {
      debugPrint('âŒ PushNotificationEnhancementService: Error loading preferences: $e');
      _userPreferences = NotificationPreferences.defaultPreferences();
    }
  }
  
  /// Set up notification handlers
  static Future<void> _setupNotificationHandlers() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });
    
    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
    
    // Handle notification when app is terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }
  
  /// Handle foreground message
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('ðŸ“± Received foreground message: ${message.messageId}');
    
    // Track delivery
    if (message.data['notificationId'] != null) {
      trackNotificationInteraction(
        notificationId: message.data['notificationId'],
        type: NotificationInteractionType.delivered,
      );
    }
    
    // Show local notification if user preferences allow
    if (_userPreferences?.showInApp ?? true) {
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? 'New Notification',
        body: message.notification?.body ?? '',
        type: NotificationType.general,
        data: message.data,
        createdAt: DateTime.now(),
      );
      NotificationService.showLocalNotification(notification);
    }
  }
  
  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('ðŸ‘† Notification tapped: ${message.messageId}');
    
    // Track interaction
    if (message.data['notificationId'] != null) {
      trackNotificationInteraction(
        notificationId: message.data['notificationId'],
        type: NotificationInteractionType.opened,
      );
    }
    
    // Handle navigation or action
    if (message.data['actionUrl'] != null) {
      // Navigate to specific screen
      // This would be handled by your navigation service
    }
  }
  
  /// Set up analytics tracking
  static Future<void> _setupAnalyticsTracking() async {
    // Listen to notification analytics updates
    _firestore
        .collection('notifications')
        .where('senderId', isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot) {
      // Process analytics updates
      _processAnalyticsUpdates(snapshot.docs);
    });
  }
  
  /// Set up delivery tracking
  static Future<void> _setupDeliveryTracking() async {
    // Listen to delivery status updates
    _firestore
        .collection('notification_delivery_status')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added || 
            doc.type == DocumentChangeType.modified) {
          final status = NotificationDeliveryStatus.fromFirestore(doc.doc);
          _deliveryController.add(status);
        }
      }
    });
  }
  
  /// Start analytics collection
  static void _startAnalyticsCollection() {
    _analyticsTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _collectAnalytics(),
    );
  }
  
  /// Collect analytics data
  static Future<void> _collectAnalytics() async {
    try {
      final analytics = await getNotificationAnalytics(
        startDate: DateTime.now().subtract(const Duration(hours: 1)),
      );
      
      _analyticsController.add(analytics);
      
    } catch (e) {
      debugPrint('âŒ PushNotificationEnhancementService: Error collecting analytics: $e');
    }
  }
  
  /// Process analytics updates
  static void _processAnalyticsUpdates(List<QueryDocumentSnapshot> docs) {
    // Process and emit analytics updates
    // This could be used for real-time dashboard updates
  }
  
  /// Schedule notification for later delivery
  static Future<void> _scheduleNotification(String notificationId, DateTime scheduledTime) async {
    // In a real implementation, this would use a job scheduler or cloud function
    // For now, we'll just mark it as scheduled
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({
      'status': 'scheduled',
      'scheduledTime': Timestamp.fromDate(scheduledTime),
    });
  }
  
  /// Send notification immediately
  static Future<bool> _sendNotificationNow(String notificationId, Map<String, dynamic> notificationData) async {
    try {
      // Update status to sending
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'status': 'sending'});
      
      // In a real implementation, this would trigger cloud functions
      // to send the actual push notifications via FCM
      
      // For now, simulate successful sending
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
        'analytics.sent': (notificationData['targetUserIds'] as List).length,
      });
      
      return true;
      
    } catch (e) {
      debugPrint('âŒ PushNotificationEnhancementService: Error sending notification: $e');
      
      // Update status to failed
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'status': 'failed',
        'error': e.toString(),
      });
      
      return false;
    }
  }
  
  /// Get users from segments
  static Future<List<String>> _getUsersFromSegments(List<UserSegment> segments) async {
    final Set<String> userIds = {};
    
    for (final segment in segments) {
      Query query = _firestore.collection('users');
      
      // Apply segment filters
      for (final filter in segment.filters) {
        query = query.where(filter.field, isEqualTo: filter.value);
      }
      
      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        userIds.add(doc.id);
      }
    }
    
    return userIds.toList();
  }
}

/// Notification priority levels
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

/// Notification interaction types
enum NotificationInteractionType {
  delivered,
  opened,
  clicked,
}

/// User segment for targeted notifications
class UserSegment {
  final String name;
  final List<SegmentFilter> filters;
  
  UserSegment({
    required this.name,
    required this.filters,
  });
}

/// Segment filter
class SegmentFilter {
  final String field;
  final dynamic value;
  
  SegmentFilter({
    required this.field,
    required this.value,
  });
}

/// Notification preferences
class NotificationPreferences {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final bool showInApp;
  final Map<String, bool> categoryPreferences;
  final List<String> mutedKeywords;
  final TimeRange? quietHours;
  
  NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.smsEnabled,
    required this.showInApp,
    required this.categoryPreferences,
    required this.mutedKeywords,
    this.quietHours,
  });
  
  factory NotificationPreferences.defaultPreferences() {
    return NotificationPreferences(
      pushEnabled: true,
      emailEnabled: true,
      smsEnabled: false,
      showInApp: true,
      categoryPreferences: {
        'posts': true,
        'comments': true,
        'likes': true,
        'follows': true,
        'mentions': true,
        'campaigns': true,
        'system': true,
      },
      mutedKeywords: [],
    );
  }
  
  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      pushEnabled: map['pushEnabled'] ?? true,
      emailEnabled: map['emailEnabled'] ?? true,
      smsEnabled: map['smsEnabled'] ?? false,
      showInApp: map['showInApp'] ?? true,
      categoryPreferences: Map<String, bool>.from(map['categoryPreferences'] ?? {}),
      mutedKeywords: List<String>.from(map['mutedKeywords'] ?? []),
      quietHours: map['quietHours'] != null 
          ? TimeRange.fromMap(map['quietHours']) 
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'pushEnabled': pushEnabled,
      'emailEnabled': emailEnabled,
      'smsEnabled': smsEnabled,
      'showInApp': showInApp,
      'categoryPreferences': categoryPreferences,
      'mutedKeywords': mutedKeywords,
      'quietHours': quietHours?.toMap(),
    };
  }
}

/// Time range for quiet hours
class TimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  
  TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
  
  factory TimeRange.fromMap(Map<String, dynamic> map) {
    return TimeRange(
      startHour: map['startHour'] ?? 0,
      startMinute: map['startMinute'] ?? 0,
      endHour: map['endHour'] ?? 0,
      endMinute: map['endMinute'] ?? 0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }
}

/// Notification analytics data
class NotificationAnalytics {
  final int totalNotifications;
  final int totalSent;
  final int totalDelivered;
  final int totalOpened;
  final int totalClicked;
  final double deliveryRate;
  final double openRate;
  final double clickRate;
  final DateRange period;
  
  NotificationAnalytics({
    required this.totalNotifications,
    required this.totalSent,
    required this.totalDelivered,
    required this.totalOpened,
    required this.totalClicked,
    required this.deliveryRate,
    required this.openRate,
    required this.clickRate,
    required this.period,
  });
  
  factory NotificationAnalytics.empty() {
    return NotificationAnalytics(
      totalNotifications: 0,
      totalSent: 0,
      totalDelivered: 0,
      totalOpened: 0,
      totalClicked: 0,
      deliveryRate: 0.0,
      openRate: 0.0,
      clickRate: 0.0,
      period: DateRange(
        start: DateTime.now(),
        end: DateTime.now(),
      ),
    );
  }
}

/// Date range
class DateRange {
  final DateTime start;
  final DateTime end;
  
  DateRange({
    required this.start,
    required this.end,
  });
}

/// Notification delivery status
class NotificationDeliveryStatus {
  final String notificationId;
  final String userId;
  final String status;
  final DateTime timestamp;
  final String? error;
  
  NotificationDeliveryStatus({
    required this.notificationId,
    required this.userId,
    required this.status,
    required this.timestamp,
    this.error,
  });
  
  factory NotificationDeliveryStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationDeliveryStatus(
      notificationId: data['notificationId'] ?? '',
      userId: data['userId'] ?? '',
      status: data['status'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      error: data['error'],
    );
  }
}
