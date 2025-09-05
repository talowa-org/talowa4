// Algolia Configuration - Production-ready search service configuration
// Complete Algolia setup for TALOWA land rights activism platform

class AlgoliaConfig {
  // Algolia Application ID and API Keys
  // Production keys - replace with actual Algolia credentials
  static const String applicationId = 'TALOWA001';
  static const String searchApiKey = 'search_key_placeholder';
  static const String adminApiKey = 'admin_key_placeholder'; // Server-side only

  // Algolia App Configuration
  static const String appName = 'TALOWA Land Rights Platform';
  static const String appVersion = '1.0.0';
  
  // Index Names for Different Content Types
  static const String postsIndex = 'talowa_posts';
  static const String usersIndex = 'talowa_users';
  static const String legalCasesIndex = 'talowa_legal_cases';
  static const String newsIndex = 'talowa_news';
  static const String professionalsIndex = 'talowa_professionals';
  static const String campaignsIndex = 'talowa_campaigns';
  static const String organizationsIndex = 'talowa_organizations';
  static const String landRecordsIndex = 'talowa_land_records';
  
  // Search Configuration
  static const int defaultHitsPerPage = 20;
  static const int maxHitsPerPage = 100;
  static const int searchTimeout = 5000; // milliseconds
  
  // Facet Configuration
  static const List<String> defaultFacets = [
    'category',
    'location.state',
    'location.district',
    'location.mandal',
    'type',
    'status',
    'priority',
    'createdAt',
  ];
  
  // Searchable Attributes Configuration
  static const Map<String, List<String>> searchableAttributes = {
    postsIndex: [
      'title',
      'content',
      'tags',
      'authorName',
      'location.state',
      'location.district',
      'location.mandal',
    ],
    usersIndex: [
      'name',
      'bio',
      'profession',
      'specialization',
      'location.state',
      'location.district',
      'skills',
    ],
    legalCasesIndex: [
      'title',
      'description',
      'caseNumber',
      'court',
      'location.state',
      'location.district',
      'tags',
      'status',
    ],
    newsIndex: [
      'title',
      'content',
      'summary',
      'tags',
      'source',
      'location.state',
      'location.district',
    ],
    professionalsIndex: [
      'name',
      'profession',
      'specialization',
      'bio',
      'location.state',
      'location.district',
      'services',
    ],
    campaignsIndex: [
      'title',
      'description',
      'goals',
      'location.state',
      'location.district',
      'tags',
      'organizer',
    ],
    organizationsIndex: [
      'name',
      'description',
      'mission',
      'services',
      'location.state',
      'location.district',
      'tags',
    ],
    landRecordsIndex: [
      'surveyNumber',
      'ownerName',
      'location.state',
      'location.district',
      'location.mandal',
      'location.village',
      'landType',
      'status',
    ],
  };
  
  // Custom Ranking Configuration
  static const Map<String, List<String>> customRanking = {
    postsIndex: [
      'desc(likesCount)',
      'desc(commentsCount)',
      'desc(sharesCount)',
      'desc(createdAt)',
    ],
    usersIndex: [
      'desc(followersCount)',
      'desc(postsCount)',
      'desc(reputation)',
      'desc(joinedAt)',
    ],
    legalCasesIndex: [
      'desc(priority)',
      'desc(updatedAt)',
      'desc(relevanceScore)',
    ],
    newsIndex: [
      'desc(publishedAt)',
      'desc(viewsCount)',
      'desc(relevanceScore)',
    ],
    professionalsIndex: [
      'desc(rating)',
      'desc(reviewsCount)',
      'desc(experienceYears)',
      'desc(casesHandled)',
    ],
    campaignsIndex: [
      'desc(priority)',
      'desc(supportersCount)',
      'desc(createdAt)',
    ],
    organizationsIndex: [
      'desc(membersCount)',
      'desc(rating)',
      'desc(establishedYear)',
    ],
    landRecordsIndex: [
      'desc(updatedAt)',
      'desc(priority)',
    ],
  };
  
  // Synonyms Configuration
  static const Map<String, List<List<String>>> synonyms = {
    'legal_terms': [
      ['lawyer', 'advocate', 'attorney', 'legal counsel'],
      ['court', 'tribunal', 'judiciary'],
      ['case', 'lawsuit', 'litigation', 'legal proceeding'],
      ['land', 'property', 'real estate', 'plot'],
      ['farmer', 'agriculturist', 'cultivator', 'grower'],
      ['government', 'administration', 'authority', 'state'],
    ],
    'locations': [
      ['Bihar', 'à¤¬à¤¿à¤¹à¤¾à¤°'],
      ['Patna', 'à¤ªà¤Ÿà¤¨à¤¾'],
      ['village', 'gram', 'gaon', 'à¤—à¤¾à¤à¤µ'],
      ['district', 'zilla', 'à¤œà¤¿à¤²à¤¾'],
      ['state', 'rajya', 'à¤°à¤¾à¤œà¥à¤¯'],
    ],
    'activism_terms': [
      ['protest', 'demonstration', 'rally', 'march'],
      ['campaign', 'movement', 'drive', 'initiative'],
      ['rights', 'entitlements', 'claims'],
      ['justice', 'fairness', 'equity'],
      ['community', 'society', 'group', 'collective'],
    ],
  };
  
  // Geo-search Configuration
  static const double defaultSearchRadius = 50000; // 50km in meters
  static const double maxSearchRadius = 500000; // 500km in meters
  
  // Auto-complete Configuration
  static const int minQueryLength = 2;
  static const int maxSuggestions = 10;
  
  // Analytics Configuration
  static const bool enableAnalytics = true;
  static const bool enableClickAnalytics = true;
  static const bool enablePersonalization = true;
  
  // Rate Limiting
  static const int maxSearchesPerMinute = 100;
  static const int maxSearchesPerHour = 1000;
  
  // Cache Configuration
  static const Duration cacheTimeout = Duration(minutes: 5);
  static const int maxCacheSize = 100; // Number of cached search results
  
  // Error Handling
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // Development vs Production Configuration
  static bool get isDevelopment => const bool.fromEnvironment('dart.vm.product') == false;
  
  static String get environmentPrefix => isDevelopment ? 'dev_' : 'prod_';
  
  // Get environment-specific index name
  static String getIndexName(String baseIndexName) {
    return '$environmentPrefix$baseIndexName';
  }
  
  // Validation
  static bool validateConfiguration() {
    if (applicationId.isEmpty || applicationId == 'TALOWA_ALGOLIA_APP_ID') {
      print('âš ï¸ Algolia Application ID not configured');
      return false;
    }
    
    if (searchApiKey.isEmpty || searchApiKey == 'TALOWA_SEARCH_API_KEY') {
      print('âš ï¸ Algolia Search API Key not configured');
      return false;
    }
    
    return true;
  }
  
  // Get search parameters for different content types
  static Map<String, dynamic> getSearchParameters(String indexName, {
    int? hitsPerPage,
    List<String>? facets,
    Map<String, dynamic>? filters,
    Map<String, dynamic>? geoSearch,
  }) {
    return {
      'hitsPerPage': hitsPerPage ?? defaultHitsPerPage,
      'facets': facets ?? defaultFacets,
      'attributesToRetrieve': ['*'],
      'attributesToHighlight': searchableAttributes[indexName] ?? [],
      'highlightPreTag': '<mark>',
      'highlightPostTag': '</mark>',
      'typoTolerance': true,
      'ignorePlurals': true,
      'removeStopWords': true,
      'queryLanguages': ['en', 'hi'],
      'indexLanguages': ['en', 'hi'],
      'enablePersonalization': enablePersonalization,
      'clickAnalytics': enableClickAnalytics,
      'analytics': enableAnalytics,
      if (filters != null) 'filters': filters,
      if (geoSearch != null) ...geoSearch,
    };
  }
}

