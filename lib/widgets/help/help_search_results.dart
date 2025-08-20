// TALOWA Help Search Results Widget
// Displays search results with relevance scoring

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/help/help_search_result.dart';
import '../../models/help/help_article.dart';

class HelpSearchResults extends StatelessWidget {
  final List<HelpSearchResult> results;
  final String query;
  final Function(HelpArticle) onArticleTap;

  const HelpSearchResults({
    super.key,
    required this.results,
    required this.query,
    required this.onArticleTap,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$query"',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try different keywords or browse categories',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${results.length} result${results.length == 1 ? '' : 's'} for "$query"',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return _SearchResultCard(
                result: result,
                query: query,
                onTap: () => onArticleTap(result.article),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final HelpSearchResult result;
  final String query;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.result,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Article title with match indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.article.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryText,
                      ),
                    ),
                  ),
                  if (result.titleMatched)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.talowaGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'TITLE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.talowaGreen,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Article metadata
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.article.category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    result.article.readTimeText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    result.matchQuality,
                    style: TextStyle(
                      fontSize: 11,
                      color: _getRelevanceColor(result.relevanceScore),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Search snippet
              Text(
                _highlightQuery(result.snippet, query),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryText,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Match indicators
              if (result.matchedSections.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: result.matchedSections.map((section) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getSectionColor(section).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        section.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _getSectionColor(section),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _highlightQuery(String text, String query) {
    // In a real implementation, this would use RichText to highlight matches
    // For now, just return the text as-is
    return text;
  }

  Color _getRelevanceColor(int score) {
    if (score >= 10) return Colors.green;
    if (score >= 7) return Colors.orange;
    if (score >= 4) return Colors.blue;
    return Colors.grey;
  }

  Color _getSectionColor(String section) {
    switch (section) {
      case 'title':
        return AppTheme.talowaGreen;
      case 'tags':
        return Colors.blue;
      case 'content':
        return Colors.orange;
      case 'steps':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}