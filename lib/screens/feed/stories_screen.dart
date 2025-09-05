// Instagram-like Stories Screen for TALOWA
// Complete stories viewing experience with gestures and interactions
import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/social_feed/story_model.dart';
import '../../services/social_feed/stories_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/stories/story_progress_indicator.dart';

class StoriesScreen extends StatefulWidget {
  final Map<String, List<StoryModel>> storiesByAuthor;
  final String initialAuthorId;
  final int initialStoryIndex;

  const StoriesScreen({
    super.key,
    required this.storiesByAuthor,
    required this.initialAuthorId,
    this.initialStoryIndex = 0,
  });

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  late AnimationController _scaleController;
  
  Timer? _storyTimer;
  int _currentAuthorIndex = 0;
  int _currentStoryIndex = 0;
  bool _isPaused = false;
  bool _isLoading = true;
  
  List<String> _authorIds = [];
  StoryModel? _currentStory;
  
  // Reaction animation
  final List<ReactionAnimation> _reactions = [];
  
  @override
  void initState() {
    super.initState();
    
    _authorIds = widget.storiesByAuthor.keys.toList();
    _currentAuthorIndex = _authorIds.indexOf(widget.initialAuthorId);
    if (_currentAuthorIndex == -1) _currentAuthorIndex = 0;
    _currentStoryIndex = widget.initialStoryIndex;
    
    _pageController = PageController(initialPage: _currentAuthorIndex);
    _progressController = AnimationController(vsync: this);
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _loadCurrentStory();
  }
  
  @override
  void dispose() {
    _storyTimer?.cancel();
    
    // Dispose all reaction animation controllers
    for (final reaction in _reactions) {
      reaction.animationController.dispose();
    }
    _reactions.clear();
    
    _pageController.dispose();
    _progressController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
  
  void _loadCurrentStory() {
    if (_currentAuthorIndex >= _authorIds.length) {
      Navigator.pop(context);
      return;
    }
    
    final authorId = _authorIds[_currentAuthorIndex];
    final stories = widget.storiesByAuthor[authorId] ?? [];
    
    if (_currentStoryIndex >= stories.length) {
      _nextAuthor();
      return;
    }
    
    setState(() {
      _currentStory = stories[_currentStoryIndex];
      _isLoading = true;
    });
    
    // Mark story as viewed
    if (_currentStory != null) {
      StoriesService().viewStory(_currentStory!.id);
    }
    
    _startStoryTimer();
  }
  
  void _startStoryTimer() {
    _storyTimer?.cancel();
    _progressController.reset();
    
    if (_currentStory == null) return;
    
    final duration = Duration(seconds: _currentStory!.duration);
    
    _progressController.duration = duration;
    _progressController.forward();
    
    _storyTimer = Timer(duration, () {
      if (!_isPaused) {
        _nextStory();
      }
    });
  }
  
  void _pauseStory() {
    setState(() {
      _isPaused = true;
    });
    _storyTimer?.cancel();
    _progressController.stop();
  }
  
  void _resumeStory() {
    setState(() {
      _isPaused = false;
    });
    
    if (_currentStory != null) {
      final remainingDuration = Duration(
        milliseconds: ((_currentStory!.duration * 1000) * 
                      (1 - _progressController.value)).round(),
      );
      
      _progressController.duration = remainingDuration;
      _progressController.forward();
      
      _storyTimer = Timer(remainingDuration, () {
        if (!_isPaused) {
          _nextStory();
        }
      });
    }
  }
  
  void _nextStory() {
    final authorId = _authorIds[_currentAuthorIndex];
    final stories = widget.storiesByAuthor[authorId] ?? [];
    
    if (_currentStoryIndex < stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _loadCurrentStory();
    } else {
      _nextAuthor();
    }
  }
  
  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _loadCurrentStory();
    } else {
      _previousAuthor();
    }
  }
  
  void _nextAuthor() {
    if (_currentAuthorIndex < _authorIds.length - 1) {
      setState(() {
        _currentAuthorIndex++;
        _currentStoryIndex = 0;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _loadCurrentStory();
    } else {
      Navigator.pop(context);
    }
  }
  
  void _previousAuthor() {
    if (_currentAuthorIndex > 0) {
      setState(() {
        _currentAuthorIndex--;
        final authorId = _authorIds[_currentAuthorIndex];
        final stories = widget.storiesByAuthor[authorId] ?? [];
        _currentStoryIndex = stories.length - 1;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _loadCurrentStory();
    } else {
      Navigator.pop(context);
    }
  }
  
  void _addReaction(String emoji, Offset position) {
    if (!mounted) return;
    
    setState(() {
      _reactions.add(ReactionAnimation(
        emoji: emoji,
        position: position,
        animationController: AnimationController(
          vsync: this,
          duration: const Duration(seconds: 2),
        )..forward(),
      ));
    });
    
    // Remove reaction after animation
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _reactions.removeWhere((r) => r.emoji == emoji);
        });
      }
    });
    
    // Send reaction to server
    if (_currentStory != null) {
      StoriesService().reactToStory(_currentStory!.id, emoji);
    }
  }
  
  void _showReactionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            'â¤ï¸', 'ðŸ˜', 'ðŸ˜‚', 'ðŸ˜®', 'ðŸ˜¢', 'ðŸ‘', 'ðŸ”¥', 'ðŸ’ª'
          ].map((emoji) => GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _addReaction(emoji, const Offset(200, 400));
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentAuthorIndex = index;
              _currentStoryIndex = 0;
            });
            _loadCurrentStory();
          },
          itemCount: _authorIds.length,
          itemBuilder: (context, authorIndex) {
            final authorId = _authorIds[authorIndex];
            final stories = widget.storiesByAuthor[authorId] ?? [];
            
            if (stories.isEmpty) return const SizedBox();
            
            return GestureDetector(
              onTapDown: (details) {
                _pauseStory();
                _scaleController.forward();
              },
              onTapUp: (details) {
                _scaleController.reverse();
                
                final screenWidth = MediaQuery.of(context).size.width;
                final tapX = details.localPosition.dx;
                
                if (tapX < screenWidth * 0.3) {
                  _previousStory();
                } else if (tapX > screenWidth * 0.7) {
                  _nextStory();
                } else {
                  _resumeStory();
                }
              },
              onTapCancel: () {
                _scaleController.reverse();
                _resumeStory();
              },
              onLongPress: () {
                _pauseStory();
              },
              onLongPressEnd: (details) {
                _resumeStory();
              },
              child: AnimatedBuilder(
                animation: _scaleController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 - (_scaleController.value * 0.05),
                    child: _buildStoryContent(stories),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildStoryContent(List<StoryModel> stories) {
    if (_currentStory == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    
    return Stack(
      children: [
        // Story Media
        Positioned.fill(
          child: _buildStoryMedia(),
        ),
        
        // Progress Indicators
        Positioned(
          top: 20,
          left: 8,
          right: 8,
          child: StoryProgressIndicator(
            storyCount: stories.length,
            currentIndex: _currentStoryIndex,
            animationController: _progressController,
          ),
        ),
        
        // Story Header
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          child: _buildStoryHeader(),
        ),
        
        // Story Caption
        if (_currentStory!.caption != null)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _buildStoryCaption(),
          ),
        
        // Story Actions
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: _buildStoryActions(),
        ),
        
        // Reactions Overlay
        ..._reactions.map((reaction) => _buildReactionAnimation(reaction)),
        
        // Loading Overlay
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildStoryMedia() {
    if (_currentStory!.mediaType == 'video') {
      // TODO: Implement video player
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 80,
          ),
        ),
      );
    } else {
      return Image.network(
        _currentStory!.mediaUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _isLoading = false;
              });
            });
            return child;
          }
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 80,
              ),
            ),
          );
        },
      );
    }
  }
  

  
  Widget _buildStoryHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.talowaGreen,
          child: Text(
            _currentStory!.authorName.isNotEmpty 
                ? _currentStory!.authorName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentStory!.authorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                _formatTime(_currentStory!.createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.close,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStoryCaption() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _currentStory!.caption!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }
  
  Widget _buildStoryActions() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Text(
              'Send message',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _showReactionPicker,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.favorite_border,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            // TODO: Implement share functionality
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.send,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildReactionAnimation(ReactionAnimation reaction) {
    return AnimatedBuilder(
      animation: reaction.animationController,
      builder: (context, child) {
        final value = reaction.animationController.value;
        return Positioned(
          left: reaction.position.dx + (value * 50),
          top: reaction.position.dy - (value * 100),
          child: Opacity(
            opacity: 1.0 - value,
            child: Transform.scale(
              scale: 1.0 + (value * 0.5),
              child: Text(
                reaction.emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
}

class ReactionAnimation {
  final String emoji;
  final Offset position;
  final AnimationController animationController;
  
  ReactionAnimation({
    required this.emoji,
    required this.position,
    required this.animationController,
  });
}
