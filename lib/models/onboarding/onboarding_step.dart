// TALOWA Onboarding Step Model
// Represents a single step in the onboarding tutorial

import 'package:flutter/material.dart';

class OnboardingStep {
  final String id;
  final String title;
  final String description;
  final String content;
  final IconData iconData;
  final String actionText;
  final bool isInteractive;
  final String? imageAsset;
  final String? videoUrl;
  final List<String>? bulletPoints;
  final Color? accentColor;

  const OnboardingStep({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.iconData,
    required this.actionText,
    this.isInteractive = false,
    this.imageAsset,
    this.videoUrl,
    this.bulletPoints,
    this.accentColor,
  });

  OnboardingStep copyWith({
    String? id,
    String? title,
    String? description,
    String? content,
    IconData? iconData,
    String? actionText,
    bool? isInteractive,
    String? imageAsset,
    String? videoUrl,
    List<String>? bulletPoints,
    Color? accentColor,
  }) {
    return OnboardingStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      iconData: iconData ?? this.iconData,
      actionText: actionText ?? this.actionText,
      isInteractive: isInteractive ?? this.isInteractive,
      imageAsset: imageAsset ?? this.imageAsset,
      videoUrl: videoUrl ?? this.videoUrl,
      bulletPoints: bulletPoints ?? this.bulletPoints,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'iconData': iconData.codePoint,
      'actionText': actionText,
      'isInteractive': isInteractive,
      'imageAsset': imageAsset,
      'videoUrl': videoUrl,
      'bulletPoints': bulletPoints,
    };
  }

  factory OnboardingStep.fromJson(Map<String, dynamic> json) {
    return OnboardingStep(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      content: json['content'] as String,
      iconData: const IconData(0xe88a, fontFamily: 'MaterialIcons'), // Default to info icon
      actionText: json['actionText'] as String,
      isInteractive: json['isInteractive'] as bool? ?? false,
      imageAsset: json['imageAsset'] as String?,
      videoUrl: json['videoUrl'] as String?,
      bulletPoints: (json['bulletPoints'] as List<dynamic>?)?.cast<String>(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnboardingStep && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'OnboardingStep(id: $id, title: $title, isInteractive: $isInteractive)';
  }
}