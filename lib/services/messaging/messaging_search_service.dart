// Messaging Search Service for TALOWA
// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
// Task: Implement comprehensive search and filtering functionality

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../models/user_model.dart';
import '../auth_service.dart';
import 'user_list_service.dart';
import 'user_discovery_service.dart';

/// Comprehensive search service for messaging functionality
/// Provides global user search, conversation search, and advanced filtering
class MessagingSearchService {
  static final MessagingSearchService _instance = MessagingSearchService._internal();
  factory MessagingSearchService() => _instance;
  MessagingSearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserListService _userListService = UserListService();
  final UserDiscoveryService _userDiscoveryService = UserDiscoveryService();

  // Search history and caching
  final List<String> _searchHistory = [];
  final Map<String, List<String>> _savedSearches = {};
  final Map<String, SearchResult> _searchCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const int _maxSearchHistory = 20;
  static const int _maxSavedSearches = 10;

  // Stream controllers for real-time search updates
  final StreamController<List<UserModel>> _userSearchController = 
      StreamController<List<UserModel>>.broadcast();
  final StreamController<List<MessageModel>> _messageSearchController = 
      StreamController<List<MessageModel>>.broadcast();

  /// Initialize the messaging search service
  Future<void> initialize() async {
    try {
      debugPrint('MessagingSearchService: Initializing');
      await _userListService.initialize();
      await _userDiscoveryService.initialize();
      await _loadSearchHistory();
      await _loadSavedSearches();
      debugPrint('MessagingSearchService: Initialized successfully');
    } catch (e) {
      debugPrint('MessagingSearchService: Error initializing: $e');
    }
  }

  // ==================== GLOBAL USER SEARCH ====================

  /// Global user search with real-time filtering
  /// Requirements: 4.1, 4.2
  Future<UserSearchResult> searchUsers({
    required String query,
    UserSearchFilters? filters,
    int limit = 20,
    bool useCache = true,
  }) async {
    try {
      if (query.trim().isEmpty) {
        return UserSearchResult(
          users: [],
          totalResults: 0,
          hasMore: false,
          searchQuery: query,
          appliedFilters: filters,
        );
      }

      // Check cache first
      final cacheKey = _generateUserSearchCacheKey(query, filters);
      if (useCache && _isValidCache(cacheKey)) {
        final cachedResult = _searchCache[cacheKey] as UserSearchResult;
        debugPrint('MessagingSearchService: Returning cached user search results');
        return cachedResult;
      }

      // Add to search history
      _addToSearchHistory(query);

      // Build Firestore query
      Query userQuery = _firestore
          .collection('users')
          .where('isActive', isEqualTo: true);

      // Apply filters
      if (filters != null) {
        userQuery = _applyUserFilters(userQuery, filters);
      }

      // Execute query with larger limit for local filtering
      final querySnapshot = await userQuery.limit(limit * 3).get();
      
      // Filter results based on search query
      final searchTerm = query.toLowerCase();
      final filteredUsers = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => _matchesUserSearchQuery(user, searchTerm))
          .toList();

      // Apply additional filters that can't be done in Firestore
      final finalUsers = _applyLocalUserFilters(filteredUsers, filters)
          .take(limit)
          .toList();

      // Sort results by relevance
      finalUsers.sort((a, b) => _calculateUserRelevanceScore(b, searchTerm)
          .compareTo(_calculateUserRelevanceScore(a, searchTerm)));

      final result = UserSearchResult(
        users: finalUsers,
        totalResults: filteredUsers.length,
        hasMore: filteredUsers.length > limit,
        searchQuery: query,
        appliedFilters: filters,
      );

      // Cache the result
      _searchCache[cacheKey] = result;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Emit to stream
      _userSearchController.add(finalUsers);

      debugPrint('MessagingSearchService: User search found ${finalUsers.length} results for "$query"');
      return result;
    } catch (e) {
      debugPrint('MessagingSearchService: Error searching users: $e');
      return UserSearchResult(
        users: [],
        totalResults: 0,
        hasMore: false,
        searchQuery: query,
        appliedFilters: filters,
        error: e.toString(),
      );
    }
  }

  /// Real-time user search stream
  /// Requirements: 4.1, 4.2
  Stream<List<UserModel>> getUserSearchStream() {
    return _userSearchController.stream;
  }

  // ==================== CONVERSATION SEARCH ====================

  /// Search within conversations to find specific messages
  /// Requirements: 4.2, 4.3
  Future<MessageSearchResult> searchMessages({
    required String query,
    MessageSearchFilters? filters,
    int limit = 50,
    bool useCache = true,
  }) async {
    try {
      if (query.trim().isEmpty) {
        return MessageSearchResult(
          messages: [],
          totalResults: 0,
          hasMore: false,
          searchQuery: query,
          appliedFilters: filters,
        );
      }

      // Check cache first
      final cacheKey = _generateMessageSearchCacheKey(query, filters);
      if (useCache && _isValidCache(cacheKey)) {
        final cachedResult = _searchCache[cacheKey] as MessageSearchResult;
        debugPrint('MessagingSearchService: Returning cached message search results');
        return cachedResult;
      }

      // Add to search history
      _addToSearchHistory(query);

      // Build Firestore query
      Query messageQuery = _firestore.collection('messages');

      // Apply filters
      if (filters != null) {
        messageQuery = _applyMessageFilters(messageQuery, filters);
      }

      // Add user's conversations filter if not specified
      if (filters?.conversationIds == null) {
        final userConversations = await _getUserConversationIds();
        if (userConversations.isNotEmpty) {
          messageQuery = messageQuery.where('conversationId', whereIn: userConversations);
        }
      }

      // Execute query
      final querySnapshot = await messageQuery
          .orderBy('sentAt', descending: true)
          .limit(limit * 2)
          .get();

      // Filter messages based on search query
      final searchTerm = query.toLowerCase();
      final filteredMessages = querySnapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .where((message) => _matchesMessageSearchQuery(message, searchTerm))
          .take(limit)
          .toList();

      // Sort by relevance and date
      filteredMessages.sort((a, b) {
        final relevanceA = _calculateMessageRelevanceScore(a, searchTerm);
        final relevanceB = _calculateMessageRelevanceScore(b, searchTerm);
        if (relevanceA != relevanceB) {
          return relevanceB.compareTo(relevanceA);
        }
        return b.sentAt.compareTo(a.sentAt);
      });

      final result = MessageSearchResult(
        messages: filteredMessages,
        totalResults: filteredMessages.length,
        hasMore: querySnapshot.docs.length >= limit * 2,
        searchQuery: query,
        appliedFilters: filters,
      );

      // Cache the result
      _searchCache[cacheKey] = result;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Emit to stream
      _messageSearchController.add(filteredMessages);

      debugPrint('MessagingSearchService: Message search found ${filteredMessages.length} results for "$query"');
      return result;
    } catch (e) {
      debugPrint('MessagingSearchService: Error searching messages: $e');
      return MessageSearchResult(
        messages: [],
        totalResults: 0,
        hasMore: false,
        searchQuery: query,
        appliedFilters: filters,
        error: e.toString(),
      );
    }
  }

  /// Real-time message search stream
  /// Requirements: 4.2, 4.3
  Stream<List<MessageModel>> getMessageSearchStream() {
    return _messageSearchController.stream;
  }

  /// Search within specific conversation
  /// Requirements: 4.2, 4.3
  Future<MessageSearchResult> searchInConversation({
    required String conversationId,
    required String query,
    MessageSearchFilters? filters,
    int limit = 50,
  }) async {
    try {
      final conversationFilters = MessageSearchFilters(
        conversationIds: [conversationId],
        messageTypes: filters?.messageTypes,
        senderIds: filters?.senderIds,
        startDate: filters?.startDate,
        endDate: filters?.endDate,
        includeDeleted: filters?.includeDeleted ?? false,
      );

      return await searchMessages(
        query: query,
        filters: conversationFilters,
        limit: limit,
      );
    } catch (e) {
      debugPrint('MessagingSearchService: Error searching in conversation: $e');
      return MessageSearchResult(
        messages: [],
        totalResults: 0,
        hasMore: false,
        searchQuery: query,
        appliedFilters: filters,
        error: e.toString(),
      );
    }
  }

  // ==================== ADVANCED FILTERING ====================

  /// Get users with advanced filtering options
  /// Requirements: 4.3, 4.4
  Future<UserSearchResult> getFilteredUsers({
    required UserSearchFilters filters,
    int limit = 50,
  }) async {
    try {
      Query userQuery = _firestore
          .collection('users')
          .where('isActive', isEqualTo: true);

      // Apply all filters
      userQuery = _applyUserFilters(userQuery, filters);

      final querySnapshot = await userQuery.limit(limit).get();
      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Apply local filters
      final filteredUsers = _applyLocalUserFilters(users, filters);

      return UserSearchResult(
        users: filteredUsers,
        totalResults: filteredUsers.length,
        hasMore: querySnapshot.docs.length >= limit,
        searchQuery: '',
        appliedFilters: filters,
      );
    } catch (e) {
      debugPrint('MessagingSearchService: Error getting filtered users: $e');
      return UserSearchResult(
        users: [],
        totalResults: 0,
        hasMore: false,
        searchQuery: '',
        appliedFilters: filters,
        error: e.toString(),
      );
    }
  }

  // ==================== SEARCH SUGGESTIONS ====================

  /// Get search suggestions based on query
  /// Requirements: 4.4, 4.5
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      if (query.length < 2) return [];

      final suggestions = <String>[];

      // Add suggestions from search history
      final historySuggestions = _searchHistory
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .take(3)
          .toList();
      suggestions.addAll(historySuggestions);

      // Add user name suggestions
      final userSuggestions = await _getUserNameSuggestions(query);
      suggestions.addAll(userSuggestions.take(3));

      // Add conversation name suggestions
      final conversationSuggestions = await _getConversationNameSuggestions(query);
      suggestions.addAll(conversationSuggestions.take(2));

      // Add common search patterns
      suggestions.addAll([
        'messages from $query',
        'images from $query',
        'documents containing $query',
      ]);

      // Remove duplicates and limit results
      return suggestions.toSet().take(10).toList();
    } catch (e) {
      debugPrint('MessagingSearchService: Error getting search suggestions: $e');
      return [];
    }
  }

  // ==================== SEARCH HISTORY & SAVED SEARCHES ====================

  /// Get search history
  /// Requirements: 4.6
  List<String> getSearchHistory() {
    return List.from(_searchHistory);
  }

  /// Clear search history
  /// Requirements: 4.6
  Future<void> clearSearchHistory() async {
    try {
      _searchHistory.clear();
      await _saveSearchHistory();
      debugPrint('MessagingSearchService: Search history cleared');
    } catch (e) {
      debugPrint('MessagingSearchService: Error clearing search history: $e');
    }
  }

  /// Save search query for frequent use
  /// Requirements: 4.6
  Future<void> saveSearch(String name, String query) async {
    try {
      _savedSearches[name] = [query];
      
      // Limit saved searches
      if (_savedSearches.length > _maxSavedSearches) {
        final oldestKey = _savedSearches.keys.first;
        _savedSearches.remove(oldestKey);
      }
      
      await _saveSavedSearches();
      debugPrint('MessagingSearchService: Search saved as "$name"');
    } catch (e) {
      debugPrint('MessagingSearchService: Error saving search: $e');
    }
  }

  /// Get saved searches
  /// Requirements: 4.6
  Map<String, List<String>> getSavedSearches() {
    return Map.from(_savedSearches);
  }

  /// Delete saved search
  /// Requirements: 4.6
  Future<void> deleteSavedSearch(String name) async {
    try {
      _savedSearches.remove(name);
      await _saveSavedSearches();
      debugPrint('MessagingSearchService: Saved search "$name" deleted');
    } catch (e) {
      debugPrint('MessagingSearchService: Error deleting saved search: $e');
    }
  }

  // ==================== SEARCH RESULT HIGHLIGHTING ====================

  /// Get highlighted search results with navigation
  /// Requirements: 4.4
  List<SearchHighlight> getSearchHighlights(String content, String query) {
    final highlights = <SearchHighlight>[];
    final searchTerm = query.toLowerCase();
    final contentLower = content.toLowerCase();
    
    int startIndex = 0;
    while (true) {
      final index = contentLower.indexOf(searchTerm, startIndex);
      if (index == -1) break;
      
      highlights.add(SearchHighlight(
        startIndex: index,
        endIndex: index + searchTerm.length,
        matchedText: content.substring(index, index + searchTerm.length),
      ));
      
      startIndex = index + searchTerm.length;
    }
    
    return highlights;
  }

  // ==================== EMPTY STATES ====================

  /// Get appropriate empty state message
  /// Requirements: 4.5
  String getEmptyStateMessage(String query, {bool isUserSearch = true}) {
    if (query.trim().isEmpty) {
      return isUserSearch 
          ? 'Start typing to search for users'
          : 'Start typing to search messages';
    }
    
    return isUserSearch
        ? 'No users found for "$query"\nTry different keywords or check filters'
        : 'No messages found for "$query"\nTry different keywords or expand date range';
  }

  /// Get search suggestions for empty state
  /// Requirements: 4.5
  List<String> getEmptyStateSuggestions() {
    return [
      'Try searching by name or phone number',
      'Use filters to narrow down results',
      'Check your spelling',
      'Try broader search terms',
      'Clear filters to see all results',
    ];
  }

  // ==================== CACHE MANAGEMENT ====================

  /// Clear search cache
  void clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
    debugPrint('MessagingSearchService: Search cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedSearches': _searchCache.length,
      'searchHistory': _searchHistory.length,
      'savedSearches': _savedSearches.length,
      'oldestCache': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _userSearchController.close();
      await _messageSearchController.close();
      clearCache();
      debugPrint('MessagingSearchService: Disposed successfully');
    } catch (e) {
      debugPrint('MessagingSearchService: Error disposing: $e');
    }
  }

  // ==================== PRIVATE HELPER METHODS ====================

  /// Apply user filters to Firestore query
  Query _applyUserFilters(Query query, UserSearchFilters filters) {
    if (filters.roles != null && filters.roles!.isNotEmpty) {
      query = query.where('role', whereIn: filters.roles);
    }
    
    if (filters.locations != null && filters.locations!.isNotEmpty) {
      query = query.where('address.state', whereIn: filters.locations);
    }
    
    if (filters.onlineOnly == true) {
      final recentThreshold = DateTime.now().subtract(const Duration(hours: 24));
      query = query.where('lastLoginAt', isGreaterThan: Timestamp.fromDate(recentThreshold));
    }
    
    return query;
  }

  /// Apply local user filters that can't be done in Firestore
  List<UserModel> _applyLocalUserFilters(List<UserModel> users, UserSearchFilters? filters) {
    if (filters == null) return users;
    
    return users.where((user) {
      // Recent activity filter
      if (filters.recentActivityOnly == true) {
        final recentThreshold = DateTime.now().subtract(const Duration(days: 7));
        if (user.lastLoginAt == null || user.lastLoginAt!.isBefore(recentThreshold)) return false;
      }
      
      return true;
    }).toList();
  }

  /// Apply message filters to Firestore query
  Query _applyMessageFilters(Query query, MessageSearchFilters filters) {
    if (filters.conversationIds != null && filters.conversationIds!.isNotEmpty) {
      query = query.where('conversationId', whereIn: filters.conversationIds);
    }
    
    if (filters.messageTypes != null && filters.messageTypes!.isNotEmpty) {
      final typeStrings = filters.messageTypes!.map((type) => type.value).toList();
      query = query.where('messageType', whereIn: typeStrings);
    }
    
    if (filters.senderIds != null && filters.senderIds!.isNotEmpty) {
      query = query.where('senderId', whereIn: filters.senderIds);
    }
    
    if (filters.startDate != null) {
      query = query.where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(filters.startDate!));
    }
    
    if (filters.endDate != null) {
      query = query.where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(filters.endDate!));
    }
    
    if (!filters.includeDeleted) {
      query = query.where('isDeleted', isEqualTo: false);
    }
    
    return query;
  }

  /// Check if user matches search query
  bool _matchesUserSearchQuery(UserModel user, String searchTerm) {
    return user.fullName.toLowerCase().contains(searchTerm) ||
           user.phoneNumber.contains(searchTerm) ||
           user.role.toLowerCase().contains(searchTerm) ||
           user.memberId.toLowerCase().contains(searchTerm) ||
           user.address.villageCity.toLowerCase().contains(searchTerm) ||
           user.address.mandal.toLowerCase().contains(searchTerm) ||
           user.address.district.toLowerCase().contains(searchTerm);
  }

  /// Check if message matches search query
  bool _matchesMessageSearchQuery(MessageModel message, String searchTerm) {
    return message.content.toLowerCase().contains(searchTerm) ||
           message.senderName.toLowerCase().contains(searchTerm);
  }

  /// Calculate user relevance score for search results
  int _calculateUserRelevanceScore(UserModel user, String searchTerm) {
    int score = 0;
    
    // Exact name match gets highest score
    if (user.fullName.toLowerCase() == searchTerm) score += 100;
    else if (user.fullName.toLowerCase().startsWith(searchTerm)) score += 50;
    else if (user.fullName.toLowerCase().contains(searchTerm)) score += 25;
    
    // Phone number match
    if (user.phoneNumber.contains(searchTerm)) score += 30;
    
    // Role match
    if (user.role.toLowerCase().contains(searchTerm)) score += 20;
    
    // Recent activity bonus
    if (user.lastLoginAt != null) {
      final daysSinceLogin = DateTime.now().difference(user.lastLoginAt!).inDays;
      if (daysSinceLogin < 1) score += 10;
      else if (daysSinceLogin < 7) score += 5;
    }
    
    return score;
  }

  /// Calculate message relevance score for search results
  int _calculateMessageRelevanceScore(MessageModel message, String searchTerm) {
    int score = 0;
    
    // Content match scoring
    final contentLower = message.content.toLowerCase();
    final termCount = searchTerm.split(' ').where((term) => 
        contentLower.contains(term.toLowerCase())).length;
    score += termCount * 10;
    
    // Exact phrase match bonus
    if (contentLower.contains(searchTerm)) score += 20;
    
    // Sender name match
    if (message.senderName.toLowerCase().contains(searchTerm)) score += 15;
    
    // Recent message bonus
    final hoursAgo = DateTime.now().difference(message.sentAt).inHours;
    if (hoursAgo < 24) score += 5;
    else if (hoursAgo < 168) score += 2; // 1 week
    
    return score;
  }

  /// Generate cache key for user search
  String _generateUserSearchCacheKey(String query, UserSearchFilters? filters) {
    final filterHash = filters?.hashCode ?? 0;
    return 'user_search_${query.hashCode}_$filterHash';
  }

  /// Generate cache key for message search
  String _generateMessageSearchCacheKey(String query, MessageSearchFilters? filters) {
    final filterHash = filters?.hashCode ?? 0;
    return 'message_search_${query.hashCode}_$filterHash';
  }

  /// Check if cache is valid
  bool _isValidCache(String cacheKey) {
    if (!_searchCache.containsKey(cacheKey) || !_cacheTimestamps.containsKey(cacheKey)) {
      return false;
    }
    
    final cacheAge = DateTime.now().difference(_cacheTimestamps[cacheKey]!);
    return cacheAge < _cacheDuration;
  }

  /// Add query to search history
  void _addToSearchHistory(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    
    // Remove if already exists
    _searchHistory.remove(trimmedQuery);
    
    // Add to beginning
    _searchHistory.insert(0, trimmedQuery);
    
    // Limit history size
    if (_searchHistory.length > _maxSearchHistory) {
      _searchHistory.removeRange(_maxSearchHistory, _searchHistory.length);
    }
    
    // Save to persistent storage
    _saveSearchHistory();
  }

  /// Get user conversation IDs for filtering
  Future<List<String>> _getUserConversationIds() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];
      
      final snapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUser.uid)
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('MessagingSearchService: Error getting user conversations: $e');
      return [];
    }
  }

  /// Get user name suggestions
  Future<List<String>> _getUserNameSuggestions(String query) async {
    try {
      final result = await _userListService.searchUsers(
        query: query,
        limit: 5,
      );
      
      return result.users.map((user) => user.fullName).toList();
    } catch (e) {
      debugPrint('MessagingSearchService: Error getting user name suggestions: $e');
      return [];
    }
  }

  /// Get conversation name suggestions
  Future<List<String>> _getConversationNameSuggestions(String query) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return [];
      
      final snapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUser.uid)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(5)
          .get();
      
      return snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc).name)
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('MessagingSearchService: Error getting conversation suggestions: $e');
      return [];
    }
  }

  /// Load search history from persistent storage
  Future<void> _loadSearchHistory() async {
    try {
      // In a real implementation, this would load from SharedPreferences or similar
      debugPrint('MessagingSearchService: Search history loaded');
    } catch (e) {
      debugPrint('MessagingSearchService: Error loading search history: $e');
    }
  }

  /// Save search history to persistent storage
  Future<void> _saveSearchHistory() async {
    try {
      // In a real implementation, this would save to SharedPreferences or similar
      debugPrint('MessagingSearchService: Search history saved');
    } catch (e) {
      debugPrint('MessagingSearchService: Error saving search history: $e');
    }
  }

  /// Load saved searches from persistent storage
  Future<void> _loadSavedSearches() async {
    try {
      // In a real implementation, this would load from SharedPreferences or similar
      debugPrint('MessagingSearchService: Saved searches loaded');
    } catch (e) {
      debugPrint('MessagingSearchService: Error loading saved searches: $e');
    }
  }

  /// Save saved searches to persistent storage
  Future<void> _saveSavedSearches() async {
    try {
      // In a real implementation, this would save to SharedPreferences or similar
      debugPrint('MessagingSearchService: Saved searches saved');
    } catch (e) {
      debugPrint('MessagingSearchService: Error saving saved searches: $e');
    }
  }
}

// ==================== DATA MODELS ====================

/// User search filters
class UserSearchFilters {
  final List<String>? roles;
  final List<String>? locations;
  final bool? onlineOnly;
  final bool? recentActivityOnly;

  const UserSearchFilters({
    this.roles,
    this.locations,
    this.onlineOnly,
    this.recentActivityOnly,
  });

  @override
  int get hashCode => Object.hash(roles, locations, onlineOnly, recentActivityOnly);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSearchFilters &&
        other.roles == roles &&
        other.locations == locations &&
        other.onlineOnly == onlineOnly &&
        other.recentActivityOnly == recentActivityOnly;
  }
}

/// Message search filters
class MessageSearchFilters {
  final List<String>? conversationIds;
  final List<MessageType>? messageTypes;
  final List<String>? senderIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool includeDeleted;

  const MessageSearchFilters({
    this.conversationIds,
    this.messageTypes,
    this.senderIds,
    this.startDate,
    this.endDate,
    this.includeDeleted = false,
  });

  @override
  int get hashCode => Object.hash(
    conversationIds, messageTypes, senderIds, startDate, endDate, includeDeleted);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageSearchFilters &&
        other.conversationIds == conversationIds &&
        other.messageTypes == messageTypes &&
        other.senderIds == senderIds &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.includeDeleted == includeDeleted;
  }
}

/// User search result
class UserSearchResult extends SearchResult {
  final List<UserModel> users;
  final UserSearchFilters? appliedFilters;

  const UserSearchResult({
    required this.users,
    required super.totalResults,
    required super.hasMore,
    required super.searchQuery,
    this.appliedFilters,
    super.error,
  });

  @override
  bool get isEmpty => users.isEmpty;
}

/// Message search result
class MessageSearchResult extends SearchResult {
  final List<MessageModel> messages;
  final MessageSearchFilters? appliedFilters;

  const MessageSearchResult({
    required this.messages,
    required super.totalResults,
    required super.hasMore,
    required super.searchQuery,
    this.appliedFilters,
    super.error,
  });

  @override
  bool get isEmpty => messages.isEmpty;
}

/// Base search result class
abstract class SearchResult {
  final int totalResults;
  final bool hasMore;
  final String searchQuery;
  final String? error;

  const SearchResult({
    required this.totalResults,
    required this.hasMore,
    required this.searchQuery,
    this.error,
  });

  bool get isSuccess => error == null;
  bool get isEmpty;
}

/// Search highlight for result navigation
class SearchHighlight {
  final int startIndex;
  final int endIndex;
  final String matchedText;

  const SearchHighlight({
    required this.startIndex,
    required this.endIndex,
    required this.matchedText,
  });

  int get length => endIndex - startIndex;
}