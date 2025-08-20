// Performance Optimization Test for TALOWA
// Tests the performance optimization and caching features

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../lib/services/messaging/redis_cache_service.dart';
import '../../../lib/services/messaging/message_pagination_service.dart';
import '../../../lib/services/messaging/cdn_integration_service.dart';
import '../../../lib/services/messaging/lazy_loading_service.dart';
import '../../../lib/services/messaging/performance_integration_service.dart';

void main() {
  group('Performance Optimization Tests', () {
    late RedisCacheService cacheService;
    late MessagePaginationService paginationService;
    late CDNIntegrationService cdnService;
    late LazyLoadingService lazyLoadingService;
    late PerformanceIntegrationService performanceService;

    setUpAll(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() async {
      cacheService = RedisCacheService();
      paginationService = MessagePaginationService();
      cdnService = CDNIntegrationService();
      lazyLoadingService = LazyLoadingService();
      performanceService = PerformanceIntegrationService();
    });

    group('Redis Cache Service', () {
      test('should initialize successfully', () async {
        await cacheService.initialize();
        expect(cacheService, isNotNull);
      });

      test('should cache and retrieve user data', () async {
        await cacheService.initialize();
        
        final userData = {
          'id': 'user123',
          'name': 'Test User',
          'email': 'test@example.com',
        };
        
        await cacheService.cacheUserData(
          userId: 'user123',
          userData: userData,
        );
        
        final cachedData = await cacheService.getCachedUserData('user123');
        expect(cachedData, isNotNull);
        expect(cachedData!['name'], equals('Test User'));
      });

      test('should cache and retrieve paginated messages', () async {
        await cacheService.initialize();
        
        final messages = [
          {'id': 'msg1', 'content': 'Hello'},
          {'id': 'msg2', 'content': 'World'},
        ];
        
        await cacheService.cacheMessagesPaginated(
          conversationId: 'conv123',
          messages: messages,
          page: 0,
        );
        
        final cachedMessages = await cacheService.getCachedMessagesPaginated(
          conversationId: 'conv123',
          page: 0,
        );
        
        expect(cachedMessages, isNotNull);
        expect(cachedMessages!.length, equals(2));
        expect(cachedMessages[0]['content'], equals('Hello'));
      });

      test('should handle cache expiration', () async {
        await cacheService.initialize();
        
        final userData = {'id': 'user123', 'name': 'Test User'};
        await cacheService.cacheUserData(userId: 'user123', userData: userData);
        
        // Simulate cache cleanup
        await cacheService.cleanupExpiredCache();
        
        // Cache should still be valid (not expired yet)
        final cachedData = await cacheService.getCachedUserData('user123');
        expect(cachedData, isNotNull);
      });

      test('should get cache statistics', () {
        final stats = cacheService.getCacheStatistics();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('memory_cache_size'), isTrue);
        expect(stats.containsKey('persistent_cache_size'), isTrue);
      });
    });

    group('Message Pagination Service', () {
      test('should initialize successfully', () async {
        await paginationService.initialize();
        expect(paginationService, isNotNull);
      });

      test('should handle pagination state', () {
        final state = paginationService.getPaginationState('conv123');
        expect(state, isNull); // No state initially
        
        paginationService.resetPaginationState('conv123');
        // Should not throw error
      });

      test('should get cache statistics', () {
        final stats = paginationService.getCacheStatistics();
        expect(stats, isA<Map<String, dynamic>>());
      });
    });

    group('CDN Integration Service', () {
      test('should initialize successfully', () async {
        await cdnService.initialize();
        expect(cdnService, isNotNull);
      });

      test('should get CDN statistics', () {
        final stats = cdnService.getCDNStatistics();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('cached_urls'), isTrue);
        expect(stats.containsKey('cached_metadata'), isTrue);
      });

      test('should clear CDN cache', () async {
        await cdnService.clearCDNCache();
        // Should not throw error
      });
    });

    group('Lazy Loading Service', () {
      test('should initialize successfully', () async {
        await lazyLoadingService.initialize();
        expect(lazyLoadingService, isNotNull);
      });

      test('should handle virtual scrolling', () {
        final items = List.generate(100, (index) => 'Item $index');
        
        final visibleItems = lazyLoadingService.getVirtualScrollItems(
          allItems: items,
          firstVisibleIndex: 10,
          lastVisibleIndex: 20,
          bufferSize: 5,
        );
        
        expect(visibleItems.length, lessThanOrEqualTo(items.length));
        expect(visibleItems.length, greaterThan(0));
      });

      test('should determine when to load more', () {
        final shouldLoad = lazyLoadingService.shouldLoadMore(
          currentItemCount: 50,
          lastVisibleIndex: 47,
          threshold: 5,
        );
        
        expect(shouldLoad, isTrue);
        
        final shouldNotLoad = lazyLoadingService.shouldLoadMore(
          currentItemCount: 50,
          lastVisibleIndex: 30,
          threshold: 5,
        );
        
        expect(shouldNotLoad, isFalse);
      });

      test('should get lazy loading statistics', () {
        final stats = lazyLoadingService.getLazyLoadingStatistics();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('active_loadings'), isTrue);
        expect(stats.containsKey('total_loadings'), isTrue);
      });
    });

    group('Performance Integration Service', () {
      test('should initialize successfully', () async {
        await performanceService.initialize();
        expect(performanceService, isNotNull);
      });

      test('should get performance statistics', () {
        final stats = performanceService.getPerformanceStatistics();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('cache_statistics'), isTrue);
        expect(stats.containsKey('integration_metrics'), isTrue);
      });

      test('should optimize performance', () async {
        await performanceService.optimizePerformance();
        // Should not throw error
      });

      test('should clear all caches', () async {
        await performanceService.clearAllCaches();
        // Should not throw error
      });

      test('should dispose properly', () async {
        await performanceService.dispose();
        // Should not throw error
      });
    });

    group('Integration Tests', () {
      test('should work together seamlessly', () async {
        // Initialize all services
        await cacheService.initialize();
        await paginationService.initialize();
        await cdnService.initialize();
        await lazyLoadingService.initialize();
        await performanceService.initialize();
        
        // Test caching workflow
        final userData = {'id': 'user123', 'name': 'Integration Test User'};
        await cacheService.cacheUserData(userId: 'user123', userData: userData);
        
        final cachedData = await cacheService.getCachedUserData('user123');
        expect(cachedData, isNotNull);
        
        // Test statistics collection
        final cacheStats = cacheService.getCacheStatistics();
        final performanceStats = performanceService.getPerformanceStatistics();
        
        expect(cacheStats, isNotNull);
        expect(performanceStats, isNotNull);
        
        // Test cleanup
        await performanceService.clearAllCaches();
        await performanceService.dispose();
      });
    });
  });
}