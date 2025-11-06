// Messaging Search Integration Widget for TALOWA
// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
// Task: Integration widget for search functionality in messaging interface

import 'package:flutter/material.dart';
import '../../models/messaging/message_model.dart';
import '../../models/user_model.dart';
import '../../services/messaging/messaging_service.dart';
import 'search/messaging_search_widget.dart';

/// Integration widget for messaging search functionality
class MessagingSearchIntegrationWidget extends StatefulWidget {
  final Function(UserModel)? onUserSelected;
  final Function(MessageModel)? onMessageSelected;
  final bool showAsBottomSheet;

  const MessagingSearchIntegrationWidget({
    Key? key,
    this.onUserSelected,
    this.onMessageSelected,
    this.showAsBottomSheet = false,
  }) : super(key: key);

  @override
  State<MessagingSearchIntegrationWidget> createState() => 
      _MessagingSearchIntegrationWidgetState();
}

class _MessagingSearchIntegrationWidgetState 
    extends State<MessagingSearchIntegrationWidget> {
  final MessagingService _messagingService = MessagingService();

  @override
  void initState() {
    super.initState();
    _initializeMessagingService();
  }

  Future<void> _initializeMessagingService() async {
    try {
      await _messagingService.initialize();
    } catch (e) {
      debugPrint('Error initializing messaging service: $e');
    }
  }

  void _handleUserSelected(UserModel user) {
    if (widget.onUserSelected != null) {
      widget.onUserSelected!(user);
    } else {
      // Default behavior: navigate to conversation with user
      _navigateToUserConversation(user);
    }
  }

  void _handleMessageSelected(MessageModel message) {
    if (widget.onMessageSelected != null) {
      widget.onMessageSelected!(message);
    } else {
      // Default behavior: navigate to message in conversation
      _navigateToMessage(message);
    }
  }

  void _navigateToUserConversation(UserModel user) {
    // TODO: Implement navigation to conversation with user
    debugPrint('Navigate to conversation with user: ${user.fullName}');
    
    // Close search if shown as bottom sheet
    if (widget.showAsBottomSheet) {
      Navigator.of(context).pop();
    }
  }

  void _navigateToMessage(MessageModel message) {
    // TODO: Implement navigation to specific message in conversation
    debugPrint('Navigate to message: ${message.id} in conversation: ${message.conversationId}');
    
    // Close search if shown as bottom sheet
    if (widget.showAsBottomSheet) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAsBottomSheet) {
      return _buildBottomSheetContent();
    } else {
      return _buildFullScreenContent();
    }
  }

  Widget _buildBottomSheetContent() {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Search content
              Expanded(
                child: MessagingSearchWidget(
                  onUserSelected: _handleUserSelected,
                  onMessageSelected: _handleMessageSelected,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullScreenContent() {
    return MessagingSearchWidget(
      onUserSelected: _handleUserSelected,
      onMessageSelected: _handleMessageSelected,
    );
  }

  /// Show search as bottom sheet
  static Future<void> showSearchBottomSheet(
    BuildContext context, {
    Function(UserModel)? onUserSelected,
    Function(MessageModel)? onMessageSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MessagingSearchIntegrationWidget(
        onUserSelected: onUserSelected,
        onMessageSelected: onMessageSelected,
        showAsBottomSheet: true,
      ),
    );
  }

  /// Show search as full screen
  static Future<void> showSearchScreen(
    BuildContext context, {
    Function(UserModel)? onUserSelected,
    Function(MessageModel)? onMessageSelected,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessagingSearchIntegrationWidget(
          onUserSelected: onUserSelected,
          onMessageSelected: onMessageSelected,
          showAsBottomSheet: false,
        ),
      ),
    );
  }
}

/// Search button widget for easy integration
class MessagingSearchButton extends StatelessWidget {
  final Function(UserModel)? onUserSelected;
  final Function(MessageModel)? onMessageSelected;
  final bool showAsBottomSheet;
  final IconData? icon;
  final String? tooltip;

  const MessagingSearchButton({
    Key? key,
    this.onUserSelected,
    this.onMessageSelected,
    this.showAsBottomSheet = true,
    this.icon,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon ?? Icons.search),
      tooltip: tooltip ?? 'Search messages and users',
      onPressed: () {
        if (showAsBottomSheet) {
          MessagingSearchIntegrationWidget.showSearchBottomSheet(
            context,
            onUserSelected: onUserSelected,
            onMessageSelected: onMessageSelected,
          );
        } else {
          MessagingSearchIntegrationWidget.showSearchScreen(
            context,
            onUserSelected: onUserSelected,
            onMessageSelected: onMessageSelected,
          );
        }
      },
    );
  }
}

/// Search app bar for messaging screens
class MessagingSearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Function(UserModel)? onUserSelected;
  final Function(MessageModel)? onMessageSelected;

  const MessagingSearchAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.onUserSelected,
    this.onMessageSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        MessagingSearchButton(
          onUserSelected: onUserSelected,
          onMessageSelected: onMessageSelected,
        ),
        ...?actions,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}