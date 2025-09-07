// Analytics Models - Data models for analytics and insights
// Complete analytics data structures for TALOWA platform


// User Analytics Model
class UserAnalyticsModel {
  final String userId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final EngagementMetrics engagementMetrics;
  final ContentMetrics contentMetrics;
  final SearchMetrics searchMetrics;
  final ActivismMetrics activismMetrics;
  final GrowthMetrics growthMetrics;
  final DateTime generatedAt;

  const UserAnalyticsModel({
    required this.userId,
    required this.periodStart,
    required this.periodEnd,
    required this.engagementMetrics,
    required this.contentMetrics,
    required this.searchMetrics,
    required this.activismMetrics,
    required this.growthMetrics,
    required this.generatedAt,
  });
}

// Platform Analytics Model
class PlatformAnalyticsModel {
  final DateTime periodStart;
  final DateTime periodEnd;
  final PlatformUserMetrics userMetrics;
  final PlatformContentMetrics contentMetrics;
  final PlatformEngagementMetrics engagementMetrics;
  final PlatformSearchMetrics searchMetrics;
  final PlatformActivismMetrics activismMetrics;
  final DateTime generatedAt;

  const PlatformAnalyticsModel({
    required this.periodStart,
    required this.periodEnd,
    required this.userMetrics,
    required this.contentMetrics,
    required this.engagementMetrics,
    required this.searchMetrics,
    required this.activismMetrics,
    required this.generatedAt,
  });
}

// Engagement Metrics
class EngagementMetrics {
  final int totalEvents;
  final int uniqueSessions;
  final double averageSessionDuration;
  final double engagementRate;
  final List<String> topActions;

  const EngagementMetrics({
    required this.totalEvents,
    required this.uniqueSessions,
    required this.averageSessionDuration,
    required this.engagementRate,
    required this.topActions,
  });
}

// Content Metrics
class ContentMetrics {
  final int totalPosts;
  final int totalViews;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final double averageEngagementRate;
  final List<String> topPerformingContent;

  const ContentMetrics({
    required this.totalPosts,
    required this.totalViews,
    required this.totalLikes,
    required this.totalComments,
    required this.totalShares,
    required this.averageEngagementRate,
    required this.topPerformingContent,
  });
}

// Search Metrics
class SearchMetrics {
  final int totalSearches;
  final int uniqueQueries;
  final double averageResultsCount;
  final double clickThroughRate;
  final List<String> topQueries;
  final Map<String, int> searchTypeDistribution;

  const SearchMetrics({
    required this.totalSearches,
    required this.uniqueQueries,
    required this.averageResultsCount,
    required this.clickThroughRate,
    required this.topQueries,
    required this.searchTypeDistribution,
  });
}

// Activism Metrics
class ActivismMetrics {
  final int totalImpactEvents;
  final int totalBeneficiaries;
  final double impactScore;
  final int casesSupported;
  final int campaignsParticipated;
  final Map<String, int> impactCategoryDistribution;

  const ActivismMetrics({
    required this.totalImpactEvents,
    required this.totalBeneficiaries,
    required this.impactScore,
    required this.casesSupported,
    required this.campaignsParticipated,
    required this.impactCategoryDistribution,
  });
}

// Growth Metrics
class GrowthMetrics {
  final List<GrowthDataPoint> followerGrowth;
  final List<GrowthDataPoint> reachGrowth;
  final List<GrowthDataPoint> engagementGrowth;

  const GrowthMetrics({
    required this.followerGrowth,
    required this.reachGrowth,
    required this.engagementGrowth,
  });
}

// Growth Data Point
class GrowthDataPoint {
  final DateTime date;
  final double value;

  const GrowthDataPoint({
    required this.date,
    required this.value,
  });
}

// Platform User Metrics
class PlatformUserMetrics {
  final int totalUsers;
  final int activeUsers;
  final int newUsers;
  final double retentionRate;

  const PlatformUserMetrics({
    required this.totalUsers,
    required this.activeUsers,
    required this.newUsers,
    required this.retentionRate,
  });
}

// Platform Content Metrics
class PlatformContentMetrics {
  final int totalPosts;
  final int totalViews;
  final int totalEngagements;
  final double averageEngagementRate;

  const PlatformContentMetrics({
    required this.totalPosts,
    required this.totalViews,
    required this.totalEngagements,
    required this.averageEngagementRate,
  });
}

// Platform Engagement Metrics
class PlatformEngagementMetrics {
  final int totalSessions;
  final double averageSessionDuration;
  final double bounceRate;
  final int pageViews;

  const PlatformEngagementMetrics({
    required this.totalSessions,
    required this.averageSessionDuration,
    required this.bounceRate,
    required this.pageViews,
  });
}

// Platform Search Metrics
class PlatformSearchMetrics {
  final int totalSearches;
  final int uniqueQueries;
  final double averageClickThroughRate;
  final double searchSuccessRate;

  const PlatformSearchMetrics({
    required this.totalSearches,
    required this.uniqueQueries,
    required this.averageClickThroughRate,
    required this.searchSuccessRate,
  });
}

// Platform Activism Metrics
class PlatformActivismMetrics {
  final int totalCases;
  final int resolvedCases;
  final int totalBeneficiaries;
  final double impactScore;

  const PlatformActivismMetrics({
    required this.totalCases,
    required this.resolvedCases,
    required this.totalBeneficiaries,
    required this.impactScore,
  });
}

// Event Models for Tracking

// Engagement Event
class EngagementEvent {
  final EngagementEventType type;
  final String category;
  final String action;
  final String? label;
  final int? value;
  final Map<String, dynamic>? metadata;
  final String sessionId;
  final Map<String, dynamic>? deviceInfo;
  final Map<String, dynamic>? location;

  const EngagementEvent({
    required this.type,
    required this.category,
    required this.action,
    this.label,
    this.value,
    this.metadata,
    required this.sessionId,
    this.deviceInfo,
    this.location,
  });
}

enum EngagementEventType {
  pageView,
  click,
  scroll,
  search,
  share,
  like,
  comment,
  follow,
  download,
  signup,
  login,
}

// Content Performance Event
class ContentPerformanceEvent {
  final String contentId;
  final String contentType;
  final String authorId;
  final ContentPerformanceMetric metric;
  final int value;
  final Map<String, dynamic>? metadata;

  const ContentPerformanceEvent({
    required this.contentId,
    required this.contentType,
    required this.authorId,
    required this.metric,
    required this.value,
    this.metadata,
  });
}

enum ContentPerformanceMetric {
  view,
  like,
  comment,
  share,
  save,
  report,
  click,
}

// Search Analytics Event
class SearchAnalyticsEvent {
  final String query;
  final SearchAnalyticsType searchType;
  final int resultsCount;
  final int? clickedResultIndex;
  final String? clickedResultId;
  final int searchDuration;
  final Map<String, dynamic>? filters;
  final Map<String, dynamic>? metadata;

  const SearchAnalyticsEvent({
    required this.query,
    required this.searchType,
    required this.resultsCount,
    this.clickedResultIndex,
    this.clickedResultId,
    required this.searchDuration,
    this.filters,
    this.metadata,
  });
}

enum SearchAnalyticsType {
  universal,
  posts,
  users,
  legal,
  news,
  professionals,
  ai,
  voice,
}

// Activism Impact Event
class ActivismImpactEvent {
  final String userId;
  final ActivismImpactType impactType;
  final String impactCategory;
  final double impactValue;
  final int beneficiaries;
  final Map<String, dynamic>? location;
  final String? caseId;
  final String? campaignId;
  final Map<String, dynamic>? metadata;

  const ActivismImpactEvent({
    required this.userId,
    required this.impactType,
    required this.impactCategory,
    required this.impactValue,
    required this.beneficiaries,
    this.location,
    this.caseId,
    this.campaignId,
    this.metadata,
  });
}

enum ActivismImpactType {
  caseResolution,
  legalAdvice,
  communitySupport,
  awarenessRaising,
  policyAdvocacy,
  resourceSharing,
  networkBuilding,
  capacityBuilding,
}

