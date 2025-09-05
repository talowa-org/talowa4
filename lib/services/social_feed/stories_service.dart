// Stories Service for TALOWA Social Feed
// Handle 24-hour temporary stories functionality
import 'dart:async';
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
  final String _storyViewsCollection = 'story_views';

  // Create a new story
  Future<String> createStory({
    required String mediaUrl,
    required String mediaType,
    String? caption,
    int? duration,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile for author info
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final storyId = _firestore.collection(_storiesCollection).doc().id;

      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final story = StoryModel(
        id: storyId,
        authorId: currentUser.uid,
        authorName: userData['fullName'] ?? 'Unknown User',
        authorRole: userData['role'] ?? 'member',
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        caption: caption,
        duration: duration ?? (mediaType == 'image' ? 5 : 15),
        createdAt: now,
        expiresAt: expiresAt,
        views: 0,
        reactions: {},
        isActive: true,
      );

      // Save story to Firestore
      await _firestore.collection(_storiesCollection).doc(storyId).set(story.toFirestore());

      debugPrint('Story created successfully: $storyId');
      return storyId;
    } catch (e) {
      debugPrint('Error creating story: $e');
      rethrow;
    }
  }

  // Get active stories (not expired)
  Future<List<StoryModel>> getActiveStories({
    String? location,
    int limit = 50,
  }) async {
    try {
      // Try the optimized query first, fall back to simple query if index doesn't exist
      try {
        Query query = _firestore.collection(_storiesCollection);

        // Only get active stories that haven't expired
        query = query
            .where('isActive', isEqualTo: true)
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .orderBy('expiresAt')
            .orderBy('createdAt', descending: true);

        if (location != null && location.isNotEmpty) {
          // TODO: Add location-based filtering when location field is added to stories
        }

        query = query.limit(limit);

        final snapshot = await query.get();
        
        List<StoryModel> stories = [];
        for (final doc in snapshot.docs) {
          final story = StoryModel.fromFirestore(doc);
          stories.add(story);
        }

        return stories;
      } catch (indexError) {
        // If composite index doesn't exist, use simpler query
        debugPrint('Using fallback query for stories (index not ready): $indexError');
        
        final snapshot = await _firestore
            .collection(_storiesCollection)
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        
        List<StoryModel> stories = [];
        final now = DateTime.now();
        
        for (final doc in snapshot.docs) {
          final story = StoryModel.fromFirestore(doc);
          // Filter expired stories manually
          if (story.expiresAt.isAfter(now)) {
            stories.add(story);
          }
        }

        return stories;
      }
    } catch (e) {
      debugPrint('Error getting active stories: $e');
      return [];
    }
  }

  // Get stories by author (grouped by author)
  Future<Map<String, List<StoryModel>>> getStoriesByAuthor({
    String? location,
    int limit = 20,
  }) async {
    try {
      final stories = await getActiveStories(location: location, limit: limit);
      
      // Group stories by author
      final Map<String, List<StoryModel>> storiesByAuthor = {};
      
      for (final story in stories) {
        if (!storiesByAuthor.containsKey(story.authorId)) {
          storiesByAuthor[story.authorId] = [];
        }
        storiesByAuthor[story.authorId]!.add(story);
      }

      // Sort stories within each author group by creation time
      for (final authorStories in storiesByAuthor.values) {
        authorStories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }

      return storiesByAuthor;
    } catch (e) {
      debugPrint('Error getting stories by author: $e');
      return {};
    }
  }

  // View a story (increment view count)
  Future<void> viewStory(String storyId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Check if user has already viewed this story
      final viewId = '${storyId}_${currentUser.uid}';
      final viewDoc = await _firestore.collection(_storyViewsCollection).doc(viewId).get();

      if (!viewDoc.exists) {
        // Record the view
        await _firestore.collection(_storyViewsCollection).doc(viewId).set({
          'storyId': storyId,
          'userId': currentUser.uid,
          'viewedAt': FieldValue.serverTimestamp(),
        });

        // Increment view count
        await _firestore.collection(_storiesCollection).doc(storyId).update({
          'views': FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint('Error viewing story: $e');
    }
  }

  // React to a story
  Future<void> reactToStory(String storyId, String reaction) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection(_storiesCollection).doc(storyId).update({
        'reactions.${currentUser.uid}': reaction,
      });
    } catch (e) {
      debugPrint('Error reacting to story: $e');
      rethrow;
    }
  }

  // Remove reaction from story
  Future<void> removeReaction(String storyId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection(_storiesCollection).doc(storyId).update({
        'reactions.${currentUser.uid}': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error removing reaction: $e');
      rethrow;
    }
  }

  // Delete a story
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
      if (storyData['authorId'] != currentUser.uid) {
        throw Exception('Not authorized to delete this story');
      }

      // Mark story as inactive instead of deleting (for analytics)
      await _firestore.collection(_storiesCollection).doc(storyId).update({
        'isActive': false,
      });

      // Delete associated views
      final viewsSnapshot = await _firestore
          .collection(_storyViewsCollection)
          .where('storyId', isEqualTo: storyId)
          .get();

      for (final doc in viewsSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting story: $e');
      rethrow;
    }
  }

  // Get story views (for story owner)
  Future<List<Map<String, dynamic>>> getStoryViews(String storyId) async {
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
      if (storyData['authorId'] != currentUser.uid) {
        throw Exception('Not authorized to view story analytics');
      }

      final viewsSnapshot = await _firestore
          .collection(_storyViewsCollection)
          .where('storyId', isEqualTo: storyId)
          .orderBy('viewedAt', descending: true)
          .get();

      List<Map<String, dynamic>> views = [];
      for (final doc in viewsSnapshot.docs) {
        final data = doc.data();
        
        // Get viewer info
        final userDoc = await _firestore.collection('users').doc(data['userId']).get();
        final userData = userDoc.exists ? userDoc.data()! : {};

        views.add({
          'userId': data['userId'],
          'viewerName': userData['fullName'] ?? 'Unknown User',
          'viewerRole': userData['role'] ?? 'member',
          'viewedAt': (data['viewedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      return views;
    } catch (e) {
      debugPrint('Error getting story views: $e');
      return [];
    }
  }

  // Clean up expired stories (should be run periodically)
  Future<void> cleanupExpiredStories() async {
    try {
      final expiredStoriesSnapshot = await _firestore
          .collection(_storiesCollection)
          .where('expiresAt', isLessThan: Timestamp.now())
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in expiredStoriesSnapshot.docs) {
        await doc.reference.update({'isActive': false});
      }

      debugPrint('Cleaned up ${expiredStoriesSnapshot.docs.length} expired stories');
    } catch (e) {
      debugPrint('Error cleaning up expired stories: $e');
    }
  }

  // Get user's own stories
  Future<List<StoryModel>> getUserStories(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_storiesCollection)
          .where('authorId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => StoryModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting user stories: $e');
      return [];
    }
  }

  // Stream active stories for real-time updates
  Stream<List<StoryModel>> streamActiveStories({
    String? location,
    int limit = 50,
  }) {
    Query query = _firestore.collection(_storiesCollection);

    query = query
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => StoryModel.fromFirestore(doc)).toList();
    });
  }
}
