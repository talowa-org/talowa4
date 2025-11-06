// User Discovery Service for TALOWA Messaging System
// Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 4.1, 4.2

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';
import '../database_service.dart';

class UserDiscoveryService {
  static final UserDiscoveryService _instance = UserDiscoveryService._internal();
  factory UserDiscoveryService() => _instance;
  UserDiscoveryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, UserModel> _userCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 10);

  /// Initialize user discovery service
  Future<void> initialize() async {
    try {
      debugPrint('UserDiscoveryService: Initializing');
      await _preloadActiveUsers();
      debugPrint('UserDiscoveryService: Initialized successfully');
    } catch (e) {
      debugPrint('UserDiscoveryService: Error initializing: $e');
    }
  }

  /// Get all active users for messaging
  /// Requirements: 1.1, 1.2
  Future<List<UserModel>> getAllActiveUsers({
    int limit = 100,
    bool useCache = true,
  }) async {
    try {
      // Check cache first
      if (useCache && _userCache.isNotEmpty && _isCacheValid()) {
        debugPrint('UserDiscoveryService: Returning cached users (${_userCache.length})');
        return _userCache.values.toList();
      }

      // Fetch from database
      final querySnapshot = await _firestore
          .collection(AppConstants.collectionUsers)
          .where('isActive', isEqualTo: true)
          .orderBy('fullName')
          .limit(limit)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Update cache
      if (useCache) {
        _updateCache(users);
      }

      debugPrint('UserDiscoveryService: Fetched ${users.length} active users');
      return users;
    } catch (e) {
      debugPrint('UserDiscoveryService: Error getting active users: $e');
      return [];
    }
  }

  /// Get users by location for targeted messaging
  /// Requirements: 1.4, 1.5
  Future<List<UserModel>> getUsersByLocation({
    String? state,
    String? district,
    String? mandal,
    String? village,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.collectionUsers)
          .where('isActive', isEqualTo: true);

      // Apply location filters
      if (state != null) {
        query = query.where('address.state', isEqualTo: state);
      }
      if (district != null) {
        query = query.where('address.district', isEqualTo: district);
      }
      if (mandal != null) {
        query = query.where('address.mandal', isEqualTo: mandal);
      }
      if (village != null) {
        query = query.where('address.villageCity', isEqualTo: village);
      }

      final querySnapshot = await query
          .orderBy('fullName')
          .limit(limit)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      debugPrint('UserDiscoveryService: Found ${users.length} users by location');
      return users;
    } catch (e) {
      debugPrint('UserDiscoveryService: Error getting users by location: $e');
      return [];
    }
  }

  /// Search users by name, phone, or role
  /// Requirements: 4.1, 4.2
  Future<List<UserModel>> searchUsers({
    required String query,
    String? role,
    String? location,
    int limit = 20,
  }) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      // Start with base query
      Query firestoreQuery = _firestore
          .collection(AppConstants.collectionUsers)
          .where('isActive', isEqualTo: true);

      // Apply role filter if specified
      if (role != null && role.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('role', isEqualTo: role);
      }

      final querySnapshot = await firestoreQuery.limit(limit * 2).get();

      // Filter results based on search query
      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) {
            final searchTerm = query.toLowerCase();
            return user.fullName.toLowerCase().contains(searchTerm) ||
                   user.phoneNumber.contains(searchTerm) ||
                   user.role.toLowerCase().contains(searchTerm) ||
                   user.memberId.toLowerCase().contains(searchTerm);
          })
          .take(limit)
          .toList();

      debugPrint('UserDiscoveryService: Search found ${users.length} users for "$query"');
      return users;
    } catch (e) {
      debugPrint('UserDiscoveryService: Error searching users: $e');
      return [];
    }
  }

  /// Get user by ID with caching
  /// Requirements: 1.1, 1.2
  Future<UserModel?> getUserById(String userId) async {
    try {
      // Check cache first
      if (_userCache.containsKey(userId) && _isCacheValid()) {
        return _userCache[userId];
      }

      // Fetch from database
      final user = await DatabaseService.getUserProfile(userId);
      
      if (user != null) {
        // Update cache
        _userCache[userId] = user;
        _cacheTimestamps[userId] = DateTime.now();
      }

      return user;
    } catch (e) {
      debugPrint('UserDiscoveryService: Error getting user by ID: $e');
      return null;
    }
  }

  /// Get multiple users by IDs efficiently
  /// Requirements: 1.1, 1.2
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    try {
      final users = <UserModel>[];
      final uncachedIds = <String>[];

      // Check cache for each user
      for (final userId in userIds) {
        if (_userCache.containsKey(userId) && _isCacheValid()) {
          users.add(_userCache[userId]!);
        } else {
          uncachedIds.add(userId);
        }
      }

      // Fetch uncached users in batches
      if (uncachedIds.isNotEmpty) {
        const batchSize = 10; // Firestore 'in' query limit
        for (int i = 0; i < uncachedIds.length; i += batchSize) {
          final batch = uncachedIds.skip(i).take(batchSize).toList();
          
          final querySnapshot = await _firestore
              .collection(AppConstants.collectionUsers)
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          final batchUsers = querySnapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();

          users.addAll(batchUsers);

          // Update cache
          for (final user in batchUsers) {
            _userCache[user.id] = user;
            _cacheTimestamps[user.id] = DateTime.now();
          }
        }
      }

      debugPrint('UserDiscoveryService: Retrieved ${users.length} users by IDs');
      return users;
    } catch (e) {
      debugPrint('UserDiscoveryService: Error getting users by IDs: $e');
      return [];
    }
  }

  /// Get users by role for role-based messaging
  /// Requirements: 1.6
  Future<List<UserModel>> getUsersByRole({
    required String role,
    String? location,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.collectionUsers)
          .where('isActive', isEqualTo: true)
          .where('role', isEqualTo: role);

      // Apply location filter if specified
      if (location != null) {
        query = query.where('address.state', isEqualTo: location);
      }

      final querySnapshot = await query
          .orderBy('fullName')
          .limit(limit)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      debugPrint('UserDiscoveryService: Found ${users.length} users with role "$role"');
      return users;
    } catch (e) {
      debugPrint('UserDiscoveryService: Error getting users by role: $e');
      return [];
    }
  }

  /// Get online users (would integrate with presence service)
  /// Requirements: 1.3, 6.1
  Future<List<UserModel>> getOnlineUsers({int limit = 50}) async {
    try {
      // For now, return recently active users
      // This would be enhanced with real-time presence tracking
      final querySnapshot = await _firestore
          .collection(AppConstants.collectionUsers)
          .where('isActive', isEqualTo: true)
          .where('lastLoginAt', isGreaterThan: 
              Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24))))
          .orderBy('lastLoginAt', descending: true)
          .limit(limit)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      debugPrint('UserDiscoveryService: Found ${users.length} recently active users');
      return users;
    } catch (e) {
      debugPrint('UserDiscoveryService: Error getting online users: $e');
      return [];
    }
  }

  /// Stream of user updates for real-time UI updates
  /// Requirements: 1.3, 6.1
  Stream<List<UserModel>> getUserUpdatesStream({
    List<String>? userIds,
    int limit = 50,
  }) {
    try {
      Query query = _firestore
          .collection(AppConstants.collectionUsers)
          .where('isActive', isEqualTo: true);

      if (userIds != null && userIds.isNotEmpty) {
        // Listen to specific users
        const batchSize = 10;
        if (userIds.length <= batchSize) {
          query = query.where(FieldPath.documentId, whereIn: userIds);
        }
      }

      return query
          .orderBy('lastLoginAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final users = snapshot.docs
                .map((doc) => UserModel.fromFirestore(doc))
                .toList();
            
            // Update cache with fresh data
            for (final user in users) {
              _userCache[user.id] = user;
              _cacheTimestamps[user.id] = DateTime.now();
            }
            
            return users;
          });
    } catch (e) {
      debugPrint('UserDiscoveryService: Error creating user updates stream: $e');
      return Stream.value([]);
    }
  }

  /// Clear user cache
  void clearCache() {
    _userCache.clear();
    _cacheTimestamps.clear();
    debugPrint('UserDiscoveryService: Cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedUsers': _userCache.length,
      'cacheValid': _isCacheValid(),
      'oldestEntry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
    };
  }

  // Private helper methods

  /// Preload frequently accessed users
  Future<void> _preloadActiveUsers() async {
    try {
      final users = await getAllActiveUsers(limit: 50, useCache: false);
      debugPrint('UserDiscoveryService: Preloaded ${users.length} active users');
    } catch (e) {
      debugPrint('UserDiscoveryService: Error preloading users: $e');
    }
  }

  /// Update user cache
  void _updateCache(List<UserModel> users) {
    final now = DateTime.now();
    for (final user in users) {
      _userCache[user.id] = user;
      _cacheTimestamps[user.id] = now;
    }
    _manageCacheSize();
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_cacheTimestamps.isEmpty) return false;
    
    final oldestTimestamp = _cacheTimestamps.values
        .reduce((a, b) => a.isBefore(b) ? a : b);
    
    return DateTime.now().difference(oldestTimestamp) < _cacheDuration;
  }

  /// Manage cache size to prevent memory issues
  void _manageCacheSize() {
    const maxCacheSize = 200;
    
    if (_userCache.length > maxCacheSize) {
      // Remove oldest entries
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final entriesToRemove = sortedEntries.take(_userCache.length - maxCacheSize);
      
      for (final entry in entriesToRemove) {
        _userCache.remove(entry.key);
        _cacheTimestamps.remove(entry.key);
      }
      
      debugPrint('UserDiscoveryService: Cleaned up ${entriesToRemove.length} old cache entries');
    }
  }
}