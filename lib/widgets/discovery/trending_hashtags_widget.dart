// Trending Hashtags Widget - Display trending hashtags
// Part of Task 8: Create content discovery features

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TrendingHashtagsWidget extends StatelessWidget {
  final List<String> hashtags;
  final Function(String) onHashtagTap;

  const TrendingHashtagsWidget({
    super.key,
    required this.hashtags,
    required this.onHashtagTap,
  });

  @override
  Widget build(BuildContext context) {
    if (hashtags.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top trending hashtags (horizontal scroll)
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hashtags.length,
            itemBuilder: (context, index) {
              final hashtag = hashtags[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: AppTheme.spacingMedium,
                  left: index == 0 ? 0 : 0,
                ),
                child: _buildHashtagChip(context, hashtag, index),
              );
            },
          ),
        ),
        
        const SizedBox(height: AppTheme.spacingMedium),
        
        // Trending hashtags grid
        _buildHashtagGrid(context),
      ],
    );
  }

  Widget _buildHashtagChip(BuildContext context, String hashtag, int index) {
    final isTopTrending = index < 3;
    
    return GestureDetector(
      onTap: () => onHashtagTap(hashtag),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isTopTrending
              ? LinearGradient(
                  colors: [
                    AppTheme.talowaGreen,
                    AppTheme.talowaGreen.withOpacity(0.8),
                  ],
                )
              : null,
          color: isTopTrending ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTopTrending 
                ? AppTheme.talowaGreen 
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTopTrending)
              const Icon(
                Icons.trending_up,
                size: 16,
                color: Colors.white,
              ),
            if (isTopTrending) const SizedBox(width: 4),
            Text(
              '#$hashtag',
              style: TextStyle(
                color: isTopTrending ? Colors.white : Colors.grey[700],
                fontWeight: isTopTrending ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHashtagGrid(BuildContext context) {
    // Show remaining hashtags in a grid format
    final remainingHashtags = hashtags.skip(3).take(6).toList();
    
    if (remainingHashtags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Trending',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Wrap(
          spacing: AppTheme.spacingSmall,
          runSpacing: AppTheme.spacingSmall,
          children: remainingHashtags.asMap().entries.map((entry) {
            final index = entry.key + 3; // Offset by top 3
            final hashtag = entry.value;
            return _buildHashtagTile(context, hashtag, index);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHashtagTile(BuildContext context, String hashtag, int index) {
    return GestureDetector(
      onTap: () => onHashtagTap(hashtag),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _getHashtagColor(index),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '#$hashtag',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey[500],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 32,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No trending hashtags yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to start a trend!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getHashtagColor(int index) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }
}