// Lazy Loading Service for TALOWA
// Implements efficient lazy loading for large group member lists and conversation history
// Requirements: 1.1, 8.4

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/messaging/message_model.dart';
import '../auth_service.dart';
import 'redis_cache_service.dart';
import '../database/database_optimization_service.dart';

class LazyLoadingService {
  static final LazyLoadingService _instance = LazyLoadingService._internal();
  factory LazyLoadingService() => _instance;
  LazyLoadingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RedisCacheService _cacheService = RedisCacheService();
  final DatabaseOptimizationService _dbOptimization = DatabaseOptimizationService();
  
  // Lazy loading configuration
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int preloadThreshold = 5; // Load more when this many items from end
  static const Duration cacheExpiration = Duration(minutes: 15);
  
  // Track loading states
  final Map<String, LazyLoadingState> _loadingStates = {};
  final Map<String, StreamController<LazyLoadingUpdate>> _updateControllers = {};

  /// Initialize lazy loading service
  Future<void> initialize() async {
    try {
      await _cacheService.initialize();
      await _dbOptimization.initialize();
      debugPrint('LazyLoadingService initialized');
    } catch (e) {
      debugPrint('Error initializing LazyLoadingService: $e');
    }
  }

  /// Lazy load group members with virtual scrolling support
  Future<LazyLoadResult<UserModel>> lazyLoadGroupMembers({
    required String groupId,
    int page = 0,
    int pageSize = defaultPageSize,
    String? searchQuery,
    GroupMemberFilter? filter,
    bool useCache = true,
  }) async {
    try {
      final loadingKey = 'group_members_$groupId';
      _updateLoadingState(loadingKey, isLoading: true);
      
      // Check cache first
      if (useCache) {
        final cachedMembers = await _cacheService.getCachedGroupMembers(
          groupId: groupId,
          page: page,
        );
        
        if (cachedMembers != null) {
          final members = cachedMembers
              .map((data) => UserModel.fromMap(data))
              .toList();
          
          final result = LazyLoadResult<UserModel>(
            items: members,
            page: page,
            pageSize: pageSize,
            hasMore: members.length == pageSize,
            totalCount: null,
            fromCache: true,
            loadingKey: loadingKey,
          );
          
          _updateLoadingState(loadingKey, isLoading: false);
          _notifyUpdate(loadingKey, LazyLoadingUpdate.loaded(result));
          
          return result;
        }
      }
      
      // Load from Firestore with optimization
      final result = await _dbOptimization.executePaginatedQuery<UserModel>(
        queryKey: 'group_members_$groupId',
        queryBuilder: () => _buildGroupMembersQuery(groupId, searchQuery, filter),
        documentMapper: (doc) => UserModel.fromFirestore(doc),
        limit: pageSize,
        useCache: useCache,
      );
      
      // Cache the results
      if (useCache && result.data.isNotEmpty) {
        final memberData = result.data.map((member) => member.toMap()).toList();
        await _cacheService.cacheGroupMembers(
          groupId: groupId,
          members: memberData,
          page: page,
          pageSize: pageSize,
        );
      }
      
      final lazyResult = LazyLoadResult<UserModel>(
        items: result.data,
        page: page,
        pageSize: pageSize,
        hasMore: result.hasMore,
        totalCount: null,
        fromCache: result.fromCache,
        loadingKey: loadingKey,
        executionTime: result.executionTime,
      );
      
      _updateLoadingState(loadingKey, isLoading: false, result: lazyResult);
      _notifyUpdate(loadingKey, LazyLoadingUpdate.loaded(lazyResult));
      
      return lazyResult;
    } catch (e) {
      debugPrint('Error lazy loading group members: $e');
      final errorResult = LazyLoadResult<UserModel>(
        items: [],
        page: page,
        pageSize: pageSize,
        hasMore: false,
        totalCount: 0,
        fromCache: false,
        loadingKey: 'group_members_$groupId',
        error: e.toString(),
      );
      
      _updateLoadingState('group_members_$groupId', isLoading: false, error: e.toString());
      _notifyUpdate('group_members_$groupId', LazyLoadingUpdate.error(e.toString()));
      
      return errorResult;
    }
  }

  /// Lazy load conversation history with intelligent preloading
  Future<LazyLoadResult<MessageModel>> lazyLoadConversationHistory({
    required String conversationId,
    int page = 0,
    int pageSize = defaultPageSize,
    DateTime? beforeTimestamp,
    bool useCache = true,
    bool preloadNext = true,
  }) async {
    try {
      final loadingKey = 'conversation_history_$conversationId';
      _updateLoadingState(loadingKey, isLoading: true);
      
      // Check cache first
      if (useCache) {
        final cachedMessages = await _cacheService.getCachedMessagesPaginated(
          conversationId: conversationId,
          page: page,
        );
        
        if (cachedMessages != null) {
          final messages = cachedMessages
              .map((data) => MessageModel.fromMap(data))
              .toList();
          
          final result = LazyLoadResult<MessageModel>(
            items: messages,
            page: page,
            pageSize: pageSize,
            hasMore: messages.length == pageSize,
            totalCount: null,
            fromCache: true,
            loadingKey: loadingKey,
          );
          
          _updateLoadingState(loadingKey, isLoading: false);
          _notifyUpdate(loadingKey, LazyLoadingUpdate.loaded(result));
          
          // Preload next page if requested
          if (preloadNext && result.hasMore) {
            _preloadNextPage(conversationId, page + 1, pageSize);
          }
          
          return result;
        }
      }
      
      // Load from Firestore
      final result = await _dbOptimization.executePaginatedQuery<MessageModel>(
        queryKey: 'conversation_history_$conversationId',
        queryBuilder: () => _buildConversationHistoryQuery(conversationId, beforeTimestamp),
        documentMapper: (doc) => MessageModel.fromFirestore(doc),
        limit: pageSize,
        useCache: useCache,
      );
      
      // Cache the results
      if (useCache && result.data.isNotEmpty) {
        final messageData = result.data.map((message) => message.toMap()).toList();
        await _cacheService.cacheMessagesPaginated(
          conversationId: conversationId,
          messages: messageData,
          page: page,
          pageSize: pageSize,
        );
      }
      
      final lazyResult = LazyLoadResult<MessageModel>(
        items: result.data,
        page: page,
        pageSize: pageSize,
        hasMore: result.hasMore,
        totalCount: null,
        fromCache: result.fromCache,
        loadingKey: loadingKey,
        executionTime: result.executionTime,
      );
      
      _updateLoadingState(loadingKey, isLoading: false, result: lazyResult);
      _notifyUpdate(loadingKey, LazyLoadingUpdate.loaded(lazyResult));
      
      // Preload next page if requested
      if (preloadNext && result.hasMore) {
        _preloadNextPage(conversationId, page + 1, pageSize);
      }
      
      return lazyResult;
    } catch (e) {
      debugPrint('Error lazy loading conversation history: $e');
      final errorResult = LazyLoadResult<MessageModel>(
        items: [],
        page: page,
        pageSize: pageSize,
        hasMore: false,
        totalCount: 0,
        fromCache: false,
        loadingKey: 'conversation_history_$conversationId',
        error: e.toString(),
      );
      
      _updateLoadingState('conversation_history_$conversationId', isLoading: false, error: e.toString());
      _notifyUpdate('conversation_history_$conversationId', LazyLoadingUpdate.error(e.toString()));
      
      return errorResult;
    }
  }

  /// Virtual scrolling support - get items for visible range
  List<T> getVirtualScrollItems<T>({
    required List<T> allItems,
    required int firstVisibleIndex,
    required int lastVisibleIndex,
    int bufferSize = 5,
  }) {
    try {
      final startIndex = (firstVisibleIndex - bufferSize).clamp(0, allItems.length);
      final endIndex = (lastVisibleIndex + bufferSize).clamp(0, allItems.length);
      
      return allItems.sublist(startIndex, endIndex);
    } catch (e) {
      debugPrint('Error getting virtual scroll items: $e');
      return allItems;
    }
  }

  /// Check if more items should be loaded based on scroll position
  bool shouldLoadMore({
    required int currentItemCount,
    required int lastVisibleIndex,
    int threshold = preloadThreshold,
  }) {
    return (currentItemCount - lastVisibleIndex) <= threshold;
  }

  /// Stream lazy loading updates
  Stream<LazyLoadingUpdate> streamLazyLoadingUpdates(String loadingKey) {
    if (!_updateControllers.containsKey(loadingKey)) {
      _updateControllers[loadingKey] = StreamController<LazyLoadingUpdate>.broadcast();
    }
    
    return _updateControllers[loadingKey]!.stream;
  }

  /// Get current loading state
  LazyLoadingState? getLoadingState(String loadingKey) {
    return _loadingStates[loadingKey];
  }

  /// Cancel loading operation
  void cancelLoading(String loadingKey) {
    _updateLoadingState(loadingKey, isLoading: false, cancelled: true);
    _notifyUpdate(loadingKey, LazyLoadingUpdate.cancelled());
  }

  /// Clear lazy loading cache
  Future<void> clearLazyLoadingCache() async {
    try {
      await _cacheService.clearCache();
      _loadingStates.clear();
      
      // Close all update controllers
      for (final controller in _updateControllers.values) {
        await controller.close();
      }
      _updateControllers.clear();
      
      debugPrint('Lazy loading cache cleared');
    } catch (e) {
      debugPrint('Error clearing lazy loading cache: $e');
    }
  }

  /// Get lazy loading statistics
  Map<String, dynamic> getLazyLoadingStatistics() {
    final activeLoadings = _loadingStates.values.where((state) => state.isLoading).length;
    final totalLoadings = _loadingStates.length;
    final cacheStats = _cacheService.getCacheStatistics();
    
    return {
      'active_loadings': activeLoadings,
      'total_loadings': totalLoadings,
      'cache_statistics': cacheStats,
      'update_controllers': _updateControllers.length,
      'loading_states': _loadingStates.map((key, state) => MapEntry(key, state.toMap())),
    };
  }

  // Private methods

  Query _buildGroupMembersQuery(String groupId, String? searchQuery, GroupMemberFilter? filter) {
    Query query = _firestore
        .collection('users')
        .where('groupIds', arrayContains: groupId)
        .where('isActive', isEqualTo: true);
    
    if (filter != null) {
      switch (filter.type) {
        case GroupMemberFilterType.role:
          query = query.where('role', isEqualTo: filter.value);
          break;
        case GroupMemberFilterType.location:
          query = query.where('address.district', isEqualTo: filter.value);
          break;
        case GroupMemberFilterType.joinedAfter:
          query = query.where('createdAt', isGreaterThan: filter.value);
          break;
      }
    }
    
    return query.orderBy('fullName');
  }

  Query _buildConversationHistoryQuery(String conversationId, DateTime? beforeTimestamp) {
    Query query = _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('isDeleted', isEqualTo: false);
    
    if (beforeTimestamp != null) {
      query = query.where('sentAt', isLessThan: Timestamp.fromDate(beforeTimestamp));
    }
    
    return query.orderBy('sentAt', descending: true);
  }

  void _updateLoadingState(
    String loadingKey, {
    required bool isLoading,
    LazyLoadResult? result,
    String? error,
    bool cancelled = false,
  }) {
    _loadingStates[loadingKey] = LazyLoadingState(
      loadingKey: loadingKey,
      isLoading: isLoading,
      lastResult: result,
      error: error,
      cancelled: cancelled,
      lastUpdated: DateTime.now(),
    );
  }

  void _notifyUpdate(String loadingKey, LazyLoadingUpdate update) {
    final controller = _updateControllers[loadingKey];
    if (controller != null && !controller.isClosed) {
      controller.add(update);
    }
  }

  Future<void> _preloadNextPage(String conversationId, int nextPage, int pageSize) async {
    try {
      // Preload in background without blocking
      lazyLoadConversationHistory(
        conversationId: conversationId,
        page: nextPage,
        pageSize: pageSize,
        preloadNext: false, // Avoid infinite preloading
      ).catchError((error) {
        debugPrint('Error preloading next page: $error');
      });
    } catch (e) {
      debugPrint('Error in preload next page: $e');
    }
  }
}

/// Lazy loading result
class LazyLoadResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final bool hasMore;
  final int? totalCount;
  final bool fromCache;
  final String loadingKey;
  final int? executionTime;
  final String? error;

  LazyLoadResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    this.totalCount,
    this.fromCache = false,
    required this.loadingKey,
    this.executionTime,
    this.error,
  });

  bool get hasError => error != null;
  bool get isEmpty => items.isEmpty;
  int get itemCount => items.length;
}

/// Lazy loading state
class LazyLoadingState {
  final String loadingKey;
  final bool isLoading;
  final LazyLoadResult? lastResult;
  final String? error;
  final bool cancelled;
  final DateTime lastUpdated;

  LazyLoadingState({
    required this.loadingKey,
    required this.isLoading,
    this.lastResult,
    this.error,
    this.cancelled = false,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'loadingKey': loadingKey,
      'isLoading': isLoading,
      'hasResult': lastResult != null,
      'error': error,
      'cancelled': cancelled,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Lazy loading update
class LazyLoadingUpdate {
  final LazyLoadingUpdateType type;
  final LazyLoadResult? result;
  final String? error;
  final DateTime timestamp;

  LazyLoadingUpdate._({
    required this.type,
    this.result,
    this.error,
    required this.timestamp,
  });

  factory LazyLoadingUpdate.loading() {
    return LazyLoadingUpdate._(
      type: LazyLoadingUpdateType.loading,
      timestamp: DateTime.now(),
    );
  }

  factory LazyLoadingUpdate.loaded(LazyLoadResult result) {
    return LazyLoadingUpdate._(
      type: LazyLoadingUpdateType.loaded,
      result: result,
      timestamp: DateTime.now(),
    );
  }

  factory LazyLoadingUpdate.error(String error) {
    return LazyLoadingUpdate._(
      type: LazyLoadingUpdateType.error,
      error: error,
      timestamp: DateTime.now(),
    );
  }

  factory LazyLoadingUpdate.cancelled() {
    return LazyLoadingUpdate._(
      type: LazyLoadingUpdateType.cancelled,
      timestamp: DateTime.now(),
    );
  }
}

/// Lazy loading update types
enum LazyLoadingUpdateType {
  loading,
  loaded,
  error,
  cancelled,
}

/// Group member filter
class GroupMemberFilter {
  final GroupMemberFilterType type;
  final dynamic value;

  GroupMemberFilter({
    required this.type,
    required this.value,
  });
}

/// Group member filter types
enum GroupMemberFilterType {
  role,
  location,
  joinedAfter,
}