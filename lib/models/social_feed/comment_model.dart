// Comment Model for TALOWA Social Feed System
// Represents comments and replies on social media posts

import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? parentCommentId; // For replies
  final int likesCount;
  final bool isLikedByCurrentUser;
  final bool isReported;
  final bool isHidden;
  final String? moderationReason;
  final DateTime? moderatedAt;
  final String? moderatedBy;
  final List<CommentModel> replies;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.parentCommentId,
    this.likesCount = 0,
    this.isLikedByCurrentUser = false,
    this.isReported = false,
    this.isHidden = false,
    this.moderationReason,
    this.moderatedAt,
    this.moderatedBy,
    this.replies = const [],
  });

  /// Create CommentModel from Firestore document
  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CommentModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorRole: data['authorRole'],
      authorAvatarUrl: data['authorAvatarUrl'],
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      parentCommentId: data['parentCommentId'],
      likesCount: data['likesCount'] ?? 0,
      isLikedByCurrentUser: data['isLikedByCurrentUser'] ?? false,
      isReported: data['isReported'] ?? false,
      isHidden: data['isHidden'] ?? false,
      moderationReason: data['moderationReason'],
      moderatedAt: data['moderatedAt'] != null 
          ? (data['moderatedAt'] as Timestamp).toDate()
          : null,
      moderatedBy: data['moderatedBy'],
      replies: (data['replies'] as List<dynamic>?)
          ?.map((reply) => CommentModel.fromMap(reply))
          .toList() ?? [],
    );
  }

  /// Create CommentModel from Map (for nested data)
  factory CommentModel.fromMap(Map<String, dynamic> data) {
    return CommentModel(
      id: data['id'] ?? '',
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorRole: data['authorRole'],
      authorAvatarUrl: data['authorAvatarUrl'],
      content: data['content'] ?? '',
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt']),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] is Timestamp 
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(data['updatedAt']))
          : null,
      parentCommentId: data['parentCommentId'],
      likesCount: data['likesCount'] ?? 0,
      isLikedByCurrentUser: data['isLikedByCurrentUser'] ?? false,
      isReported: data['isReported'] ?? false,
      isHidden: data['isHidden'] ?? false,
      moderationReason: data['moderationReason'],
      moderatedAt: data['moderatedAt'] != null 
          ? (data['moderatedAt'] is Timestamp 
              ? (data['moderatedAt'] as Timestamp).toDate()
              : DateTime.parse(data['moderatedAt']))
          : null,
      moderatedBy: data['moderatedBy'],
      replies: (data['replies'] as List<dynamic>?)
          ?.map((reply) => CommentModel.fromMap(reply))
          .toList() ?? [],
    );
  }

  /// Convert CommentModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'parentCommentId': parentCommentId,
      'likesCount': likesCount,
      'isReported': isReported,
      'isHidden': isHidden,
      'moderationReason': moderationReason,
      'moderatedAt': moderatedAt != null ? Timestamp.fromDate(moderatedAt!) : null,
      'moderatedBy': moderatedBy,
      'replies': replies.map((reply) => reply.toMap()).toList(),
    };
  }

  /// Convert CommentModel to Map (for nested data)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'parentCommentId': parentCommentId,
      'likesCount': likesCount,
      'isLikedByCurrentUser': isLikedByCurrentUser,
      'isReported': isReported,
      'isHidden': isHidden,
      'moderationReason': moderationReason,
      'moderatedAt': moderatedAt?.toIso8601String(),
      'moderatedBy': moderatedBy,
      'replies': replies.map((reply) => reply.toMap()).toList(),
    };
  }

  /// Create a copy of CommentModel with updated fields
  CommentModel copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? authorAvatarUrl,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentCommentId,
    int? likesCount,
    bool? isLikedByCurrentUser,
    bool? isReported,
    bool? isHidden,
    String? moderationReason,
    DateTime? moderatedAt,
    String? moderatedBy,
    List<CommentModel>? replies,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      likesCount: likesCount ?? this.likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isReported: isReported ?? this.isReported,
      isHidden: isHidden ?? this.isHidden,
      moderationReason: moderationReason ?? this.moderationReason,
      moderatedAt: moderatedAt ?? this.moderatedAt,
      moderatedBy: moderatedBy ?? this.moderatedBy,
      replies: replies ?? this.replies,
    );
  }

  /// Check if comment is visible to a specific user
  bool isVisibleToUser({
    required String userId,
    String? userRole,
  }) {
    // Author can always see their own comments
    if (authorId == userId) return true;
    
    // Hidden comments are not visible to regular users
    if (isHidden) {
      return userRole != null && 
             (userRole.contains('coordinator') || userRole.contains('admin'));
    }
    
    return true;
  }

  /// Check if user can interact with this comment
  bool canUserInteract({
    required String userId,
    String? userRole,
  }) {
    // Author can always interact
    if (authorId == userId) return true;
    
    // Hidden or reported comments have limited interaction
    if (isHidden || isReported) {
      return userRole != null && 
             (userRole.contains('coordinator') || userRole.contains('admin'));
    }
    
    return true;
  }

  /// Get formatted time ago string
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if this is a reply to another comment
  bool get isReply => parentCommentId != null;

  /// Check if this comment has replies
  bool get hasReplies => replies.isNotEmpty;

  /// Get the depth level of this comment (0 for top-level, 1 for reply, etc.)
  int get depth {
    if (parentCommentId == null) return 0;
    // For now, we'll limit to 2 levels (comment and reply)
    return 1;
  }

  /// Validate comment content
  static String? validateContent(String content) {
    if (content.trim().isEmpty) {
      return 'Comment cannot be empty';
    }
    if (content.length > 500) {
      return 'Comment cannot exceed 500 characters';
    }
    return null;
  }

  /// Check if content contains inappropriate language (basic implementation)
  static bool containsInappropriateContent(String content) {
    // This is a basic implementation - in production, use a proper content moderation service
    final inappropriateWords = [
      // Add inappropriate words here
    ];
    
    final lowerContent = content.toLowerCase();
    return inappropriateWords.any((word) => lowerContent.contains(word));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CommentModel{id: $id, authorName: $authorName, content: ${content.substring(0, content.length > 30 ? 30 : content.length)}...}';
  }
}
