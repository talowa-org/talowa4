// Story Model for TALOWA Social Feed
// 24-hour temporary stories feature
import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? caption;
  final int duration; // For videos in seconds
  final DateTime createdAt;
  final DateTime expiresAt;
  final int views;
  final Map<String, String> reactions; // userId -> reaction emoji
  final bool isActive;

  StoryModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    this.duration = 5, // Default 5 seconds for images
    required this.createdAt,
    required this.expiresAt,
    required this.views,
    required this.reactions,
    required this.isActive,
  });

  // Convert from Firestore document
  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return StoryModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorRole: data['authorRole'] ?? 'member',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      caption: data['caption'],
      duration: data['duration'] ?? 5,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 24)),
      views: data['views'] ?? 0,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      isActive: data['isActive'] ?? true,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'caption': caption,
      'duration': duration,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'views': views,
      'reactions': reactions,
      'isActive': isActive,
    };
  }

  // Copy with method for updates
  StoryModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? mediaUrl,
    String? mediaType,
    String? caption,
    int? duration,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? views,
    Map<String, String>? reactions,
    bool? isActive,
  }) {
    return StoryModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      views: views ?? this.views,
      reactions: reactions ?? this.reactions,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'StoryModel(id: $id, authorName: $authorName, mediaType: $mediaType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}