// Animated Post Widget - Provides smooth animations for real-time post updates
// Part of Task 13: Implement real-time feed updates

import 'package:flutter/material.dart';
import '../../models/social_feed/post_model.dart';
import '../social_feed/post_widget.dart';

class AnimatedPostWidget extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onUserTap;
  final VoidCallback? onPostTap;
  final String? highlightQuery;
  final bool isNew;

  const AnimatedPostWidget({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onUserTap,
    this.onPostTap,
    this.highlightQuery,
    this.isNew = false,
  });

  @override
  State<AnimatedPostWidget> createState() => _AnimatedPostWidgetState();
}

class _AnimatedPostWidgetState extends State<AnimatedPostWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _highlightController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Color?> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Initialize animations
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _highlightAnimation = ColorTween(
      begin: Colors.blue.withOpacity(0.1),
      end: Colors.transparent,
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeOut,
    ));
    
    // Start animations
    _startAnimations();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    if (widget.isNew) {
      // Animate new posts sliding in from top
      _slideController.forward();
      _fadeController.forward();
      
      // Add highlight effect for new posts
      _highlightController.forward();
    } else {
      // Existing posts appear immediately
      _slideController.value = 1.0;
      _fadeController.value = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: AnimatedBuilder(
          animation: _highlightAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: _highlightAnimation.value,
                borderRadius: BorderRadius.circular(8),
              ),
              child: PostWidget(
                post: widget.post,
                onLike: widget.onLike,
                onComment: widget.onComment,
                onShare: widget.onShare,
                onUserTap: widget.onUserTap,
                onPostTap: widget.onPostTap,
                highlightQuery: widget.highlightQuery,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Widget for animating post updates (like count changes, etc.)
class AnimatedPostUpdateWidget extends StatefulWidget {
  final Widget child;
  final bool hasUpdate;

  const AnimatedPostUpdateWidget({
    super.key,
    required this.child,
    this.hasUpdate = false,
  });

  @override
  State<AnimatedPostUpdateWidget> createState() => _AnimatedPostUpdateWidgetState();
}

class _AnimatedPostUpdateWidgetState extends State<AnimatedPostUpdateWidget>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedPostUpdateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.hasUpdate && !oldWidget.hasUpdate) {
      _pulseController.forward().then((_) {
        _pulseController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: widget.child,
    );
  }
}

/// Widget for showing real-time typing indicators
class TypingIndicatorWidget extends StatefulWidget {
  final bool isVisible;
  final String userName;

  const TypingIndicatorWidget({
    super.key,
    required this.isVisible,
    required this.userName,
  });

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _dotsController;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _dotAnimations = List.generate(3, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _dotsController,
        curve: Interval(
          index * 0.2,
          (index * 0.2) + 0.4,
          curve: Curves.easeInOut,
        ),
      ));
    });
    
    if (widget.isVisible) {
      _dotsController.repeat();
    }
  }

  @override
  void didUpdateWidget(TypingIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible && !oldWidget.isVisible) {
      _dotsController.repeat();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _dotsController.stop();
    }
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${widget.userName} is typing',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _dotAnimations[index],
                builder: (context, child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    child: Opacity(
                      opacity: _dotAnimations[index].value,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}