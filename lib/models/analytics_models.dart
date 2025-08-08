// Analytics Data Models for TALOWA
// Implements Task 23: Implement content analytics - Data Models

class PostAnalytics {
  final String postId;
  final Map<String, dynamic> postData;
  final EngagementMetrics engagementMetrics;
  final ReachMetrics reachMetrics;
  final ImpressionMetrics impressionMetrics;
  final DemographicsData demographics;
  final double performanceScore;
  final DateRange dateRange;
  final DateTime generatedAt;

  PostAnalytics({
    required this.postId,
    required this.postData,
    required this.engagementMetrics,
    required this.reachMetrics,
    required this.impressionMetrics,
    required this.demographics,
    required this.performanceScore,
    required this.dateRange,
    required this.generatedAt,
  });
}

class EngagementMetrics {
  final int likes;
  final int comments;
  final int shares;
  final int clicks;
  final int totalEngagements;
  final double engagementRate;
  final double averageTimeSpent;

  EngagementMetrics({
    required this.likes,
    required this.comments,
    required this.shares,
    required this.clicks,
    required this.totalEngagements,
    required this.engagementRate,
    required this.averageTimeSpent,
  });

  static EngagementMetrics empty() {
    return EngagementMetrics(
      likes: 0,
      comments: 0,
      shares: 0,
      clicks: 0,
      totalEngagements: 0,
      engagementRate: 0.0,
      averageTimeSpent: 0.0,
    );
  }
}

class ReachMetrics {
  final int totalReach;
  final int organicReach;
  final int viralReach;
  final double reachRate;
  final int uniqueUsers;

  ReachMetrics({
    required this.totalReach,
    required this.organicReach,
    required this.viralReach,
    required this.reachRate,
    required this.uniqueUsers,
  });

  static ReachMetrics empty() {
    return ReachMetrics(
      totalReach: 0,
      organicReach: 0,
      viralReach: 0,
      reachRate: 0.0,
      uniqueUsers: 0,
    );
  }
}

class ImpressionMetrics {
  final int totalImpressions;
  final int uniqueImpressions;
  final double impressionRate;
  final double viewThroughRate;

  ImpressionMetrics({
    required this.totalImpressions,
    required this.uniqueImpressions,
    required this.impressionRate,
    required this.viewThroughRate,
  });

  static ImpressionMetrics empty() {
    return ImpressionMetrics(
      totalImpressions: 0,
      uniqueImpressions: 0,
      impressionRate: 0.0,
      viewThroughRate: 0.0,
    );
  }
}

class DemographicsData {
  final Map<String, int> ageGroups;
  final Map<String, int> genders;
  final Map<String, int> locations;
  final Map<String, int> roles;
  final int totalUsers;

  DemographicsData({
    required this.ageGroups,
    required this.genders,
    required this.locations,
    required this.roles,
    required this.totalUsers,
  });

  static DemographicsData empty() {
    return DemographicsData(
      ageGroups: {},
      genders: {},
      locations: {},
      roles: {},
      totalUsers: 0,
    );
  }
}

class ContentEffectivenessInsights {
  final List<PostPerformance> topPerformingContent;
  final List<ContentTrend> contentTrends;
  final List<OptimalTime> optimalPostingTimes;
  final List<ContentRecommendation> recommendations;
  final DateRange dateRange;
  final DateTime generatedAt;

  ContentEffectivenessInsights({
    required this.topPerformingContent,
    required this.contentTrends,
    required this.optimalPostingTimes,
    required this.recommendations,
    required this.dateRange,
    required this.generatedAt,
  });
}

class PostPerformance {
  final String postId;
  final String title;
  final int engagementCount;
  final int viewCount;
  final int shareCount;
  final double performanceScore;
  final DateTime createdAt;

  PostPerformance({
    required this.postId,
    required this.title,
    required this.engagementCount,
    required this.viewCount,
    required this.shareCount,
    required this.performanceScore,
    required this.createdAt,
  });
}

class ContentTrend {
  final String trendType;
  final double value;
  final double change;
  final String period;
  final String description;

  ContentTrend({
    required this.trendType,
    required this.value,
    required this.change,
    required this.period,
    required this.description,
  });
}

class OptimalTime {
  final String dayOfWeek;
  final int hour;
  final double engagementRate;
  final double confidence;

  OptimalTime({
    required this.dayOfWeek,
    required this.hour,
    required this.engagementRate,
    required this.confidence,
  });
}

class ContentRecommendation {
  final String type;
  final String recommendation;
  final String reason;
  final double confidence;
  final double expectedImpact;

  ContentRecommendation({
    required this.type,
    required this.recommendation,
    required this.reason,
    required this.confidence,
    required this.expectedImpact,
  });
}

class MovementAnalytics {
  final GrowthMetrics growthMetrics;
  final List<EngagementTrend> engagementTrends;
  final List<CampaignMetrics> campaignEffectiveness;
  final GeographicDistribution geographicDistribution;
  final DateRange dateRange;
  final DateTime generatedAt;

  MovementAnalytics({
    required this.growthMetrics,
    required this.engagementTrends,
    required this.campaignEffectiveness,
    required this.geographicDistribution,
    required this.dateRange,
    required this.generatedAt,
  });
}

class GrowthMetrics {
  final int newUsers;
  final int activeUsers;
  final double retentionRate;
  final double growthRate;
  final double churnRate;

  GrowthMetrics({
    required this.newUsers,
    required this.activeUsers,
    required this.retentionRate,
    required this.growthRate,
    required this.churnRate,
  });

  static GrowthMetrics empty() {
    return GrowthMetrics(
      newUsers: 0,
      activeUsers: 0,
      retentionRate: 0.0,
      growthRate: 0.0,
      churnRate: 0.0,
    );
  }
}

class EngagementTrend {
  final DateTime date;
  final int likes;
  final int comments;
  final int shares;
  final int totalEngagement;

  EngagementTrend({
    required this.date,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.totalEngagement,
  });
}

class CampaignMetrics {
  final String campaignId;
  final String campaignName;
  final int reach;
  final int engagement;
  final int conversions;
  final double roi;

  CampaignMetrics({
    required this.campaignId,
    required this.campaignName,
    required this.reach,
    required this.engagement,
    required this.conversions,
    required this.roi,
  });
}

class GeographicDistribution {
  final Map<String, int> regions;
  final List<String> topRegions;
  final int totalUsers;

  GeographicDistribution({
    required this.regions,
    required this.topRegions,
    required this.totalUsers,
  });

  static GeographicDistribution empty() {
    return GeographicDistribution(
      regions: {},
      topRegions: [],
      totalUsers: 0,
    );
  }
}

class RealTimeAnalytics {
  final RealTimeEngagement engagement;
  final RealTimeUserActivity userActivity;
  final RealTimeContentMetrics contentMetrics;
  final List<TrendingTopic> trendingTopics;
  final DateTime lastUpdated;

  RealTimeAnalytics({
    required this.engagement,
    required this.userActivity,
    required this.contentMetrics,
    required this.trendingTopics,
    required this.lastUpdated,
  });
}

class RealTimeEngagement {
  final int likes;
  final int comments;
  final int shares;
  final int total;
  final double rate;

  RealTimeEngagement({
    required this.likes,
    required this.comments,
    required this.shares,
    required this.total,
    required this.rate,
  });

  static RealTimeEngagement empty() {
    return RealTimeEngagement(
      likes: 0,
      comments: 0,
      shares: 0,
      total: 0,
      rate: 0.0,
    );
  }
}

class RealTimeUserActivity {
  final int activeUsers;
  final int newUsers;
  final int sessions;
  final double averageSessionDuration;

  RealTimeUserActivity({
    required this.activeUsers,
    required this.newUsers,
    required this.sessions,
    required this.averageSessionDuration,
  });

  static RealTimeUserActivity empty() {
    return RealTimeUserActivity(
      activeUsers: 0,
      newUsers: 0,
      sessions: 0,
      averageSessionDuration: 0.0,
    );
  }
}

class RealTimeContentMetrics {
  final int newPosts;
  final int totalViews;
  final int totalEngagements;
  final double averageEngagementRate;

  RealTimeContentMetrics({
    required this.newPosts,
    required this.totalViews,
    required this.totalEngagements,
    required this.averageEngagementRate,
  });

  static RealTimeContentMetrics empty() {
    return RealTimeContentMetrics(
      newPosts: 0,
      totalViews: 0,
      totalEngagements: 0,
      averageEngagementRate: 0.0,
    );
  }
}

class TrendingTopic {
  final String topic;
  final int mentions;
  final double growth;
  final double sentiment;

  TrendingTopic({
    required this.topic,
    required this.mentions,
    required this.growth,
    required this.sentiment,
  });
}

class ABTestResult {
  final String testId;
  final String testName;
  final ABTestStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final ABVariantResult variantAResults;
  final ABVariantResult variantBResults;
  final double statisticalSignificance;
  final String? winningVariant;

  ABTestResult({
    required this.testId,
    required this.testName,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.variantAResults,
    required this.variantBResults,
    required this.statisticalSignificance,
    this.winningVariant,
  });
}

class ABVariantResult {
  final int participants;
  final int conversions;
  final double conversionRate;
  final double confidence;

  ABVariantResult({
    required this.participants,
    required this.conversions,
    required this.conversionRate,
    required this.confidence,
  });

  static ABVariantResult empty() {
    return ABVariantResult(
      participants: 0,
      conversions: 0,
      conversionRate: 0.0,
      confidence: 0.0,
    );
  }
}

enum ABTestStatus {
  running,
  completed,
  cancelled,
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  int get durationInDays => end.difference(start).inDays;
}