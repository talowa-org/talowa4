// Enhanced Offline Message Caching Service for TALOWA
// Implements Task 5: Build offline message caching system for recent conversations
// Reference: in-app-communication/requirements.md - Requirements 5.5, 5.6, 10.1, 10.3

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';

import 'offline_messaging_service.dart';
import 'message_compression_service.dart';

class EnhancedOfflineCacheService {
  static final EnhancedOfflineCacheService _instance = EnhancedOfflineCacheService._internal();
  factory EnhancedOfflineCacheService() => _instance;
  EnhancedOfflineCacheService._internal();

  final OfflineMessagingService _offlineService = OfflineMessagingService();
  final MessageCompressionService _compressionService = MessageCompressionService();
  
  // Cache management
  final Map<String, List<MessageModel>> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, CacheMetadata> _cacheMetadata = {};
  
  // Configuration
  static const int maxMemoryCacheSize = 100; // Messages per conversation
  static const int maxTotalMemoryCache = 1000; // Total messages in memory
  static const Duration cacheExpiration = Duration(hours: 24);
  static const Duration recentConversationThreshold = Duration(days: 7);
  static const String cacheDirectory = 'message_cache';
  static const String metadataFile = 'cache_metadata.json';
  
  bool _isInitialized = false;
  bool _isOnline = true;
  Timer? _cleanupTimer;
  
  // Cache statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _totalCacheSize = 0;

  /// Initialize the enhanced offline cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Enhanced Offline Cache Service');
      
      await _offlineService.initialize();
      await _loadCacheMetadata();
      await _startConnectivityMonitoring();
      await _schedulePeriodicCleanup();
      
      _isInitialized = true;
      debugPrint('Enhanced Offline Cache Service initialized');
    } catch (e) {
      debugPrint('Error initializing enhanced offline cache service: $e');
      rethrow;
    }
  }

  /// Cache messages for a conversation
  Future<void> cacheConversationMessages({
    required String conversationId,
    required List<MessageModel> messages,
    CachePriority priority = CachePriority.normal,
    bool compress = true,
  }) async {
    try {
      if (messages.isEmpty) return;

      // Update memory cache
      await _updateMemoryCache(conversationId, messages);
      
      // Cache to disk for persistence
      await _cacheToDisk(conversationId, messages, priority, compress);
      
      // Update metadata
      await _updateCacheMetadata(conversationId, messages.length, priority);
      
      debugPrint('Cached ${messages.length} messages for conversation $conversationId');
    } catch (e) {
      debugPrint('Error caching conversation messages: $e');
    }
  }

  /// Get cached messages for a conversation
  Future<List<MessageModel>?> getCachedMessages({
    required String conversationId,
    int? limit,
    bool includeExpired = false,
  }) async {
    try {
      // Check memory cache first
      final memoryMessages = _getFromMemoryCache(conversationId, limit);
      if (memoryMessages != null) {
        _cacheHits++;
        return memoryMessages;
      }

      // Check disk cache
      final diskMessages = await _getFromDiskCache(conversationId, limit, includeExpired);
      if (diskMessages != null) {
        // Update memory cache with disk data
        await _updateMemoryCache(conversationId, diskMessages);
        _cacheHits++;
        return diskMessages;
      }

      _cacheMisses++;
      return null;
    } catch (e) {
      debugPrint('Error getting cached messages: $e');
      _cacheMisses++;
      return null;
    }
  }

  /// Cache recent conversations for offline access
  Future<void> cacheRecentConversations({
    required List<ConversationModel> conversations,
    int messagesPerConversation = 50,
  }) async {
    try {
      final recentConversations = conversations
          .where((conv) => conv.lastMessageAt.isAfter(
              DateTime.now().subtract(recentConversationThreshold)))
          .take(20) // Limit to 20 most recent conversations
          .toList();

      for (final conversation in recentConversations) {
        try {
          // Get messages from offline service
          final messages = await _offlineService.getOfflineMessages(
            conversationId: conversation.id,
            limit: messagesPerConversation,
          );

          if (messages.isNotEmpty) {
            await cacheConversationMessages(
              conversationId: conversation.id,
              messages: List<MessageModel>.from(messages),
              priority: CachePriority.high,
            );
          }
        } catch (e) {
          debugPrint('Error caching conversation ${conversation.id}: $e');
        }
      }

      debugPrint('Cached ${recentConversations.length} recent conversations');
    } catch (e) {
      debugPrint('Error caching recent conversations: $e');
    }
  }

  /// Preload messages for upcoming conversations
  Future<void> preloadConversationMessages({
    required List<String> conversationIds,
    int messagesPerConversation = 30,
  }) async {
    try {
      if (!_isOnline) return; // Only preload when online

      for (final conversationId in conversationIds) {
        try {
          // Check if already cached
          final cached = await getCachedMessages(conversationId: conversationId);
          if (cached != null && cached.length >= messagesPerConversation) {
            continue; // Already sufficiently cached
          }

          // Get messages from offline service
          final messages = await _offlineService.getOfflineMessages(
            conversationId: conversationId,
            limit: messagesPerConversation,
          );

          if (messages.isNotEmpty) {
            await cacheConversationMessages(
              conversationId: conversationId,
              messages: List<MessageModel>.from(messages),
              priority: CachePriority.low,
            );
          }
        } catch (e) {
          debugPrint('Error preloading conversation $conversationId: $e');
        }
      }

      debugPrint('Preloaded ${conversationIds.length} conversations');
    } catch (e) {
      debugPrint('Error preloading conversation messages: $e');
    }
  }

  /// Sync cached messages when coming back online
  Future<SyncResult> syncCachedMessages() async {
    try {
      if (!_isOnline) {
        return SyncResult(success: false, message: 'Device is offline');
      }

      debugPrint('Starting cached message sync');
      
      int syncedConversations = 0;
      int syncedMessages = 0;
      final errors = <String>[];

      // Get all cached conversations
      final cachedConversationIds = _memoryCache.keys.toList();
      cachedConversationIds.addAll(_cacheMetadata.keys);
      final uniqueConversationIds = cachedConversationIds.toSet().toList();

      for (final conversationId in uniqueConversationIds) {
        try {
          // Get latest messages from offline service
          final latestMessages = await _offlineService.getOfflineMessages(
            conversationId: conversationId,
            limit: maxMemoryCacheSize,
          );

          if (latestMessages.isNotEmpty) {
            await cacheConversationMessages(
              conversationId: conversationId,
              messages: List<MessageModel>.from(latestMessages),
              priority: CachePriority.normal,
            );
            
            syncedConversations++;
            syncedMessages += latestMessages.length;
          }
        } catch (e) {
          errors.add('Conversation $conversationId: $e');
        }
      }

      return SyncResult(
        success: errors.isEmpty,
        message: 'Synced $syncedMessages messages from $syncedConversations conversations',
        syncedCount: syncedMessages,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error syncing cached messages: $e');
      return SyncResult(success: false, message: e.toString());
    }
  }

  /// Get cache statistics
  CacheStatistics getCacheStatistics() {
    final memorySize = _memoryCache.values
        .map((messages) => messages.length)
        .fold(0, (sum, count) => sum + count);

    final diskSize = _cacheMetadata.values
        .map((metadata) => metadata.messageCount)
        .fold(0, (sum, count) => sum + count);

    final hitRate = (_cacheHits + _cacheMisses) > 0 
        ? _cacheHits / (_cacheHits + _cacheMisses)
        : 0.0;

    return CacheStatistics(
      memoryCachedConversations: _memoryCache.length,
      diskCachedConversations: _cacheMetadata.length,
      memoryCachedMessages: memorySize,
      diskCachedMessages: diskSize,
      totalCacheSize: _totalCacheSize,
      cacheHitRate: hitRate,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
    );
  }

  /// Clear cache for specific conversation
  Future<void> clearConversationCache(String conversationId) async {
    try {
      // Clear memory cache
      _memoryCache.remove(conversationId);
      _cacheTimestamps.remove(conversationId);
      
      // Clear disk cache
      await _clearDiskCache(conversationId);
      
      // Update metadata
      _cacheMetadata.remove(conversationId);
      await _saveCacheMetadata();
      
      debugPrint('Cleared cache for conversation $conversationId');
    } catch (e) {
      debugPrint('Error clearing conversation cache: $e');
    }
  }

  /// Clear all expired cache
  Future<void> clearExpiredCache() async {
    try {
      final now = DateTime.now();
      final expiredConversations = <String>[];

      // Find expired conversations
      for (final entry in _cacheTimestamps.entries) {
        if (now.difference(entry.value) > cacheExpiration) {
          expiredConversations.add(entry.key);
        }
      }

      // Clear expired conversations
      for (final conversationId in expiredConversations) {
        await clearConversationCache(conversationId);
      }

      debugPrint('Cleared ${expiredConversations.length} expired cache entries');
    } catch (e) {
      debugPrint('Error clearing expired cache: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      // Clear memory cache
      _memoryCache.clear();
      _cacheTimestamps.clear();
      _cacheMetadata.clear();
      
      // Clear disk cache
      await _clearAllDiskCache();
      
      // Reset statistics
      _cacheHits = 0;
      _cacheMisses = 0;
      _totalCacheSize = 0;
      
      debugPrint('Cleared all cache');
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
    }
  }

  // Private helper methods

  /// Update memory cache with LRU eviction
  Future<void> _updateMemoryCache(String conversationId, List<MessageModel> messages) async {
    try {
      // Limit messages per conversation
      final limitedMessages = messages.take(maxMemoryCacheSize).toList();
      
      // Check total memory cache size
      final currentTotalSize = _memoryCache.values
          .map((msgs) => msgs.length)
          .fold(0, (sum, count) => sum + count);

      // Evict oldest conversations if needed
      while (currentTotalSize + limitedMessages.length > maxTotalMemoryCache && _memoryCache.isNotEmpty) {
        final oldestConversation = _cacheTimestamps.entries
            .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
            .key;
        
        _memoryCache.remove(oldestConversation);
        _cacheTimestamps.remove(oldestConversation);
      }

      // Update cache
      _memoryCache[conversationId] = limitedMessages;
      _cacheTimestamps[conversationId] = DateTime.now();
    } catch (e) {
      debugPrint('Error updating memory cache: $e');
    }
  }

  /// Get messages from memory cache
  List<MessageModel>? _getFromMemoryCache(String conversationId, int? limit) {
    try {
      final messages = _memoryCache[conversationId];
      if (messages == null) return null;

      // Check if cache is expired
      final timestamp = _cacheTimestamps[conversationId];
      if (timestamp != null && DateTime.now().difference(timestamp) > cacheExpiration) {
        _memoryCache.remove(conversationId);
        _cacheTimestamps.remove(conversationId);
        return null;
      }

      return limit != null ? messages.take(limit).toList() : messages;
    } catch (e) {
      debugPrint('Error getting from memory cache: $e');
      return null;
    }
  }

  /// Cache messages to disk
  Future<void> _cacheToDisk(
    String conversationId,
    List<MessageModel> messages,
    CachePriority priority,
    bool compress,
  ) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final conversationFile = File(join(cacheDir.path, '$conversationId.json'));

      // Prepare data for caching
      final cacheData = {
        'conversationId': conversationId,
        'messages': messages.map((msg) => msg.toMap()).toList(),
        'cachedAt': DateTime.now().toIso8601String(),
        'priority': priority.toString(),
        'compressed': compress,
      };

      String jsonData = jsonEncode(cacheData);
      
      // Apply compression if requested
      if (compress && jsonData.length > 1024) {
        final compressed = await _compressionService.compressText(jsonData);
        if (compressed.length < jsonData.length * 0.8) {
          jsonData = compressed;
          cacheData['compressed'] = true;
        }
      }

      await conversationFile.writeAsString(jsonData);
      _totalCacheSize += jsonData.length;
    } catch (e) {
      debugPrint('Error caching to disk: $e');
    }
  }

  /// Get messages from disk cache
  Future<List<MessageModel>?> _getFromDiskCache(
    String conversationId,
    int? limit,
    bool includeExpired,
  ) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final conversationFile = File(join(cacheDir.path, '$conversationId.json'));

      if (!await conversationFile.exists()) return null;

      String jsonData = await conversationFile.readAsString();
      
      // Try to parse as regular JSON first
      Map<String, dynamic> cacheData;
      try {
        cacheData = jsonDecode(jsonData);
      } catch (e) {
        // If parsing fails, try decompression
        try {
          final decompressed = await _compressionService.decompressText(jsonData);
          cacheData = jsonDecode(decompressed);
        } catch (e2) {
          debugPrint('Error parsing cached data: $e2');
          return null;
        }
      }

      // Check expiration
      if (!includeExpired) {
        final cachedAt = DateTime.parse(cacheData['cachedAt']);
        if (DateTime.now().difference(cachedAt) > cacheExpiration) {
          await conversationFile.delete();
          return null;
        }
      }

      // Parse messages
      final messagesList = cacheData['messages'] as List;
      final messages = messagesList
          .map((msgData) => MessageModel.fromMap(msgData))
          .toList();

      return limit != null ? messages.take(limit).toList() : messages;
    } catch (e) {
      debugPrint('Error getting from disk cache: $e');
      return null;
    }
  }

  /// Clear disk cache for conversation
  Future<void> _clearDiskCache(String conversationId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final conversationFile = File(join(cacheDir.path, '$conversationId.json'));

      if (await conversationFile.exists()) {
        final fileSize = await conversationFile.length();
        await conversationFile.delete();
        _totalCacheSize -= fileSize;
      }
    } catch (e) {
      debugPrint('Error clearing disk cache: $e');
    }
  }

  /// Clear all disk cache
  Future<void> _clearAllDiskCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        _totalCacheSize = 0;
      }
    } catch (e) {
      debugPrint('Error clearing all disk cache: $e');
    }
  }

  /// Get cache directory
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(join(appDir.path, cacheDirectory));
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Update cache metadata
  Future<void> _updateCacheMetadata(
    String conversationId,
    int messageCount,
    CachePriority priority,
  ) async {
    try {
      _cacheMetadata[conversationId] = CacheMetadata(
        conversationId: conversationId,
        messageCount: messageCount,
        priority: priority,
        lastUpdated: DateTime.now(),
      );
      
      await _saveCacheMetadata();
    } catch (e) {
      debugPrint('Error updating cache metadata: $e');
    }
  }

  /// Load cache metadata
  Future<void> _loadCacheMetadata() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metadataFile = File(join(cacheDir.path, EnhancedOfflineCacheService.metadataFile));

      if (await metadataFile.exists()) {
        final jsonData = await metadataFile.readAsString();
        final metadataMap = jsonDecode(jsonData) as Map<String, dynamic>;

        for (final entry in metadataMap.entries) {
          _cacheMetadata[entry.key] = CacheMetadata.fromMap(entry.value);
        }

        debugPrint('Loaded metadata for ${_cacheMetadata.length} cached conversations');
      }
    } catch (e) {
      debugPrint('Error loading cache metadata: $e');
    }
  }

  /// Save cache metadata
  Future<void> _saveCacheMetadata() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metadataFile = File(join(cacheDir.path, EnhancedOfflineCacheService.metadataFile));

      final metadataMap = <String, dynamic>{};
      for (final entry in _cacheMetadata.entries) {
        metadataMap[entry.key] = entry.value.toMap();
      }

      await metadataFile.writeAsString(jsonEncode(metadataMap));
    } catch (e) {
      debugPrint('Error saving cache metadata: $e');
    }
  }

  /// Start connectivity monitoring
  Future<void> _startConnectivityMonitoring() async {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      
      if (!wasOnline && _isOnline) {
        debugPrint('Connection restored, syncing cached messages');
        syncCachedMessages();
      }
    });
    
    // Check initial connectivity
    final connectivity = await Connectivity().checkConnectivity();
    _isOnline = connectivity.any((result) => result != ConnectivityResult.none);
  }

  /// Schedule periodic cleanup
  Future<void> _schedulePeriodicCleanup() async {
    _cleanupTimer?.cancel();
    
    _cleanupTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      await clearExpiredCache();
    });
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _cacheMetadata.clear();
  }
}

// Data models for enhanced offline cache

enum CachePriority {
  low,
  normal,
  high,
}

class CacheMetadata {
  final String conversationId;
  final int messageCount;
  final CachePriority priority;
  final DateTime lastUpdated;

  CacheMetadata({
    required this.conversationId,
    required this.messageCount,
    required this.priority,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'messageCount': messageCount,
      'priority': priority.toString(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory CacheMetadata.fromMap(Map<String, dynamic> map) {
    return CacheMetadata(
      conversationId: map['conversationId'] ?? '',
      messageCount: map['messageCount'] ?? 0,
      priority: CachePriority.values.firstWhere(
        (p) => p.toString() == map['priority'],
        orElse: () => CachePriority.normal,
      ),
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class CacheStatistics {
  final int memoryCachedConversations;
  final int diskCachedConversations;
  final int memoryCachedMessages;
  final int diskCachedMessages;
  final int totalCacheSize;
  final double cacheHitRate;
  final int cacheHits;
  final int cacheMisses;

  CacheStatistics({
    required this.memoryCachedConversations,
    required this.diskCachedConversations,
    required this.memoryCachedMessages,
    required this.diskCachedMessages,
    required this.totalCacheSize,
    required this.cacheHitRate,
    required this.cacheHits,
    required this.cacheMisses,
  });

  int get totalCachedConversations => memoryCachedConversations + diskCachedConversations;
  int get totalCachedMessages => memoryCachedMessages + diskCachedMessages;
  double get cacheSizeMB => totalCacheSize / (1024 * 1024);
  double get cacheEfficiency => cacheHitRate * 100;
}

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.errors = const [],
  });
}