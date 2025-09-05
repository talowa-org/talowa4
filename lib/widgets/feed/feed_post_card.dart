// Feed Post Card Widget
// Reference: social-feed-implementation-plan.md - Feed Interface

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class FeedPostCard extends StatelessWidget {
  final FeedPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onUserTap;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          _buildPostHeader(),
          
          // Post Content
          _buildPostContent(),
          
          // Post Image (if any)
          if (post.imageUrl != null) _buildPostImage(),
          
          // Post Actions
          _buildPostActions(),
          
          // Post Stats
          _buildPostStats(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          GestureDetector(
            onTap: onUserTap,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: _getRoleColor(post.authorRole),
              child: Text(
                post.authorName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onUserTap,
                  child: Text(
                    post.authorName,
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${post.authorRole} • ${post.authorLocation}',
                  style: AppTheme.captionStyle,
                ),
                Text(
                  _formatTimestamp(post.timestamp),
                  style: AppTheme.captionStyle,
                ),
              ],
            ),
          ),
          _buildPostTypeChip(),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.content,
            style: AppTheme.bodyStyle,
          ),
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            Wrap(
              spacing: AppTheme.spacingSmall,
              children: post.hashtags.map((hashtag) => Text(
                hashtag,
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.talowaGreen,
                  fontWeight: FontWeight.w500,
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostImage() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingMedium),
      height: 200,
      width: double.infinity,
      color: AppTheme.background,
      child: const Center(
        child: Icon(
          Icons.image,
          size: 64,
          color: AppTheme.secondaryText,
        ),
      ),
    );
  }

  Widget _buildPostActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Row(
        children: [
          IconButton(
            onPressed: onLike,
            icon: const Icon(Icons.thumb_up_outlined),
            color: AppTheme.secondaryText,
          ),
          IconButton(
            onPressed: onComment,
            icon: const Icon(Icons.chat_bubble_outline),
            color: AppTheme.secondaryText,
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            color: AppTheme.secondaryText,
          ),
          const Spacer(),
          IconButton(
            onPressed: () {}, // TODO: Implement bookmark
            icon: const Icon(Icons.bookmark_border),
            color: AppTheme.secondaryText,
          ),
        ],
      ),
    );
  }

  Widget _buildPostStats() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          Text(
            '${post.likes} likes',
            style: AppTheme.captionStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Text(
            '${post.comments} comments',
            style: AppTheme.captionStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Text(
            '${post.shares} shares',
            style: AppTheme.captionStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostTypeChip() {
    Color chipColor;
    String chipText;
    
    switch (post.type) {
      case AppConstants.postTypeSuccessStory:
        chipColor = AppTheme.successGreen;
        chipText = 'Success';
        break;
      case AppConstants.postTypeEmergencyAlert:
        chipColor = AppTheme.emergencyRed;
        chipText = 'Emergency';
        break;
      case AppConstants.postTypeLegalUpdate:
        chipColor = AppTheme.legalBlue;
        chipText = 'Legal';
        break;
      case AppConstants.postTypeCampaignUpdate:
        chipColor = AppTheme.warningOrange;
        chipText = 'Campaign';
        break;
      default:
        chipColor = AppTheme.secondaryText;
        chipText = 'Update';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        chipText,
        style: AppTheme.captionStyle.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case AppConstants.roleVillageCoordinator:
        return AppTheme.talowaGreen;
      case AppConstants.roleMandalCoordinator:
        return AppTheme.legalBlue;
      case AppConstants.roleDistrictCoordinator:
        return AppTheme.warningOrange;
      case AppConstants.roleLegalAdvisor:
        return AppTheme.legalBlue;
      default:
        return AppTheme.secondaryText;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

