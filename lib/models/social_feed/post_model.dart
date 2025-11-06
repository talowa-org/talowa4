// Post Model for TALOWA Social Feed
// Complete post data model with all required fields
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'geographic_targeting.dart';

class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String? authorAvatarUrl; // Added missing property
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
  final int viewsCount; // Added missing property
  final bool isLikedByCurrentUser;
  final bool isSharedByCurrentUser; // Added missing property
  final bool isPinned; // Added missing property
  final bool isEmergency; // Added missing property
  final DateTime? updatedAt; // Added for sync functionality
  final int syncVersion; // Added for sync functionality
  final bool isDeleted; // Added for sync functionality
  final String visibility; // Added for database compatibility
  final String priority; // Added for database compatibility
  final bool allowComments; // Added for database compatibility
  final bool allowShares; // Added for database compatibility
  final Map<String, dynamic>? metadata; // Added for database compatibility
  final GeographicTargeting? geographicTargeting;
  final GeographicTargeting? targeting; // Added missing property (alias for geographicTargeting)

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
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
    this.viewsCount = 0,
    required this.isLikedByCurrentUser,
    this.isSharedByCurrentUser = false,
    this.isPinned = false,
    this.isEmergency = false,
    this.updatedAt,
    this.syncVersion = 1,
    this.isDeleted = false,
    this.visibility = 'public',
    this.priority = 'normal',
    this.allowComments = true,
    this.allowShares = true,
    this.metadata,
    this.geographicTargeting,
  }) : targeting = geographicTargeting;

  // Convert from Firestore document
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      
      if (data == null) {
        throw Exception('Document data is null for post ${doc.id}');
      }
      
      return PostModel(
        id: doc.id,
        authorId: data['authorId']?.toString() ?? '',
        authorName: data['authorName']?.toString() ?? 'Unknown User',
        authorRole: data['authorRole']?.toString(),
        authorAvatarUrl: data['authorAvatarUrl']?.toString(),
        title: data['title']?.toString(),
        content: data['content']?.toString() ?? '',
        mediaUrls: _safeListFromData(data['mediaUrls']), // Legacy support
        imageUrls: _safeListFromData(data['imageUrls']),
        videoUrls: _safeListFromData(data['videoUrls']),
        documentUrls: _safeListFromData(data['documentUrls']),
        hashtags: _safeListFromData(data['hashtags']),
        category: PostCategoryExtension.fromString(data['category']?.toString() ?? 'general_discussion'),
        location: data['location']?.toString() ?? '',
        createdAt: _safeDateFromTimestamp(data['createdAt']),
        likesCount: _safeIntFromData(data['likesCount']),
        commentsCount: _safeIntFromData(data['commentsCount']),
        sharesCount: _safeIntFromData(data['sharesCount']),
        viewsCount: _safeIntFromData(data['viewsCount']),
        isLikedByCurrentUser: false, // This will be set separately
        isSharedByCurrentUser: data['isSharedByCurrentUser'] == true,
        isPinned: data['isPinned'] == true,
        isEmergency: data['isEmergency'] == true,
        updatedAt: _safeDateFromTimestamp(data['updatedAt']),
        syncVersion: _safeIntFromData(data['syncVersion'], defaultValue: 1),
        isDeleted: data['isDeleted'] == true,
        visibility: data['visibility']?.toString() ?? 'public',
        priority: data['priority']?.toString() ?? 'normal',
        allowComments: data['allowComments'] != false,
        allowShares: data['allowShares'] != false,
        metadata: data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata']) : null,
        geographicTargeting: data['geographicTargeting'] != null 
            ? GeographicTargeting.fromMap(Map<String, dynamic>.from(data['geographicTargeting'])) 
            : null,
      );
    } catch (e) {
      throw Exception('Error parsing PostModel from Firestore document ${doc.id}: $e');
    }
  }

  // Helper methods for safe data extraction
  static List<String> _safeListFromData(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList();
    }
    return [];
  }

  static int _safeIntFromData(dynamic data, {int defaultValue = 0}) {
    if (data == null) return defaultValue;
    if (data is int) return data;
    if (data is double) return data.toInt();
    if (data is String) return int.tryParse(data) ?? defaultValue;
    return defaultValue;
  }

  static DateTime _safeDateFromTimestamp(dynamic data) {
    if (data == null) return DateTime.now();
    if (data is Timestamp) return data.toDate();
    if (data is DateTime) return data;
    return DateTime.now();
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'authorAvatarUrl': authorAvatarUrl,
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
      'viewsCount': viewsCount,
      'isSharedByCurrentUser': isSharedByCurrentUser,
      'isPinned': isPinned,
      'isEmergency': isEmergency,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'syncVersion': syncVersion,
      'isDeleted': isDeleted,
      'visibility': visibility,
      'priority': priority,
      'allowComments': allowComments,
      'allowShares': allowShares,
      'metadata': metadata,
      'geographicTargeting': geographicTargeting?.toMap(),
    };
  }

  // Copy with method for updates
  PostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? authorAvatarUrl,
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
    int? viewsCount,
    bool? isLikedByCurrentUser,
    bool? isSharedByCurrentUser,
    bool? isPinned,
    bool? isEmergency,
    DateTime? updatedAt,
    int? syncVersion,
    bool? isDeleted,
    String? visibility,
    String? priority,
    bool? allowComments,
    bool? allowShares,
    Map<String, dynamic>? metadata,
    GeographicTargeting? geographicTargeting,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
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
      viewsCount: viewsCount ?? this.viewsCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isSharedByCurrentUser: isSharedByCurrentUser ?? this.isSharedByCurrentUser,
      isPinned: isPinned ?? this.isPinned,
      isEmergency: isEmergency ?? this.isEmergency,
      updatedAt: updatedAt ?? this.updatedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      isDeleted: isDeleted ?? this.isDeleted,
      visibility: visibility ?? this.visibility,
      priority: priority ?? this.priority,
      allowComments: allowComments ?? this.allowComments,
      allowShares: allowShares ?? this.allowShares,
      metadata: metadata ?? this.metadata,
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

  // Time ago method for displaying relative time
  String getTimeAgo() {
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

  // Convert from Map (for sync functionality)
  factory PostModel.fromMap(Map<String, dynamic> data) {
    return PostModel(
      id: data['id'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorRole: data['authorRole'],
      authorAvatarUrl: data['authorAvatarUrl'],
      title: data['title'],
      content: data['content'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrls: List<String>.from(data['videoUrls'] ?? []),
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      category: PostCategoryExtension.fromString(data['category'] ?? 'general_discussion'),
      location: data['location'] ?? '',
      createdAt: DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      viewsCount: data['viewsCount'] ?? 0,
      isLikedByCurrentUser: data['isLikedByCurrentUser'] ?? false,
      isSharedByCurrentUser: data['isSharedByCurrentUser'] ?? false,
      isPinned: data['isPinned'] ?? false,
      isEmergency: data['isEmergency'] ?? false,
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : null,
      syncVersion: data['syncVersion'] ?? 1,
      isDeleted: data['isDeleted'] ?? false,
      visibility: data['visibility'] ?? 'public',
      priority: data['priority'] ?? 'normal',
      allowComments: data['allowComments'] ?? true,
      allowShares: data['allowShares'] ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
      geographicTargeting: data['geographicTargeting'] != null 
          ? GeographicTargeting.fromMap(data['geographicTargeting']) 
          : null,
    );
  }

  // Convert to Map (for sync functionality)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'authorAvatarUrl': authorAvatarUrl,
      'title': title,
      'content': content,
      'mediaUrls': mediaUrls,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'documentUrls': documentUrls,
      'hashtags': hashtags,
      'category': category.value,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'viewsCount': viewsCount,
      'isLikedByCurrentUser': isLikedByCurrentUser,
      'isSharedByCurrentUser': isSharedByCurrentUser,
      'isPinned': isPinned,
      'isEmergency': isEmergency,
      'updatedAt': updatedAt?.toIso8601String(),
      'syncVersion': syncVersion,
      'isDeleted': isDeleted,
      'visibility': visibility,
      'priority': priority,
      'allowComments': allowComments,
      'allowShares': allowShares,
      'metadata': metadata,
      'geographicTargeting': geographicTargeting?.toMap(),
    };
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

  // Icon to visually represent the category in UI components
  IconData get icon {
    switch (this) {
      case PostCategory.announcement:
        return Icons.campaign;
      case PostCategory.successStory:
        return Icons.celebration;
      case PostCategory.legalUpdate:
        return Icons.gavel;
      case PostCategory.emergency:
        return Icons.warning;
      case PostCategory.communityNews:
        return Icons.newspaper;
      case PostCategory.generalDiscussion:
        return Icons.forum;
      case PostCategory.landRights:
        return Icons.landscape;
      case PostCategory.agriculture:
        return Icons.agriculture;
      case PostCategory.governmentSchemes:
        return Icons.account_balance;
      case PostCategory.education:
        return Icons.school;
      case PostCategory.health:
        return Icons.health_and_safety;
    }
  }

  // Short description to explain the category purpose
  String get description {
    switch (this) {
      case PostCategory.announcement:
        return 'General announcements and notices';
      case PostCategory.successStory:
        return 'Share positive outcomes and achievements';
      case PostCategory.legalUpdate:
        return 'Important legal information and updates';
      case PostCategory.emergency:
        return 'Urgent matters requiring immediate attention';
      case PostCategory.communityNews:
        return 'Local community news and events';
      case PostCategory.generalDiscussion:
        return 'Open discussion topics';
      case PostCategory.landRights:
        return 'Land rights specific content';
      case PostCategory.agriculture:
        return 'Farming practices and agriculture';
      case PostCategory.governmentSchemes:
        return 'Government schemes and benefits';
      case PostCategory.education:
        return 'Education resources and opportunities';
      case PostCategory.health:
        return 'Health tips and resources';
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
