// PostWidget - Individual post display widget for social feed
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/comment_model.dart';
import '../../services/social_feed/feed_service.dart';
import '../../services/auth/auth_service.dart';
import '../media/image_gallery_widget.dart';
import 'post_engagement_widget.dart';
import 'hashtag_text_widget.dart';
import 'author_info_widget.dart';
import 'geographic_scope_widget.dart';
import 'document_preview_widget.dart';

/// Widget for displaying individual social feed posts
class PostWidget extends StatefulWidget {
  final PostModel post;
  final Function(PostModel)? onPostUpdated;
  final Function(String)? onHashtagTapped;
  final Function(String)? onUserTapped;
  final Function(PostModel)? onPostTapped;
  final bool showFullContent;
  final bool enableInteractions;
  
  const PostWidget({
    super.key,
    required this.post,
    this.onPostUpdated,
    this.onHashtagTapped,
    this.onUserTapped,
    this.onPostTapped,
    this.showFullContent = true,
    this.enableInteractions = true,
  });
  
  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> with SingleTickerProviderStateMixin {
  late PostModel _currentPost;
  bool _isLiked = false;
  bool _isProcessingLike = false;
  bool _showFullContent = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  
  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _isLiked = _currentPost.isLikedByCurrentUser;
    _showFullContent = widget.showFullContent;
    
    // Initialize like animation
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.elasticOut),
    );
  }
  
  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      setState(() {
        _currentPost = widget.post;
        _isLiked = _currentPost.isLikedByCurrentUser;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => widget.onPostTapped?.call(_currentPost),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post header with author info
            _buildPostHeader(),
            
            // Post content
            _buildPostContent(),
            
            // Media content (images/documents)
            if (_currentPost.imageUrls.isNotEmpty || _currentPost.documentUrls.isNotEmpty)
              _buildMediaContent(),
            
            // Geographic scope and category
            _buildPostMetadata(),
            
            // Engagement section
            if (widget.enableInteractions)
              _buildEngagementSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Author avatar and info
          Expanded(
            child: AuthorInfoWidget(
              authorId: _currentPost.authorId,
              authorName: _currentPost.authorName,
              authorRole: _currentPost.authorRole,
              authorAvatarUrl: _currentPost.authorAvatarUrl,
              createdAt: _currentPost.createdAt,
              onUserTapped: widget.onUserTapped,
            ),
          ),
          
          // Post menu
          _buildPostMenu(),
        ],
      ),
    );
  }
  
  Widget _buildPostMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      onSelected: _handleMenuAction,
      itemBuilder: (context) => [
        if (_currentPost.authorId == AuthService.currentUser?.uid) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Edit Post'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete Post', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ] else ...[
          const PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.flag, size: 20, color: Colors.orange),
                SizedBox(width: 8),
                Text('Report Post'),
              ],
            ),
          ),
        ],
        const PopupMenuItem(
          value: 'share_external',
          child: Row(
            children: [
              Icon(Icons.share, size: 20),
              SizedBox(width: 8),
              Text('Share Externally'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_link',
          child: Row(
            children: [
              Icon(Icons.link, size: 20),
              SizedBox(width: 8),
              Text('Copy Link'),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPostContent() {
    final hasLongContent = _currentPost.content.length > 300;
    final shouldTruncate = hasLongContent && !_showFullContent;
    final displayContent = shouldTruncate 
        ? '${_currentPost.content.substring(0, 300)}...'
        : _currentPost.content;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post title (if exists)
          if (_currentPost.title?.isNotEmpty == true) ...[
            Text(
              _currentPost.title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          // Post content with hashtag highlighting
          HashtagTextWidget(
            text: displayContent,
            onHashtagTapped: widget.onHashtagTapped,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          
          // Show more/less button
          if (hasLongContent) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                setState(() {
                  _showFullContent = !_showFullContent;
                });
              },
              child: Text(
                _showFullContent ? 'Show less' : 'Show more',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }
  
  Widget _buildMediaContent() {
    return Column(
      children: [
        // Images
        if (_currentPost.imageUrls.isNotEmpty)
          ImageGalleryWidget(
            imageUrls: _currentPost.imageUrls,
            heroTag: 'post_${_currentPost.id}',
          ),
        
        // Documents
        if (_currentPost.documentUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          DocumentPreviewWidget(
            documentUrls: _currentPost.documentUrls,
            postId: _currentPost.id,
          ),
        ],
      ],
    );
  }
  
  Widget _buildPostMetadata() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          // Category badge
          _buildCategoryBadge(),
          
          // Geographic scope
          if (_currentPost.geographicTargeting != null)
            GeographicScopeWidget(
              targeting: _currentPost.geographicTargeting!,
            ),
          
          // Priority indicator
          if (_currentPost.priority == PostPriority.high)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.priority_high, size: 12, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'High Priority',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          // Pinned indicator
          if (_currentPost.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin, size: 12, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    'Pinned',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryBadge() {
    final categoryInfo = _getCategoryInfo(_currentPost.category);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: categoryInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryInfo['color'].withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            categoryInfo['icon'],
            size: 12,
            color: categoryInfo['color'],
          ),
          const SizedBox(width: 4),
          Text(
            categoryInfo['label'],
            style: TextStyle(
              fontSize: 10,
              color: categoryInfo['color'],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEngagementSection() {
    return PostEngagementWidget(
      post: _currentPost,
      onLikePressed: _handleLikePressed,
      onCommentPressed: _handleCommentPressed,
      onSharePressed: _handleSharePressed,
      isLiked: _isLiked,
      isProcessingLike: _isProcessingLike,
      likeAnimation: _likeAnimation,
    );
  }
  
  // Event handlers
  
  void _handleMenuAction(String action) async {
    switch (action) {
      case 'edit':
        _handleEditPost();
        break;
      case 'delete':
        _handleDeletePost();
        break;
      case 'report':
        _handleReportPost();
        break;
      case 'share_external':
        _handleShareExternal();
        break;
      case 'copy_link':
        _handleCopyLink();
        break;
    }
  }
  
  Future<void> _handleLikePressed() async {
    if (_isProcessingLike) return;
    
    setState(() {
      _isProcessingLike = true;
    });
    
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showLoginRequired();
        return;
      }
      
      if (_isLiked) {
        await FeedService.unlikePost(_currentPost.id, currentUser.uid);
        setState(() {
          _isLiked = false;
          _currentPost = _currentPost.copyWith(
            likesCount: _currentPost.likesCount - 1,
            isLikedByCurrentUser: false,
          );
        });
      } else {
        await FeedService.likePost(_currentPost.id, currentUser.uid);
        setState(() {
          _isLiked = true;
          _currentPost = _currentPost.copyWith(
            likesCount: _currentPost.likesCount + 1,
            isLikedByCurrentUser: true,
          );
        });
        
        // Animate like button
        _likeAnimationController.forward().then((_) {
          _likeAnimationController.reverse();
        });
      }
      
      widget.onPostUpdated?.call(_currentPost);
    } catch (e) {
      _showError('Failed to update like: $e');
    } finally {
      setState(() {
        _isProcessingLike = false;
      });
    }
  }
  
  void _handleCommentPressed() {
    // Navigate to post detail screen or show comment bottom sheet
    _showCommentBottomSheet();
  }
  
  Future<void> _handleSharePressed() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showLoginRequired();
        return;
      }
      
      await FeedService.sharePost(_currentPost.id, currentUser.uid);
      
      setState(() {
        _currentPost = _currentPost.copyWith(
          sharesCount: _currentPost.sharesCount + 1,
        );
      });
      
      widget.onPostUpdated?.call(_currentPost);
      
      _showSuccess('Post shared successfully!');
    } catch (e) {
      _showError('Failed to share post: $e');
    }
  }
  
  void _handleEditPost() {
    // Navigate to edit post screen
    // TODO: Implement edit post navigation
    _showInfo('Edit post feature coming soon!');
  }
  
  void _handleDeletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDeletePost();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _confirmDeletePost() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;
      
      await FeedService.deletePost(_currentPost.id, currentUser.uid);
      _showSuccess('Post deleted successfully');
      
      // Notify parent to remove post from list
      widget.onPostUpdated?.call(_currentPost.copyWith(isHidden: true));
    } catch (e) {
      _showError('Failed to delete post: $e');
    }
  }
  
  void _handleReportPost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Why are you reporting this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _submitReport('inappropriate_content');
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _submitReport(String reason) async {
    try {
      await FeedService.reportPost(_currentPost.id, reason);
      _showSuccess('Post reported successfully');
    } catch (e) {
      _showError('Failed to report post: $e');
    }
  }
  
  void _handleShareExternal() {
    // TODO: Implement external sharing
    _showInfo('External sharing feature coming soon!');
  }
  
  void _handleCopyLink() {
    // TODO: Implement copy link functionality
    _showInfo('Copy link feature coming soon!');
  }
  
  void _showCommentBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Comments header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_currentPost.commentsCount}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Comments list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _currentPost.recentComments.length,
                  itemBuilder: (context, index) {
                    final comment = _currentPost.recentComments[index];
                    return _buildCommentItem(comment);
                  },
                ),
              ),
              
              // Comment input
              _buildCommentInput(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCommentItem(CommentModel comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment author avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            child: Text(
              comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name and time
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Comment text
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),
                
                const SizedBox(height: 4),
                
                // Comment actions
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        // TODO: Implement comment like
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            comment.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: comment.isLikedByCurrentUser ? Colors.red : Colors.grey,
                          ),
                          if (comment.likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${comment.likesCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    InkWell(
                      onTap: () {
                        // TODO: Implement reply to comment
                      },
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
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
    );
  }
  
  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, size: 16),
          ),
          
          const SizedBox(width: 12),
          
          // Comment input field
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Send button
          IconButton(
            onPressed: () {
              // TODO: Implement send comment
            },
            icon: Icon(
              Icons.send,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper methods
  
  Map<String, dynamic> _getCategoryInfo(PostCategory category) {
    switch (category) {
      case PostCategory.successStory:
        return {
          'label': 'Success Story',
          'icon': Icons.celebration,
          'color': Colors.green,
        };
      case PostCategory.legalUpdate:
        return {
          'label': 'Legal Update',
          'icon': Icons.gavel,
          'color': Colors.blue,
        };
      case PostCategory.announcement:
        return {
          'label': 'Announcement',
          'icon': Icons.campaign,
          'color': Colors.orange,
        };
      case PostCategory.emergency:
        return {
          'label': 'Emergency',
          'icon': Icons.warning,
          'color': Colors.red,
        };
      case PostCategory.generalDiscussion:
        return {
          'label': 'Discussion',
          'icon': Icons.forum,
          'color': Colors.purple,
        };
      case PostCategory.landRights:
        return {
          'label': 'Land Rights',
          'icon': Icons.landscape,
          'color': Colors.brown,
        };
      case PostCategory.communityNews:
        return {
          'label': 'Community News',
          'icon': Icons.newspaper,
          'color': Colors.teal,
        };
    }
  }
  
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
  
  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please log in to interact with posts'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }
}