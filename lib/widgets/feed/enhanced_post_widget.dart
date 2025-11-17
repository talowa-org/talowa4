// Enhanced Post Widget with Image + Video Support
// Instagram-style post card with full media capabilities
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../../services/social_feed/comment_service.dart';
import '../../services/social_feed/share_service.dart';
import '../../services/auth/auth_service.dart';
import '../../models/social_feed/comment_model.dart';
import 'dart:html' as html show window;

class EnhancedPostWidget extends StatefulWidget {
  final InstagramPostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;
  final VoidCallback? onViewProfile;

  const EnhancedPostWidget({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onBookmark,
    this.onViewProfile,
  });

  @override
  State<EnhancedPostWidget> createState() => _EnhancedPostWidgetState();
}

class _EnhancedPostWidgetState extends State<EnhancedPostWidget> {
  int _currentMediaIndex = 0;
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void dispose() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
          if (widget.post.commentsCount > 0) _buildCommentsPreview(),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onViewProfile,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.post.authorProfileImageUrl != null
                  ? CachedNetworkImageProvider(widget.post.authorProfileImageUrl!)
                  : null,
              child: widget.post.authorProfileImageUrl == null
                  ? Text(
                      widget.post.authorName.isNotEmpty
                          ? widget.post.authorName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.onViewProfile,
                  child: Text(
                    widget.post.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (widget.post.locationTag != null)
                  Text(
                    widget.post.locationTag!.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showMoreOptions(context),
            icon: const Icon(Icons.more_vert),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    if (!widget.post.hasMedia) {
      return const SizedBox.shrink();
    }

    final totalMedia = widget.post.mediaItems.length;

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: PageView.builder(
            itemCount: totalMedia,
            onPageChanged: (index) {
              setState(() => _currentMediaIndex = index);
            },
            itemBuilder: (context, index) {
              final mediaItem = widget.post.mediaItems[index];

              if (mediaItem.type == MediaType.video) {
                return _buildVideoPlayer(mediaItem.url, index);
              } else {
                return _buildImageViewer(mediaItem.url);
              }
            },
          ),
        ),
        if (totalMedia > 1) _buildMediaIndicator(totalMedia),
      ],
    );
  }

  Widget _buildImageViewer(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheHeight: 800, // Performance: Limit memory cache height
      memCacheWidth: 800, // Performance: Limit memory cache width
      maxHeightDiskCache: 1000, // Performance: Limit disk cache
      maxWidthDiskCache: 1000, // Performance: Limit disk cache
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl, int index) {
    if (!_videoControllers.containsKey(index)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
      _videoControllers[index] = controller;
    }

    final controller = _videoControllers[index]!;

    return Stack(
      alignment: Alignment.center,
      children: [
        controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              )
            : Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
        if (controller.value.isInitialized)
          GestureDetector(
            onTap: () {
              setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaIndicator(int totalMedia) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${_currentMediaIndex + 1}/$totalMedia',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onLike,
            icon: Icon(
              widget.post.isLikedByCurrentUser
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: widget.post.isLikedByCurrentUser
                  ? Colors.red
                  : Colors.black,
            ),
            iconSize: 28,
          ),
          IconButton(
            onPressed: () {
              _showCommentsSheet();
              widget.onComment?.call();
            },
            icon: const Icon(Icons.chat_bubble_outline),
            iconSize: 28,
          ),
          IconButton(
            onPressed: () {
              _showShareDialog();
            },
            icon: const Icon(Icons.send_outlined),
            iconSize: 28,
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onBookmark,
            icon: Icon(
              widget.post.isBookmarkedByCurrentUser
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            iconSize: 28,
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
        '${widget.post.likesCount} ${widget.post.likesCount == 1 ? 'like' : 'likes'}',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCaption() {
    if (widget.post.caption.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(
              text: '${widget.post.authorName} ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: widget.post.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () {
          _showCommentsSheet();
          widget.onComment?.call();
        },
        child: Text(
          'View all ${widget.post.commentsCount} comments',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTimestamp() {
    final now = DateTime.now();
    final difference = now.difference(widget.post.createdAt);

    String timeAgo;
    if (difference.inDays > 0) {
      timeAgo = '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      timeAgo = '${difference.inMinutes}m ago';
    } else {
      timeAgo = 'Just now';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        timeAgo,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Link'),
              onTap: () async {
                Navigator.pop(context);
                await _handleCopyLink();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _showShareDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Report', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement report
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCopyLink() async {
    try {
      await ShareService().copyPostLink(widget.post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showShareDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
              
              // Social Media Platforms
              if (kIsWeb) ...[
                ListTile(
                  leading: Icon(Icons.chat, color: Colors.green[700]),
                  title: const Text('WhatsApp'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _shareToWhatsApp();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.facebook, color: Colors.blue[800]),
                  title: const Text('Facebook'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _shareToFacebook();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.alternate_email, color: Colors.blue[400]),
                  title: const Text('Twitter'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _shareToTwitter();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.business, color: Colors.blue[700]),
                  title: const Text('LinkedIn'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _shareToLinkedIn();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.send, color: Colors.blue[600]),
                  title: const Text('Telegram'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _shareToTelegram();
                  },
                ),
                const Divider(height: 1),
              ] else
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
                leading: const Icon(Icons.link, color: Colors.blue),
                title: const Text('Copy Link'),
                onTap: () async {
                  Navigator.pop(context);
                  await _handleCopyLink();
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
      ),
    );
  }

  Future<void> _shareViaEmail() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showLoginRequired();
        return;
      }

      await ShareService().shareViaEmail(widget.post.id, widget.post.caption);
      await ShareService().sharePost(widget.post.id, shareType: 'email', platform: 'email');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email content copied to clipboard!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      widget.onShare?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share via email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareToSocialMedia() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showLoginRequired();
        return;
      }

      await ShareService().shareToNativePlatforms(
        postId: widget.post.id,
        postContent: widget.post.caption,
        authorName: widget.post.authorName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content copied! Paste in your favorite app.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
      widget.onShare?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareToWhatsApp() async {
    try {
      final link = ShareService().getShareLink(widget.post.id);
      final text = '${widget.post.authorName} shared: ${widget.post.caption}\n\nView on TALOWA: $link';
      final url = ShareService().getWhatsAppShareUrl(text);
      
      await _openUrl(url);
      await ShareService().sharePost(widget.post.id, shareType: 'whatsapp', platform: 'whatsapp');
      widget.onShare?.call();
    } catch (e) {
      _showError('Failed to share to WhatsApp: $e');
    }
  }

  Future<void> _shareToFacebook() async {
    try {
      final link = ShareService().getShareLink(widget.post.id);
      final url = ShareService().getFacebookShareUrl(link);
      
      await _openUrl(url);
      await ShareService().sharePost(widget.post.id, shareType: 'facebook', platform: 'facebook');
      widget.onShare?.call();
    } catch (e) {
      _showError('Failed to share to Facebook: $e');
    }
  }

  Future<void> _shareToTwitter() async {
    try {
      final link = ShareService().getShareLink(widget.post.id);
      final text = '${widget.post.caption.substring(0, widget.post.caption.length > 200 ? 200 : widget.post.caption.length)}...';
      final url = ShareService().getTwitterShareUrl(text, link);
      
      await _openUrl(url);
      await ShareService().sharePost(widget.post.id, shareType: 'twitter', platform: 'twitter');
      widget.onShare?.call();
    } catch (e) {
      _showError('Failed to share to Twitter: $e');
    }
  }

  Future<void> _shareToLinkedIn() async {
    try {
      final link = ShareService().getShareLink(widget.post.id);
      final url = ShareService().getLinkedInShareUrl(link);
      
      await _openUrl(url);
      await ShareService().sharePost(widget.post.id, shareType: 'linkedin', platform: 'linkedin');
      widget.onShare?.call();
    } catch (e) {
      _showError('Failed to share to LinkedIn: $e');
    }
  }

  Future<void> _shareToTelegram() async {
    try {
      final link = ShareService().getShareLink(widget.post.id);
      final text = '${widget.post.authorName} shared: ${widget.post.caption}';
      final url = ShareService().getTelegramShareUrl(text, link);
      
      await _openUrl(url);
      await ShareService().sharePost(widget.post.id, shareType: 'telegram', platform: 'telegram');
      widget.onShare?.call();
    } catch (e) {
      _showError('Failed to share to Telegram: $e');
    }
  }

  Future<void> _openUrl(String url) async {
    if (kIsWeb) {
      // On web, open in new tab
      html.window.open(url, '_blank');
    } else {
      // On mobile, use url_launcher (would need to be added)
      // For now, copy URL
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Share URL copied to clipboard!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareToFeed() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showLoginRequired();
        return;
      }

      await ShareService().sharePost(widget.post.id, shareType: 'feed', platform: 'talowa');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      widget.onShare?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLoginRequired() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to share posts'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true, // Allow dismissing by tapping outside
      enableDrag: true, // Allow dragging down to close
      builder: (context) => _CommentsBottomSheet(
        postId: widget.post.id,
        initialCommentsCount: widget.post.commentsCount,
        onCommentAdded: () {
          widget.onComment?.call();
        },
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
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, size: 16),
          ),
          const SizedBox(width: 12),
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
          _isSending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  onPressed: _sendComment,
                  icon: const Icon(
                    Icons.send,
                    color: Colors.blue,
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
