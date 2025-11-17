// Presence Indicator Widgets for TALOWA Messaging System
// Requirements: 6.4 - Add status indicators throughout the UI

import 'package:flutter/material.dart';
import '../../models/messaging/presence_model.dart';
import '../../services/messaging/presence_service.dart';

/// Simple online/offline status indicator
class PresenceIndicator extends StatelessWidget {
  final String userId;
  final double size;
  final bool showBorder;
  final Color? borderColor;

  const PresenceIndicator({
    super.key,
    required this.userId,
    this.size = 12.0,
    this.showBorder = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserPresence>(
      stream: PresenceService().presenceUpdateStream
          .where((presence) => presence.userId == userId),
      builder: (context, snapshot) {
        return FutureBuilder<UserPresence?>(
          future: PresenceService().getUserPresence(userId),
          builder: (context, presenceSnapshot) {
            final presence = snapshot.data ?? presenceSnapshot.data;
            
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getStatusColor(presence),
                border: showBorder
                    ? Border.all(
                        color: borderColor ?? Colors.white,
                        width: 2.0,
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(UserPresence? presence) {
    if (presence == null || !presence.isOnline) {
      return Colors.grey;
    }

    switch (presence.customStatus) {
      case PresenceStatus.available:
        return Colors.green;
      case PresenceStatus.busy:
        return Colors.red;
      case PresenceStatus.away:
        return Colors.orange;
      case PresenceStatus.doNotDisturb:
        return Colors.red.shade800;
      case PresenceStatus.invisible:
        return Colors.grey;
      case null:
        return Colors.green;
    }
  }
}

/// Detailed presence status widget with text
class PresenceStatusWidget extends StatelessWidget {
  final String userId;
  final bool showStatusMessage;
  final TextStyle? textStyle;
  final MainAxisAlignment alignment;

  const PresenceStatusWidget({
    super.key,
    required this.userId,
    this.showStatusMessage = true,
    this.textStyle,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserPresence>(
      stream: PresenceService().presenceUpdateStream
          .where((presence) => presence.userId == userId),
      builder: (context, snapshot) {
        return FutureBuilder<UserPresence?>(
          future: PresenceService().getUserPresence(userId),
          builder: (context, presenceSnapshot) {
            final presence = snapshot.data ?? presenceSnapshot.data;
            
            return Row(
              mainAxisAlignment: alignment,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  presence?.statusEmoji ?? '⚫',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        presence?.displayStatus ?? 'Offline',
                        style: textStyle ?? Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showStatusMessage && 
                          presence?.statusMessage != null &&
                          presence!.statusMessage!.isNotEmpty)
                        Text(
                          presence.statusMessage!,
                          style: (textStyle ?? Theme.of(context).textTheme.bodySmall)
                              ?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontSize: (textStyle?.fontSize ?? 12) - 1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// User avatar with presence indicator overlay
class UserAvatarWithPresence extends StatelessWidget {
  final String userId;
  final String? userImageUrl;
  final String userName;
  final double radius;
  final bool showPresence;

  const UserAvatarWithPresence({
    super.key,
    required this.userId,
    this.userImageUrl,
    required this.userName,
    this.radius = 20.0,
    this.showPresence = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundImage: userImageUrl != null
              ? NetworkImage(userImageUrl!)
              : null,
          child: userImageUrl == null
              ? Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: radius * 0.8,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        if (showPresence)
          Positioned(
            right: 0,
            bottom: 0,
            child: PresenceIndicator(
              userId: userId,
              size: radius * 0.6,
            ),
          ),
      ],
    );
  }
}

/// Typing indicator widget
class TypingIndicatorWidget extends StatefulWidget {
  final String conversationId;
  final List<String> excludeUserIds;

  const TypingIndicatorWidget({
    super.key,
    required this.conversationId,
    this.excludeUserIds = const [],
  });

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TypingIndicator>>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) async {
        // This is a simplified implementation for demo purposes
        // In a real implementation, you would use the actual typing indicators stream
        return <TypingIndicator>[];
      }).asyncMap((future) => future),
      builder: (context, snapshot) {
        final typingUsers = snapshot.data ?? [];
        
        if (typingUsers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        child: Opacity(
                          opacity: (_animation.value + index * 0.3) % 1.0,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                _getTypingText(typingUsers.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTypingText(int count) {
    if (count == 1) {
      return 'Someone is typing...';
    } else if (count == 2) {
      return '2 people are typing...';
    } else {
      return '$count people are typing...';
    }
  }
}

/// Custom status selector widget
class CustomStatusSelector extends StatefulWidget {
  final PresenceStatus? currentStatus;
  final String? currentMessage;
  final Function(PresenceStatus?, String?) onStatusChanged;

  const CustomStatusSelector({
    super.key,
    this.currentStatus,
    this.currentMessage,
    required this.onStatusChanged,
  });

  @override
  State<CustomStatusSelector> createState() => _CustomStatusSelectorState();
}

class _CustomStatusSelectorState extends State<CustomStatusSelector> {
  late TextEditingController _messageController;
  PresenceStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.currentMessage);
    _selectedStatus = widget.currentStatus;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set your status',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        
        // Status options
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PresenceStatus.values.map((status) {
            final isSelected = _selectedStatus == status;
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status.emoji),
                  const SizedBox(width: 4),
                  Text(status.displayName),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedStatus = selected ? status : null;
                });
              },
            );
          }).toList(),
        ),
        
        const SizedBox(height: 16),
        
        // Status message input
        TextField(
          controller: _messageController,
          decoration: const InputDecoration(
            labelText: 'Status message (optional)',
            hintText: 'What\'s on your mind?',
            border: OutlineInputBorder(),
          ),
          maxLength: 100,
          maxLines: 2,
        ),
        
        const SizedBox(height: 16),
        
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = null;
                  _messageController.clear();
                });
                widget.onStatusChanged(null, null);
              },
              child: const Text('Clear'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                widget.onStatusChanged(
                  _selectedStatus,
                  _messageController.text.trim().isEmpty
                      ? null
                      : _messageController.text.trim(),
                );
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Online users count widget
class OnlineUsersCountWidget extends StatelessWidget {
  final TextStyle? textStyle;
  final Duration refreshInterval;

  const OnlineUsersCountWidget({
    super.key,
    this.textStyle,
    this.refreshInterval = const Duration(minutes: 1),
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(refreshInterval, (_) async {
        return await PresenceService().getOnlineUsersCount();
      }).asyncMap((future) => future),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.circle,
              color: Colors.green,
              size: 8,
            ),
            const SizedBox(width: 4),
            Text(
              '$count online',
              style: textStyle ?? Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}