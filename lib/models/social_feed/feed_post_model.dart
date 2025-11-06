// Feed Post Model for TALOWA Social Feed
// Simplified post model for feed display
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_model.dart';

class FeedPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String? authorAvatarUrl;
  final String content;
  final List<String> mediaUrls;
  final List<String> hashtags;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLikedByCurrentUser;
  final PostCategory category;
  final String location;

  FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
    required this.content,
    this.mediaUrls = const [],
    this.hashtags = const [],
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isLikedByCurrentUser = false,
    this.category = PostCategory.generalDiscussion,
    this.location = '',
  });

  factory FeedPost.fromPostModel(PostModel post) {
    return FeedPost(
      id: post.id,
      authorId: post.authorId,
      authorName: post.authorName,
      authorRole: post.authorRole,
      authorAvatarUrl: post.authorAvatarUrl,
      content: post.content,
      mediaUrls: post.allMediaUrls,
      hashtags: post.hashtags,
      createdAt: post.createdAt,
      likesCount: post.likesCount,
      commentsCount: post.commentsCount,
      sharesCount: post.sharesCount,
      isLikedByCurrentUser: post.isLikedByCurrentUser,
      category: post.category,
      location: post.location,
    );
  }

  factory FeedPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FeedPost(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorRole: data['authorRole'],
      authorAvatarUrl: data['authorAvatarUrl'],
      content: data['content'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      isLikedByCurrentUser: false, // Set separately
      category: PostCategoryExtension.fromString(data['category'] ?? 'general_discussion'),
      location: data['location'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'mediaUrls': mediaUrls,
      'hashtags': hashtags,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'category': category.value,
      'location': location,
    };
  }

  FeedPost copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? authorAvatarUrl,
    String? content,
    List<String>? mediaUrls,
    List<String>? hashtags,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isLikedByCurrentUser,
    PostCategory? category,
    String? location,
  }) {
    return FeedPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      hashtags: hashtags ?? this.hashtags,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      category: category ?? this.category,
      location: location ?? this.location,
    );
  }

  // Convenience getters
  bool get hasMedia => mediaUrls.isNotEmpty;
  bool get hasHashtags => hashtags.isNotEmpty;
  
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedPost && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}