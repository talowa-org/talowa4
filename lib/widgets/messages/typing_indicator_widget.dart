// Typing Indicator Widget for TALOWA Messaging
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TypingIndicatorWidget extends StatefulWidget {
  final List<String> typingUsers;
  final bool isVisible;

  const TypingIndicatorWidget({
    super.key,
    required this.typingUsers,
    this.isVisible = true,
  });

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    if (widget.isVisible && widget.typingUsers.isNotEmpty) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(TypingIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible && widget.typingUsers.isNotEmpty) {
      if (!_animationController.isCompleted) {
        _animationController.forward();
      }
    } else {
      if (_animationController.isCompleted) {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || widget.typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.talowaGreen.withOpacity(0.2),
                child: const Icon(
                  Icons.person,
                  size: 14,
                  color: AppTheme.talowaGreen,
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Typing indicator bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomLeft: const Radius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Typing text
                    Text(
                      _getTypingText(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Animated dots
                    _buildTypingDots(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingDots() {
    return SizedBox(
      width: 24,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          return _TypingDot(
            delay: Duration(milliseconds: index * 200),
          );
        }),
      ),
    );
  }

  String _getTypingText() {
    if (widget.typingUsers.isEmpty) return '';
    
    if (widget.typingUsers.length == 1) {
      return '${widget.typingUsers.first} is typing';
    } else if (widget.typingUsers.length == 2) {
      return '${widget.typingUsers.first} and ${widget.typingUsers.last} are typing';
    } else {
      return '${widget.typingUsers.first} and ${widget.typingUsers.length - 1} others are typing';
    }
  }
}

class _TypingDot extends StatefulWidget {
  final Duration delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
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

    // Start animation with delay
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
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppTheme.talowaGreen,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// Typing Status Manager
class TypingStatusManager {
  static final Map<String, Set<String>> _typingUsers = {};
  static final Map<String, Function(List<String>)> _listeners = {};

  static void startTyping(String conversationId, String userId, String userName) {
    _typingUsers.putIfAbsent(conversationId, () => <String>{});
    _typingUsers[conversationId]!.add(userName);
    _notifyListeners(conversationId);

    // Auto-stop typing after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      stopTyping(conversationId, userId, userName);
    });
  }

  static void stopTyping(String conversationId, String userId, String userName) {
    if (_typingUsers.containsKey(conversationId)) {
      _typingUsers[conversationId]!.remove(userName);
      if (_typingUsers[conversationId]!.isEmpty) {
        _typingUsers.remove(conversationId);
      }
      _notifyListeners(conversationId);
    }
  }

  static void addListener(String conversationId, Function(List<String>) listener) {
    _listeners[conversationId] = listener;
  }

  static void removeListener(String conversationId) {
    _listeners.remove(conversationId);
  }

  static void _notifyListeners(String conversationId) {
    if (_listeners.containsKey(conversationId)) {
      final typingUsers = _typingUsers[conversationId]?.toList() ?? [];
      _listeners[conversationId]!(typingUsers);
    }
  }

  static List<String> getTypingUsers(String conversationId) {
    return _typingUsers[conversationId]?.toList() ?? [];
  }

  static void clear() {
    _typingUsers.clear();
    _listeners.clear();
  }
}