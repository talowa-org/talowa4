// Notification Service - Handle push notifications and in-app notifications
// Part of Task 14: Build notification system

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import '../../models/notification_model.dart';
import '../auth/auth_service.dart';

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
  
  /// Initialize notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('NotificationService: Initializing...');
      
      // Request permissions
      await _requestPermissions();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Get FCM token
      await _getFCMToken();
      
      // Set up message handlers
      _setupMessageHandlers();
      
      // Subscribe to topics
      await _subscribeToTopics();
      
      _isInitialized = true;
      debugPrint('NotificationService: Initialized successfully');
      
    } catch (e) {
      debugPrint('NotificationService: Initialization failed: $e');
      rethrow;
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
      
      // Add to in-app notifications
      _inAppNotifications.insert(0, notification);
      
      // Show local notification
      await _showLocalNotification(notification);
      
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
  
  /// Clear in-app notifications
  static void clearInAppNotifications() {
    _inAppNotifications.clear();
  }
}