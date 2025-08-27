// Search Result Widget for TALOWA
// Implements Task 24: Add advanced search and discovery - Search Result Display

import 'package:flutter/material.dart';
import '../../services/search/advanced_search_service.dart';
import '../common/user_avatar.dart';

class SearchResultWidget extends StatelessWidget {
  final SearchResult result;
  final String query;
  final VoidCallback? onTap;

  const SearchResultWidget({
    super.key,
    required this.result,
    required this.query,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (result.type) {
      case SearchResultType.post:
        return _buildPostResult(context);
      case SearchResultType.user:
        return _buildUserResult(context);
      case SearchResultType.hashtag:
        return _buildHashtagResult(context);
      case SearchResultType.topic:
        return _buildTopicResult(context);
    }
  }

  Widget _buildPostResult(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    imageUrl: result.metadata['authorAvatar'],
                    name: result.metadata['authorName'] ?? 'Unknown',
                    radius: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.metadata['authorName'] ?? 'Unknown Author',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _formatDate(result.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildRelevanceScore(),
                ],
              ),
              const SizedBox(height: 12),
              _buildHighlightedContent(context),
              if (result.metadata['hashtags'] != null) ...[
                const SizedBox(height: 8),
                _buildHashtags(),
              ],
              const SizedBox(height: 8),
              _buildEngagementStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserResult(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: UserAvatar(
          imageUrl: result.metadata['avatarUrl'],
          name: result.title,
          radius: 24,
        ),
        title: _buildHighlightedText(result.title, query),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.metadata['role'] != null)
              Text(
                result.metadata['role'],
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (result.metadata['location'] != null)
              Text(
                result.metadata['location'],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRelevanceScore(),
            const SizedBox(height: 4),
            if (result.metadata['followers'] != null)
              Text(
                '${result.metadata['followers']} followers',
                style: const TextStyle(fontSize: 10),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildHashtagResult(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.tag, color: Colors.white),
        ),
        title: _buildHighlightedText(result.title, query),
        subtitle: Text(
          '${result.metadata['postCount'] ?? 0} posts',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRelevanceScore(),
            const SizedBox(height: 4),
            if (result.metadata['trending'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'TRENDING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildTopicResult(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.topic, color: Colors.white),
        ),
        title: _buildHighlightedText(result.title, query),
        subtitle: Text(
          result.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: _buildRelevanceScore(),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRelevanceScore() {
    final score = (result.relevanceScore * 100).round();
    final color = score >= 80 ? Colors.green : score >= 60 ? Colors.orange : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHighlightedContent(BuildContext context) {
    return _buildHighlightedText(
      result.content,
      query,
      maxLines: 3,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildHighlightedText(
    String text,
    String query, {
    int? maxLines,
    TextStyle? style,
  }) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        style: style,
      );
    }

    final queryTerms = query.toLowerCase().split(' ');
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    
    int lastIndex = 0;
    
    for (final term in queryTerms) {
      if (term.isEmpty) continue;
      
      int index = lowerText.indexOf(term, lastIndex);
      while (index != -1) {
        // Add text before the match
        if (index > lastIndex) {
          spans.add(TextSpan(
            text: text.substring(lastIndex, index),
            style: style,
          ));
        }
        
        // Add highlighted match
        spans.add(TextSpan(
          text: text.substring(index, index + term.length),
          style: (style ?? const TextStyle()).copyWith(
            backgroundColor: Colors.yellow.withOpacity(0.3),
            fontWeight: FontWeight.bold,
          ),
        ));
        
        lastIndex = index + term.length;
        index = lowerText.indexOf(term, lastIndex);
      }
    }
    
    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans.isEmpty ? [TextSpan(text: text, style: style)] : spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }

  Widget _buildHashtags() {
    final hashtags = List<String>.from(result.metadata['hashtags'] ?? []);
    
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: hashtags.take(5).map((hashtag) {
        final isHighlighted = query.toLowerCase().contains(hashtag.toLowerCase());
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isHighlighted 
                ? Colors.blue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: isHighlighted 
                ? Border.all(color: Colors.blue.withOpacity(0.3))
                : null,
          ),
          child: Text(
            hashtag,
            style: TextStyle(
              fontSize: 12,
              color: isHighlighted ? Colors.blue : Colors.grey[700],
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEngagementStats() {
    final likes = result.metadata['likeCount'] ?? 0;
    final comments = result.metadata['commentCount'] ?? 0;
    final shares = result.metadata['shareCount'] ?? 0;
    
    return Row(
      children: [
        _buildEngagementStat(Icons.favorite, likes, Colors.red),
        const SizedBox(width: 16),
        _buildEngagementStat(Icons.comment, comments, Colors.blue),
        const SizedBox(width: 16),
        _buildEngagementStat(Icons.share, shares, Colors.green),
        const Spacer(),
        if (result.metadata['category'] != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.metadata['category'],
              style: const TextStyle(fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildEngagementStat(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class SearchResultsListView extends StatelessWidget {
  final List<SearchResult> results;
  final String query;
  final Function(SearchResult) onResultTap;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;

  const SearchResultsListView({
    super.key,
    required this.results,
    required this.query,
    required this.onResultTap,
    this.onLoadMore,
    this.isLoadingMore = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final result = results[index];
        return SearchResultWidget(
          result: result,
          query: query,
          onTap: () => onResultTap(result),
        );
      },
    );
  }
}

class EmptySearchResults extends StatelessWidget {
  final String query;
  final List<String> suggestions;
  final Function(String) onSuggestionTap;

  const EmptySearchResults({
    super.key,
    required this.query,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'No results found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No results found for "$query"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Try searching for:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((suggestion) {
                  return ActionChip(
                    label: Text(suggestion),
                    onPressed: () => onSuggestionTap(suggestion),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SearchResultSkeleton extends StatelessWidget {
  const SearchResultSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 80,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 200,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}