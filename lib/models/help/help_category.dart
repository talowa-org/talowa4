// TALOWA Help Category Model
// Represents a category of help articles

import 'package:flutter/material.dart';
import 'help_article.dart';

class HelpCategory {
  final String id;
  final String title;
  final String description;
  final IconData iconData;
  final List<HelpArticle> articles;
  final Color? accentColor;
  final int sortOrder;

  const HelpCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.iconData,
    required this.articles,
    this.accentColor,
    this.sortOrder = 0,
  });

  HelpCategory copyWith({
    String? id,
    String? title,
    String? description,
    IconData? iconData,
    List<HelpArticle>? articles,
    Color? accentColor,
    int? sortOrder,
  }) {
    return HelpCategory(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconData: iconData ?? this.iconData,
      articles: articles ?? this.articles,
      accentColor: accentColor ?? this.accentColor,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Get articles count
  int get articleCount => articles.length;

  /// Get FAQ articles in this category
  List<HelpArticle> get faqArticles => articles.where((article) => article.isFAQ).toList();

  /// Get articles relevant for a specific user role
  List<HelpArticle> getArticlesForRole(String userRole) {
    return articles.where((article) => article.isRelevantForRole(userRole)).toList();
  }

  /// Get contextual articles for a specific screen
  List<HelpArticle> getContextualArticles(String screenName) {
    return articles.where((article) => article.isContextualForScreen(screenName)).toList();
  }

  /// Check if category has any articles
  bool get hasArticles => articles.isNotEmpty;

  /// Get estimated total read time for all articles
  int get totalReadTime => articles.fold(0, (sum, article) => sum + article.estimatedReadTime);

  /// Get formatted total read time
  String get totalReadTimeText {
    if (totalReadTime <= 1) return '1 min total';
    return '$totalReadTime min total';
  }

  /// Create empty category (for error handling)
  factory HelpCategory.empty() {
    return const HelpCategory(
      id: '',
      title: 'Unknown Category',
      description: '',
      iconData: Icons.help,
      articles: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconData': iconData.codePoint,
      'articles': articles.map((article) => article.toJson()).toList(),
      'sortOrder': sortOrder,
    };
  }

  factory HelpCategory.fromJson(Map<String, dynamic> json) {
    return HelpCategory(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      iconData: Icons.help, // Use constant icon
      articles: (json['articles'] as List<dynamic>)
          .map((articleJson) => HelpArticle.fromJson(articleJson as Map<String, dynamic>))
          .toList(),
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HelpCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'HelpCategory(id: $id, title: $title, articles: ${articles.length})';
  }
}