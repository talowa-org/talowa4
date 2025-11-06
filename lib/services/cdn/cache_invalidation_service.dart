import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/cdn_config.dart';

/// Enhanced Cache Invalidation Service for TALOWA CDN
/// Manages cache invalidation strategies for dynamic content with advanced features
class CacheInvalidationService {
  static final CacheInvalidationService _instance = CacheInvalidationService._internal();
  factory CacheInvalidationService() => _instance;
  CacheInvalidationService._internal();
  
  late FirebaseFirestore _firestore;
  
  // Enhanced cache invalidation strategies
  static const Duration DEFAULT_TTL = Duration(hours: 24);
  static const Duration PROFILE_TTL = Duration(hours: 1);
  static const Duration FEED_TTL = Duration(minutes: 30);
  static const Duration EVENT_TTL = Duration(hours: 6);
  static const Duration STORY_TTL = Duration(minutes: 5);
  static const Duration MEDIA_TTL = Duration(hours: 12);
  
  // Advanced invalidation tracking
  final Map<String, List<InvalidationRequest>> _invalidationQueues = {};
  final Map<String, DateTime> _lastInvalidation = {};
  final Map<String, CacheInvalidationRule> _invalidationRules = {};
  final Map<String, List<String>> _dependencyGraph = {};
  final List<InvalidationRequest> _pendingInvalidations = [];
  
  // Performance metrics
  int _totalInvalidations = 0;
  int _successfulInvalidations = 0;
  final Map<String, int> _invalidationsByType = {};
  
  // Batch processing
  Timer? _batchProcessor;
  static const Duration BATCH_INTERVAL = Duration(seconds: 30);
  static const int MAX_BATCH_SIZE = 100;
  
  bool _isInitialized = false;

  /// Initialize enhanced cache invalidation service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _firestore = FirebaseFirestore.instance;
      
      // Set up advanced invalidation rules
      _setupAdvancedInvalidationRules();
      
      // Start enhanced batch processor
      _startEnhancedBatchProcessor();
      
      // Setup comprehensive invalidation listeners
      await _setupComprehensiveInvalidationListeners();
      
      _isInitialized = true;
      print('🚀 Enhanced Cache Invalidation Service initialized with advanced features');
    } catch (e) {
      print('❌ Enhanced Cache Invalidation Service initialization failed: $e');
      rethrow;
    }
  }

  /// Set up advanced invalidation rules for different content types
  void _setupAdvancedInvalidationRules() {
    // User profile content with dependencies
    _invalidationRules['user_profile'] = CacheInvalidationRule(
      pattern: '/users/{userId}/*',
      ttl: PROFILE_TTL,
      strategy: InvalidationStrategy.immediate,
      dependencies: ['user_avatar', 'user_posts', 'user_stories'],
    );

    // Feed posts with cascading invalidation
    _invalidationRules['feed_posts'] = CacheInvalidationRule(
      pattern: '/feed/*',
      ttl: FEED_TTL,
      strategy: InvalidationStrategy.batched,
      dependencies: ['user_profile', 'post_media', 'post_comments'],
    );

    // Post media with lazy invalidation
    _invalidationRules['post_media'] = CacheInvalidationRule(
      pattern: '/media/posts/*',
      ttl: MEDIA_TTL,
      strategy: InvalidationStrategy.lazy,
      dependencies: [],
    );

    // User avatars with immediate invalidation
    _invalidationRules['user_avatar'] = CacheInvalidationRule(
      pattern: '/media/avatars/*',
      ttl: const Duration(minutes: 30),
      strategy: InvalidationStrategy.immediate,
      dependencies: ['user_profile'],
    );

    // Stories with immediate invalidation (short-lived content)
    _invalidationRules['stories'] = CacheInvalidationRule(
      pattern: '/stories/*',
      ttl: STORY_TTL,
      strategy: InvalidationStrategy.immediate,
      dependencies: ['user_profile'],
    );

    // Organization content
    _invalidationRules['organization'] = CacheInvalidationRule(
      pattern: '/organizations/{orgId}/*',
      ttl: const Duration(hours: 2),
      strategy: InvalidationStrategy.batched,
      dependencies: ['organization_media', 'organization_events'],
    );

    // Events with medium priority
    _invalidationRules['events'] = CacheInvalidationRule(
      pattern: '/events/*',
      ttl: EVENT_TTL,
      strategy: InvalidationStrategy.batched,
      dependencies: ['organization', 'event_media'],
    );

    print('📋 Set up ${_invalidationRules.length} advanced invalidation rules');
  }
  
  /// Start enhanced batch processor for efficient invalidation
  void _startEnhancedBatchProcessor() {
    _batchProcessor = Timer.periodic(BATCH_INTERVAL, (timer) {
      _processAdvancedBatchInvalidations();
    });
  }
  
  /// Setup comprehensive real-time invalidation listeners
  Future<void> _setupComprehensiveInvalidationListeners() async {
    try {
      // Enhanced user profile listener
      _firestore.collection('users').snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            _scheduleAdvancedInvalidation(
              InvalidationRequest(
                type: InvalidationType.userProfile,
                resourceId: change.doc.id,
                reason: 'Profile updated',
                priority: InvalidationPriority.high,
                metadata: {'timestamp': DateTime.now().toIso8601String()},
              ),
            );
          }
        }
      });
      
      // Enhanced post listener with media tracking
      _firestore.collection('posts').snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified || 
              change.type == DocumentChangeType.removed) {
            _scheduleAdvancedInvalidation(
              InvalidationRequest(
                type: InvalidationType.feedContent,
                resourceId: change.doc.id,
                reason: 'Post ${change.type.name}',
                priority: InvalidationPriority.medium,
                metadata: {
                  'change_type': change.type.name,
                  'has_media': change.doc.data()?['mediaUrls'] != null,
                },
              ),
            );
          }
        }
      });
      
      // Stories listener (high frequency updates)
      _firestore.collection('stories').snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          _scheduleAdvancedInvalidation(
            InvalidationRequest(
              type: InvalidationType.storyContent,
              resourceId: change.doc.id,
              reason: 'Story ${change.type.name}',
              priority: InvalidationPriority.high,
              metadata: {'expires_at': change.doc.data()?['expiresAt']},
            ),
          );
        }
      });
      
      // Event listener
      _firestore.collection('events').snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            _scheduleAdvancedInvalidation(
              InvalidationRequest(
                type: InvalidationType.eventContent,
                resourceId: change.doc.id,
                reason: 'Event updated',
                priority: InvalidationPriority.medium,
                metadata: {'organization_id': change.doc.data()?['organizationId']},
              ),
            );
          }
        }
      });

      // Organization listener
      _firestore.collection('organizations').snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            _scheduleAdvancedInvalidation(
              InvalidationRequest(
                type: InvalidationType.organizationContent,
                resourceId: change.doc.id,
                reason: 'Organization updated',
                priority: InvalidationPriority.medium,
              ),
            );
          }
        }
      });
      
      print('👂 Comprehensive invalidation listeners setup complete');
    } catch (e) {
      print('❌ Failed to setup invalidation listeners: $e');
    }
  }

  /// Advanced invalidation scheduling with dependency management
  void _scheduleAdvancedInvalidation(InvalidationRequest request) {
    final queueKey = request.type.toString();
    _invalidationQueues.putIfAbsent(queueKey, () => []).add(request);
    
    // Process dependencies
    _processDependencies(request);
    
    // Immediate processing for high priority items
    if (request.priority == InvalidationPriority.critical) {
      _processImmediateInvalidation(request);
    }
    
    print('📝 Scheduled advanced invalidation: ${request.type} - ${request.resourceId}');
  }

  /// Process dependencies for cascading invalidation
  void _processDependencies(InvalidationRequest request) {
    final contentType = request.type.toString().split('.').last;
    final rule = _invalidationRules[contentType];
    
    if (rule?.dependencies.isNotEmpty ?? false) {
      for (final dependency in rule!.dependencies) {
        _scheduleAdvancedInvalidation(
          InvalidationRequest(
            type: _getInvalidationTypeFromString(dependency),
            resourceId: request.resourceId,
            reason: 'Dependency of ${request.type}',
            priority: InvalidationPriority.low,
            metadata: {'parent_request': request.type.toString()},
          ),
        );
      }
    }
  }

  /// Process immediate invalidation for critical content
  Future<void> _processImmediateInvalidation(InvalidationRequest request) async {
    try {
      await _performCDNInvalidation(request);
      _updateInvalidationMetrics(request, true);
      print('⚡ Immediate invalidation processed: ${request.resourceId}');
    } catch (e) {
      _updateInvalidationMetrics(request, false);
      print('❌ Immediate invalidation failed: $e');
    }
  }

  /// Process advanced batch invalidations with optimization
  Future<void> _processAdvancedBatchInvalidations() async {
    if (_invalidationQueues.isEmpty) return;
    
    print('🔄 Processing advanced batch invalidations...');
    
    final allRequests = <InvalidationRequest>[];
    for (final queue in _invalidationQueues.values) {
      allRequests.addAll(queue);
    }
    _invalidationQueues.clear();
    
    if (allRequests.isEmpty) return;
    
    // Group by priority and type for optimized processing
    final groupedRequests = _groupRequestsForOptimization(allRequests);
    
    // Process each group
    for (final group in groupedRequests) {
      await _processBatchGroup(group);
    }
    
    print('✅ Advanced batch invalidation completed: ${allRequests.length} requests');
  }

  /// Group requests for optimized batch processing
  List<List<InvalidationRequest>> _groupRequestsForOptimization(List<InvalidationRequest> requests) {
    final groups = <List<InvalidationRequest>>[];
    final priorityGroups = <InvalidationPriority, List<InvalidationRequest>>{};
    
    // Group by priority first
    for (final request in requests) {
      priorityGroups.putIfAbsent(request.priority, () => []).add(request);
    }
    
    // Process high priority first, then medium, then low
    for (final priority in [InvalidationPriority.high, InvalidationPriority.medium, InvalidationPriority.low]) {
      final priorityRequests = priorityGroups[priority] ?? [];
      
      // Split into batches of MAX_BATCH_SIZE
      for (int i = 0; i < priorityRequests.length; i += MAX_BATCH_SIZE) {
        final batch = priorityRequests.skip(i).take(MAX_BATCH_SIZE).toList();
        groups.add(batch);
      }
    }
    
    return groups;
  }

  /// Process a batch group with error handling
  Future<void> _processBatchGroup(List<InvalidationRequest> requests) async {
    try {
      // Simulate batch CDN invalidation
      await _performBatchCDNInvalidation(requests);
      
      // Update metrics for successful requests
      for (final request in requests) {
        _updateInvalidationMetrics(request, true);
      }
      
      print('✅ Batch group processed: ${requests.length} requests');
    } catch (e) {
      // Update metrics for failed requests
      for (final request in requests) {
        _updateInvalidationMetrics(request, false);
      }
      print('❌ Batch group processing failed: $e');
    }
  }

  /// Perform CDN invalidation for a single request
  Future<void> _performCDNInvalidation(InvalidationRequest request) async {
    // Simulate CDN API call
    await Future.delayed(const Duration(milliseconds: 100));
    
    final cacheKey = _generateCacheKey(request);
    _lastInvalidation[cacheKey] = DateTime.now();
    
    print('🌐 CDN invalidation performed: $cacheKey');
  }

  /// Perform batch CDN invalidation
  Future<void> _performBatchCDNInvalidation(List<InvalidationRequest> requests) async {
    // Simulate batch CDN API call
    await Future.delayed(const Duration(milliseconds: 200));
    
    for (final request in requests) {
      final cacheKey = _generateCacheKey(request);
      _lastInvalidation[cacheKey] = DateTime.now();
    }
    
    print('🌐 Batch CDN invalidation performed: ${requests.length} items');
  }

  /// Update invalidation metrics
  void _updateInvalidationMetrics(InvalidationRequest request, bool success) {
    _totalInvalidations++;
    if (success) {
      _successfulInvalidations++;
    }
    
    final typeKey = request.type.toString();
    _invalidationsByType[typeKey] = (_invalidationsByType[typeKey] ?? 0) + 1;
  }

  /// Generate cache key for request
  String _generateCacheKey(InvalidationRequest request) {
    return '${request.type}_${request.resourceId}';
  }

  /// Get invalidation type from string
  InvalidationType _getInvalidationTypeFromString(String typeString) {
    switch (typeString) {
      case 'user_profile':
        return InvalidationType.userProfile;
      case 'user_avatar':
        return InvalidationType.userProfile;
      case 'user_posts':
        return InvalidationType.feedContent;
      case 'user_stories':
        return InvalidationType.storyContent;
      case 'post_media':
        return InvalidationType.mediaContent;
      case 'post_comments':
        return InvalidationType.feedContent;
      case 'organization_media':
        return InvalidationType.mediaContent;
      case 'organization_events':
        return InvalidationType.eventContent;
      case 'event_media':
        return InvalidationType.mediaContent;
      default:
        return InvalidationType.feedContent;
    }
  }

  /// Get comprehensive invalidation statistics
  Map<String, dynamic> getAdvancedInvalidationStats() {
    final successRate = _totalInvalidations > 0 
        ? (_successfulInvalidations / _totalInvalidations * 100).toStringAsFixed(1)
        : '0.0';
    
    final queueSizes = <String, int>{};
    for (final entry in _invalidationQueues.entries) {
      queueSizes[entry.key] = entry.value.length;
    }
    
    return {
      'total_invalidations': _totalInvalidations,
      'successful_invalidations': _successfulInvalidations,
      'success_rate': '$successRate%',
      'invalidations_by_type': _invalidationsByType,
      'active_rules': _invalidationRules.length,
      'queue_sizes': queueSizes,
      'tracked_cache_keys': _lastInvalidation.length,
      'pending_batch_size': _pendingInvalidations.length,
    };
  }

  /// Get cache headers with advanced settings
  Map<String, String> getAdvancedCacheHeaders({
    required String contentType,
    Map<String, dynamic>? metadata,
  }) {
    final rule = _invalidationRules[contentType];
    final headers = <String, String>{};
    
    if (rule != null) {
      final maxAge = rule.ttl.inSeconds;
      
      // Advanced cache control based on strategy
      switch (rule.strategy) {
        case InvalidationStrategy.immediate:
          headers['Cache-Control'] = 'public, max-age=$maxAge, must-revalidate';
          break;
        case InvalidationStrategy.batched:
          headers['Cache-Control'] = 'public, max-age=$maxAge, s-maxage=${maxAge * 2}';
          break;
        case InvalidationStrategy.lazy:
          headers['Cache-Control'] = 'public, max-age=${maxAge * 2}, stale-while-revalidate=$maxAge';
          break;
      }
      
      // Add ETag for validation
      headers['ETag'] = _generateAdvancedETag(contentType, metadata);
      
      // Add Last-Modified
      headers['Last-Modified'] = DateTime.now().toUtc().toIso8601String();
      
      // Add Vary header for dynamic content
      headers['Vary'] = 'Accept-Encoding, User-Agent, Authorization';
      
      // Add CDN-specific headers
      headers['X-CDN-Cache-Status'] = 'MISS';
      headers['X-CDN-Cache-TTL'] = maxAge.toString();
    } else {
      // Default advanced cache headers
      headers['Cache-Control'] = 'public, max-age=3600, stale-while-revalidate=1800';
      headers['ETag'] = _generateAdvancedETag(contentType, metadata);
    }
    
    return headers;
  }

  /// Generate advanced ETag with metadata
  String _generateAdvancedETag(String contentType, Map<String, dynamic>? metadata) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final metadataHash = metadata?.toString().hashCode ?? 0;
    final combined = '$contentType$metadataHash$timestamp';
    return '"${combined.hashCode.abs().toRadixString(16)}"';
  }

  /// Invalidate cache by pattern with advanced matching
  Future<InvalidationResult> invalidateCacheByPattern({
    required String pattern,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('🎯 Advanced pattern invalidation: $pattern');
      
      // Find matching cache keys
      final matchingKeys = _findMatchingCacheKeys(pattern);
      
      // Create invalidation requests for matching keys
      final requests = matchingKeys.map((key) => InvalidationRequest(
        type: InvalidationType.patternMatch,
        resourceId: key,
        reason: 'Pattern match: $pattern',
        priority: InvalidationPriority.medium,
        metadata: metadata,
      )).toList();
      
      // Process batch invalidation
      if (requests.isNotEmpty) {
        await _processBatchGroup(requests);
      }
      
      return InvalidationResult(
        success: true,
        processedCount: requests.length,
        pattern: pattern,
      );
      
    } catch (e) {
      return InvalidationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Find cache keys matching pattern
  List<String> _findMatchingCacheKeys(String pattern) {
    final matchingKeys = <String>[];
    final regex = RegExp(pattern.replaceAll('*', '.*').replaceAll('{', '\\{').replaceAll('}', '\\}'));
    
    for (final key in _lastInvalidation.keys) {
      if (regex.hasMatch(key)) {
        matchingKeys.add(key);
      }
    }
    
    return matchingKeys;
  }

  /// Dispose enhanced resources
  void dispose() {
    _batchProcessor?.cancel();
    _invalidationQueues.clear();
    _lastInvalidation.clear();
    _invalidationRules.clear();
    _dependencyGraph.clear();
    _pendingInvalidations.clear();
    _isInitialized = false;
    print('🧹 Enhanced Cache Invalidation Service disposed');
  }
}

/// Enhanced cache invalidation rule
class CacheInvalidationRule {
  final String pattern;
  final Duration ttl;
  final InvalidationStrategy strategy;
  final List<String> dependencies;

  CacheInvalidationRule({
    required this.pattern,
    required this.ttl,
    required this.strategy,
    this.dependencies = const [],
  });
}

/// Enhanced invalidation strategies
enum InvalidationStrategy {
  immediate,  // Invalidate immediately
  batched,    // Add to batch queue
  lazy,       // Mark as stale, invalidate on next access
}

/// Enhanced invalidation result
class InvalidationResult {
  final bool success;
  final int? processedCount;
  final String? pattern;
  final String? error;

  InvalidationResult({
    required this.success,
    this.processedCount,
    this.pattern,
    this.error,
  });
}

/// Enhanced Invalidation Request with metadata support
class InvalidationRequest {
  final InvalidationType type;
  final String resourceId;
  final String reason;
  final InvalidationPriority priority;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  InvalidationRequest({
    required this.type,
    required this.resourceId,
    required this.reason,
    required this.priority,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to JSON for logging/analytics
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'resource_id': resourceId,
      'reason': reason,
      'priority': priority.toString(),
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'InvalidationRequest(type: $type, resourceId: $resourceId, priority: $priority)';
  }
}

/// Enhanced Invalidation Types with comprehensive coverage
enum InvalidationType {
  userProfile,
  feedContent,
  eventContent,
  assetContent,
  mediaContent,
  storyContent,
  organizationContent,
  globalCache,
  patternMatch,
}

/// Enhanced Invalidation Priority with critical level
enum InvalidationPriority {
  low,
  medium,
  high,
  critical,
}

/// Enhanced Invalidation Statistics with comprehensive metrics
class InvalidationStats {
  final int totalPendingInvalidations;
  final int totalProcessedInvalidations;
  final Map<String, int> queueSizes;
  final Map<String, DateTime> lastInvalidationTimes;
  final Duration averageProcessingTime;
  final double successRate;
  final Map<String, int> invalidationsByType;
  final Map<String, int> invalidationsByPriority;
  final DateTime lastUpdated;

  InvalidationStats({
    required this.totalPendingInvalidations,
    required this.totalProcessedInvalidations,
    required this.queueSizes,
    required this.lastInvalidationTimes,
    required this.averageProcessingTime,
    required this.successRate,
    required this.invalidationsByType,
    required this.invalidationsByPriority,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory InvalidationStats.empty() {
    return InvalidationStats(
      totalPendingInvalidations: 0,
      totalProcessedInvalidations: 0,
      queueSizes: {},
      lastInvalidationTimes: {},
      averageProcessingTime: Duration.zero,
      successRate: 0.0,
      invalidationsByType: {},
      invalidationsByPriority: {},
    );
  }

  /// Convert to JSON for analytics
  Map<String, dynamic> toJson() {
    return {
      'total_pending_invalidations': totalPendingInvalidations,
      'total_processed_invalidations': totalProcessedInvalidations,
      'queue_sizes': queueSizes,
      'last_invalidation_times': lastInvalidationTimes.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'average_processing_time_ms': averageProcessingTime.inMilliseconds,
      'success_rate': successRate,
      'invalidations_by_type': invalidationsByType,
      'invalidations_by_priority': invalidationsByPriority,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'InvalidationStats(pending: $totalPendingInvalidations, '
           'processed: $totalProcessedInvalidations, '
           'success_rate: ${successRate.toStringAsFixed(1)}%)';
  }
}

/// Cache Performance Metrics for monitoring
class CachePerformanceMetrics {
  final int hitCount;
  final int missCount;
  final int invalidationCount;
  final Duration averageResponseTime;
  final double hitRatio;
  final Map<String, int> contentTypeHits;
  final Map<String, int> contentTypeMisses;
  final DateTime periodStart;
  final DateTime periodEnd;

  CachePerformanceMetrics({
    required this.hitCount,
    required this.missCount,
    required this.invalidationCount,
    required this.averageResponseTime,
    required this.contentTypeHits,
    required this.contentTypeMisses,
    required this.periodStart,
    required this.periodEnd,
  }) : hitRatio = (hitCount + missCount) > 0 
           ? hitCount / (hitCount + missCount) 
           : 0.0;

  /// Convert to JSON for analytics
  Map<String, dynamic> toJson() {
    return {
      'hit_count': hitCount,
      'miss_count': missCount,
      'invalidation_count': invalidationCount,
      'average_response_time_ms': averageResponseTime.inMilliseconds,
      'hit_ratio': hitRatio,
      'content_type_hits': contentTypeHits,
      'content_type_misses': contentTypeMisses,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
    };
  }
}

/// CDN Cache Configuration for different content types
class CDNCacheConfig {
  final String contentType;
  final Duration ttl;
  final Duration staleWhileRevalidate;
  final bool enableCompression;
  final List<String> varyHeaders;
  final Map<String, String> customHeaders;

  CDNCacheConfig({
    required this.contentType,
    required this.ttl,
    this.staleWhileRevalidate = const Duration(minutes: 5),
    this.enableCompression = true,
    this.varyHeaders = const ['Accept-Encoding'],
    this.customHeaders = const {},
  });

  /// Generate cache control header
  String get cacheControlHeader {
    final parts = <String>[];
    
    parts.add('public');
    parts.add('max-age=${ttl.inSeconds}');
    
    if (staleWhileRevalidate.inSeconds > 0) {
      parts.add('stale-while-revalidate=${staleWhileRevalidate.inSeconds}');
    }
    
    return parts.join(', ');
  }

  /// Get all headers for this cache config
  Map<String, String> get headers {
    final headers = <String, String>{
      'Cache-Control': cacheControlHeader,
    };
    
    if (varyHeaders.isNotEmpty) {
      headers['Vary'] = varyHeaders.join(', ');
    }
    
    if (enableCompression) {
      headers['Content-Encoding'] = 'gzip';
    }
    
    headers.addAll(customHeaders);
    
    return headers;
  }
}