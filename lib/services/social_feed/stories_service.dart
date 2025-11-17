// Stories Service for TALOWA
// Manages Instagram-style stories

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/story_model.dart';
import '../auth_service.dart';

class StoriesService {
  static final StoriesService _instance = StoriesService._internal();
  factory StoriesService() => _instance;
  StoriesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _storiesCollection = 'stories';

  /// Get all active stories grouped by user
  Future<List<UserStoriesGroup>> getActiveStories() async {
    try {
      final currentUserId = AuthService.currentUser?.uid;
      
      // Get stories that haven't expired
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(_storiesCollection)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt', descending: false)
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Group stories by user
      final Map<String, List<StoryModel>> storiesByUser = {};
      
      for (final doc in snapshot.docs) {
        final story = StoryModel.fromFirestore(doc);
        
        // Check if current user has viewed this story
        final isViewed = currentUserId != null && 
            story.viewedBy.contains(currentUserId);
        
        final storyWithViewStatus = story.copyWith(isViewed: isViewed);
        
        if (!storiesByUser.containsKey(story.userId)) {
          storiesByUser[story.userId] = [];
        }
        storiesByUser[story.userId]!.add(storyWithViewStatus);
      }

      // Convert to UserStoriesGroup list
      final groups = storiesByUser.entries.map((entry) {
        final stories = entry.value;
        final hasUnviewed = stories.any((s) => !s.isViewed);
        
        return UserStoriesGroup(
          userId: entry.key,
          userName: stories.first.userName,
          userProfileImage: stories.first.userProfileImage,
          stories: stories,
          hasUnviewedStories: hasUnviewed,
        );
      }).toList();

      // Sort: unviewed first, then by most recent story
      groups.sort((a, b) {
        if (a.hasUnviewedStories && !b.hasUnviewedStories) return -1;
        if (!a.hasUnviewedStories && b.hasUnviewedStories) return 1;
        return b.latestStory!.createdAt.compareTo(a.latestStory!.createdAt);
      });

      debugPrint('✅ Loaded ${groups.length} story groups');
      return groups;
    } catch (e) {
      debugPrint('❌ Error loading stories: $e');
      return [];
    }
  }

  /// Mark story as viewed
  Future<void> markStoryAsViewed(String storyId) async {
    try {
      final currentUserId = AuthService.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection(_storiesCollection).doc(storyId).update({
        'viewedBy': FieldValue.arrayUnion([currentUserId]),
        'viewsCount': FieldValue.increment(1),
      });

      debugPrint('✅ Story marked as viewed: $storyId');
    } catch (e) {
      debugPrint('❌ Error marking story as viewed: $e');
    }
  }

  /// Create a new story
  Future<String> createStory({
    required String mediaUrl,
    required StoryMediaType mediaType,
    String? caption,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final storyId = _firestore.collection(_storiesCollection).doc().id;

      final story = StoryModel(
        id: storyId,
        userId: currentUser.uid,
        userName: userData['fullName'] ?? 'Unknown User',
        userProfileImage: userData['profileImageUrl'],
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        caption: caption,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await _firestore
          .collection(_storiesCollection)
          .doc(storyId)
          .set(story.toFirestore());

      debugPrint('✅ Story created: $storyId');
      return storyId;
    } catch (e) {
      debugPrint('❌ Error creating story: $e');
      rethrow;
    }
  }

  /// Delete a story
  Future<void> deleteStory(String storyId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user owns the story
      final storyDoc = await _firestore.collection(_storiesCollection).doc(storyId).get();
      if (!storyDoc.exists) {
        throw Exception('Story not found');
      }

      final storyData = storyDoc.data()!;
      if (storyData['userId'] != currentUser.uid) {
        throw Exception('Not authorized to delete this story');
      }

      await _firestore.collection(_storiesCollection).doc(storyId).delete();
      debugPrint('✅ Story deleted: $storyId');
    } catch (e) {
      debugPrint('❌ Error deleting story: $e');
      rethrow;
    }
  }

  /// Get stories for a specific user
  Future<List<StoryModel>> getUserStories(String userId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(_storiesCollection)
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt', descending: false)
          .orderBy('createdAt', descending: false)
          .get();

      final stories = snapshot.docs
          .map((doc) => StoryModel.fromFirestore(doc))
          .toList();

      debugPrint('✅ Loaded ${stories.length} stories for user $userId');
      return stories;
    } catch (e) {
      debugPrint('❌ Error loading user stories: $e');
      return [];
    }
  }

  /// Clean up expired stories (should be run periodically)
  Future<void> cleanupExpiredStories() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(_storiesCollection)
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ Cleaned up ${snapshot.docs.length} expired stories');
    } catch (e) {
      debugPrint('❌ Error cleaning up expired stories: $e');
    }
  }
}
