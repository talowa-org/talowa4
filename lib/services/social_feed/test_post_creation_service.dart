// Test Post Creation Service - Creates sample posts with working media for testing
// This service creates posts with proper Firebase Storage URLs for testing the feed

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart';
import '../../models/social_feed/post_model.dart';
import '../auth/auth_service.dart';

class TestPostCreationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _postsCollection = 'posts';

  /// Create test posts with working media URLs
  static Future<void> createTestPosts() async {
    // Allow test post creation in web environment for debugging
    debugPrint('Creating test posts...');

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        debugPrint('No authenticated user found');
        return;
      }

      debugPrint('Creating test posts...');

      // Test post 1: Text post with emojis
      await _createTestPost(
        title: 'Beautiful Landscape',
        content: 'Check out this amazing view from our community! ðŸŒ„ The sunrise this morning was absolutely breathtaking. Our village is blessed with such natural beauty. #nature #community #sunrise',
        hashtags: ['nature', 'community', 'landscape'],
        category: PostCategory.communityNews,
      );

      // Test post 2: Community announcement
      await _createTestPost(
        title: 'Community Meeting Highlights',
        content: 'Key moments from our recent community meeting. Great discussions about upcoming projects! ðŸ“¹ We discussed the new water system, road improvements, and the harvest festival. Thank you to everyone who attended. #meeting #community #highlights',
        hashtags: ['meeting', 'community', 'highlights'],
        category: PostCategory.announcement,
      );

      // Test post 3: Agricultural success story
      await _createTestPost(
        title: 'Agricultural Success Story',
        content: 'Our farmers are achieving great results with new techniques! ðŸŒ¾ðŸ‘¨â€ðŸŒ¾ The new irrigation system has increased crop yield by 40% while using 30% less water. We\'re also implementing organic pest control methods that are both effective and environmentally friendly. #agriculture #success #innovation',
        hashtags: ['agriculture', 'success', 'farming'],
        category: PostCategory.agriculture,
      );

      // Test post 4: Text-only post
      await _createTestPost(
        title: 'Important Legal Update',
        content: 'New land rights legislation has been passed. This affects all community members. Please attend the information session next week. #legal #landrights #important',
        hashtags: ['legal', 'landrights', 'important'],
        category: PostCategory.legalUpdate,
      );

      // Test post 5: Emergency post
      await _createTestPost(
        title: 'ðŸš¨ Emergency Alert',
        content: 'Flash flood warning in the northern districts. Please take necessary precautions and move to higher ground if needed. Emergency contacts: 911, 108. #emergency #flood #safety',
        hashtags: ['emergency', 'flood', 'safety'],
        category: PostCategory.emergency,
      );

      debugPrint('âœ… Test posts created successfully!');
      debugPrint('ðŸ“± Pull to refresh the feed to see the new posts!');
    } catch (e) {
      debugPrint('âŒ Error creating test posts: $e');
    }
  }

  static Future<void> _createTestPost({
    required String content,
    String? title,
    List<String> imageUrls = const [],
    List<String> videoUrls = const [],
    List<String> documentUrls = const [],
    List<String> hashtags = const [],
    required PostCategory category,
  }) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    // Get user profile for author name
    String authorName = 'Test User';
    String? authorRole;
    
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        authorName = userData['name'] ?? userData['displayName'] ?? 'Test User';
        authorRole = userData['role'];
      }
    } catch (e) {
      debugPrint('Could not get user data: $e');
    }

    final post = PostModel(
      id: '', // Will be set by Firestore
      authorId: currentUser.uid,
      authorName: authorName,
      authorRole: authorRole,
      title: title,
      content: content,
      mediaUrls: [...imageUrls, ...videoUrls, ...documentUrls], // Legacy support
      imageUrls: imageUrls,
      videoUrls: videoUrls,
      documentUrls: documentUrls,
      hashtags: hashtags,
      category: category,
      location: 'Test Location',
      createdAt: DateTime.now(),
      likesCount: (DateTime.now().millisecondsSinceEpoch % 50), // Random likes
      commentsCount: (DateTime.now().millisecondsSinceEpoch % 20), // Random comments
      sharesCount: (DateTime.now().millisecondsSinceEpoch % 10), // Random shares
      isLikedByCurrentUser: false,
    );

    await _firestore.collection(_postsCollection).add(post.toFirestore());
    debugPrint('Created test post: ${title ?? content.substring(0, 30)}...');
  }

  /// Clear all test posts (for cleanup)
  static Future<void> clearTestPosts() async {
    if (!kDebugMode) {
      debugPrint('Test post clearing is only available in debug mode');
      return;
    }

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      final snapshot = await _firestore
          .collection(_postsCollection)
          .where('authorId', isEqualTo: currentUser.uid)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('âœ… Test posts cleared successfully!');
    } catch (e) {
      debugPrint('âŒ Error clearing test posts: $e');
    }
  }
}

