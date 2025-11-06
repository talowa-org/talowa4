// Sync Conflict Resolver for TALOWA
// Implements Task 22: Add sync and conflict resolution - Conflict Resolution

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../social_feed/feed_service.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/comment_model.dart';

class SyncConflictResolver {
  static final SyncConflictResolver _instance = SyncConflictResolver._internal();
  factory SyncConflictResolver() => _instance;
  SyncConflictResolver._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FeedService _feedService = FeedService();

  /// Resolve conflicts for posts
  Future<ConflictResolution> resolvePostConflict({
    required PostModel localPost,
    required PostModel remotePost,
    required ConflictResolutionStrategy strategy,
  }) async {
    try {
      debugPrint('Resolving post conflict: ${localPost.id}');
      
      final conflict = PostConflict(
        localPost: localPost,
        remotePost: remotePost,
        conflictType: _determinePostConflictType(localPost, remotePost),
        detectedAt: DateTime.now(),
      );

      PostModel? resolvedPost;
      
      switch (strategy) {
        case ConflictResolutionStrategy.localWins:
          resolvedPost = await _resolveLocalWins(conflict);
          break;
        case ConflictResolutionStrategy.remoteWins:
          resolvedPost = await _resolveRemoteWins(conflict);
          break;
        case ConflictResolutionStrategy.merge:
          resolvedPost = await _mergePostConflict(conflict);
          break;
        case ConflictResolutionStrategy.userChoice:
          // Return conflict for user to decide
          return ConflictResolution(
            isResolved: false,
            resolvedData: null,
            conflict: conflict,
            requiresUserInput: true,
          );
        case ConflictResolutionStrategy.automatic:
          resolvedPost = await _autoResolvePostConflict(conflict);
          break;
      }

      // Apply the resolution
      await _applyPostResolution(resolvedPost, conflict);
      
      return ConflictResolution(
        isResolved: true,
        resolvedData: resolvedPost,
        conflict: conflict,
        requiresUserInput: false,
      );
    
      return ConflictResolution(
        isResolved: false,
        resolvedData: null,
        conflict: conflict,
        requiresUserInput: true,
      );
    } catch (e) {
      debugPrint('Error resolving post conflict: $e');
      rethrow;
    }
  }

  /// Resolve conflicts for comments
  Future<ConflictResolution> resolveCommentConflict({
    required CommentModel localComment,
    required CommentModel remoteComment,
    required ConflictResolutionStrategy strategy,
  }) async {
    try {
      debugPrint('Resolving comment conflict: ${localComment.id}');
      
      final conflict = CommentConflict(
        localComment: localComment,
        remoteComment: remoteComment,
        conflictType: _determineCommentConflictType(localComment, remoteComment),
        detectedAt: DateTime.now(),
      );

      CommentModel? resolvedComment;
      
      switch (strategy) {
        case ConflictResolutionStrategy.localWins:
          resolvedComment = localComment;
          break;
        case ConflictResolutionStrategy.remoteWins:
          resolvedComment = remoteComment;
          break;
        case ConflictResolutionStrategy.merge:
          resolvedComment = await _mergeCommentConflict(conflict);
          break;
        case ConflictResolutionStrategy.userChoice:
          return ConflictResolution(
            isResolved: false,
            resolvedData: null,
            conflict: conflict,
            requiresUserInput: true,
          );
        case ConflictResolutionStrategy.automatic:
          resolvedComment = await _autoResolveCommentConflict(conflict);
          break;
      }

      await _applyCommentResolution(resolvedComment, conflict);
      
      return ConflictResolution(
        isResolved: true,
        resolvedData: resolvedComment,
        conflict: conflict,
        requiresUserInput: false,
      );
    
      return ConflictResolution(
        isResolved: false,
        resolvedData: null,
        conflict: conflict,
        requiresUserInput: true,
      );
    } catch (e) {
      debugPrint('Error resolving comment conflict: $e');
      rethrow;
    }
  }

  /// Resolve engagement conflicts (likes, shares)
  Future<ConflictResolution> resolveEngagementConflict({
    required Map<String, dynamic> localEngagement,
    required Map<String, dynamic> remoteEngagement,
    required String engagementType,
  }) async {
    try {
      debugPrint('Resolving engagement conflict: $engagementType');
      
      final conflict = EngagementConflict(
        localEngagement: localEngagement,
        remoteEngagement: remoteEngagement,
        engagementType: engagementType,
        conflictType: _determineEngagementConflictType(localEngagement, remoteEngagement),
        detectedAt: DateTime.now(),
      );

      // For engagement conflicts, we typically merge the data
      final resolvedEngagement = await _mergeEngagementConflict(conflict);
      
      await _applyEngagementResolution(resolvedEngagement, conflict);
      
      return ConflictResolution(
        isResolved: true,
        resolvedData: resolvedEngagement,
        conflict: conflict,
        requiresUserInput: false,
      );
    
      return ConflictResolution(
        isResolved: false,
        resolvedData: null,
        conflict: conflict,
        requiresUserInput: true,
      );
    } catch (e) {
      debugPrint('Error resolving engagement conflict: $e');
      rethrow;
    }
  }

  /// Get conflict resolution statistics
  Future<ConflictStats> getConflictStats() async {
    try {
      final snapshot = await _firestore
          .collection('sync_conflicts')
          .get();

      int totalConflicts = snapshot.docs.length;
      int resolvedConflicts = 0;
      int pendingConflicts = 0;
      
      final conflictTypes = <String, int>{};
      final resolutionStrategies = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isResolved = data['isResolved'] as bool? ?? false;
        final conflictType = data['conflictType'] as String? ?? 'unknown';
        final strategy = data['resolutionStrategy'] as String? ?? 'unknown';

        if (isResolved) {
          resolvedConflicts++;
        } else {
          pendingConflicts++;
        }

        conflictTypes[conflictType] = (conflictTypes[conflictType] ?? 0) + 1;
        if (isResolved) {
          resolutionStrategies[strategy] = (resolutionStrategies[strategy] ?? 0) + 1;
        }
      }

      return ConflictStats(
        totalConflicts: totalConflicts,
        resolvedConflicts: resolvedConflicts,
        pendingConflicts: pendingConflicts,
        conflictTypeBreakdown: conflictTypes,
        resolutionStrategyBreakdown: resolutionStrategies,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting conflict stats: $e');
      return ConflictStats(
        totalConflicts: 0,
        resolvedConflicts: 0,
        pendingConflicts: 0,
        conflictTypeBreakdown: {},
        resolutionStrategyBreakdown: {},
        lastUpdated: DateTime.now(),
      );
    }
  }

  // Private helper methods

  ConflictType _determinePostConflictType(PostModel local, PostModel remote) {
    if (local.content != remote.content) {
      return ConflictType.contentModified;
    } else if (local.mediaUrls.length != remote.mediaUrls.length ||
               !_listsEqual(local.mediaUrls, remote.mediaUrls)) {
      return ConflictType.mediaModified;
    } else if (local.hashtags.length != remote.hashtags.length ||
               !_listsEqual(local.hashtags, remote.hashtags)) {
      return ConflictType.metadataModified;
    } else if (local.updatedAt != remote.updatedAt) {
      return ConflictType.timestampMismatch;
    }
    return ConflictType.unknown;
  }

  ConflictType _determineCommentConflictType(CommentModel local, CommentModel remote) {
    if (local.content != remote.content) {
      return ConflictType.contentModified;
    } else if (local.updatedAt != remote.updatedAt) {
      return ConflictType.timestampMismatch;
    }
    return ConflictType.unknown;
  }

  ConflictType _determineEngagementConflictType(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localCount = local['count'] as int? ?? 0;
    final remoteCount = remote['count'] as int? ?? 0;
    
    if (localCount != remoteCount) {
      return ConflictType.countMismatch;
    }
    return ConflictType.unknown;
  }

  Future<PostModel> _resolveLocalWins(PostConflict conflict) async {
    // Local version wins, but update timestamp to avoid future conflicts
    return conflict.localPost.copyWith(
      updatedAt: DateTime.now(),
      syncVersion: (conflict.remotePost.syncVersion ?? 0) + 1,
    );
  }

  Future<PostModel> _resolveRemoteWins(PostConflict conflict) async {
    // Remote version wins
    return conflict.remotePost;
  }

  Future<PostModel> _mergePostConflict(PostConflict conflict) async {
    final local = conflict.localPost;
    final remote = conflict.remotePost;

    // Intelligent merge based on conflict type
    switch (conflict.conflictType) {
      case ConflictType.contentModified:
        // If both modified content, prefer the most recent
        final useLocal = local.updatedAt.isAfter(remote.updatedAt);
        return useLocal ? local : remote;
        
      case ConflictType.mediaModified:
        // Merge media lists (union of both)
        final mergedMedia = <String>{...local.mediaUrls, ...remote.mediaUrls}.toList();
        return local.copyWith(
          mediaUrls: mergedMedia,
          updatedAt: DateTime.now(),
          syncVersion: (remote.syncVersion ?? 0) + 1,
        );
        
      case ConflictType.metadataModified:
        // Merge hashtags and other metadata
        final mergedHashtags = <String>{...local.hashtags, ...remote.hashtags}.toList();
        return local.copyWith(
          hashtags: mergedHashtags,
          updatedAt: DateTime.now(),
          syncVersion: (remote.syncVersion ?? 0) + 1,
        );
        
      default:
        // Default to most recent
        return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
    }
  }

  Future<PostModel> _autoResolvePostConflict(PostConflict conflict) async {
    final local = conflict.localPost;
    final remote = conflict.remotePost;

    // Automatic resolution rules
    
    // Rule 1: If one is deleted, keep the deletion
    if (local.isDeleted && !remote.isDeleted) {
      return local;
    } else if (!local.isDeleted && remote.isDeleted) {
      return remote;
    }
    
    // Rule 2: If conflict is only timestamp, use remote (server time is authoritative)
    if (conflict.conflictType == ConflictType.timestampMismatch) {
      return remote;
    }
    
    // Rule 3: For content conflicts, prefer the version with more content
    if (conflict.conflictType == ConflictType.contentModified) {
      if (local.content.length > remote.content.length) {
        return local.copyWith(syncVersion: (remote.syncVersion ?? 0) + 1);
      } else {
        return remote;
      }
    }
    
    // Rule 4: For media/metadata conflicts, merge them
    if (conflict.conflictType == ConflictType.mediaModified ||
        conflict.conflictType == ConflictType.metadataModified) {
      return await _mergePostConflict(conflict);
    }
    
    // Default: Use most recent
    return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
  }

  Future<CommentModel> _mergeCommentConflict(CommentConflict conflict) async {
    final local = conflict.localComment;
    final remote = conflict.remoteComment;

    // For comments, prefer the most recent content
    if (local.updatedAt.isAfter(remote.updatedAt)) {
      return local.copyWith(syncVersion: (remote.syncVersion ?? 0) + 1);
    } else {
      return remote;
    }
  }

  Future<CommentModel> _autoResolveCommentConflict(CommentConflict conflict) async {
    // For comments, automatic resolution is simple - use most recent
    return await _mergeCommentConflict(conflict);
  }

  Future<Map<String, dynamic>> _mergeEngagementConflict(EngagementConflict conflict) async {
    final local = conflict.localEngagement;
    final remote = conflict.remoteEngagement;

    // For engagement, merge the user lists and recalculate counts
    final localUsers = Set<String>.from(local['users'] ?? []);
    final remoteUsers = Set<String>.from(remote['users'] ?? []);
    final mergedUsers = localUsers.union(remoteUsers).toList();

    return {
      'count': mergedUsers.length,
      'users': mergedUsers,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _applyPostResolution(PostModel resolvedPost, PostConflict conflict) async {
    try {
      // Update in Firestore
      await _firestore.collection('posts').doc(resolvedPost.id).set(
        resolvedPost.toMap(),
        SetOptions(merge: false),
      );

      // Log the conflict resolution
      await _logConflictResolution(
        conflictId: '${resolvedPost.id}_${DateTime.now().millisecondsSinceEpoch}',
        conflictType: conflict.conflictType.toString(),
        resolutionStrategy: 'auto_resolved',
        resolvedData: resolvedPost.toMap(),
      );

      debugPrint('Post conflict resolved: ${resolvedPost.id}');
    } catch (e) {
      debugPrint('Error applying post resolution: $e');
      rethrow;
    }
  }

  Future<void> _applyCommentResolution(CommentModel resolvedComment, CommentConflict conflict) async {
    try {
      // Update in Firestore
      await _firestore
          .collection('posts')
          .doc(resolvedComment.postId)
          .collection('comments')
          .doc(resolvedComment.id)
          .set(resolvedComment.toMap(), SetOptions(merge: false));

      // Log the conflict resolution
      await _logConflictResolution(
        conflictId: '${resolvedComment.id}_${DateTime.now().millisecondsSinceEpoch}',
        conflictType: conflict.conflictType.toString(),
        resolutionStrategy: 'auto_resolved',
        resolvedData: resolvedComment.toMap(),
      );

      debugPrint('Comment conflict resolved: ${resolvedComment.id}');
    } catch (e) {
      debugPrint('Error applying comment resolution: $e');
      rethrow;
    }
  }

  Future<void> _applyEngagementResolution(
    Map<String, dynamic> resolvedEngagement,
    EngagementConflict conflict,
  ) async {
    try {
      // Update engagement data in Firestore
      final engagementPath = 'posts/${conflict.localEngagement['postId']}/engagement/${conflict.engagementType}';
      await _firestore.doc(engagementPath).set(resolvedEngagement, SetOptions(merge: false));

      // Log the conflict resolution
      await _logConflictResolution(
        conflictId: '${conflict.engagementType}_${DateTime.now().millisecondsSinceEpoch}',
        conflictType: conflict.conflictType.toString(),
        resolutionStrategy: 'merge',
        resolvedData: resolvedEngagement,
      );

      debugPrint('Engagement conflict resolved: ${conflict.engagementType}');
    } catch (e) {
      debugPrint('Error applying engagement resolution: $e');
      rethrow;
    }
  }

  Future<void> _logConflictResolution({
    required String conflictId,
    required String conflictType,
    required String resolutionStrategy,
    required Map<String, dynamic> resolvedData,
  }) async {
    try {
      await _firestore.collection('sync_conflicts').doc(conflictId).set({
        'conflictId': conflictId,
        'conflictType': conflictType,
        'resolutionStrategy': resolutionStrategy,
        'isResolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedData': resolvedData,
      });
    } catch (e) {
      debugPrint('Error logging conflict resolution: $e');
    }
  }

  bool _listsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
}

// Data models for conflict resolution

enum ConflictType {
  contentModified,
  mediaModified,
  metadataModified,
  timestampMismatch,
  countMismatch,
  unknown,
}

enum ConflictResolutionStrategy {
  localWins,
  remoteWins,
  merge,
  userChoice,
  automatic,
}

abstract class SyncConflict {
  final ConflictType conflictType;
  final DateTime detectedAt;

  SyncConflict({
    required this.conflictType,
    required this.detectedAt,
  });
}

class PostConflict extends SyncConflict {
  final PostModel localPost;
  final PostModel remotePost;

  PostConflict({
    required this.localPost,
    required this.remotePost,
    required super.conflictType,
    required super.detectedAt,
  });
}

class CommentConflict extends SyncConflict {
  final CommentModel localComment;
  final CommentModel remoteComment;

  CommentConflict({
    required this.localComment,
    required this.remoteComment,
    required super.conflictType,
    required super.detectedAt,
  });
}

class EngagementConflict extends SyncConflict {
  final Map<String, dynamic> localEngagement;
  final Map<String, dynamic> remoteEngagement;
  final String engagementType;

  EngagementConflict({
    required this.localEngagement,
    required this.remoteEngagement,
    required this.engagementType,
    required super.conflictType,
    required super.detectedAt,
  });
}

class ConflictResolution {
  final bool isResolved;
  final dynamic resolvedData;
  final SyncConflict conflict;
  final bool requiresUserInput;

  ConflictResolution({
    required this.isResolved,
    required this.resolvedData,
    required this.conflict,
    required this.requiresUserInput,
  });
}

class ConflictStats {
  final int totalConflicts;
  final int resolvedConflicts;
  final int pendingConflicts;
  final Map<String, int> conflictTypeBreakdown;
  final Map<String, int> resolutionStrategyBreakdown;
  final DateTime lastUpdated;

  ConflictStats({
    required this.totalConflicts,
    required this.resolvedConflicts,
    required this.pendingConflicts,
    required this.conflictTypeBreakdown,
    required this.resolutionStrategyBreakdown,
    required this.lastUpdated,
  });
}

// Extension methods for PostModel and CommentModel
extension PostModelSync on PostModel {
  PostModel copyWith({
    String? id,
    String? authorId,
    String? content,
    List<String>? mediaUrls,
    List<String>? hashtags,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncVersion,
    bool? isDeleted,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? authorName,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      hashtags: hashtags ?? this.hashtags,
      category: category ?? category,
      location: location ?? location,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? likesCount,
      commentsCount: commentsCount ?? commentsCount,
      sharesCount: sharesCount ?? sharesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? isLikedByCurrentUser,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension CommentModelSync on CommentModel {
  CommentModel copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncVersion,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? authorName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
