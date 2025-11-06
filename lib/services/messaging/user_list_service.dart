// User List Service for TALOWA Messaging System
// Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 4.1, 4.2
// Task: Build real user data display and user listing functionality

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';

import 'user_discovery_service.dart';

/// Service for managing user lists in messaging interface
/// Provides real-time user data with proper loading states and error handling
class UserListService {
  static final UserListService _instance = UserListService._internal();
  factory UserListService() => _instance;
  UserListService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserDiscoveryService _userDiscovery = UserDiscoveryService();
  
  // Cache for user lists
  final Map<String, List<UserModel>> _userListCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // Pagination state
  final Map<String, DocumentSnapshot?> _lastDocuments = {};
  final Map<String, bool> _hasMoreData = {};
  
  // Stream controllers for real-time updates
  final Map<String, StreamController<UserListResult>> _streamControllers = {};
  final Map<String, StreamSubscription> _firestoreSubscriptions = {};

  /// Initialize the user list service
  Future<void> initialize() async {
    try {
      debugPrint('UserListService: Initializing');
      await _userDiscovery.initialize();
      debugPrint('UserListService: Initialized successfully');
    } catch (e) {
      debugPrint('UserListService: Error initializing: $e');
    }
  }

  /// Get all active users with pagination support
  /// Requirements: 1.1, 1.2
  Future<UserListResult> getAllActiveUsers({
    int limit = 20,
    bool loadMore = false,
    bool useCache = true,
  }) async {
    const cacheKey = 'all_active_users';
    
    try {
      // Check cache first (only for initial load)
      if (!loadMore && useCache && _isValidCache(cacheKey)) {
        debugPrint('UserListService: Returning cached active users');
        return UserListResult(
          users: _userListCache[cacheKey]!,
          hasMore: _hasMoreData[cacheKey] ?? false,
          isFromCache: true,
        );
      }

      Query query = _firestore
          .collection(AppConstants.collectionUsers)
          .where('isActive', isEqualTo: true)
          .orderBy('fullName');

      // Handle pagination
      if (loadMore && _lastDocuments[cacheKey] != null) {
        query = query.startAfterDocument(_lastDocuments[cacheKey]!);
      }

      final querySnapshot = await query.limit(limit + 1).get();
      
      // Check if there are more documents
      final hasMore = querySnapshot.docs.length > limit;
      final users = querySnapshot.docs
          .take(limit)
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Update pagination state
      if (users.isNotEmpty) {
        _lastDocuments[cacheKey] = querySnapshot.docs[users.length - 1];
      }
      _hasMoreData[cacheKey] = hasMore;

      // Update cache
      if (loadMore) {
        _userListCache[cacheKey] = [...(_userListCache[cacheKey] ?? []), ...users];
      } else {
        _userListCache[cacheKey] = users;
      }
      _cacheTimestamps[cacheKey] = DateTime.now();

      debugPrint('UserListService: Fetched ${users.length} active users (hasMore: $hasMore)');
      
      return UserListResult(
        users: loadMore ? _userListCache[cacheKey]! : users,
        hasMore: hasMore,
        isFromCache: false,
      );
    } catch (e) {
      debugPrint('UserListService: Error getting active users: $e');
      return UserListResult(
        users: [],
        hasMore: false,
        isFromCache: false,
        error: e.toString(),
      );
    }
  }

  /// Search users with real-time filtering
  /// Requirements: 4.1, 4.2
  Future<UserListResult> searchUsers({
    required String query,
    String? role,
    String? location,
    int limit = 20,
    bool loadMore = false,
  }) async {
    final cacheKey = 'search_${query}_${role}_$location';
    
    try {
      if (query.trim().isEmpty) {
        return UserListResult(users: [], hasMore: false, isFromCache: false);
      }

      // For search, we'll get a larger dataset and filter locally for better performance
      Query firestoreQuery = _firestore
          .collection(AppConstants.collectionUsers)
          .where('isActive', isEqualTo: true);

      // Apply role filter if specified
      if (role != null && role.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('role', isEqualTo: role);
      }

      // Handle pagination for search
      if (loadMore && _lastDocuments[cacheKey] != null) {
        firestoreQuery = firestoreQuery.startAfterDocument(_lastDocuments[cacheKey]!);
      }

      final querySnapshot = await firestoreQuery
          .orderBy('fullName')
          .limit(limit * 3) // Get more docs to filter locally
          .get();

      // Filter results based on search query
      final searchTerm = query.toLowerCase();
      final filteredUsers = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) {
            return user.fullName.toLowerCase().contains(searchTerm) ||
                   user.phoneNumber.contains(searchTerm) ||
                   user.role.toLowerCase().contains(searchTerm) ||
                   user.memberId.toLowerCase().contains(searchTerm) ||
                   user.address.villageCity.toLowerCase().contains(searchTerm) ||
                   user.address.mandal.toLowerCase().contains(searchTerm) ||
                   user.address.district.toLowerCase().contains(searchTerm);
          })
          .take(limit)
          .toList();

      // Update pagination state
      final hasMore = querySnapshot.docs.length >= limit * 3;
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocuments[cacheKey] = querySnapshot.docs.last;
      }
      _hasMoreData[cacheKey] = hasMore;

      // Update cache
      if (loadMore) {
        _userListCache[cacheKey] = [...(_userListCache[cacheKey] ?? []), ...filteredUsers];
      } else {
        _userListCache[cacheKey] = filteredUsers;
      }
      _cacheTimestamps[cacheKey] = DateTime.now();

      debugPrint('UserListService: Search found ${filteredUsers.length} users for "$query"');
      
      return UserListResult(
        users: loadMore ? _userListCache[cacheKey]! : filteredUsers,
        hasMore: hasMore,
        isFromCache: false,
      );
    } catch (e) {
      debugPrint('UserListService: Error searching users: $e');
      return UserListResult(
        users: [],
        hasMore: false,
        isFromCache: false,
        error: e.toString(),
      );
    }
  }

  /// Get online/recently active users
  /// Requirements: 1.3, 6.1
  Future<UserListResult> getOnlineUsers({
    int limit = 50,
    Duration recentThreshold = const Duration(hours: 24),
  }) async {
    const cacheKey = 'online_users';
    
    try {
      // Check cache first
      if (_isValidCache(cacheKey)) {
        debugPrint('UserListService: Returning cached online users');
        return UserListResult(
          users: _userListCache[cacheKey]!,
          hasMore: false,
          isFromCache: true,
        );
      }

      final cutoffTime = DateTime.now().subtract(recentThreshold);
      
      final querySnapshot = await _firestore
          .collection(AppConstants.collectionUsers)
          .where('isActive', isEqualTo: true)
          .where('lastLoginAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .orderBy('lastLoginAt', descending: true)
          .limit(limit)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Update cache
      _userListCache[cacheKey] = users;
      _cacheTimestamps[cacheKey] = DateTime.now();

      debugPrint('UserListService: Found ${users.length} recently active users');
      
      return UserListResult(
        users: users,
        hasMore: false,
        isFromCache: false,
      );
    } catch (e) {
      debugPrint('UserListService: Error getting online users: $e');
      return UserListResult(
        users: [],
        hasMore: false,
        isFromCache: false,
        error: e.toString(),
      );
    }
  }

  /// Get user profile with caching
  /// Requirements: 1.1, 1.2
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      return await _userDiscovery.getUserById(userId);
    } catch (e) {
      debugPrint('UserListService: Error getting user profile: $e');
      return null;
    }
  }

  /// Get multiple user profiles efficiently
  /// Requirements: 1.1, 1.2
  Future<List<UserModel>> getUserProfiles(List<String> userIds) async {
    try {
      return await _userDiscovery.getUsersByIds(userIds);
    } catch (e) {
      debugPrint('UserListService: Error getting user profiles: $e');
      return [];
    }
  }

  /// Clear cache for specific key or all caches
  void clearCache([String? cacheKey]) {
    if (cacheKey != null) {
      _userListCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      _lastDocuments.remove(cacheKey);
      _hasMoreData.remove(cacheKey);
    } else {
      _userListCache.clear();
      _cacheTimestamps.clear();
      _lastDocuments.clear();
      _hasMoreData.clear();
    }
    debugPrint('UserListService: Cache cleared${cacheKey != null ? ' for $cacheKey' : ''}');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedLists': _userListCache.length,
      'totalCachedUsers': _userListCache.values.fold(0, (sum, list) => sum + list.length),
      'activeStreams': _streamControllers.length,
      'oldestCache': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
    };
  }

  /// Dispose resources
  void dispose() {
    // Close all stream controllers
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    
    // Cancel all Firestore subscriptions
    for (final subscription in _firestoreSubscriptions.values) {
      subscription.cancel();
    }
    _firestoreSubscriptions.clear();
    
    // Clear caches
    clearCache();
    
    debugPrint('UserListService: Disposed');
  }

  // Private helper methods

  /// Check if cache is valid for given key
  bool _isValidCache(String cacheKey) {
    if (!_userListCache.containsKey(cacheKey) || !_cacheTimestamps.containsKey(cacheKey)) {
      return false;
    }
    
    final cacheAge = DateTime.now().difference(_cacheTimestamps[cacheKey]!);
    return cacheAge < _cacheDuration;
  }
}

/// Result class for user list operations
class UserListResult {
  final List<UserModel> users;
  final bool hasMore;
  final bool isFromCache;
  final String? error;

  const UserListResult({
    required this.users,
    required this.hasMore,
    required this.isFromCache,
    this.error,
  });

  bool get isSuccess => error == null;
  bool get isEmpty => users.isEmpty;
  int get count => users.length;
}