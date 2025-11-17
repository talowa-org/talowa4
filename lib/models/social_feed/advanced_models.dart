// Advanced Social Feed Models for TALOWA
// Core models for enterprise-grade social feed system

import 'package:cloud_firestore/cloud_firestore.dart';
import 'geographic_targeting.dart';

/// Diverse reaction types for enhanced user engagement
enum ReactionType {
  like,
  love,
  laugh,
  wow,
  sad,
  angry,
  celebrate,
  support,
  insightful,
  helpful,
  inspiring,
  concerned,
  grateful,
  proud,
  curious,
  disagree,
  agree,
  thinking,
  fire,
  heart,
}

extension ReactionTypeExtension on ReactionType {
  String get value {
    switch (this) {
      case ReactionType.like:
        return 'like';
      case ReactionType.love:
        return 'love';
      case ReactionType.laugh:
        return 'laugh';
      case ReactionType.wow:
        return 'wow';
      case ReactionType.sad:
        return 'sad';
      case ReactionType.angry:
        return 'angry';
      case ReactionType.celebrate:
        return 'celebrate';
      case ReactionType.support:
        return 'support';
      case ReactionType.insightful:
        return 'insightful';
      case ReactionType.helpful:
        return 'helpful';
      case ReactionType.inspiring:
        return 'inspiring';
      case ReactionType.concerned:
        return 'concerned';
      case ReactionType.grateful:
        return 'grateful';
      case ReactionType.proud:
        return 'proud';
      case ReactionType.curious:
        return 'curious';
      case ReactionType.disagree:
        return 'disagree';
      case ReactionType.agree:
        return 'agree';
      case ReactionType.thinking:
        return 'thinking';
      case ReactionType.fire:
        return 'fire';
      case ReactionType.heart:
        return 'heart';
    }
  }

  String get emoji {
    switch (this) {
      case ReactionType.like:
        return '👍';
      case ReactionType.love:
        return '❤️';
      case ReactionType.laugh:
        return '😂';
      case ReactionType.wow:
        return '😮';
      case ReactionType.sad:
        return '😢';
      case ReactionType.angry:
        return '😠';
      case ReactionType.celebrate:
        return '🎉';
      case ReactionType.support:
        return '🤝';
      case ReactionType.insightful:
        return '💡';
      case ReactionType.helpful:
        return '🙏';
      case ReactionType.inspiring:
        return '✨';
      case ReactionType.concerned:
        return '😟';
      case ReactionType.grateful:
        return '🙏';
      case ReactionType.proud:
        return '💪';
      case ReactionType.curious:
        return '🤔';
      case ReactionType.disagree:
        return '👎';
      case ReactionType.agree:
        return '✅';
      case ReactionType.thinking:
        return '🤔';
      case ReactionType.fire:
        return '🔥';
      case ReactionType.heart:
        return '💖';
    }
  }

  static ReactionType fromString(String reaction) {
    switch (reaction.toLowerCase()) {
      case 'like':
        return ReactionType.like;
      case 'love':
        return ReactionType.love;
      case 'laugh':
        return ReactionType.laugh;
      case 'wow':
        return ReactionType.wow;
      case 'sad':
        return ReactionType.sad;
      case 'angry':
        return ReactionType.angry;
      case 'celebrate':
        return ReactionType.celebrate;
      case 'support':
        return ReactionType.support;
      case 'insightful':
        return ReactionType.insightful;
      case 'helpful':
        return ReactionType.helpful;
      case 'inspiring':
        return ReactionType.inspiring;
      case 'concerned':
        return ReactionType.concerned;
      case 'grateful':
        return ReactionType.grateful;
      case 'proud':
        return ReactionType.proud;
      case 'curious':
        return ReactionType.curious;
      case 'disagree':
        return ReactionType.disagree;
      case 'agree':
        return ReactionType.agree;
      case 'thinking':
        return ReactionType.thinking;
      case 'fire':
        return ReactionType.fire;
      case 'heart':
        return ReactionType.heart;
      default:
        return ReactionType.like;
    }
  }
}

/// Media types for multimedia content
enum MediaType {
  image,
  video,
  audio,
  document,
  gif,
  sticker,
}

extension MediaTypeExtension on MediaType {
  String get value {
    switch (this) {
      case MediaType.image:
        return 'image';
      case MediaType.video:
        return 'video';
      case MediaType.audio:
        return 'audio';
      case MediaType.document:
        return 'document';
      case MediaType.gif:
        return 'gif';
      case MediaType.sticker:
        return 'sticker';
    }
  }

  static MediaType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return MediaType.image;
      case 'video':
        return MediaType.video;
      case 'audio':
        return MediaType.audio;
      case 'document':
        return MediaType.document;
      case 'gif':
        return MediaType.gif;
      case 'sticker':
        return MediaType.sticker;
      default:
        return MediaType.image;
    }
  }
}

/// Media processing status
enum MediaProcessingStatus {
  pending,
  processing,
  completed,
  failed,
}

extension MediaProcessingStatusExtension on MediaProcessingStatus {
  String get value {
    switch (this) {
      case MediaProcessingStatus.pending:
        return 'pending';
      case MediaProcessingStatus.processing:
        return 'processing';
      case MediaProcessingStatus.completed:
        return 'completed';
      case MediaProcessingStatus.failed:
        return 'failed';
    }
  }

  static MediaProcessingStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return MediaProcessingStatus.pending;
      case 'processing':
        return MediaProcessingStatus.processing;
      case 'completed':
        return MediaProcessingStatus.completed;
      case 'failed':
        return MediaProcessingStatus.failed;
      default:
        return MediaProcessingStatus.pending;
    }
  }
}

/// Moderation status for content safety
enum ModerationStatus {
  pending,
  approved,
  rejected,
  flagged,
}

extension ModerationStatusExtension on ModerationStatus {
  String get value {
    switch (this) {
      case ModerationStatus.pending:
        return 'pending';
      case ModerationStatus.approved:
        return 'approved';
      case ModerationStatus.rejected:
        return 'rejected';
      case ModerationStatus.flagged:
        return 'flagged';
    }
  }

  bool get isVisible {
    return this == ModerationStatus.approved;
  }

  static ModerationStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ModerationStatus.pending;
      case 'approved':
        return ModerationStatus.approved;
      case 'rejected':
        return ModerationStatus.rejected;
      case 'flagged':
        return ModerationStatus.flagged;
      default:
        return ModerationStatus.pending;
    }
  }
}

/// Content sentiment for AI analysis
enum ContentSentiment {
  positive,
  negative,
  neutral,
  mixed,
}

extension ContentSentimentExtension on ContentSentiment {
  String get value {
    switch (this) {
      case ContentSentiment.positive:
        return 'positive';
      case ContentSentiment.negative:
        return 'negative';
      case ContentSentiment.neutral:
        return 'neutral';
      case ContentSentiment.mixed:
        return 'mixed';
    }
  }

  static ContentSentiment fromString(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return ContentSentiment.positive;
      case 'negative':
        return ContentSentiment.negative;
      case 'neutral':
        return ContentSentiment.neutral;
      case 'mixed':
        return ContentSentiment.mixed;
      default:
        return ContentSentiment.neutral;
    }
  }
}

/// Content warning types
enum ContentWarning {
  violence,
  adultContent,
  sensitiveTopics,
  spam,
}

extension ContentWarningExtension on ContentWarning {
  String get value {
    switch (this) {
      case ContentWarning.violence:
        return 'violence';
      case ContentWarning.adultContent:
        return 'adultContent';
      case ContentWarning.sensitiveTopics:
        return 'sensitiveTopics';
      case ContentWarning.spam:
        return 'spam';
    }
  }

  static ContentWarning fromString(String warning) {
    switch (warning.toLowerCase()) {
      case 'violence':
        return ContentWarning.violence;
      case 'adultcontent':
        return ContentWarning.adultContent;
      case 'sensitivetopics':
        return ContentWarning.sensitiveTopics;
      case 'spam':
        return ContentWarning.spam;
      default:
        return ContentWarning.sensitiveTopics;
    }
  }
}

/// Collaborator roles
enum CollaboratorRole {
  owner,
  editor,
  reviewer,
  viewer,
}

extension CollaboratorRoleExtension on CollaboratorRole {
  String get value {
    switch (this) {
      case CollaboratorRole.owner:
        return 'owner';
      case CollaboratorRole.editor:
        return 'editor';
      case CollaboratorRole.reviewer:
        return 'reviewer';
      case CollaboratorRole.viewer:
        return 'viewer';
    }
  }

  static CollaboratorRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return CollaboratorRole.owner;
      case 'editor':
        return CollaboratorRole.editor;
      case 'reviewer':
        return CollaboratorRole.reviewer;
      case 'viewer':
        return CollaboratorRole.viewer;
      default:
        return CollaboratorRole.viewer;
    }
  }
}

/// Media Asset model
class MediaAsset {
  final String id;
  final MediaType type;
  final String url;
  final String? thumbnailUrl;
  final Map<String, String> qualityUrls;
  final int? duration;
  final int? fileSize;
  final String? altText;
  final MediaProcessingStatus processingStatus;

  const MediaAsset({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.qualityUrls = const {},
    this.duration,
    this.fileSize,
    this.altText,
    this.processingStatus = MediaProcessingStatus.pending,
  });

  factory MediaAsset.fromMap(Map<String, dynamic> data) {
    return MediaAsset(
      id: data['id'] ?? '',
      type: MediaTypeExtension.fromString(data['type'] ?? 'image'),
      url: data['url'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      qualityUrls: Map<String, String>.from(data['qualityUrls'] ?? {}),
      duration: data['duration'],
      fileSize: data['fileSize'],
      altText: data['altText'],
      processingStatus: MediaProcessingStatusExtension.fromString(data['processingStatus'] ?? 'pending'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'qualityUrls': qualityUrls,
      'duration': duration,
      'fileSize': fileSize,
      'altText': altText,
      'processingStatus': processingStatus.value,
    };
  }
}

/// Collaborator model
class Collaborator {
  final String userId;
  final String name;
  final String? avatarUrl;
  final CollaboratorRole role;
  final DateTime joinedAt;
  final bool isActive;

  const Collaborator({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.isActive = true,
  });

  factory Collaborator.fromMap(Map<String, dynamic> data) {
    return Collaborator(
      userId: data['userId'] ?? '',
      name: data['name'] ?? 'Unknown User',
      avatarUrl: data['avatarUrl'],
      role: CollaboratorRoleExtension.fromString(data['role'] ?? 'viewer'),
      joinedAt: data['joinedAt'] is Timestamp 
          ? (data['joinedAt'] as Timestamp).toDate()
          : DateTime.parse(data['joinedAt'] ?? DateTime.now().toIso8601String()),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'avatarUrl': avatarUrl,
      'role': role.value,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
    };
  }
}

/// Content version for version control
class ContentVersion {
  final String id;
  final String postId;
  final int versionNumber;
  final String content;
  final String authorId;
  final DateTime createdAt;

  const ContentVersion({
    required this.id,
    required this.postId,
    required this.versionNumber,
    required this.content,
    required this.authorId,
    required this.createdAt,
  });

  factory ContentVersion.fromMap(Map<String, dynamic> data) {
    return ContentVersion(
      id: data['id'] ?? '',
      postId: data['postId'] ?? '',
      versionNumber: data['versionNumber'] ?? 1,
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'versionNumber': versionNumber,
      'content': content,
      'authorId': authorId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Privacy settings
class PrivacySettings {
  final String visibility;
  final bool allowComments;
  final bool allowShares;
  final bool allowReactions;

  const PrivacySettings({
    this.visibility = 'public',
    this.allowComments = true,
    this.allowShares = true,
    this.allowReactions = true,
  });

  factory PrivacySettings.fromMap(Map<String, dynamic> data) {
    return PrivacySettings(
      visibility: data['visibility'] ?? 'public',
      allowComments: data['allowComments'] ?? true,
      allowShares: data['allowShares'] ?? true,
      allowReactions: data['allowReactions'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'visibility': visibility,
      'allowComments': allowComments,
      'allowShares': allowShares,
      'allowReactions': allowReactions,
    };
  }
}

/// Access Control List
class AccessControlList {
  final List<String> allowedUsers;
  final List<String> blockedUsers;

  const AccessControlList({
    this.allowedUsers = const [],
    this.blockedUsers = const [],
  });

  factory AccessControlList.fromMap(Map<String, dynamic> data) {
    return AccessControlList(
      allowedUsers: List<String>.from(data['allowedUsers'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allowedUsers': allowedUsers,
      'blockedUsers': blockedUsers,
    };
  }
}

/// Advanced Post Model with comprehensive features
class AdvancedPostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String? authorAvatarUrl;
  final String? title;
  final String content;
  final List<MediaAsset> mediaAssets;
  final List<String> hashtags;
  final String category;
  final GeographicTargeting? targeting;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Advanced engagement data
  final Map<ReactionType, int> reactions;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final double engagementRate;
  
  // Collaborative features
  final List<Collaborator> collaborators;
  final bool isCollaborative;
  final List<ContentVersion> versions;
  
  // AI and analytics
  final List<String> aiGeneratedTags;
  final double aiEngagementPrediction;
  final ContentSentiment sentiment;
  
  // Moderation and safety
  final ModerationStatus moderationStatus;
  final double toxicityScore;
  final List<ContentWarning> contentWarnings;
  
  // Privacy and access
  final PrivacySettings privacy;
  final AccessControlList acl;
  
  // Metadata
  final Map<String, dynamic> metadata;

  const AdvancedPostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
    this.title,
    required this.content,
    this.mediaAssets = const [],
    this.hashtags = const [],
    required this.category,
    this.targeting,
    required this.createdAt,
    this.updatedAt,
    this.reactions = const {},
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    this.engagementRate = 0.0,
    this.collaborators = const [],
    this.isCollaborative = false,
    this.versions = const [],
    this.aiGeneratedTags = const [],
    this.aiEngagementPrediction = 0.0,
    this.sentiment = ContentSentiment.neutral,
    this.moderationStatus = ModerationStatus.pending,
    this.toxicityScore = 0.0,
    this.contentWarnings = const [],
    required this.privacy,
    required this.acl,
    this.metadata = const {},
  });

  /// Create from Firestore document
  factory AdvancedPostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AdvancedPostModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorRole: data['authorRole'],
      authorAvatarUrl: data['authorAvatarUrl'],
      title: data['title'],
      content: data['content'] ?? '',
      mediaAssets: (data['mediaAssets'] as List<dynamic>?)
          ?.map((item) => MediaAsset.fromMap(Map<String, dynamic>.from(item)))
          .toList() ?? [],
      hashtags: List<String>.from(data['hashtags'] ?? []),
      category: data['category'] ?? 'generalDiscussion',
      targeting: data['targeting'] != null 
          ? GeographicTargeting.fromMap(Map<String, dynamic>.from(data['targeting']))
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      reactions: Map<ReactionType, int>.from(
        (data['reactions'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(ReactionTypeExtension.fromString(key), value as int)
        ) ?? {}
      ),
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      viewsCount: data['viewsCount'] ?? 0,
      engagementRate: (data['engagementRate'] ?? 0.0).toDouble(),
      collaborators: (data['collaborators'] as List<dynamic>?)
          ?.map((item) => Collaborator.fromMap(Map<String, dynamic>.from(item)))
          .toList() ?? [],
      isCollaborative: data['isCollaborative'] ?? false,
      versions: (data['versions'] as List<dynamic>?)
          ?.map((item) => ContentVersion.fromMap(Map<String, dynamic>.from(item)))
          .toList() ?? [],
      aiGeneratedTags: List<String>.from(data['aiGeneratedTags'] ?? []),
      aiEngagementPrediction: (data['aiEngagementPrediction'] ?? 0.0).toDouble(),
      sentiment: ContentSentimentExtension.fromString(data['sentiment'] ?? 'neutral'),
      moderationStatus: ModerationStatusExtension.fromString(data['moderationStatus'] ?? 'pending'),
      toxicityScore: (data['toxicityScore'] ?? 0.0).toDouble(),
      contentWarnings: (data['contentWarnings'] as List<dynamic>?)
          ?.map((item) => ContentWarningExtension.fromString(item.toString()))
          .toList() ?? [],
      privacy: PrivacySettings.fromMap(Map<String, dynamic>.from(data['privacy'] ?? {})),
      acl: AccessControlList.fromMap(Map<String, dynamic>.from(data['acl'] ?? {})),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'authorAvatarUrl': authorAvatarUrl,
      'title': title,
      'content': content,
      'mediaAssets': mediaAssets.map((asset) => asset.toMap()).toList(),
      'hashtags': hashtags,
      'category': category,
      'targeting': targeting?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'reactions': reactions.map((key, value) => MapEntry(key.value, value)),
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'viewsCount': viewsCount,
      'engagementRate': engagementRate,
      'collaborators': collaborators.map((collab) => collab.toMap()).toList(),
      'isCollaborative': isCollaborative,
      'versions': versions.map((version) => version.toMap()).toList(),
      'aiGeneratedTags': aiGeneratedTags,
      'aiEngagementPrediction': aiEngagementPrediction,
      'sentiment': sentiment.value,
      'moderationStatus': moderationStatus.value,
      'toxicityScore': toxicityScore,
      'contentWarnings': contentWarnings.map((warning) => warning.value).toList(),
      'privacy': privacy.toMap(),
      'acl': acl.toMap(),
      'metadata': metadata,
    };
  }

  /// Convenience methods
  bool get hasMedia => mediaAssets.isNotEmpty;
  bool get hasImages => mediaAssets.any((asset) => asset.type == MediaType.image);
  bool get hasVideos => mediaAssets.any((asset) => asset.type == MediaType.video);
  bool get hasAudio => mediaAssets.any((asset) => asset.type == MediaType.audio);
  bool get hasDocuments => mediaAssets.any((asset) => asset.type == MediaType.document);
  
  int get totalReactions => reactions.values.fold(0, (sum, count) => sum + count);
  int get totalEngagement => totalReactions + commentsCount + sharesCount;
  
  bool get isPublished => moderationStatus == ModerationStatus.approved;
  bool get needsModeration => moderationStatus == ModerationStatus.pending;
  bool get isHighToxicity => toxicityScore > 0.7;
  
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedPostModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AdvancedPostModel(id: $id, authorName: $authorName, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }
}