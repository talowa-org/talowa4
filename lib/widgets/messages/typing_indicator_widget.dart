// Typing Indicator Widget for Real-time Chat
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TypingIndicatorWidget extends StatefulWidget {
  final List<String> typingUsers;
  final bool isVisible;

  const TypingIndicatorWidget({
    super.key,
    required this.typingUsers,
    required this.isVisible,
  });

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TypingIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.grey[400],
                  child: const Icon(
                    Icons.more_horiz,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getTypingText(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTypingDots(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTypingText() {
    if (widget.typingUsers.isEmpty) {
      return 'Someone is typing';
    } else if (widget.typingUsers.length == 1) {
      return '${widget.typingUsers.first} is typing';
    } else if (widget.typingUsers.length == 2) {
      return '${widget.typingUsers.first} and ${widget.typingUsers.last} are typing';
    } else {
      return '${widget.typingUsers.first} and ${widget.typingUsers.length - 1} others are typing';
    }
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedTypingDot(
          delay: Duration(milliseconds: index * 200),
        );
      }),
    );
  }
}

class AnimatedTypingDot extends StatefulWidget {
  final Duration delay;

  const AnimatedTypingDot({
    super.key,
    required this.delay,
  });

  @override
  State<AnimatedTypingDot> createState() => _AnimatedTypingDotState();
}

class _AnimatedTypingDotState extends State<AnimatedTypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          child: Opacity(
            opacity: _animation.value,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppTheme.talowaGreen,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Typing Status Manager for real-time typing indicators
class TypingStatusManager {
  static final Map<String, List<String>> _typingUsers = {};
  static final Map<String, Function(List<String>)> _listeners = {};

  static void addListener(String conversationId, Function(List<String>) listener) {
    _listeners[conversationId] = listener;
  }

  static void removeListener(String conversationId) {
    _listeners.remove(conversationId);
  }

  static void startTyping(String conversationId, String userId, String userName) {
    if (!_typingUsers.containsKey(conversationId)) {
      _typingUsers[conversationId] = [];
    }

    if (!_typingUsers[conversationId]!.contains(userName)) {
      _typingUsers[conversationId]!.add(userName);
      _notifyListeners(conversationId);
    }

    // Auto-stop typing after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      stopTyping(conversationId, userId, userName);
    });
  }

  static void stopTyping(String conversationId, String userId, String userName) {
    if (_typingUsers.containsKey(conversationId)) {
      _typingUsers[conversationId]!.remove(userName);
      _notifyListeners(conversationId);
    }
  }

  static void _notifyListeners(String conversationId) {
    final listener = _listeners[conversationId];
    if (listener != null) {
      final typingUsers = _typingUsers[conversationId] ?? [];
      listener(List.from(typingUsers));
    }
  }
}