// Privacy-Aware Feed Service for TALOWA Social Feed
// Implements Task 17: Privacy protection system - Feed Integration

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/index.dart';
import '../../models/user_model.dart';
import 'privacy_protection_service.dart';

class PrivacyAwareFeedService {
  static final PrivacyAwareFeedService _instance = PrivacyAwareFeedService._internal();
  factory PrivacyAwareFeedService() => _instance;
  PrivacyAwareFeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PrivacyProtectionService _privacyService = PrivacyProtectionService();

  /// Get privacy-filtered feed for user
  Future<List<PostModel>> getPrivacyFilteredFeed({
    required String userId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
    PostCategory? category,
    String? searchQuery,
  }) async {
    try {
      // Get user's location and role for filtering
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return [];
      }

      final user = UserModel.fromFirestore(userDoc);
      
      // Build base query
      Query query = _firestore
          .collection('posts')
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true);

      // Apply category filter
      if (category != null) {
        query = query.where('category', isEqualTo: category.toString());
      }

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit * 2); // Get more to account for privacy filtering

      final snapshot = await query.get();
      final allPosts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // Apply privacy filtering
      final filteredPosts = await _privacyService.filterPostsByPrivacy(
        posts: allPosts,
        viewerId: userId,
      );

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        return _applySearchFilter(filteredPosts, searchQuery);
      }

      // Limit to requested number after filtering
      return filteredPosts.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting privacy-filtered feed: $e');
      return [];
    }
  }

  /// Get privacy-filtered user posts
  Future<List<PostModel>> getUserPosts({
    required String userId,
    required String viewerId,
    int limit = 20,
  }) async {
    try {
      // Check if viewer can see user's posts
      final canViewProfile = await _privacyService.canViewContent(
        contentId: 'profile_$userId',
        viewerId: viewerId,
        contentAuthorId: userId,
        contentPrivacy: PrivacyProtectionService.privacyNetwork,
      );

      if (!canViewProfile && userId != viewerId) {
        return [];
      }

      // Get user's posts
      final query = _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      final posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // Apply privacy filtering
      return await _privacyService.filterPostsByPrivacy(
        posts: posts,
        viewerId: viewerId,
      );
    } catch (e) {
      debugPrint('Error getting user posts: $e');
      return [];
    }
  }

  /// Get privacy-filtered network feed (posts from user's network)
  Future<List<PostModel>> getNetworkFeed({
    required String userId,
    int limit = 20,
  }) async {
    try {
      // Get user's network (direct and indirect referrals)
      final networkUserIds = await _getUserNetworkIds(userId);
      
      if (networkUserIds.isEmpty) {
        return [];
      }

      // Get posts from network users
      final query = _firestore
          .collection('posts')
          .where('authorId', whereIn: networkUserIds.take(10).toList()) // Firestore limit
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit * 2);

      final snapshot = await query.get();
      final posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // Apply privacy filtering
      final filteredPosts = await _privacyService.filterPostsByPrivacy(
        posts: posts,
        viewerId: userId,
      );

      return filteredPosts.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting network feed: $e');
      return [];
    }
  }

  /// Get privacy-filtered geographic feed (posts from user's area)
  Future<List<PostModel>> getGeographicFeed({
    required String userId,
    int limit = 20,
  }) async {
    try {
      // Get user's location
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return [];
      }

      final user = UserModel.fromFirestore(userDoc);
      final userLocation = user.address;
      
      if (userLocation == null) {
        return [];
      }

      // Build geographic query
      Query query = _firestore
          .collection('posts')
          .where('isDeleted', isEqualTo: false);

      // Filter by geographic targeting
      if (userLocation.villageCode != null) {
        query = query.where('geographicTargeting.villageCode', isEqualTo: userLocation.villageCode);
      } else if (userLocation.mandalCode != null) {
        query = query.where('geographicTargeting.mandalCode', isEqualTo: userLocation.mandalCode);
      } else if (userLocation.districtCode != null) {
        query = query.where('geographicTargeting.districtCode', isEqualTo: userLocation.districtCode);
      } else if (userLocation.stateCode != null) {
        query = query.where('geographicTargeting.stateCode', isEqualTo: userLocation.stateCode);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit * 2);

      final snapshot = await query.get();
      final posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // Apply privacy filtering
      final filteredPosts = await _privacyService.filterPostsByPrivacy(
        posts: posts,
        viewerId: userId,
      );

      return filteredPosts.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting geographic feed: $e');
      return [];
    }
  }

  /// Get privacy-filtered user profile data
  Future<Map<String, dynamic>?> getPrivacyFilteredUserProfile({
    required String userId,
    required String viewerId,
  }) async {
    try {
      // Get contact visibility level
      final visibility = await _privacyService.getContactVisibility(
        viewerId: viewerId,
        targetUserId: userId,
      );

      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data()!;

      // Apply privacy filters
      final filteredData = _privacyService.applyPrivacyFilters(
        userData: userData,
        visibility: visibility,
      );

      // Log privacy access
      await _privacyService.logPrivacyAccess(
        viewerId: viewerId,
        targetId: userId,
        accessType: 'profile_view',
        result: visibility.toString(),
      );

      return filteredData;
    } catch (e) {
      debugPrint('Error getting privacy-filtered user profile: $e');
      return null;
    }
  }

  /// Search users with privacy filtering
  Future<List<Map<String, dynamic>>> searchUsersWithPrivacy({
    required String query,
    required String searcherId,
    int limit = 20,
  }) async {
    try {
      // Basic text search (in production, use proper search service)
      final usersQuery = _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .limit(limit * 3); // Get more to account for privacy filtering

      final snapshot = await usersQuery.get();
      final users = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final userData = doc.data();
        final userId = doc.id;

        // Check if user matches search query
        final name = userData['fullName'] as String? ?? '';
        if (!name.toLowerCase().contains(query.toLowerCase())) {
          continue;
        }

        // Check privacy settings
        final preferences = await _privacyService.getUserPrivacyPreferences(userId);
        final showInSearch = preferences['showInSearch'] as bool? ?? true;
        
        if (!showInSearch && userId != searcherId) {
          continue;
        }

        // Get filtered profile data
        final filteredData = await getPrivacyFilteredUserProfile(
          userId: userId,
          viewerId: searcherId,
        );

        if (filteredData != null && filteredData.isNotEmpty) {
          users.add(filteredData);
        }

        if (users.length >= limit) break;
      }

      return users;
    } catch (e) {
      debugPrint('Error searching users with privacy: $e');
      return [];
    }
  }

  /// Get user's network IDs (direct and indirect referrals)
  Future<List<String>> _getUserNetworkIds(String userId) async {
    try {
      final networkIds = <String>{};

      // Get direct referrals
      final directReferralsQuery = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .get();

      for (final doc in directReferralsQuery.docs) {
        networkIds.add(doc.id);
      }

      // Get indirect referrals (up to 2 levels)
      for (final directReferralId in List.from(networkIds)) {
        final indirectReferralsQuery = await _firestore
            .collection('users')
            .where('referredBy', isEqualTo: directReferralId)
            .get();

        for (final doc in indirectReferralsQuery.docs) {
          networkIds.add(doc.id);
        }
      }

      // Get user's referrer and their network
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final referredBy = userDoc.data()?['referredBy'] as String?;
        if (referredBy != null) {
          networkIds.add(referredBy);
          
          // Get referrer's other referrals
          final siblingReferralsQuery = await _firestore
              .collection('users')
              .where('referredBy', isEqualTo: referredBy)
              .get();

          for (final doc in siblingReferralsQuery.docs) {
            if (doc.id != userId) {
              networkIds.add(doc.id);
            }
          }
        }
      }

      return networkIds.toList();
    } catch (e) {
      debugPrint('Error getting user network IDs: $e');
      return [];
    }
  }

  /// Apply search filter to posts
  List<PostModel> _applySearchFilter(List<PostModel> posts, String query) {
    final lowerQuery = query.toLowerCase();
    return posts.where((post) {
      return post.title?.toLowerCase().contains(lowerQuery) == true ||
             post.content.toLowerCase().contains(lowerQuery) ||
             post.hashtags.any((tag) => tag.toLowerCase().contains(lowerQuery)) ||
             post.authorName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Check if user can perform action on content
  Future<bool> canPerformAction({
    required String userId,
    required String contentId,
    required String contentAuthorId,
    required String action, // 'like', 'comment', 'share', 'report'
  }) async {
    try {
      // Get user's privacy preferences
      final preferences = await _privacyService.getUserPrivacyPreferences(contentAuthorId);
      
      switch (action) {
        case 'like':
        case 'share':
          // These actions are generally allowed if user can view content
          return await _privacyService.canViewContent(
            contentId: contentId,
            viewerId: userId,
            contentAuthorId: contentAuthorId,
            contentPrivacy: PrivacyProtectionService.privacyPublic,
          );
        
        case 'comment':
          // Check if comments are allowed on the content
          // This would be stored in the post document
          return true; // Simplified for now
        
        case 'report':
          // Reporting is always allowed
          return true;
        
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Error checking action permission: $e');
      return false;
    }
  }

  /// Get privacy-aware engagement data
  Future<Map<String, dynamic>> getPrivacyAwareEngagementData({
    required String postId,
    required String viewerId,
  }) async {
    try {
      // Get post data
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        return {};
      }

      final post = PostModel.fromFirestore(postDoc);

      // Check if viewer can see engagement details
      final canViewDetails = await _privacyService.canViewContent(
        contentId: postId,
        viewerId: viewerId,
        contentAuthorId: post.authorId,
        contentPrivacy: post.visibility.toString(),
      );

      if (!canViewDetails) {
        // Return limited engagement data
        return {
          'likesCount': post.likesCount,
          'commentsCount': post.commentsCount,
          'sharesCount': post.sharesCount,
          'canViewDetails': false,
        };
      }

      // Return full engagement data
      return {
        'likesCount': post.likesCount,
        'commentsCount': post.commentsCount,
        'sharesCount': post.sharesCount,
        'viewsCount': post.viewsCount,
        'canViewDetails': true,
        'isLikedByCurrentUser': post.isLikedByCurrentUser,
        'isSharedByCurrentUser': post.isSharedByCurrentUser,
      };
    } catch (e) {
      debugPrint('Error getting privacy-aware engagement data: $e');
      return {};
    }
  }

  /// Clean up expired privacy logs
  Future<void> cleanupPrivacyLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      
      final query = _firestore
          .collection('privacy_logs')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate));

      final snapshot = await query.get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Cleaned up ${snapshot.docs.length} expired privacy logs');
    } catch (e) {
      debugPrint('Error cleaning up privacy logs: $e');
    }
  }
}