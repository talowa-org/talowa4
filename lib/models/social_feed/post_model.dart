// Post Model for TALOWA Social Feed
// Complete post data model with all required fields
import 'package:cloud_firestore/cloud_firestore.dart';
import 'geographic_targeting.dart';

class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String? title;
  final String content;
  final List<String> mediaUrls; // Legacy field - kept for backward compatibility
  final List<String> imageUrls; // Specific image URLs
  final List<String> videoUrls; // Specific video URLs
  final List<String> documentUrls; // Specific document URLs
  final List<String> hashtags;
  final PostCategory category;
  final String location;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLikedByCurrentUser;
  final GeographicTargeting? geographicTargeting;

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    this.title,
    required this.content,
    this.mediaUrls = const [], // Legacy field - kept for backward compatibility
    this.imageUrls = const [],
    this.videoUrls = const [],
    this.documentUrls = const [],
    required this.hashtags,
    required this.category,
    required this.location,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLikedByCurrentUser,
    this.geographicTargeting,
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
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []), // Legacy support
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrls: List<String>.from(data['videoUrls'] ?? []),
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      category: PostCategoryExtension.fromString(data['category'] ?? 'general_discussion'),
      location: data['location'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      isLikedByCurrentUser: false, // This will be set separately
      geographicTargeting: data['geographicTargeting'] != null 
          ? GeographicTargeting.fromMap(data['geographicTargeting']) 
          : null,
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
      'mediaUrls': mediaUrls, // Legacy support
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'documentUrls': documentUrls,
      'hashtags': hashtags,
      'category': category.value,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'geographicTargeting': geographicTargeting?.toMap(),
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
    List<String>? imageUrls,
    List<String>? videoUrls,
    List<String>? documentUrls,
    List<String>? hashtags,
    PostCategory? category,
    String? location,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isLikedByCurrentUser,
    GeographicTargeting? geographicTargeting,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrls: videoUrls ?? this.videoUrls,
      documentUrls: documentUrls ?? this.documentUrls,
      hashtags: hashtags ?? this.hashtags,
      category: category ?? this.category,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      geographicTargeting: geographicTargeting ?? this.geographicTargeting,
    );
  }

  // Convenience methods for media handling
  bool get hasImages => imageUrls.isNotEmpty;
  bool get hasVideos => videoUrls.isNotEmpty;
  bool get hasDocuments => documentUrls.isNotEmpty;
  bool get hasMedia => hasImages || hasVideos || hasDocuments;

  int get totalMediaCount => imageUrls.length + videoUrls.length + documentUrls.length;

  List<String> get allMediaUrls => [...imageUrls, ...videoUrls, ...documentUrls];

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

// Post visibility enum
enum PostVisibility {
  public,
  coordinatorsOnly,
  localCommunity,
  private,
}

extension PostVisibilityExtension on PostVisibility {
  String get value {
    switch (this) {
      case PostVisibility.public:
        return 'public';
      case PostVisibility.coordinatorsOnly:
        return 'coordinators_only';
      case PostVisibility.localCommunity:
        return 'local_community';
      case PostVisibility.private:
        return 'private';
    }
  }

  String get displayName {
    switch (this) {
      case PostVisibility.public:
        return 'Public';
      case PostVisibility.coordinatorsOnly:
        return 'Coordinators Only';
      case PostVisibility.localCommunity:
        return 'Local Community';
      case PostVisibility.private:
        return 'Private';
    }
  }

  String get description {
    switch (this) {
      case PostVisibility.public:
        return 'Everyone can see this post';
      case PostVisibility.coordinatorsOnly:
        return 'Only coordinators can see this post';
      case PostVisibility.localCommunity:
        return 'Only local community members can see this post';
      case PostVisibility.private:
        return 'Only you can see this post';
    }
  }

  static PostVisibility fromString(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'coordinators_only':
        return PostVisibility.coordinatorsOnly;
      case 'local_community':
        return PostVisibility.localCommunity;
      case 'private':
        return PostVisibility.private;
      default:
        return PostVisibility.public;
    }
  }
}

// Post priority enum
enum PostPriority {
  low,
  normal,
  high,
  urgent,
  emergency,
}

extension PostPriorityExtension on PostPriority {
  String get value {
    switch (this) {
      case PostPriority.low:
        return 'low';
      case PostPriority.normal:
        return 'normal';
      case PostPriority.high:
        return 'high';
      case PostPriority.urgent:
        return 'urgent';
      case PostPriority.emergency:
        return 'emergency';
    }
  }

  String get displayName {
    switch (this) {
      case PostPriority.low:
        return 'Low Priority';
      case PostPriority.normal:
        return 'Normal';
      case PostPriority.high:
        return 'High Priority';
      case PostPriority.urgent:
        return 'Urgent';
      case PostPriority.emergency:
        return 'Emergency';
    }
  }

  static PostPriority fromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return PostPriority.low;
      case 'high':
        return PostPriority.high;
      case 'urgent':
        return PostPriority.urgent;
      case 'emergency':
        return PostPriority.emergency;
      default:
        return PostPriority.normal;
    }
  }
}
