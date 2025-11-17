// Stories Service for TALOWA
// Handles story creation, retrieval, and expiration
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../media/media_upload_service.dart';
import '../auth/auth_service.dart';

class StoriesService {
  static final StoriesService _instance = StoriesService._internal();
  factory StoriesService() => _instance;
  StoriesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _storiesCollection = 'stories';
  static const Duration _storyDuration = Duration(hours: 24);

  /// Create a new story
  Future<String> createStory({
    required String mediaUrl,
    required String mediaType, // 'image' or 'video'
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};

      final storyId = _firestore.collection(_storiesCollection).doc().id;
      final now = DateTime.now();
      final expiresAt = now.add(_storyDuration);

      final storyData = {
        'id': storyId,
        'authorId': currentUser.uid,
        'authorName': userData['fullName'] ?? 'Unknown User',
        'authorAvatarUrl': userData['profileImageUrl'],
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'viewsCount': 0,
        'viewers': [], // List of user IDs who viewed
      };

      await _firestore.collection(_storiesCollection).doc(storyId).set(storyData);

      debugPrint('✅ Story created: $storyId');
      return storyId;
    } catch (e) {
      debugPrint('❌ Failed to create story: $e');
      rethrow;
    }
  }

  /// Get active stories (not expired)
  Future<List<Map<String, dynamic>>> getActiveStories() async {
    try {
      final now = Timestamp.now();

      final snapshot = await _firestore
          .collection(_storiesCollection)
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt', descending: false)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Failed to get active stories: $e');
      return [];
    }
  }

  /// Get stories by user
  Future<List<Map<String, dynamic>>> getUserStories(String userId) async {
    try {
      final now = Timestamp.now();

      final snapshot = await _firestore
          .collection(_storiesCollection)
          .where('authorId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt', descending: false)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Failed to get user stories: $e');
      return [];
    }
  }

  /// Mark story as viewed
  Future<void> markStoryAsViewed(String storyId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      await _firestore.collection(_storiesCollection).doc(storyId).update({
        'viewsCount': FieldValue.increment(1),
        'viewers': FieldValue.arrayUnion([currentUser.uid]),
      });

      debugPrint('✅ Story marked as viewed: $storyId');
    } catch (e) {
      debugPrint('❌ Failed to mark story as viewed: $e');
    }
  }

  /// Delete story
  Future<void> deleteStory(String storyId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get story data
      final storyDoc = await _firestore.collection(_storiesCollection).doc(storyId).get();
      if (!storyDoc.exists) {
        throw Exception('Story not found');
      }

      final storyData = storyDoc.data()!;

      // Check if user owns the story
      if (storyData['authorId'] != currentUser.uid) {
        throw Exception('Not authorized to delete this story');
      }

      // Delete media from storage
      final mediaUrl = storyData['mediaUrl'];
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        await MediaUploadService.deleteMedia(mediaUrl);
      }

      // Delete story document
      await _firestore.collection(_storiesCollection).doc(storyId).delete();

      debugPrint('✅ Story deleted: $storyId');
    } catch (e) {
      debugPrint('❌ Failed to delete story: $e');
      rethrow;
    }
  }

  /// Delete expired stories (should be called periodically)
  Future<void> deleteExpiredStories() async {
    try {
      final now = Timestamp.now();

      final snapshot = await _firestore
          .collection(_storiesCollection)
          .where('expiresAt', isLessThan: now)
          .get();

      debugPrint('🗑️ Found ${snapshot.docs.length} expired stories to delete');

      for (final doc in snapshot.docs) {
        try {
          final storyData = doc.data();
          final mediaUrl = storyData['mediaUrl'];

          // Delete media from storage
          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            await MediaUploadService.deleteMedia(mediaUrl);
          }

          // Delete story document
          await doc.reference.delete();

          debugPrint('✅ Deleted expired story: ${doc.id}');
        } catch (e) {
          debugPrint('❌ Failed to delete expired story ${doc.id}: $e');
        }
      }

      debugPrint('✅ Expired stories cleanup completed');
    } catch (e) {
      debugPrint('❌ Failed to delete expired stories: $e');
    }
  }

  /// Get story stream for real-time updates
  Stream<List<Map<String, dynamic>>> getStoriesStream() {
    final now = Timestamp.now();

    return _firestore
        .collection(_storiesCollection)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: false)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
