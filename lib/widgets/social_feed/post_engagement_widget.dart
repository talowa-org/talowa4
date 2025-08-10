// Post Engagement Widget - Handle post interactions (like, comment, share)
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import '../../models/social_feed/post_model.dart';

/// Widget for post engagement actions (like, comment, share)
class PostEngagementWidget extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onLikePressed;
  final VoidCallback? onCommentPressed;
  final VoidCallback? onSharePressed;
  final bool isLiked;
  final bool isProcessingLike;
  final Animation<double>? likeAnimation;
  final bool showCounts;
  final bool isCompact;
  
  const PostEngagementWidget({
    super.key,
    required this.post,
    this.onLikePressed,
    this.onCommentPressed,
    this.onSharePressed,
    this.isLiked = false,
    this.isProcessingLike = false,
    this.likeAnimation,
    this.showCounts = true,
    this.isCompact = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Engagement counts
          if (showCounts && !isCompact) _buildEngagementCounts(context),
          
          // Action buttons
          _buildActionButtons(context),
        ],
      ),
    );
  }
  
  Widget _buildEngagementCounts(BuildContext context) {
    final hasEngagement = post.likesCount > 0 || post.commentsCount > 0 || post.sharesCount > 0;
    
    if (!hasEngagement) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Likes count
          if (post.likesCount > 0) ...[
            _buildEngagementCount(
              icon: Icons.favorite,
              count: post.likesCount,
              color: Colors.red,
              label: 'likes',
            ),
            const SizedBox(width: 16),
          ],
          
          // Comments count
          if (post.commentsCount > 0) ...[
            _buildEngagementCount(
              icon: Icons.comment,
              count: post.commentsCount,
              color: Colors.blue,
              label: 'comments',
            ),
            const SizedBox(width: 16),
          ],
          
          const Spacer(),
          
          // Shares count
          if (post.sharesCount > 0)
            _buildEngagementCount(
              icon: Icons.share,
              count: post.sharesCount,
              color: Colors.green,
              label: 'shares',
            ),
        ],
      ),
    );
  }
  
  Widget _buildEngagementCount({
    required IconData icon,
    required int count,
    required Color color,
    required String label,
  }) {
    return InkWell(
      onTap: () {
        // TODO: Show users who engaged
      },
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _formatCount(count),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Like button
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            label: isCompact ? null : 'Like',
            color: isLiked ? Colors.red : Colors.grey.shade600,
            onPressed: isProcessingLike ? null : onLikePressed,
            isActive: isLiked,
            animation: likeAnimation,
            count: showCounts && isCompact ? post.likesCount : null,
          ),
        ),
        
        // Comment button
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: Icons.comment_outlined,
            label: isCompact ? null : 'Comment',
            color: Colors.grey.shade600,
            onPressed: onCommentPressed,
            count: showCounts && isCompact ? post.commentsCount : null,
          ),
        ),
        
        // Share button
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: Icons.share_outlined,
            label: isCompact ? null : 'Share',
            color: Colors.grey.shade600,
            onPressed: onSharePressed,
            count: showCounts && isCompact ? post.sharesCount : null,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    String? label,
    required Color color,
    VoidCallback? onPressed,
    bool isActive = false,
    Animation<double>? animation,
    int? count,
  }) {
    Widget iconWidget = Icon(icon, size: 20, color: color);
    
    // Apply animation if provided
    if (animation != null) {
      iconWidget = AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.scale(
          scale: animation.value,
          child: child,
        ),
        child: iconWidget,
      );
    }
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
            
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Text(
                _formatCount(count),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      final k = count / 1000;
      return k == k.toInt() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    } else {
      final m = count / 1000000;
      return m == m.toInt() ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
  }
}

/// Widget for displaying engagement statistics
class EngagementStatsWidget extends StatelessWidget {
  final PostModel post;
  final bool showDetailed;
  
  const EngagementStatsWidget({
    super.key,
    required this.post,
    this.showDetailed = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, size: 20),
                SizedBox(width: 8),
                Text(
                  'Engagement Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Basic stats
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.favorite,
                    label: 'Likes',
                    value: post.likesCount,
                    color: Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.comment,
                    label: 'Comments',
                    value: post.commentsCount,
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.share,
                    label: 'Shares',
                    value: post.sharesCount,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            if (showDetailed) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Detailed stats
              _buildDetailedStats(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          _formatCount(value),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 2),
        
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailedStats() {
    final totalEngagement = post.likesCount + post.commentsCount + post.sharesCount;
    final engagementRate = totalEngagement > 0 ? (totalEngagement / 100.0) : 0.0; // Mock calculation
    
    return Column(
      children: [
        // Total engagement
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Engagement',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              _formatCount(totalEngagement),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Engagement rate
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Engagement Rate',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '${engagementRate.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Reach (mock data)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Estimated Reach',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              _formatCount(totalEngagement * 5), // Mock calculation
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
  
  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      final k = count / 1000;
      return k == k.toInt() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    } else {
      final m = count / 1000000;
      return m == m.toInt() ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
  }
}

/// Widget for showing who liked a post
class PostLikersWidget extends StatelessWidget {
  final String postId;
  final int likesCount;
  final bool isLikedByCurrentUser;
  
  const PostLikersWidget({
    super.key,
    required this.postId,
    required this.likesCount,
    required this.isLikedByCurrentUser,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Liked by $likesCount ${likesCount == 1 ? 'person' : 'people'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // List of likers (mock data)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5, // Mock count
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade300,
                  child: Text('U${index + 1}'),
                ),
                title: Text('User ${index + 1}'),
                subtitle: const Text('Village Coordinator'),
                trailing: index == 0 && isLikedByCurrentUser
                    ? const Text(
                        'You',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}