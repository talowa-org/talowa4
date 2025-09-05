// Live Activity Service - Real-time activity feed and notifications
// Enhanced real-time features for TALOWA app

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/comment_model.dart';
import '../auth/auth_service.dart';
import '../notifications/notification_service.dart';

/// Service for managing live activity feed and real-time notifications
class LiveActivityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream controllers for live activities
  static final StreamController<LiveActivity> _activityStreamController = 
      StreamController<LiveActivity>.broadcast();
  static final StreamController<List<LiveActivity>> _feedActivityController = 
      StreamController<List<LiveActivity>>.broadcast();
  static final StreamController<Map<String, int>> _activityCountsController = 
      StreamController<Map<String, int>>.broadcast();
  
  // Active listeners
  static final Map<String, StreamSubscription> _activeListeners = {};
  static StreamSubscription? _globalActivityListener;
  static Timer? _activityAggregationTimer;
  
  // State management
  static bool _isInitialized = false;
  static final List<LiveActivity> _recentActivities = [];
  static final Map<String, int> _activityCounts = {
    'posts': 0,
    'comments': 0,
    'likes': 0,
    'shares': 0,
    'users_online': 0,
  };
  
  // Configuration
  static const Duration _activityRetentionPeriod = Duration(hours: 24);
  static const int _maxRecentActivities = 100;
  static const Duration _aggregationInterval = Duration(seconds: 30);
  
  /// Initialize live activity service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('ðŸ”´ LiveActivityService: Initializing...');
      
      // Start global activity monitoring
      await _startGlobalActivityMonitoring();
      
      // Start activity aggregation
      _startActivityAggregation();
      
      // Clean up old activities
      await _cleanupOldActivities();
      
      _isInitialized = true;
      debugPrint('âœ… LiveActivityService: Initialized successfully');
      
    } catch (e) {
      debugPrint('âŒ LiveActivityService: Initialization failed: $e');
      rethrow;
    }
  }
  
  /// Dispose service and clean up resources
  static Future<void> dispose() async {
    debugPrint('ðŸ”´ LiveActivityService: Disposing...');
    
    // Cancel all listeners
    for (final subscription in _activeListeners.values) {
      await subscription.cancel();
    }
    _activeListeners.clear();
    
    // Cancel global listener
    await _globalActivityListener?.cancel();
    _globalActivityListener = null;
    
    // Cancel timers
    _activityAggregationTimer?.cancel();
    _activityAggregationTimer = null;
    
    // Close stream controllers
    await _activityStreamController.close();
    await _feedActivityController.close();
    await _activityCountsController.close();
    
    _isInitialized = false;
    debugPrint('âœ… LiveActivityService: Disposed successfully');
  }
  
  /// Get live activity stream
  static Stream<LiveActivity> get activityStream => _activityStreamController.stream;
  
  /// Get feed activity stream
  static Stream<List<LiveActivity>> get feedActivityStream => _feedActivityController.stream;
  
  /// Get activity counts stream
  static Stream<Map<String, int>> get activityCountsStream => _activityCountsController.stream;
  
  /// Track new post activity
  static Future<void> trackPostActivity({
    required PostModel post,
    required ActivityType type,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final activity = LiveActivity(
        id: _generateActivityId(),
        type: type,
        userId: userId ?? AuthService.currentUser?.uid ?? 'anonymous',
        targetId: post.id,
        targetType: 'post',
        title: _getActivityTitle(type, post.title ?? 'Untitled Post'),
        description: _getActivityDescription(type, post),
        imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls.first : null,
        timestamp: DateTime.now(),
        metadata: {
          'postTitle': post.title,
          'authorName': post.authorName,
          'location': post.location,
          ...?metadata,
        },
      );
      
      await _saveActivity(activity);
      _broadcastActivity(activity);
      
    } catch (e) {
      debugPrint('âŒ LiveActivityService: Error tracking post activity: $e');
    }
  }
  
  /// Track comment activity
  static Future<void> trackCommentActivity({
    required CommentModel comment,
    required String postTitle,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final activity = LiveActivity(
        id: _generateActivityId(),
        type: ActivityType.comment,
        userId: userId ?? AuthService.currentUser?.uid ?? 'anonymous',
        targetId: comment.id,
        targetType: 'comment',
        title: 'New comment on "$postTitle"',
        description: comment.content.length > 100 
            ? '${comment.content.substring(0, 100)}...' 
            : comment.content,
        timestamp: DateTime.now(),
        metadata: {
          'postId': comment.postId,
          'postTitle': postTitle,
          'authorName': comment.authorName,
          ...?metadata,
        },
      );
      
      await _saveActivity(activity);
      _broadcastActivity(activity);
      
    } catch (e) {
      debugPrint('âŒ LiveActivityService: Error tracking comment activity: $e');
    }
  }
  
  /// Track engagement activity (likes, shares)
  static Future<void> trackEngagementActivity({
    required ActivityType type,
    required String targetId,
    required String targetType,
    required String targetTitle,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final activity = LiveActivity(
        id: _generateActivityId(),
        type: type,
        userId: userId ?? AuthService.currentUser?.uid ?? 'anonymous',
        targetId: targetId,
        targetType: targetType,
        title: _getEngagementTitle(type, targetTitle),
        description: _getEngagementDescription(type, targetTitle),
        timestamp: DateTime.now(),
        metadata: {
          'targetTitle': targetTitle,
          ...?metadata,
        },
      );
      
      await _saveActivity(activity);
      _broadcastActivity(activity);
      
    } catch (e) {
      debugPrint('âŒ LiveActivityService: Error tracking engagement activity: $e');
    }
  }
  
  /// Get recent activities for user feed
  static Future<List<LiveActivity>> getRecentActivities({
    int limit = 50,
    String? userId,
    List<ActivityType>? types,
  }) async {
    try {
      Query query = _firestore
          .collection('live_activities')
          .orderBy('timestamp', descending: true)
          .limit(limit);
      
      // Filter by user if specified
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      // Filter by types if specified
      if (types != null && types.isNotEmpty) {
        query = query.where('type', whereIn: types.map((t) => t.name).toList());
      }
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => LiveActivity.fromFirestore(doc))
          .toList();
      
    } catch (e) {
      debugPrint('âŒ LiveActivityService: Error getting recent activities: $e');
      return [];
    }
  }
  
  /// Get activity statistics
  static Future<Map<String, dynamic>> getActivityStats({
    Duration? period,
  }) async {
    try {
      final startTime = DateTime.now().subtract(period ?? const Duration(hours: 24));
      
      final snapshot = await _firestore
          .collection('live_activities')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startTime))
          .get();
      
      final activities = snapshot.docs
          .map((doc) => LiveActivity.fromFirestore(doc))
          .toList();
      
      // Calculate statistics
      final stats = <String, dynamic>{
        'totalActivities': activities.length,
        'uniqueUsers': activities.map((a) => a.userId).toSet().length,
        'typeBreakdown': <String, int>{},
        'hourlyDistribution': <int, int>{},
        'topUsers': <String, int>{},
      };
      
      // Type breakdown
      for (final activity in activities) {
        final type = activity.type.name;
        stats['typeBreakdown'][type] = (stats['typeBreakdown'][type] ?? 0) + 1;
      }
      
      // Hourly distribution
      for (final activity in activities) {
        final hour = activity.timestamp.hour;
        stats['hourlyDistribution'][hour] = (stats['hourlyDistribution'][hour] ?? 0) + 1;
      }
      
      // Top users
      for (final activity in activities) {
        stats['topUsers'][activity.userId] = (stats['topUsers'][activity.userId] ?? 0) + 1;
      }
      
      return stats;
      
    } catch (e) {
      debugPrint('âŒ LiveActivityService: Error getting activity stats: $e');
      return {};
    }
  }
  
  /// Start monitoring user's personalized activity feed
  static void startPersonalizedFeed(String userId) {
    if (_activeListeners.containsKey('personal_$userId')) return;
    
    _activeListeners['personal_$userId'] = _firestore
        .collection('live_activities')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(_activityRetentionPeriod)))
        .orderBy('timestamp', descending: true)
        .limit(_maxRecentActivities)
        .snapshots()
        .listen(
          (snapshot) {
            final activities = snapshot.docs
                .map((doc) => LiveActivity.fromFirestore(doc))
                .toList();
            
            _feedActivityController.add(activities);
          },
          onError: (error) {
            debugPrint('âŒ LiveActivityService: Personal feed error: $error');
          },
        );
  }
  
  /// Stop monitoring user's personalized activity feed
  static void stopPersonalizedFeed(String userId) {
    final listener = _activeListeners.remove('personal_$userId');
    listener?.cancel();
  }
  
  // Private helper methods
  
  static Future<void> _startGlobalActivityMonitoring() async {
    _globalActivityListener = _firestore
        .collection('live_activities')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 5))))
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final activity = LiveActivity.fromFirestore(change.doc);
                _broadcastActivity(activity);
              }
            }
          },
          onError: (error) {
            debugPrint('âŒ LiveActivityService: Global monitoring error: $error');
          },
        );
  }
  
  static void _startActivityAggregation() {
    _activityAggregationTimer = Timer.periodic(_aggregationInterval, (timer) {
      _updateActivityCounts();
    });
  }
  
  static Future<void> _updateActivityCounts() async {
    try {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      // Get recent activities
      final snapshot = await _firestore
          .collection('live_activities')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();
      
      final activities = snapshot.docs
          .map((doc) => LiveActivity.fromFirestore(doc))
          .toList();
      
      // Update counts
      _activityCounts['posts'] = activities.where((a) => a.type == ActivityType.postCreated).length;
      _activityCounts['comments'] = activities.where((a) => a.type == ActivityType.comment).length;
      _activityCounts['likes'] = activities.where((a) => a.type == ActivityType.like).length;
      _activityCounts['shares'] = activities.where((a) => a.type == ActivityType.share).length;
      
      // Get online users count (simplified)
      final onlineUsersSnapshot = await _firestore
          .collection('user_presence')
          .where('isOnline', isEqualTo: true)
          .where('lastSeen', isGreaterThan: Timestamp.fromDate(
              now.subtract(const Duration(minutes: 5))))
          .get();
      
      _activityCounts['users_online'] = onlineUsersSnapshot.docs.length;
      
      // Broadcast updated counts
      _activityCountsController.add(Map.from(_activityCounts));
      
    } catch (e) {
      debugPrint('âŒ LiveActivityService: Error updating activity counts: $e');
    }
  }
  
  static Future<void> _saveActivity(LiveActivity activity) async {
    await _firestore
        .collection('live_activities')
        .doc(activity.id)
        .set(activity.toFirestore());
  }
  
  static void _broadcastActivity(LiveActivity activity) {
    // Add to recent activities
    _recentActivities.insert(0, activity);
    if (_recentActivities.length > _maxRecentActivities) {
      _recentActivities.removeLast();
    }
    
    // Broadcast to stream
    _activityStreamController.add(activity);
    
    // Send push notification for important activities
    _sendActivityNotification(activity);
  }
  
  static Future<void> _sendActivityNotification(LiveActivity activity) async {
    try {
      // Only send notifications for certain activity types
      if (![ActivityType.comment, ActivityType.like, ActivityType.share].contains(activity.type)) {
        return;
      }
      
      // Don't send notifications for user's own activities
      if (activity.userId == AuthService.currentUser?.uid) {
        return;
      }
      
      // Use NotificationOverlayManager for in-app notifications
      // NotificationService.showInAppNotification is private
      debugPrint('Live activity notification: ${activity.title}');
      // TODO: Implement proper in-app notification display
      /*
      await NotificationService.showInAppNotification(
        title: activity.title,
        body: activity.description,
        data: {
          'type': 'live_activity',
          'activityId': activity.id,
          'targetId': activity.targetId,
          'targetType': activity.targetType,
        },
      );
      */
      
    } catch (e) {
      debugPrint('âŒ LiveActivityService: Error sending activity notification: $e');
    }
  }
  
  static Future<void> _cleanupOldActivities() async {
    try {
      final cutoffTime = DateTime.now().subtract(_activityRetentionPeriod);
      
      final oldActivities = await _firestore
          .collection('live_activities')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();
      
      final batch = _firestore.batch();
      for (final doc in oldActivities.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('ðŸ§¹ LiveActivityService: Cleaned up ${oldActivities.docs.length} old activities');
      
    } catch (e) {
      debugPrint('âŒ LiveActivityService: Error cleaning up old activities: $e');
    }
  }
  
  static String _generateActivityId() {
    return 'activity_${DateTime.now().millisecondsSinceEpoch}_${AuthService.currentUser?.uid ?? "anon"}';
  }
  
  static String _getActivityTitle(ActivityType type, String postTitle) {
    switch (type) {
      case ActivityType.postCreated:
        return 'New post: "$postTitle"';
      case ActivityType.postUpdated:
        return 'Post updated: "$postTitle"';
      default:
        return 'Activity on "$postTitle"';
    }
  }
  
  static String _getActivityDescription(ActivityType type, PostModel post) {
    switch (type) {
      case ActivityType.postCreated:
        return 'New post by ${post.authorName} in ${post.location ?? "your area"}';
      case ActivityType.postUpdated:
        return 'Post updated by ${post.authorName}';
      default:
        return 'Activity on post by ${post.authorName}';
    }
  }
  
  static String _getEngagementTitle(ActivityType type, String targetTitle) {
    switch (type) {
      case ActivityType.like:
        return 'Someone liked "$targetTitle"';
      case ActivityType.share:
        return 'Someone shared "$targetTitle"';
      default:
        return 'Activity on "$targetTitle"';
    }
  }
  
  static String _getEngagementDescription(ActivityType type, String targetTitle) {
    switch (type) {
      case ActivityType.like:
        return 'Your post received a new like';
      case ActivityType.share:
        return 'Your post was shared with others';
      default:
        return 'New activity on your post';
    }
  }
}

/// Live activity model
class LiveActivity {
  final String id;
  final ActivityType type;
  final String userId;
  final String targetId;
  final String targetType;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  
  const LiveActivity({
    required this.id,
    required this.type,
    required this.userId,
    required this.targetId,
    required this.targetType,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.timestamp,
    this.metadata = const {},
  });
  
  factory LiveActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveActivity(
      id: doc.id,
      type: ActivityType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ActivityType.other,
      ),
      userId: data['userId'] ?? '',
      targetId: data['targetId'] ?? '',
      targetType: data['targetType'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'userId': userId,
      'targetId': targetId,
      'targetType': targetType,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}

/// Activity types
enum ActivityType {
  postCreated,
  postUpdated,
  comment,
  like,
  share,
  userJoined,
  campaignCreated,
  other,
}