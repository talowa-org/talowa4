// Story Service for TALOWA Instagram-like Stories
// Comprehensive story management with real-time updates
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/story_model.dart';
import '../auth/auth_service.dart';
import '../cache/cache_service.dart';
import '../analytics/analytics_service.dart';

class StoryService {
  static final StoryService _instance = StoryService._internal();
  factory StoryService() => _instance;
  StoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CacheService _cacheService = CacheService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Collections
  static const String _storiesCollection = 'stories';
  static const String _storyViewsCollection = 'story_views';

  // Cache keys
  static const String _storiesCacheKey = 'user_stories_cache';
  static const String _myStoriesCacheKey = 'my_stories_cache';

  // Stream controllers
  final StreamController<List<StoryModel>> _storiesStreamController = 
      StreamController<List<StoryModel>>.broadcast();
  final StreamController<List<StoryModel>> _myStoriesStreamController = 
      StreamController<List<StoryModel>>.broadcast();

  // Internal state
  List<StoryModel> _cachedStories = [];
  List<StoryModel> _cachedMyStories = [];
  Set<String> _viewedStories = {};
  bool _isInitialized = false;

  // Getters
  Stream<List<StoryModel>> get storiesStream => _storiesStreamController.stream;
  Stream<List<StoryModel>> get myStoriesStream => _myStoriesStreamController.stream;
  bool get isInitialized => _isInitialized;

  /// Initialize the story service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadViewedStories();
      _setupRealTimeListeners();
      _isInitialized = true;
      debugPrint('✅ Story Service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Story Service: $e');
      rethrow;
    }
  }

  /// Get all active stories from followed users
  Future<List<StoryModel>> getStories({bool refresh = false}) async {
    try {
      if (!_isInitialized) await initialize();

      // Track analytics
      _analyticsService.trackEvent('stories_load_requested', {
        'refresh': refresh,
      });

      // Use cached data if available and not refreshing
      if (!refresh && _cachedStories.isNotEmpty) {
        return _applyViewedStatus(_cachedStories);
      }

      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      // Get stories from last 24 hours
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
      
      final query = _firestore
          .collection(_storiesCollection)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .where('createdAt', isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo))
          .orderBy('createdAt', descending: true)
          .limit(50);

      final querySnapshot = await query.get();
      
      final stories = querySnapshot.docs
          .map((doc) => StoryModel.fromFirestore(doc))
          .where((story) => _canViewStory(story, currentUser.uid))
          .toList();

      // Group stories by author (latest story per user)
      final Map<String, StoryModel> latestStoriesByUser = {};
      for (final story in stories) {
        if (!latestStoriesByUser.containsKey(story.authorId) ||
            story.createdAt.isAfter(latestStoriesByUser[story.authorId]!.createdAt)) {
          latestStoriesByUser[story.authorId] = story;
        }
      }

      final groupedStories = latestStoriesByUser.values.toList();
      groupedStories.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Apply viewed status
      final enrichedStories = _applyViewedStatus(groupedStories);

      // Update cache
      _cachedStories = enrichedStories;
      await _cacheResults(_storiesCacheKey, enrichedStories);

      // Emit to stream
      _storiesStreamController.add(enrichedStories);

      // Track analytics
      _analyticsService.trackEvent('stories_loaded', {
        'stories_count': enrichedStories.length,
      });

      debugPrint('✅ Loaded ${enrichedStories.length} stories');
      return enrichedStories;

    } catch (e) {
      debugPrint('❌ Failed to load stories: $e');
      _analyticsService.trackEvent('stories_load_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Get current user's stories
  Future<List<StoryModel>> getMyStories({bool refresh = false}) async {
    try {
      if (!_isInitialized) await initialize();

      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];

      // Use cached data if available and not refreshing
      if (!refresh && _cachedMyStories.isNotEmpty) {
        return _cachedMyStories;
      }

      final query = _firestore
          .collection(_storiesCollection)
          .where('authorId', isEqualTo: currentUser.uid)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('expiresAt', descending: false)
          .orderBy('createdAt', descending: true);

      final querySnapshot = await query.get();
      
      final stories = querySnapshot.docs
          .map((doc) => StoryModel.fromFirestore(doc))
          .toList();

      // Update cache
      _cachedMyStories = stories;
      await _cacheResults(_myStoriesCacheKey, stories);

      // Emit to stream
      _myStoriesStreamController.add(stories);

      debugPrint('✅ Loaded ${stories.length} of my stories');
      return stories;

    } catch (e) {
      debugPrint('❌ Failed to load my stories: $e');
      rethrow;
    }
  }

  /// Create a new story
  Future<String> createStory({
    required List<File> mediaFiles,
    List<String>? texts,
    List<String>? backgroundColors,
    StoryPrivacy privacy = StoryPrivacy.public,
    List<String>? allowedViewerIds,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      if (mediaFiles.isEmpty) throw Exception('At least one media file is required');

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) throw Exception('User profile not found');

      final userData = userDoc.data()!;
      final storyId = _firestore.collection(_storiesCollection).doc().id;

      // Upload media files and create story items
      final List<StoryItem> storyItems = [];
      
      for (int i = 0; i < mediaFiles.length; i++) {
        final file = mediaFiles[i];
        final isVideo = file.path.toLowerCase().contains('.mp4') || 
                       file.path.toLowerCase().contains('.mov');
        
        // Upload to Firebase Storage with error handling
        final fileName = '${storyId}_item_$i.${isVideo ? 'mp4' : 'jpg'}';
        final storageRef = _storage.ref().child('stories/$storyId/$fileName');
        
        String downloadUrl;
        try {
          final uploadTask = await storageRef.putFile(file);
          downloadUrl = await uploadTask.ref.getDownloadURL();
        } catch (e) {
          debugPrint('❌ Error uploading story media: $e');
          // For web compatibility, use putData instead of putFile
          try {
            final bytes = await file.readAsBytes();
            final uploadTask = await storageRef.putData(bytes);
            downloadUrl = await uploadTask.ref.getDownloadURL();
          } catch (webError) {
            debugPrint('❌ Error with putData: $webError');
            throw Exception('Failed to upload story media: $webError');
          }
        }

        // Create story item
        final storyItem = StoryItem(
          id: '${storyId}_item_$i',
          type: isVideo ? StoryItemType.video : StoryItemType.image,
          content: downloadUrl,
          caption: texts != null && i < texts.length ? texts[i] : null,
          duration: isVideo ? 15 : 5, // 15s for video, 5s for image
          timestamp: DateTime.now(),
        );

        storyItems.add(storyItem);
      }

      // Create story model
      final story = StoryModel(
        id: storyId,
        authorId: currentUser.uid,
        authorName: userData['fullName'] ?? 'Unknown User',
        authorAvatarUrl: userData['profileImageUrl'],
        mediaUrl: storyItems.isNotEmpty ? storyItems.first.content : '',
        mediaType: storyItems.isNotEmpty ? 
          (storyItems.first.type == StoryItemType.video ? StoryMediaType.video : StoryMediaType.image) :
          StoryMediaType.image,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        privacy: privacy,
      );

      // Save to database
      await _firestore.collection(_storiesCollection).doc(storyId).set(story.toFirestore());

      // Invalidate caches
      await _invalidateCaches();

      // Track analytics
      _analyticsService.trackEvent('story_created', {
        'story_id': storyId,
        'items_count': storyItems.length,
        'privacy': privacy.value,
      });

      debugPrint('✅ Story created successfully: $storyId');
      return storyId;

    } catch (e) {
      debugPrint('❌ Error creating story: $e');
      _analyticsService.trackEvent('story_create_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// View a story (mark as viewed and increment view count)
  Future<void> viewStory(String storyId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Check if already viewed
      if (_viewedStories.contains(storyId)) return;

      final viewId = '${storyId}_${currentUser.uid}';
      
      await _firestore.runTransaction((transaction) async {
        final storyRef = _firestore.collection(_storiesCollection).doc(storyId);
        final viewRef = _firestore.collection(_storyViewsCollection).doc(viewId);
        
        final storyDoc = await transaction.get(storyRef);
        final viewDoc = await transaction.get(viewRef);
        
        if (!storyDoc.exists) return;
        if (viewDoc.exists) return; // Already viewed

        // Add view record
        transaction.set(viewRef, {
          'storyId': storyId,
          'userId': currentUser.uid,
          'viewedAt': FieldValue.serverTimestamp(),
        });

        // Increment view count
        transaction.update(storyRef, {
          'viewsCount': FieldValue.increment(1),
          'viewedByUserIds': FieldValue.arrayUnion([currentUser.uid]),
        });
      });

      // Update local state
      _viewedStories.add(storyId);

      // Track analytics
      _analyticsService.trackEvent('story_viewed', {'story_id': storyId});

    } catch (e) {
      debugPrint('❌ Error viewing story: $e');
    }
  }

  /// Delete a story
  Future<void> deleteStory(String storyId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Verify ownership
      final storyDoc = await _firestore.collection(_storiesCollection).doc(storyId).get();
      if (!storyDoc.exists) throw Exception('Story not found');

      final storyData = storyDoc.data()!;
      if (storyData['authorId'] != currentUser.uid) {
        throw Exception('You can only delete your own stories');
      }

      // Delete from database
      await _firestore.collection(_storiesCollection).doc(storyId).delete();

      // Delete associated views
      final viewsQuery = await _firestore
          .collection(_storyViewsCollection)
          .where('storyId', isEqualTo: storyId)
          .get();

      final batch = _firestore.batch();
      for (final doc in viewsQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete media files from storage
      try {
        final storageRef = _storage.ref().child('stories/$storyId');
        final listResult = await storageRef.listAll();
        for (final item in listResult.items) {
          await item.delete();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to delete story media files: $e');
      }

      // Invalidate caches
      await _invalidateCaches();

      // Track analytics
      _analyticsService.trackEvent('story_deleted', {'story_id': storyId});

      debugPrint('✅ Story deleted successfully: $storyId');

    } catch (e) {
      debugPrint('❌ Error deleting story: $e');
      rethrow;
    }
  }

  /// Get story viewers
  Future<List<Map<String, dynamic>>> getStoryViewers(String storyId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Verify ownership
      final storyDoc = await _firestore.collection(_storiesCollection).doc(storyId).get();
      if (!storyDoc.exists) throw Exception('Story not found');

      final storyData = storyDoc.data()!;
      if (storyData['authorId'] != currentUser.uid) {
        throw Exception('You can only view your own story viewers');
      }

      final viewsQuery = await _firestore
          .collection(_storyViewsCollection)
          .where('storyId', isEqualTo: storyId)
          .orderBy('viewedAt', descending: true)
          .get();

      final viewers = <Map<String, dynamic>>[];
      
      for (final doc in viewsQuery.docs) {
        final data = doc.data();
        final userId = data['userId'];
        
        // Get user profile
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          viewers.add({
            'userId': userId,
            'name': userData['fullName'] ?? 'Unknown User',
            'profileImageUrl': userData['profileImageUrl'],
            'viewedAt': data['viewedAt'],
          });
        }
      }

      return viewers;

    } catch (e) {
      debugPrint('❌ Error getting story viewers: $e');
      rethrow;
    }
  }

  // Private helper methods

  void _setupRealTimeListeners() {
    // Listen for new stories
    _firestore
        .collection(_storiesCollection)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        // Refresh stories when changes occur
        getStories(refresh: true);
      },
      onError: (error) {
        debugPrint('❌ Stories real-time listener error: $error');
      },
    );
  }

  Future<void> _loadViewedStories() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      final viewsQuery = await _firestore
          .collection(_storyViewsCollection)
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      _viewedStories = viewsQuery.docs
          .map((doc) => doc.data()['storyId'] as String)
          .toSet();

      debugPrint('✅ Loaded ${_viewedStories.length} viewed stories');

    } catch (e) {
      debugPrint('❌ Failed to load viewed stories: $e');
    }
  }

  bool _canViewStory(StoryModel story, String currentUserId) {
    switch (story.privacy) {
      case StoryPrivacy.public:
        return true;
      case StoryPrivacy.friends:
        return story.allowedViewerIds.contains(currentUserId) || 
               story.authorId == currentUserId;
      case StoryPrivacy.close:
        return story.allowedViewerIds.contains(currentUserId) || 
               story.authorId == currentUserId;
      case StoryPrivacy.closeFriends:
        return story.allowedViewerIds.contains(currentUserId) || 
               story.authorId == currentUserId;
      case StoryPrivacy.private:
        return story.authorId == currentUserId;
    }
  }

  List<StoryModel> _applyViewedStatus(List<StoryModel> stories) {
    return stories.map((story) => story.copyWith(
      isViewedByCurrentUser: _viewedStories.contains(story.id),
    )).toList();
  }

  Future<void> _cacheResults(String key, List<StoryModel> stories) async {
    try {
      final cacheData = {
        'stories': stories.map((story) => story.toFirestore()).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _cacheService.set(key, cacheData, 
          expiry: const Duration(minutes: 5));
    } catch (e) {
      debugPrint('❌ Failed to cache stories: $e');
    }
  }

  Future<void> _invalidateCaches() async {
    try {
      await _cacheService.remove(_storiesCacheKey);
      await _cacheService.remove(_myStoriesCacheKey);
      
      _cachedStories.clear();
      _cachedMyStories.clear();

      debugPrint('✅ Story caches invalidated');
    } catch (e) {
      debugPrint('❌ Failed to invalidate story caches: $e');
    }
  }

  /// Clear all caches
  Future<void> clearCache() async {
    await _invalidateCaches();
    _viewedStories.clear();
  }

  /// Dispose resources
  void dispose() {
    _storiesStreamController.close();
    _myStoriesStreamController.close();
    _isInitialized = false;
  }
}