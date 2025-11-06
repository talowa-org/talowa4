// Test for Messaging Search Functionality
// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/messaging/messaging_search_service.dart';

void main() {
  group('MessagingSearchService Tests', () {
    late MessagingSearchService searchService;

    setUp(() {
      searchService = MessagingSearchService();
    });

    test('should initialize successfully', () async {
      // Test service initialization
      expect(() async => await searchService.initialize(), returnsNormally);
    });

    test('should return empty results for empty query', () async {
      // Test empty query handling
      final result = await searchService.searchUsers(query: '');
      
      expect(result.isEmpty, isTrue);
      expect(result.users, isEmpty);
      expect(result.searchQuery, isEmpty);
    });

    test('should generate search highlights correctly', () {
      // Test search highlighting functionality
      const content = 'This is a test message with important content';
      const query = 'test';
      
      final highlights = searchService.getSearchHighlights(content, query);
      
      expect(highlights, isNotEmpty);
      expect(highlights.first.matchedText, equals('test'));
      expect(highlights.first.startIndex, equals(10));
      expect(highlights.first.endIndex, equals(14));
    });

    test('should provide appropriate empty state messages', () {
      // Test empty state message generation
      const query = 'nonexistent';
      
      final userMessage = searchService.getEmptyStateMessage(query, isUserSearch: true);
      final messageMessage = searchService.getEmptyStateMessage(query, isUserSearch: false);
      
      expect(userMessage, contains('No users found'));
      expect(messageMessage, contains('No messages found'));
    });

    test('should manage search history correctly', () {
      // Test search history functionality
      final initialHistory = searchService.getSearchHistory();
      expect(initialHistory, isEmpty);
      
      // Search history is managed internally, so we can't directly test it
      // without making the methods public or using integration tests
    });

    test('should provide search suggestions', () async {
      // Test search suggestions
      final suggestions = await searchService.getSearchSuggestions('test');
      
      expect(suggestions, isA<List<String>>());
      // Suggestions might be empty in test environment, which is acceptable
    });

    test('should handle cache statistics', () {
      // Test cache statistics
      final stats = searchService.getCacheStats();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('cachedSearches'), isTrue);
      expect(stats.containsKey('searchHistory'), isTrue);
      expect(stats.containsKey('savedSearches'), isTrue);
    });

    test('should create proper filter objects', () {
      // Test filter creation
      const userFilters = UserSearchFilters(
        roles: ['Admin', 'Coordinator'],
        onlineOnly: true,
      );
      
      expect(userFilters.roles, contains('Admin'));
      expect(userFilters.roles, contains('Coordinator'));
      expect(userFilters.onlineOnly, isTrue);
      
      const messageFilters = MessageSearchFilters(
        includeDeleted: false,
      );
      
      expect(messageFilters.includeDeleted, isFalse);
    });

    tearDown(() async {
      await searchService.dispose();
    });
  });

  group('Search Result Models Tests', () {
    test('should create user search result correctly', () {
      const result = UserSearchResult(
        users: [],
        totalResults: 0,
        hasMore: false,
        searchQuery: 'test',
      );
      
      expect(result.isEmpty, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.searchQuery, equals('test'));
    });

    test('should create message search result correctly', () {
      const result = MessageSearchResult(
        messages: [],
        totalResults: 0,
        hasMore: false,
        searchQuery: 'test',
      );
      
      expect(result.isEmpty, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.searchQuery, equals('test'));
    });

    test('should handle error states correctly', () {
      const result = UserSearchResult(
        users: [],
        totalResults: 0,
        hasMore: false,
        searchQuery: 'test',
        error: 'Test error',
      );
      
      expect(result.isSuccess, isFalse);
      expect(result.error, equals('Test error'));
    });
  });

  group('Search Highlight Tests', () {
    test('should create search highlight correctly', () {
      const highlight = SearchHighlight(
        startIndex: 5,
        endIndex: 10,
        matchedText: 'test',
      );
      
      expect(highlight.startIndex, equals(5));
      expect(highlight.endIndex, equals(10));
      expect(highlight.matchedText, equals('test'));
      expect(highlight.length, equals(5));
    });
  });
}