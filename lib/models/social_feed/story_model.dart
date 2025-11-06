// Story Model for TALOWA Social Feed Stories
// Instagram-like stories functionality
import 'package:cloud_firestore/cloud_firestore.dart';

// Main Story Model (alias for backward compatibility)
typedef StoryModel = FeedStory;

// Story Privacy enum
enum StoryPrivacy {
  public,
  friends,
  close,
  closeFriends,
  private,
}

extension StoryPrivacyExtension on StoryPrivacy {
  String get value {
    switch (this) {
      case StoryPrivacy.public:
        return 'public';
      case StoryPrivacy.friends:
        return 'friends';
      case StoryPrivacy.close:
        return 'close';
      case StoryPrivacy.closeFriends:
        return 'closeFriends';
      case StoryPrivacy.private:
        return 'private';
    }
  }

  static StoryPrivacy fromString(String privacy) {
    switch (privacy.toLowerCase()) {
      case 'friends':
        return StoryPrivacy.friends;
      case 'close':
        return StoryPrivacy.close;
      case 'closefriends':
      case 'closeFriends':
        return StoryPrivacy.closeFriends;
      case 'private':
        return StoryPrivacy.private;
      default:
        return StoryPrivacy.public;
    }
  }
}

// Story Item Type enum
enum StoryItemType {
  image,
  video,
  text,
}

extension StoryItemTypeExtension on StoryItemType {
  String get value {
    switch (this) {
      case StoryItemType.image:
        return 'image';
      case StoryItemType.video:
        return 'video';
      case StoryItemType.text:
        return 'text';
    }
  }

  static StoryItemType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return StoryItemType.video;
      case 'text':
        return StoryItemType.text;
      default:
        return StoryItemType.image;
    }
  }
}

// Story Item model
class StoryItem {
  final String id;
  final StoryItemType type;
  final String content; // URL for media, text for text stories
  final String? caption;
  final int duration;
  final DateTime timestamp;

  StoryItem({
    required this.id,
    required this.type,
    required this.content,
    this.caption,
    this.duration = 5,
    required this.timestamp,
  });

  factory StoryItem.fromMap(Map<String, dynamic> data) {
    return StoryItem(
      id: data['id'] ?? '',
      type: StoryItemTypeExtension.fromString(data['type'] ?? 'image'),
      content: data['content'] ?? '',
      caption: data['caption'],
      duration: data['duration'] ?? 5,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'content': content,
      'caption': caption,
      'duration': duration,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class FeedStory {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String? authorAvatarUrl;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int duration; // Duration in seconds for video stories
  final int views;
  final List<String> viewedBy;
  final Map<String, StoryReaction> reactions;
  final bool isActive;
  final bool isHighlighted;
  final String? highlightTitle;
  final StoryPrivacy privacy;
  final List<String> allowedViewerIds;
  final bool isViewedByCurrentUser;

  FeedStory({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.duration = 5,
    this.views = 0,
    this.viewedBy = const [],
    this.reactions = const {},
    this.isActive = true,
    this.isHighlighted = false,
    this.highlightTitle,
    this.privacy = StoryPrivacy.public,
    this.allowedViewerIds = const [],
    this.isViewedByCurrentUser = false,
  });

  factory FeedStory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FeedStory(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorRole: data['authorRole'],
      authorAvatarUrl: data['authorAvatarUrl'],
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: StoryMediaTypeExtension.fromString(data['mediaType'] ?? 'image'),
      caption: data['caption'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 24)),
      duration: data['duration'] ?? 5,
      views: data['views'] ?? 0,
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
      reactions: Map<String, StoryReaction>.from(
        (data['reactions'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, StoryReaction.fromMap(value)),
        ) ?? {},
      ),
      isActive: data['isActive'] ?? true,
      isHighlighted: data['isHighlighted'] ?? false,
      highlightTitle: data['highlightTitle'],
      privacy: StoryPrivacyExtension.fromString(data['privacy'] ?? 'public'),
      allowedViewerIds: List<String>.from(data['allowedViewerIds'] ?? []),
      isViewedByCurrentUser: data['isViewedByCurrentUser'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'authorAvatarUrl': authorAvatarUrl,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.value,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'duration': duration,
      'views': views,
      'viewedBy': viewedBy,
      'reactions': reactions.map((key, value) => MapEntry(key, value.toMap())),
      'isActive': isActive,
      'isHighlighted': isHighlighted,
      'highlightTitle': highlightTitle,
      'privacy': privacy.value,
      'allowedViewerIds': allowedViewerIds,
      'isViewedByCurrentUser': isViewedByCurrentUser,
    };
  }

  FeedStory copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? authorAvatarUrl,
    String? mediaUrl,
    StoryMediaType? mediaType,
    String? caption,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? duration,
    int? views,
    List<String>? viewedBy,
    Map<String, StoryReaction>? reactions,
    bool? isActive,
    bool? isHighlighted,
    String? highlightTitle,
    StoryPrivacy? privacy,
    List<String>? allowedViewerIds,
    bool? isViewedByCurrentUser,
  }) {
    return FeedStory(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      duration: duration ?? this.duration,
      views: views ?? this.views,
      viewedBy: viewedBy ?? this.viewedBy,
      reactions: reactions ?? this.reactions,
      isActive: isActive ?? this.isActive,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      highlightTitle: highlightTitle ?? this.highlightTitle,
      privacy: privacy ?? this.privacy,
      allowedViewerIds: allowedViewerIds ?? this.allowedViewerIds,
      isViewedByCurrentUser: isViewedByCurrentUser ?? this.isViewedByCurrentUser,
    );
  }

  // Convenience getters
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get hasCaption => caption != null && caption!.isNotEmpty;
  bool get hasReactions => reactions.isNotEmpty;
  bool get isVideo => mediaType == StoryMediaType.video;
  bool get isImage => mediaType == StoryMediaType.image;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedStory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Story media type enum
enum StoryMediaType {
  image,
  video,
}

extension StoryMediaTypeExtension on StoryMediaType {
  String get value {
    switch (this) {
      case StoryMediaType.image:
        return 'image';
      case StoryMediaType.video:
        return 'video';
    }
  }

  static StoryMediaType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return StoryMediaType.video;
      default:
        return StoryMediaType.image;
    }
  }
}

// Story reaction model
class StoryReaction {
  final String userId;
  final String userName;
  final String reaction; // emoji or reaction type
  final DateTime timestamp;

  StoryReaction({
    required this.userId,
    required this.userName,
    required this.reaction,
    required this.timestamp,
  });

  factory StoryReaction.fromMap(Map<String, dynamic> data) {
    return StoryReaction(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      reaction: data['reaction'] ?? '❤️',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'reaction': reaction,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}