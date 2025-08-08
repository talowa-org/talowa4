// Real-time Engagement Service for TALOWA Social Feed
// Implements Task 15: Add real-time engagement features

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/index.dart';

class RealTimeEngagementService {
  static final RealTimeEngagementService _instance = RealTimeEngagementService._internal();
  factory RealTimeEngagementService() => _instance;
  RealTimeEngagementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _engagementListeners = {};
  final Map<String, StreamSubscription> _commentListeners = {};
  final Map<String, StreamSubscription> _typingListeners = {};
  final Map<String, StreamSubscription> _presenceListeners = {};

  // Stream controllers for real-time updates
  final StreamController<EngagementUpdate> _engagementController = 
      StreamController<EngagementUpdate>.broadcast();
  final StreamController<CommentUpdate> _commentController = 
      StreamController<CommentUpdate>.broadcast();
  final StreamController<TypingIndicator> _typingController = 
      StreamController<TypingIndicator>.broadcast();
  final StreamController<UserPresence> _presenceController = 
      StreamController<UserPresence>.broadcast();

  // Public streams
  Stream<EngagementUpdate> get engagementUpdates => _engagementController.stream;
  Stream<CommentUpdate> get commentUpdates => _commentController.stream;
  Stream<TypingIndicator> get typingIndicators => _typingController.stream;
  Stream<UserPresence> get userPresence => _presenceController.stream;

  // Current user tracking
  String? _currentUserId;
  final Map<String, Timer> _typingTimers = {};
  final Map<String, DateTime> _lastActivity = {};

  void initialize(String userId) {
    _currentUserId = userId;
    _startPresenceTracking();
  }

  // Real-time engagement tracking
  void startEngagementTracking(String postId) {
    if (_engagementListeners.containsKey(postId)) return;

    _engagementListeners[postId] = _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final update = EngagementUpdate(
          postId: postId,
          likesCount: data['likesCount'] ?? 0,
          commentsCount: data['commentsCount'] ?? 0,
          sharesCount: data['sharesCount'] ?? 0,
          viewsCount: data['viewsCount'] ?? 0,
          timestamp: DateTime.now(),
        );
        _engagementController.add(update);
      }
    });
  }

  void stopEngagementTracking(String postId) {
    _engagementListeners[postId]?.cancel();
    _engagementListeners.remove(postId);
  }

  // Real-time comment updates
  void startCommentTracking(String postId) {
    if (_commentListeners.containsKey(postId)) return;

    _commentListeners[postId] = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final comment = CommentModel.fromFirestore(change.doc);
        
        CommentUpdateType updateType;
        switch (change.type) {
          case DocumentChangeType.added:
            updateType = CommentUpdateType.added;
            break;
          case DocumentChangeType.modified:
            updateType = CommentUpdateType.modified;
            break;
          case DocumentChangeType.removed:
            updateType = CommentUpdateType.removed;
            break;
        }

        final update = CommentUpdate(
          postId: postId,
          comment: comment,
          updateType: updateType,
          timestamp: DateTime.now(),
        );
        _commentController.add(update);
      }
    });
  }

  void stopCommentTracking(String postId) {
    _commentListeners[postId]?.cancel();
    _commentListeners.remove(postId);
  }

  // Typing indicators
  void startTypingIndicator(String postId) {
    if (_currentUserId == null) return;

    // Cancel existing timer
    _typingTimers[postId]?.cancel();

    // Update typing status
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('typing')
        .doc(_currentUserId)
        .set({
      'userId': _currentUserId,
      'isTyping': true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Set timer to stop typing after 3 seconds of inactivity
    _typingTimers[postId] = Timer(const Duration(seconds: 3), () {
      stopTypingIndicator(postId);
    });
  }

  void stopTypingIndicator(String postId) {
    if (_currentUserId == null) return;

    _typingTimers[postId]?.cancel();
    _typingTimers.remove(postId);

    _firestore
        .collection('posts')
        .doc(postId)
        .collection('typing')
        .doc(_currentUserId)
        .delete();
  }

  void startTypingTracking(String postId) {
    if (_typingListeners.containsKey(postId)) return;

    _typingListeners[postId] = _firestore
        .collection('posts')
        .doc(postId)
        .collection('typing')
        .where('isTyping', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final typingUsers = <String>[];
      for (final doc in snapshot.docs) {
        final userId = doc.data()['userId'] as String;
        if (userId != _currentUserId) {
          typingUsers.add(userId);
        }
      }

      final indicator = TypingIndicator(
        postId: postId,
        typingUsers: typingUsers,
        timestamp: DateTime.now(),
      );
      _typingController.add(indicator);
    });
  }

  void stopTypingTracking(String postId) {
    _typingListeners[postId]?.cancel();
    _typingListeners.remove(postId);
  }

  // User presence tracking
  void _startPresenceTracking() {
    if (_currentUserId == null) return;

    // Update user presence every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _updatePresence();
    });

    // Initial presence update
    _updatePresence();
  }

  void _updatePresence() {
    if (_currentUserId == null) return;

    _firestore
        .collection('user_presence')
        .doc(_currentUserId)
        .set({
      'userId': _currentUserId,
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'activity': 'social_feed',
    }, SetOptions(merge: true));
  }

  void startPresenceTracking(List<String> userIds) {
    for (final userId in userIds) {
      if (_presenceListeners.containsKey(userId)) continue;

      _presenceListeners[userId] = _firestore
          .collection('user_presence')
          .doc(userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data()!;
          final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();
          final isOnline = data['isOnline'] as bool? ?? false;
          
          // Consider user online if last seen within 2 minutes
          final isRecentlyActive = lastSeen != null && 
              DateTime.now().difference(lastSeen).inMinutes < 2;

          final presence = UserPresence(
            userId: userId,
            isOnline: isOnline && isRecentlyActive,
            lastSeen: lastSeen,
            activity: data['activity'] as String?,
            timestamp: DateTime.now(),
          );
          _presenceController.add(presence);
        }
      });
    }
  }

  void stopPresenceTracking(String userId) {
    _presenceListeners[userId]?.cancel();
    _presenceListeners.remove(userId);
  }

  // Engagement actions with real-time feedback
  Future<void> likePost(String postId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection('posts').doc(postId);
        final likeRef = postRef.collection('likes').doc(_currentUserId);
        
        final postDoc = await transaction.get(postRef);
        final likeDoc = await transaction.get(likeRef);
        
        if (!postDoc.exists) return;
        
        final currentLikes = postDoc.data()!['likesCount'] as int? ?? 0;
        
        if (likeDoc.exists) {
          // Unlike
          transaction.delete(likeRef);
          transaction.update(postRef, {
            'likesCount': currentLikes - 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Like
          transaction.set(likeRef, {
            'userId': _currentUserId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {
            'likesCount': currentLikes + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error liking post: $e');
      rethrow;
    }
  }

  Future<void> sharePost(String postId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection('posts').doc(postId);
        final shareRef = postRef.collection('shares').doc(_currentUserId);
        
        final postDoc = await transaction.get(postRef);
        final shareDoc = await transaction.get(shareRef);
        
        if (!postDoc.exists) return;
        
        final currentShares = postDoc.data()!['sharesCount'] as int? ?? 0;
        
        if (!shareDoc.exists) {
          // Share
          transaction.set(shareRef, {
            'userId': _currentUserId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {
            'sharesCount': currentShares + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error sharing post: $e');
      rethrow;
    }
  }

  Future<void> incrementViewCount(String postId) async {
    if (_currentUserId == null) return;

    try {
      // Only increment if user hasn't viewed recently (within 1 hour)
      final viewKey = '${postId}_$_currentUserId';
      final lastView = _lastActivity[viewKey];
      
      if (lastView != null && 
          DateTime.now().difference(lastView).inHours < 1) {
        return;
      }

      _lastActivity[viewKey] = DateTime.now();

      await _firestore.collection('posts').doc(postId).update({
        'viewsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
    }
  }

  // Cleanup
  void dispose() {
    // Cancel all listeners
    for (final listener in _engagementListeners.values) {
      listener.cancel();
    }
    for (final listener in _commentListeners.values) {
      listener.cancel();
    }
    for (final listener in _typingListeners.values) {
      listener.cancel();
    }
    for (final listener in _presenceListeners.values) {
      listener.cancel();
    }

    // Cancel all timers
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }

    // Clear maps
    _engagementListeners.clear();
    _commentListeners.clear();
    _typingListeners.clear();
    _presenceListeners.clear();
    _typingTimers.clear();
    _lastActivity.clear();

    // Close stream controllers
    _engagementController.close();
    _commentController.close();
    _typingController.close();
    _presenceController.close();

    // Update presence to offline
    if (_currentUserId != null) {
      _firestore.collection('user_presence').doc(_currentUserId).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }
}

// Data models for real-time updates
class EngagementUpdate {
  final String postId;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final DateTime timestamp;

  EngagementUpdate({
    required this.postId,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.viewsCount,
    required this.timestamp,
  });
}

class CommentUpdate {
  final String postId;
  final CommentModel comment;
  final CommentUpdateType updateType;
  final DateTime timestamp;

  CommentUpdate({
    required this.postId,
    required this.comment,
    required this.updateType,
    required this.timestamp,
  });
}

enum CommentUpdateType { added, modified, removed }

class TypingIndicator {
  final String postId;
  final List<String> typingUsers;
  final DateTime timestamp;

  TypingIndicator({
    required this.postId,
    required this.typingUsers,
    required this.timestamp,
  });
}

class UserPresence {
  final String userId;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? activity;
  final DateTime timestamp;

  UserPresence({
    required this.userId,
    required this.isOnline,
    this.lastSeen,
    this.activity,
    required this.timestamp,
  });
}