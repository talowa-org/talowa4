// Post Model for TALOWA Social Feed
// Complete post data model with all required fields
import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String? title;
  final String content;
  final List<String> mediaUrls;
  final List<String> hashtags;
  final PostCategory category;
  final String location;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLikedByCurrentUser;

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    this.title,
    required this.content,
    required this.mediaUrls,
    required this.hashtags,
    required this.category,
    required this.location,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLikedByCurrentUser,
  });

  // Convert from Firestore document
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PostModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorRole: data['authorRole'],
      title: data['title'],
      content: data['content'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      category: PostCategoryExtension.fromString(data['category'] ?? 'general_discussion'),
      location: data['location'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      isLikedByCurrentUser: false, // This will be set separately
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'title': title,
      'content': content,
      'mediaUrls': mediaUrls,
      'hashtags': hashtags,
      'category': category.value,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
    };
  }

  // Copy with method for updates
  PostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? title,
    String? content,
    List<String>? mediaUrls,
    List<String>? hashtags,
    PostCategory? category,
    String? location,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isLikedByCurrentUser,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      hashtags: hashtags ?? this.hashtags,
      category: category ?? this.category,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    );
  }

  @override
  String toString() {
    return 'PostModel(id: $id, authorName: $authorName, content: ${content.substring(0, content.length > 50 ? 50 : content.length)}...)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Post categories enum
enum PostCategory {
  announcement,
  successStory,
  legalUpdate,
  emergency,
  communityNews,
  generalDiscussion,
  landRights,
  agriculture,
  governmentSchemes,
  education,
  health,
}

extension PostCategoryExtension on PostCategory {
  String get value {
    switch (this) {
      case PostCategory.announcement:
        return 'announcement';
      case PostCategory.successStory:
        return 'success_story';
      case PostCategory.legalUpdate:
        return 'legal_update';
      case PostCategory.emergency:
        return 'emergency';
      case PostCategory.communityNews:
        return 'community_news';
      case PostCategory.generalDiscussion:
        return 'general_discussion';
      case PostCategory.landRights:
        return 'land_rights';
      case PostCategory.agriculture:
        return 'agriculture';
      case PostCategory.governmentSchemes:
        return 'government_schemes';
      case PostCategory.education:
        return 'education';
      case PostCategory.health:
        return 'health';
    }
  }

  String get displayName {
    switch (this) {
      case PostCategory.announcement:
        return 'Announcement';
      case PostCategory.successStory:
        return 'Success Story';
      case PostCategory.legalUpdate:
        return 'Legal Update';
      case PostCategory.emergency:
        return 'Emergency';
      case PostCategory.communityNews:
        return 'Community News';
      case PostCategory.generalDiscussion:
        return 'General Discussion';
      case PostCategory.landRights:
        return 'Land Rights';
      case PostCategory.agriculture:
        return 'Agriculture';
      case PostCategory.governmentSchemes:
        return 'Government Schemes';
      case PostCategory.education:
        return 'Education';
      case PostCategory.health:
        return 'Health';
    }
  }

  static PostCategory fromString(String category) {
    switch (category.toLowerCase()) {
      case 'announcement':
        return PostCategory.announcement;
      case 'success_story':
        return PostCategory.successStory;
      case 'legal_update':
        return PostCategory.legalUpdate;
      case 'emergency':
        return PostCategory.emergency;
      case 'community_news':
        return PostCategory.communityNews;
      case 'land_rights':
        return PostCategory.landRights;
      case 'agriculture':
        return PostCategory.agriculture;
      case 'government_schemes':
        return PostCategory.governmentSchemes;
      case 'education':
        return PostCategory.education;
      case 'health':
        return PostCategory.health;
      default:
        return PostCategory.generalDiscussion;
    }
  }
}