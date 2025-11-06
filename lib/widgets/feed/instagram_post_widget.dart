// Instagram-style Post Widget for TALOWA
// Individual post display with all modern social media features
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../media/optimized_image_widget.dart';
import '../media/optimized_video_widget.dart';
import '../common/expandable_text_widget.dart';
import '../common/user_avatar_widget.dart';

class InstagramPostWidget extends StatefulWidget {
  final InstagramPostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onViewProfile;
  final VoidCallback? onReport;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const InstagramPostWidget({
    super.key,
    required this.post,
    this.onLike,
    this.onBookmark,
    this.onComment,
    this.onShare,
    this.onViewProfile,
    this.onReport,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<InstagramPostWidget> createState() => _InstagramPostWidgetState();
}

class _InstagramPostWidgetState extends State<InstagramPostWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  late AnimationController _doubleTapAnimationController;
  late Animation<double> _doubleTapAnimation;
  
  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;
  bool _showUserTags = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _doubleTapAnimationController.dispose();
    _mediaPageController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.easeInOut),
    );

    _doubleTapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _doubleTapAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _doubleTapAnimationController, curve: Curves.elasticOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildMediaSection(),
          _buildActionButtons(),
          _buildLikesCount(),
          _buildCaption(),
          _buildCommentsPreview(),
          _buildTimeStamp(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onViewProfile,
            child: UserAvatarWidget(
              imageUrl: widget.post.authorProfileImageUrl,
              name: widget.post.authorName,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: widget.onViewProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.post.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.post.authorVerificationBadge != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: Colors.blue[600],
                        ),
                      ],
                    ],
                  ),
                  if (widget.post.hasLocation) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.post.locationTag!.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showMoreOptions(context),
            icon: const Icon(Icons.more_vert, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    if (!widget.post.hasMedia) return const SizedBox.shrink();

    return SizedBox(
      height: 400,
      child: Stack(
        children: [
          GestureDetector(
            onDoubleTap: _handleDoubleTap,
            child: PageView.builder(
              controller: _mediaPageController,
              itemCount: widget.post.mediaItems.length,
              onPageChanged: (index) {
                setState(() => _currentMediaIndex = index);
              },
              itemBuilder: (context, index) {
                final mediaItem = widget.post.mediaItems[index];
                return _buildMediaItem(mediaItem);
              },
            ),
          ),
          
          // Media indicators
          if (widget.post.isMultipleMedia)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentMediaIndex + 1}/${widget.post.mediaItems.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          
          // User tags overlay
          if (widget.post.hasUserTags && _showUserTags)
            ..._buildUserTagsOverlay(),
          
          // Double tap animation
          Center(
            child: AnimatedBuilder(
              animation: _doubleTapAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _doubleTapAnimation.value,
                  child: Opacity(
                    opacity: _doubleTapAnimation.value > 0.5 
                        ? 1.0 - _doubleTapAnimation.value 
                        : _doubleTapAnimation.value * 2,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 80,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // User tags toggle button
          if (widget.post.hasUserTags)
            Positioned(
              bottom: 16,
              left: 16,
              child: GestureDetector(
                onTap: () => setState(() => _showUserTags = !_showUserTags),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _showUserTags ? Icons.person_off : Icons.person,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(MediaItem mediaItem) {
    switch (mediaItem.type) {
      case MediaType.image:
        return OptimizedImageWidget(
          imageUrl: mediaItem.url,
          altText: mediaItem.altText ?? widget.post.altText,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      case MediaType.video:
        return OptimizedVideoWidget(
          videoUrl: mediaItem.url,
          thumbnailUrl: mediaItem.thumbnailUrl,
          aspectRatio: mediaItem.aspectRatio ?? 1.0,
          autoPlay: false,
          showControls: true,
        );
    }
  }

  List<Widget> _buildUserTagsOverlay() {
    return widget.post.userTags.map((tag) {
      return Positioned(
        left: tag.x * 400, // Assuming media width is 400
        top: tag.y * 400,  // Assuming media height is 400
        child: GestureDetector(
          onTap: () {
            // TODO: Navigate to tagged user profile
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '@${tag.username}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Like button
          GestureDetector(
            onTap: _handleLike,
            child: AnimatedBuilder(
              animation: _likeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _likeAnimation.value,
                  child: Icon(
                    widget.post.isLikedByCurrentUser 
                        ? Icons.favorite 
                        : Icons.favorite_border,
                    color: widget.post.isLikedByCurrentUser 
                        ? Colors.red 
                        : Colors.black,
                    size: 24,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          
          // Comment button
          GestureDetector(
            onTap: widget.onComment,
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.black,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          
          // Share button
          GestureDetector(
            onTap: widget.onShare,
            child: const Icon(
              Icons.send_outlined,
              color: Colors.black,
              size: 24,
            ),
          ),
          
          const Spacer(),
          
          // Bookmark button
          GestureDetector(
            onTap: widget.onBookmark,
            child: Icon(
              widget.post.isBookmarkedByCurrentUser 
                  ? Icons.bookmark 
                  : Icons.bookmark_border,
              color: Colors.black,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikesCount() {
    if (widget.post.likesCount == 0) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '${_formatCount(widget.post.likesCount)} likes',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCaption() {
    if (widget.post.caption.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpandableTextWidget(
        text: widget.post.caption,
        authorName: widget.post.authorName,
        maxLines: 3,
        style: const TextStyle(fontSize: 14),
        onHashtagTap: (hashtag) {
          // TODO: Navigate to hashtag page
        },
        onMentionTap: (mention) {
          // TODO: Navigate to mentioned user profile
        },
      ),
    );
  }

  Widget _buildCommentsPreview() {
    if (widget.post.commentsCount == 0) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: widget.onComment,
        child: Text(
          widget.post.commentsCount == 1
              ? 'View 1 comment'
              : 'View all ${_formatCount(widget.post.commentsCount)} comments',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeStamp() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        widget.post.timeAgo,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }

  void _handleLike() {
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });
    
    HapticFeedback.lightImpact();
    widget.onLike?.call();
  }

  void _handleDoubleTap() {
    if (!widget.post.isLikedByCurrentUser) {
      widget.onLike?.call();
    }
    
    _doubleTapAnimationController.forward().then((_) {
      _doubleTapAnimationController.reset();
    });
    
    HapticFeedback.mediumImpact();
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit option (only for post author)
            if (widget.onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onEdit?.call();
                },
              ),
            
            // Delete option (only for post author)
            if (widget.onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outlined, color: Colors.red),
                title: const Text('Delete Post'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
            
            // Archive option (only for post author)
            if (widget.onEdit != null)
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: Colors.orange),
                title: const Text('Archive Post'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement archive functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post archived'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            
            // Divider if there are author options
            if (widget.onEdit != null || widget.onDelete != null)
              const Divider(),
            
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Copy post link to clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            
            if (widget.post.allowSharing)
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share to...'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onShare?.call();
                },
              ),
            
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.red),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                widget.onReport?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
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
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
  }
}