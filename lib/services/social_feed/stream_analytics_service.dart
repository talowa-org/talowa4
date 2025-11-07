import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for tracking and analyzing live stream performance and engagement
class StreamAnalyticsService {
  static final StreamAnalyticsService _instance = StreamAnalyticsService._internal();
  factory StreamAnalyticsService() => _instance;
  StreamAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Timer> _analyticsTimers = {};

  /// Start tracking analytics for a stream
  void startTracking(String streamId) {
    // Update analytics every 30 seconds
    _analyticsTimers[streamId] = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateStreamAnalytics(streamId),
    );
  }

  /// Stop tracking analytics for a stream
  void stopTracking(String streamId) {
    _analyticsTimers[streamId]?.cancel();
    _analyticsTimers.remove(streamId);
    _updateStreamAnalytics(streamId); // Final update
  }

  /// Get real-time stream analytics
  Future<StreamAnalytics> getStreamAnalytics(String streamId) async {
    final streamDoc = await _firestore.collection('live_streams').doc(streamId).get();
    final data = streamDoc.data();

    if (data == null) {
      throw Exception('Stream not found');
    }

    final chatSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('chat')
        .get();

    final reactionsSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reactions')
        .get();

    final viewersSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .get();

    return StreamAnalytics(
      streamId: streamId,
      totalViews: data['totalViews'] ?? 0,
      currentViewers: data['viewerCount'] ?? 0,
      peakViewers: data['peakViewers'] ?? 0,
      averageWatchTime: data['averageWatchTime'] ?? 0,
      chatMessages: chatSnapshot.docs.length,
      reactions: reactionsSnapshot.docs.length,
      uniqueViewers: viewersSnapshot.docs.length,
      duration: _calculateDuration(data),
      engagementRate: _calculateEngagementRate(data, chatSnapshot.docs.length, reactionsSnapshot.docs.length),
    );
  }

  /// Get stream analytics stream for real-time updates
  Stream<StreamAnalytics> getStreamAnalyticsStream(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .snapshots()
        .asyncMap((snapshot) async {
      final data = snapshot.data();
      if (data == null) {
        throw Exception('Stream not found');
      }

      final chatSnapshot = await _firestore
          .collection('live_streams')
          .doc(streamId)
          .collection('chat')
          .get();

      final reactionsSnapshot = await _firestore
          .collection('live_streams')
          .doc(streamId)
          .collection('reactions')
          .get();

      final viewersSnapshot = await _firestore
          .collection('live_streams')
          .doc(streamId)
          .collection('viewers')
          .get();

      return StreamAnalytics(
        streamId: streamId,
        totalViews: data['totalViews'] ?? 0,
        currentViewers: data['viewerCount'] ?? 0,
        peakViewers: data['peakViewers'] ?? 0,
        averageWatchTime: data['averageWatchTime'] ?? 0,
        chatMessages: chatSnapshot.docs.length,
        reactions: reactionsSnapshot.docs.length,
        uniqueViewers: viewersSnapshot.docs.length,
        duration: _calculateDuration(data),
        engagementRate: _calculateEngagementRate(data, chatSnapshot.docs.length, reactionsSnapshot.docs.length),
      );
    });
  }

  /// Get viewer demographics
  Future<ViewerDemographics> getViewerDemographics(String streamId) async {
    final viewersSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .get();

    final Map<String, int> locations = {};
    final Map<String, int> devices = {};
    int totalWatchTime = 0;

    for (final doc in viewersSnapshot.docs) {
      final data = doc.data();
      
      // Track locations
      final location = data['location'] as String?;
      if (location != null) {
        locations[location] = (locations[location] ?? 0) + 1;
      }

      // Track devices
      final device = data['device'] as String?;
      if (device != null) {
        devices[device] = (devices[device] ?? 0) + 1;
      }

      // Calculate watch time
      final joinedAt = data['joinedAt'] as Timestamp?;
      final leftAt = data['leftAt'] as Timestamp?;
      if (joinedAt != null) {
        final endTime = leftAt?.toDate() ?? DateTime.now();
        totalWatchTime += endTime.difference(joinedAt.toDate()).inSeconds;
      }
    }

    return ViewerDemographics(
      totalViewers: viewersSnapshot.docs.length,
      locations: locations,
      devices: devices,
      averageWatchTime: viewersSnapshot.docs.isEmpty ? 0 : totalWatchTime ~/ viewersSnapshot.docs.length,
    );
  }

  /// Get engagement timeline
  Future<List<EngagementPoint>> getEngagementTimeline(String streamId) async {
    final streamDoc = await _firestore.collection('live_streams').doc(streamId).get();
    final data = streamDoc.data();

    if (data == null) {
      throw Exception('Stream not found');
    }

    final startedAt = (data['startedAt'] as Timestamp?)?.toDate();
    if (startedAt == null) {
      return [];
    }

    // Get chat messages over time
    final chatSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('chat')
        .orderBy('timestamp')
        .get();

    // Get reactions over time
    final reactionsSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reactions')
        .orderBy('timestamp')
        .get();

    // Create timeline with 1-minute intervals
    final List<EngagementPoint> timeline = [];
    final endTime = data['endedAt'] != null
        ? (data['endedAt'] as Timestamp).toDate()
        : DateTime.now();

    var currentTime = startedAt;
    while (currentTime.isBefore(endTime)) {
      final nextTime = currentTime.add(const Duration(minutes: 1));

      final chatCount = chatSnapshot.docs.where((doc) {
        final timestamp = (doc.data()['timestamp'] as Timestamp?)?.toDate();
        return timestamp != null &&
            timestamp.isAfter(currentTime) &&
            timestamp.isBefore(nextTime);
      }).length;

      final reactionCount = reactionsSnapshot.docs.where((doc) {
        final timestamp = (doc.data()['timestamp'] as Timestamp?)?.toDate();
        return timestamp != null &&
            timestamp.isAfter(currentTime) &&
            timestamp.isBefore(nextTime);
      }).length;

      timeline.add(EngagementPoint(
        timestamp: currentTime,
        chatMessages: chatCount,
        reactions: reactionCount,
        engagement: chatCount + reactionCount,
      ));

      currentTime = nextTime;
    }

    return timeline;
  }

  /// Get top chatters
  Future<List<TopChatter>> getTopChatters(String streamId, {int limit = 10}) async {
    final chatSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('chat')
        .get();

    final Map<String, int> userMessageCounts = {};
    final Map<String, String> userNames = {};

    for (final doc in chatSnapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String?;
      final userName = data['userName'] as String?;

      if (userId != null) {
        userMessageCounts[userId] = (userMessageCounts[userId] ?? 0) + 1;
        if (userName != null) {
          userNames[userId] = userName;
        }
      }
    }

    final topChatters = userMessageCounts.entries
        .map((entry) => TopChatter(
              userId: entry.key,
              userName: userNames[entry.key] ?? 'Unknown',
              messageCount: entry.value,
            ))
        .toList()
      ..sort((a, b) => b.messageCount.compareTo(a.messageCount));

    return topChatters.take(limit).toList();
  }

  /// Get reaction breakdown
  Future<Map<String, int>> getReactionBreakdown(String streamId) async {
    final reactionsSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reactions')
        .get();

    final Map<String, int> reactionCounts = {};

    for (final doc in reactionsSnapshot.docs) {
      final data = doc.data();
      final type = data['type'] as String?;
      if (type != null) {
        reactionCounts[type] = (reactionCounts[type] ?? 0) + 1;
      }
    }

    return reactionCounts;
  }

  /// Track viewer retention
  Future<RetentionMetrics> getRetentionMetrics(String streamId) async {
    final viewersSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .get();

    final streamDoc = await _firestore.collection('live_streams').doc(streamId).get();
    final data = streamDoc.data();

    if (data == null) {
      throw Exception('Stream not found');
    }

    final duration = _calculateDuration(data);
    if (duration == 0) {
      return RetentionMetrics(
        averageRetention: 0,
        dropOffRate: 0,
        completionRate: 0,
      );
    }

    int totalWatchTime = 0;
    int completedViewers = 0;

    for (final doc in viewersSnapshot.docs) {
      final viewerData = doc.data();
      final joinedAt = viewerData['joinedAt'] as Timestamp?;
      final leftAt = viewerData['leftAt'] as Timestamp?;

      if (joinedAt != null) {
        final endTime = leftAt?.toDate() ?? DateTime.now();
        final watchTime = endTime.difference(joinedAt.toDate()).inSeconds;
        totalWatchTime += watchTime;

        // Consider viewer completed if they watched > 80% of stream
        if (watchTime >= duration * 0.8) {
          completedViewers++;
        }
      }
    }

    final totalViewers = viewersSnapshot.docs.length;
    final averageWatchTime = totalViewers > 0 ? totalWatchTime ~/ totalViewers : 0;

    return RetentionMetrics(
      averageRetention: duration > 0 ? (averageWatchTime / duration * 100).clamp(0, 100) : 0,
      dropOffRate: totalViewers > 0 ? ((totalViewers - completedViewers) / totalViewers * 100) : 0,
      completionRate: totalViewers > 0 ? (completedViewers / totalViewers * 100) : 0,
    );
  }

  // Private helper methods

  Future<void> _updateStreamAnalytics(String streamId) async {
    try {
      final analytics = await getStreamAnalytics(streamId);
      
      await _firestore.collection('live_streams').doc(streamId).update({
        'analytics': {
          'totalViews': analytics.totalViews,
          'peakViewers': analytics.peakViewers,
          'chatMessages': analytics.chatMessages,
          'reactions': analytics.reactions,
          'engagementRate': analytics.engagementRate,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      print('Error updating stream analytics: $e');
    }
  }

  int _calculateDuration(Map<String, dynamic> data) {
    final startedAt = data['startedAt'] as Timestamp?;
    final endedAt = data['endedAt'] as Timestamp?;

    if (startedAt != null) {
      final endTime = endedAt?.toDate() ?? DateTime.now();
      return endTime.difference(startedAt.toDate()).inSeconds;
    }
    return 0;
  }

  double _calculateEngagementRate(Map<String, dynamic> data, int chatMessages, int reactions) {
    final totalViews = data['totalViews'] ?? 0;
    if (totalViews == 0) return 0.0;

    final totalEngagement = chatMessages + reactions;
    return (totalEngagement / totalViews * 100).clamp(0, 100);
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _analyticsTimers.values) {
      timer.cancel();
    }
    _analyticsTimers.clear();
  }
}

// Models
class StreamAnalytics {
  final String streamId;
  final int totalViews;
  final int currentViewers;
  final int peakViewers;
  final int averageWatchTime;
  final int chatMessages;
  final int reactions;
  final int uniqueViewers;
  final int duration;
  final double engagementRate;

  StreamAnalytics({
    required this.streamId,
    required this.totalViews,
    required this.currentViewers,
    required this.peakViewers,
    required this.averageWatchTime,
    required this.chatMessages,
    required this.reactions,
    required this.uniqueViewers,
    required this.duration,
    required this.engagementRate,
  });
}

class ViewerDemographics {
  final int totalViewers;
  final Map<String, int> locations;
  final Map<String, int> devices;
  final int averageWatchTime;

  ViewerDemographics({
    required this.totalViewers,
    required this.locations,
    required this.devices,
    required this.averageWatchTime,
  });
}

class EngagementPoint {
  final DateTime timestamp;
  final int chatMessages;
  final int reactions;
  final int engagement;

  EngagementPoint({
    required this.timestamp,
    required this.chatMessages,
    required this.reactions,
    required this.engagement,
  });
}

class TopChatter {
  final String userId;
  final String userName;
  final int messageCount;

  TopChatter({
    required this.userId,
    required this.userName,
    required this.messageCount,
  });
}

class RetentionMetrics {
  final double averageRetention;
  final double dropOffRate;
  final double completionRate;

  RetentionMetrics({
    required this.averageRetention,
    required this.dropOffRate,
    required this.completionRate,
  });
}
