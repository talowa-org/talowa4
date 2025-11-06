// Post Management Service for TALOWA Instagram-like Posts
// Comprehensive post management with editing, deletion, and sharing
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../auth/auth_service.dart';
import '../cache/cache_service.dart';
import '../analytics/analytics_service.dart';

class PostManagementService {
  static final PostManagementService _instance = PostManagementService._internal();
  factory PostManagementService() => _instance;
  PostManagementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CacheService _cacheService = CacheService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Collections
  static const String _postsCollection = 'posts';
  static const String _sharesCollection = 'post_shares';
  static const String _reportsCollection = 'post_reports';

  // Stream controllers
  final StreamController<String> _postUpdateController = 
      StreamController<String>.broadcast();
  final StreamController<String> _postDeleteController = 
      StreamController<String>.broadcast();

  // Getters
  Stream<String> get postUpdateStream => _postUpdateController.stream;
  Stream<String> get postDeleteStream => _postDeleteController.stream;

  /// Edit a post
  Future<void> editPost({
    required String postId,
    String? newCaption,
    List<String>? newHashtags,
    LocationTag? newLocationTag,
    List<UserTag>? newUserTags,
    PostVisibility? newVisibility,
    bool? allowComments,
    bool? allowSharing,
    String? altText,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get current post data
      final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final postData = postDoc.data()!;
      
      // Verify ownership
      if (postData['authorId'] != currentUser.uid) {
        throw Exception('You can only edit your own posts');
      }

      // Prepare update data
      final Map<String, dynamic> updateData = {
        'editedAt': FieldValue.serverTimestamp(),
      };

      if (newCaption != null) {
        if (newCaption.length > 2200) {
          throw Exception('Caption cannot exceed 2200 characters');
        }
        updateData['caption'] = newCaption;
        
        // Extract hashtags from caption if not provided separately
        if (newHashtags == null) {
          updateData['hashtags'] = _extractHashtags(newCaption);
        }
      }

      if (newHashtags != null) {
        updateData['hashtags'] = newHashtags;
      }

      if (newLocationTag != null) {
        updateData['locationTag'] = newLocationTag.toMap();
      }

      if (newUserTags != null) {
        updateData['userTags'] = newUserTags.map((tag) => tag.toMap()).toList();
        updateData['mentionedUserIds'] = newUserTags.map((tag) => tag.userId).toList();
      }

      if (newVisibility != null) {
        updateData['visibility'] = newVisibility.value;
      }

      if (allowComments != null) {
        updateData['allowComments'] = allowComments;
      }

      if (allowSharing != null) {
        updateData['allowSharing'] = allowSharing;
      }

      if (altText != null) {
        updateData['altText'] = altText;
      }

      // Update post in database
      await _firestore.collection(_postsCollection).doc(postId).update(updateData);

      // Invalidate caches
      await _invalidatePostCaches();

      // Track analytics
      _analyticsService.trackEvent('post_edited', {
        'post_id': postId,
        'fields_updated': updateData.keys.toList(),
      });

      // Emit update
      _postUpdateController.add(postId);

      debugPrint('✅ Post edited successfully: $postId');

    } catch (e) {
      debugPrint('❌ Error editing post: $e');
      _analyticsService.trackEvent('post_edit_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get post data
      final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final postData = postDoc.data()!;
      
      // Verify ownership or admin privileges
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final isAdmin = userData['role'] == 'admin' || userData['role'] == 'superAdmin';
      
      if (postData['authorId'] != currentUser.uid && !isAdmin) {
        throw Exception('You can only delete your own posts');
      }

      // Get all related data counts
      final commentsQuery = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();

      final likesQuery = await _firestore
          .collection('post_likes')
          .where('postId', isEqualTo: postId)
          .get();

      final sharesQuery = await _firestore
          .collection(_sharesCollection)
          .where('postId', isEqualTo: postId)
          .get();

      // Use batch write for consistency
      final batch = _firestore.batch();

      // Delete the post
      batch.delete(_firestore.collection(_postsCollection).doc(postId));

      // Delete all comments
      for (final commentDoc in commentsQuery.docs) {
        batch.delete(commentDoc.reference);
      }

      // Delete all likes
      for (final likeDoc in likesQuery.docs) {
        batch.delete(likeDoc.reference);
      }

      // Delete all shares
      for (final shareDoc in sharesQuery.docs) {
        batch.delete(shareDoc.reference);
      }

      // Update user stats
      batch.update(_firestore.collection('users').doc(postData['authorId']), {
        'postsCount': FieldValue.increment(-1),
      });

      await batch.commit();

      // Delete media files from storage
      await _deletePostMedia(postData);

      // Invalidate caches
      await _invalidatePostCaches();

      // Track analytics
      _analyticsService.trackEvent('post_deleted', {
        'post_id': postId,
        'comments_deleted': commentsQuery.docs.length,
        'likes_deleted': likesQuery.docs.length,
        'shares_deleted': sharesQuery.docs.length,
      });

      // Emit deletion event
      _postDeleteController.add(postId);

      debugPrint('✅ Post deleted successfully: $postId');

    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
      _analyticsService.trackEvent('post_delete_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Share a post externally
  Future<void> sharePost(InstagramPostModel post, {String? shareType}) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Check if sharing is allowed
      if (!post.allowSharing) {
        throw Exception('This post cannot be shared');
      }

      // Create share content
      String shareText = '${post.authorName} shared a post on TALOWA\n\n';
      if (post.caption.isNotEmpty) {
        shareText += '${post.caption}\n\n';
      }
      shareText += 'Join TALOWA to see more: https://talowa.web.app';

      // Share using platform share dialog
      await Share.share(
        shareText,
        subject: 'Check out this post on TALOWA',
      );

      // Record share activity (assuming successful since Share.share doesn't return status on web)
      {
        await _recordShareActivity(post.id, currentUser.uid, shareType ?? 'external');
        
        // Update post share count
        await _firestore.collection(_postsCollection).doc(post.id).update({
          'sharesCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Track analytics
        _analyticsService.trackEvent('post_shared_external', {
          'post_id': post.id,
          'share_type': shareType ?? 'external',
        });

        // Emit update
        _postUpdateController.add(post.id);
      }

      debugPrint('✅ Post shared externally: ${post.id}');

    } catch (e) {
      debugPrint('❌ Error sharing post: $e');
      _analyticsService.trackEvent('post_share_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Share a post internally (repost)
  Future<String> repostPost({
    required String originalPostId,
    String? additionalCaption,
    PostVisibility visibility = PostVisibility.public,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get original post
      final originalPostDoc = await _firestore.collection(_postsCollection).doc(originalPostId).get();
      if (!originalPostDoc.exists) throw Exception('Original post not found');

      final originalPost = InstagramPostModel.fromFirestore(originalPostDoc);
      
      // Check if sharing is allowed
      if (!originalPost.allowSharing) {
        throw Exception('This post cannot be shared');
      }

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) throw Exception('User profile not found');

      final userData = userDoc.data()!;
      final repostId = _firestore.collection(_postsCollection).doc().id;

      // Create repost caption
      String repostCaption = '';
      if (additionalCaption != null && additionalCaption.isNotEmpty) {
        repostCaption = '$additionalCaption\n\n';
      }
      repostCaption += '📤 Shared from @${originalPost.authorName}';
      if (originalPost.caption.isNotEmpty) {
        repostCaption += '\n\n"${originalPost.caption}"';
      }

      // Create repost model
      final repost = InstagramPostModel(
        id: repostId,
        authorId: currentUser.uid,
        authorName: userData['fullName'] ?? 'Unknown User',
        authorProfileImageUrl: userData['profileImageUrl'],
        caption: repostCaption,
        mediaItems: originalPost.mediaItems, // Same media
        hashtags: originalPost.hashtags,
        userTags: [], // Clear user tags for reposts
        locationTag: originalPost.locationTag,
        createdAt: DateTime.now(),
        visibility: visibility,
        allowComments: true,
        allowSharing: true,
        mentionedUserIds: [originalPost.authorId], // Mention original author
        analytics: {
          'isRepost': true,
          'originalPostId': originalPostId,
          'originalAuthorId': originalPost.authorId,
        },
      );

      // Use batch write for consistency
      final batch = _firestore.batch();
      
      // Add repost
      batch.set(_firestore.collection(_postsCollection).doc(repostId), repost.toFirestore());
      
      // Update original post share count
      batch.update(_firestore.collection(_postsCollection).doc(originalPostId), {
        'sharesCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update user stats
      batch.update(_firestore.collection('users').doc(currentUser.uid), {
        'postsCount': FieldValue.increment(1),
        'lastPostAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Record share activity
      await _recordShareActivity(originalPostId, currentUser.uid, 'repost');

      // Invalidate caches
      await _invalidatePostCaches();

      // Track analytics
      _analyticsService.trackEvent('post_reposted', {
        'original_post_id': originalPostId,
        'repost_id': repostId,
        'has_additional_caption': additionalCaption != null && additionalCaption.isNotEmpty,
      });

      // Emit update
      _postUpdateController.add(repostId);

      debugPrint('✅ Post reposted successfully: $repostId');
      return repostId;

    } catch (e) {
      debugPrint('❌ Error reposting: $e');
      _analyticsService.trackEvent('repost_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Report a post
  Future<void> reportPost({
    required String postId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Check if user has already reported this post
      final existingReportQuery = await _firestore
          .collection(_reportsCollection)
          .where('postId', isEqualTo: postId)
          .where('reportedBy', isEqualTo: currentUser.uid)
          .get();

      if (existingReportQuery.docs.isNotEmpty) {
        throw Exception('You have already reported this post');
      }

      // Create report
      await _firestore.collection(_reportsCollection).add({
        'postId': postId,
        'reportedBy': currentUser.uid,
        'reason': reason,
        'additionalDetails': additionalDetails,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'reviewedBy': null,
        'reviewedAt': null,
        'action': null,
      });

      // Track analytics
      _analyticsService.trackEvent('post_reported', {
        'post_id': postId,
        'reason': reason,
        'has_additional_details': additionalDetails != null && additionalDetails.isNotEmpty,
      });

      debugPrint('✅ Post reported successfully: $postId');

    } catch (e) {
      debugPrint('❌ Error reporting post: $e');
      _analyticsService.trackEvent('post_report_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Archive/unarchive a post (hide from public feed)
  Future<void> togglePostArchive(String postId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get post data
      final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final postData = postDoc.data()!;
      
      // Verify ownership
      if (postData['authorId'] != currentUser.uid) {
        throw Exception('You can only archive your own posts');
      }

      final isArchived = postData['isArchived'] ?? false;

      // Update post
      await _firestore.collection(_postsCollection).doc(postId).update({
        'isArchived': !isArchived,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Invalidate caches
      await _invalidatePostCaches();

      // Track analytics
      _analyticsService.trackEvent('post_archive_toggled', {
        'post_id': postId,
        'is_archived': !isArchived,
      });

      // Emit update
      _postUpdateController.add(postId);

      debugPrint('✅ Post archive toggled: $postId (archived: ${!isArchived})');

    } catch (e) {
      debugPrint('❌ Error toggling post archive: $e');
      rethrow;
    }
  }

  /// Get user's archived posts
  Future<List<InstagramPostModel>> getArchivedPosts({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      Query query = _firestore
          .collection(_postsCollection)
          .where('authorId', isEqualTo: currentUser.uid)
          .where('isArchived', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      query = query.limit(limit);

      final querySnapshot = await query.get();
      
      final posts = querySnapshot.docs
          .map((doc) => InstagramPostModel.fromFirestore(doc))
          .toList();

      debugPrint('✅ Loaded ${posts.length} archived posts');
      return posts;

    } catch (e) {
      debugPrint('❌ Error loading archived posts: $e');
      rethrow;
    }
  }

  // Private helper methods

  List<String> _extractHashtags(String content) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(content);
    return matches.map((match) => match.group(1)!.toLowerCase()).toList();
  }

  Future<void> _deletePostMedia(Map<String, dynamic> postData) async {
    try {
      // Delete media items from storage
      final mediaItems = List<Map<String, dynamic>>.from(postData['mediaItems'] ?? []);
      
      for (final mediaItem in mediaItems) {
        final url = mediaItem['url'] as String?;
        if (url != null && url.contains('firebase')) {
          try {
            final ref = _storage.refFromURL(url);
            await ref.delete();
          } catch (e) {
            debugPrint('⚠️ Failed to delete media file: $url - $e');
          }
        }
      }

      // Also handle legacy format
      final imageUrls = List<String>.from(postData['imageUrls'] ?? []);
      final videoUrls = List<String>.from(postData['videoUrls'] ?? []);
      
      for (final url in [...imageUrls, ...videoUrls]) {
        if (url.contains('firebase')) {
          try {
            final ref = _storage.refFromURL(url);
            await ref.delete();
          } catch (e) {
            debugPrint('⚠️ Failed to delete legacy media file: $url - $e');
          }
        }
      }

    } catch (e) {
      debugPrint('⚠️ Error deleting post media: $e');
    }
  }

  Future<void> _recordShareActivity(String postId, String userId, String shareType) async {
    try {
      await _firestore.collection(_sharesCollection).add({
        'postId': postId,
        'userId': userId,
        'shareType': shareType,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Failed to record share activity: $e');
    }
  }

  Future<void> _invalidatePostCaches() async {
    try {
      // Clear all post-related caches
      await _cacheService.clear();
      debugPrint('✅ Post caches invalidated');
    } catch (e) {
      debugPrint('❌ Failed to invalidate post caches: $e');
    }
  }

  /// Get scheduled posts
  Future<List<Map<String, dynamic>>> getScheduledPosts() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection('scheduled_posts')
          .where('authorId', isEqualTo: currentUser.uid)
          .where('scheduledAt', isGreaterThan: Timestamp.now())
          .orderBy('scheduledAt')
          .get();

      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

    } catch (e) {
      debugPrint('❌ Error getting scheduled posts: $e');
      return [];
    }
  }

  /// Cancel scheduled post
  Future<void> cancelScheduledPost(String scheduledPostId) async {
    try {
      await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .delete();

      debugPrint('✅ Scheduled post cancelled: $scheduledPostId');

    } catch (e) {
      debugPrint('❌ Error cancelling scheduled post: $e');
      rethrow;
    }
  }

  /// Auto-save draft
  Future<void> autoSaveDraft(Map<String, dynamic> draftData) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('drafts')
          .doc('${currentUser.uid}_auto')
          .set({
        ...draftData,
        'userId': currentUser.uid,
        'lastSaved': FieldValue.serverTimestamp(),
        'isAutoSave': true,
      });

      debugPrint('✅ Draft auto-saved');

    } catch (e) {
      debugPrint('❌ Error auto-saving draft: $e');
    }
  }

  /// Save draft
  Future<String> saveDraft(Map<String, dynamic> draftData) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final draftRef = await _firestore
          .collection('drafts')
          .add({
        ...draftData,
        'userId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSaved': FieldValue.serverTimestamp(),
        'isAutoSave': false,
      });

      debugPrint('✅ Draft saved: ${draftRef.id}');
      return draftRef.id;

    } catch (e) {
      debugPrint('❌ Error saving draft: $e');
      rethrow;
    }
  }

  /// Get user drafts
  Future<List<Map<String, dynamic>>> getUserDrafts() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection('drafts')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('lastSaved', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

    } catch (e) {
      debugPrint('❌ Error getting user drafts: $e');
      return [];
    }
  }

  /// Delete draft
  Future<void> deleteDraft(String draftId) async {
    try {
      await _firestore
          .collection('drafts')
          .doc(draftId)
          .delete();

      debugPrint('✅ Draft deleted: $draftId');

    } catch (e) {
      debugPrint('❌ Error deleting draft: $e');
      rethrow;
    }
  }

  /// Get user post analytics
  Future<Map<String, dynamic>> getUserPostAnalytics(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_postsCollection)
          .where('authorId', isEqualTo: userId)
          .get();

      int totalPosts = querySnapshot.docs.length;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        totalLikes += (data['likesCount'] ?? 0) as int;
        totalComments += (data['commentsCount'] ?? 0) as int;
        totalShares += (data['sharesCount'] ?? 0) as int;
      }

      return {
        'totalPosts': totalPosts,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'averageLikes': totalPosts > 0 ? totalLikes / totalPosts : 0,
        'averageComments': totalPosts > 0 ? totalComments / totalPosts : 0,
        'averageShares': totalPosts > 0 ? totalShares / totalPosts : 0,
      };

    } catch (e) {
      debugPrint('❌ Error getting user post analytics: $e');
      return {};
    }
  }

  /// Update post visibility
  Future<void> updatePostVisibility(String postId, String visibility) async {
    try {
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .update({
        'visibility': visibility,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Post visibility updated: $postId -> $visibility');

    } catch (e) {
      debugPrint('❌ Error updating post visibility: $e');
      rethrow;
    }
  }

  /// Get post analytics
  Future<Map<String, dynamic>> getPostAnalytics(String postId) async {
    try {
      final postDoc = await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .get();

      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final data = postDoc.data()!;
      
      return {
        'postId': postId,
        'likesCount': data['likesCount'] ?? 0,
        'commentsCount': data['commentsCount'] ?? 0,
        'sharesCount': data['sharesCount'] ?? 0,
        'viewsCount': data['viewsCount'] ?? 0,
        'createdAt': data['createdAt'],
        'engagement': _calculateEngagement(data),
      };

    } catch (e) {
      debugPrint('❌ Error getting post analytics: $e');
      return {};
    }
  }

  /// Calculate engagement rate
  double _calculateEngagement(Map<String, dynamic> postData) {
    final likes = (postData['likesCount'] ?? 0) as int;
    final comments = (postData['commentsCount'] ?? 0) as int;
    final shares = (postData['sharesCount'] ?? 0) as int;
    final views = (postData['viewsCount'] ?? 0) as int;

    if (views == 0) return 0.0;

    final totalEngagement = likes + comments + shares;
    return (totalEngagement / views) * 100;
  }

  /// Dispose resources
  void dispose() {
    _postUpdateController.close();
    _postDeleteController.close();
  }
}