// Enhanced Comment Model for TALOWA Instagram-like Comments
// Comprehensive comment model with modern social media features
import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorProfileImageUrl;
  final String? authorAvatarUrl; // Added alias for authorProfileImageUrl
  final String? authorRole;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int likesCount;
  final int repliesCount;
  final bool isLikedByCurrentUser;
  final bool isAuthor; // Added missing property
  final String? parentCommentId; // For nested replies
  final List<String> mentionedUserIds;
  final List<CommentModel> replies; // Added missing property
  final bool isPinned; // For pinned comments
  final bool isAuthorVerified;
  final DateTime? updatedAt; // Added for sync functionality
  final int syncVersion; // Added for sync functionality
  final Map<String, dynamic>? metadata;

  CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorProfileImageUrl,
    this.authorRole,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.isLikedByCurrentUser = false,
    this.isAuthor = false,
    this.parentCommentId,
    this.mentionedUserIds = const [],
    this.replies = const [],
    this.isPinned = false,
    this.isAuthorVerified = false,
    this.updatedAt,
    this.syncVersion = 1,
    this.metadata,
  }) : authorAvatarUrl = authorProfileImageUrl;

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CommentModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorProfileImageUrl: data['authorProfileImageUrl'],
      authorRole: data['authorRole'],
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      likesCount: data['likesCount'] ?? 0,
      repliesCount: data['repliesCount'] ?? 0,
      isLikedByCurrentUser: false, // Set separately
      isAuthor: data['isAuthor'] ?? false,
      parentCommentId: data['parentCommentId'],
      mentionedUserIds: List<String>.from(data['mentionedUserIds'] ?? []),
      replies: [], // Will be populated separately
      isPinned: data['isPinned'] ?? false,
      isAuthorVerified: data['isAuthorVerified'] ?? false,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      syncVersion: data['syncVersion'] ?? 1,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImageUrl': authorProfileImageUrl,
      'authorRole': authorRole,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'likesCount': likesCount,
      'repliesCount': repliesCount,
      'isAuthor': isAuthor,
      'parentCommentId': parentCommentId,
      'mentionedUserIds': mentionedUserIds,
      'isPinned': isPinned,
      'isAuthorVerified': isAuthorVerified,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'syncVersion': syncVersion,
      'metadata': metadata,
    };
  }

  CommentModel copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorProfileImageUrl,
    String? authorRole,
    String? content,
    DateTime? createdAt,
    DateTime? editedAt,
    int? likesCount,
    int? repliesCount,
    bool? isLikedByCurrentUser,
    bool? isAuthor,
    String? parentCommentId,
    List<String>? mentionedUserIds,
    List<CommentModel>? replies,
    bool? isPinned,
    bool? isAuthorVerified,
    DateTime? updatedAt,
    int? syncVersion,
    Map<String, dynamic>? metadata,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImageUrl: authorProfileImageUrl ?? this.authorProfileImageUrl,
      authorRole: authorRole ?? this.authorRole,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      likesCount: likesCount ?? this.likesCount,
      repliesCount: repliesCount ?? this.repliesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isAuthor: isAuthor ?? this.isAuthor,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      replies: replies ?? this.replies,
      isPinned: isPinned ?? this.isPinned,
      isAuthorVerified: isAuthorVerified ?? this.isAuthorVerified,
      updatedAt: updatedAt ?? this.updatedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convenience getters
  bool get isReply => parentCommentId != null;
  bool get isEdited => editedAt != null;
  bool get hasMentions => mentionedUserIds.isNotEmpty;
  bool get hasReplies => replies.isNotEmpty;
  
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${difference.inDays ~/ 7}w';
    }
  }

  // Method version of timeAgo for compatibility
  String getTimeAgo() => timeAgo;

  // Convert from Map (for sync functionality)
  factory CommentModel.fromMap(Map<String, dynamic> data) {
    return CommentModel(
      id: data['id'] ?? '',
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorProfileImageUrl: data['authorProfileImageUrl'],
      authorRole: data['authorRole'],
      content: data['content'] ?? '',
      createdAt: DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      editedAt: data['editedAt'] != null ? DateTime.parse(data['editedAt']) : null,
      likesCount: data['likesCount'] ?? 0,
      repliesCount: data['repliesCount'] ?? 0,
      isLikedByCurrentUser: data['isLikedByCurrentUser'] ?? false,
      isAuthor: data['isAuthor'] ?? false,
      parentCommentId: data['parentCommentId'],
      mentionedUserIds: List<String>.from(data['mentionedUserIds'] ?? []),
      replies: [], // Will be populated separately
      isPinned: data['isPinned'] ?? false,
      isAuthorVerified: data['isAuthorVerified'] ?? false,
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : null,
      syncVersion: data['syncVersion'] ?? 1,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  // Convert to Map (for sync functionality)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImageUrl': authorProfileImageUrl,
      'authorRole': authorRole,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
      'likesCount': likesCount,
      'repliesCount': repliesCount,
      'isLikedByCurrentUser': isLikedByCurrentUser,
      'isAuthor': isAuthor,
      'parentCommentId': parentCommentId,
      'mentionedUserIds': mentionedUserIds,
      'isPinned': isPinned,
      'isAuthorVerified': isAuthorVerified,
      'updatedAt': updatedAt?.toIso8601String(),
      'syncVersion': syncVersion,
      'metadata': metadata,
    };
  }

  // Validation methods
  static String? validateContent(String content) {
    if (content.trim().isEmpty) {
      return 'Comment cannot be empty';
    }
    
    if (content.length > 2200) {
      return 'Comment cannot exceed 2200 characters';
    }
    
    return null; // Valid
  }

  static List<String> extractMentions(String content) {
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(content);
    return matches.map((match) => match.group(1)!).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Comment thread model for organizing nested comments
class CommentThread {
  final CommentModel parentComment;
  final List<CommentModel> replies;
  final bool hasMoreReplies;
  final int totalRepliesCount;

  CommentThread({
    required this.parentComment,
    this.replies = const [],
    this.hasMoreReplies = false,
    this.totalRepliesCount = 0,
  });

  CommentThread copyWith({
    CommentModel? parentComment,
    List<CommentModel>? replies,
    bool? hasMoreReplies,
    int? totalRepliesCount,
  }) {
    return CommentThread(
      parentComment: parentComment ?? this.parentComment,
      replies: replies ?? this.replies,
      hasMoreReplies: hasMoreReplies ?? this.hasMoreReplies,
      totalRepliesCount: totalRepliesCount ?? this.totalRepliesCount,
    );
  }
}

// Comment sort options
enum CommentSortOption {
  newest,
  oldest,
  mostLiked,
  mostReplies,
}

extension CommentSortOptionExtension on CommentSortOption {
  String get displayName {
    switch (this) {
      case CommentSortOption.newest:
        return 'Newest First';
      case CommentSortOption.oldest:
        return 'Oldest First';
      case CommentSortOption.mostLiked:
        return 'Most Liked';
      case CommentSortOption.mostReplies:
        return 'Most Replies';
    }
  }
}