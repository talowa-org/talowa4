// Engagement Service for TALOWA Social Feed System
// Handles user interactions like likes, comments, shares, and notifications

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class EngagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection references
  static final CollectionReference _postsCollection = _firestore.collection('posts');
  static final CollectionReference _usersCollection = _firestore.collection('users');
  static final CollectionReference _notificationsCollection = _firestore.collection('notifications');

  /// Get engagement statistics for a post
  static Future<Map<String, dynamic>> getPostEngagementStats(String postId) async {
    try {
      debugPrint('EngagementService: Getting engagement stats for post $postId');

      final engagementSnapshot = await _postsCollection
          .doc(postId)
          .collection('engagement')
          .get();

      int likesCount = 0;
      int sharesCount = 0;
      int viewsCount = 0;
      final List<String> likedBy = [];
      final List<String> sharedBy = [];

      for (final doc in engagementSnapshot.docs) {
        final data = doc.data();
        
        if (data['liked'] == true) {
          likesCount++;
          likedBy.add(doc.id);
        }
        
        if (data['shared'] == true) {
          sharesCount++;
          sharedBy.add(doc.id);
        }
        
        if (data['viewedAt'] != null) {
          viewsCount++;
        }
      }

      return {
        'likesCount': likesCount,
        'sharesCount': sharesCount,
        'viewsCount': viewsCount,
        'likedBy': likedBy,
        'sharedBy': sharedBy,
      };
      
    } catch (e) {
      debugPrint('EngagementService: Error getting engagement stats: $e');
      return {
        'likesCount': 0,
        'sharesCount': 0,
        'viewsCount': 0,
        'likedBy': <String>[],
        'sharedBy': <String>[],
      };
    }
  }

  /// Get users who liked a post
  static Future<List<Map<String, dynamic>>> getPostLikers(String postId, {
    int limit = 20,
  }) async {
    try {
      debugPrint('EngagementService: Getting likers for post $postId');

      final engagementSnapshot = await _postsCollection
          .doc(postId)
          .collection('engagement')
          .where('liked', isEqualTo: true)
          .orderBy('likedAt', descending: true)
          .limit(limit)
          .get();

      final likers = <Map<String, dynamic>>[];
      
      for (final doc in engagementSnapshot.docs) {
        try {
          final userId = doc.id;
          final userDoc = await _usersCollection.doc(userId).get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            likers.add({
              'userId': userId,
              'name': userData['fullName'] ?? 'Unknown User',
              'role': userData['role'],
              'avatarUrl': userData['avatarUrl'],
              'likedAt': doc.data()['likedAt'],
            });
          }
        } catch (e) {
          debugPrint('EngagementService: Error getting liker data: $e');
        }
      }

      return likers;
      
    } catch (e) {
      debugPrint('EngagementService: Error getting post likers: $e');
      return [];
    }
  }

  /// Record post view
  static Future<void> recordPostView(String postId, String userId) async {
    try {
      debugPrint('EngagementService: Recording view for post $postId by user $userId');

      final engagementRef = _postsCollection
          .doc(postId)
          .collection('engagement')
          .doc(userId);

      await engagementRef.set({
        'userId': userId,
        'postId': postId,
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update post views count
      await _postsCollection.doc(postId).update({
        'viewsCount': FieldValue.increment(1),
      });

      debugPrint('EngagementService: Post view recorded successfully');
      
    } catch (e) {
      debugPrint('EngagementService: Error recording post view: $e');
    }
  }

  /// Get user's engagement history
  static Future<List<Map<String, dynamic>>> getUserEngagementHistory(
    String userId, {
    int limit = 50,
  }) async {
    try {
      debugPrint('EngagementService: Getting engagement history for user $userId');

      // This is a simplified implementation
      // In production, consider using a separate collection for user activity
      final engagementHistory = <Map<String, dynamic>>[];

      // Get recent posts the user has engaged with
      final recentPosts = await _postsCollection
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      for (final postDoc in recentPosts.docs) {
        try {
          final engagementDoc = await postDoc.reference
              .collection('engagement')
              .doc(userId)
              .get();

          if (engagementDoc.exists) {
            final engagementData = engagementDoc.data()!;
            final postData = postDoc.data() as Map<String, dynamic>;

            engagementHistory.add({
              'postId': postDoc.id,
              'postContent': postData['content'],
              'postAuthor': postData['authorName'],
              'liked': engagementData['liked'] ?? false,
              'shared': engagementData['shared'] ?? false,
              'likedAt': engagementData['likedAt'],
              'sharedAt': engagementData['sharedAt'],
              'viewedAt': engagementData['viewedAt'],
            });
          }
        } catch (e) {
          debugPrint('EngagementService: Error processing engagement history: $e');
        }
      }

      // Sort by most recent engagement
      engagementHistory.sort((a, b) {
        final aTime = a['likedAt'] ?? a['sharedAt'] ?? a['viewedAt'];
        final bTime = b['likedAt'] ?? b['sharedAt'] ?? b['viewedAt'];
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return (bTime as Timestamp).compareTo(aTime as Timestamp);
      });

      return engagementHistory.take(limit).toList();
      
    } catch (e) {
      debugPrint('EngagementService: Error getting user engagement history: $e');
      return [];
    }
  }

  /// Send engagement notification with batching
  static Future<void> sendEngagementNotification({
    required String recipientId,
    required String actorId,
    required String postId,
    required EngagementType type,
    String? commentId,
  }) async {
    try {
      debugPrint('EngagementService: Sending $type notification to $recipientId');

      // Don't send notification to self
      if (recipientId == actorId) return;

      // Check if user has notifications enabled
      final recipientDoc = await _usersCollection.doc(recipientId).get();
      if (!recipientDoc.exists) return;
      
      final recipientData = recipientDoc.data() as Map<String, dynamic>;
      final notificationSettings = recipientData['notificationSettings'] as Map<String, dynamic>?;
      
      // Check if this type of notification is enabled
      if (notificationSettings != null) {
        final engagementNotifications = notificationSettings['engagement'] as bool? ?? true;
        if (!engagementNotifications) return;
      }

      // Get actor information
      final actorDoc = await _usersCollection.doc(actorId).get();
      if (!actorDoc.exists) return;

      final actorData = actorDoc.data() as Map<String, dynamic>;
      final actorName = actorData['fullName'] ?? 'Someone';

      // Get post information
      final postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) return;

      final postData = postDoc.data() as Map<String, dynamic>;
      final postContent = postData['content'] as String;
      final shortContent = postContent.length > 50 
          ? '${postContent.substring(0, 50)}...'
          : postContent;

      // Create notification message with localization support
      String message;
      String notificationType;
      
      switch (type) {
        case EngagementType.like:
          message = '$actorName ने आपकी पोस्ट को पसंद किया: "$shortContent"';
          notificationType = 'post_liked';
          break;
        case EngagementType.comment:
          message = '$actorName ने आपकी पोस्ट पर टिप्पणी की: "$shortContent"';
          notificationType = 'post_commented';
          break;
        case EngagementType.share:
          message = '$actorName ने आपकी पोस्ट को साझा किया: "$shortContent"';
          notificationType = 'post_shared';
          break;
        case EngagementType.reply:
          message = '$actorName ने आपकी टिप्पणी का जवाब दिया';
          notificationType = 'comment_replied';
          break;
      }

      // Check for duplicate notifications (avoid spam)
      final recentNotifications = await _notificationsCollection
          .where('recipientId', isEqualTo: recipientId)
          .where('actorId', isEqualTo: actorId)
          .where('postId', isEqualTo: postId)
          .where('type', isEqualTo: notificationType)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(minutes: 5))))
          .get();

      if (recentNotifications.docs.isNotEmpty) {
        debugPrint('EngagementService: Duplicate notification prevented');
        return;
      }

      // Create notification document
      await _notificationsCollection.add({
        'recipientId': recipientId,
        'actorId': actorId,
        'actorName': actorName,
        'actorAvatarUrl': actorData['avatarUrl'],
        'type': notificationType,
        'message': message,
        'postId': postId,
        'commentId': commentId,
        'isRead': false,
        'priority': _getNotificationPriority(type),
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('EngagementService: Notification sent successfully');
      
    } catch (e) {
      debugPrint('EngagementService: Error sending notification: $e');
    }
  }

  /// Get real-time engagement updates stream
  static Stream<Map<String, dynamic>> getEngagementStream(String postId) {
    try {
      debugPrint('EngagementService: Setting up engagement stream for post $postId');
      
      return _postsCollection
          .doc(postId)
          .collection('engagement')
          .snapshots()
          .map((snapshot) {
        int likesCount = 0;
        int sharesCount = 0;
        final List<String> likedBy = [];
        final List<String> sharedBy = [];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          
          if (data['liked'] == true) {
            likesCount++;
            likedBy.add(doc.id);
          }
          
          if (data['shared'] == true) {
            sharesCount++;
            sharedBy.add(doc.id);
          }
        }

        return {
          'likesCount': likesCount,
          'sharesCount': sharesCount,
          'likedBy': likedBy,
          'sharedBy': sharedBy,
          'lastUpdated': DateTime.now().toIso8601String(),
        };
      });
      
    } catch (e) {
      debugPrint('EngagementService: Error setting up engagement stream: $e');
      return Stream.error(e);
    }
  }

  /// Batch engagement operations for better performance
  static Future<void> batchEngagementOperations(List<EngagementOperation> operations) async {
    try {
      debugPrint('EngagementService: Performing ${operations.length} batch operations');
      
      final batch = _firestore.batch();
      
      for (final operation in operations) {
        final postRef = _postsCollection.doc(operation.postId);
        final engagementRef = postRef.collection('engagement').doc(operation.userId);
        
        switch (operation.type) {
          case EngagementOperationType.like:
            batch.update(postRef, {'likesCount': FieldValue.increment(1)});
            batch.set(engagementRef, {
              'userId': operation.userId,
              'postId': operation.postId,
              'liked': true,
              'likedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            break;
            
          case EngagementOperationType.unlike:
            batch.update(postRef, {'likesCount': FieldValue.increment(-1)});
            batch.update(engagementRef, {
              'liked': false,
              'likedAt': null,
            });
            break;
            
          case EngagementOperationType.share:
            batch.update(postRef, {'sharesCount': FieldValue.increment(1)});
            batch.set(engagementRef, {
              'userId': operation.userId,
              'postId': operation.postId,
              'shared': true,
              'sharedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            break;
        }
      }
      
      await batch.commit();
      debugPrint('EngagementService: Batch operations completed');
      
    } catch (e) {
      debugPrint('EngagementService: Error in batch operations: $e');
      rethrow;
    }
  }

  /// Get engagement leaderboard
  static Future<List<Map<String, dynamic>>> getEngagementLeaderboard({
    Duration timeWindow = const Duration(days: 30),
    int limit = 10,
  }) async {
    try {
      debugPrint('EngagementService: Getting engagement leaderboard');

      final cutoffTime = DateTime.now().subtract(timeWindow);
      
      // Get all posts in time window
      final postsSnapshot = await _postsCollection
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .get();

      final userEngagement = <String, Map<String, dynamic>>{};

      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final authorId = postData['authorId'] as String;
        
        if (!userEngagement.containsKey(authorId)) {
          userEngagement[authorId] = {
            'userId': authorId,
            'authorName': postData['authorName'],
            'totalPosts': 0,
            'totalLikes': 0,
            'totalComments': 0,
            'totalShares': 0,
            'engagementScore': 0.0,
          };
        }

        final userData = userEngagement[authorId]!;
        userData['totalPosts'] = (userData['totalPosts'] as int) + 1;
        userData['totalLikes'] = (userData['totalLikes'] as int) + (postData['likesCount'] as int? ?? 0);
        userData['totalComments'] = (userData['totalComments'] as int) + (postData['commentsCount'] as int? ?? 0);
        userData['totalShares'] = (userData['totalShares'] as int) + (postData['sharesCount'] as int? ?? 0);
        
        // Calculate engagement score (weighted)
        final score = (userData['totalLikes'] as int) * 1.0 + 
                     (userData['totalComments'] as int) * 2.0 + 
                     (userData['totalShares'] as int) * 3.0;
        userData['engagementScore'] = score;
      }

      // Sort by engagement score and return top users
      final leaderboard = userEngagement.values.toList()
        ..sort((a, b) => (b['engagementScore'] as double).compareTo(a['engagementScore'] as double));

      return leaderboard.take(limit).toList();
      
    } catch (e) {
      debugPrint('EngagementService: Error getting engagement leaderboard: $e');
      return [];
    }
  }

  // Private helper methods
  
  static String _getNotificationPriority(EngagementType type) {
    switch (type) {
      case EngagementType.like:
        return 'low';
      case EngagementType.comment:
      case EngagementType.reply:
        return 'medium';
      case EngagementType.share:
        return 'high';
    }
  }

  /// Get engagement analytics for a user's posts
  static Future<Map<String, dynamic>> getUserPostAnalytics(String userId) async {
    try {
      debugPrint('EngagementService: Getting post analytics for user $userId');

      // Get user's posts
      final userPostsSnapshot = await _postsCollection
          .where('authorId', isEqualTo: userId)
          .get();

      int totalPosts = userPostsSnapshot.docs.length;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;
      int totalViews = 0;

      for (final postDoc in userPostsSnapshot.docs) {
        final postData = postDoc.data() as Map<String, dynamic>;
        totalLikes += (postData['likesCount'] as int? ?? 0);
        totalComments += (postData['commentsCount'] as int? ?? 0);
        totalShares += (postData['sharesCount'] as int? ?? 0);
        totalViews += (postData['viewsCount'] as int? ?? 0);
      }

      final avgEngagement = totalPosts > 0 
          ? (totalLikes + totalComments + totalShares) / totalPosts
          : 0.0;

      return {
        'totalPosts': totalPosts,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'totalViews': totalViews,
        'averageEngagement': avgEngagement,
        'engagementRate': totalViews > 0 
            ? (totalLikes + totalComments + totalShares) / totalViews
            : 0.0,
      };
      
    } catch (e) {
      debugPrint('EngagementService: Error getting user analytics: $e');
      return {
        'totalPosts': 0,
        'totalLikes': 0,
        'totalComments': 0,
        'totalShares': 0,
        'totalViews': 0,
        'averageEngagement': 0.0,
        'engagementRate': 0.0,
      };
    }
  }

  /// Get trending posts based on engagement
  static Future<List<String>> getTrendingPosts({
    int limit = 10,
    Duration timeWindow = const Duration(days: 7),
  }) async {
    try {
      debugPrint('EngagementService: Getting trending posts');

      final cutoffTime = DateTime.now().subtract(timeWindow);
      
      final recentPostsSnapshot = await _postsCollection
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .where('isHidden', isEqualTo: false)
          .get();

      final postScores = <String, double>{};

      for (final postDoc in recentPostsSnapshot.docs) {
        final postData = postDoc.data() as Map<String, dynamic>;
        
        final likes = (postData['likesCount'] as int? ?? 0);
        final comments = (postData['commentsCount'] as int? ?? 0);
        final shares = (postData['sharesCount'] as int? ?? 0);
        final views = (postData['viewsCount'] as int? ?? 0);
        
        // Calculate engagement score (weighted)
        final score = (likes * 1.0) + (comments * 2.0) + (shares * 3.0) + (views * 0.1);
        
        // Apply time decay (newer posts get slight boost)
        final createdAt = (postData['createdAt'] as Timestamp).toDate();
        final hoursSinceCreation = DateTime.now().difference(createdAt).inHours;
        final timeDecay = 1.0 / (1.0 + (hoursSinceCreation / 24.0));
        
        postScores[postDoc.id] = score * timeDecay;
      }

      // Sort by score and return top posts
      final sortedPosts = postScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final trendingPostIds = sortedPosts
          .take(limit)
          .map((entry) => entry.key)
          .toList();

      debugPrint('EngagementService: Found ${trendingPostIds.length} trending posts');
      return trendingPostIds;
      
    } catch (e) {
      debugPrint('EngagementService: Error getting trending posts: $e');
      return [];
    }
  }

  /// Batch update engagement metrics (for maintenance)
  static Future<void> updateEngagementMetrics() async {
    try {
      debugPrint('EngagementService: Updating engagement metrics');

      final postsSnapshot = await _postsCollection.limit(100).get();
      
      for (final postDoc in postsSnapshot.docs) {
        try {
          final stats = await getPostEngagementStats(postDoc.id);
          
          await postDoc.reference.update({
            'likesCount': stats['likesCount'],
            'sharesCount': stats['sharesCount'],
            'viewsCount': stats['viewsCount'],
          });
        } catch (e) {
          debugPrint('EngagementService: Error updating metrics for post ${postDoc.id}: $e');
        }
      }

      debugPrint('EngagementService: Engagement metrics updated');
      
    } catch (e) {
      debugPrint('EngagementService: Error updating engagement metrics: $e');
    }
  }
}

/// Engagement type enumeration
enum EngagementType {
  like,
  comment,
  share,
  reply,
}

/// Engagement operation type for batch operations
enum EngagementOperationType {
  like,
  unlike,
  share,
}

/// Engagement operation for batch processing
class EngagementOperation {
  final String postId;
  final String userId;
  final EngagementOperationType type;

  const EngagementOperation({
    required this.postId,
    required this.userId,
    required this.type,
  });
}