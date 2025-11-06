// Content Warning Model for TALOWA Safety System
// Comprehensive content moderation and warning system
import 'package:flutter/material.dart';

enum ContentWarningType {
  explicitContent,
  violentContent,
  sensitiveContent,
  misinformation,
  spam,
  harassment,
  adultContent,
  graphicContent,
  politicalContent,
  religiousContent,
}

extension ContentWarningTypeExtension on ContentWarningType {
  String get value {
    switch (this) {
      case ContentWarningType.explicitContent:
        return 'explicit_content';
      case ContentWarningType.violentContent:
        return 'violent_content';
      case ContentWarningType.sensitiveContent:
        return 'sensitive_content';
      case ContentWarningType.misinformation:
        return 'misinformation';
      case ContentWarningType.spam:
        return 'spam';
      case ContentWarningType.harassment:
        return 'harassment';
      case ContentWarningType.adultContent:
        return 'adult_content';
      case ContentWarningType.graphicContent:
        return 'graphic_content';
      case ContentWarningType.politicalContent:
        return 'political_content';
      case ContentWarningType.religiousContent:
        return 'religious_content';
    }
  }

  String get displayName {
    switch (this) {
      case ContentWarningType.explicitContent:
        return 'Explicit Content';
      case ContentWarningType.violentContent:
        return 'Violent Content';
      case ContentWarningType.sensitiveContent:
        return 'Sensitive Content';
      case ContentWarningType.misinformation:
        return 'Misinformation';
      case ContentWarningType.spam:
        return 'Spam';
      case ContentWarningType.harassment:
        return 'Harassment';
      case ContentWarningType.adultContent:
        return 'Adult Content';
      case ContentWarningType.graphicContent:
        return 'Graphic Content';
      case ContentWarningType.politicalContent:
        return 'Political Content';
      case ContentWarningType.religiousContent:
        return 'Religious Content';
    }
  }

  String get description {
    switch (this) {
      case ContentWarningType.explicitContent:
        return 'Contains explicit language or imagery';
      case ContentWarningType.violentContent:
        return 'Contains violent or disturbing content';
      case ContentWarningType.sensitiveContent:
        return 'May contain sensitive material';
      case ContentWarningType.misinformation:
        return 'May contain false or misleading information';
      case ContentWarningType.spam:
        return 'Identified as spam or promotional content';
      case ContentWarningType.harassment:
        return 'Contains harassment or bullying';
      case ContentWarningType.adultContent:
        return 'Contains adult or mature content';
      case ContentWarningType.graphicContent:
        return 'Contains graphic or disturbing imagery';
      case ContentWarningType.politicalContent:
        return 'Contains political content';
      case ContentWarningType.religiousContent:
        return 'Contains religious content';
    }
  }

  IconData get icon {
    switch (this) {
      case ContentWarningType.explicitContent:
        return Icons.explicit;
      case ContentWarningType.violentContent:
        return Icons.warning;
      case ContentWarningType.sensitiveContent:
        return Icons.visibility_off;
      case ContentWarningType.misinformation:
        return Icons.fact_check;
      case ContentWarningType.spam:
        return Icons.block;
      case ContentWarningType.harassment:
        return Icons.report;
      case ContentWarningType.adultContent:
        return Icons.eighteen_up_rating;
      case ContentWarningType.graphicContent:
        return Icons.warning_amber;
      case ContentWarningType.politicalContent:
        return Icons.how_to_vote;
      case ContentWarningType.religiousContent:
        return Icons.church;
    }
  }

  Color get color {
    switch (this) {
      case ContentWarningType.explicitContent:
        return Colors.red;
      case ContentWarningType.violentContent:
        return Colors.red.shade700;
      case ContentWarningType.sensitiveContent:
        return Colors.orange;
      case ContentWarningType.misinformation:
        return Colors.amber;
      case ContentWarningType.spam:
        return Colors.grey;
      case ContentWarningType.harassment:
        return Colors.red.shade800;
      case ContentWarningType.adultContent:
        return Colors.purple;
      case ContentWarningType.graphicContent:
        return Colors.red.shade900;
      case ContentWarningType.politicalContent:
        return Colors.blue;
      case ContentWarningType.religiousContent:
        return Colors.indigo;
    }
  }

  static ContentWarningType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'explicit_content':
        return ContentWarningType.explicitContent;
      case 'violent_content':
        return ContentWarningType.violentContent;
      case 'sensitive_content':
        return ContentWarningType.sensitiveContent;
      case 'misinformation':
        return ContentWarningType.misinformation;
      case 'spam':
        return ContentWarningType.spam;
      case 'harassment':
        return ContentWarningType.harassment;
      case 'adult_content':
        return ContentWarningType.adultContent;
      case 'graphic_content':
        return ContentWarningType.graphicContent;
      case 'political_content':
        return ContentWarningType.politicalContent;
      case 'religious_content':
        return ContentWarningType.religiousContent;
      default:
        return ContentWarningType.sensitiveContent;
    }
  }
}

// Content warning model
class ContentWarning {
  final String id;
  final ContentWarningType type;
  final String reason;
  final String? description;
  final DateTime createdAt;
  final String reportedBy;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  ContentWarning({
    required this.id,
    required this.type,
    required this.reason,
    this.description,
    required this.createdAt,
    required this.reportedBy,
    this.isActive = true,
    this.metadata,
  });

  factory ContentWarning.fromMap(Map<String, dynamic> data) {
    return ContentWarning(
      id: data['id'] ?? '',
      type: ContentWarningTypeExtension.fromString(data['type'] ?? 'sensitive_content'),
      reason: data['reason'] ?? '',
      description: data['description'],
      createdAt: DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      reportedBy: data['reportedBy'] ?? '',
      isActive: data['isActive'] ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'reason': reason,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'reportedBy': reportedBy,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  ContentWarning copyWith({
    String? id,
    ContentWarningType? type,
    String? reason,
    String? description,
    DateTime? createdAt,
    String? reportedBy,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return ContentWarning(
      id: id ?? this.id,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      reportedBy: reportedBy ?? this.reportedBy,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentWarning && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}