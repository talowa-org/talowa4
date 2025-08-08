// Local Database Service for TALOWA Offline Support
// Implements Task 20: Offline functionality - Local Storage

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/social_feed/index.dart';
import '../../services/social_feed/offline_sync_service.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _database;
  static const String _databaseName = 'talowa_offline.db';
  static const int _databaseVersion = 1;

  /// Initialize the local database
  Future<void> initialize() async {
    if (_database != null) return;

    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);
      
      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      
      debugPrint('Local database initialized at: $path');
    } catch (e) {
      debugPrint('Error initializing local database: $e');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    try {
      // Posts table
      await db.execute('''
        CREATE TABLE posts (
          id TEXT PRIMARY KEY,
          author_id TEXT NOT NULL,
          author_name TEXT NOT NULL,
          author_role TEXT,
          author_avatar_url TEXT,
          title TEXT,
          content TEXT NOT NULL,
          category TEXT NOT NULL,
          visibility TEXT NOT NULL,
          priority TEXT NOT NULL,
          hashtags TEXT, -- JSON array
          image_urls TEXT, -- JSON array
          document_urls TEXT, -- JSON array
          geographic_targeting TEXT, -- JSON object
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          likes_count INTEGER DEFAULT 0,
          comments_count INTEGER DEFAULT 0,
          shares_count INTEGER DEFAULT 0,
          views_count INTEGER DEFAULT 0,
          is_liked_by_current_user INTEGER DEFAULT 0,
          is_shared_by_current_user INTEGER DEFAULT 0,
          is_pinned INTEGER DEFAULT 0,
          is_emergency INTEGER DEFAULT 0,
          allow_comments INTEGER DEFAULT 1,
          allow_shares INTEGER DEFAULT 1,
          metadata TEXT, -- JSON object for sync status, etc.
          cached_at INTEGER
        )
      ''');

      // Comments table
      await db.execute('''
        CREATE TABLE comments (
          id TEXT PRIMARY KEY,
          post_id TEXT NOT NULL,
          author_id TEXT NOT NULL,
          author_name TEXT NOT NULL,
          author_role TEXT,
          author_avatar_url TEXT,
          content TEXT NOT NULL,
          parent_comment_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          likes_count INTEGER DEFAULT 0,
          is_liked_by_current_user INTEGER DEFAULT 0,
          is_author INTEGER DEFAULT 0,
          metadata TEXT, -- JSON object
          FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE
        )
      ''');

      // Sync queue table
      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          action TEXT NOT NULL,
          item_id TEXT NOT NULL,
          data TEXT NOT NULL, -- JSON object
          created_at INTEGER NOT NULL,
          attempts INTEGER DEFAULT 0,
          status TEXT DEFAULT 'pending',
          last_attempt_at INTEGER,
          completed_at INTEGER,
          error TEXT
        )
      ''');

      // User cache table
      await db.execute('''
        CREATE TABLE user_cache (
          id TEXT PRIMARY KEY,
          full_name TEXT NOT NULL,
          role TEXT NOT NULL,
          avatar_url TEXT,
          address TEXT, -- JSON object
          is_online INTEGER DEFAULT 0,
          last_seen INTEGER,
          cached_at INTEGER NOT NULL,
          metadata TEXT -- JSON object
        )
      ''');

      // Media cache table
      await db.execute('''
        CREATE TABLE media_cache (
          id TEXT PRIMARY KEY,
          url TEXT NOT NULL,
          local_path TEXT NOT NULL,
          media_type TEXT NOT NULL, -- 'image', 'document', 'video'
          file_size INTEGER,
          cached_at INTEGER NOT NULL,
          last_accessed INTEGER NOT NULL,
          metadata TEXT -- JSON object
        )
      ''');

      // Create indexes for better performance
      await db.execute('CREATE INDEX idx_posts_created_at ON posts (created_at DESC)');
      await db.execute('CREATE INDEX idx_posts_author_id ON posts (author_id)');
      await db.execute('CREATE INDEX idx_posts_category ON posts (category)');
      await db.execute('CREATE INDEX idx_comments_post_id ON comments (post_id)');
      await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue (status)');
      await db.execute('CREATE INDEX idx_sync_queue_created_at ON sync_queue (created_at)');

      debugPrint('Database tables created successfully');
    } catch (e) {
      debugPrint('Error creating database tables: $e');
      rethrow;
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades here
    debugPrint('Upgrading database from version $oldVersion to $newVersion');
  }

  /// Get database instance
  Future<Database> get database async {
    if (_database == null) {
      await initialize();
    }
    return _database!;
  }

  /// Insert or update post
  Future<void> insertOrUpdatePost(PostModel post) async {
    try {
      final db = await database;
      await db.insertOrReplace('posts', _postToMap(post));
    } catch (e) {
      debugPrint('Error inserting/updating post: $e');
      rethrow;
    }
  }

  /// Insert post
  Future<void> insertPost(PostModel post) async {
    try {
      final db = await database;
      await db.insert('posts', _postToMap(post));
    } catch (e) {
      debugPrint('Error inserting post: $e');
      rethrow;
    }
  }

  /// Update post
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      final db = await database;
      await db.update(
        'posts',
        updates,
        where: 'id = ?',
        whereArgs: [postId],
      );
    } catch (e) {
      debugPrint('Error updating post: $e');
      rethrow;
    }
  }

  /// Get posts with pagination
  Future<List<PostModel>> getPosts({
    int limit = 20,
    String? lastPostId,
    PostCategory? category,
  }) async {
    try {
      final db = await database;
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category.toString());
      }

      if (lastPostId != null) {
        // Get the timestamp of the last post for pagination
        final lastPostResult = await db.query(
          'posts',
          columns: ['created_at'],
          where: 'id = ?',
          whereArgs: [lastPostId],
          limit: 1,
        );
        
        if (lastPostResult.isNotEmpty) {
          final lastTimestamp = lastPostResult.first['created_at'] as int;
          whereClause += ' AND created_at < ?';
          whereArgs.add(lastTimestamp);
        }
      }

      final result = await db.query(
        'posts',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
        limit: limit,
      );

      return result.map((map) => _postFromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting posts: $e');
      return [];
    }
  }

  /// Update post engagement (likes, comments, shares)
  Future<void> updatePostEngagement(String postId, Map<String, dynamic> updates) async {
    try {
      final db = await database;
      
      // Get current values
      final result = await db.query(
        'posts',
        where: 'id = ?',
        whereArgs: [postId],
        limit: 1,
      );
      
      if (result.isEmpty) return;
      
      final current = result.first;
      final updatedValues = <String, dynamic>{};
      
      // Handle incremental updates
      updates.forEach((key, value) {
        if (key.endsWith('Count') && value is int) {
          final currentValue = current[_camelToSnake(key)] as int? ?? 0;
          updatedValues[_camelToSnake(key)] = currentValue + value;
        } else {
          updatedValues[_camelToSnake(key)] = value;
        }
      });
      
      updatedValues['updated_at'] = DateTime.now().millisecondsSinceEpoch;
      
      await db.update(
        'posts',
        updatedValues,
        where: 'id = ?',
        whereArgs: [postId],
      );
    } catch (e) {
      debugPrint('Error updating post engagement: $e');
    }
  }

  /// Insert comment
  Future<void> insertComment(CommentModel comment) async {
    try {
      final db = await database;
      await db.insert('comments', _commentToMap(comment));
    } catch (e) {
      debugPrint('Error inserting comment: $e');
      rethrow;
    }
  }

  /// Update comment
  Future<void> updateComment(String commentId, Map<String, dynamic> updates) async {
    try {
      final db = await database;
      await db.update(
        'comments',
        updates,
        where: 'id = ?',
        whereArgs: [commentId],
      );
    } catch (e) {
      debugPrint('Error updating comment: $e');
      rethrow;
    }
  }

  /// Get comments for a post
  Future<List<CommentModel>> getComments(String postId) async {
    try {
      final db = await database;
      final result = await db.query(
        'comments',
        where: 'post_id = ?',
        whereArgs: [postId],
        orderBy: 'created_at ASC',
      );

      return result.map((map) => _commentFromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting comments: $e');
      return [];
    }
  }

  /// Insert sync item
  Future<void> insertSyncItem(SyncItem item) async {
    try {
      final db = await database;
      await db.insert('sync_queue', _syncItemToMap(item));
    } catch (e) {
      debugPrint('Error inserting sync item: $e');
      rethrow;
    }
  }

  /// Update sync item
  Future<void> updateSyncItem(String itemId, Map<String, dynamic> updates) async {
    try {
      final db = await database;
      await db.update(
        'sync_queue',
        updates,
        where: 'id = ?',
        whereArgs: [itemId],
      );
    } catch (e) {
      debugPrint('Error updating sync item: $e');
      rethrow;
    }
  }

  /// Get pending sync items
  Future<List<SyncItem>> getPendingSyncItems() async {
    try {
      final db = await database;
      final result = await db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );

      return result.map((map) => _syncItemFromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting pending sync items: $e');
      return [];
    }
  }

  /// Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    try {
      final db = await database;
      
      final pendingResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE status = ?',
        ['pending'],
      );
      
      final completedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE status = ?',
        ['completed'],
      );
      
      final failedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE status = ?',
        ['failed'],
      );

      return {
        'pending': pendingResult.first['count'] as int,
        'completed': completedResult.first['count'] as int,
        'failed': failedResult.first['count'] as int,
      };
    } catch (e) {
      debugPrint('Error getting sync stats: $e');
      return {};
    }
  }

  /// Clear old cached data
  Future<void> clearOldCache(DateTime cutoffDate) async {
    try {
      final db = await database;
      final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch;
      
      // Clear old posts
      await db.delete(
        'posts',
        where: 'cached_at < ?',
        whereArgs: [cutoffTimestamp],
      );
      
      // Clear old comments
      await db.delete(
        'comments',
        where: 'created_at < ?',
        whereArgs: [cutoffTimestamp],
      );
      
      // Clear completed sync items older than cutoff
      await db.delete(
        'sync_queue',
        where: 'status = ? AND completed_at < ?',
        whereArgs: ['completed', cutoffTimestamp],
      );
      
      // Clear old media cache
      await db.delete(
        'media_cache',
        where: 'last_accessed < ?',
        whereArgs: [cutoffTimestamp],
      );
      
      debugPrint('Cleared old cache data');
    } catch (e) {
      debugPrint('Error clearing old cache: $e');
    }
  }

  /// Get storage usage information
  Future<Map<String, dynamic>> getStorageUsage() async {
    try {
      final db = await database;
      
      final postsCount = await db.rawQuery('SELECT COUNT(*) as count FROM posts');
      final commentsCount = await db.rawQuery('SELECT COUNT(*) as count FROM comments');
      final syncQueueCount = await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
      final mediaCacheCount = await db.rawQuery('SELECT COUNT(*) as count FROM media_cache');
      
      // Get database file size
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, _databaseName);
      final dbFile = File(dbPath);
      final dbSize = await dbFile.exists() ? await dbFile.length() : 0;

      return {
        'posts_count': postsCount.first['count'],
        'comments_count': commentsCount.first['count'],
        'sync_queue_count': syncQueueCount.first['count'],
        'media_cache_count': mediaCacheCount.first['count'],
        'database_size_bytes': dbSize,
        'database_size_mb': (dbSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      debugPrint('Error getting storage usage: $e');
      return {};
    }
  }

  /// Convert PostModel to database map
  Map<String, dynamic> _postToMap(PostModel post) {
    return {
      'id': post.id,
      'author_id': post.authorId,
      'author_name': post.authorName,
      'author_role': post.authorRole,
      'author_avatar_url': post.authorAvatarUrl,
      'title': post.title,
      'content': post.content,
      'category': post.category.toString(),
      'visibility': post.visibility.toString(),
      'priority': post.priority.toString(),
      'hashtags': jsonEncode(post.hashtags),
      'image_urls': jsonEncode(post.imageUrls),
      'document_urls': jsonEncode(post.documentUrls),
      'geographic_targeting': post.geographicTargeting != null 
          ? jsonEncode(post.geographicTargeting!.toMap()) 
          : null,
      'created_at': post.createdAt.millisecondsSinceEpoch,
      'updated_at': post.updatedAt.millisecondsSinceEpoch,
      'likes_count': post.likesCount,
      'comments_count': post.commentsCount,
      'shares_count': post.sharesCount,
      'views_count': post.viewsCount,
      'is_liked_by_current_user': post.isLikedByCurrentUser ? 1 : 0,
      'is_shared_by_current_user': post.isSharedByCurrentUser ? 1 : 0,
      'is_pinned': post.isPinned ? 1 : 0,
      'is_emergency': post.isEmergency ? 1 : 0,
      'allow_comments': post.allowComments ? 1 : 0,
      'allow_shares': post.allowShares ? 1 : 0,
      'metadata': post.metadata != null ? jsonEncode(post.metadata) : null,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Convert database map to PostModel
  PostModel _postFromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'],
      authorId: map['author_id'],
      authorName: map['author_name'],
      authorRole: map['author_role'],
      authorAvatarUrl: map['author_avatar_url'],
      title: map['title'],
      content: map['content'],
      category: PostCategory.values.firstWhere(
        (e) => e.toString() == map['category'],
        orElse: () => PostCategory.generalDiscussion,
      ),
      visibility: PostVisibility.values.firstWhere(
        (e) => e.toString() == map['visibility'],
        orElse: () => PostVisibility.public,
      ),
      priority: PostPriority.values.firstWhere(
        (e) => e.toString() == map['priority'],
        orElse: () => PostPriority.normal,
      ),
      hashtags: List<String>.from(jsonDecode(map['hashtags'] ?? '[]')),
      imageUrls: List<String>.from(jsonDecode(map['image_urls'] ?? '[]')),
      documentUrls: List<String>.from(jsonDecode(map['document_urls'] ?? '[]')),
      geographicTargeting: map['geographic_targeting'] != null
          ? GeographicTargeting.fromMap(jsonDecode(map['geographic_targeting']))
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      likesCount: map['likes_count'] ?? 0,
      commentsCount: map['comments_count'] ?? 0,
      sharesCount: map['shares_count'] ?? 0,
      viewsCount: map['views_count'] ?? 0,
      isLikedByCurrentUser: (map['is_liked_by_current_user'] ?? 0) == 1,
      isSharedByCurrentUser: (map['is_shared_by_current_user'] ?? 0) == 1,
      isPinned: (map['is_pinned'] ?? 0) == 1,
      isEmergency: (map['is_emergency'] ?? 0) == 1,
      allowComments: (map['allow_comments'] ?? 1) == 1,
      allowShares: (map['allow_shares'] ?? 1) == 1,
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(map['metadata']))
          : null,
    );
  }

  /// Convert CommentModel to database map
  Map<String, dynamic> _commentToMap(CommentModel comment) {
    return {
      'id': comment.id,
      'post_id': comment.postId,
      'author_id': comment.authorId,
      'author_name': comment.authorName,
      'author_role': comment.authorRole,
      'author_avatar_url': comment.authorAvatarUrl,
      'content': comment.content,
      'parent_comment_id': comment.parentCommentId,
      'created_at': comment.createdAt.millisecondsSinceEpoch,
      'updated_at': comment.updatedAt.millisecondsSinceEpoch,
      'likes_count': comment.likesCount,
      'is_liked_by_current_user': comment.isLikedByCurrentUser ? 1 : 0,
      'is_author': comment.isAuthor ? 1 : 0,
      'metadata': comment.metadata != null ? jsonEncode(comment.metadata) : null,
    };
  }

  /// Convert database map to CommentModel
  CommentModel _commentFromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'],
      postId: map['post_id'],
      authorId: map['author_id'],
      authorName: map['author_name'],
      authorRole: map['author_role'],
      authorAvatarUrl: map['author_avatar_url'],
      content: map['content'],
      parentCommentId: map['parent_comment_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      likesCount: map['likes_count'] ?? 0,
      isLikedByCurrentUser: (map['is_liked_by_current_user'] ?? 0) == 1,
      isAuthor: (map['is_author'] ?? 0) == 1,
      replies: [], // Replies would be loaded separately
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(map['metadata']))
          : null,
    );
  }

  /// Convert SyncItem to database map
  Map<String, dynamic> _syncItemToMap(SyncItem item) {
    return {
      'id': item.id,
      'action': item.action,
      'item_id': item.itemId,
      'data': jsonEncode(item.data),
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'attempts': item.attempts,
      'status': item.status.toString(),
      'last_attempt_at': item.lastAttemptAt?.millisecondsSinceEpoch,
      'completed_at': item.completedAt?.millisecondsSinceEpoch,
      'error': item.error,
    };
  }

  /// Convert database map to SyncItem
  SyncItem _syncItemFromMap(Map<String, dynamic> map) {
    return SyncItem(
      id: map['id'],
      action: map['action'],
      itemId: map['item_id'],
      data: jsonDecode(map['data']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      attempts: map['attempts'] ?? 0,
      status: SyncStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => SyncStatus.pending,
      ),
      lastAttemptAt: map['last_attempt_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_attempt_at'])
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'])
          : null,
      error: map['error'],
    );
  }

  /// Convert camelCase to snake_case
  String _camelToSnake(String camelCase) {
    return camelCase.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}