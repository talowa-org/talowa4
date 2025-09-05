// Post Management Service - Handle post editing, deletion, and management
// Part of Task 11: Add post editing and management

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/geographic_targeting.dart';
import '../auth/auth_service.dart';
import 'feed_service.dart';

/// Service for managing posts (editing, deletion, scheduling, etc.)
class PostManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  static final CollectionReference _postsCollection = _firestore.collection('posts');
  static final CollectionReference _draftsCollection = _firestore.collection('drafts');
  static final CollectionReference _scheduledPostsCollection = _firestore.collection('scheduled_posts');
  static final CollectionReference _postAnalyticsCollection = _firestore.collection('post_analytics');
  
  /// Edit an existing post
  static Future<PostModel> editPost({
    required String postId,
    String? title,
    String? content,
    List<String>? imageUrls,
    List<String>? documentUrls,
    List<String>? hashtags,
    PostCategory? category,
    PostPriority? priority,
    GeographicTargeting? targeting,
    PostVisibility? visibility,
  }) async {
    try {
      debugPrint('PostManagementService: Editing post $postId');
      
      // Get current user
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Get existing post
      final existingPost = await FeedService.getPostById(postId);
      if (existingPost == null) {
        throw Exception('Post not found');
      }
      
      // Check permissions
      if (!_canUserEditPost(existingPost, currentUser.uid, currentUser.role)) {
        throw Exception('User does not have permission to edit this post');
      }
      
      // Use FeedService.updatePost which already has the logic
      return await FeedService.updatePost(
        postId: postId,
        title: title,
        content: content,
        imageUrls: imageUrls,
        documentUrls: documentUrls,
        hashtags: hashtags,
        category: category,
        priority: priority,
        targeting: targeting,
        visibility: visibility,
      );
      
    } catch (e) {
      debugPrint('PostManagementService: Error editing post: $e');
      rethrow;
    }
  }
  
  /// Delete a post with confirmation
  static Future<void> deletePost(String postId, {String? reason}) async {
    try {
      debugPrint('PostManagementService: Deleting post $postId');
      
      // Get current user
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Get existing post
      final existingPost = await FeedService.getPostById(postId);
      if (existingPost == null) {
        throw Exception('Post not found');
      }
      
      // Check permissions
      if (!_canUserDeletePost(existingPost, currentUser.uid, currentUser.role)) {
        throw Exception('User does not have permission to delete this post');
      }
      
      // Use transaction to ensure consistency
      await _firestore.runTransaction((transaction) async {
        // Soft delete - mark as hidden instead of actual deletion
        final postRef = _postsCollection.doc(postId);
        transaction.update(postRef, {
          'isHidden': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': currentUser.uid,
          'deletionReason': reason,
        });
        
        // Update user's post count
        final userRef = _firestore.collection('users').doc(existingPost.authorId);
        transaction.update(userRef, {
          'postsCount': FieldValue.increment(-1),
        });
        
        // Log the deletion for audit purposes
        final auditRef = _firestore.collection('audit_logs').doc();
        transaction.set(auditRef, {
          'action': 'post_deleted',
          'postId': postId,
          'authorId': existingPost.authorId,
          'deletedBy': currentUser.uid,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
      
      debugPrint('PostManagementService: Post deleted successfully');
      
    } catch (e) {
      debugPrint('PostManagementService: Error deleting post: $e');
      rethrow;
    }
  }
  
  /// Update post visibility
  static Future<void> updatePostVisibility(
    String postId,
    PostVisibility visibility,
  ) async {
    try {
      debugPrint('PostManagementService: Updating post visibility $postId to $visibility');
      
      // Get current user
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Get existing post
      final existingPost = await FeedService.getPostById(postId);
      if (existingPost == null) {
        throw Exception('Post not found');
      }
      
      // Check permissions
      if (!_canUserEditPost(existingPost, currentUser.uid, currentUser.role)) {
        throw Exception('User does not have permission to edit this post');
      }
      
      // Update visibility
      await _postsCollection.doc(postId).update({
        'visibility': visibility.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('PostManagementService: Post visibility updated successfully');
      
    } catch (e) {
      debugPrint('PostManagementService: Error updating post visibility: $e');
      rethrow;
    }
  }
  
  /// Save post as draft
  static Future<String> saveDraft({
    String? draftId,
    required String authorId,
    String? title,
    String? content,
    List<String>? imageUrls,
    List<String>? documentUrls,
    List<String>? hashtags,
    PostCategory? category,
    PostPriority? priority,
    GeographicTargeting? targeting,
    PostVisibility? visibility,
  }) async {
    try {
      debugPrint('PostManagementService: Saving draft');
      
      final draftData = {
        'authorId': authorId,
        'title': title,
        'content': content ?? '',
        'imageUrls': imageUrls ?? [],
        'documentUrls': documentUrls ?? [],
        'hashtags': hashtags ?? [],
        'category': category?.toString().split('.').last ?? 'generalDiscussion',
        'priority': priority?.toString().split('.').last ?? 'normal',
        'targeting': targeting?.toMap(),
        'visibility': visibility?.toString().split('.').last ?? 'public',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      DocumentReference draftRef;
      if (draftId != null) {
        // Update existing draft
        draftRef = _draftsCollection.doc(draftId);
        await draftRef.update(draftData);
      } else {
        // Create new draft
        draftRef = _draftsCollection.doc();
        await draftRef.set(draftData);
      }
      
      debugPrint('PostManagementService: Draft saved with ID ${draftRef.id}');
      return draftRef.id;
      
    } catch (e) {
      debugPrint('PostManagementService: Error saving draft: $e');
      rethrow;
    }
  }
  
  /// Get user's drafts
  static Future<List<Map<String, dynamic>>> getUserDrafts(String userId) async {
    try {
      debugPrint('PostManagementService: Getting drafts for user $userId');
      
      final querySnapshot = await _draftsCollection
          .where('authorId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();
      
      final drafts = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      debugPrint('PostManagementService: Found ${drafts.length} drafts');
      return drafts;
      
    } catch (e) {
      debugPrint('PostManagementService: Error getting drafts: $e');
      return [];
    }
  }
  
  /// Delete a draft
  static Future<void> deleteDraft(String draftId) async {
    try {
      debugPrint('PostManagementService: Deleting draft $draftId');
      
      await _draftsCollection.doc(draftId).delete();
      
      debugPrint('PostManagementService: Draft deleted successfully');
      
    } catch (e) {
      debugPrint('PostManagementService: Error deleting draft: $e');
      rethrow;
    }
  }
  
  /// Schedule a post for later publishing
  static Future<String> schedulePost({
    required String authorId,
    required DateTime scheduledTime,
    String? title,
    required String content,
    List<String>? imageUrls,
    List<String>? documentUrls,
    List<String>? hashtags,
    required PostCategory category,
    PostPriority priority = PostPriority.normal,
    GeographicTargeting? targeting,
    PostVisibility visibility = PostVisibility.public,
  }) async {
    try {
      debugPrint('PostManagementService: Scheduling post for $scheduledTime');
      
      // Validate scheduled time is in the future
      if (scheduledTime.isBefore(DateTime.now())) {
        throw Exception('Scheduled time must be in the future');
      }
      
      // Validate scheduled time is not too far in the future (e.g., 1 year)
      final maxScheduleTime = DateTime.now().add(const Duration(days: 365));
      if (scheduledTime.isAfter(maxScheduleTime)) {
        throw Exception('Cannot schedule posts more than 1 year in advance');
      }
      
      final scheduledPostData = {
        'authorId': authorId,
        'title': title,
        'content': content,
        'imageUrls': imageUrls ?? [],
        'documentUrls': documentUrls ?? [],
        'hashtags': hashtags ?? [],
        'category': category.toString().split('.').last,
        'priority': priority.toString().split('.').last,
        'targeting': targeting?.toMap(),
        'visibility': visibility.toString().split('.').last,
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await _scheduledPostsCollection.add(scheduledPostData);
      
      debugPrint('PostManagementService: Post scheduled with ID ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      debugPrint('PostManagementService: Error scheduling post: $e');
      rethrow;
    }
  }
  
  /// Get user's scheduled posts
  static Future<List<Map<String, dynamic>>> getScheduledPosts(String userId) async {
    try {
      debugPrint('PostManagementService: Getting scheduled posts for user $userId');
      
      final querySnapshot = await _scheduledPostsCollection
          .where('authorId', isEqualTo: userId)
          .where('status', isEqualTo: 'scheduled')
          .orderBy('scheduledTime', descending: false)
          .get();
      
      final scheduledPosts = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      debugPrint('PostManagementService: Found ${scheduledPosts.length} scheduled posts');
      return scheduledPosts;
      
    } catch (e) {
      debugPrint('PostManagementService: Error getting scheduled posts: $e');
      return [];
    }
  }
  
  /// Cancel a scheduled post
  static Future<void> cancelScheduledPost(String scheduledPostId) async {
    try {
      debugPrint('PostManagementService: Canceling scheduled post $scheduledPostId');
      
      await _scheduledPostsCollection.doc(scheduledPostId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('PostManagementService: Scheduled post cancelled successfully');
      
    } catch (e) {
      debugPrint('PostManagementService: Error canceling scheduled post: $e');
      rethrow;
    }
  }
  
  /// Get post analytics
  static Future<Map<String, dynamic>> getPostAnalytics(String postId) async {
    try {
      debugPrint('PostManagementService: Getting analytics for post $postId');
      
      // Get basic post data
      final post = await FeedService.getPostById(postId);
      if (post == null) {
        throw Exception('Post not found');
      }
      
      // Get detailed analytics if available
      final analyticsDoc = await _postAnalyticsCollection.doc(postId).get();
      Map<String, dynamic> analyticsData = {};
      
      if (analyticsDoc.exists) {
        analyticsData = analyticsDoc.data() as Map<String, dynamic>;
      }
      
      // Calculate basic metrics
      final totalEngagement = post.likesCount + post.commentsCount + post.sharesCount;
      final engagementRate = analyticsData['impressions'] != null && analyticsData['impressions'] > 0
          ? (totalEngagement / analyticsData['impressions'] * 100).toStringAsFixed(2)
          : '0.00';
      
      final analytics = {
        'postId': postId,
        'likes': post.likesCount,
        'comments': post.commentsCount,
        'shares': post.sharesCount,
        'totalEngagement': totalEngagement,
        'impressions': analyticsData['impressions'] ?? 0,
        'reach': analyticsData['reach'] ?? 0,
        'engagementRate': engagementRate,
        'createdAt': post.createdAt.toIso8601String(),
        'category': post.category.displayName,
        'hashtags': post.hashtags,
        'geographicScope': _getGeographicScopeString(post.geographicTargeting),
        'hourlyEngagement': analyticsData['hourlyEngagement'] ?? {},
        'dailyEngagement': analyticsData['dailyEngagement'] ?? {},
        'topCommenters': analyticsData['topCommenters'] ?? [],
        'shareDestinations': analyticsData['shareDestinations'] ?? {},
      };
      
      debugPrint('PostManagementService: Analytics retrieved for post $postId');
      return analytics;
      
    } catch (e) {
      debugPrint('PostManagementService: Error getting post analytics: $e');
      rethrow;
    }
  }
  
  /// Get user's post analytics summary
  static Future<Map<String, dynamic>> getUserPostAnalytics(String userId) async {
    try {
      debugPrint('PostManagementService: Getting user analytics for $userId');
      
      // Get user's posts from last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final querySnapshot = await _postsCollection
          .where('authorId', isEqualTo: userId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .where('isHidden', isEqualTo: false)
          .get();
      
      int totalPosts = querySnapshot.docs.length;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;
      Map<String, int> categoryBreakdown = {};
      Map<String, int> dailyPosts = {};
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        totalLikes += (data['likesCount'] as int? ?? 0);
        totalComments += (data['commentsCount'] as int? ?? 0);
        totalShares += (data['sharesCount'] as int? ?? 0);
        
        // Category breakdown
        final category = data['category'] as String? ?? 'unknown';
        categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
        
        // Daily posts
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        dailyPosts[dateKey] = (dailyPosts[dateKey] ?? 0) + 1;
      }
      
      final totalEngagement = totalLikes + totalComments + totalShares;
      final avgEngagementPerPost = totalPosts > 0 ? (totalEngagement / totalPosts).toStringAsFixed(2) : '0.00';
      
      final analytics = {
        'userId': userId,
        'period': '30 days',
        'totalPosts': totalPosts,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'totalEngagement': totalEngagement,
        'avgEngagementPerPost': avgEngagementPerPost,
        'categoryBreakdown': categoryBreakdown,
        'dailyPosts': dailyPosts,
        'generatedAt': DateTime.now().toIso8601String(),
      };
      
      debugPrint('PostManagementService: User analytics retrieved');
      return analytics;
      
    } catch (e) {
      debugPrint('PostManagementService: Error getting user analytics: $e');
      rethrow;
    }
  }
  
  /// Auto-save functionality
  static Future<void> autoSaveDraft({
    required String authorId,
    String? draftId,
    String? title,
    String? content,
    List<String>? hashtags,
    PostCategory? category,
  }) async {
    try {
      // Only auto-save if there's meaningful content
      if ((content?.trim().isEmpty ?? true) && (title?.trim().isEmpty ?? true)) {
        return;
      }
      
      await saveDraft(
        draftId: draftId,
        authorId: authorId,
        title: title,
        content: content,
        hashtags: hashtags,
        category: category,
      );
      
    } catch (e) {
      debugPrint('PostManagementService: Error auto-saving draft: $e');
      // Don't rethrow for auto-save failures
    }
  }
  
  // Helper methods
  
  static bool _canUserEditPost(PostModel post, String userId, String? userRole) {
    // Author can always edit their own posts
    if (post.authorId == userId) return true;
    
    // Coordinators and admins can edit posts in their jurisdiction
    if (userRole != null && (userRole.contains('coordinator') || userRole.contains('admin'))) {
      return true;
    }
    
    return false;
  }
  
  static bool _canUserDeletePost(PostModel post, String userId, String? userRole) {
    // Author can always delete their own posts
    if (post.authorId == userId) return true;
    
    // Higher-level coordinators and admins can delete posts
    if (userRole != null && (userRole.contains('coordinator') || userRole.contains('admin'))) {
      return true;
    }
    
    return false;
  }
  
  static String _getGeographicScopeString(GeographicTargeting? targeting) {
    if (targeting == null) return 'No geographic targeting';
    
    final parts = <String>[];
    if (targeting.village?.isNotEmpty == true) parts.add(targeting.village!);
    if (targeting.mandal?.isNotEmpty == true) parts.add(targeting.mandal!);
    if (targeting.district?.isNotEmpty == true) parts.add(targeting.district!);
    if (targeting.state?.isNotEmpty == true) parts.add(targeting.state!);
    
    return parts.isNotEmpty ? parts.join(', ') : 'No geographic targeting';
  }
}
