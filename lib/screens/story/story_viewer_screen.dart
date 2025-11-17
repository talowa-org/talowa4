// Story Viewer Screen - Instagram-style story viewer
// Supports images, videos, and text stories

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../models/social_feed/story_model.dart';
import '../../services/social_feed/stories_service.dart';
import '../../widgets/stories/story_progress_indicator.dart';
import 'dart:async';

class StoryViewerScreen extends StatefulWidget {
  final UserStoriesGroup storyGroup;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.storyGroup,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  final StoriesService _storiesService = StoriesService();
  
  int _currentStoryIndex = 0;
  VideoPlayerController? _videoController;
  bool _isPaused = false;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _currentStoryIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentStoryIndex);
    _progressController = AnimationController(vsync: this);
    
    _loadStory(_currentStoryIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _videoController?.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _loadStory(int index) {
    if (index >= widget.storyGroup.stories.length) {
      Navigator.pop(context);
      return;
    }

    final story = widget.storyGroup.stories[index];
    
    // Mark story as viewed
    _storiesService.markStoryAsViewed(story.id);

    // Dispose previous video controller
    _videoController?.dispose();
    _videoController = null;

    if (story.mediaType == StoryMediaType.video && story.mediaUrl != null) {
      _loadVideo(story.mediaUrl!);
    } else {
      _startProgress(const Duration(seconds: 5));
    }
  }

  void _loadVideo(String url) {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.play();
          _startProgress(_videoController!.value.duration);
        }
      });
  }

  void _startProgress(Duration duration) {
    _progressController.duration = duration;
    _progressController.forward(from: 0).then((_) {
      if (!_isPaused) {
        _nextStory();
      }
    });
  }

  void _pauseStory() {
    setState(() => _isPaused = true);
    _progressController.stop();
    _videoController?.pause();
  }

  void _resumeStory() {
    setState(() => _isPaused = false);
    _progressController.forward();
    _videoController?.play();
  }

  void _nextStory() {
    if (_currentStoryIndex < widget.storyGroup.stories.length - 1) {
      setState(() => _currentStoryIndex++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() => _currentStoryIndex--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _previousStory();
          } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
            _nextStory();
          } else {
            if (_isPaused) {
              _resumeStory();
            } else {
              _pauseStory();
            }
          }
        },
        child: Stack(
          children: [
            // Story content
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.storyGroup.stories.length,
              onPageChanged: (index) {
                setState(() => _currentStoryIndex = index);
                _loadStory(index);
              },
              itemBuilder: (context, index) {
                return _buildStoryContent(widget.storyGroup.stories[index]);
              },
            ),

            // Top gradient overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Progress indicators
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: StoryProgressIndicator(
                storyCount: widget.storyGroup.stories.length,
                currentIndex: _currentStoryIndex,
                progress: _progressController.value,
              ),
            ),

            // Header
            Positioned(
              top: MediaQuery.of(context).padding.top + 32,
              left: 8,
              right: 8,
              child: _buildHeader(),
            ),

            // Caption
            if (widget.storyGroup.stories[_currentStoryIndex].caption != null)
              Positioned(
                bottom: 80,
                left: 16,
                right: 16,
                child: _buildCaption(
                  widget.storyGroup.stories[_currentStoryIndex].caption!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(StoryModel story) {
    switch (story.mediaType) {
      case StoryMediaType.text:
        return Container(
          color: story.backgroundColor ?? const Color(0xFF6200EA),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                story.textContent ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
        
      case StoryMediaType.image:
        if (story.mediaUrl == null) {
          return const Center(
            child: Icon(Icons.error, color: Colors.white, size: 48),
          );
        }
        return CachedNetworkImage(
          imageUrl: story.mediaUrl!,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (context, url, error) => const Center(
            child: Icon(Icons.error, color: Colors.white, size: 48),
          ),
        );

      case StoryMediaType.video:
        if (_videoController != null && _videoController!.value.isInitialized) {
          return Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
    }
  }

  Widget _buildHeader() {
    final story = widget.storyGroup.stories[_currentStoryIndex];
    final timeAgo = _formatTimeAgo(story.createdAt);

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          backgroundImage: widget.storyGroup.userProfileImage != null
              ? CachedNetworkImageProvider(widget.storyGroup.userProfileImage!)
              : null,
          child: widget.storyGroup.userProfileImage == null
              ? Text(
                  widget.storyGroup.userName[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.storyGroup.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                timeAgo,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildCaption(String caption) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        caption,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
