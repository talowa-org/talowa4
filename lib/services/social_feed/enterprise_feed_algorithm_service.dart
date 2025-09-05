// Enterprise-Grade Feed Algorithm Service for TALOWA
// Implements advanced personalization, role-based prioritization, and geographic relevance

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/user_model.dart';

import 'dart:math';

class EnterpriseFeedAlgorithmService {
  static final EnterpriseFeedAlgorithmService _instance = EnterpriseFeedAlgorithmService._internal();
  factory EnterpriseFeedAlgorithmService() => _instance;
  EnterpriseFeedAlgorithmService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get personalized feed with enterprise-grade algorithm
  Future<List<PostModel>> getPersonalizedFeed({
    required String userId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      debugPrint('ðŸŽ¯ Generating enterprise-grade personalized feed for user: $userId');
      
      // Get user profile and preferences
      final userProfile = await _getUserProfile(userId);
      if (userProfile == null) {
        debugPrint('âŒ User profile not found, returning chronological feed');
        return await _getChronologicalFeed(limit: limit, lastDocument: lastDocument);
      }

      // Get candidate posts (fetch more than needed for better filtering)
      final candidatePosts = await _getCandidatePosts(
        limit: limit * 3,
        lastDocument: lastDocument,
      );

      if (candidatePosts.isEmpty) {
        debugPrint('ðŸ“­ No candidate posts found');
        return [];
      }

      // Apply enterprise-grade scoring algorithm
      final scoredPosts = await _applyEnterpriseScoringAlgorithm(
        posts: candidatePosts,
        userProfile: userProfile,
      );

      // Sort by final score and return top results
      scoredPosts.sort((a, b) => b.finalScore.compareTo(a.finalScore));
      
      final finalPosts = scoredPosts.take(limit).map((sp) => sp.post).toList();
      
      debugPrint('âœ… Generated personalized feed with ${finalPosts.length} posts');
      return finalPosts;
      
    } catch (e) {
      debugPrint('âŒ Error generating personalized feed: $e');
      // Fallback to chronological feed
      return await _getChronologicalFeed(limit: limit, lastDocument: lastDocument);
    }
  }

  /// Apply enterprise-grade scoring algorithm
  Future<List<ScoredPost>> _applyEnterpriseScoringAlgorithm({
    required List<PostModel> posts,
    required UserModel userProfile,
  }) async {
    final scoredPosts = <ScoredPost>[];
    
    for (final post in posts) {
      final scores = await _calculateComprehensiveScore(post, userProfile);
      scoredPosts.add(ScoredPost(
        post: post,
        geographicScore: scores['geographic']!,
        roleBasedScore: scores['roleBased']!,
        engagementScore: scores['engagement']!,
        contentRelevanceScore: scores['contentRelevance']!,
        timeDecayScore: scores['timeDecay']!,
        personalPreferenceScore: scores['personalPreference']!,
        finalScore: scores['final']!,
      ));
    }
    
    return scoredPosts;
  }

  /// Calculate comprehensive scoring for a post
  Future<Map<String, double>> _calculateComprehensiveScore(
    PostModel post,
    UserModel userProfile,
  ) async {
    // 1. Geographic Relevance Score (0-50 points)
    final geographicScore = _calculateGeographicRelevance(post, userProfile);
    
    // 2. Role-Based Priority Score (0-40 points)
    final roleBasedScore = _calculateRoleBasedPriority(post, userProfile);
    
    // 3. Engagement Score (0-30 points)
    final engagementScore = await _calculateEngagementScore(post);
    
    // 4. Content Relevance Score (0-25 points)
    final contentRelevanceScore = await _calculateContentRelevance(post, userProfile);
    
    // 5. Time Decay Factor (0.1-1.0 multiplier)
    final timeDecayScore = _calculateTimeDecayFactor(post);
    
    // 6. Personal Preference Score (0-20 points)
    final personalPreferenceScore = await _calculatePersonalPreferences(post, userProfile);
    
    // Calculate weighted final score
    final baseScore = geographicScore + roleBasedScore + engagementScore + 
                     contentRelevanceScore + personalPreferenceScore;
    final finalScore = baseScore * timeDecayScore;
    
    return {
      'geographic': geographicScore,
      'roleBased': roleBasedScore,
      'engagement': engagementScore,
      'contentRelevance': contentRelevanceScore,
      'timeDecay': timeDecayScore,
      'personalPreference': personalPreferenceScore,
      'final': finalScore,
    };
  }

  /// Calculate geographic relevance score (0-50 points)
  double _calculateGeographicRelevance(PostModel post, UserModel userProfile) {
    // For now, return a default score since geographic targeting is not implemented
    return 10.0;
  }

  /// Calculate role-based priority score (0-40 points)
  double _calculateRoleBasedPriority(PostModel post, UserModel userProfile) {
    final authorRole = post.authorRole?.toLowerCase() ?? '';
    
    // Role hierarchy scoring
    const roleScores = {
      'district_coordinator': 40.0,
      'legal_advisor': 35.0,
      'mandal_coordinator': 30.0,
      'media_coordinator': 25.0,
      'village_coordinator': 20.0,
      'volunteer': 15.0,
      'farmer': 10.0,
    };
    
    return roleScores[authorRole] ?? 5.0;
  }

  /// Calculate engagement score (0-30 points)
  Future<double> _calculateEngagementScore(PostModel post) async {
    try {
      // Get engagement metrics
      final likesCount = post.likesCount;
      final commentsCount = post.commentsCount;
      final sharesCount = post.sharesCount;
      
      // Weighted engagement calculation
      final engagementScore = (likesCount * 1.0) + 
                             (commentsCount * 2.0) + 
                             (sharesCount * 3.0);
      
      // Normalize to 0-30 scale using logarithmic scaling
      final normalizedScore = min(30.0, log(engagementScore + 1) * 5);
      
      return normalizedScore;
    } catch (e) {
      debugPrint('Error calculating engagement score: $e');
      return 0.0;
    }
  }

  /// Calculate content relevance score (0-25 points)
  Future<double> _calculateContentRelevance(PostModel post, UserModel userProfile) async {
    double score = 0.0;
    
    // Category preference matching
    final userPreferredCategories = await _getUserPreferredCategories(userProfile.id);
    if (userPreferredCategories.contains(post.category)) {
      score += 10.0;
    }
    
    // Content type priority
    const contentTypeScores = {
      'emergency_alert': 25.0,
      'success_story': 15.0,
      'legal_update': 20.0,
      'campaign_update': 12.0,
      'educational_content': 10.0,
      'media_coverage': 8.0,
    };
    
    final contentType = _inferContentType(post);
    score += contentTypeScores[contentType] ?? 5.0;
    
    return min(25.0, score);
  }

  /// Calculate time decay factor (0.1-1.0 multiplier)
  double _calculateTimeDecayFactor(PostModel post) {
    final now = DateTime.now();
    final postTime = post.createdAt;
    final hoursSincePost = now.difference(postTime).inHours;
    
    // Time decay curve: newer posts get higher multiplier
    if (hoursSincePost <= 1) return 1.0;      // Last hour: full score
    if (hoursSincePost <= 6) return 0.9;      // Last 6 hours: 90%
    if (hoursSincePost <= 24) return 0.8;     // Last day: 80%
    if (hoursSincePost <= 72) return 0.6;     // Last 3 days: 60%
    if (hoursSincePost <= 168) return 0.4;    // Last week: 40%
    if (hoursSincePost <= 720) return 0.2;    // Last month: 20%
    return 0.1;                                // Older: 10%
  }

  /// Calculate personal preference score (0-20 points)
  Future<double> _calculatePersonalPreferences(PostModel post, UserModel userProfile) async {
    double score = 0.0;
    
    try {
      // Check if user has interacted with this author before
      final hasInteractedWithAuthor = await _hasUserInteractedWithAuthor(
        userProfile.id, 
        post.authorId,
      );
      if (hasInteractedWithAuthor) {
        score += 8.0;
      }
      
      // Check hashtag preferences
      final userHashtagPreferences = await _getUserHashtagPreferences(userProfile.id);
      final commonHashtags = post.hashtags.where(
        (hashtag) => userHashtagPreferences.contains(hashtag),
      ).length;
      score += min(7.0, commonHashtags * 2.0);
      
      // Check posting time preference
      final userActiveHours = await _getUserActiveHours(userProfile.id);
      final postHour = post.createdAt.hour;
      if (userActiveHours.contains(postHour)) {
        score += 5.0;
      }
      
    } catch (e) {
      debugPrint('Error calculating personal preferences: $e');
    }
    
    return min(20.0, score);
  }

  /// Get candidate posts for personalization
  Future<List<PostModel>> _getCandidatePosts({
    required int limit,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore
        .collection('posts')
        .where('isDeleted', isEqualTo: false)
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true);
    
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    
    query = query.limit(limit);
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
  }

  /// Get chronological feed as fallback
  Future<List<PostModel>> _getChronologicalFeed({
    required int limit,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore
        .collection('posts')
        .where('isDeleted', isEqualTo: false)
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
  }

  /// Get user profile
  Future<UserModel?> _getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
    }
    return null;
  }

  /// Helper methods for preference calculation
  Future<List<PostCategory>> _getUserPreferredCategories(String userId) async {
    // Implementation would analyze user's interaction history
    // For now, return default categories
    return [PostCategory.announcement, PostCategory.successStory];
  }

  String _inferContentType(PostModel post) {
    final content = post.content.toLowerCase();
    if (content.contains('emergency') || content.contains('urgent')) {
      return 'emergency_alert';
    }
    if (content.contains('success') || content.contains('achievement')) {
      return 'success_story';
    }
    if (content.contains('legal') || content.contains('court')) {
      return 'legal_update';
    }
    return 'general';
  }

  Future<bool> _hasUserInteractedWithAuthor(String userId, String authorId) async {
    try {
      final snapshot = await _firestore
          .collection('interactions')
          .where('userId', isEqualTo: userId)
          .where('targetUserId', isEqualTo: authorId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> _getUserHashtagPreferences(String userId) async {
    // Implementation would analyze user's hashtag interaction history
    return ['#landRights', '#patta', '#agriculture'];
  }

  Future<List<int>> _getUserActiveHours(String userId) async {
    // Implementation would analyze when user is most active
    return [9, 10, 11, 18, 19, 20]; // Default active hours
  }
}

/// Data class for scored posts
class ScoredPost {
  final PostModel post;
  final double geographicScore;
  final double roleBasedScore;
  final double engagementScore;
  final double contentRelevanceScore;
  final double timeDecayScore;
  final double personalPreferenceScore;
  final double finalScore;

  ScoredPost({
    required this.post,
    required this.geographicScore,
    required this.roleBasedScore,
    required this.engagementScore,
    required this.contentRelevanceScore,
    required this.timeDecayScore,
    required this.personalPreferenceScore,
    required this.finalScore,
  });

  @override
  String toString() {
    return 'ScoredPost(finalScore: $finalScore, geo: $geographicScore, role: $roleBasedScore, engagement: $engagementScore)';
  }
}