// Real-time Engagement Widget for TALOWA Social Feed
// Implements Task 15: Add real-time engagement features - UI Components

import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/social_feed/real_time_engagement_service.dart';
import '../../core/theme/app_theme.dart';

class RealTimeEngagementWidget extends StatefulWidget {
  final String postId;
  final int initialLikes;
  final int initialComments;
  final int initialShares;
  final int initialViews;
  final bool isLiked;
  final bool isShared;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const RealTimeEngagementWidget({
    super.key,
    required this.postId,
    required this.initialLikes,
    required this.initialComments,
    required this.initialShares,
    required this.initialViews,
    required this.isLiked,
    required this.isShared,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<RealTimeEngagementWidget> createState() => _RealTimeEngagementWidgetState();
}

class _RealTimeEngagementWidgetState extends State<RealTimeEngagementWidget>
    with TickerProviderStateMixin {
  final RealTimeEngagementService _engagementService = RealTimeEngagementService();
  
  late StreamSubscription _engagementSubscription;
  late AnimationController _likeAnimationController;
  late AnimationController _shareAnimationController;
  late Animation<double> _likeScaleAnimation;
  late Animation<double> _shareScaleAnimation;
  late Animation<Color?> _likeColorAnimation;

  int _likesCount = 0;
  int _commentsCount = 0;
  int _sharesCount = 0;
  int _viewsCount = 0;
  bool _isLiked = false;
  bool _isShared = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize values
    _likesCount = widget.initialLikes;
    _commentsCount = widget.initialComments;
    _sharesCount = widget.initialShares;
    _viewsCount = widget.initialViews;
    _isLiked = widget.isLiked;
    _isShared = widget.isShared;

    // Initialize animations
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _shareAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _likeScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));

    _shareScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _shareAnimationController,
      curve: Curves.easeInOut,
    ));

    _likeColorAnimation = ColorTween(
      begin: Colors.grey[600],
      end: Colors.red,
    ).animate(_likeAnimationController);

    // Start listening to real-time updates
    _startEngagementTracking();
  }

  void _startEngagementTracking() {
    _engagementService.startEngagementTracking(widget.postId);
    
    _engagementSubscription = _engagementService.engagementUpdates
        .where((update) => update.postId == widget.postId)
        .listen((update) {
      if (mounted) {
        setState(() {
          _likesCount = update.likesCount;
          _commentsCount = update.commentsCount;
          _sharesCount = update.sharesCount;
          _viewsCount = update.viewsCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _engagementSubscription.cancel();
    _engagementService.stopEngagementTracking(widget.postId);
    _likeAnimationController.dispose();
    _shareAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Like Button with Animation
        _buildAnimatedLikeButton(),
        
        // Comment Button with Badge
        _buildCommentButton(),
        
        // Share Button with Animation
        _buildAnimatedShareButton(),
        
        const Spacer(),
        
        // View Count
        if (_viewsCount > 0)
          Text(
            '${_formatCount(_viewsCount)} views',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Widget _buildAnimatedLikeButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _likeScaleAnimation,
          child: IconButton(
            onPressed: _isAnimating ? null : _handleLike,
            icon: AnimatedBuilder(
              animation: _likeColorAnimation,
              builder: (context, child) {
                return Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : _likeColorAnimation.value,
                );
              },
            ),
            tooltip: _isLiked ? 'Unlike' : 'Like',
          ),
        ),
        if (_likesCount > 0) ...[
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _formatCount(_likesCount),
              key: ValueKey(_likesCount),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _isLiked ? Colors.red : Colors.grey[600],
                fontWeight: _isLiked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            IconButton(
              onPressed: widget.onComment,
              icon: Icon(Icons.comment_outlined, color: Colors.grey[600]),
              tooltip: 'Comment',
            ),
            if (_commentsCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.talowaGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _commentsCount > 99 ? '99+' : _commentsCount.toString(),
                      key: ValueKey(_commentsCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_commentsCount > 0) ...[
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _formatCount(_commentsCount),
              key: ValueKey(_commentsCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnimatedShareButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _shareScaleAnimation,
          child: IconButton(
            onPressed: _isAnimating ? null : _handleShare,
            icon: Icon(
              _isShared ? Icons.share : Icons.share_outlined,
              color: _isShared ? AppTheme.talowaGreen : Colors.grey[600],
            ),
            tooltip: 'Share',
          ),
        ),
        if (_sharesCount > 0) ...[
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _formatCount(_sharesCount),
              key: ValueKey(_sharesCount),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _isShared ? AppTheme.talowaGreen : Colors.grey[600],
                fontWeight: _isShared ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleLike() async {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
      _isLiked = !_isLiked;
    });

    // Trigger animation
    if (_isLiked) {
      await _likeAnimationController.forward();
      await _likeAnimationController.reverse();
    }

    // Call the service and callback
    try {
      await _engagementService.likePost(widget.postId);
      widget.onLike();
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !_isLiked;
      });
      if (kDebugMode) {
        debugPrint('Error liking post: $e');
      }
    } finally {
      setState(() {
        _isAnimating = false;
      });
    }
  }

  Future<void> _handleShare() async {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    // Trigger animation
    await _shareAnimationController.forward();
    await _shareAnimationController.reverse();

    // Call the service and callback
    try {
      await _engagementService.sharePost(widget.postId);
      widget.onShare();
      setState(() {
        _isShared = true;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing post: $e');
      }
    } finally {
      setState(() {
        _isAnimating = false;
      });
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

// Typing Indicator Widget
class TypingIndicatorWidget extends StatefulWidget {
  final String postId;

  const TypingIndicatorWidget({
    super.key,
    required this.postId,
  });

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with TickerProviderStateMixin {
  final RealTimeEngagementService _engagementService = RealTimeEngagementService();
  late StreamSubscription _typingSubscription;
  late AnimationController _animationController;
  late Animation<double> _animation;

  List<String> _typingUsers = [];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    _startTypingTracking();
  }

  void _startTypingTracking() {
    _engagementService.startTypingTracking(widget.postId);
    
    _typingSubscription = _engagementService.typingIndicators
        .where((indicator) => indicator.postId == widget.postId)
        .listen((indicator) {
      if (mounted) {
        setState(() {
          _typingUsers = indicator.typingUsers;
        });
      }
    });
  }

  @override
  void dispose() {
    _typingSubscription.cancel();
    _engagementService.stopTypingTracking(widget.postId);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Row(
                children: List.generate(3, (index) {
                  final delay = index * 0.2;
                  final opacity = ((_animation.value + delay) % 1.0);
                  return Container(
                    margin: const EdgeInsets.only(right: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.talowaGreen.withOpacity(opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            _getTypingText(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _getTypingText() {
    if (_typingUsers.length == 1) {
      return 'Someone is typing...';
    } else if (_typingUsers.length == 2) {
      return '2 people are typing...';
    } else {
      return '${_typingUsers.length} people are typing...';
    }
  }
}

// User Presence Indicator Widget
class UserPresenceIndicator extends StatefulWidget {
  final String userId;
  final double size;

  const UserPresenceIndicator({
    super.key,
    required this.userId,
    this.size = 12,
  });

  @override
  State<UserPresenceIndicator> createState() => _UserPresenceIndicatorState();
}

class _UserPresenceIndicatorState extends State<UserPresenceIndicator> {
  final RealTimeEngagementService _engagementService = RealTimeEngagementService();
  late StreamSubscription _presenceSubscription;
  
  bool _isOnline = false;
  DateTime? _lastSeen;

  @override
  void initState() {
    super.initState();
    _startPresenceTracking();
  }

  void _startPresenceTracking() {
    _engagementService.startPresenceTracking([widget.userId]);
    
    _presenceSubscription = _engagementService.userPresence
        .where((presence) => presence.userId == widget.userId)
        .listen((presence) {
      if (mounted) {
        setState(() {
          _isOnline = presence.isOnline;
          _lastSeen = presence.lastSeen;
        });
      }
    });
  }

  @override
  void dispose() {
    _presenceSubscription.cancel();
    _engagementService.stopPresenceTracking(widget.userId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

