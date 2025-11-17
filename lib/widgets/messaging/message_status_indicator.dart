// Message Status Indicator Widget
// Shows visual indicators for message delivery status
// Requirements: 2.2, 2.3, 2.4

import 'package:flutter/material.dart';
import '../../models/messaging/message_status_model.dart';

/// Widget to display message delivery status with visual indicators
class MessageStatusIndicator extends StatelessWidget {
  final MessageStatus status;
  final bool isRead;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool showTimestamp;
  final Color? readColor;
  final Color? deliveredColor;
  final Color? sentColor;
  final Color? failedColor;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    this.isRead = false,
    this.deliveredAt,
    this.readAt,
    this.showTimestamp = false,
    this.readColor,
    this.deliveredColor,
    this.sentColor,
    this.failedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIcon(context),
        if (showTimestamp) ...[
          const SizedBox(width: 4),
          _buildTimestamp(context),
        ],
      ],
    );
  }

  /// Build status icon based on message status
  Widget _buildStatusIcon(BuildContext context) {
    final theme = Theme.of(context);
    
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary.withOpacity(0.6),
            ),
          ),
        );

      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 16,
          color: sentColor ?? theme.colorScheme.outline,
        );

      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 16,
          color: deliveredColor ?? theme.colorScheme.outline,
        );

      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 16,
          color: readColor ?? theme.colorScheme.primary,
        );

      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 16,
          color: failedColor ?? theme.colorScheme.error,
        );
    }
  }

  /// Build timestamp text
  Widget _buildTimestamp(BuildContext context) {
    final theme = Theme.of(context);
    DateTime? timestampToShow;
    
    if (readAt != null) {
      timestampToShow = readAt;
    } else if (deliveredAt != null) {
      timestampToShow = deliveredAt;
    }

    if (timestampToShow == null) return const SizedBox.shrink();

    return Text(
      _formatTimestamp(timestampToShow),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
        fontSize: 10,
      ),
    );
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
}

/// Animated message status indicator that updates in real-time
class AnimatedMessageStatusIndicator extends StatefulWidget {
  final Stream<MessageStatusModel?> statusStream;
  final bool showTimestamp;
  final Color? readColor;
  final Color? deliveredColor;
  final Color? sentColor;
  final Color? failedColor;

  const AnimatedMessageStatusIndicator({
    super.key,
    required this.statusStream,
    this.showTimestamp = false,
    this.readColor,
    this.deliveredColor,
    this.sentColor,
    this.failedColor,
  });

  @override
  State<AnimatedMessageStatusIndicator> createState() => 
      _AnimatedMessageStatusIndicatorState();
}

class _AnimatedMessageStatusIndicatorState 
    extends State<AnimatedMessageStatusIndicator>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  MessageStatusModel? _currentStatus;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MessageStatusModel?>(
      stream: widget.statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data;
        
        // Animate when status changes
        if (status != null && status != _currentStatus) {
          _currentStatus = status;
          _animationController.forward(from: 0);
        }

        if (status == null) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: MessageStatusIndicator(
                status: status.status,
                isRead: status.isRead,
                deliveredAt: status.deliveredAt,
                readAt: status.readAt,
                showTimestamp: widget.showTimestamp,
                readColor: widget.readColor,
                deliveredColor: widget.deliveredColor,
                sentColor: widget.sentColor,
                failedColor: widget.failedColor,
              ),
            );
          },
        );
      },
    );
  }
}

/// Typing indicator widget
class TypingIndicator extends StatefulWidget {
  final List<String> typingUsers;
  final Color? dotColor;
  final double dotSize;

  const TypingIndicator({
    super.key,
    required this.typingUsers,
    this.dotColor,
    this.dotSize = 4.0,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationControllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations = _animationControllers.map((controller) {
      return Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with staggered delays
    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _animationControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final dotColor = widget.dotColor ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getTypingText(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _animations[index],
                builder: (context, child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    child: Opacity(
                      opacity: _animations[index].value,
                      child: Container(
                        width: widget.dotSize,
                        height: widget.dotSize,
                        decoration: BoxDecoration(
                          color: dotColor,
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

  String _getTypingText() {
    if (widget.typingUsers.length == 1) {
      return '${widget.typingUsers.first} is typing';
    } else if (widget.typingUsers.length == 2) {
      return '${widget.typingUsers.join(' and ')} are typing';
    } else {
      return '${widget.typingUsers.length} people are typing';
    }
  }
}