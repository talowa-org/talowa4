// Enhanced Post Widget with Image + Video Support
// Instagram-style post card with full media capabilities
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../models/social_feed/instagram_post_model.dart';

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
                  color: Colors.white.withOpacity(0.8),
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
            onPressed: widget.onComment,
            icon: const Icon(Icons.chat_bubble_outline),
            iconSize: 28,
          ),
          IconButton(
            onPressed: widget.onShare,
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
        onTap: widget.onComment,
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
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement copy link
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                widget.onShare?.call();
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
}
