import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for moderating live streams, managing viewers, and enforcing community guidelines
class StreamModerationService {
  static final StreamModerationService _instance = StreamModerationService._internal();
  factory StreamModerationService() => _instance;
  StreamModerationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ban a viewer from the stream
  Future<void> banViewer({
    required String streamId,
    required String viewerId,
    required String moderatorId,
    String? reason,
    Duration? duration,
  }) async {
    final banData = {
      'viewerId': viewerId,
      'moderatorId': moderatorId,
      'reason': reason,
      'bannedAt': FieldValue.serverTimestamp(),
      'expiresAt': duration != null
          ? Timestamp.fromDate(DateTime.now().add(duration))
          : null,
      'isPermanent': duration == null,
    };

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('banned_viewers')
        .doc(viewerId)
        .set(banData);

    // Remove viewer from active viewers
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .doc(viewerId)
        .update({
      'isActive': false,
      'isBanned': true,
      'bannedAt': FieldValue.serverTimestamp(),
    });

    // Decrement viewer count
    await _firestore.collection('live_streams').doc(streamId).update({
      'viewerCount': FieldValue.increment(-1),
    });
  }

  /// Unban a viewer
  Future<void> unbanViewer({
    required String streamId,
    required String viewerId,
    required String moderatorId,
  }) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('banned_viewers')
        .doc(viewerId)
        .update({
      'unbannedAt': FieldValue.serverTimestamp(),
      'unbannedBy': moderatorId,
      'isActive': false,
    });
  }

  /// Check if viewer is banned
  Future<bool> isViewerBanned(String streamId, String viewerId) async {
    final banDoc = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('banned_viewers')
        .doc(viewerId)
        .get();

    if (!banDoc.exists) return false;

    final data = banDoc.data()!;
    final isPermanent = data['isPermanent'] ?? false;
    
    if (isPermanent) return true;

    final expiresAt = data['expiresAt'] as Timestamp?;
    if (expiresAt != null) {
      return DateTime.now().isBefore(expiresAt.toDate());
    }

    return false;
  }

  /// Delete a chat message
  Future<void> deleteChatMessage({
    required String streamId,
    required String messageId,
    required String moderatorId,
    String? reason,
  }) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('chat')
        .doc(messageId)
        .update({
      'isDeleted': true,
      'deletedBy': moderatorId,
      'deletedAt': FieldValue.serverTimestamp(),
      'deleteReason': reason,
    });
  }

  /// Mute a viewer (prevent them from sending chat messages)
  Future<void> muteViewer({
    required String streamId,
    required String viewerId,
    required String moderatorId,
    Duration? duration,
    String? reason,
  }) async {
    final muteData = {
      'viewerId': viewerId,
      'moderatorId': moderatorId,
      'reason': reason,
      'mutedAt': FieldValue.serverTimestamp(),
      'expiresAt': duration != null
          ? Timestamp.fromDate(DateTime.now().add(duration))
          : null,
      'isPermanent': duration == null,
    };

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('muted_viewers')
        .doc(viewerId)
        .set(muteData);
  }

  /// Unmute a viewer
  Future<void> unmuteViewer({
    required String streamId,
    required String viewerId,
    required String moderatorId,
  }) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('muted_viewers')
        .doc(viewerId)
        .delete();
  }

  /// Check if viewer is muted
  Future<bool> isViewerMuted(String streamId, String viewerId) async {
    final muteDoc = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('muted_viewers')
        .doc(viewerId)
        .get();

    if (!muteDoc.exists) return false;

    final data = muteDoc.data()!;
    final isPermanent = data['isPermanent'] ?? false;
    
    if (isPermanent) return true;

    final expiresAt = data['expiresAt'] as Timestamp?;
    if (expiresAt != null) {
      return DateTime.now().isBefore(expiresAt.toDate());
    }

    return false;
  }

  /// Add a moderator to the stream
  Future<void> addModerator({
    required String streamId,
    required String userId,
    required String addedBy,
  }) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'moderators': FieldValue.arrayUnion([userId]),
    });

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('moderator_actions')
        .add({
      'action': 'moderator_added',
      'userId': userId,
      'performedBy': addedBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a moderator from the stream
  Future<void> removeModerator({
    required String streamId,
    required String userId,
    required String removedBy,
  }) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'moderators': FieldValue.arrayRemove([userId]),
    });

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('moderator_actions')
        .add({
      'action': 'moderator_removed',
      'userId': userId,
      'performedBy': removedBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Check if user is a moderator
  Future<bool> isModerator(String streamId, String userId) async {
    final streamDoc = await _firestore.collection('live_streams').doc(streamId).get();
    final data = streamDoc.data();
    
    if (data == null) return false;

    final moderators = List<String>.from(data['moderators'] ?? []);
    return moderators.contains(userId);
  }

  /// Enable slow mode (limit message frequency)
  Future<void> enableSlowMode({
    required String streamId,
    required int intervalSeconds,
    required String moderatorId,
  }) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'slowModeEnabled': true,
      'slowModeInterval': intervalSeconds,
    });

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('moderator_actions')
        .add({
      'action': 'slow_mode_enabled',
      'intervalSeconds': intervalSeconds,
      'performedBy': moderatorId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Disable slow mode
  Future<void> disableSlowMode({
    required String streamId,
    required String moderatorId,
  }) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'slowModeEnabled': false,
      'slowModeInterval': 0,
    });

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('moderator_actions')
        .add({
      'action': 'slow_mode_disabled',
      'performedBy': moderatorId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Enable followers-only mode
  Future<void> enableFollowersOnlyMode({
    required String streamId,
    required String moderatorId,
  }) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'followersOnlyMode': true,
    });

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('moderator_actions')
        .add({
      'action': 'followers_only_enabled',
      'performedBy': moderatorId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Disable followers-only mode
  Future<void> disableFollowersOnlyMode({
    required String streamId,
    required String moderatorId,
  }) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'followersOnlyMode': false,
    });

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('moderator_actions')
        .add({
      'action': 'followers_only_disabled',
      'performedBy': moderatorId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get moderation actions log
  Stream<List<ModerationAction>> getModerationActionsStream(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('moderator_actions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ModerationAction(
          id: doc.id,
          action: data['action'] ?? '',
          performedBy: data['performedBy'] ?? '',
          userId: data['userId'],
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          details: data,
        );
      }).toList();
    });
  }

  /// Report a viewer
  Future<void> reportViewer({
    required String streamId,
    required String viewerId,
    required String reportedBy,
    required String reason,
    String? details,
  }) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reports')
        .add({
      'viewerId': viewerId,
      'reportedBy': reportedBy,
      'reason': reason,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// Get banned viewers list
  Future<List<BannedViewer>> getBannedViewers(String streamId) async {
    final snapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('banned_viewers')
        .where('isPermanent', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return BannedViewer(
        viewerId: data['viewerId'] ?? '',
        moderatorId: data['moderatorId'] ?? '',
        reason: data['reason'],
        bannedAt: (data['bannedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isPermanent: data['isPermanent'] ?? false,
      );
    }).toList();
  }

  /// Clear chat (delete all messages)
  Future<void> clearChat({
    required String streamId,
    required String moderatorId,
  }) async {
    final chatSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('chat')
        .get();

    final batch = _firestore.batch();
    for (final doc in chatSnapshot.docs) {
      batch.update(doc.reference, {
        'isDeleted': true,
        'deletedBy': moderatorId,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('moderator_actions')
        .add({
      'action': 'chat_cleared',
      'performedBy': moderatorId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

// Models
class ModerationAction {
  final String id;
  final String action;
  final String performedBy;
  final String? userId;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  ModerationAction({
    required this.id,
    required this.action,
    required this.performedBy,
    this.userId,
    required this.timestamp,
    required this.details,
  });
}

class BannedViewer {
  final String viewerId;
  final String moderatorId;
  final String? reason;
  final DateTime bannedAt;
  final bool isPermanent;

  BannedViewer({
    required this.viewerId,
    required this.moderatorId,
    this.reason,
    required this.bannedAt,
    required this.isPermanent,
  });
}
