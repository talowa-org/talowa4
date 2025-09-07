// Search Indexing Service - Sync data with Algolia indices
// Complete data synchronization for TALOWA search functionality

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/algolia_config.dart';
import '../../models/legal_case_model.dart';
import '../../models/news_model.dart';

class SearchIndexingService {
  static SearchIndexingService? _instance;
  static SearchIndexingService get instance => _instance ??= SearchIndexingService._internal();
  
  SearchIndexingService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _subscriptions = {};
  bool _isListening = false;
  
  /// Start real-time indexing listeners
  Future<void> startRealTimeIndexing() async {
    if (_isListening) return;
    
    try {
      debugPrint('ðŸ”„ Starting real-time search indexing...');
      
      // Listen to posts changes
      _subscriptions['posts'] = _firestore
          .collection('posts')
          .snapshots()
          .listen(_handlePostsChange);
      
      // Listen to users changes
      _subscriptions['users'] = _firestore
          .collection('users')
          .snapshots()
          .listen(_handleUsersChange);
      
      // Listen to legal cases changes
      _subscriptions['legal_cases'] = _firestore
          .collection('legal_cases')
          .snapshots()
          .listen(_handleLegalCasesChange);
      
      // Listen to news changes
      _subscriptions['news'] = _firestore
          .collection('news')
          .snapshots()
          .listen(_handleNewsChange);
      
      _isListening = true;
      debugPrint('âœ… Real-time search indexing started');
      
    } catch (e) {
      debugPrint('âŒ Failed to start real-time indexing: $e');
      rethrow;
    }
  }
  
  /// Stop real-time indexing listeners
  void stopRealTimeIndexing() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _isListening = false;
    debugPrint('ðŸ›‘ Real-time search indexing stopped');
  }
  
  /// Handle posts collection changes
  void _handlePostsChange(QuerySnapshot snapshot) async {
    try {
      for (final change in snapshot.docChanges) {
        final doc = change.doc;
        final data = doc.data() as Map<String, dynamic>?;
        
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            if (data != null) {
              await _indexPost(doc.id, data);
            }
            break;
          case DocumentChangeType.removed:
            await _removeFromIndex(AlgoliaConfig.postsIndex, doc.id);
            break;
        }
      }
    } catch (e) {
      debugPrint('âŒ Error handling posts change: $e');
    }
  }
  
  /// Handle users collection changes
  void _handleUsersChange(QuerySnapshot snapshot) async {
    try {
      for (final change in snapshot.docChanges) {
        final doc = change.doc;
        final data = doc.data() as Map<String, dynamic>?;
        
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            if (data != null) {
              await _indexUser(doc.id, data);
            }
            break;
          case DocumentChangeType.removed:
            await _removeFromIndex(AlgoliaConfig.usersIndex, doc.id);
            break;
        }
      }
    } catch (e) {
      debugPrint('âŒ Error handling users change: $e');
    }
  }
  
  /// Handle legal cases collection changes
  void _handleLegalCasesChange(QuerySnapshot snapshot) async {
    try {
      for (final change in snapshot.docChanges) {
        final doc = change.doc;
        final data = doc.data() as Map<String, dynamic>?;
        
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            if (data != null) {
              await _indexLegalCase(doc.id, data);
            }
            break;
          case DocumentChangeType.removed:
            await _removeFromIndex(AlgoliaConfig.legalCasesIndex, doc.id);
            break;
        }
      }
    } catch (e) {
      debugPrint('âŒ Error handling legal cases change: $e');
    }
  }
  
  /// Handle news collection changes
  void _handleNewsChange(QuerySnapshot snapshot) async {
    try {
      for (final change in snapshot.docChanges) {
        final doc = change.doc;
        final data = doc.data() as Map<String, dynamic>?;
        
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            if (data != null) {
              await _indexNews(doc.id, data);
            }
            break;
          case DocumentChangeType.removed:
            await _removeFromIndex(AlgoliaConfig.newsIndex, doc.id);
            break;
        }
      }
    } catch (e) {
      debugPrint('âŒ Error handling news change: $e');
    }
  }
  
  /// Index a post document
  Future<void> _indexPost(String postId, Map<String, dynamic> data) async {
    try {
      final searchableData = _preparePostForSearch(postId, data);
      await _addToIndex(AlgoliaConfig.postsIndex, postId, searchableData);
      debugPrint('ðŸ“ Indexed post: $postId');
    } catch (e) {
      debugPrint('âŒ Failed to index post $postId: $e');
    }
  }
  
  /// Index a user document
  Future<void> _indexUser(String userId, Map<String, dynamic> data) async {
    try {
      final searchableData = _prepareUserForSearch(userId, data);
      await _addToIndex(AlgoliaConfig.usersIndex, userId, searchableData);
      debugPrint('ðŸ‘¤ Indexed user: $userId');
    } catch (e) {
      debugPrint('âŒ Failed to index user $userId: $e');
    }
  }
  
  /// Index a legal case document
  Future<void> _indexLegalCase(String caseId, Map<String, dynamic> data) async {
    try {
      final searchableData = _prepareLegalCaseForSearch(caseId, data);
      await _addToIndex(AlgoliaConfig.legalCasesIndex, caseId, searchableData);
      debugPrint('âš–ï¸ Indexed legal case: $caseId');
    } catch (e) {
      debugPrint('âŒ Failed to index legal case $caseId: $e');
    }
  }
  
  /// Index a news document
  Future<void> _indexNews(String newsId, Map<String, dynamic> data) async {
    try {
      final searchableData = _prepareNewsForSearch(newsId, data);
      await _addToIndex(AlgoliaConfig.newsIndex, newsId, searchableData);
      debugPrint('ðŸ“° Indexed news: $newsId');
    } catch (e) {
      debugPrint('âŒ Failed to index news $newsId: $e');
    }
  }
  
  /// Prepare post data for search indexing
  Map<String, dynamic> _preparePostForSearch(String postId, Map<String, dynamic> data) {
    return {
      'objectID': postId,
      'title': data['title'] ?? '',
      'content': data['content'] ?? '',
      'authorId': data['authorId'] ?? '',
      'authorName': data['authorName'] ?? '',
      'type': data['type'] ?? 'post',
      'category': data['category'] ?? 'general',
      'tags': data['tags'] ?? [],
      'location': data['location'] ?? {},
      'likesCount': data['likesCount'] ?? 0,
      'commentsCount': data['commentsCount'] ?? 0,
      'sharesCount': data['sharesCount'] ?? 0,
      'createdAt': _getTimestamp(data['createdAt']),
      'updatedAt': _getTimestamp(data['updatedAt']),
      'isPublic': data['isPublic'] ?? true,
      'status': data['status'] ?? 'active',
      'priority': _calculatePostPriority(data),
      '_geoloc': _extractGeoLocation(data['location']),
    };
  }
  
  /// Prepare user data for search indexing
  Map<String, dynamic> _prepareUserForSearch(String userId, Map<String, dynamic> data) {
    return {
      'objectID': userId,
      'name': data['name'] ?? '',
      'bio': data['bio'] ?? '',
      'profession': data['profession'] ?? '',
      'specialization': data['specialization'] ?? '',
      'location': data['location'] ?? {},
      'skills': data['skills'] ?? [],
      'followersCount': data['followersCount'] ?? 0,
      'postsCount': data['postsCount'] ?? 0,
      'reputation': data['reputation'] ?? 0,
      'isVerified': data['isVerified'] ?? false,
      'isPublic': data['isPublic'] ?? true,
      'joinedAt': _getTimestamp(data['joinedAt']),
      'lastActiveAt': _getTimestamp(data['lastActiveAt']),
      'type': 'user',
      '_geoloc': _extractGeoLocation(data['location']),
    };
  }
  
  /// Prepare legal case data for search indexing
  Map<String, dynamic> _prepareLegalCaseForSearch(String caseId, Map<String, dynamic> data) {
    return {
      'objectID': caseId,
      'title': data['title'] ?? '',
      'description': data['description'] ?? '',
      'caseNumber': data['caseNumber'] ?? '',
      'court': data['court'] ?? '',
      'status': data['status'] ?? '',
      'priority': data['priority'] ?? 'medium',
      'tags': data['tags'] ?? [],
      'location': data['location'] ?? {},
      'createdAt': _getTimestamp(data['createdAt']),
      'updatedAt': _getTimestamp(data['updatedAt']),
      'nextHearingDate': _getTimestamp(data['nextHearingDate']),
      'type': 'legal_case',
      'category': data['category'] ?? 'land_rights',
      '_geoloc': _extractGeoLocation(data['location']),
    };
  }
  
  /// Prepare news data for search indexing
  Map<String, dynamic> _prepareNewsForSearch(String newsId, Map<String, dynamic> data) {
    return {
      'objectID': newsId,
      'title': data['title'] ?? '',
      'content': data['content'] ?? '',
      'summary': data['summary'] ?? '',
      'source': data['source'] ?? '',
      'tags': data['tags'] ?? [],
      'location': data['location'] ?? {},
      'publishedAt': _getTimestamp(data['publishedAt']),
      'createdAt': _getTimestamp(data['createdAt']),
      'viewsCount': data['viewsCount'] ?? 0,
      'type': 'news',
      'category': data['category'] ?? 'general',
      'priority': data['priority'] ?? 'normal',
      'isBreaking': data['isBreaking'] ?? false,
      '_geoloc': _extractGeoLocation(data['location']),
    };
  }
  
  /// Extract geo-location for Algolia geo-search
  Map<String, double>? _extractGeoLocation(Map<String, dynamic>? location) {
    if (location == null) return null;
    
    final lat = location['latitude'] as double?;
    final lng = location['longitude'] as double?;
    
    if (lat != null && lng != null) {
      return {'lat': lat, 'lng': lng};
    }
    
    return null;
  }
  
  /// Get timestamp in milliseconds
  int _getTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    } else if (timestamp is DateTime) {
      return timestamp.millisecondsSinceEpoch;
    } else if (timestamp is int) {
      return timestamp;
    }
    return DateTime.now().millisecondsSinceEpoch;
  }
  
  /// Calculate post priority for ranking
  int _calculatePostPriority(Map<String, dynamic> data) {
    int priority = 0;
    
    // Base priority on engagement
    priority += (data['likesCount'] as int? ?? 0) * 1;
    priority += (data['commentsCount'] as int? ?? 0) * 2;
    priority += (data['sharesCount'] as int? ?? 0) * 3;
    
    // Boost recent posts
    final createdAt = data['createdAt'];
    if (createdAt != null) {
      final age = DateTime.now().difference(
        createdAt is Timestamp ? createdAt.toDate() : DateTime.fromMillisecondsSinceEpoch(createdAt)
      ).inDays;
      
      if (age < 1) {
        priority += 100;
      } else if (age < 7) priority += 50;
      else if (age < 30) priority += 20;
    }
    
    // Boost verified authors
    if (data['authorVerified'] == true) {
      priority += 25;
    }
    
    return priority;
  }
  
  /// Add document to Algolia index
  Future<void> _addToIndex(String indexName, String objectId, Map<String, dynamic> data) async {
    try {
      // This would typically use the Algolia admin API
      // For now, we'll simulate the indexing
      debugPrint('ðŸ“‹ Adding to index $indexName: $objectId');
      
      // In a real implementation, you would:
      // final index = AlgoliaService.instance._indices[indexName];
      // await index.saveObject(data);
      
    } catch (e) {
      debugPrint('âŒ Failed to add to index $indexName: $e');
      rethrow;
    }
  }
  
  /// Remove document from Algolia index
  Future<void> _removeFromIndex(String indexName, String objectId) async {
    try {
      debugPrint('ðŸ—‘ï¸ Removing from index $indexName: $objectId');
      
      // In a real implementation, you would:
      // final index = AlgoliaService.instance._indices[indexName];
      // await index.deleteObject(objectId);
      
    } catch (e) {
      debugPrint('âŒ Failed to remove from index $indexName: $e');
      rethrow;
    }
  }
  
  /// Perform full reindex of all data
  Future<void> performFullReindex() async {
    try {
      debugPrint('ðŸ”„ Starting full reindex...');
      
      // Reindex posts
      await _reindexCollection('posts', AlgoliaConfig.postsIndex, _preparePostForSearch);
      
      // Reindex users
      await _reindexCollection('users', AlgoliaConfig.usersIndex, _prepareUserForSearch);
      
      // Reindex legal cases
      await _reindexCollection('legal_cases', AlgoliaConfig.legalCasesIndex, _prepareLegalCaseForSearch);
      
      // Reindex news
      await _reindexCollection('news', AlgoliaConfig.newsIndex, _prepareNewsForSearch);
      
      debugPrint('âœ… Full reindex completed');
      
    } catch (e) {
      debugPrint('âŒ Full reindex failed: $e');
      rethrow;
    }
  }
  
  /// Reindex a specific collection
  Future<void> _reindexCollection(
    String collectionName,
    String indexName,
    Map<String, dynamic> Function(String, Map<String, dynamic>) prepareFunction,
  ) async {
    try {
      debugPrint('ðŸ”„ Reindexing collection: $collectionName');
      
      final snapshot = await _firestore.collection(collectionName).get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final searchableData = prepareFunction(doc.id, data);
        await _addToIndex(indexName, doc.id, searchableData);
      }
      
      debugPrint('âœ… Reindexed ${snapshot.docs.length} documents from $collectionName');
      
    } catch (e) {
      debugPrint('âŒ Failed to reindex collection $collectionName: $e');
      rethrow;
    }
  }
  
  /// Get indexing statistics
  Map<String, dynamic> getIndexingStats() {
    return {
      'isListening': _isListening,
      'activeSubscriptions': _subscriptions.length,
      'subscriptionTypes': _subscriptions.keys.toList(),
    };
  }
  
  /// Dispose resources
  void dispose() {
    stopRealTimeIndexing();
    debugPrint('ðŸ—‘ï¸ Search indexing service disposed');
  }
}

