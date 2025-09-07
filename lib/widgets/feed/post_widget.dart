// Post Widget for TALOWA Social Feed
// Implements Task 6: Implement PostWidget for individual posts

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../screens/media/document_viewer_screen.dart';
import '../../screens/hashtag/hashtag_screen.dart';
import '../media/enhanced_feed_media_widget.dart';
import '../../services/auth/auth_service.dart';
import '../../services/social_feed/post_management_service.dart';
import '../../utils/navigation_helper.dart';

class PostWidget extends StatefulWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onUserTap;
  final VoidCallback onPostTap;
  final String? highlightQuery;

  const PostWidget({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onUserTap,
    required this.onPostTap,
    this.highlightQuery,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> with TickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late AnimationController _shareAnimationController;
  late Animation<double> _likeAnimation;
  late Animation<double> _shareAnimation;
  
  bool _isLiking = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shareAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.elasticOut),
    );
    _shareAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _shareAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _shareAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      elevation: AppTheme.elevationLow,
      child: InkWell(
        onTap: widget.onPostTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            _buildPostContent(),
            if (widget.post.imageUrls.isNotEmpty) _buildPostImages(),
            if (widget.post.videoUrls.isNotEmpty) _buildPostVideos(),
            if (widget.post.documentUrls.isNotEmpty) _buildPostDocuments(),
            _buildPostActions(),
            _buildPostStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          // Author Avatar
          GestureDetector(
            onTap: widget.onUserTap,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.talowaGreen,
              backgroundImage: widget.post.authorAvatarUrl != null
                  ? NetworkImage(widget.post.authorAvatarUrl!)
                  : null,
              child: widget.post.authorAvatarUrl == null
                  ? Text(
                      widget.post.authorName.isNotEmpty
                          ? widget.post.authorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          
          // Author Info
          Expanded(
            child: GestureDetector(
              onTap: widget.onUserTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.post.authorName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.post.authorRole != null) ...[
                        const SizedBox(width: AppTheme.spacingSmall),
                        _buildRoleBadge(widget.post.authorRole!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        widget.post.getTimeAgo(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (widget.post.targeting != null) ...[
                        const SizedBox(width: AppTheme.spacingSmall),
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            widget.post.targeting!.getDisplayString(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Category Badge
          _buildCategoryBadge(),
          
          // More Options
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            onSelected: _handlePostAction,
            itemBuilder: (context) => _buildMenuItems(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    String badgeText;
    
    if (role.contains('coordinator')) {
      badgeColor = AppTheme.talowaGreen;
      badgeText = 'Coordinator';
    } else if (role.contains('admin')) {
      badgeColor = Colors.red;
      badgeText = 'Admin';
    } else {
      badgeColor = Colors.blue;
      badgeText = 'Member';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getCategoryColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.post.category.icon,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            widget.post.category.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _getCategoryColor(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor() {
    switch (widget.post.category) {
      case PostCategory.emergency:
        return Colors.red;
      case PostCategory.successStory:
        return Colors.green;
      case PostCategory.legalUpdate:
        return Colors.blue;
      case PostCategory.announcement:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content
          _buildRichText(widget.post.content),
          
          // Hashtags
          if (widget.post.hashtags.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            _buildHashtags(),
          ],
          
          const SizedBox(height: AppTheme.spacingMedium),
        ],
      ),
    );
  }

  Widget _buildRichText(String content) {
    // Enhanced rich text with hashtag and mention highlighting
    return RichText(
      text: _buildTextSpans(content),
    );
  }

  TextSpan _buildTextSpans(String content) {
    final List<TextSpan> spans = [];
    final RegExp hashtagRegex = RegExp(r'#[\w\u0900-\u097F\u0C00-\u0C7F_]+');
    final RegExp mentionRegex = RegExp(r'@[\w\u0900-\u097F\u0C00-\u0C7F_]+');
    
    int lastIndex = 0;
    
    // Find all hashtags and mentions
    final List<RegExpMatch> allMatches = [
      ...hashtagRegex.allMatches(content),
      ...mentionRegex.allMatches(content),
    ];
    
    // Sort matches by position
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    for (final match in allMatches) {
      // Add text before the match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: content.substring(lastIndex, match.start),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
        ));
      }
      
      // Add the highlighted match
      final matchText = match.group(0)!;
      spans.add(TextSpan(
        text: matchText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.talowaGreen,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (matchText.startsWith('#')) {
              _onHashtagTap(matchText.substring(1));
            } else if (matchText.startsWith('@')) {
              _onMentionTap(matchText.substring(1));
            }
          },
      ));
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
      ));
    }
    
    return TextSpan(children: spans);
  }

  Widget _buildHashtags() {
    return Wrap(
      spacing: AppTheme.spacingSmall,
      runSpacing: 4,
      children: widget.post.hashtags.map((hashtag) {
        return GestureDetector(
          onTap: () => _onHashtagTap(hashtag),
          child: Text(
            '#$hashtag',
            style: const TextStyle(
              color: AppTheme.talowaGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPostImages() {
    if (widget.post.imageUrls.length == 1) {
      return _buildSingleImage(widget.post.imageUrls.first);
    } else {
      return _buildImageGrid();
    }
  }

  Widget _buildSingleImage(String imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: GestureDetector(
        onTap: () => _openImageGallery(0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Hero(
              tag: 'post_image_${widget.post.id}_0',
              child: EnhancedFeedMediaWidget(
                mediaUrl: imageUrl,
                postId: widget.post.id,
                mediaIndex: 0,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      height: 200,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.post.imageUrls.length > 2 ? 2 : widget.post.imageUrls.length,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: widget.post.imageUrls.length > 4 ? 4 : widget.post.imageUrls.length,
        itemBuilder: (context, index) {
          final isLastItem = index == 3 && widget.post.imageUrls.length > 4;
          return GestureDetector(
            onTap: () => _openImageGallery(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'post_image_${widget.post.id}_$index',
                    child: EnhancedFeedMediaWidget(
                      mediaUrl: widget.post.imageUrls[index],
                      postId: widget.post.id,
                      mediaIndex: index,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isLastItem)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '+${widget.post.imageUrls.length - 3}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'more photos',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.2),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostVideos() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Column(
        children: widget.post.videoUrls.asMap().entries.map((entry) {
          final index = entry.key;
          final videoUrl = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: EnhancedFeedMediaWidget(
                  mediaUrl: videoUrl,
                  contentType: 'video/mp4',
                  postId: widget.post.id,
                  mediaIndex: index,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  showControls: true,
                  autoPlay: false,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPostDocuments() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Column(
        children: widget.post.documentUrls.map((docUrl) {
          return Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(
                  _getDocumentIcon(docUrl),
                  color: AppTheme.talowaGreen,
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDocumentName(docUrl),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _getDocumentType(docUrl),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openDocument(docUrl),
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Open Document',
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPostActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Row(
        children: [
          // Like Button with enhanced animation
          ScaleTransition(
            scale: _likeAnimation,
            child: IconButton(
              onPressed: _isLiking ? null : _handleLike,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.post.isLikedByCurrentUser
                      ? Icons.favorite
                      : Icons.favorite_border,
                  key: ValueKey(widget.post.isLikedByCurrentUser),
                  color: widget.post.isLikedByCurrentUser
                      ? Colors.red
                      : Colors.grey[600],
                ),
              ),
              tooltip: widget.post.isLikedByCurrentUser ? 'Unlike' : 'Like',
            ),
          ),
          
          // Comment Button with badge
          Stack(
            children: [
              IconButton(
                onPressed: widget.onComment,
                icon: Icon(Icons.comment_outlined, color: Colors.grey[600]),
                tooltip: 'Comment',
              ),
              if (widget.post.commentsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.talowaGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      widget.post.commentsCount > 99 
                          ? '99+' 
                          : widget.post.commentsCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          
          // Share Button with animation
          ScaleTransition(
            scale: _shareAnimation,
            child: IconButton(
              onPressed: _isSharing ? null : _handleShare,
              icon: Icon(
                widget.post.isSharedByCurrentUser
                    ? Icons.share
                    : Icons.share_outlined,
                color: widget.post.isSharedByCurrentUser
                    ? AppTheme.talowaGreen
                    : Colors.grey[600],
              ),
              tooltip: 'Share',
            ),
          ),
          
          const Spacer(),
          
          // Pinned Badge
          if (widget.post.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin, size: 12, color: Colors.amber[700]),
                  const SizedBox(width: 2),
                  Text(
                    'PINNED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
            ),
          
          // Emergency Badge
          if (widget.post.isEmergency) ...[
            if (widget.post.isPinned) const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, size: 12, color: Colors.red),
                  SizedBox(width: 2),
                  Text(
                    'EMERGENCY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleLike() async {
    if (_isLiking) return;
    
    setState(() {
      _isLiking = true;
    });
    
    // Trigger animation
    await _likeAnimationController.forward();
    await _likeAnimationController.reverse();
    
    // Call the callback
    widget.onLike();
    
    setState(() {
      _isLiking = false;
    });
  }

  void _handleShare() async {
    if (_isSharing) return;
    
    setState(() {
      _isSharing = true;
    });
    
    // Trigger animation
    await _shareAnimationController.forward();
    await _shareAnimationController.reverse();
    
    // Call the callback
    widget.onShare();
    
    setState(() {
      _isSharing = false;
    });
  }

  Widget _buildPostStats() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          if (widget.post.likesCount > 0) ...[
            const Icon(Icons.favorite, size: 16, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              _formatCount(widget.post.likesCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: AppTheme.spacingMedium),
          ],
          
          if (widget.post.commentsCount > 0) ...[
            Icon(Icons.comment, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              _formatCount(widget.post.commentsCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: AppTheme.spacingMedium),
          ],
          
          if (widget.post.sharesCount > 0) ...[
            Icon(Icons.share, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              _formatCount(widget.post.sharesCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          
          const Spacer(),
          
          if (widget.post.viewsCount > 0)
            Text(
              '${_formatCount(widget.post.viewsCount)} views',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  // Helper Methods
  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  IconData _getDocumentIcon(String url) {
    final extension = url.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getDocumentName(String url) {
    return url.split('/').last.split('?').first;
  }

  String _getDocumentType(String url) {
    final extension = url.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      default:
        return 'Document';
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final currentUser = AuthService.currentUser;
    final isAuthor = currentUser != null && currentUser.uid == widget.post.authorId;
    
    List<PopupMenuEntry<String>> items = [];
    
    if (isAuthor) {
      // Author can edit and delete their own posts
      items.addAll([
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit, color: Colors.blue),
            title: Text('Edit Post'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete Post', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
      ]);
    }
    
    // Common options for all users
    items.addAll([
      if (!isAuthor)
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            leading: Icon(Icons.flag, color: Colors.orange),
            title: Text('Report Post'),
            dense: true,
          ),
        ),
      const PopupMenuItem(
        value: 'hide',
        child: ListTile(
          leading: Icon(Icons.visibility_off),
          title: Text('Hide Post'),
          dense: true,
        ),
      ),
      const PopupMenuItem(
        value: 'copy_link',
        child: ListTile(
          leading: Icon(Icons.link),
          title: Text('Copy Link'),
          dense: true,
        ),
      ),
    ]);
    
    return items;
  }

  void _handlePostAction(String action) {
    switch (action) {
      case 'edit':
        _editPost();
        break;
      case 'delete':
        _deletePost();
        break;
      case 'report':
        _reportPost();
        break;
      case 'hide':
        _hidePost();
        break;
      case 'copy_link':
        _copyPostLink();
        break;
    }
  }

  void _editPost() {
    // Navigate to post creation screen with editing data
    NavigationHelper.navigateToPostCreation(
      context,
      editingPost: widget.post,
    ).then((result) {
      if (result == true) {
        // Refresh the feed or update the post
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _deletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeletePost();
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
      await PostManagementService.deletePost(widget.post.id);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reportPost() {
    // TODO: Implement report functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report functionality coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _hidePost() {
    // TODO: Implement hide functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hide functionality coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _copyPostLink() {
    // TODO: Implement copy link functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copy link functionality coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _onHashtagTap(String hashtag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HashtagScreen(hashtag: hashtag),
      ),
    );
  }

  void _onMentionTap(String username) {
    // Navigate to user profile
    // TODO: Implement user profile navigation
    // Navigator.pushNamed(context, '/profile', arguments: username);
  }

  void _openImageGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('${initialIndex + 1} of ${widget.post.imageUrls.length}'),
          ),
          body: PageView.builder(
            itemCount: widget.post.imageUrls.length,
            controller: PageController(initialPage: initialIndex),
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  child: EnhancedFeedMediaWidget(
                    mediaUrl: widget.post.imageUrls[index],
                    postId: widget.post.id,
                    mediaIndex: index,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openDocument(String documentUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(url: documentUrl),
      ),
    );
  }
}


