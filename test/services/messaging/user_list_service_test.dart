// Test for UserListService
// Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 4.1, 4.2

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/messaging/user_list_service.dart';

void main() {
  group('UserListService', () {
    late UserListService userListService;

    setUp(() {
      userListService = UserListService();
    });

    test('should initialize successfully', () async {
      // Test that the service can be initialized without errors
      expect(() => userListService.initialize(), returnsNormally);
    });

    test('should return empty result for empty search query', () async {
      final result = await userListService.searchUsers(query: '');
      
      expect(result.users, isEmpty);
      expect(result.hasMore, false);
      expect(result.isFromCache, false);
    });

    test('should handle cache operations correctly', () {
      // Test cache statistics
      final stats = userListService.getCacheStats();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('cachedLists'), true);
      expect(stats.containsKey('totalCachedUsers'), true);
      expect(stats.containsKey('activeStreams'), true);
    });

    test('should clear cache correctly', () {
      userListService.clearCache();
      
      final stats = userListService.getCacheStats();
      expect(stats['cachedLists'], 0);
      expect(stats['totalCachedUsers'], 0);
    });

    tearDown(() {
      userListService.dispose();
    });
  });

  group('UserListResult', () {
    test('should create result with correct properties', () {
      final result = UserListResult(
        users: [],
        hasMore: false,
        isFromCache: true,
      );

      expect(result.users, isEmpty);
      expect(result.hasMore, false);
      expect(result.isFromCache, true);
      expect(result.isSuccess, true);
      expect(result.isEmpty, true);
      expect(result.count, 0);
    });

    test('should handle error state correctly', () {
      final result = UserListResult(
        users: [],
        hasMore: false,
        isFromCache: false,
        error: 'Test error',
      );

      expect(result.isSuccess, false);
      expect(result.error, 'Test error');
    });
  });
}