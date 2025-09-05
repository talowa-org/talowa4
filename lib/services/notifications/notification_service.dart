// Notification Service - Handle push notifications and in-app notifications
// Part of Task 12: Build push notification system

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';

// Conditional import for local notifications (not supported on web)
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'web_notification_stub.dart';
import '../../models/notification_model.dart';
import '../auth/auth_service.dart';
import 'notification_batching_service.dart';
import 'notification_templates.dart';
import 'notification_preferences_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  // Collection references
  static final CollectionReference _notificationsCollection = 
      _firestore.collection('notifications');
  static final CollectionReference _userNotificationsCollection = 
      _firestore.collection('user_notifications');
  
  // Notification channels
  static const String _defaultChannelId = 'talowa_default';
  static const String _emergencyChannelId = 'talowa_emergency';
  static const String _engagementChannelId = 'talowa_engagement';
  static const String _announcementChannelId = 'talowa_announcement';
  
  // State management
  static bool _isInitialized = false;
  static String? _fcmToken;
  static final List<NotificationModel> _inAppNotifications = [];
  
  // Stream controllers
  static final StreamController<NotificationModel> _notificationController = 
      StreamController<NotificationModel>.broadcast();
  static final StreamController<int> _unreadCountController = 
      StreamController<int>.broadcast();
  
  /// Initialize notification service with enhanced FCM features
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('ðŸ”” NotificationService: Initializing with enhanced FCM...');

      // Initialize preferences service
      await NotificationPreferencesService.initialize();

      // Initialize advanced FCM features
      await _initializeAdvancedFCM();
      
      // Initialize batching service
      await NotificationBatchingService().initialize();
      
      // Skip platform-specific features on web
      if (!kIsWeb) {
        // Request permissions
        await _requestPermissions();
        
        // Initialize local notifications
        await _initializeLocalNotifications();
        
        // Set up message handlers
        _setupMessageHandlers();
      }
      
      // Get FCM token (works on web)
      await _getFCMToken();
      
      // Subscribe to topics (works on web)
      await _subscribeToTopics();
      
      _isInitialized = true;
      debugPrint('NotificationService: Initialized successfully');
      
    } catch (e) {
      debugPrint('NotificationService: Initialization failed: $e');
      // Don't rethrow on web to prevent app crashes
      if (!kIsWeb) rethrow;
    }
  }
  
  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );
      
      debugPrint('NotificationService: Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        throw Exception('Notification permissions denied');
      }
    } catch (e) {
      debugPrint('NotificationService: Error requesting permissions: $e');
      rethrow;
    }
  }
  
  /// Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // Create notification channels
      await _createNotificationChannels();
      
      debugPrint('NotificationService: Local notifications initialized');
    } catch (e) {
      debugPrint('NotificationService: Error initializing local notifications: $e');
      rethrow;
    }
  }
  
  /// Create notification channels for Android
  static Future<void> _createNotificationChannels() async {
    try {
      const channels = [
        AndroidNotificationChannel(
          _defaultChannelId,
          'General Notifications',
          description: 'General app notifications',
          importance: Importance.defaultImportance,
        ),
        AndroidNotificationChannel(
          _emergencyChannelId,
          'Emergency Alerts',
          description: 'Critical emergency notifications',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('emergency_alert'),
        ),
        AndroidNotificationChannel(
          _engagementChannelId,
          'Engagement Notifications',
          description: 'Likes, comments, and shares',
          importance: Importance.defaultImportance,
        ),
        AndroidNotificationChannel(
          _announcementChannelId,
          'Announcements',
          description: 'Important announcements from coordinators',
          importance: Importance.high,
        ),
      ];
      
      for (final channel in channels) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
      
      debugPrint('NotificationService: Notification channels created');
    } catch (e) {
      debugPrint('NotificationService: Error creating channels: $e');
    }
  }
  
  /// Get FCM token
  static Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('NotificationService: FCM Token: $_fcmToken');
      
      // Save token to user profile
      final currentUser = AuthService.currentUser;
      if (currentUser != null && _fcmToken != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'fcmToken': _fcmToken,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('NotificationService: Token refreshed: $newToken');
        
        // Update token in user profile
        if (currentUser != null) {
          _firestore.collection('users').doc(currentUser.uid).update({
            'fcmToken': newToken,
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      
    } catch (e) {
      debugPrint('NotificationService: Error getting FCM token: $e');
    }
  }
  
  /// Set up message handlers
  static void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle notification tap when app is terminated
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }
  
  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      debugPrint('NotificationService: Foreground message received');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');
      
      // Create notification model
      final notification = NotificationModel.fromRemoteMessage(message);
      
      // Check if notification should be shown based on preferences
      if (!NotificationPreferencesService.shouldShowNotification(notification)) {
        debugPrint('NotificationService: Notification blocked by user preferences');
        return;
      }
      
      // Add to in-app notifications
      _inAppNotifications.insert(0, notification);
      
      // Add to batching service (will handle showing local notification)
      await NotificationBatchingService().addNotificationToBatch(notification);
      
      // Save to database
      await _saveNotificationToDatabase(notification);
      
    } catch (e) {
      debugPrint('NotificationService: Error handling foreground message: $e');
    }
  }
  
  /// Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    try {
      debugPrint('NotificationService: Background message received');
      
      // Create notification model
      final notification = NotificationModel.fromRemoteMessage(message);
      
      // Save to database
      await _saveNotificationToDatabase(notification);
      
    } catch (e) {
      debugPrint('NotificationService: Error handling background message: $e');
    }
  }
  
  /// Handle notification tap
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    try {
      debugPrint('NotificationService: Notification tapped');
      
      // Navigate based on notification type
      final notificationType = message.data['type'];
      final targetId = message.data['targetId'];
      
      // TODO: Implement navigation logic based on notification type
      switch (notificationType) {
        case 'post_like':
        case 'post_comment':
        case 'post_share':
          // Navigate to post detail
          break;
        case 'emergency':
          // Navigate to emergency screen
          break;
        case 'announcement':
          // Navigate to announcement
          break;
        default:
          // Navigate to notifications screen
          break;
      }
      
    } catch (e) {
      debugPrint('NotificationService: Error handling notification tap: $e');
    }
  }
  
  /// Handle local notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    try {
      debugPrint('NotificationService: Local notification tapped');
      
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        // Handle navigation based on payload data
        // TODO: Implement navigation logic
      }
      
    } catch (e) {
      debugPrint('NotificationService: Error handling local notification tap: $e');
    }
  }
  
  /// Show local notification
  static Future<void> _showLocalNotification(NotificationModel notification) async {
    try {
      final channelId = _getChannelId(notification.type);
      
      const androidDetails = AndroidNotificationDetails(
        _defaultChannelId,
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        details,
        payload: jsonEncode(notification.data),
      );
      
    } catch (e) {
      debugPrint('NotificationService: Error showing local notification: $e');
    }
  }
  
  /// Get channel ID based on notification type
  static String _getChannelId(NotificationType type) {
    switch (type) {
      case NotificationType.emergency:
        return _emergencyChannelId;
      case NotificationType.postLike:
      case NotificationType.postComment:
      case NotificationType.postShare:
        return _engagementChannelId;
      case NotificationType.announcement:
        return _announcementChannelId;
      default:
        return _defaultChannelId;
    }
  }
  
  /// Save notification to database
  static Future<void> _saveNotificationToDatabase(NotificationModel notification) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;
      
      // Save to user's notifications collection
      await _userNotificationsCollection
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
      
      debugPrint('NotificationService: Notification saved to database');
    } catch (e) {
      debugPrint('NotificationService: Error saving notification: $e');
    }
  }
  
  /// Subscribe to topics
  static Future<void> _subscribeToTopics() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;
      
      // Get user profile to determine subscriptions
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final userLocation = userData['location'] as Map<String, dynamic>?;
      final userRole = userData['role'] as String?;
      
      // Subscribe to general topics
      await _messaging.subscribeToTopic('all_users');
      
      // Subscribe to role-based topics
      if (userRole != null) {
        await _messaging.subscribeToTopic('role_$userRole');
      }
      
      // Subscribe to location-based topics
      if (userLocation != null) {
        if (userLocation['state'] != null) {
          await _messaging.subscribeToTopic('state_${userLocation['state']}');
        }
        if (userLocation['district'] != null) {
          await _messaging.subscribeToTopic('district_${userLocation['district']}');
        }
        if (userLocation['mandal'] != null) {
          await _messaging.subscribeToTopic('mandal_${userLocation['mandal']}');
        }
        if (userLocation['village'] != null) {
          await _messaging.subscribeToTopic('village_${userLocation['village']}');
        }
      }
      
      debugPrint('NotificationService: Subscribed to topics');
    } catch (e) {
      debugPrint('NotificationService: Error subscribing to topics: $e');
    }
  }
  
  /// Send notification to specific user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('NotificationService: Sending notification to user $userId');
      
      // Create notification document
      final notification = NotificationModel(
        id: _firestore.collection('notifications').doc().id,
        title: title,
        body: body,
        type: type,
        data: data ?? {},
        createdAt: DateTime.now(),
        isRead: false,
      );
      
      // Save to notifications collection for server processing
      await _notificationsCollection.doc(notification.id).set({
        ...notification.toMap(),
        'targetUserId': userId,
        'status': 'pending',
      });
      
      debugPrint('NotificationService: Notification queued for delivery');
    } catch (e) {
      debugPrint('NotificationService: Error sending notification: $e');
      rethrow;
    }
  }
  
  /// Send notification to topic
  static Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('NotificationService: Sending notification to topic $topic');
      
      // Create notification document
      final notification = NotificationModel(
        id: _firestore.collection('notifications').doc().id,
        title: title,
        body: body,
        type: type,
        data: data ?? {},
        createdAt: DateTime.now(),
        isRead: false,
      );
      
      // Save to notifications collection for server processing
      await _notificationsCollection.doc(notification.id).set({
        ...notification.toMap(),
        'targetTopic': topic,
        'status': 'pending',
      });
      
      debugPrint('NotificationService: Topic notification queued for delivery');
    } catch (e) {
      debugPrint('NotificationService: Error sending topic notification: $e');
      rethrow;
    }
  }
  
  /// Get user notifications
  static Future<List<NotificationModel>> getUserNotifications({
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];
      
      Query query = _userNotificationsCollection
          .doc(currentUser.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(limit);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final querySnapshot = await query.get();
      
      return querySnapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      
    } catch (e) {
      debugPrint('NotificationService: Error getting user notifications: $e');
      return [];
    }
  }
  
  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;
      
      await _userNotificationsCollection
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
      
      debugPrint('NotificationService: Notification marked as read');
    } catch (e) {
      debugPrint('NotificationService: Error marking notification as read: $e');
    }
  }
  
  /// Mark all notifications as read
  static Future<void> markAllNotificationsAsRead() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;
      
      final batch = _firestore.batch();
      final notifications = await _userNotificationsCollection
          .doc(currentUser.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      debugPrint('NotificationService: All notifications marked as read');
    } catch (e) {
      debugPrint('NotificationService: Error marking all notifications as read: $e');
    }
  }
  
  /// Get unread notification count
  static Future<int> getUnreadNotificationCount() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return 0;
      
      final querySnapshot = await _userNotificationsCollection
          .doc(currentUser.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      
      return querySnapshot.count ?? 0;
    } catch (e) {
      debugPrint('NotificationService: Error getting unread count: $e');
      return 0;
    }
  }
  
  /// Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;
      
      await _userNotificationsCollection
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      debugPrint('NotificationService: Notification deleted');
    } catch (e) {
      debugPrint('NotificationService: Error deleting notification: $e');
    }
  }
  
  /// Get FCM token
  static String? get fcmToken => _fcmToken;
  
  /// Get in-app notifications
  static List<NotificationModel> get inAppNotifications => _inAppNotifications;
  
  /// Get notification stream
  static Stream<NotificationModel>? get notificationStream => 
      _notificationController.stream;
  
  /// Get unread count stream
  static Stream<int>? get unreadCountStream => 
      _unreadCountController.stream;
  
  /// Clear in-app notifications
  static void clearInAppNotifications() {
    _inAppNotifications.clear();
  }
  
  /// Get recent notifications for a user
  static Future<List<NotificationModel>> getRecentNotifications({
    int limit = 20,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      final querySnapshot = await _userNotificationsCollection
          .doc(user.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('NotificationService: Error getting recent notifications: $e');
      return [];
    }
  }

  /// Send notification using template
  static Future<void> sendNotificationFromTemplate({
    required String userId,
    required NotificationTemplateType templateType,
    required Map<String, dynamic> templateData,
    String? customTitle,
    String? customBody,
  }) async {
    try {
      debugPrint('NotificationService: Sending templated notification to user $userId');
      
      // Create notification from template
      final notification = NotificationTemplates.createFromTemplate(
        templateType: templateType,
        data: {
          ...templateData,
          'targetUserId': userId,
        },
        customTitle: customTitle,
        customBody: customBody,
      );
      
      // Send the notification
      await sendNotificationToUser(
        userId: userId,
        title: notification.title,
        body: notification.body,
        type: notification.type,
        data: notification.data,
      );
      
      debugPrint('NotificationService: Templated notification sent successfully');
    } catch (e) {
      debugPrint('NotificationService: Error sending templated notification: $e');
      rethrow;
    }
  }

  /// Send bulk notifications using template
  static Future<void> sendBulkNotificationsFromTemplate({
    required List<String> userIds,
    required NotificationTemplateType templateType,
    required Map<String, dynamic> templateData,
    String? customTitle,
    String? customBody,
  }) async {
    try {
      debugPrint('NotificationService: Sending bulk templated notifications to ${userIds.length} users');
      
      // Process in batches to avoid overwhelming the system
      const batchSize = 100;
      for (int i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.skip(i).take(batchSize).toList();
        
        final futures = batch.map((userId) => sendNotificationFromTemplate(
          userId: userId,
          templateType: templateType,
          templateData: templateData,
          customTitle: customTitle,
          customBody: customBody,
        ));
        
        await Future.wait(futures);
        
        // Small delay between batches to prevent rate limiting
        if (i + batchSize < userIds.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      debugPrint('NotificationService: Bulk templated notifications sent successfully');
    } catch (e) {
      debugPrint('NotificationService: Error sending bulk templated notifications: $e');
      rethrow;
    }
  }

  /// Show local notification (enhanced with templates)
  static Future<void> showLocalNotification(NotificationModel notification) async {
    try {
      // Check preferences
      if (!NotificationPreferencesService.shouldShowNotification(notification)) {
        debugPrint('NotificationService: Local notification blocked by preferences');
        return;
      }

      final preferences = NotificationPreferencesService.getPreferences();
      
      // Determine channel ID
      String channelId = _defaultChannelId;
      if (notification.data['templateType'] != null) {
        final templateType = NotificationTemplateType.values.firstWhere(
          (type) => type.toString() == notification.data['templateType'],
          orElse: () => NotificationTemplateType.generalAnnouncement,
        );
        channelId = NotificationTemplates.getChannelId(templateType);
      } else {
        channelId = _getChannelId(notification.type);
      }
      
      // Determine sound
      String? sound;
      if (notification.data['templateType'] != null) {
        final templateType = NotificationTemplateType.values.firstWhere(
          (type) => type.toString() == notification.data['templateType'],
          orElse: () => NotificationTemplateType.generalAnnouncement,
        );
        sound = NotificationTemplates.getNotificationSound(templateType);
      }
      
      // Check quiet hours
      bool shouldPlaySound = true;
      bool shouldVibrate = true;
      
      if (preferences.isInQuietHours && !notification.isHighPriority) {
        shouldPlaySound = false;
        shouldVibrate = false;
      }
      
      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: _getImportance(notification.type),
        priority: _getPriority(notification.type),
        playSound: shouldPlaySound,
        enableVibration: shouldVibrate,
        sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
      );
      
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: shouldPlaySound,
        sound: sound,
        interruptionLevel: notification.isHighPriority 
            ? InterruptionLevel.critical 
            : InterruptionLevel.active,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        details,
        payload: jsonEncode(notification.data),
      );
      
      debugPrint('NotificationService: Local notification shown: ${notification.title}');
    } catch (e) {
      debugPrint('NotificationService: Error showing local notification: $e');
    }
  }

  /// Get notification preferences
  static NotificationPreferences? getNotificationPreferences() {
    return NotificationPreferencesService.getPreferences();
  }

  /// Update notification preferences
  static Future<void> updateNotificationPreferences(NotificationPreferences preferences) async {
    await NotificationPreferencesService.updatePreferences(preferences);
  }

  /// Get batching statistics
  static Map<String, dynamic> getBatchingStatistics() {
    return NotificationBatchingService().getBatchStatistics();
  }

  /// Process queued notifications
  static Future<void> processQueuedNotifications() async {
    await NotificationBatchingService().processQueuedNotifications();
  }

  /// Helper methods for notification details
  static String _getChannelName(String channelId) {
    switch (channelId) {
      case _emergencyChannelId:
        return 'Emergency Alerts';
      case _announcementChannelId:
        return 'Announcements';
      case _engagementChannelId:
        return 'Engagement Notifications';
      default:
        return 'General Notifications';
    }
  }

  static String _getChannelDescription(String channelId) {
    switch (channelId) {
      case _emergencyChannelId:
        return 'Critical emergency notifications';
      case _announcementChannelId:
        return 'Important announcements from coordinators';
      case _engagementChannelId:
        return 'Likes, comments, and shares';
      default:
        return 'General app notifications';
    }
  }

  static Importance _getImportance(NotificationType type) {
    switch (type) {
      case NotificationType.emergency:
      case NotificationType.landRightsAlert:
        return Importance.max;
      case NotificationType.announcement:
      case NotificationType.courtDateReminder:
      case NotificationType.legalUpdate:
        return Importance.high;
      case NotificationType.postLike:
      case NotificationType.postShare:
      case NotificationType.newFollower:
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  static Priority _getPriority(NotificationType type) {
    switch (type) {
      case NotificationType.emergency:
      case NotificationType.landRightsAlert:
        return Priority.max;
      case NotificationType.announcement:
      case NotificationType.courtDateReminder:
      case NotificationType.legalUpdate:
        return Priority.high;
      case NotificationType.postLike:
      case NotificationType.postShare:
      case NotificationType.newFollower:
        return Priority.low;
      default:
        return Priority.defaultPriority;
    }
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      debugPrint('NotificationService: Marked notification as read: $notificationId');
    } catch (e) {
      debugPrint('NotificationService: Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('NotificationService: Marked all notifications as read');
    } catch (e) {
      debugPrint('NotificationService: Error marking all notifications as read: $e');
    }
  }

  /// Initialize advanced FCM features
  static Future<void> _initializeAdvancedFCM() async {
    try {
      debugPrint('ðŸš€ Initializing advanced FCM features...');

      // Enable auto-initialization
      await _messaging.setAutoInitEnabled(true);

      // Configure foreground notification presentation options
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Subscribe to topic-based notifications
      await _subscribeToTopics();

      // Setup advanced message handlers
      await _setupAdvancedMessageHandlers();

      // Initialize notification analytics
      await _initializeNotificationAnalytics();

      debugPrint('âœ… Advanced FCM features initialized');

    } catch (e) {
      debugPrint('âŒ Failed to initialize advanced FCM: $e');
    }
  }



  /// Setup advanced message handlers
  static Future<void> _setupAdvancedMessageHandlers() async {
    try {
      // Handle messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('ðŸ”” Received foreground message: ${message.messageId}');

        // Track notification analytics
        await _trackNotificationReceived(message);

        // Show custom in-app notification
        await _showInAppNotification(message);

        // Process notification based on type
        await _processAdvancedNotification(message);
      });

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        debugPrint('ðŸ”” Notification tapped (background): ${message.messageId}');

        // Track notification interaction
        await _trackNotificationOpened(message);

        // Handle navigation
        await _handleNotificationNavigation(message);
      });

      // Handle notification when app is terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('ðŸ”” App opened from notification: ${initialMessage.messageId}');

        // Track notification interaction
        await _trackNotificationOpened(initialMessage);

        // Handle navigation
        await _handleNotificationNavigation(initialMessage);
      }

      debugPrint('âœ… Advanced message handlers setup complete');

    } catch (e) {
      debugPrint('âŒ Failed to setup advanced message handlers: $e');
    }
  }

  /// Show custom in-app notification
  static Future<void> _showInAppNotification(RemoteMessage message) async {
    try {
      // Create notification model
      final notification = NotificationModel(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? 'New Notification',
        body: message.notification?.body ?? '',
        type: _getNotificationTypeFromData(message.data),
        data: message.data,
        createdAt: DateTime.now(),
        isRead: false,
      );

      // Add to in-app notifications
      _inAppNotifications.insert(0, notification);

      // Show custom notification UI
      await _showCustomNotificationUI(notification);

    } catch (e) {
      debugPrint('âŒ Failed to show in-app notification: $e');
    }
  }

  /// Process advanced notification based on type
  static Future<void> _processAdvancedNotification(RemoteMessage message) async {
    try {
      final notificationType = message.data['type'];

      switch (notificationType) {
        case 'emergency_alert':
          await _handleEmergencyAlert(message);
          break;
        case 'legal_update':
          await _handleLegalUpdate(message);
          break;
        case 'campaign_update':
          await _handleCampaignUpdate(message);
          break;
        case 'social_interaction':
          await _handleSocialInteraction(message);
          break;
        case 'system_announcement':
          await _handleSystemAnnouncement(message);
          break;
        default:
          debugPrint('ðŸ”” Unknown notification type: $notificationType');
      }

    } catch (e) {
      debugPrint('âŒ Failed to process advanced notification: $e');
    }
  }

  /// Handle emergency alert notifications
  static Future<void> _handleEmergencyAlert(RemoteMessage message) async {
    try {
      debugPrint('ðŸš¨ Processing emergency alert notification');

      // Show high-priority local notification
      await _showHighPriorityNotification(
        title: message.notification?.title ?? 'Emergency Alert',
        body: message.notification?.body ?? '',
        payload: jsonEncode(message.data),
        channelId: _emergencyChannelId,
      );

      // Store in emergency alerts collection
      await _firestore.collection('emergency_alerts').add({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
        'timestamp': FieldValue.serverTimestamp(),
        'messageId': message.messageId,
      });

    } catch (e) {
      debugPrint('âŒ Failed to handle emergency alert: $e');
    }
  }

  /// Initialize notification analytics
  static Future<void> _initializeNotificationAnalytics() async {
    try {
      debugPrint('ðŸ“Š Initializing notification analytics...');

      // Setup analytics collection
      await _firestore.collection('notification_analytics').doc('config').set({
        'initialized': true,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('âœ… Notification analytics initialized');

    } catch (e) {
      debugPrint('âŒ Failed to initialize notification analytics: $e');
    }
  }

  /// Track notification received
  static Future<void> _trackNotificationReceived(RemoteMessage message) async {
    try {
      await _firestore.collection('notification_analytics').add({
        'event': 'notification_received',
        'messageId': message.messageId,
        'type': message.data['type'],
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'platform': 'flutter_web',
      });
    } catch (e) {
      debugPrint('âŒ Failed to track notification received: $e');
    }
  }

  /// Track notification opened
  static Future<void> _trackNotificationOpened(RemoteMessage message) async {
    try {
      await _firestore.collection('notification_analytics').add({
        'event': 'notification_opened',
        'messageId': message.messageId,
        'type': message.data['type'],
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'platform': 'flutter_web',
      });
    } catch (e) {
      debugPrint('âŒ Failed to track notification opened: $e');
    }
  }

  /// Handle notification navigation
  static Future<void> _handleNotificationNavigation(RemoteMessage message) async {
    try {
      final notificationType = message.data['type'];
      final targetId = message.data['targetId'];

      debugPrint('ðŸ§­ Handling navigation for: $notificationType');

      // Navigation logic will be implemented based on app structure
      switch (notificationType) {
        case 'post_like':
        case 'post_comment':
        case 'post_share':
          // Navigate to specific post
          debugPrint('ðŸ“± Navigate to post: $targetId');
          break;
        case 'new_follower':
        case 'follow_request':
          // Navigate to user profile
          debugPrint('ðŸ‘¤ Navigate to profile: $targetId');
          break;
        case 'legal_update':
        case 'court_case':
          // Navigate to legal section
          debugPrint('âš–ï¸ Navigate to legal section: $targetId');
          break;
        case 'emergency_alert':
          // Navigate to emergency alerts
          debugPrint('ðŸš¨ Navigate to emergency alerts');
          break;
        default:
          debugPrint('ðŸ”” Default navigation for: $notificationType');
      }

    } catch (e) {
      debugPrint('âŒ Failed to handle notification navigation: $e');
    }
  }

  /// Get notification type from message data
  static NotificationType _getNotificationTypeFromData(Map<String, dynamic> data) {
    final typeString = data['type'] as String?;

    switch (typeString) {
      case 'post_like':
        return NotificationType.postLike;
      case 'post_comment':
        return NotificationType.postComment;
      case 'post_share':
        return NotificationType.postShare;
      case 'new_follower':
        return NotificationType.newFollower;
      case 'emergency_alert':
        return NotificationType.emergency;
      case 'legal_update':
        return NotificationType.legalUpdate;
      case 'announcement':
        return NotificationType.announcement;
      case 'campaign_update':
        return NotificationType.campaignUpdate;
      case 'land_rights_alert':
        return NotificationType.landRightsAlert;
      case 'court_date_reminder':
        return NotificationType.courtDateReminder;
      default:
        return NotificationType.general;
    }
  }

  /// Show custom notification UI
  static Future<void> _showCustomNotificationUI(NotificationModel notification) async {
    try {
      // This would integrate with your app's notification UI system
      debugPrint('ðŸŽ¨ Showing custom notification UI: ${notification.title}');

      // For now, just log the notification
      // In a real implementation, this would trigger UI updates

    } catch (e) {
      debugPrint('âŒ Failed to show custom notification UI: $e');
    }
  }

  /// Handle legal update notifications
  static Future<void> _handleLegalUpdate(RemoteMessage message) async {
    try {
      debugPrint('âš–ï¸ Processing legal update notification');

      // Store in legal updates collection
      await _firestore.collection('legal_updates').add({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
        'timestamp': FieldValue.serverTimestamp(),
        'messageId': message.messageId,
      });

    } catch (e) {
      debugPrint('âŒ Failed to handle legal update: $e');
    }
  }

  /// Handle campaign update notifications
  static Future<void> _handleCampaignUpdate(RemoteMessage message) async {
    try {
      debugPrint('ðŸ“¢ Processing campaign update notification');

      // Store in campaign updates collection
      await _firestore.collection('campaign_updates').add({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
        'timestamp': FieldValue.serverTimestamp(),
        'messageId': message.messageId,
      });

    } catch (e) {
      debugPrint('âŒ Failed to handle campaign update: $e');
    }
  }

  /// Handle social interaction notifications
  static Future<void> _handleSocialInteraction(RemoteMessage message) async {
    try {
      debugPrint('ðŸ‘¥ Processing social interaction notification');

      // Store in social interactions collection
      await _firestore.collection('social_interactions').add({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
        'timestamp': FieldValue.serverTimestamp(),
        'messageId': message.messageId,
      });

    } catch (e) {
      debugPrint('âŒ Failed to handle social interaction: $e');
    }
  }

  /// Handle system announcement notifications
  static Future<void> _handleSystemAnnouncement(RemoteMessage message) async {
    try {
      debugPrint('ðŸ“£ Processing system announcement notification');

      // Store in system announcements collection
      await _firestore.collection('system_announcements').add({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
        'timestamp': FieldValue.serverTimestamp(),
        'messageId': message.messageId,
      });

    } catch (e) {
      debugPrint('âŒ Failed to handle system announcement: $e');
    }
  }

  /// Show high-priority notification
  static Future<void> _showHighPriorityNotification({
    required String title,
    required String body,
    required String payload,
    required String channelId,
  }) async {
    try {
      if (kIsWeb) {
        // Web notifications are handled differently
        debugPrint('ðŸŒ Web high-priority notification: $title');
        return;
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'emergency_channel',
        'Emergency Alerts',
        channelDescription: 'Critical emergency alerts and notifications',
        enableVibration: true,
        playSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

    } catch (e) {
      debugPrint('âŒ Failed to show high-priority notification: $e');
    }
  }
}
