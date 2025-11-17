// Enhanced Instagram-style Post Model for TALOWA
// Comprehensive post model with modern social media features
import 'package:cloud_firestore/cloud_firestore.dart';

class InstagramPostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorProfileImageUrl;
  final String? authorVerificationBadge;
  final String caption; // Up to 2200 characters
  final List<MediaItem> mediaItems;
  final List<String> hashtags;
  final List<UserTag> userTags;
  final LocationTag? locationTag;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final bool isLikedByCurrentUser;
  final bool isBookmarkedByCurrentUser;
  final bool allowComments;
  final bool allowSharing;
  final PostVisibility visibility;
  final List<String> mentionedUserIds;
  final String? altText; // Accessibility support
  final Map<String, dynamic>? analytics;

  InstagramPostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorProfileImageUrl,
    this.authorVerificationBadge,
    required this.caption,
    required this.mediaItems,
    this.hashtags = const [],
    this.userTags = const [],
    this.locationTag,
    required this.createdAt,
    this.editedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    this.isLikedByCurrentUser = false,
    this.isBookmarkedByCurrentUser = false,
    this.allowComments = true,
    this.allowSharing = true,
    this.visibility = PostVisibility.public,
    this.mentionedUserIds = const [],
    this.altText,
    this.analytics,
  });

  factory InstagramPostModel.empty() {
    return InstagramPostModel(
      id: '',
      authorId: '',
      authorName: '',
      caption: '',
      mediaItems: [],
      createdAt: DateTime.now(),
    );
  }

  factory InstagramPostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle both new mediaItems format and old imageUrls/videoUrls format
    List<MediaItem> mediaItems = [];
    
    if (data['mediaItems'] != null) {
      // New format
      mediaItems = (data['mediaItems'] as List<dynamic>)
          .map((item) => MediaItem.fromMap(item as Map<String, dynamic>))
          .toList();
    } else {
      // Old format - convert imageUrls and videoUrls to mediaItems
      int mediaIndex = 0;
      if (data['imageUrls'] != null) {
        final imageUrls = List<String>.from(data['imageUrls']);
        for (final url in imageUrls) {
          mediaItems.add(MediaItem(
            id: 'media_$mediaIndex',
            type: MediaType.image,
            url: url,
            aspectRatio: 1.0,
          ));
          mediaIndex++;
        }
      }
      if (data['videoUrls'] != null) {
        final videoUrls = List<String>.from(data['videoUrls']);
        for (final url in videoUrls) {
          mediaItems.add(MediaItem(
            id: 'media_$mediaIndex',
            type: MediaType.video,
            url: url,
            aspectRatio: 1.0,
          ));
          mediaIndex++;
        }
      }
    }
    
    return InstagramPostModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorProfileImageUrl: data['authorProfileImageUrl'] ?? data['authorAvatarUrl'],
      authorVerificationBadge: data['authorVerificationBadge'],
      caption: data['caption'] ?? data['content'] ?? '',
      mediaItems: mediaItems,
      hashtags: List<String>.from(data['hashtags'] ?? []),
      userTags: (data['userTags'] as List<dynamic>?)
          ?.map((tag) => UserTag.fromMap(tag as Map<String, dynamic>))
          .toList() ?? [],
      locationTag: data['locationTag'] != null 
          ? LocationTag.fromMap(data['locationTag'] as Map<String, dynamic>)
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      viewsCount: data['viewsCount'] ?? 0,
      isLikedByCurrentUser: false, // Set separately
      isBookmarkedByCurrentUser: false, // Set separately
      allowComments: data['allowComments'] ?? true,
      allowSharing: data['allowSharing'] ?? true,
      visibility: PostVisibilityExtension.fromString(data['visibility'] ?? 'public'),
      mentionedUserIds: List<String>.from(data['mentionedUserIds'] ?? []),
      altText: data['altText'],
      analytics: data['analytics'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImageUrl': authorProfileImageUrl,
      'authorVerificationBadge': authorVerificationBadge,
      'caption': caption,
      'mediaItems': mediaItems.map((item) => item.toMap()).toList(),
      'hashtags': hashtags,
      'userTags': userTags.map((tag) => tag.toMap()).toList(),
      'locationTag': locationTag?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'viewsCount': viewsCount,
      'allowComments': allowComments,
      'allowSharing': allowSharing,
      'visibility': visibility.value,
      'mentionedUserIds': mentionedUserIds,
      'altText': altText,
      'analytics': analytics,
    };
  }

  InstagramPostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorProfileImageUrl,
    String? authorVerificationBadge,
    String? caption,
    List<MediaItem>? mediaItems,
    List<String>? hashtags,
    List<UserTag>? userTags,
    LocationTag? locationTag,
    DateTime? createdAt,
    DateTime? editedAt,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? viewsCount,
    bool? isLikedByCurrentUser,
    bool? isBookmarkedByCurrentUser,
    bool? allowComments,
    bool? allowSharing,
    PostVisibility? visibility,
    List<String>? mentionedUserIds,
    String? altText,
    Map<String, dynamic>? analytics,
  }) {
    return InstagramPostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImageUrl: authorProfileImageUrl ?? this.authorProfileImageUrl,
      authorVerificationBadge: authorVerificationBadge ?? this.authorVerificationBadge,
      caption: caption ?? this.caption,
      mediaItems: mediaItems ?? this.mediaItems,
      hashtags: hashtags ?? this.hashtags,
      userTags: userTags ?? this.userTags,
      locationTag: locationTag ?? this.locationTag,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isBookmarkedByCurrentUser: isBookmarkedByCurrentUser ?? this.isBookmarkedByCurrentUser,
      allowComments: allowComments ?? this.allowComments,
      allowSharing: allowSharing ?? this.allowSharing,
      visibility: visibility ?? this.visibility,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      altText: altText ?? this.altText,
      analytics: analytics ?? this.analytics,
    );
  }

  // Convenience getters
  bool get hasMedia => mediaItems.isNotEmpty;
  bool get hasImages => mediaItems.any((item) => item.type == MediaType.image);
  bool get hasVideos => mediaItems.any((item) => item.type == MediaType.video);
  bool get isMultipleMedia => mediaItems.length > 1;
  bool get hasLocation => locationTag != null;
  bool get hasUserTags => userTags.isNotEmpty;
  bool get isEdited => editedAt != null;
  
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
    return other is InstagramPostModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Media item model for posts
class MediaItem {
  final String id;
  final MediaType type;
  final String url;
  final String? thumbnailUrl;
  final String? altText;
  final double? aspectRatio;
  final int? width;
  final int? height;
  final int? duration; // For videos in seconds
  final Map<String, dynamic>? metadata;

  MediaItem({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.altText,
    this.aspectRatio,
    this.width,
    this.height,
    this.duration,
    this.metadata,
  });

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] ?? '',
      type: MediaTypeExtension.fromString(map['type'] ?? 'image'),
      url: map['url'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      altText: map['altText'],
      aspectRatio: map['aspectRatio']?.toDouble(),
      width: map['width']?.toInt(),
      height: map['height']?.toInt(),
      duration: map['duration']?.toInt(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'altText': altText,
      'aspectRatio': aspectRatio,
      'width': width,
      'height': height,
      'duration': duration,
      'metadata': metadata,
    };
  }
}

// User tag model for tagging users in posts
class UserTag {
  final String userId;
  final String username;
  final double x; // Position on image (0.0 to 1.0)
  final double y; // Position on image (0.0 to 1.0)

  UserTag({
    required this.userId,
    required this.username,
    required this.x,
    required this.y,
  });

  factory UserTag.fromMap(Map<String, dynamic> map) {
    return UserTag(
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      x: map['x']?.toDouble() ?? 0.0,
      y: map['y']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'x': x,
      'y': y,
    };
  }
}

// Location tag model
class LocationTag {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? country;

  LocationTag({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.country,
  });

  factory LocationTag.fromMap(Map<String, dynamic> map) {
    return LocationTag(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      address: map['address'],
      city: map['city'],
      country: map['country'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'country': country,
    };
  }
}

// Media type enum
enum MediaType {
  image,
  video,
}

extension MediaTypeExtension on MediaType {
  String get value {
    switch (this) {
      case MediaType.image:
        return 'image';
      case MediaType.video:
        return 'video';
    }
  }

  static MediaType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return MediaType.video;
      default:
        return MediaType.image;
    }
  }
}

// Post visibility enum
enum PostVisibility {
  public,
  private,
  friends,
  closeFriends,
}

extension PostVisibilityExtension on PostVisibility {
  String get value {
    switch (this) {
      case PostVisibility.public:
        return 'public';
      case PostVisibility.private:
        return 'private';
      case PostVisibility.friends:
        return 'friends';
      case PostVisibility.closeFriends:
        return 'close_friends';
    }
  }

  static PostVisibility fromString(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'private':
        return PostVisibility.private;
      case 'friends':
        return PostVisibility.friends;
      case 'close_friends':
        return PostVisibility.closeFriends;
      default:
        return PostVisibility.public;
    }
  }
}