// TALOWA Help Search Result Model
// Represents a search result with relevance scoring

import 'help_article.dart';

class HelpSearchResult {
  final HelpArticle article;
  final int relevanceScore;
  final List<String> matchedSections;
  final String snippet;

  const HelpSearchResult({
    required this.article,
    required this.relevanceScore,
    required this.matchedSections,
    required this.snippet,
  });

  HelpSearchResult copyWith({
    HelpArticle? article,
    int? relevanceScore,
    List<String>? matchedSections,
    String? snippet,
  }) {
    return HelpSearchResult(
      article: article ?? this.article,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      matchedSections: matchedSections ?? this.matchedSections,
      snippet: snippet ?? this.snippet,
    );
  }

  /// Check if title was matched
  bool get titleMatched => matchedSections.contains('title');

  /// Check if tags were matched
  bool get tagsMatched => matchedSections.contains('tags');

  /// Check if content was matched
  bool get contentMatched => matchedSections.contains('content');

  /// Check if steps were matched
  bool get stepsMatched => matchedSections.contains('steps');

  /// Get relevance percentage (0-100)
  int get relevancePercentage => (relevanceScore * 10).clamp(0, 100);

  /// Get match quality description
  String get matchQuality {
    if (relevanceScore >= 10) return 'Excellent match';
    if (relevanceScore >= 7) return 'Good match';
    if (relevanceScore >= 4) return 'Fair match';
    return 'Partial match';
  }

  Map<String, dynamic> toJson() {
    return {
      'article': article.toJson(),
      'relevanceScore': relevanceScore,
      'matchedSections': matchedSections,
      'snippet': snippet,
    };
  }

  factory HelpSearchResult.fromJson(Map<String, dynamic> json) {
    return HelpSearchResult(
      article: HelpArticle.fromJson(json['article'] as Map<String, dynamic>),
      relevanceScore: json['relevanceScore'] as int,
      matchedSections: (json['matchedSections'] as List<dynamic>).cast<String>(),
      snippet: json['snippet'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HelpSearchResult && 
           other.article.id == article.id &&
           other.relevanceScore == relevanceScore;
  }

  @override
  int get hashCode => Object.hash(article.id, relevanceScore);

  @override
  String toString() {
    return 'HelpSearchResult(article: ${article.title}, relevance: $relevanceScore, '
           'sections: $matchedSections)';
  }
}