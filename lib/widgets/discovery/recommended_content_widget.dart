// Recommended Content Widget - AI-powered content recommendations
// Part of Task 8: Create content discovery features

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';

class RecommendedContentWidget extends StatefulWidget {
  final List<PostModel> posts;
  final Function(PostModel) onPostTap;
  final VoidCallback onRefresh;

  const RecommendedContentWidget({
    super.key,
    required this.posts,
    required this.onPostTap,
    required this.onRefresh,
  });

  @override
  State<RecommendedContentWidget> createState() => _RecommendedContentWidgetState();
}

class _RecommendedContentWidgetState extends State<RecommendedContentWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with AI indicator
        _buildHeader(),
        
        const SizedBox(height: AppTheme.spacingMedium),
        
        // Recommendation explanation
        _buildRecommendationExplanation(),
        
        const SizedBox(height: AppTheme.spacingLarge),
        
        // Featured recommendations (horizontal scroll)
        _buildFeaturedRecommendations(),
        
        const SizedBox(height: AppTheme.spacingLarge),
        
        // All recommendations list
        _buildRecommendationsList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Colors.purple,
                Colors.blue,
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommended for You',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Personalized content based on your interests',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: widget.onRefresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh recommendations',
        ),
      ],
    );
  }

  Widget _buildRecommendationExplanation() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue[600],
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Text(
              'These recommendations are based on your location, interests, and community activity.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedRecommendations() {
    final featuredPosts = widget.posts.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Picks',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: featuredPosts.length,
            itemBuilder: (context, index) {
              final post = featuredPosts[index];
              return Padding(
                padding: const EdgeInsets.only(right: AppTheme.spacingMedium),
                child: _buildFeaturedPostCard(post),
              );
            },
          ),
        ),
        
        const SizedBox(height: AppTheme.spacingMedium),
        
        // Page indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            featuredPosts.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? AppTheme.talowaGreen
                    : Colors.grey[300],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedPostCard(PostModel post) {
    return GestureDetector(
      onTap: () => widget.onPostTap(post),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.talowaGreen.withValues(alpha: 0.1),
              AppTheme.talowaGreen.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: AppTheme.talowaGreen.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with author info
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.talowaGreen,
                    backgroundImage: post.imageUrls.isNotEmpty
                        ? NetworkImage(post.imageUrls.first)
                        : null,
                    child: post.imageUrls.isEmpty
                        ? Text(
                            post.authorName.isNotEmpty
                                ? post.authorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppTheme.spacingSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(post.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Recommended',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingMedium),
              
              // Post content
              Expanded(
                child: Text(
                  post.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingMedium),
              
              // Engagement stats
              Row(
                children: [
                  const Icon(Icons.favorite, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    '${post.likesCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentsCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.talowaGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsList() {
    final remainingPosts = widget.posts.skip(3).toList();
    
    if (remainingPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Recommendations',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        
        ...remainingPosts.map((post) => Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
          child: _buildRecommendationTile(post),
        )),
      ],
    );
  }

  Widget _buildRecommendationTile(PostModel post) {
    return GestureDetector(
      onTap: () => widget.onPostTap(post),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.talowaGreen,
              backgroundImage: post.imageUrls.isNotEmpty
                  ? NetworkImage(post.imageUrls.first)
                  : null,
              child: post.imageUrls.isEmpty
                  ? Text(
                      post.authorName.isNotEmpty
                          ? post.authorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            
            // Post content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.authorName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimeAgo(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${post.commentsCount}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'AI Pick',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              'No Recommendations Yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              'Interact with more content to get personalized recommendations',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            ElevatedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
  }
}
