import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/performance/advanced_cache_service.dart';
import 'package:talowa/services/performance/cache_partition_service.dart';
import 'package:talowa/services/performance/cache_monitoring_service.dart';
import 'package:talowa/services/performance/cache_failover_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Advanced Cache System Tests', () {
    late AdvancedCacheService advancedCache;
    late CachePartitionService partitionService;
    late CacheMonitoringService monitoringService;
    late CacheFailoverService failoverService;

    setUp(() async {
      advancedCache = AdvancedCacheService.instance;
      partitionService = CachePartitionService.instance;
      monitoringService = CacheMonitoringService.instance;
      failoverService = CacheFailoverService.instance;
      
      await advancedCache.initialize();
      await partitionService.initialize();
      await monitoringService.initialize();
      await failoverService.initialize();
    });

    tearDown(() async {
      await advancedCache.clearAll();
      monitoringService.clearHistory();
    });

    test('should initialize advanced cache service', () async {
      expect(advancedCache, isNotNull);
      
      // Configure cache
      advancedCache.configure(
        maxL1Size: 10 * 1024 * 1024, // 10MB
        maxL2Size: 50 * 1024 * 1024, // 50MB
        compressionEnabled: true,
      );
      
      // Verify configuration applied
      final stats = advancedCache.getStats();
      expect(stats, isNotNull);
      expect(stats.containsKey('l1Memory'), isTrue);
    });

    test('should cache and retrieve data with multi-tier architecture', () async {
      const testKey = 'test_post_123';
      final testData = {
        'id': '123',
        'content': 'Test post content',
        'author': 'Test User',
        'timestamp': '2024-01-01T00:00:00Z',
      };

      // Set data in cache
      await advancedCache.set(
        testKey,
        testData,
        duration: const Duration(minutes: 30),
        dependencies: ['user_123', 'feed_global'],
        metadata: {'test': true},
      );

      // Retrieve data
      final retrievedData = await advancedCache.get<Map<String, dynamic>>(testKey);
      
      expect(retrievedData, isNotNull);
      expect(retrievedData!['id'], equals('123'));
      expect(retrievedData['content'], equals('Test post content'));
    });

    test('should handle cache partitioning correctly', () async {
      const testKey = 'user_profile_456';
      final testProfile = {
        'userId': '456',
        'name': 'John Doe',
        'email': 'john@example.com',
        'preferences': ['tech', 'sports'],
      };

      // Set data in user profiles partition
      await partitionService.setInPartition(
        CachePartition.userProfiles,
        testKey,
        testProfile,
        duration: const Duration(hours: 2),
      );

      // Retrieve from partition
      final retrievedProfile = await partitionService.getFromPartition<Map<String, dynamic>>(
        CachePartition.userProfiles,
        testKey,
      );

      expect(retrievedProfile, isNotNull);
      expect(retrievedProfile!['userId'], equals('456'));
      expect(retrievedProfile['name'], equals('John Doe'));

      // Verify partition stats
      final partitionStats = partitionService.getPartitionStats();
      expect(partitionStats.containsKey('user_profiles'), isTrue);
    });

    test('should track cache performance metrics', () async {
      // Perform cache operations
      for (int i = 0; i < 10; i++) {
        await advancedCache.set('test_key_$i', 'test_value_$i');
      }

      // Record cache operations
      for (int i = 0; i < 5; i++) {
        monitoringService.recordCacheOperation(
          operation: 'get',
          isHit: i % 2 == 0, // 50% hit rate
          responseTime: 10.0 + i,
          partition: 'feedPosts',
        );
      }

      // Get performance metrics
      final metrics = monitoringService.getCurrentMetrics();
      
      expect(metrics.totalRequests, equals(5));
      expect(metrics.totalHits, equals(3)); // 3 hits out of 5
      expect(metrics.hitRate, closeTo(0.6, 0.1)); // ~60% hit rate
    });

    test('should handle intelligent cache invalidation', () async {
      const parentKey = 'user_789';
      const dependentKey1 = 'user_posts_789';
      const dependentKey2 = 'user_feed_789';

      // Set up cache entries with dependencies
      await advancedCache.set(parentKey, 'user_data');
      await advancedCache.set(
        dependentKey1,
        'user_posts',
        dependencies: [parentKey],
      );
      await advancedCache.set(
        dependentKey2,
        'user_feed',
        dependencies: [parentKey],
      );

      // Verify all entries exist
      expect(await advancedCache.get(parentKey), isNotNull);
      expect(await advancedCache.get(dependentKey1), isNotNull);
      expect(await advancedCache.get(dependentKey2), isNotNull);

      // Invalidate parent - should cascade to dependents
      await advancedCache.invalidate(parentKey);

      // Verify all dependent entries are invalidated
      expect(await advancedCache.get(parentKey), isNull);
      expect(await advancedCache.get(dependentKey1), isNull);
      expect(await advancedCache.get(dependentKey2), isNull);
    });

    test('should handle cache failover scenarios', () async {
      const testKey = 'failover_test';
      const testData = 'test_data_for_failover';

      // Test normal operation
      final result1 = await failoverService.executeWithFailover<String>(
        testKey,
        () async => testData, // Cache operation
        () async => 'fallback_data', // Fallback operation
      );

      expect(result1, equals(testData));

      // Test failover to fallback
      final result2 = await failoverService.executeWithFailover<String>(
        testKey,
        () async => throw Exception('Cache failure'), // Simulated failure
        () async => 'fallback_data', // Fallback operation
      );

      expect(result2, equals('fallback_data'));

      // Verify failover status
      final failoverStatus = failoverService.getFailoverStatus();
      expect(failoverStatus['overall_health'], isNotNull);
      expect(failoverStatus['current_strategy'], isNotNull);
    });

    test('should compress large data automatically', () async {
      const testKey = 'large_data_test';
      
      // Create large test data (> 1KB to trigger compression)
      final largeData = List.generate(1000, (i) => 'data_item_$i').join(',');
      
      await advancedCache.set(
        testKey,
        largeData,
        compress: true,
      );

      final retrievedData = await advancedCache.get<String>(testKey);
      
      expect(retrievedData, equals(largeData));
      
      // Verify compression was applied
      final stats = advancedCache.getStats();
      expect(stats['l1Memory']['compressions'], greaterThan(0));
    });

    test('should handle cache warming and preloading', () async {
      final warmingData = {
        'popular_post_1': {'id': '1', 'content': 'Popular post 1'},
        'popular_post_2': {'id': '2', 'content': 'Popular post 2'},
        'popular_post_3': {'id': '3', 'content': 'Popular post 3'},
      };

      // Warm cache
      await advancedCache.warmCache(warmingData);

      // Verify warmed data is accessible
      for (final entry in warmingData.entries) {
        final cachedData = await advancedCache.get<Map<String, dynamic>>(entry.key);
        expect(cachedData, isNotNull);
        expect(cachedData!['id'], equals(entry.value['id']));
      }
    });

    test('should provide comprehensive performance reports', () async {
      // Perform various cache operations
      await advancedCache.set('test1', 'data1');
      await advancedCache.set('test2', 'data2');
      await advancedCache.get('test1');
      await advancedCache.get('nonexistent');

      // Record monitoring data
      monitoringService.recordCacheOperation(
        operation: 'get',
        isHit: true,
        responseTime: 15.0,
      );

      // Get comprehensive report
      final report = monitoringService.getPerformanceReport();
      
      expect(report['overall_performance'], isNotNull);
      expect(report['partition_performance'], isNotNull);
      expect(report['recommendations'], isA<List>());
      
      final overallPerf = report['overall_performance'] as Map<String, dynamic>;
      expect(overallPerf['hit_rate'], isA<double>());
      expect(overallPerf['performance_grade'], isA<String>());
    });

    test('should handle cache pattern invalidation', () async {
      // Set up multiple cache entries with patterns
      await advancedCache.set('feed_user_123', 'feed_data_1');
      await advancedCache.set('feed_user_456', 'feed_data_2');
      await advancedCache.set('feed_global', 'global_feed');
      await advancedCache.set('user_profile_123', 'profile_data');

      // Verify all entries exist
      expect(await advancedCache.get('feed_user_123'), isNotNull);
      expect(await advancedCache.get('feed_user_456'), isNotNull);
      expect(await advancedCache.get('feed_global'), isNotNull);
      expect(await advancedCache.get('user_profile_123'), isNotNull);

      // Invalidate all feed-related entries
      await advancedCache.invalidatePattern('feed_.*');

      // Verify feed entries are invalidated but others remain
      expect(await advancedCache.get('feed_user_123'), isNull);
      expect(await advancedCache.get('feed_user_456'), isNull);
      expect(await advancedCache.get('feed_global'), isNull);
      expect(await advancedCache.get('user_profile_123'), isNotNull);
    });
  });
}