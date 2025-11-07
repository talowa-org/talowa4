// Recommendation Models for TALOWA Personalization Engine
import 'package:cloud_firestore/cloud_firestore.dart';
import '../social_feed/post_model.dart';

/// User profile for personalization
class UserProfile {
  final String userId;
  final List<String> preferredCategories;
  final String location;
  final List<String> interests;
  final List<String> followedUsers;
  final String language;

  UserProfile({
    required this.userId,
    required this.preferredCategories,
    required this.location,
    required this.interests,
    required this.followedUsers,
    required this.language,
  });

  factory UserProfile.empty(String userId) {
    return UserProfile(
      userId: userId,
      preferredCategories: [],
      location: '',
      interests: [],
      followedUsers: [],
      language: 'en',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'preferredCategories': preferredCategories,
      'location': location,
      'interests': interests,
      'followedUsers': followedUsers,
      'language': language,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] ?? '',
      preferredCategories: List<String>.from(map['preferredCategories'] ?? []),
      location: map['location'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      followedUsers: List<String>.from(map['followedUsers'] ?? []),
      language: map['language'] ?? 'en',
    );
  }
}

/// User behavior profile for personalization
class UserBehaviorProfile {
  final String userId;
  final Map<String, double> categoryPreferences;
  final Map<String, double> topicPreferences;
  final Map<String, double> authorPreferences;
  final Map<int, int> timePatterns; // hour -> count
  final Map<int, int> dayPatterns; // day of week -> count
  final int totalInteractions;
  final DateTime lastUpdated;

  UserBehaviorProfile({
    required this.userId,
    required this.categoryPreferences,
    required this.topicPreferences,
    required this.authorPreferences,
    required this.timePatterns,
    required this.dayPatterns,
    required this.totalInteractions,
    required this.lastUpdated,
  });

  factory UserBehaviorProfile.empty(String userId) {
    return UserBehaviorProfile(
      userId: userId,
      categoryPreferences: {},
      topicPreferences: {},
      authorPreferences: {},
      timePatterns: {},
      dayPatterns: {},
      totalInteractions: 0,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'categoryPreferences': categoryPreferences,
      'topicPreferences': topicPreferences,
      'authorPreferences': authorPreferences,
      'timePatterns': timePatterns.map((k, v) => MapEntry(k.toString(), v)),
      'dayPatterns': dayPatterns.map((k, v) => MapEntry(k.toString(), v)),
      'totalInteractions': totalInteractions,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory UserBehaviorProfile.fromMap(Map<String, dynamic> map) {
    return UserBehaviorProfile(
      userId: map['userId'] ?? '',
      categoryPreferences: Map<String, double>.from(map['categoryPreferences'] ?? {}),
      topicPreferences: Map<String, double>.from(map['topicPreferences'] ?? {}),
      authorPreferences: Map<String, double>.from(map['authorPreferences'] ?? {}),
      timePatterns: (map['timePatterns'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), v as int)) ??
          {},
      dayPatterns: (map['dayPatterns'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), v as int)) ??
          {},
      totalInteractions: map['totalInteractions'] ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Scored post with recommendation score
class ScoredPost {
  final PostModel post;
  final double score;
  final Map<String, double> scoreBreakdown;

  ScoredPost({
    required this.post,
    required this.score,
    required this.scoreBreakdown,
  });

  Map<String, dynamic> toMap() {
    return {
      'post': post.toFirestore(),
      'score': score,
      'scoreBreakdown': scoreBreakdown,
    };
  }
}

/// Similar user for collaborative filtering
class SimilarUser {
  final String userId;
  final double similarity;

  SimilarUser({
    required this.userId,
    required this.similarity,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'similarity': similarity,
    };
  }
}

/// Optimal posting time prediction
class OptimalPostingTime {
  final String userId;
  final List<int> peakHours;
  final List<int> peakDaysOfWeek;
  final DateTime nextOptimalTime;
  final double confidence;
  final int basedOnInteractions;
  final DateTime calculatedAt;

  OptimalPostingTime({
    required this.userId,
    required this.peakHours,
    required this.peakDaysOfWeek,
    required this.nextOptimalTime,
    required this.confidence,
    required this.basedOnInteractions,
    required this.calculatedAt,
  });

  factory OptimalPostingTime.defaultTime(String userId) {
    return OptimalPostingTime(
      userId: userId,
      peakHours: [9, 12, 18, 21],
      peakDaysOfWeek: [1, 3, 5],
      nextOptimalTime: DateTime.now().add(const Duration(hours: 1)),
      confidence: 0.3,
      basedOnInteractions: 0,
      calculatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'peakHours': peakHours,
      'peakDaysOfWeek': peakDaysOfWeek,
      'nextOptimalTime': Timestamp.fromDate(nextOptimalTime),
      'confidence': confidence,
      'basedOnInteractions': basedOnInteractions,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
    };
  }

  factory OptimalPostingTime.fromMap(Map<String, dynamic> map) {
    return OptimalPostingTime(
      userId: map['userId'] ?? '',
      peakHours: List<int>.from(map['peakHours'] ?? []),
      peakDaysOfWeek: List<int>.from(map['peakDaysOfWeek'] ?? []),
      nextOptimalTime: (map['nextOptimalTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confidence: map['confidence'] ?? 0.0,
      basedOnInteractions: map['basedOnInteractions'] ?? 0,
      calculatedAt: (map['calculatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Trending topic with geographic awareness
class TrendingTopic {
  final String topic;
  final int mentions;
  final int engagement;
  final double trendingScore;
  final double velocity;
  final String? location;
  final Duration timeWindow;
  final DateTime calculatedAt;

  TrendingTopic({
    required this.topic,
    required this.mentions,
    required this.engagement,
    required this.trendingScore,
    required this.velocity,
    this.location,
    required this.timeWindow,
    required this.calculatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'mentions': mentions,
      'engagement': engagement,
      'trendingScore': trendingScore,
      'velocity': velocity,
      'location': location,
      'timeWindowHours': timeWindow.inHours,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
    };
  }

  factory TrendingTopic.fromMap(Map<String, dynamic> map) {
    return TrendingTopic(
      topic: map['topic'] ?? '',
      mentions: map['mentions'] ?? 0,
      engagement: map['engagement'] ?? 0,
      trendingScore: map['trendingScore'] ?? 0.0,
      velocity: map['velocity'] ?? 0.0,
      location: map['location'],
      timeWindow: Duration(hours: map['timeWindowHours'] ?? 24),
      calculatedAt: (map['calculatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Topic score for trending calculation
class TopicScore {
  final String topic;
  int mentions = 0;
  int totalEngagement = 0;

  TopicScore({required this.topic});

  void incrementMentions() {
    mentions++;
  }

  void addEngagement(int engagement) {
    totalEngagement += engagement;
  }
}

/// Engagement prediction for posts
class EngagementPrediction {
  final String postId;
  final String? userId;
  final double likeProbability;
  final double commentProbability;
  final double shareProbability;
  final int estimatedLikes;
  final int estimatedComments;
  final int estimatedShares;
  final double overallEngagementScore;
  final double confidence;
  final DateTime predictedAt;

  EngagementPrediction({
    required this.postId,
    this.userId,
    required this.likeProbability,
    required this.commentProbability,
    required this.shareProbability,
    required this.estimatedLikes,
    required this.estimatedComments,
    required this.estimatedShares,
    required this.overallEngagementScore,
    required this.confidence,
    required this.predictedAt,
  });

  factory EngagementPrediction.defaultPrediction(String postId, String? userId) {
    return EngagementPrediction(
      postId: postId,
      userId: userId,
      likeProbability: 0.5,
      commentProbability: 0.3,
      shareProbability: 0.2,
      estimatedLikes: 5,
      estimatedComments: 2,
      estimatedShares: 1,
      overallEngagementScore: 0.5,
      confidence: 0.5,
      predictedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'likeProbability': likeProbability,
      'commentProbability': commentProbability,
      'shareProbability': shareProbability,
      'estimatedLikes': estimatedLikes,
      'estimatedComments': estimatedComments,
      'estimatedShares': estimatedShares,
      'overallEngagementScore': overallEngagementScore,
      'confidence': confidence,
      'predictedAt': Timestamp.fromDate(predictedAt),
    };
  }

  factory EngagementPrediction.fromMap(Map<String, dynamic> map) {
    return EngagementPrediction(
      postId: map['postId'] ?? '',
      userId: map['userId'],
      likeProbability: map['likeProbability'] ?? 0.0,
      commentProbability: map['commentProbability'] ?? 0.0,
      shareProbability: map['shareProbability'] ?? 0.0,
      estimatedLikes: map['estimatedLikes'] ?? 0,
      estimatedComments: map['estimatedComments'] ?? 0,
      estimatedShares: map['estimatedShares'] ?? 0,
      overallEngagementScore: map['overallEngagementScore'] ?? 0.0,
      confidence: map['confidence'] ?? 0.0,
      predictedAt: (map['predictedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Post features for ML models
class PostFeatures {
  final int contentLength;
  final bool hasImages;
  final bool hasVideos;
  final int hashtagCount;
  final bool hasTitle;
  final String category;
  final String location;
  final String authorRole;
  final DateTime createdAt;

  PostFeatures({
    required this.contentLength,
    required this.hasImages,
    required this.hasVideos,
    required this.hashtagCount,
    required this.hasTitle,
    required this.category,
    required this.location,
    required this.authorRole,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'contentLength': contentLength,
      'hasImages': hasImages,
      'hasVideos': hasVideos,
      'hashtagCount': hashtagCount,
      'hasTitle': hasTitle,
      'category': category,
      'location': location,
      'authorRole': authorRole,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Engagement patterns for user analysis
class EngagementPatterns {
  final Map<int, int> hourlyEngagement;
  final Map<int, int> dailyEngagement;
  final int totalInteractions;

  EngagementPatterns({
    required this.hourlyEngagement,
    required this.dailyEngagement,
    required this.totalInteractions,
  });

  factory EngagementPatterns.empty() {
    return EngagementPatterns(
      hourlyEngagement: {},
      dailyEngagement: {},
      totalInteractions: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hourlyEngagement': hourlyEngagement.map((k, v) => MapEntry(k.toString(), v)),
      'dailyEngagement': dailyEngagement.map((k, v) => MapEntry(k.toString(), v)),
      'totalInteractions': totalInteractions,
    };
  }
}

/// A/B test assignment
class ABTestAssignment {
  final String testName;
  final String userId;
  final String variant;
  final DateTime assignedAt;

  ABTestAssignment({
    required this.testName,
    required this.userId,
    required this.variant,
    required this.assignedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'testName': testName,
      'userId': userId,
      'variant': variant,
      'assignedAt': Timestamp.fromDate(assignedAt),
    };
  }

  factory ABTestAssignment.fromMap(Map<String, dynamic> map) {
    return ABTestAssignment(
      testName: map['testName'] ?? '',
      userId: map['userId'] ?? '',
      variant: map['variant'] ?? '',
      assignedAt: (map['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// A/B test result
class ABTestResult {
  final String testName;
  final String variant;
  final List<PostModel> recommendations;
  final ABTestAssignment assignment;

  ABTestResult({
    required this.testName,
    required this.variant,
    required this.recommendations,
    required this.assignment,
  });

  factory ABTestResult.defaultResult(String testName, List<PostModel> posts) {
    return ABTestResult(
      testName: testName,
      variant: 'default',
      recommendations: posts,
      assignment: ABTestAssignment(
        testName: testName,
        userId: '',
        variant: 'default',
        assignedAt: DateTime.now(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'testName': testName,
      'variant': variant,
      'recommendations': recommendations.map((p) => p.toFirestore()).toList(),
      'assignment': assignment.toMap(),
    };
  }
}

/// A/B test metrics
class ABTestMetrics {
  final String variant;
  final int impressions;
  final int clicks;
  final int likes;
  final int comments;
  final int shares;
  final double timeSpent;
  final double conversionRate;

  ABTestMetrics({
    required this.variant,
    required this.impressions,
    required this.clicks,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.timeSpent,
    required this.conversionRate,
  });

  double get clickThroughRate => impressions > 0 ? clicks / impressions : 0.0;
  double get engagementRate => impressions > 0 ? (likes + comments + shares) / impressions : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'variant': variant,
      'impressions': impressions,
      'clicks': clicks,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'timeSpent': timeSpent,
      'conversionRate': conversionRate,
      'clickThroughRate': clickThroughRate,
      'engagementRate': engagementRate,
    };
  }

  factory ABTestMetrics.fromMap(Map<String, dynamic> map) {
    return ABTestMetrics(
      variant: map['variant'] ?? '',
      impressions: map['impressions'] ?? 0,
      clicks: map['clicks'] ?? 0,
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      shares: map['shares'] ?? 0,
      timeSpent: map['timeSpent'] ?? 0.0,
      conversionRate: map['conversionRate'] ?? 0.0,
    );
  }
}

/// Recommendation algorithm interface
abstract class RecommendationAlgorithm {
  Future<List<PostModel>> recommend(
    List<PostModel> candidatePosts,
    String userId,
    int limit,
  );
}
