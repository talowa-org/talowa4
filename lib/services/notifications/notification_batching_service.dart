// Notification Batching Service - Prevent spam and improve battery life
// Part of Task 12: Build push notification system

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/notification_model.dart';
import 'notification_service.dart';

class NotificationBatchingService {
  static final NotificationBatchingService _instance = NotificationBatchingService._internal();
  factory NotificationBatchingService() => _instance;
  NotificationBatchingService._internal();

  // Batching configuration
  static const int _maxBatchSize = 5;
  static const Duration _batchWindow = Duration(minutes: 5);
  static const Duration _quietHoursBatchWindow = Duration(hours: 1);
  static const int _maxNotificationsPerHour = 10;
  static const int _maxNotificationsPerDay = 50;

  // Batch storage
  final Queue<NotificationModel> _pendingNotifications = Queue<NotificationModel>();
  final Map<NotificationType, List<NotificationModel>> _typeBatches = {};
  Timer? _batchTimer;
  Timer? _rateLimitResetTimer;

  // Rate limiting counters
  int _notificationsThisHour = 0;
  int _notificationsToday = 0;
  DateTime _lastHourReset = DateTime.now();
  DateTime _lastDayReset = DateTime.now();

  /// Initialize the batching service
  Future<void> initialize() async {
    try {
      debugPrint('NotificationBatchingService: Initializing...');
      
      // Load persisted counters
      await _loadRateLimitCounters();
      
      // Set up rate limit reset timers
      _setupRateLimitResetTimers();
      
      debugPrint('NotificationBatchingService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationBatchingService: Initialization failed: $e');
    }
  }

  /// Add notification to batch queue
  Future<void> addNotificationToBatch(NotificationModel notification) async {
    try {
      // Check if notification should bypass batching
      if (_shouldBypassBatching(notification)) {
        await _deliverImmediately(notification);
        return;
      }

      // Check rate limits
      if (!_checkRateLimits(notification)) {
        debugPrint('NotificationBatchingService: Rate limit exceeded, queuing for later');
        await _queueForLater(notification);
        return;
      }

      // Add to appropriate batch
      _addToBatch(notification);

      // Check if batch should be delivered immediately
      if (_shouldDeliverBatch(notification.type)) {
        await _deliverBatch(notification.type);
      } else {
        _scheduleBatchDelivery();
      }

    } catch (e) {
      debugPrint('NotificationBatchingService: Error adding notification to batch: $e');
    }
  }

  /// Check if notification should bypass batching
  bool _shouldBypassBatching(NotificationModel notification) {
    // Emergency notifications always bypass batching
    if (notification.type == NotificationType.emergency) {
      return true;
    }

    // Critical announcements bypass batching
    if (notification.type == NotificationType.announcement && 
        notification.isHighPriority) {
      return true;
    }

    // Court date reminders bypass batching
    if (notification.type == NotificationType.courtDateReminder) {
      return true;
    }

    return false;
  }

  /// Check rate limits
  bool _checkRateLimits(NotificationModel notification) {
    _updateRateLimitCounters();

    // Emergency notifications bypass rate limits
    if (notification.type == NotificationType.emergency) {
      return true;
    }

    // Check hourly limit
    if (_notificationsThisHour >= _maxNotificationsPerHour) {
      return false;
    }

    // Check daily limit
    if (_notificationsToday >= _maxNotificationsPerDay) {
      return false;
    }

    return true;
  }

  /// Update rate limit counters
  void _updateRateLimitCounters() {
    final now = DateTime.now();

    // Reset hourly counter if needed
    if (now.difference(_lastHourReset).inHours >= 1) {
      _notificationsThisHour = 0;
      _lastHourReset = now;
    }

    // Reset daily counter if needed
    if (now.difference(_lastDayReset).inDays >= 1) {
      _notificationsToday = 0;
      _lastDayReset = now;
    }
  }

  /// Add notification to type-specific batch
  void _addToBatch(NotificationModel notification) {
    if (!_typeBatches.containsKey(notification.type)) {
      _typeBatches[notification.type] = [];
    }
    
    _typeBatches[notification.type]!.add(notification);
    _pendingNotifications.add(notification);

    debugPrint('NotificationBatchingService: Added ${notification.type} notification to batch. '
        'Batch size: ${_typeBatches[notification.type]!.length}');
  }

  /// Check if batch should be delivered immediately
  bool _shouldDeliverBatch(NotificationType type) {
    final batch = _typeBatches[type];
    if (batch == null || batch.isEmpty) return false;

    // Deliver if batch is full
    if (batch.length >= _maxBatchSize) {
      return true;
    }

    // Deliver high-priority types more frequently
    if (_isHighPriorityType(type) && batch.length >= 2) {
      return true;
    }

    return false;
  }

  /// Check if notification type is high priority
  bool _isHighPriorityType(NotificationType type) {
    return [
      NotificationType.emergency,
      NotificationType.announcement,
      NotificationType.legalUpdate,
      NotificationType.courtDateReminder,
      NotificationType.landRightsAlert,
    ].contains(type);
  }

  /// Schedule batch delivery
  void _scheduleBatchDelivery() {
    // Cancel existing timer
    _batchTimer?.cancel();

    // Determine batch window based on quiet hours
    final preferences = NotificationService.getNotificationPreferences();
    final batchWindow = preferences?.isInQuietHours == true 
        ? _quietHoursBatchWindow 
        : _batchWindow;

    // Schedule delivery
    _batchTimer = Timer(batchWindow, () async {
      await _deliverAllBatches();
    });

    debugPrint('NotificationBatchingService: Scheduled batch delivery in ${batchWindow.inMinutes} minutes');
  }

  /// Deliver specific batch
  Future<void> _deliverBatch(NotificationType type) async {
    try {
      final batch = _typeBatches[type];
      if (batch == null || batch.isEmpty) return;

      debugPrint('NotificationBatchingService: Delivering batch of ${batch.length} $type notifications');

      // Create batched notification
      final batchedNotification = _createBatchedNotification(type, batch);

      // Deliver the batched notification
      await _deliverImmediately(batchedNotification);

      // Update rate limit counters
      _notificationsThisHour++;
      _notificationsToday++;
      await _saveRateLimitCounters();

      // Clear the batch
      _typeBatches[type]!.clear();
      _pendingNotifications.removeWhere((n) => n.type == type);

    } catch (e) {
      debugPrint('NotificationBatchingService: Error delivering batch: $e');
    }
  }

  /// Deliver all pending batches
  Future<void> _deliverAllBatches() async {
    try {
      debugPrint('NotificationBatchingService: Delivering all pending batches');

      final typesToDeliver = _typeBatches.keys.where((type) => 
          _typeBatches[type]!.isNotEmpty).toList();

      for (final type in typesToDeliver) {
        await _deliverBatch(type);
      }

      // Cancel the timer
      _batchTimer?.cancel();
      _batchTimer = null;

    } catch (e) {
      debugPrint('NotificationBatchingService: Error delivering all batches: $e');
    }
  }

  /// Create a batched notification from multiple notifications
  NotificationModel _createBatchedNotification(NotificationType type, List<NotificationModel> batch) {
    if (batch.length == 1) {
      return batch.first;
    }

    // Create summary notification
    final String title;
    final String body;

    switch (type) {
      case NotificationType.postLike:
        title = 'New Likes';
        body = batch.length == 2 
            ? '${batch[0].title} and 1 other liked your posts'
            : '${batch[0].title} and ${batch.length - 1} others liked your posts';
        break;

      case NotificationType.postComment:
        title = 'New Comments';
        body = batch.length == 2
            ? '${batch[0].title} and 1 other commented on your posts'
            : '${batch[0].title} and ${batch.length - 1} others commented on your posts';
        break;

      case NotificationType.networkUpdate:
        title = 'Network Updates';
        body = 'You have ${batch.length} new network updates';
        break;

      case NotificationType.announcement:
        title = 'Announcements';
        body = 'You have ${batch.length} new announcements';
        break;

      case NotificationType.legalUpdate:
        title = 'Legal Updates';
        body = 'You have ${batch.length} new legal updates';
        break;

      default:
        title = '${type.displayName}s';
        body = 'You have ${batch.length} new ${type.displayName.toLowerCase()}s';
        break;
    }

    return NotificationModel(
      id: 'batch_${type.toString().split('.').last}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      data: {
        'isBatched': true,
        'batchCount': batch.length,
        'batchIds': batch.map((n) => n.id).toList(),
      },
      createdAt: DateTime.now(),
      isRead: false,
    );
  }

  /// Deliver notification immediately
  Future<void> _deliverImmediately(NotificationModel notification) async {
    try {
      await NotificationService.showLocalNotification(notification);
      
      // Update counters for non-batched notifications
      if (notification.data['isBatched'] != true) {
        _notificationsThisHour++;
        _notificationsToday++;
        await _saveRateLimitCounters();
      }

      debugPrint('NotificationBatchingService: Delivered notification immediately: ${notification.title}');
    } catch (e) {
      debugPrint('NotificationBatchingService: Error delivering notification immediately: $e');
    }
  }

  /// Queue notification for later delivery
  Future<void> _queueForLater(NotificationModel notification) async {
    try {
      // Store in local storage for later delivery
      final prefs = await SharedPreferences.getInstance();
      final queuedNotifications = prefs.getStringList('queued_notifications') ?? [];
      
      // Add notification to queue (limit queue size)
      if (queuedNotifications.length < 100) {
        queuedNotifications.add(notification.toMap().toString());
        await prefs.setStringList('queued_notifications', queuedNotifications);
      }

      debugPrint('NotificationBatchingService: Queued notification for later: ${notification.title}');
    } catch (e) {
      debugPrint('NotificationBatchingService: Error queuing notification: $e');
    }
  }

  /// Process queued notifications
  Future<void> processQueuedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queuedNotifications = prefs.getStringList('queued_notifications') ?? [];
      
      if (queuedNotifications.isEmpty) return;

      debugPrint('NotificationBatchingService: Processing ${queuedNotifications.length} queued notifications');

      final processedIds = <String>[];

      for (final notificationData in queuedNotifications) {
        try {
          // Parse notification (simplified - in real implementation, use proper JSON parsing)
          // For now, just clear the queue
          processedIds.add(notificationData);
        } catch (e) {
          debugPrint('NotificationBatchingService: Error processing queued notification: $e');
        }
      }

      // Remove processed notifications from queue
      await prefs.setStringList('queued_notifications', []);

      debugPrint('NotificationBatchingService: Processed ${processedIds.length} queued notifications');
    } catch (e) {
      debugPrint('NotificationBatchingService: Error processing queued notifications: $e');
    }
  }

  /// Load rate limit counters from storage
  Future<void> _loadRateLimitCounters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _notificationsThisHour = prefs.getInt('notifications_this_hour') ?? 0;
      _notificationsToday = prefs.getInt('notifications_today') ?? 0;
      
      final lastHourResetMs = prefs.getInt('last_hour_reset') ?? DateTime.now().millisecondsSinceEpoch;
      final lastDayResetMs = prefs.getInt('last_day_reset') ?? DateTime.now().millisecondsSinceEpoch;
      
      _lastHourReset = DateTime.fromMillisecondsSinceEpoch(lastHourResetMs);
      _lastDayReset = DateTime.fromMillisecondsSinceEpoch(lastDayResetMs);

      debugPrint('NotificationBatchingService: Loaded rate limit counters - Hour: $_notificationsThisHour, Day: $_notificationsToday');
    } catch (e) {
      debugPrint('NotificationBatchingService: Error loading rate limit counters: $e');
    }
  }

  /// Save rate limit counters to storage
  Future<void> _saveRateLimitCounters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt('notifications_this_hour', _notificationsThisHour);
      await prefs.setInt('notifications_today', _notificationsToday);
      await prefs.setInt('last_hour_reset', _lastHourReset.millisecondsSinceEpoch);
      await prefs.setInt('last_day_reset', _lastDayReset.millisecondsSinceEpoch);

    } catch (e) {
      debugPrint('NotificationBatchingService: Error saving rate limit counters: $e');
    }
  }

  /// Set up rate limit reset timers
  void _setupRateLimitResetTimers() {
    // Reset hourly counter every hour
    _rateLimitResetTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _notificationsThisHour = 0;
      _lastHourReset = DateTime.now();
      _saveRateLimitCounters();
    });

    // Process queued notifications every hour
    Timer.periodic(const Duration(hours: 1), (timer) {
      processQueuedNotifications();
    });
  }

  /// Get current batch statistics
  Map<String, dynamic> getBatchStatistics() {
    return {
      'pendingNotifications': _pendingNotifications.length,
      'typeBatches': _typeBatches.map((key, value) => MapEntry(key.toString(), value.length)),
      'notificationsThisHour': _notificationsThisHour,
      'notificationsToday': _notificationsToday,
      'maxNotificationsPerHour': _maxNotificationsPerHour,
      'maxNotificationsPerDay': _maxNotificationsPerDay,
    };
  }

  /// Clear all batches (for testing or reset)
  void clearAllBatches() {
    _pendingNotifications.clear();
    _typeBatches.clear();
    _batchTimer?.cancel();
    _batchTimer = null;
    
    debugPrint('NotificationBatchingService: Cleared all batches');
  }

  /// Dispose resources
  void dispose() {
    _batchTimer?.cancel();
    _rateLimitResetTimer?.cancel();
    clearAllBatches();
  }
}
