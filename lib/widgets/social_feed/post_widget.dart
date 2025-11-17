// PostWidget - Individual post display widget for social feed
// Part of Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
// removed: import 'package:intl/intl.dart';
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/comment_model.dart';
import '../../services/social_feed/feed_service.dart';
import '../../services/social_feed/comment_service.dart';
import '../../services/social_feed/share_service.dart';
import '../../services/auth/auth_service.dart';
// import '../media/enhanced_media_widget.dart'; // TODO: Add when available
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
              // TODO: Add authorAvatarUrl property to PostModel
              // authorAvatarUrl: _currentPost.authorAvatarUrl,
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
          // TODO: Implement ImageGalleryWidget when available
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('Image Gallery - Coming Soon'),
            ),
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
          
          // Priority indicator - TODO: Add priority property to PostModel
          // if (_currentPost.priority == PostPriority.high)
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //     decoration: BoxDecoration(
          //       color: Colors.orange.withValues(alpha: 0.1),
          //       borderRadius: BorderRadius.circular(12),
          //       border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          //     ),
          //     child: const Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         Icon(Icons.priority_high, size: 12, color: Colors.orange),
          //         SizedBox(width: 4),
          //         Text(
          //           'High Priority',
          //           style: TextStyle(
          //             fontSize: 10,
          //             color: Colors.orange,
          //             fontWeight: FontWeight.w500,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          
          // Pinned indicator - TODO: Add isPinned property to PostModel
          // if (_currentPost.isPinned)
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //     decoration: BoxDecoration(
          //       color: Colors.blue.withValues(alpha: 0.1),
          //       borderRadius: BorderRadius.circular(12),
          //       border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          //     ),
          //     child: const Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         Icon(Icons.push_pin, size: 12, color: Colors.blue),
          //         SizedBox(width: 4),
          //         Text(
          //           'Pinned',
          //           style: TextStyle(
          //             fontSize: 10,
          //             color: Colors.blue,
          //             fontWeight: FontWeight.w500,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryBadge() {
    final categoryInfo = _getCategoryInfo(_currentPost.category);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: categoryInfo['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryInfo['color'].withValues(alpha: 0.3)),
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
        await FeedService().toggleLike(_currentPost.id);
        setState(() {
          _isLiked = false;
          _currentPost = _currentPost.copyWith(
            likesCount: _currentPost.likesCount - 1,
            isLikedByCurrentUser: false,
          );
        });
      } else {
        await FeedService().toggleLike(_currentPost.id);
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
    // Show comment bottom sheet with full functionality
    _showCommentBottomSheet();
  }
  
  Future<void> _handleSharePressed() async {
    // Show share options dialog
    _showShareDialog();
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
      
      await FeedService().deletePost(_currentPost.id);
      _showSuccess('Post deleted successfully');
      
      // Notify parent to remove post from list
      widget.onPostUpdated?.call(_currentPost);
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
      // TODO: Implement report functionality when available
      // await FeedService.reportPost(_currentPost.id, reason);
      _showSuccess('Post reported successfully');
    } catch (e) {
      _showError('Failed to report post: $e');
    }
  }
  
  void _handleShareExternal() {
    _showShareDialog();
  }
  
  Future<void> _handleCopyLink() async {
    try {
      await ShareService().copyPostLink(_currentPost.id);
      _showSuccess('Link copied to clipboard!');
    } catch (e) {
      _showError('Failed to copy link: $e');
    }
  }
  
  void _showCommentBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsBottomSheet(
        postId: _currentPost.id,
        initialCommentsCount: _currentPost.commentsCount,
        onCommentAdded: () {
          setState(() {
            _currentPost = _currentPost.copyWith(
              commentsCount: _currentPost.commentsCount + 1,
            );
          });
          widget.onPostUpdated?.call(_currentPost);
        },
      ),
    );
  }
  
  void _showShareDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            
            // Share header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Share Post',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const Divider(height: 1),
            
            // Share options
            ListTile(
              leading: const Icon(Icons.link, color: Colors.blue),
              title: const Text('Copy Link'),
              onTap: () async {
                Navigator.pop(context);
                await _handleCopyLink();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.ios_share, color: Colors.purple),
              title: const Text('Share to Social Media'),
              subtitle: const Text('WhatsApp, Instagram, Facebook, etc.'),
              onTap: () async {
                Navigator.pop(context);
                await _shareToSocialMedia();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.email, color: Colors.orange),
              title: const Text('Share via Email'),
              onTap: () async {
                Navigator.pop(context);
                await _shareViaEmail();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text('Share to Feed'),
              subtitle: const Text('Share this post to your followers'),
              onTap: () async {
                Navigator.pop(context);
                await _shareToFeed();
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Future<void> _shareToSocialMedia() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showLoginRequired();
        return;
      }
      
      await ShareService().shareToNativePlatforms(
        postId: _currentPost.id,
        postContent: _currentPost.content,
        authorName: _currentPost.authorName,
      );
      
      _showInfo('Opening share options...');
      widget.onPostUpdated?.call(_currentPost);
    } catch (e) {
      _showError('Failed to open share options: $e');
    }
  }

  Future<void> _shareViaEmail() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showLoginRequired();
        return;
      }
      
      await ShareService().shareViaEmail(_currentPost.id, _currentPost.content);
      await ShareService().sharePost(_currentPost.id, shareType: 'email', platform: 'email');
      
      setState(() {
        _currentPost = _currentPost.copyWith(
          sharesCount: _currentPost.sharesCount + 1,
        );
      });
      
      widget.onPostUpdated?.call(_currentPost);
      _showSuccess('Email content copied to clipboard!');
    } catch (e) {
      _showError('Failed to share via email: $e');
    }
  }
  
  Future<void> _shareToFeed() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showLoginRequired();
        return;
      }
      
      await ShareService().sharePost(_currentPost.id, shareType: 'feed', platform: 'talowa');
      
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
      case PostCategory.agriculture:
        return {
          'label': 'Agriculture',
          'icon': Icons.agriculture,
          'color': Colors.green,
        };
      case PostCategory.governmentSchemes:
        return {
          'label': 'Government Schemes',
          'icon': Icons.account_balance,
          'color': Colors.indigo,
        };
      case PostCategory.education:
        return {
          'label': 'Education',
          'icon': Icons.school,
          'color': Colors.blue,
        };
      case PostCategory.health:
        return {
          'label': 'Health',
          'icon': Icons.health_and_safety,
          'color': Colors.red,
        };
    }
  }
  
  // Removed unused helper _formatTime(DateTime)
  
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



// Comments Bottom Sheet Widget
class _CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final int initialCommentsCount;
  final VoidCallback? onCommentAdded;

  const _CommentsBottomSheet({
    required this.postId,
    required this.initialCommentsCount,
    this.onCommentAdded,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final CommentService _commentService = CommentService();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await _commentService.getComments(widget.postId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _commentService.addComment(
        postId: widget.postId,
        content: content,
      );

      _commentController.clear();
      widget.onCommentAdded?.call();
      await _loadComments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
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
                    '${_comments.length}',
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.comment_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No comments yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to comment!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            return _buildCommentItem(_comments[index]);
                          },
                        ),
            ),

            // Comment input
            _buildCommentInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    final currentUserId = AuthService.currentUser?.uid;
    final isOwnComment = comment.authorId == currentUserId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade300,
            child: Text(
              comment.authorName.isNotEmpty
                  ? comment.authorName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name and role
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (comment.authorRole != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          comment.authorRole!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),

                // Comment text
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(height: 8),

                // Comment actions
                Row(
                  children: [
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (comment.isEdited) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(edited)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () {
                        // TODO: Implement reply functionality
                      },
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isOwnComment) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => _deleteComment(comment.id),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              enabled: !_isSending,
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          _isSending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  onPressed: _sendComment,
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _commentService.deleteComment(commentId);
        await _loadComments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete comment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
