// TALOWA Help Article Model
// Represents a single help article with content and metadata

import 'package:flutter/material.dart';

class HelpArticle {
  final String id;
  final String title;
  final String content;
  final List<String> steps;
  final List<String> tags;
  final String category;
  final int estimatedReadTime; // in minutes
  final List<String> screenshots;
  final String? videoUrl;
  final List<String> targetRoles; // empty means all roles
  final List<String> contextualScreens; // screens where this help is relevant
  final bool isFAQ;
  final DateTime? lastUpdated;
  final int viewCount;
  final double rating;

  const HelpArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.steps,
    required this.tags,
    required this.category,
    required this.estimatedReadTime,
    this.screenshots = const [],
    this.videoUrl,
    this.targetRoles = const [],
    this.contextualScreens = const [],
    this.isFAQ = false,
    this.lastUpdated,
    this.viewCount = 0,
    this.rating = 0.0,
  });

  HelpArticle copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? steps,
    List<String>? tags,
    String? category,
    int? estimatedReadTime,
    List<String>? screenshots,
    String? videoUrl,
    List<String>? targetRoles,
    List<String>? contextualScreens,
    bool? isFAQ,
    DateTime? lastUpdated,
    int? viewCount,
    double? rating,
  }) {
    return HelpArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      estimatedReadTime: estimatedReadTime ?? this.estimatedReadTime,
      screenshots: screenshots ?? this.screenshots,
      videoUrl: videoUrl ?? this.videoUrl,
      targetRoles: targetRoles ?? this.targetRoles,
      contextualScreens: contextualScreens ?? this.contextualScreens,
      isFAQ: isFAQ ?? this.isFAQ,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      viewCount: viewCount ?? this.viewCount,
      rating: rating ?? this.rating,
    );
  }

  /// Check if this article is relevant for a specific user role
  bool isRelevantForRole(String userRole) {
    return targetRoles.isEmpty || targetRoles.contains(userRole);
  }

  /// Check if this article provides contextual help for a specific screen
  bool isContextualForScreen(String screenName) {
    return contextualScreens.contains(screenName);
  }

  /// Get formatted read time string
  String get readTimeText {
    if (estimatedReadTime <= 1) return '1 min read';
    return '$estimatedReadTime min read';
  }

  /// Check if article has multimedia content
  bool get hasMultimedia => screenshots.isNotEmpty || videoUrl != null;

  /// Get primary screenshot (first one)
  String? get primaryScreenshot => screenshots.isNotEmpty ? screenshots.first : null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'steps': steps,
      'tags': tags,
      'category': category,
      'estimatedReadTime': estimatedReadTime,
      'screenshots': screenshots,
      'videoUrl': videoUrl,
      'targetRoles': targetRoles,
      'contextualScreens': contextualScreens,
      'isFAQ': isFAQ,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'viewCount': viewCount,
      'rating': rating,
    };
  }

  factory HelpArticle.fromJson(Map<String, dynamic> json) {
    return HelpArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      steps: (json['steps'] as List<dynamic>).cast<String>(),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      category: json['category'] as String,
      estimatedReadTime: json['estimatedReadTime'] as int,
      screenshots: (json['screenshots'] as List<dynamic>?)?.cast<String>() ?? [],
      videoUrl: json['videoUrl'] as String?,
      targetRoles: (json['targetRoles'] as List<dynamic>?)?.cast<String>() ?? [],
      contextualScreens: (json['contextualScreens'] as List<dynamic>?)?.cast<String>() ?? [],
      isFAQ: json['isFAQ'] as bool? ?? false,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
      viewCount: json['viewCount'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HelpArticle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'HelpArticle(id: $id, title: $title, category: $category, isFAQ: $isFAQ)';
  }
}