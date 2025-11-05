// Comment Model for TALOWA Social Feed
import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String content;
  final DateTime createdAt;
  final String? parentCommentId; // For nested comments
  final int likesCount;
  final bool isLikedByCurrentUser;
  final List<String> replies; // IDs of reply comments

  CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    required this.content,
    required this.createdAt,
    this.parentCommentId,
    this.likesCount = 0,
    this.isLikedByCurrentUser = false,
    this.replies = const [],
  });

  // Convert from Firestore document
  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CommentModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorRole: data['authorRole'],
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentCommentId: data['parentCommentId'],
      likesCount: data['likesCount'] ?? 0,
      isLikedByCurrentUser: false, // This will be set separately
      replies: List<String>.from(data['replies'] ?? []),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'parentCommentId': parentCommentId,
      'likesCount': likesCount,
      'replies': replies,
    };
  }

  // Copy with method for updates
  CommentModel copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? content,
    DateTime? createdAt,
    String? parentCommentId,
    int? likesCount,
    bool? isLikedByCurrentUser,
    List<String>? replies,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      likesCount: likesCount ?? this.likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      replies: replies ?? this.replies,
    );
  }

  // Validation methods
  static String? validateContent(String content) {
    if (content.trim().isEmpty) {
      return 'Comment cannot be empty';
    }
    
    if (content.length > 1000) {
      return 'Comment cannot exceed 1000 characters';
    }
    
    return null; // Valid
  }

  // Helper methods
  bool get isReply => parentCommentId != null;
  bool get hasReplies => replies.isNotEmpty;
  
  @override
  String toString() {
    return 'CommentModel(id: $id, authorName: $authorName, content: ${content.substring(0, content.length > 50 ? 50 : content.length)}...)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}