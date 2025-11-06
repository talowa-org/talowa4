import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for handling local notifications including call notifications
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the local notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Combined initialization settings
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // Initialize the plugin
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions
      await _requestPermissions();

      _isInitialized = true;
      debugPrint('Local notification service initialized');
    } catch (e) {
      debugPrint('Failed to initialize local notification service: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Request Android permissions
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }

      // Request iOS permissions (using generic approach for compatibility)
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS permissions are handled during initialization
        debugPrint('iOS notification permissions requested during initialization');
      }
    } catch (e) {
      debugPrint('Failed to request notification permissions: $e');
    }
  }

  /// Show incoming call notification (overloaded method for IncomingCall object)
  Future<void> showIncomingCallNotification(dynamic incomingCall) async {
    if (incomingCall is Map) {
      // Handle map-based call
      await showIncomingCallNotificationDetails(
        callId: incomingCall['id'] ?? '',
        callerName: incomingCall['callerName'] ?? 'Unknown',
        callerRole: incomingCall['callerRole'] ?? 'member',
      );
    } else {
      // Handle object-based call
      await showIncomingCallNotificationDetails(
        callId: incomingCall.id,
        callerName: incomingCall.callerName,
        callerRole: incomingCall.callerRole,
      );
    }
  }

  /// Show incoming call notification with details
  Future<void> showIncomingCallNotificationDetails({
    required String callId,
    required String callerName,
    required String callerRole,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'incoming_calls',
        'Incoming Calls',
        channelDescription: 'Notifications for incoming voice calls',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
        sound: RawResourceAndroidNotificationSound('call_ringtone'),
        playSound: true,
        enableVibration: true,
        vibrationPattern: [0, 1000, 500, 1000],
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'accept_call',
            'Accept',
            icon: DrawableResourceAndroidBitmap('ic_call_accept'),
          ),
          AndroidNotificationAction(
            'reject_call',
            'Reject',
            icon: DrawableResourceAndroidBitmap('ic_call_reject'),
          ),
        ],
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        categoryIdentifier: 'incoming_call',
        sound: 'call_ringtone.aiff',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        callId.hashCode,
        'Incoming Call',
        '$callerName ($callerRole)',
        platformChannelSpecifics,
        payload: 'incoming_call:$callId',
      );

      debugPrint('Incoming call notification shown for: $callerName');
    } catch (e) {
      debugPrint('Failed to show incoming call notification: $e');
    }
  }

  /// Show missed call notification (overloaded method for IncomingCall object)
  Future<void> showMissedCallNotification(dynamic incomingCall) async {
    if (incomingCall is Map) {
      // Handle map-based call
      await showMissedCallNotificationDetails(
        callId: incomingCall['id'] ?? '',
        callerName: incomingCall['callerName'] ?? 'Unknown',
        callerRole: incomingCall['callerRole'] ?? 'member',
      );
    } else {
      // Handle object-based call
      await showMissedCallNotificationDetails(
        callId: incomingCall.id,
        callerName: incomingCall.callerName,
        callerRole: incomingCall.callerRole,
      );
    }
  }

  /// Show missed call notification with details
  Future<void> showMissedCallNotificationDetails({
    required String callId,
    required String callerName,
    required String callerRole,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'missed_calls',
        'Missed Calls',
        channelDescription: 'Notifications for missed voice calls',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.missedCall,
        showWhen: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'call_back',
            'Call Back',
            icon: DrawableResourceAndroidBitmap('ic_call'),
          ),
          AndroidNotificationAction(
            'view_history',
            'View History',
            icon: DrawableResourceAndroidBitmap('ic_history'),
          ),
        ],
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        categoryIdentifier: 'missed_call',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        callId.hashCode + 1000, // Different ID from incoming call
        'Missed Call',
        '$callerName ($callerRole)',
        platformChannelSpecifics,
        payload: 'missed_call:$callId',
      );

      debugPrint('Missed call notification shown for: $callerName');
    } catch (e) {
      debugPrint('Failed to show missed call notification: $e');
    }
  }

  /// Cancel incoming call notification
  Future<void> cancelIncomingCallNotification(String callId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(callId.hashCode);
      debugPrint('Cancelled incoming call notification for: $callId');
    } catch (e) {
      debugPrint('Failed to cancel incoming call notification: $e');
    }
  }

  /// Cancel all call notifications
  Future<void> cancelAllCallNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('Cancelled all call notifications');
    } catch (e) {
      debugPrint('Failed to cancel all call notifications: $e');
    }
  }

  /// Show general notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const AndroidNotificationDetails defaultAndroidDetails =
          AndroidNotificationDetails(
        'general',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const DarwinNotificationDetails defaultIOSDetails =
          DarwinNotificationDetails();

      final NotificationDetails details = notificationDetails ??
          const NotificationDetails(
            android: defaultAndroidDetails,
            iOS: defaultIOSDetails,
          );

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('Notification shown: $title');
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    try {
      final payload = notificationResponse.payload;
      if (payload == null) return;

      debugPrint('Notification tapped with payload: $payload');

      // Handle different notification types
      if (payload.startsWith('incoming_call:')) {
        final callId = payload.substring('incoming_call:'.length);
        _handleIncomingCallNotificationTap(callId);
      } else if (payload.startsWith('missed_call:')) {
        final callId = payload.substring('missed_call:'.length);
        _handleMissedCallNotificationTap(callId);
      }

      // Handle notification actions
      final actionId = notificationResponse.actionId;
      if (actionId != null) {
        _handleNotificationAction(actionId, payload);
      }
    } catch (e) {
      debugPrint('Failed to handle notification tap: $e');
    }
  }

  /// Handle incoming call notification tap
  void _handleIncomingCallNotificationTap(String callId) {
    // TODO: Navigate to incoming call screen or accept call
    debugPrint('Incoming call notification tapped: $callId');
  }

  /// Handle missed call notification tap
  void _handleMissedCallNotificationTap(String callId) {
    // TODO: Navigate to call history or call back
    debugPrint('Missed call notification tapped: $callId');
  }

  /// Handle notification actions
  void _handleNotificationAction(String actionId, String payload) {
    try {
      switch (actionId) {
        case 'accept_call':
          final callId = payload.substring('incoming_call:'.length);
          _handleAcceptCallAction(callId);
          break;
        case 'reject_call':
          final callId = payload.substring('incoming_call:'.length);
          _handleRejectCallAction(callId);
          break;
        case 'call_back':
          final callId = payload.substring('missed_call:'.length);
          _handleCallBackAction(callId);
          break;
        case 'view_history':
          _handleViewHistoryAction();
          break;
      }
    } catch (e) {
      debugPrint('Failed to handle notification action: $e');
    }
  }

  /// Handle accept call action
  void _handleAcceptCallAction(String callId) {
    // TODO: Accept the incoming call
    debugPrint('Accept call action: $callId');
  }

  /// Handle reject call action
  void _handleRejectCallAction(String callId) {
    // TODO: Reject the incoming call
    debugPrint('Reject call action: $callId');
  }

  /// Handle call back action
  void _handleCallBackAction(String callId) {
    // TODO: Initiate call back
    debugPrint('Call back action: $callId');
  }

  /// Handle view history action
  void _handleViewHistoryAction() {
    // TODO: Navigate to call history
    debugPrint('View history action');
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Failed to get pending notifications: $e');
      return [];
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
      
      return true; // Assume enabled for iOS
    } catch (e) {
      debugPrint('Failed to check notification permissions: $e');
      return false;
    }
  }

  /// Clear call notifications for a specific call
  Future<void> clearCallNotifications(String callId) async {
    try {
      await cancelIncomingCallNotification(callId);
      debugPrint('Cleared call notifications for: $callId');
    } catch (e) {
      debugPrint('Failed to clear call notifications: $e');
    }
  }

  /// Send call notification to a specific user
  Future<void> sendCallNotification(String recipientId, dynamic incomingCall) async {
    try {
      // For local notifications, we just show the incoming call notification
      await showIncomingCallNotification(incomingCall);
      debugPrint('Sent call notification to: $recipientId');
    } catch (e) {
      debugPrint('Failed to send call notification: $e');
    }
  }

  /// Show call failed notification
  Future<void> showCallFailedNotification(dynamic callSession) async {
    try {
      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Call Failed',
        body: 'Unable to connect the call. Please try again.',
        payload: 'call_failed:${callSession.id}',
      );
      debugPrint('Call failed notification shown');
    } catch (e) {
      debugPrint('Failed to show call failed notification: $e');
    }
  }
}
