// Story Model for TALOWA
// Instagram-style stories with images and videos

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum StoryMediaType {
  image,
  video,
  text,
}

class StoryModel {
  final String id;
  final String userId;
  final String userName;
  final String? userProfileImage;
  final String? mediaUrl; // Optional for text-only stories
  final StoryMediaType mediaType;
  final String? caption;
  final String? textContent; // For text-only stories
  final Color? backgroundColor; // For text-only stories
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewsCount;
  final bool isViewed; // By current user
  final List<String> viewedBy;

  StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfileImage,
    this.mediaUrl,
    required this.mediaType,
    this.caption,
    this.textContent,
    this.backgroundColor,
    required this.createdAt,
    required this.expiresAt,
    this.viewsCount = 0,
    this.isViewed = false,
    this.viewedBy = const [],
  });

  // Check if story is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // Check if story is active
  bool get isActive => !isExpired;

  // Time remaining until expiration
  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  // Copy with method
  StoryModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userProfileImage,
    String? mediaUrl,
    StoryMediaType? mediaType,
    String? caption,
    String? textContent,
    Color? backgroundColor,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewsCount,
    bool? isViewed,
    List<String>? viewedBy,
  }) {
    return StoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      textContent: textContent ?? this.textContent,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewsCount: viewsCount ?? this.viewsCount,
      isViewed: isViewed ?? this.isViewed,
      viewedBy: viewedBy ?? this.viewedBy,
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.name,
      'caption': caption,
      'textContent': textContent,
      'backgroundColor': backgroundColor?.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewsCount': viewsCount,
      'viewedBy': viewedBy,
    };
  }

  // Create from Firestore
  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return StoryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userProfileImage: data['userProfileImage'],
      mediaUrl: data['mediaUrl'],
      mediaType: StoryMediaType.values.firstWhere(
        (e) => e.name == data['mediaType'],
        orElse: () => StoryMediaType.image,
      ),
      caption: data['caption'],
      textContent: data['textContent'],
      backgroundColor: data['backgroundColor'] != null 
          ? Color(data['backgroundColor'] as int)
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? 
          DateTime.now().add(const Duration(hours: 24)),
      viewsCount: data['viewsCount'] ?? 0,
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
    );
  }
}

// User Stories Group - Groups all stories from one user
class UserStoriesGroup {
  final String userId;
  final String userName;
  final String? userProfileImage;
  final List<StoryModel> stories;
  final bool hasUnviewedStories;

  UserStoriesGroup({
    required this.userId,
    required this.userName,
    this.userProfileImage,
    required this.stories,
    required this.hasUnviewedStories,
  });

  // Get the most recent story for thumbnail
  StoryModel? get latestStory => stories.isNotEmpty ? stories.first : null;

  // Get count of unviewed stories
  int get unviewedCount => stories.where((s) => !s.isViewed).length;

  // Get total stories count
  int get totalCount => stories.length;
}
